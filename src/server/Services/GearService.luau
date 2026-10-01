-- อุปกรณ์ป้อม: ใส่/ถอด · เปิดช่อง · ย่อย · รวม 3→1 · ดรอปจากบอส · โบนัสให้ป้อม (เจ้าของ: Gameplay_Scripter) · สเปก: design/equipment.md
-- แทนระบบกาชาสกิลเดิม (SkillService ถูกลบ 2026-09-30 ตามคำสั่งเจ้าของเกม)
-- Server Authority: Client ส่งแค่ "id ที่อยากทำ" (ผ่าน Network/GearHandler + Guard) · กฎทุกข้อตรวจซ้ำ "ข้างใน" PlayerData.update
--   เช็ก → หัก → เพิ่ม ในการเรียก update ครั้งเดียว (ไม่มีสถานะครึ่งๆ กลางๆ · กันของซ้ำ/เงินหาย)
-- การสุ่มดรอปเกิดที่นี่ที่เดียว ด้วย Random.new() ของ Server · ไม่มี Remote ให้ Client ขอดรอป
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ตัวเลขทั้งหมด (ราคาช่อง, ค่าสถานะ, ย่อย/รวม, ตารางดรอป, pity, ขนาดกระเป๋า) → src/shared/Config/Equipment.luau
--   • สูตรรวมโบนัส / ขั้นตอนสุ่ม → src/shared/Util/GearMath.luau
--
-- คุยกับไฟล์ไหนบ้าง:
--   • Network/GearHandler — เรียก equip / unequip / unlockSlot / salvage / salvageRarity / merge หลังผ่าน Guard
--   • BossService.finish — เรียก grantBossDrops (แทนการแจกตั๋วกาชาเดิม)
--   • TurretService — อ่าน bonus / visuals · ฟัง GearService.Changed (อัปเดตเลือดเต็ม + ชิ้นบนป้อม)
--   • TurretElementService.damageBoss — อ่าน bonus (ดาเมจบอส)
--   • PlayerData — เก็บ Gear + Coins · Client เห็นผ่าน Player Attribute "Gear" / "GearSlots" / "GearBonus" + Remote "GearDrops"
--
-- ⚠️ ห้ามแก้:
--   • ทุกการแก้ Gear / Coins ต้องอยู่ใน PlayerData.update และตรวจกฎซ้ำข้างในเสมอ (ห้ามเชื่อค่าที่ Client ส่งมา)
--   • ห้าม require BossService บนหัวไฟล์ (BossService require ไฟล์นี้ → วนกัน = require พัง) → ใช้ bossActive() ด้านล่าง
--   • ห้าม require TutorialService บนหัวไฟล์ (เหตุผลเดียวกัน) → ใช้ tutorialDone() · ฝึกยังไม่จบ = ทุกคำสั่งไม่ทำงาน (ยกเว้นดรอปบอส)
--   • ระบบอื่นห้ามแก้ data.Gear เอง (cache โบนัส / Attribute จะไม่อัปเดต) → เพิ่มฟังก์ชันในไฟล์นี้แทน
--
-- 📖 อ่านตามลำดับนี้
--   1) Init (ท้ายไฟล์) — ผูก Remote GearDrops · ฟัง PlayerData.Changed (โหลดเสร็จ/ธาตุเปลี่ยน → ส่ง Attribute + ยิง Changed)
--   2) bonus — TurretService / TurretElementService ถามโบนัสของผู้เล่น (cache · คำนวณใหม่เมื่ออุปกรณ์/ธาตุเปลี่ยน)
--   3) equip / unequip / unlockSlot — เปลี่ยนสิ่งที่ใส่ (ห้ามระหว่างบอส ยกเว้นเปิดช่อง)
--   4) salvage / salvageRarity / merge — จัดการของซ้ำ (ทำได้ทุกเวลา)
--   5) grantBossDrops — บอสจากไป: จำนวน roll → ระดับ (+ pity) → ช่อง → แบบ → เข้ากระเป๋า (เต็ม = ย่อยอัตโนมัติ)
--   6) afterChange / mirror — ล้าง cache + ส่ง Attribute ให้ Client + ยิง Changed

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== สถานะ (หน่วยความจำเท่านั้น · ความจริงอยู่ใน PlayerData) =====
local rng = Random.new()
-- โบนัสที่คำนวณไว้แล้ว + ธาตุตอนคำนวณ (ธาตุเปลี่ยน = คำนวณใหม่เอง) · อุปกรณ์เปลี่ยน = ลบทิ้ง
local bonusCache: { [Player]: { element: string, bonus: GearMath.Bonus } } = {}
-- ส่ง Attribute ให้คนนี้ครั้งแรกแล้วหรือยัง · ธาตุล่าสุดที่เห็น (ใช้รู้ว่าธาตุเปลี่ยน → โบนัสธาตุตรงเปลี่ยน)
local mirrored: { [Player]: boolean } = {}
local lastElement: { [Player]: string } = {}
-- โบนัสว่าง (ข้อมูลยังไม่โหลด) · freeze กันใครเผลอแก้
local EMPTY_BONUS: GearMath.Bonus = table.freeze(GearMath.emptyBonus())
local changedEvent = Instance.new("BindableEvent")
local dropsRemote: RemoteEvent? = nil

-- ===== ตัวช่วย =====
-- BossService โหลดทีหลัง (lazy require) · BossService require ไฟล์นี้อยู่แล้ว → require บนหัวไฟล์จะวนกัน
local BossService: any = nil
local function bossActive(): boolean
	if not BossService then
		BossService = require(script.Parent.BossService)
	end
	return BossService.isActive()
end

-- ฝึกสอนจบหรือยัง (design/tutorial.md: ระหว่างฝึกใช้อุปกรณ์ไม่ได้ทุกคำสั่ง) · lazy require เหมือน BossService
-- TutorialService → BossService → ไฟล์นี้ → require บนหัวไฟล์จะวนกัน
local TutorialService: any = nil
local function tutorialDone(player: Player): boolean
	if not TutorialService then
		TutorialService = require(script.Parent.TutorialService)
	end
	return TutorialService.isDone(player)
end

-- ธาตุป้อมจากข้อมูล ("" = ยังไม่เลือก / ข้อมูลเสีย)
local function elementOf(data: any): string
	return if ElementMath.isElement(data.Element) then data.Element else ""
end

-- Gear ของผู้เล่น (ใช้ใน update เท่านั้น) · โครงเสีย (ไม่น่าเกิดเพราะ sanitize ตอนโหลดแล้ว) → ล้างใหม่ก่อนใช้
local function gearOf(data: any): GearMath.Gear
	local gear = data.Gear
	if type(gear) ~= "table" or type(gear.Items) ~= "table" or type(gear.Equipped) ~= "table" then
		data.Gear = GearMath.sanitize(gear)
	end
	return data.Gear
end

-- เงินตอนนี้ (ค่าเสีย = 0)
local function coinsOf(data: any): number
	local coins = data.Coins
	return if type(coins) == "number" and coins == coins then coins else 0
end

-- บวกเหรียญ (ย่อย) ในที่เดียวกับการหักของ · ไม่เกิน MaxCoins
-- ⚠️ ตั้งใจไม่ใช้ Wallet.earn: ต้องอยู่ใน update เดียวกับการหักของ (atomic) และเหรียญจากย่อยไม่คูณโบนัสเพื่อน [Proposed]
local function addCoins(data: any, amount: number)
	data.Coins = math.min(coinsOf(data) + amount, Economy.MaxCoins)
end

-- ส่งอุปกรณ์ให้ Client ผ่าน Player Attribute (แสดงผลเท่านั้น · สัญญาอยู่ท้าย design/equipment.md)
--   Gear = JSON ของ data.Gear · GearSlots = ช่องที่เปิด · GearBonus = JSON โบนัสรวม (ตามธาตุป้อมตอนนี้)
local function mirror(player: Player, data: any)
	local gear = data.Gear
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, gear)
	if ok then
		player:SetAttribute("Gear", encoded)
	end
	player:SetAttribute("GearSlots", GearMath.clampSlots(if type(gear) == "table" then gear.Slots else nil))
	local bonusOk, bonusJson = pcall(HttpService.JSONEncode, HttpService, GearMath.bonus(gear, elementOf(data)))
	if bonusOk then
		player:SetAttribute("GearBonus", bonusJson)
	end
end

-- หลังอุปกรณ์เปลี่ยน: ล้าง cache โบนัส → ส่ง Attribute → (ถ้าของที่ใส่เปลี่ยน) ยิง Changed ให้ TurretService
local function afterChange(player: Player, equippedChanged: boolean)
	bonusCache[player] = nil
	local data = PlayerData.get(player)
	if data then
		mirror(player, data)
	end
	if equippedChanged then
		changedEvent:Fire(player)
	end
end

-- PlayerData.Changed (ยิงทุกครั้งที่ข้อมูลเปลี่ยน เช่น เงิน): ทำงานแค่ตอน "โหลดเสร็จครั้งแรก" หรือ "ธาตุเปลี่ยน"
-- (ไม่ encode JSON ทุกครั้งที่เงินเปลี่ยน · การแก้อุปกรณ์เรียก afterChange เองอยู่แล้ว)
local function onDataChanged(player: Player, data: any)
	if not player.Parent then
		return
	end
	local element = elementOf(data)
	if mirrored[player] and lastElement[player] == element then
		return
	end
	mirrored[player] = true
	lastElement[player] = element
	bonusCache[player] = nil
	mirror(player, data)
	changedEvent:Fire(player)
end

-- ===== API =====
local GearService = {}

-- ดังเมื่อ "ของที่ใส่" หรือธาตุ (โบนัสธาตุตรง) เปลี่ยน หรือข้อมูลโหลดเสร็จ: (player) · TurretService อัปเดตเลือด + ชิ้นบนป้อม
GearService.Changed = changedEvent.Event

-- โบนัสรวมของผู้เล่น (สัดส่วน · บีบเพดานแล้ว) → GearMath.bonus · ยังไม่โหลดข้อมูล = ศูนย์ทั้งหมด
-- ⚠️ ค่าที่คืนเป็นตารางใน cache → อ่านอย่างเดียว ห้ามแก้
function GearService.bonus(player: Player): GearMath.Bonus
	local data = PlayerData.get(player)
	if not data then
		return EMPTY_BONUS
	end
	local element = elementOf(data)
	local cached = bonusCache[player]
	if cached and cached.element == element then
		return cached.bonus
	end
	local bonus = GearMath.bonus(data.Gear, element)
	bonusCache[player] = { element = element, bonus = bonus }
	return bonus
end

-- ชิ้นที่ใส่ (สำหรับปั้นหน้าตาบนป้อม) → TurretLook.setGear
function GearService.visuals(player: Player): { GearMath.Visual }
	local data = PlayerData.get(player)
	return if data then GearMath.visuals(data.Gear) else {}
end

-- ใส่ชิ้น key ในช่องของมัน · กฎ: id มีจริง · มีในกระเป๋า ≥ 1 · ช่องเปิดแล้ว · บอสไม่อยู่ · คืน true ถ้าเปลี่ยน
function GearService.equip(player: Player, key: string): boolean
	local changed = false
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		-- ⚠️ ตรวจทุกข้อ "ข้างใน" update (ห้ามย้ายออก)
		if bossActive() then
			return -- ห้ามเปลี่ยนอุปกรณ์ระหว่างบอส (กันสลับหาค่าเฉพาะหน้า · เหมือนกฎเปลี่ยนธาตุ)
		end
		local gear = gearOf(data)
		local slot = GearMath.parseKey(key)
		if not slot or not GearMath.isSlotOpen(slot, gear.Slots) then
			return
		end
		if (gear.Items[key] or 0) < 1 or gear.Equipped[slot] == key then
			return
		end
		gear.Equipped[slot] = key
		changed = true
	end)
	if changed then
		afterChange(player, true)
	end
	return changed
end

-- ถอดชิ้นในช่อง slot · กฎ: ช่องมีจริง · มีของใส่อยู่ · บอสไม่อยู่
function GearService.unequip(player: Player, slot: string): boolean
	local changed = false
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		if bossActive() or not GearMath.slotIndex(slot) then
			return
		end
		local gear = gearOf(data)
		if gear.Equipped[slot] == "" or gear.Equipped[slot] == nil then
			return
		end
		gear.Equipped[slot] = ""
		changed = true
	end)
	if changed then
		afterChange(player, true)
	end
	return changed
end

-- เปิดช่องถัดไป (ตามลำดับ SlotOrder) ด้วยเหรียญ SlotPrices[ช่องที่ n] · ทำได้ระหว่างบอส (ไม่เปลี่ยนค่าที่ใส่)
-- ตัวอย่าง: Slots 2 + เงิน 3,000 → เงิน 500 · Slots 3
function GearService.unlockSlot(player: Player): boolean
	local unlocked = false
	-- ⚠️ ระวัง: แตะเงินจริง · เช็กเงินพอก่อนหักเสมอ
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		local gear = gearOf(data)
		local price = GearMath.nextSlotPrice(gear.Slots)
		if not price then
			return -- เปิดครบแล้ว
		end
		local coins = coinsOf(data)
		if coins < price then
			return
		end
		data.Coins = coins - price
		gear.Slots = GearMath.clampSlots(gear.Slots) + 1
		unlocked = true
	end)
	if unlocked then
		afterChange(player, false)
	end
	return unlocked
end

-- ย่อย key จำนวน count ชิ้นเป็นเหรียญ · กฎ: count ≤ จำนวนที่มี − 1 ถ้าใส่อยู่ (ชิ้นที่ใส่ย่อยไม่ได้) · คืนเหรียญที่ได้
-- ตัวอย่าง: มี Barrel_Fire_Rare 3 ใส่อยู่ 1 → ย่อยได้สูงสุด 2 → +120 เหรียญ
function GearService.salvage(player: Player, key: string, count: number): number
	local gained = 0
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		local _, _, rarity = GearMath.parseKey(key)
		if not rarity or count % 1 ~= 0 or count < 1 then
			return
		end
		local gear = gearOf(data)
		if count > GearMath.freeCount(gear, key) then
			return
		end
		local left = (gear.Items[key] or 0) - count
		gear.Items[key] = if left > 0 then left else nil
		gained = GearMath.salvageValue(rarity) * count
		addCoins(data, gained)
	end)
	if gained > 0 then
		afterChange(player, false)
	end
	return gained
end

-- ย่อยทุกชิ้นระดับ rarity ที่ไม่ได้ใส่ · ไม่รับ Legendary (กันกดพลาด) · คืนเหรียญที่ได้
function GearService.salvageRarity(player: Player, rarity: string): number
	local gained = 0
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		if not GearMath.rarityIndex(rarity) or rarity == "Legendary" then
			return
		end
		local gear = gearOf(data)
		local value = GearMath.salvageValue(rarity)
		local keys = {}
		for key in gear.Items do
			local _, _, itemRarity = GearMath.parseKey(key)
			if itemRarity == rarity then
				table.insert(keys, key)
			end
		end
		for _, key in keys do
			local free = GearMath.freeCount(gear, key)
			if free > 0 then
				local left = gear.Items[key] - free
				gear.Items[key] = if left > 0 then left else nil
				gained += value * free
			end
		end
		if gained > 0 then
			addCoins(data, gained)
		end
	end)
	if gained > 0 then
		afterChange(player, false)
	end
	return gained
end

-- รวม 3 ชิ้น key (ที่ไม่ได้ใส่) → 1 ชิ้นแบบเดิมระดับถัดไป · เสียเหรียญ MergeCost · ผลต้องไม่เกิน StackCap
-- ตัวอย่าง: Barrel_Fire_Common ×3 + 30 เหรียญ → Barrel_Fire_Rare ×1 · เงินไม่พอ = ไม่เสียของ
function GearService.merge(player: Player, key: string): boolean
	local merged = false
	-- ⚠️ ระวัง: หักของ + หักเงิน + ให้ของ ต้องอยู่ใน update เดียว (ห้ามแยก)
	PlayerData.update(player, function(data)
		if not tutorialDone(player) then
			return -- ฝึกสอนยังไม่จบ
		end
		local slot, variant, rarity = GearMath.parseKey(key)
		if not slot or not variant or not rarity then
			return
		end
		local nextRarity = GearMath.nextRarity(rarity)
		local cost = GearMath.mergeCost(rarity)
		if not nextRarity or not cost then
			return -- Legendary รวมต่อไม่ได้
		end
		local gear = gearOf(data)
		if GearMath.freeCount(gear, key) < 3 then
			return
		end
		local resultKey = GearMath.keyOf(slot, variant, nextRarity)
		if (gear.Items[resultKey] or 0) + 1 > Equipment.StackCap then
			return
		end
		local coins = coinsOf(data)
		if coins < cost then
			return
		end
		data.Coins = coins - cost
		local left = gear.Items[key] - 3
		gear.Items[key] = if left > 0 then left else nil
		gear.Items[resultKey] = (gear.Items[resultKey] or 0) + 1
		merged = true
	end)
	if merged then
		afterChange(player, false)
	end
	return merged
end

-- บอสจากไป: ให้อุปกรณ์ผู้เล่น 1 คน (BossService.finish เรียก · แทนตั๋วกาชาเดิม)
--   rank = อันดับดาเมจ (1 = สูงสุด) · share = ดาเมจตัวเอง ÷ ดาเมจรวม (ต้อง > 0)
-- ขั้นตอนต่อ roll (สเปกหัวข้อ 4): ตาราง (GearMath.rollTables) → ระดับ (pickRarity) → pity (applyPity)
--   → ช่อง 1 ใน 4 เท่ากัน (รวมช่องที่ยังล็อก) → แบบ (ธาตุตัวเอง ×2) → เข้ากระเป๋า · กระเป๋า/กองเต็ม = ย่อยเป็นเหรียญแทน
-- ตัวอย่าง: อันดับ 1 share 12% → 3 rolls (B, B, Top)
function GearService.grantBossDrops(player: Player, rank: number, share: number)
	if not player.Parent or share ~= share or share <= 0 then
		return
	end
	local tables = GearMath.rollTables(share, rank)
	local results = {}
	PlayerData.update(player, function(data)
		local gear = gearOf(data)
		local weights = GearMath.variantWeights(elementOf(data))
		local total = GearMath.countAll(gear.Items)
		for _, name in tables do
			local rarity = GearMath.pickRarity(name, rng:NextNumber())
			rarity, gear.Pity = GearMath.applyPity(rarity, gear.Pity)
			local slot = Equipment.SlotOrder[rng:NextInteger(1, #Equipment.SlotOrder)]
			local variant = GearMath.pickWeighted(weights, rng:NextNumber())
			local key = GearMath.keyOf(slot, variant, rarity)
			local have = gear.Items[key] or 0
			local entry: { [string]: any } = { Key = key, New = false }
			if name == "Top" then
				entry.Top = true
			end
			if total >= Equipment.InventoryCap or have >= Equipment.StackCap then
				-- กระเป๋าเต็ม → ย่อยอัตโนมัติ (ไม่มีของหาย)
				local value = GearMath.salvageValue(rarity)
				addCoins(data, value)
				entry.Salvaged = value
			else
				gear.Items[key] = have + 1
				entry.New = have == 0
				total += 1
			end
			table.insert(results, entry)
		end
	end)
	if #results == 0 then
		return
	end
	afterChange(player, false)
	if dropsRemote then
		dropsRemote:FireClient(player, results)
	end
end

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูก Remote แสดงผลดรอป · ฟังข้อมูลโหลด/ธาตุเปลี่ยน · ล้างสถานะตอนออก
function GearService.Init()
	dropsRemote = Remotes.get("GearDrops") :: RemoteEvent
	PlayerData.Changed:Connect(onDataChanged)
	-- ผู้เล่นที่ข้อมูลโหลดเสร็จก่อน service นี้เริ่มฟัง
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			onDataChanged(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		bonusCache[player] = nil
		mirrored[player] = nil
		lastElement[player] = nil
	end)
end

return GearService
