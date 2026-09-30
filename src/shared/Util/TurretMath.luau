-- สูตรค่าสถานะ/ราคาป้อม (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผลเท่านั้น
-- ตัวเลขอยู่ที่ Config/Combat.Turret (ดาเมจ/อัตรายิง) และ Config/Economy.Turret (ราคา) · ไฟล์นี้เก็บแค่สูตร
-- ใครใช้: Server = Services/TurretService, TurretElementService · Util/ElementMath · Client = UI/CombatUI, Controllers/TurretController (travelTime)

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

-- ดาเมจต่อนัดของป้อมเลเวลนี้ (ยังไม่คูณตัวคูณธาตุ)
function TurretMath.damage(level: number): number
	return Combat.Turret.BaseDamage + Combat.Turret.DamagePerLevel * (level - 1)
end

-- อัตรายิงของป้อมเลเวลนี้ (นัดต่อวินาที · ยังไม่คูณตัวคูณธาตุ/บัฟ)
function TurretMath.fireRate(level: number): number
	return Combat.Turret.BaseFireRate + Combat.Turret.FireRatePerLevel * (level - 1)
end

-- ราคาอัปจาก level → level + 1
function TurretMath.upgradeCost(level: number): number
	return math.floor(Economy.Turret.UpgradeBaseCost * Economy.Turret.UpgradeCostGrowth ^ (level - 1))
end

-- เวลาเดินทางของกระสุนชนิด kind ระยะ distance studs (วินาที) · 0 = โดนทันที (Combat.Turret.Projectile.Instant)
-- Server ใช้ตั้งเวลาทำดาเมจตอนกระสุนถึง · Client ใช้วาดกระสุนให้ถึงเป้าพร้อมกัน → ต้องใช้สูตรนี้ที่เดียว ห้ามแยกสูตร
-- ตัวอย่าง: Shell ระยะ 60 → 60 ÷ 120 = 0.5 วิ · ระยะ 200 → 1.67 วิ แต่เพดาน MaxTravel 0.6 → 0.6 วิ
function TurretMath.travelTime(kind: string, distance: number): number
	local config = Combat.Turret.Projectile
	if config.Instant[kind] then
		return 0
	end
	local speed = config.Speeds[kind] or config.Speed
	local minimum = config.MinTravelBy[kind] or config.MinTravel
	return math.clamp(distance / speed, minimum, math.max(config.MaxTravel, minimum))
end

return TurretMath
