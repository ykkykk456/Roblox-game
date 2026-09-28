-- รับคำขอเกี่ยวกับป้อมจาก Client (เจ้าของ: Networking_Specialist)
-- ทั้งสอง Remote ไม่รับ argument (Guard ปฏิเสธถ้าส่งมา) · สิทธิ์/เงิน/cooldown ตรวจใน TurretService
--
-- อยากปรับ:
--   • ราคาอัปป้อม → src/shared/Config/Economy.luau (Turret.UpgradeBaseCost / UpgradeCostGrowth)
--   • ความถี่ที่ยอมให้กดได้ (กันสแปม) → ตัวเลข rate/per ด้านล่าง (rate = กี่ครั้ง ต่อ per วินาที)
-- คุยกับ: Guard (ด่านตรวจ) · Services/TurretService (ทำงานจริง) · Remotes (ชื่อ Remote)
-- ห้ามแก้: ห้ามต่อ Remote ตรงๆ ด้วย OnServerEvent ต้องผ่าน Guard.connect เสมอ

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretService = require(script.Parent.Parent.Services.TurretService)

local TurretHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม (init.server.luau) · ผูก Remote เข้ากับฟังก์ชันใน TurretService
function TurretHandler.Init()
	-- กดอัปเลเวลป้อม: ได้สูงสุด 5 ครั้ง/วินาที
	Guard.connect(Remotes.get("UpgradeTurret"), { rate = 5, per = 1 }, function(player)
		TurretService.upgrade(player)
	end)
	-- กดใช้สกิลป้อม: ได้สูงสุด 2 ครั้ง/วินาที (cooldown จริงตรวจใน TurretService)
	Guard.connect(Remotes.get("UseTurretSkill"), { rate = 2, per = 1 }, function(player)
		TurretService.useSkill(player)
	end)
end

return TurretHandler
