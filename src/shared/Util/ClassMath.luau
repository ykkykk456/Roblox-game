-- สูตรคลาสป้อม/สายธาตุ (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผล/เปิดปิดปุ่มเท่านั้น
-- ค่าทั้งหมดอยู่ที่ Config/Skill_class_default.luau · สเปก: design/turret-classes.md
-- อยากปรับตัวเลขคลาส/สาย → แก้ Config ไม่ต้องแก้ไฟล์นี้ · แก้ไฟล์นี้เมื่อต้องการเปลี่ยน "กฎ" (เช่น เงื่อนไขเลือกสาย)
-- ใครใช้: Server = Services/TurretService, TurretClassService, TurretLook · Client = UI/CombatUI
-- ⚠️ Client ใช้แค่แสดงผล · Server ต้องเช็กซ้ำเองทุกครั้งที่ผู้เล่นขอเลือกคลาส/สาย
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์นี้ "ไม่ทำอะไรเอง" มีแต่ฟังก์ชันรับค่า → คืนคำตอบ ไม่แก้ข้อมูลใดๆ = "ฟังก์ชันบริสุทธิ์")
--   1) isClass / isBranch  — ตรวจว่าชื่อที่ได้มามีอยู่ใน Config จริงไหม (ด่านแรกของทุกฟังก์ชัน)
--   2) branchOf / validBranch — สายที่ "ใช้ได้จริง" = มีใน Config และเป็นของคลาสนี้
--   3) stats — หัวใจของไฟล์: รวมคลาส + สาย + เลเวล → ได้ตัวคูณดาเมจ/อัตรายิง/เอฟเฟกต์/สี
--        ถูกเรียกจาก TurretService:statsOf (ตอนยิงทุกนัด) และ TurretLook:build / keyOf (ตอนสร้างหน้าตาป้อม)
--   4) fireTier / fireColor — สีบอลไฟของสายไฟตามเลเวล (stats เรียกใช้เมื่อเป็นสายไฟ)
--   5) canChooseClass / canChooseBranch — กฎ "เลือกได้ไหม"
--        ถูกเรียกจาก TurretClassService:choose / chooseBranch (ตัดสินจริงที่ Server) และ UI ฝั่ง Client (แค่เปิด/ปิดปุ่ม)

-- require = โหลดโมดูลอื่นมาใช้ · script.Parent.Parent = ขึ้นไป 2 ชั้น (Util → Shared) แล้วเข้า Config
-- local = ตัวแปรที่ใช้ได้เฉพาะในไฟล์นี้ (ไฟล์อื่นมองไม่เห็น)
local ClassConfig = require(script.Parent.Parent.Config.Skill_class_default)

-- รูปแบบค่าที่ ClassMath.stats คืนให้
-- export type = ประกาศ "หน้าตาของตาราง" ให้ไฟล์อื่นใช้เป็นชื่อชนิดได้ (เช่น ClassMath.Stats) · แค่ช่วยตัวตรวจโค้ด ไม่มีผลตอนเกมรัน
-- `: number` = บอกว่าช่องนี้เป็นตัวเลข · `any?` = อะไรก็ได้ หรือ nil (เครื่องหมาย ? แปลว่า "อาจไม่มี")
export type Stats = {
	Damage: number, -- ตัวคูณดาเมจต่อนัด (คูณกับ TurretMath.damage)
	FireRate: number, -- ตัวคูณอัตรายิง (คูณกับ TurretMath.fireRate)
	Fx: string,
	Color: Color3,
	Effect: any?, -- ความสามารถพิเศษของสาย (ตาราง Effect ใน Config) · nil = ไม่มี
}

-- ตารางว่างที่เราจะเติมฟังก์ชันลงไป แล้ว return ท้ายไฟล์ (ไฟล์อื่น require แล้วได้ตารางนี้)
local ClassMath = {}

-- ===== ตรวจชื่อ =====
-- true ถ้า id เป็นชื่อคลาสที่มีใน Config (เช่น "Mage")
function ClassMath.isClass(id: any): boolean
	-- type(id) == "string" กันค่าแปลกๆ (ตัวเลข/nil/ตาราง) ก่อน แล้วค่อยเปิดหาใน Classes
	-- `and` ในลูอาจะหยุดทันทีถ้าข้างซ้ายเป็น false (ไม่ไปแตะ Classes[id] เลย)
	-- `~= nil` = "ไม่ใช่ nil" = หาเจอ
	return type(id) == "string" and ClassConfig.Classes[id] ~= nil
end

-- true ถ้า id เป็นชื่อสายธาตุที่มีใน Config (เช่น "Fire")
function ClassMath.isBranch(id: any): boolean
	return type(id) == "string" and ClassConfig.Branches[id] ~= nil
end

-- ===== สีบอลไฟ (สายไฟ) =====
-- ลำดับขั้นสีไฟ (index ใน FireColors) ของเลเวลนี้ · ต่ำกว่าแถวแรก = 1
function ClassMath.fireTier(level: number): number
	-- เริ่มที่ขั้น 1 ไว้ก่อน แล้ววนดูทุกแถว: เลเวลถึงแถวไหน ก็จำเลขแถวนั้นไว้ (แถวหลังทับแถวก่อน)
	-- `for index, row in ตาราง do` = วนทีละช่อง · index = ลำดับ 1,2,3... · row = ค่าในช่องนั้น
	-- ตัวอย่าง: FireColors มี Level 10/20/30/40/50 · ป้อม Lv.27 → ผ่านแถว 1 (10) และ 2 (20) → tier = 2 (สีแดง)
	local tier = 1
	for index, row in ClassConfig.FireColors do
		if level >= row.Level then
			tier = index
		end
	end
	return tier
end

-- สีบอลไฟของสายไฟ: แถวสุดท้ายที่ Level ≤ เลเวลป้อม
function ClassMath.fireColor(level: number): Color3
	local row = ClassConfig.FireColors[ClassMath.fireTier(level)]
	-- `if เงื่อนไข then A else B` แบบนี้เป็น "นิพจน์" = เลือกค่า A หรือ B มาใช้ทันที (เหมือน ? : ในภาษาอื่น)
	-- เผื่อ FireColors ว่าง (row = nil) → ใช้สีของสายไฟใน Branches แทน กันเกม error
	return if row then row.Color else ClassConfig.Branches.Fire.Color
end

-- ===== สายธาตุ + ค่าสถานะ =====
-- สายที่ใช้ได้จริง: ต้องมีใน Config และเป็นของคลาสนี้ (ข้อมูลเสีย/ไม่ตรงคลาส → ถือว่ายังไม่มีสาย)
-- `local function` = ฟังก์ชันใช้ภายในไฟล์นี้เท่านั้น (ไม่อยู่ในตาราง ClassMath)
local function branchOf(classId: string, branchId: any): any?
	if type(branchId) ~= "string" then
		return nil
	end
	-- หาสายใน Config แล้วเช็กว่า "เจ้าของสาย" (branch.Class) ตรงกับคลาสของป้อมไหม
	-- เช่น คลาส Mage ขอสาย "Fire" → Fire.Class = "Cannon" ไม่ตรง → nil (ใช้ไม่ได้)
	local branch = ClassConfig.Branches[branchId]
	if branch and branch.Class == classId then
		return branch
	end
	return nil
end

-- สายที่ใช้ได้จริงของคลาสนี้ ("" = ไม่มี) · ใช้เลือกหน้าตาป้อม/เอฟเฟกต์
function ClassMath.validBranch(classId: any, branchId: any): string
	if ClassMath.isClass(classId) and branchOf(classId, branchId) then
		return branchId
	end
	return ""
end

-- สถิติรวมของป้อม: ไม่รู้จักคลาส/"" → Unchosen · มีสาย → ค่าของสายแทนค่าคลาส
-- ลำดับการตัดสิน 3 ทาง: (ก) ยังไม่มีคลาส → Unchosen  (ข) มีคลาสแต่ไม่มีสาย → ค่าคลาส  (ค) มีสาย → ค่าสาย
-- หมายเหตุ: ค่าสาย "แทนที่" ค่าคลาส ไม่ได้คูณกัน
--   ตัวอย่าง: นักเวท Damage 1.2 · เลือกสายฟ้า Damage 1.3 → ใช้ 1.3 (ไม่ใช่ 1.2 × 1.3)
function ClassMath.stats(classId: any, branchId: any, turretLevel: number): Stats
	-- (ก) ยังไม่เลือกคลาส / ชื่อคลาสเสีย → ค่าป้อมเริ่มต้น Unchosen (ตัวคูณ 1 = แรงเท่าป้อมพื้นฐาน)
	if not ClassMath.isClass(classId) then
		local u = ClassConfig.Unchosen
		-- สร้างตารางใหม่คืนไป (ไม่คืน Config ตรงๆ เพราะ Config ถูก table.freeze แก้ไม่ได้ และรูปร่างต้องตรง Stats)
		return { Damage = u.Damage, FireRate = u.FireRate, Fx = u.Fx, Color = u.Color }
	end
	local class = ClassConfig.Classes[classId]
	local branch = branchOf(classId, branchId)
	-- (ข) มีคลาสแต่ยังไม่มีสาย (หรือสายไม่ตรงคลาส) → ใช้ค่าของคลาส · ไม่มี Effect พิเศษ
	if not branch then
		return { Damage = class.Damage, FireRate = class.FireRate, Fx = class.Fx, Color = class.Color }
	end
	-- (ค) มีสายที่ถูกต้อง → ใช้ค่าของสาย + ติด Effect ไปด้วย (TurretService อ่าน Effect.Kind แล้วทำพลังพิเศษ)
	local effect = branch.Effect
	-- สายไฟ (Effect.Kind = "FireColor") สีเปลี่ยนตามเลเวล · สายอื่นใช้สีคงที่จาก Config
	-- ตัวอย่าง: สายไฟ Lv.35 → fireColor(35) = แถว Level 30 = สีม่วง
	local color = if effect and effect.Kind == "FireColor" then ClassMath.fireColor(turretLevel) else branch.Color
	return { Damage = branch.Damage, FireRate = branch.FireRate, Fx = branch.Fx, Color = color, Effect = effect }
end

-- ===== กฎการเลือก =====
-- เปลี่ยนคลาสได้ฟรีตราบใดที่ยังไม่มีสายที่ถูกต้องของคลาสตัวเอง [Proposed]
-- (สายเสีย/ไม่ตรงคลาส = ไม่ล็อก ผู้เล่นไม่ติดค้าง)
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนกฎ "เลือกสายแล้วล็อกคลาส" (เช่น ให้เปลี่ยนคลาสได้ตลอด → return true)
--    ⚠️ ระวัง: ฟังก์ชันนี้คือกฎที่ Server ใช้ตัดสินจริง (TurretClassService.choose) แก้แล้วมีผลกับข้อมูลผู้เล่นที่บันทึก
function ClassMath.canChooseClass(classId: any, currentBranch: any): boolean
	-- ยังไม่มีสายที่ใช้ได้ ("") = ยังไม่ล็อก = เปลี่ยนคลาสได้
	return ClassMath.validBranch(classId, currentBranch) == ""
end

-- เลือกสายได้เมื่อ: มีคลาสแล้ว · ยังไม่มีสาย · สายนี้เป็นของคลาสตัวเอง · เลเวลถึง BranchLevel
-- ⚠️ ระวัง: เงื่อนไขทั้ง 4 ข้อนี้คือด่านกันโกงของการเลือกสาย (Server เรียกใน TurretClassService.chooseBranch) ห้ามลบข้อใดทิ้ง
function ClassMath.canChooseBranch(classId: any, currentBranch: any, branchId: any, level: number): boolean
	-- ข้อ 1+2: ต้องมีคลาสจริง และยังไม่ได้เลือกสายมาก่อน (เลือกได้ครั้งเดียว)
	if not ClassMath.isClass(classId) or not ClassMath.canChooseClass(classId, currentBranch) then
		return false
	end
	-- ข้อ 3: สายที่ขอต้องเป็นของคลาสตัวเอง (นักเวทขอ "Gatling" ไม่ได้)
	if not branchOf(classId, branchId) then
		return false
	end
	-- ข้อ 4: เลเวลต้องถึง BranchLevel (ตอนนี้ = 10) · ตัวอย่าง: Lv.9 → false · Lv.10 → true
	return type(level) == "number" and level >= ClassConfig.BranchLevel
end

return ClassMath
