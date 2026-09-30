-- รับคำขอเลือก/เปลี่ยนธาตุป้อมจาก Client (เจ้าของ: Networking_Specialist) · สเปก: design/element-skills.md หัวข้อ 6.4
-- แทน TurretClassHandler เดิม (ChooseTurretClass / ChooseTurretBranch ถูกลบแล้ว) · วิวัฒนาการยังไม่ทำ (ไม่มี ChooseEvolution)
-- ตรวจที่นี่: ชนิด + จำนวน argument + rate (Guard) · id ต้องเป็นธาตุที่มีจริงใน Config/Elements
-- ตรวจใน TurretElementService (ใน PlayerData.update): ธาตุเดิมซ้ำ = ไม่ทำ · เปลี่ยน = เงินพอ + บอสไม่อยู่
--
-- อยากเพิ่ม/แก้ธาตุ → src/shared/Config/Elements.luau · ความถี่ที่ยอมให้กด → rate/per ด้านล่าง
-- คุยกับ: Guard · Services/TurretElementService (บันทึกลง PlayerData + หักเงิน) · Remotes
-- ห้ามแก้: ต้องเช็ก id กับ Config ก่อนส่งต่อเสมอ (Client ส่ง string อะไรมาก็ได้) · ห้ามต่อ OnServerEvent ตรงๆ
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์สั้น มีฟังก์ชันเดียว)
--   1) Init — init.server.luau เรียกให้ตอนเซิร์ฟเริ่ม · ผูก Remote "ChooseElement" เข้ากับ Guard
--   2) ผู้เล่นกดปุ่มในหน้าเลือกธาตุ (Client: UI/ElementUI → Controllers/ElementController) → ส่ง Remote มาที่นี่
--   3) Guard (Network/Guard.luau:connect) ตรวจชนิด + ความถี่ก่อน · ไม่ผ่าน = เงียบ
--   4) ผ่านแล้ว → เช็กว่า id เป็นธาตุจริง → ส่งต่อ Services/TurretElementService.luau:choose

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretElementService = require(script.Parent.Parent.Services.TurretElementService)

local ElementHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · รับ id เป็น string 1 ตัว สูงสุด 3 ครั้ง/วินาที/ผู้เล่น
function ElementHandler.Init()
	-- ⚠️ ระวัง: ห้ามเอา args ออก — จะไม่มีการกันส่งชนิดมั่ว/ส่งหลายค่า
	Guard.connect(Remotes.get("ChooseElement"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		-- ⚠️ ด่านกัน id มั่ว (เช่น "SuperFire") ห้ามลบ · กฎเงิน/บอสตรวจต่อใน TurretElementService.choose
		if ElementMath.isElement(id) then
			TurretElementService.choose(player, id)
		end
	end)
end

return ElementHandler
