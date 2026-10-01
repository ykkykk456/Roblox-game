-- รับปุ่ม "เข้าใจแล้ว!" ของขั้นสุดท้ายในระบบฝึกสอน (เจ้าของ: Networking_Specialist) · สเปก: design/tutorial.md
-- Remote "TutorialAck" ไม่มี argument (Guard ปฏิเสธถ้าส่งมา) · สิทธิ์ (ต้องอยู่ขั้น 5 + อ่านมาแล้ว ≥ MinReadSeconds) ตรวจใน TutorialService.ack
-- ⚠️ ไม่มี Remote ให้ Client สั่ง "จบขั้น" อื่น — ขั้น 1–4 Server เลื่อนเองเมื่อเห็นผลจริง (เลือกธาตุ / มอนหมด / ใช้สกิล / อัป)
--
-- อยากปรับ: ความถี่ที่ยอมให้กด → rate/per ด้านล่าง · เวลาอ่านขั้นต่ำ → Config/Tutorial.luau (MinReadSeconds)
-- คุยกับ: Guard · Services/TutorialService · Remotes
-- ห้ามแก้: ห้ามต่อ OnServerEvent ตรงๆ ต้องผ่าน Guard.connect เสมอ
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์สั้น มีฟังก์ชันเดียว)
--   1) Init — init.server.luau เรียกให้ตอนเซิร์ฟเริ่ม · ผูก Remote "TutorialAck" เข้ากับ Guard
--   2) ผู้เล่นกด "เข้าใจแล้ว!" (Client) → Guard ตรวจความถี่ + ห้ามมี argument → TutorialService.ack ตรวจขั้น/เวลา

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TutorialService = require(script.Parent.Parent.Services.TutorialService)

local TutorialHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · สูงสุด 2 ครั้ง/วินาที/ผู้เล่น (กดซ้ำเกินนี้ = เงียบ)
function TutorialHandler.Init()
	Guard.connect(Remotes.get("TutorialAck"), { rate = 2, per = 1 }, function(player)
		TutorialService.ack(player)
	end)
end

return TutorialHandler
