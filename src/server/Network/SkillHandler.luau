-- รับคำขอกาชา/สกิลจาก Client (เจ้าของ: Networking_Specialist)
-- ตรวจที่นี่: ชนิด + rate (Guard) · จำนวนสุ่มต้องอยู่ใน RollSizes · skillId ต้องมีจริงใน Config
-- ตรวจใน SkillService: ตั๋วพอไหม · มีสกิลนี้ไหม · สกิลซ้ำพอไหม

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local Guard = require(script.Parent.Guard)
local SkillService = require(script.Parent.Parent.Services.SkillService)

local function isRollSize(count: number): boolean
	return table.find(Economy.Gacha.RollSizes, count) ~= nil
end

local SkillHandler = {}

function SkillHandler.Init()
	Guard.connect(Remotes.get("RollGacha"), { rate = 2, per = 1, args = { "number" } }, function(player, count)
		if isRollSize(count) then
			SkillService.roll(player, count)
		end
	end)
	Guard.connect(Remotes.get("EquipSkill"), { rate = 5, per = 1, args = { "string" } }, function(player, id)
		if Skills.List[id] then
			SkillService.equip(player, id)
		end
	end)
	Guard.connect(Remotes.get("UpgradeSkill"), { rate = 5, per = 1, args = { "string" } }, function(player, id)
		if Skills.List[id] then
			SkillService.upgrade(player, id)
		end
	end)
end

return SkillHandler
