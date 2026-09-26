-- คำนวณตำแหน่งบนแมพหลุมอุกกาบาตจาก Config/Map (ใช้ได้ทั้ง Server และ Client)
-- พิกัดท้องถิ่นของฐาน: u = ระยะจากกลางแมพ · v = ระยะไปทางขวาเมื่อยืนหันหลังให้หลุม

local Map = require(script.Parent.Parent.Config.Map)

local MapMath = {}

-- มุมของช่องฐาน (เรเดียน) · ฐาน 1 ชี้ทิศเหนือ (−Z)
function MapMath.angle(slot: number): number
	return -math.pi / 2 + (slot - 1) * 2 * math.pi / Map.MaxBases
end

-- ทิศออกจากกลางแมพ และทิศขวาของฐาน
function MapMath.axes(slot: number): (Vector3, Vector3)
	local angle = MapMath.angle(slot)
	return Vector3.new(math.cos(angle), 0, math.sin(angle)), Vector3.new(-math.sin(angle), 0, math.cos(angle))
end

function MapMath.point(slot: number, u: number, v: number, y: number?): Vector3
	local out, right = MapMath.axes(slot)
	return out * u + right * v + Vector3.new(0, y or 0, 0)
end

function MapMath.polar(angle: number, radius: number, y: number?): Vector3
	return Vector3.new(math.cos(angle) * radius, y or 0, math.sin(angle) * radius)
end

return MapMath
