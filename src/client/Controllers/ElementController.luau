-- ส่งคำขอเลือกธาตุป้อม ไป Server (เจ้าของ: Client_UI_Scripter) · สเปก: design/element-skills.md
-- แทน ClassController เดิม · Client ส่งแค่ "เจตนา" (id ที่อยากได้) · Server ตรวจเงิน/บอส/ธาตุเอง แล้วตั้ง Attribute
-- Element กลับมา — UI อ่านผลจาก Attribute เท่านั้น ไม่ถือว่าเลือกสำเร็จเอง
-- ใครใช้: UI/ElementUI · ตัวรับฝั่ง Server: src/server/Network/ElementHandler.luau
--
-- 📖 อ่านตามลำดับนี้ (เส้นทางของคำขอ 1 ครั้ง):
--   1) ผู้เล่นกดปุ่ม "เลือก" ใน UI/ElementUI
--   2) ElementUI เรียก ElementController.requestElement(id)
--   3) fire() ส่ง id ผ่าน RemoteEvent ไป Server
--   4) Server: Network/ElementHandler (Guard + rate limit) → Services/TurretElementService.choose
--   5) ผ่าน → Server ตั้ง Attribute Element ใหม่ → ElementUI ที่ฟังอยู่วาดใหม่
-- ⚠️ ระวัง: ไฟล์นี้ห้ามตั้ง Attribute เอง/ห้ามเดาว่าเลือกสำเร็จ — Client แก้ได้ แต่ Server ไม่เชื่อ

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ElementController = {}

-- ส่ง id ไป Server ผ่าน Remote ชื่อ name · id ว่าง/ไม่ใช่ข้อความ → ไม่ส่ง
local function fire(name: string, id: string)
	if type(id) ~= "string" or id == "" then
		return
	end
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer(id)
end

-- elementId = ธาตุพื้นฐานใน Config/Elements.Order (ครั้งแรกฟรี · เปลี่ยน = เสียเงิน ChangeElementCost)
function ElementController.requestElement(elementId: string)
	fire("ChooseElement", elementId)
end

return ElementController
