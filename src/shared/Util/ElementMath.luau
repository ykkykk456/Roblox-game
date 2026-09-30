-- สูตรธาตุป้อม (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผล/เปิดปิดปุ่มเท่านั้น
-- ค่าทั้งหมดอยู่ที่ Config/Elements.luau · สเปก: design/element-skills.md (แทน Util/ClassMath เดิม)
-- อยากปรับตัวเลขธาตุ → แก้ Config ไม่ต้องแก้ไฟล์นี้ · แก้ไฟล์นี้เมื่อต้องการเปลี่ยน "กฎ" (เช่น เงื่อนไขเปลี่ยนธาตุ)
-- ใครใช้: Server = Services/TurretService, TurretElementService, ElementSkillService, TurretLook, Network/ElementHandler
--   Client = UI/CombatUI, UI/ElementUI
-- ⚠️ Client ใช้แค่แสดงผล · Server ต้องเช็กซ้ำเองทุกครั้งที่ผู้เล่นขอเลือกธาตุ
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์นี้ "ไม่ทำอะไรเอง" มีแต่ฟังก์ชันรับค่า → คืนคำตอบ ไม่แก้ข้อมูลใดๆ)
--   1) isElement — ตรวจว่า id เป็นธาตุที่มีใน Config จริงไหม (ด่านแรกของทุกฟังก์ชัน)
--   2) stats — หัวใจของไฟล์: ธาตุ + เลเวล → ตัวคูณ/กระสุน/Passive/สกิล/สี
--        ถูกเรียกจาก TurretService (ทุกรอบยิง) · TurretLook (ปั้นหน้าตา) · CombatUI/ElementUI (แสดงผล)
--   3) skillScale / skillTravel — ตัวคูณดาเมจสกิลตามเลเวล · เวลาบินของกระสุนสกิล
--   4) fireTier / fireColor — สีบอลไฟตามเลเวล (ธาตุที่ UseFireColors)
--   5) lookTier / lookKey — ขั้นหน้าตาป้อม (อัปทุก 10 เลเวล) · คีย์บอกว่าต้องปั้นป้อมใหม่ไหม
--   6) canChooseElement — กฎ "เลือก/เปลี่ยนธาตุได้ไหม" (Server ตัดสินจริงใน TurretElementService)

local Combat = require(script.Parent.Parent.Config.Combat)
local Elements = require(script.Parent.Parent.Config.Elements)
local TurretMath = require(script.Parent.TurretMath)

-- รูปแบบค่าที่ stats คืนให้ · export type = ไฟล์อื่นใช้ชื่อ ElementMath.Stats ได้ (ช่วยตัวตรวจโค้ดเท่านั้น)
export type Stats = {
	Id: string, -- ธาตุที่ใช้อยู่จริง ("" = ยังไม่เลือก)
	Name: string,
	Damage: number, -- ตัวคูณดาเมจการยิงปกติ
	FireRate: number, -- ตัวคูณอัตรายิง
	Fx: string, -- ชนิดภาพกระสุนปกติ
	Color: Color3, -- สีกระสุน/สีหลักของป้อม
	Shot: any, -- ตาราง Shot ใน Config (ว่าง = ไม่มีผลพิเศษ)
	Passive: any?, -- ตาราง Passive ใน Config หรือ nil
	Skill: any?, -- ตาราง Skill ใน Config หรือ nil (ยังไม่เลือกธาตุ = ไม่มีสกิล)
}

local EMPTY = table.freeze({})

local ElementMath = {}

-- ===== ตรวจชื่อ =====
-- true ถ้า id เป็นธาตุใน Config เช่น "Fire" · type(id) == "string" กันค่าแปลกๆ ก่อนเปิดหา
function ElementMath.isElement(id: any): boolean
	return type(id) == "string" and Elements.Elements[id] ~= nil
end

-- ตาราง Config ของธาตุ (ยังไม่เลือก/ข้อมูลเสีย = nil)
function ElementMath.defOf(element: any): any?
	return if ElementMath.isElement(element) then Elements.Elements[element] else nil
end

-- ===== สีไฟ =====
-- ขั้นสีไฟ (index ใน FireColors) ของเลเวลนี้ · ต่ำกว่าแถวแรก = 1 · ตัวอย่าง: Lv.27 → 2 (แดง)
function ElementMath.fireTier(level: number): number
	local tier = 1
	for index, row in Elements.FireColors do
		if level >= row.Level then
			tier = index
		end
	end
	return tier
end

-- สีบอลไฟตามเลเวล
function ElementMath.fireColor(level: number): Color3
	local row = Elements.FireColors[ElementMath.fireTier(level)]
	return if row then row.Color else Elements.Elements.Fire.Color
end

-- ===== ค่าสถานะรวม =====
-- ยังไม่เลือก/ข้อมูลเสีย → Unchosen (ตัวคูณ 1 · ไม่มีสกิล) · มีธาตุ → ค่าของธาตุ (ไฟ: สีตามเลเวล)
-- ตัวอย่าง: ("Fire", 12) → Damage 1.4 · FireRate 0.7 · Fx "Fireball" · สีส้ม (FireColors ขั้น 1)
function ElementMath.stats(element: any, level: number): Stats
	local def = ElementMath.defOf(element)
	if not def then
		local u = Elements.Unchosen
		return {
			Id = "",
			Name = "ยังไม่เลือกธาตุ",
			Damage = u.Damage,
			FireRate = u.FireRate,
			Fx = u.Fx,
			Color = u.Color,
			Shot = EMPTY,
			Passive = nil,
			Skill = nil,
		}
	end
	return {
		Id = element,
		Name = def.Name,
		Damage = def.Damage,
		FireRate = def.FireRate,
		Fx = def.Shot.Fx,
		Color = if def.UseFireColors then ElementMath.fireColor(level) else def.Color,
		Shot = def.Shot,
		Passive = def.Passive,
		Skill = def.Skill,
	}
end

-- ===== สกิล =====
-- ตัวคูณดาเมจสกิลตามเลเวล (คูณกับ Pattern.Damage × D) = อัตรายิงตามเลเวล ÷ BaseFireRate (ถ้า ScaleWithFireRate)
-- เหตุผล: อัตรายิงโต 1 → 5.9 นัด/วิ (Lv.1 → 50) ถ้าไม่คูณ สกิลจะไร้ค่าตอนเลเวลสูง [Inferred: จาก Combat.Turret]
-- ตัวอย่าง: Lv.1 → 1 · Lv.11 → 2.0 · Lv.50 → 5.9
function ElementMath.skillScale(skill: any, level: number): number
	if skill and skill.ScaleWithFireRate then
		return TurretMath.fireRate(level) / math.max(Combat.Turret.BaseFireRate, 0.001)
	end
	return 1
end

-- เวลาเดินทางของกระสุนสกิล (วินาที): ใช้ Pattern.TravelTime ถ้ามี · ไม่งั้น ระยะ ÷ Pattern.Speed
-- บีบในช่วง Projectile.MinTravel..SkillMaxTravel · Server ส่งค่านี้ไปใน TurretFx.Travel ให้ Client วาดตรงจังหวะดาเมจ
-- ตัวอย่าง: ลูกไฟ Speed 90 ระยะ 120 → 1.33 วิ · ระยะ 400 → 4.4 แต่เพดาน 2 → 2 วิ
function ElementMath.skillTravel(pattern: any, distance: number): number
	if type(pattern.TravelTime) == "number" then
		return pattern.TravelTime
	end
	local speed = if type(pattern.Speed) == "number" and pattern.Speed > 0 then pattern.Speed else 100
	local minimum = Combat.Turret.Projectile.MinTravel
	return math.clamp(distance / speed, minimum, math.max(Elements.SkillMaxTravel, minimum))
end

-- ===== หน้าตาป้อมตามเลเวล =====
-- ขั้นหน้าตา: (ลำดับขั้น 1..6, เลเวลของขั้น) · ตัวอย่าง: Lv.27 → (3, 20) · Lv.50 → (6, 50) · Lv.1 → (1, 1)
function ElementMath.lookTier(level: number): (number, number)
	local index, tierLevel = 1, Elements.LookTiers[1] or 1
	for i, value in Elements.LookTiers do
		if level >= value then
			index, tierLevel = i, value
		end
	end
	return index, tierLevel
end

-- คีย์หน้าตาป้อม: "ธาตุ|ขั้นหน้าตา|ขั้นสีไฟ" · เปลี่ยน = TurretService ปั้นป้อมใหม่
-- ⚠️ ถ้าเพิ่มสิ่งที่ทำให้หน้าตาเปลี่ยน ต้องใส่ลงคีย์นี้ด้วย ไม่งั้นป้อมไม่ถูกปั้นใหม่
function ElementMath.lookKey(element: any, level: number): string
	local def = ElementMath.defOf(element)
	local id = if def then element else ""
	local tier = ElementMath.lookTier(level)
	local fire = if def and def.UseFireColors then ElementMath.fireTier(level) else 0
	return `{id}|{tier}|{fire}`
end

-- ===== กฎการเลือก =====
-- เลือก/เปลี่ยนธาตุได้ไหม · คืน (ได้ไหม, ราคาเงิน)
--   ยังไม่มีธาตุ → ฟรี · มีธาตุแล้ว = "เปลี่ยน" → ราคา ChangeElementCost + ห้ามระหว่างบอสอยู่ · เลือกธาตุเดิมซ้ำ = ไม่ได้
-- ⚠️ ระวัง: Server ใช้ฟังก์ชันนี้ตัดสินจริง (TurretElementService.choose) · ส่วนเช็กเงินพอไหมทำใน PlayerData.update
function ElementMath.canChooseElement(current: any, id: any, bossActive: boolean): (boolean, number)
	if not ElementMath.isElement(id) or current == id then
		return false, 0
	end
	if not ElementMath.isElement(current) then
		return true, 0 -- ครั้งแรก (หรือข้อมูลเก่าเสีย) = ฟรี
	end
	if bossActive then
		return false, Elements.ChangeElementCost -- กันสลับหาของดีกลางไฟต์บอส
	end
	return true, Elements.ChangeElementCost
end

return ElementMath
