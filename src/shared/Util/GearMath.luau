-- สูตรคำนวณของอุปกรณ์ป้อม (ฟังก์ชันล้วน ไม่แตะเกม/ไม่สุ่มเอง) (เจ้าของ: Gameplay_Scripter) · สเปก: design/equipment.md
-- ใช้ได้ทั้งสองฝั่ง: Server ใช้ตัดสินจริง (GearService, PlayerData) · Client ใช้ "แสดง" เท่านั้น (โบนัสรวม, โอกาสดรอป)
-- ตัวเลขทั้งหมดอยู่ที่ src/shared/Config/Equipment.luau → ปรับค่าไม่ต้องแก้ไฟล์นี้
-- การสุ่ม: ฟังก์ชันที่นี่รับเลขสุ่ม u (0 ≤ u < 1) จากผู้เรียก → ทดสอบได้ และ Server เป็นคนสุ่มด้วย Random.new() เท่านั้น
--
-- ใครใช้: Services/GearService · Data/PlayerData (migration + sanitize ตอนโหลด) · Services/TurretService (stunReduce)
--   Client = UI อุปกรณ์ (แสดงโบนัส/โอกาส)
-- ⚠️ ห้ามแก้: sanitize ต้อง "ทิ้งของที่ไม่รู้จัก" เสมอ (ข้อมูลจาก DataStore ห้ามเชื่อ) · fromLegacy ใช้ใน migration v6→v7
--   (แก้แล้วผลกับผู้เล่นที่ยังไม่ได้ migrate จะเปลี่ยน → แก้ได้เฉพาะกรณีบั๊ก)
--
-- 📖 อ่านตามลำดับนี้
--   1) parseKey / keyOf — id ในกระเป๋า "<ช่อง>_<แบบ>_<ระดับ>" ↔ 3 ส่วน (ตัวกันหลักของ id มั่ว)
--   2) bonus — รวมโบนัสจากชิ้นที่ใส่ (ค่าหลัก + ธาตุตรง + ชุดครบ) แล้วบีบเพดาน → TurretService ใช้ผ่าน GearService.bonus
--   3) rollTables / pickRarity / applyPity / variantWeights / pickWeighted — ขั้นตอนดรอปจากบอส (GearService.grantBossDrops)
--   4) sanitize / fromLegacy — ล้างข้อมูลตอนโหลด / แปลงข้อมูลเก่า (PlayerData)

local Equipment = require(script.Parent.Parent.Config.Equipment)

-- ===== ชนิดข้อมูล =====
-- โบนัสรวมเป็นสัดส่วน (0.22 = +22%) · SkillCooldown / StunReduce = "ลดลง" กี่ %
export type Bonus = {
	Damage: number,
	FireRate: number,
	BossDamage: number,
	SkillCooldown: number,
	SkillDamage: number,
	TurretHp: number,
	StunReduce: number,
}
-- ข้อมูลอุปกรณ์ที่เซฟ (PlayerData.Gear · v7)
export type Gear = {
	Items: { [string]: number }, -- ["Barrel_Fire_Rare"] = 2 (จำนวนเต็ม 1..StackCap)
	Equipped: { [string]: string }, -- [ช่อง] = id ในกระเป๋า หรือ ""
	Slots: number, -- ช่องที่เปิดแล้ว StartSlots..MaxSlots
	Pity: number, -- rolls ติดกันที่ยังไม่ได้ PityRarity ขึ้นไป
}
-- ภาพของชิ้นที่ใส่ 1 ชิ้น (TurretLook ใช้ปั้นชิ้นบนป้อม)
export type Visual = { Slot: string, Variant: string, Rarity: string }

-- ===== ตารางค้นหา (สร้างครั้งเดียวจาก Config) =====
-- ลำดับ (index) ของช่อง/ระดับ · ใช้เช็กว่ามีจริง + เทียบสูงต่ำ
local SLOT_INDEX: { [string]: number } = {}
for index, slot in Equipment.SlotOrder do
	SLOT_INDEX[slot] = index
end
local RARITY_INDEX: { [string]: number } = {}
for index, rarity in Equipment.RarityOrder do
	RARITY_INDEX[rarity] = index
end
local VARIANT_SET: { [string]: boolean } = {}
for _, variant in Equipment.Variants do
	VARIANT_SET[variant] = true
end
local BONUS_STATS = { "Damage", "FireRate", "BossDamage", "SkillCooldown", "SkillDamage", "TurretHp", "StunReduce" }

local GearMath = {}

-- ===== id =====
-- "<ช่อง>_<แบบ>_<ระดับ>" · ผู้เรียกต้องส่งค่าที่ถูกต้องเอง (ใช้กับค่าจาก Config)
function GearMath.keyOf(slot: string, variant: string, rarity: string): string
	return `{slot}_{variant}_{rarity}`
end

-- แยก id → (ช่อง, แบบ, ระดับ) · ไม่ใช่ id ที่รู้จัก (ชนิดผิด/ส่วนเกิน/ชื่อมั่ว) → nil, nil, nil
-- ตัวอย่าง: "Barrel_Fire_Rare" → "Barrel", "Fire", "Rare" · "Barrel_Rare" → nil
function GearMath.parseKey(key: any): (string?, string?, string?)
	if type(key) ~= "string" or #key > 64 then
		return nil, nil, nil
	end
	local parts = string.split(key, "_")
	if #parts ~= 3 then
		return nil, nil, nil
	end
	local slot, variant, rarity = parts[1], parts[2], parts[3]
	if SLOT_INDEX[slot] and VARIANT_SET[variant] and RARITY_INDEX[rarity] then
		return slot, variant, rarity
	end
	return nil, nil, nil
end

-- true ถ้าเป็น id ที่มีจริงใน Config
function GearMath.isKey(key: any): boolean
	return (GearMath.parseKey(key)) ~= nil
end

-- ลำดับช่อง (1..4) / ลำดับระดับ (1..4) · ไม่รู้จัก = nil
function GearMath.slotIndex(slot: any): number?
	return if type(slot) == "string" then SLOT_INDEX[slot] else nil
end
function GearMath.rarityIndex(rarity: any): number?
	return if type(rarity) == "string" then RARITY_INDEX[rarity] else nil
end

-- ระดับถัดไป (ใช้กับรวม 3→1) · Legendary / ไม่รู้จัก = nil
function GearMath.nextRarity(rarity: string): string?
	local index = RARITY_INDEX[rarity]
	return if index then Equipment.RarityOrder[index + 1] else nil
end

-- ===== ตัวเลขพื้นฐาน =====
-- จำนวนช่องที่เปิดแล้ว (บีบเป็นจำนวนเต็ม StartSlots..MaxSlots · ค่าเสีย = StartSlots)
function GearMath.clampSlots(value: any): number
	if type(value) ~= "number" or value ~= value then
		return Equipment.StartSlots
	end
	return math.clamp(math.floor(value), Equipment.StartSlots, Equipment.MaxSlots)
end

-- ช่อง slot เปิดแล้วหรือยัง (slots = จำนวนช่องที่เปิด)
function GearMath.isSlotOpen(slot: string, slots: number): boolean
	local index = SLOT_INDEX[slot]
	return index ~= nil and index <= GearMath.clampSlots(slots)
end

-- ราคาเปิดช่องถัดไป · เปิดครบแล้ว = nil
function GearMath.nextSlotPrice(slots: number): number?
	local current = GearMath.clampSlots(slots)
	if current >= Equipment.MaxSlots then
		return nil
	end
	return Equipment.SlotPrices[current + 1]
end

-- ค่าหลักของชิ้น: (ชนิดค่า, สัดส่วน) · ตัวอย่าง: Barrel_Neutral_Epic → "Damage", 0.18
function GearMath.mainStat(slot: string, variant: string, rarity: string): (string, number)
	local tableFor = if variant == "Neutral" then Equipment.NeutralMainStat else Equipment.MainStat
	return Equipment.Slots[slot].Main, tableFor[slot][rarity]
end

-- ค่ารองธาตุตรง: (ชนิดค่า, สัดส่วน) เมื่อ variant == ธาตุป้อม · ไม่ตรง/ชิ้นกลาง/ยังไม่เลือกธาตุ = nil, 0
-- ตัวอย่าง: Barrel_Fire_Legendary บนป้อมไฟ → "SkillDamage", 0.25 · บนป้อมน้ำ → nil, 0
function GearMath.matchStat(variant: string, rarity: string, element: any): (string?, number)
	local match = Equipment.MatchBonus[variant]
	if not match or variant ~= element then
		return nil, 0
	end
	return match.Stat, match[rarity] or 0
end

-- เหรียญที่ได้จากการย่อย 1 ชิ้น / ค่ารวม 3→1 (Legendary = nil รวมไม่ได้)
function GearMath.salvageValue(rarity: string): number
	local def = Equipment.Rarities[rarity]
	return if def then def.Salvage else 0
end
function GearMath.mergeCost(rarity: string): number?
	local def = Equipment.Rarities[rarity]
	return if def then def.MergeCost else nil
end

-- ===== กระเป๋า =====
-- จำนวนชิ้นทั้งหมด (ทุกสำเนา รวมชิ้นที่ใส่)
function GearMath.countAll(items: { [string]: number }): number
	local total = 0
	for _, count in items do
		total += count
	end
	return total
end

-- id นี้ถูกใส่อยู่ในช่องของมันไหม
function GearMath.isEquipped(gear: Gear, key: string): boolean
	local slot = GearMath.parseKey(key)
	return slot ~= nil and gear.Equipped[slot] == key
end

-- จำนวนที่ "ใช้ได้" (ย่อย/รวม) = จำนวนที่มี − 1 ถ้าใส่อยู่ (ชิ้นที่ใส่ย่อย/รวมไม่ได้)
function GearMath.freeCount(gear: Gear, key: string): number
	local have = gear.Items[key] or 0
	return math.max(0, have - (if GearMath.isEquipped(gear, key) then 1 else 0))
end

-- ===== โบนัสรวม =====
function GearMath.emptyBonus(): Bonus
	return { Damage = 0, FireRate = 0, BossDamage = 0, SkillCooldown = 0, SkillDamage = 0, TurretHp = 0, StunReduce = 0 }
end

-- รวมโบนัสจากชิ้นที่ใส่ (เฉพาะช่องที่เปิดแล้ว) บนป้อมธาตุ element ("" = ยังไม่เลือก)
-- ขั้นตอน: ค่าหลักทุกชิ้น + ค่ารองของชิ้นธาตุตรง → ธาตุตรงครบทุกช่อง = + FullSetBonus → บีบเพดาน Caps
-- ทุกชิ้น "บวกกัน" แล้วผู้ใช้คูณครั้งเดียว เช่น ดาเมจ +22% +5% = ×1.27 (ไม่คูณทบ)
-- ตัวอย่าง: ป้อมไฟใส่ Barrel_Fire_Legendary ชิ้นเดียว → Damage 0.22, SkillDamage 0.25
function GearMath.bonus(gear: any, element: any): Bonus
	local result = GearMath.emptyBonus()
	if type(gear) ~= "table" or type(gear.Equipped) ~= "table" then
		return result
	end
	local slots = GearMath.clampSlots(gear.Slots)
	local matched = 0
	for index, slot in Equipment.SlotOrder do
		if index > slots then
			break
		end
		local itemSlot, variant, rarity = GearMath.parseKey(gear.Equipped[slot])
		if itemSlot == slot and variant and rarity then
			local stat, value = GearMath.mainStat(slot, variant, rarity)
			result[stat] += value
			local matchStat, matchValue = GearMath.matchStat(variant, rarity, element)
			if matchStat then
				result[matchStat] += matchValue
				matched += 1
			end
		end
	end
	-- ชุดธาตุ: ต้องใส่ชิ้นธาตุตรงครบ "ทุกช่อง" (เปิดครบ 4 ช่องก่อน)
	if matched == #Equipment.SlotOrder then
		result[Equipment.FullSetBonus.Stat] += Equipment.FullSetBonus.Value
	end
	local caps = Equipment.Caps
	result.BossDamage = math.min(result.BossDamage, caps.BossDamage)
	result.SkillCooldown = math.min(result.SkillCooldown, caps.SkillCooldown)
	result.TurretHp = math.min(result.TurretHp, caps.TurretHp)
	result.StunReduce = math.min(result.StunReduce, caps.StunReduceTotal)
	return result
end

-- เวลาช็อตลดรวม = Passive ของธาตุ (ตัวเบา 0.4) + อุปกรณ์ · ไม่เกิน Caps.StunReduceTotal
-- ตัวอย่าง: ลม 0.4 + เกราะลม 0.16 + ... → สูงสุด 0.7 → ช็อต 6 × 0.3 = 1.8 วิ
function GearMath.stunReduce(passiveAmount: number, gearAmount: number): number
	return math.clamp(passiveAmount + gearAmount, 0, Equipment.Caps.StunReduceTotal)
end

-- รายการภาพของชิ้นที่ใส่ (ช่องที่เปิดแล้วเท่านั้น) → TurretLook.setGear
function GearMath.visuals(gear: any): { Visual }
	local list: { Visual } = {}
	if type(gear) ~= "table" or type(gear.Equipped) ~= "table" then
		return list
	end
	local slots = GearMath.clampSlots(gear.Slots)
	for index, slot in Equipment.SlotOrder do
		if index > slots then
			break
		end
		local itemSlot, variant, rarity = GearMath.parseKey(gear.Equipped[slot])
		if itemSlot == slot and variant and rarity then
			table.insert(list, { Slot = slot, Variant = variant, Rarity = rarity })
		end
	end
	return list
end

-- ===== ดรอปจากบอส (ผู้เรียกสุ่มเลข u เอง) =====
-- ตารางโอกาสตาม share (ดาเมจตัวเอง ÷ รวม) · < 10% = A · 10–25% = B · ≥ 25% = C
function GearMath.tableFor(share: number): string
	local steps = Equipment.Drops.ShareRolls
	if share ~= share then
		return "A"
	end
	if share >= steps[2] then
		return "C"
	elseif share >= steps[1] then
		return "B"
	end
	return "A"
end

-- รายชื่อตารางของทุก roll ที่คนนี้ได้ (ความยาว = จำนวน roll · ไม่เกิน MaxRolls)
-- ตัวอย่าง: อันดับ 1 share 12% → { "B", "B", "Top" } · อันดับ 5 share 3% → { "A" }
function GearMath.rollTables(share: number, rank: number): { string }
	local drops = Equipment.Drops
	local safeShare = if share == share then share else 0
	local normal = GearMath.tableFor(safeShare)
	local list = {}
	for _ = 1, drops.BaseRolls do
		table.insert(list, normal)
	end
	for _, threshold in drops.ShareRolls do
		if safeShare >= threshold then
			table.insert(list, normal)
		end
	end
	if rank == drops.TopRollRank then
		table.insert(list, "Top")
	end
	if table.find(drops.RankRolls, rank) then
		table.insert(list, normal)
	end
	while #list > drops.MaxRolls do
		table.remove(list)
	end
	return list
end

-- โอกาสของแต่ละระดับในตาราง name เป็นสัดส่วนรวม 1 (สำหรับ UI "โอกาสดรอป") · { { Rarity, Chance } }
function GearMath.odds(name: string): { { Rarity: string, Chance: number } }
	local weights = Equipment.Drops.Tables[name]
	local list = {}
	if not weights then
		return list
	end
	local sum = 0
	for _, rarity in Equipment.RarityOrder do
		sum += weights[rarity] or 0
	end
	for _, rarity in Equipment.RarityOrder do
		table.insert(list, { Rarity = rarity, Chance = if sum > 0 then (weights[rarity] or 0) / sum else 0 })
	end
	return list
end

-- เลือกระดับจากตาราง name ด้วยเลขสุ่ม u (0 ≤ u < 1)
-- ตัวอย่าง ตาราง A: u < 0.72 → Common · < 0.95 → Rare · < 0.995 → Epic · ที่เหลือ → Legendary
function GearMath.pickRarity(name: string, u: number): string
	local weights = Equipment.Drops.Tables[name] or Equipment.Drops.Tables.A
	local sum = 0
	for _, rarity in Equipment.RarityOrder do
		sum += weights[rarity] or 0
	end
	local roll = u * sum
	local last = Equipment.RarityOrder[1]
	for _, rarity in Equipment.RarityOrder do
		local weight = weights[rarity] or 0
		if weight > 0 then
			last = rarity
			if roll < weight then
				return rarity
			end
			roll -= weight
		end
	end
	return last -- กันเศษทศนิยม
end

-- Pity: pity ครบ PityRolls แล้วยังได้ต่ำกว่า PityRarity → บังคับเป็น PityRarity
-- คืน (ระดับที่ได้จริง, pity ใหม่) · ได้ PityRarity ขึ้นไป = รีเซ็ต 0 · ไม่ได้ = +1 (ไม่เกิน PityRolls)
-- ตัวอย่าง: 30 ครั้งติดไม่ได้ Epic (pity = 30) → ครั้งที่ 31 ได้ Epic แน่นอน
function GearMath.applyPity(rarity: string, pity: number): (string, number)
	local drops = Equipment.Drops
	local threshold = RARITY_INDEX[drops.PityRarity]
	local result = rarity
	if pity >= drops.PityRolls and (RARITY_INDEX[result] or 0) < threshold then
		result = drops.PityRarity
	end
	if (RARITY_INDEX[result] or 0) >= threshold then
		return result, 0
	end
	return result, math.min(pity + 1, drops.PityRolls)
end

-- น้ำหนักสุ่ม "แบบ" ของชิ้น ตามธาตุป้อม · { { Id, Weight } }
-- ตัวอย่าง ป้อมไฟ: Fire 2 · Water 1 · Earth 1 · Wind 1 · Neutral 1 (ไฟ = 2/6) · ยังไม่เลือกธาตุ = ทุกแบบ 1
function GearMath.variantWeights(element: any): { { Id: string, Weight: number } }
	local drops = Equipment.Drops
	local hasElement = type(element) == "string" and Equipment.MatchBonus[element] ~= nil
	local list = {}
	for _, variant in Equipment.Variants do
		local weight
		if not hasElement then
			weight = 1
		elseif variant == "Neutral" then
			weight = drops.NeutralWeight
		elseif variant == element then
			weight = drops.OwnElementWeight
		else
			weight = drops.OtherWeight
		end
		table.insert(list, { Id = variant, Weight = weight })
	end
	return list
end

-- เลือก 1 รายการจาก { { Id, Weight } } ด้วยเลขสุ่ม u (0 ≤ u < 1)
function GearMath.pickWeighted(list: { { Id: string, Weight: number } }, u: number): string
	local sum = 0
	for _, entry in list do
		sum += entry.Weight
	end
	local roll = u * sum
	for _, entry in list do
		if roll < entry.Weight then
			return entry.Id
		end
		roll -= entry.Weight
	end
	return list[#list].Id
end

-- ===== ข้อมูลเซฟ =====
-- ข้อมูลอุปกรณ์ตั้งต้น (ผู้เล่นใหม่ / แทนข้อมูลเสีย)
function GearMath.newGear(): Gear
	local equipped = {}
	for _, slot in Equipment.SlotOrder do
		equipped[slot] = ""
	end
	return { Items = {}, Equipped = equipped, Slots = Equipment.StartSlots, Pity = 0 }
end

-- ล้างข้อมูลอุปกรณ์จาก DataStore (PlayerData เรียกทุกครั้งตอนโหลด หลัง reconcile) · คืน (ข้อมูลใหม่, จำนวนจุดที่แก้)
-- reconcile ไม่ตรวจ key ข้างใน Items (แม่แบบว่าง) → ที่นี่ตรวจเอง:
--   Items: id ต้องมีใน Config · จำนวนต้องเป็นจำนวนเต็ม > 0 (ติดลบ/ทศนิยม/NaN = ทิ้ง) · เกิน StackCap = บีบลง
--   Slots: บีบ StartSlots..MaxSlots · Pity: บีบ 0..PityRolls
--   Equipped: ต้องเป็น id ที่มีในกระเป๋า + ตรงช่อง + ช่องเปิดแล้ว ไม่งั้น = ""
-- ตัวอย่าง: Items = { Fake_X_Y = 3, Barrel_Fire_Rare = 1.5, Core_Wind_Epic = 1e9 } → { Core_Wind_Epic = 99 } (แก้ 3 จุด)
function GearMath.sanitize(raw: any): (Gear, number)
	local fixes = 0
	local source = if type(raw) == "table" then raw else {}
	if type(raw) ~= "table" then
		fixes += 1
	end
	local items: { [string]: number } = {}
	if type(source.Items) == "table" then
		for key, count in source.Items do
			local valid = GearMath.isKey(key) and type(count) == "number" and count == count and count >= 1 and count % 1 == 0
			if valid then
				if count > Equipment.StackCap then
					fixes += 1
				end
				items[key] = math.min(count, Equipment.StackCap)
			else
				fixes += 1
			end
		end
	elseif source.Items ~= nil then
		fixes += 1
	end

	local slots = GearMath.clampSlots(source.Slots)
	if slots ~= source.Slots then
		fixes += 1
	end

	local pity = source.Pity
	if type(pity) ~= "number" or pity ~= pity then
		pity = 0
		fixes += 1
	else
		local clamped = math.clamp(math.floor(pity), 0, Equipment.Drops.PityRolls)
		if clamped ~= pity then
			fixes += 1
		end
		pity = clamped
	end

	local equipped: { [string]: string } = {}
	local rawEquipped = if type(source.Equipped) == "table" then source.Equipped else {}
	for index, slot in Equipment.SlotOrder do
		local key = rawEquipped[slot]
		local itemSlot = GearMath.parseKey(key)
		if itemSlot == slot and index <= slots and (items[key] or 0) >= 1 then
			equipped[slot] = key
		else
			if key ~= "" then
				fixes += 1
			end
			equipped[slot] = ""
		end
	end

	return { Items = items, Equipped = equipped, Slots = slots, Pity = pity }, fixes
end

-- แปลงอุปกรณ์รูปแบบ v4–v6 ["<ช่อง>_<ระดับ>"] = จำนวน → Items ของ v7 (เป็นชิ้นกลาง Neutral) · ใช้ใน migration v6→v7
-- ช่อง/ระดับไม่รู้จัก หรือจำนวนเสีย = ทิ้ง · จำนวนปัดลง บีบ 0..StackCap · id รูปแบบ v7 อยู่แล้ว = เก็บไว้
-- คืน (Items, จำนวน key ที่ทิ้ง) · ตัวอย่าง: { Barrel_Rare = 2, Scope_Epic = 1 } → { Barrel_Neutral_Rare = 2 }, 1
-- [Verified: grep ไม่พบโค้ดที่เคยเขียน Gear ใน src (v4–v6 เป็น {} ทุกคน)] → แปลงไว้กันพลาดเท่านั้น
function GearMath.fromLegacy(old: any): ({ [string]: number }, number)
	local items: { [string]: number } = {}
	local dropped = 0
	if type(old) ~= "table" then
		return items, 0
	end
	for key, count in old do
		local newKey: string? = nil
		if GearMath.isKey(key) then
			newKey = key
		elseif type(key) == "string" then
			local parts = string.split(key, "_")
			if #parts == 2 and SLOT_INDEX[parts[1]] and RARITY_INDEX[parts[2]] then
				newKey = GearMath.keyOf(parts[1], "Neutral", parts[2])
			end
		end
		local amount = if type(count) == "number" and count == count then math.clamp(math.floor(count), 0, Equipment.StackCap) else 0
		if newKey and amount > 0 then
			items[newKey] = math.min((items[newKey] or 0) + amount, Equipment.StackCap)
		else
			dropped += 1
		end
	end
	return items, dropped
end

-- ชื่อชนิดโบนัสทั้งหมด (UI ใช้วนแสดง)
GearMath.BONUS_STATS = table.freeze(BONUS_STATS)

return GearMath
