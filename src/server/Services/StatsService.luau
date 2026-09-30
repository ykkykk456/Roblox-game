-- ส่งค่าที่ผู้เล่นควรเห็นไปแสดงบน HUD ผ่าน Player Attribute (เจ้าของ: Gameplay_Scripter)
-- Attribute ที่ Server ตั้ง replicate ไป Client อัตโนมัติ และ Client แก้แล้วไม่ส่งกลับ Server [Inferred]
-- → Client ใช้แสดงผลได้ แต่ความจริงยังอยู่ที่ PlayerData ฝั่ง Server เสมอ
--
-- อยากให้ UI เห็นค่าใหม่ (เช่น Rebirths) → เพิ่มชื่อ field ใน PUBLIC_FIELDS (ถ้าเป็นตาราง ใส่ JSON_FIELDS)
--   แล้วฝั่ง Client อ่านด้วย player:GetAttribute("ชื่อ field")
-- คุยกับ: Data/PlayerData (ฟัง PlayerData.Changed) · UI ฝั่ง Client อ่าน Attribute ที่ตั้งไว้
-- ห้ามแก้: ห้ามใส่ข้อมูลที่ผู้เล่นไม่ควรรู้ลงในรายการ (ทุกคนในเซิร์ฟเห็น Attribute ของผู้เล่นได้ [Inferred])

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- field ใน PlayerData ที่เปิดให้ Client เห็น (เพิ่มได้ เช่น "Level") · ห้ามใส่ข้อมูลลับ
local PUBLIC_FIELDS = { "Coins", "TurretLevel", "GachaTickets", "EquippedSkill", "Element" }
-- field ที่เป็นตาราง (Attribute เก็บตารางไม่ได้) → ส่งเป็น JSON string
local JSON_FIELDS = { "Skills" }

-- คัดลอกค่าจาก data ไปตั้งเป็น Attribute บนตัว player · เรียกทุกครั้งที่ PlayerData เปลี่ยน
local function mirror(player: Player, data: any)
	for _, field in PUBLIC_FIELDS do
		player:SetAttribute(field, data[field])
	end
	for _, field in JSON_FIELDS do
		-- pcall กันกรณีแปลงเป็น JSON ไม่ได้ → ข้ามไป ค่าเก่ายังอยู่
		local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data[field])
		if ok then
			player:SetAttribute(field, encoded)
		end
	end
end

local StatsService = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · เริ่มฟังการเปลี่ยนข้อมูล และส่งค่าให้คนที่อยู่ในเกมแล้ว
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
