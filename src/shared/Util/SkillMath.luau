-- สูตรสกิลและโอกาสกาชา (ฟังก์ชันบริสุทธิ์) — Server ใช้คำนวณจริง · Client ใช้แสดงผลเท่านั้น
-- ตัวเลขทั้งหมดอยู่ที่ Config/Skills.luau · แก้ไฟล์นี้เมื่ออยากเปลี่ยน "สูตร" เช่น เลเวลเพิ่มพลังแบบไหน
-- ใครใช้: Server = Services/SkillService, TurretService · Client = UI/GachaUI

local Skills = require(script.Parent.Parent.Config.Skills)

local SkillMath = {}

-- บังคับเลเวลสกิลให้อยู่ในช่วง 1..MaxLevel (ค่าเสีย/ไม่ใช่ตัวเลข → 1)
function SkillMath.clampLevel(level: any): number
	if type(level) ~= "number" or level ~= level then
		return 1
	end
	return math.clamp(math.floor(level), 1, Skills.MaxLevel)
end

-- ตัวคูณของสกิลที่เลเวลนี้ (base = ค่าใน Config, nil = ไม่มีผลนี้ → 1)
function SkillMath.multiplier(base: number?, level: number): number
	if not base then
		return 1
	end
	return 1 + (base - 1) * (1 + Skills.PowerPerLevel * (level - 1))
end

-- ตัวคูณนัดใหญ่ (Burst) ที่เลเวลนี้ · nil = สกิลนี้ไม่มี Burst → 0
function SkillMath.burst(base: number?, level: number): number
	if not base then
		return 0
	end
	return base * (1 + Skills.PowerPerLevel * (level - 1))
end

-- สกิลซ้ำที่ต้องใช้อัปจาก level → level + 1 (nil = เลเวลสูงสุดแล้ว)
function SkillMath.copiesToUpgrade(level: number): number?
	return Skills.CopiesToUpgrade[level]
end

-- โอกาสได้แต่ละสกิล (0–1) · ระดับที่ไม่มีสกิลเลยไม่ถูกนับ
function SkillMath.odds(): { [string]: number }
	local countByRarity: { [string]: number } = {}
	for _, id in Skills.Order do
		local rarity = Skills.List[id].Rarity
		countByRarity[rarity] = (countByRarity[rarity] or 0) + 1
	end
	local totalWeight = 0
	for _, rarity in Skills.Rarities do
		if countByRarity[rarity.Id] then
			totalWeight += rarity.Weight
		end
	end
	local result = {}
	for _, id in Skills.Order do
		local rarityId = Skills.List[id].Rarity
		for _, rarity in Skills.Rarities do
			if rarity.Id == rarityId then
				result[id] = rarity.Weight / totalWeight / countByRarity[rarityId]
			end
		end
	end
	return result
end

-- ข้อมูลระดับความหายาก (แถวใน Config.Rarities) ของสกิล id · ไม่เจอ → แถวแรก
function SkillMath.rarity(id: string): any
	local skill = Skills.List[id]
	for _, rarity in Skills.Rarities do
		if skill and rarity.Id == skill.Rarity then
			return rarity
		end
	end
	return Skills.Rarities[1]
end

return SkillMath
