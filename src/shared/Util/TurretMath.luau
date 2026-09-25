-- สูตรค่าสถานะ/ราคาป้อม (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผลเท่านั้น

local Combat = require(script.Parent.Parent.Config.Combat)
local Economy = require(script.Parent.Parent.Config.Economy)

local TurretMath = {}

-- ค่าเลเวลจากข้อมูลบันทึกห้ามเชื่อตรงๆ → บังคับเป็นจำนวนเต็มในช่วงที่ถูกต้อง
function TurretMath.clampLevel(level: any): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	return math.clamp(math.floor(level), 1, Combat.Turret.MaxLevel)
end

function TurretMath.damage(level: number): number
	return Combat.Turret.BaseDamage + Combat.Turret.DamagePerLevel * (level - 1)
end

function TurretMath.fireRate(level: number): number
	return Combat.Turret.BaseFireRate + Combat.Turret.FireRatePerLevel * (level - 1)
end

-- ราคาอัปจาก level → level + 1
function TurretMath.upgradeCost(level: number): number
	return math.floor(Economy.Turret.UpgradeBaseCost * Economy.Turret.UpgradeCostGrowth ^ (level - 1))
end

return TurretMath
