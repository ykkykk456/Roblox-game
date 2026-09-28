-- รับคำขอเลือกคลาสป้อม/สายธาตุจาก Client (เจ้าของ: Networking_Specialist)
-- ตรวจที่นี่: ชนิด + rate (Guard) · id ต้องมีจริงใน Config/Skill_class_default
-- ตรวจใน TurretClassService: ยังไม่มีสาย · สายเป็นของคลาสตัวเอง · เลเวลถึง BranchLevel

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.Skill_class_default)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretClassService = require(script.Parent.Parent.Services.TurretClassService)

local TurretClassHandler = {}

function TurretClassHandler.Init()
	Guard.connect(Remotes.get("ChooseTurretClass"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		if ClassConfig.Classes[id] then
			TurretClassService.choose(player, id)
		end
	end)
	Guard.connect(Remotes.get("ChooseTurretBranch"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		if ClassConfig.Branches[id] then
			TurretClassService.chooseBranch(player, id)
		end
	end)
end

return TurretClassHandler
