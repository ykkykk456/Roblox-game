-- สูตรคลาสป้อม/สายธาตุ (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผล/เปิดปิดปุ่มเท่านั้น
-- ค่าทั้งหมดอยู่ที่ Config/Skill_class_default.luau · สเปก: design/turret-classes.md
-- อยากปรับตัวเลขคลาส/สาย → แก้ Config ไม่ต้องแก้ไฟล์นี้ · แก้ไฟล์นี้เมื่อต้องการเปลี่ยน "กฎ" (เช่น เงื่อนไขเลือกสาย)
-- ใครใช้: Server = Services/TurretService, TurretClassService, TurretLook · Client = UI/CombatUI
-- ⚠️ Client ใช้แค่แสดงผล · Server ต้องเช็กซ้ำเองทุกครั้งที่ผู้เล่นขอเลือกคลาส/สาย

local ClassConfig = require(script.Parent.Parent.Config.Skill_class_default)

-- รูปแบบค่าที่ ClassMath.stats คืนให้
export type Stats = {
	Damage: number, -- ตัวคูณดาเมจต่อนัด (คูณกับ TurretMath.damage)
	FireRate: number, -- ตัวคูณอัตรายิง (คูณกับ TurretMath.fireRate)
	Fx: string,
	Color: Color3,
	Effect: any?, -- ความสามารถพิเศษของสาย (ตาราง Effect ใน Config) · nil = ไม่มี
}

local ClassMath = {}

-- ===== ตรวจชื่อ =====
-- true ถ้า id เป็นชื่อคลาสที่มีใน Config (เช่น "Mage")
function ClassMath.isClass(id: any): boolean
	return type(id) == "string" and ClassConfig.Classes[id] ~= nil
end

-- true ถ้า id เป็นชื่อสายธาตุที่มีใน Config (เช่น "Fire")
function ClassMath.isBranch(id: any): boolean
	return type(id) == "string" and ClassConfig.Branches[id] ~= nil
end

-- ===== สีบอลไฟ (สายไฟ) =====
-- ลำดับขั้นสีไฟ (index ใน FireColors) ของเลเวลนี้ · ต่ำกว่าแถวแรก = 1
function ClassMath.fireTier(level: number): number
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
	return if row then row.Color else ClassConfig.Branches.Fire.Color
end

-- ===== สายธาตุ + ค่าสถานะ =====
-- สายที่ใช้ได้จริง: ต้องมีใน Config และเป็นของคลาสนี้ (ข้อมูลเสีย/ไม่ตรงคลาส → ถือว่ายังไม่มีสาย)
local function branchOf(classId: string, branchId: any): any?
	if type(branchId) ~= "string" then
		return nil
	end
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
function ClassMath.stats(classId: any, branchId: any, turretLevel: number): Stats
	if not ClassMath.isClass(classId) then
		local u = ClassConfig.Unchosen
		return { Damage = u.Damage, FireRate = u.FireRate, Fx = u.Fx, Color = u.Color }
	end
	local class = ClassConfig.Classes[classId]
	local branch = branchOf(classId, branchId)
	if not branch then
		return { Damage = class.Damage, FireRate = class.FireRate, Fx = class.Fx, Color = class.Color }
	end
	local effect = branch.Effect
	local color = if effect and effect.Kind == "FireColor" then ClassMath.fireColor(turretLevel) else branch.Color
	return { Damage = branch.Damage, FireRate = branch.FireRate, Fx = branch.Fx, Color = color, Effect = effect }
end

-- ===== กฎการเลือก =====
-- เปลี่ยนคลาสได้ฟรีตราบใดที่ยังไม่มีสายที่ถูกต้องของคลาสตัวเอง [Proposed]
-- (สายเสีย/ไม่ตรงคลาส = ไม่ล็อก ผู้เล่นไม่ติดค้าง)
function ClassMath.canChooseClass(classId: any, currentBranch: any): boolean
	return ClassMath.validBranch(classId, currentBranch) == ""
end

-- เลือกสายได้เมื่อ: มีคลาสแล้ว · ยังไม่มีสาย · สายนี้เป็นของคลาสตัวเอง · เลเวลถึง BranchLevel
function ClassMath.canChooseBranch(classId: any, currentBranch: any, branchId: any, level: number): boolean
	if not ClassMath.isClass(classId) or not ClassMath.canChooseClass(classId, currentBranch) then
		return false
	end
	if not branchOf(classId, branchId) then
		return false
	end
	return type(level) == "number" and level >= ClassConfig.BranchLevel
end

return ClassMath
