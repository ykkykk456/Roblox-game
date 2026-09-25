-- รับคำขอเกี่ยวกับป้อมจาก Client (เจ้าของ: Networking_Specialist)
-- ทั้งสอง Remote ไม่รับ argument (Guard ปฏิเสธถ้าส่งมา) · สิทธิ์/เงิน/cooldown ตรวจใน TurretService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretService = require(script.Parent.Parent.Services.TurretService)

local TurretHandler = {}

function TurretHandler.Init()
	Guard.connect(Remotes.get("UpgradeTurret"), { rate = 5, per = 1 }, function(player)
		TurretService.upgrade(player)
	end)
	Guard.connect(Remotes.get("UseTurretSkill"), { rate = 2, per = 1 }, function(player)
		TurretService.useSkill(player)
	end)
end

return TurretHandler
