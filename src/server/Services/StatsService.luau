-- ส่งค่าที่ผู้เล่นควรเห็นไปแสดงบน HUD ผ่าน Player Attribute (เจ้าของ: Gameplay_Scripter)
-- Attribute ที่ Server ตั้ง replicate ไป Client อัตโนมัติ และ Client แก้แล้วไม่ส่งกลับ Server [Inferred]
-- → Client ใช้แสดงผลได้ แต่ความจริงยังอยู่ที่ PlayerData ฝั่ง Server เสมอ
--
-- ฝึกสอน: "TutorialStep" / "TutorialDone" ตั้งที่ mirrorTutorial (ไม่ใส่ใน PUBLIC_FIELDS เพราะต้องแปลงค่าตอนปิดระบบฝึก)
-- อยากให้ UI เห็นค่าใหม่ (เช่น Rebirths) → เพิ่มชื่อ field ใน PUBLIC_FIELDS (ถ้าเป็นตาราง ใส่ JSON_FIELDS)
--   แล้วฝั่ง Client อ่านด้วย player:GetAttribute("ชื่อ field")
-- คุยกับ: Data/PlayerData (ฟัง PlayerData.Changed) · UI ฝั่ง Client อ่าน Attribute ที่ตั้งไว้
-- ห้ามแก้: ห้ามใส่ข้อมูลที่ผู้เล่นไม่ควรรู้ลงในรายการ (ทุกคนในเซิร์ฟเห็น Attribute ของผู้เล่นได้ [Inferred])

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- field ใน PlayerData ที่เปิดให้ Client เห็น (เพิ่มได้ เช่น "Level") · ห้ามใส่ข้อมูลลับ
-- (กาชาถูกถอดแล้ว: ไม่มี GachaTickets / EquippedSkill อีก)
local PUBLIC_FIELDS = { "Coins", "TurretLevel", "Element" }
-- field ที่เป็นตาราง (Attribute เก็บตารางไม่ได้) → ส่งเป็น JSON string (encode ทุกครั้งที่ข้อมูลเปลี่ยน · ใส่เฉพาะตารางเล็ก)
-- ✏️ อุปกรณ์ (Gear) ไม่อยู่ที่นี่: Services/GearService ส่ง Attribute "Gear" / "GearSlots" / "GearBonus" เองเฉพาะตอนอุปกรณ์เปลี่ยน
--   (ไม่ต้อง encode ทุกครั้งที่เงินเปลี่ยน) · สัญญากับ Client ดู design/equipment.md หัวข้อ "สัญญากับ Client"
local JSON_FIELDS: { string } = {}

-- ระบบฝึกสอน (design/tutorial.md) → Attribute "TutorialStep" (1..5 · 6 = จบ) และ "TutorialDone" (boolean)
-- ✏️ ปิดระบบฝึก (Config/Tutorial.Enabled = false) → ส่ง "จบแล้ว" ให้ทุกคน (ไม่เขียนลงเซฟ) · ตรงกับ TutorialService.isDone
local function mirrorTutorial(player: Player, data: any)
	local finished = #Tutorial.Steps + 1
	local done = not Tutorial.Enabled or data.TutorialDone == true
	local step = data.TutorialStep
	if done then
		step = finished
	elseif type(step) ~= "number" or step ~= step or step % 1 ~= 0 or step < 1 or step > #Tutorial.Steps then
		step = 1 -- ข้อมูลเสีย → ขั้น 1 (TutorialService ใช้กฎเดียวกัน)
	end
	player:SetAttribute("TutorialStep", step)
	player:SetAttribute("TutorialDone", done)
end

-- คัดลอกค่าจาก data ไปตั้งเป็น Attribute บนตัว player · เรียกทุกครั้งที่ PlayerData เปลี่ยน
local function mirror(player: Player, data: any)
	for _, field in PUBLIC_FIELDS do
		player:SetAttribute(field, data[field])
	end
	mirrorTutorial(player, data)
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
