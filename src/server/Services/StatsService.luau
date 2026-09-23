-- ส่งค่าที่ผู้เล่นควรเห็นไปแสดงบน HUD ผ่าน Player Attribute (เจ้าของ: Gameplay_Scripter)
-- Attribute ที่ Server ตั้ง replicate ไป Client อัตโนมัติ และ Client แก้แล้วไม่ส่งกลับ Server [Inferred]
-- → Client ใช้แสดงผลได้ แต่ความจริงยังอยู่ที่ PlayerData ฝั่ง Server เสมอ

local Players = game:GetService("Players")

local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- field ใน PlayerData ที่เปิดให้ Client เห็น (เพิ่มได้ เช่น "Level") · ห้ามใส่ข้อมูลลับ
local PUBLIC_FIELDS = { "Coins" }

local function mirror(player: Player, data: any)
	for _, field in PUBLIC_FIELDS do
		player:SetAttribute(field, data[field])
	end
end

local StatsService = {}

function StatsService.Init()
	PlayerData.Changed:Connect(mirror)
	-- ผู้เล่นที่ข้อมูลโหลดเสร็จก่อน service นี้เริ่มฟัง
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			mirror(player, data)
		end
	end
end

return StatsService
