-- รับคำขอกาชา/สกิลจาก Client (เจ้าของ: Networking_Specialist)
-- ตรวจที่นี่: ชนิด + rate (Guard) · จำนวนสุ่มต้องอยู่ใน RollSizes · skillId ต้องมีจริงใน Config
-- ตรวจใน SkillService: ตั๋วพอไหม · มีสกิลนี้ไหม · สกิลซ้ำพอไหม
--
-- อยากปรับ:
--   • สุ่มได้ครั้งละกี่ใบ (เช่น เพิ่ม x5) → src/shared/Config/Economy.luau (Gacha.RollSizes)
--   • รายชื่อสกิล/อัตราออก → src/shared/Config/Skills.luau (List / Rarities)
-- คุยกับ: Guard · Services/SkillService (ทำงานจริง) · Remotes
-- ห้ามแก้: ห้ามตัดการเช็ก isRollSize / Skills.List ออก (กัน Client ส่งตัวเลข/ชื่อมั่ว)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Guard = require(script.Parent.Guard)
local SkillService = require(script.Parent.Parent.Services.SkillService)

-- จริงถ้าจำนวนที่ขอสุ่มเป็นหนึ่งในค่าที่อนุญาต (Economy.Gacha.RollSizes เช่น 1 หรือ 10)
local function isRollSize(count: number): boolean
	return table.find(Economy.Gacha.RollSizes, count) ~= nil
end

local SkillHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูก 3 Remote: สุ่มกาชา / สวมสกิล / อัปสกิล
function SkillHandler.Init()
	-- สุ่มกาชา: รับจำนวนครั้ง (number) · สูงสุด 2 คำขอ/วินาที
	Guard.connect(Remotes.get("RollGacha"), { rate = 2, per = 1, args = { "number" } }, function(player, count)
		if isRollSize(count) then
			SkillService.roll(player, count)
		end
	end)
	-- สวมสกิล: รับ skillId (string)
	Guard.connect(Remotes.get("EquipSkill"), { rate = 5, per = 1, args = { "string" } }, function(player, id)
		if Skills.List[id] then
			SkillService.equip(player, id)
		end
	end)
	-- อัปเลเวลสกิล: รับ skillId (string)
	Guard.connect(Remotes.get("UpgradeSkill"), { rate = 5, per = 1, args = { "string" } }, function(player, id)
		if Skills.List[id] then
			SkillService.upgrade(player, id)
		end
	end)
end

return SkillHandler
