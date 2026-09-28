-- ส่งคำขอเลือกคลาสป้อม / สายธาตุ ไป Server (เจ้าของ: Client_UI_Scripter)
-- Client ส่งแค่ "เจตนา" (id ที่อยากได้) · Server ตรวจสิทธิ์ เลเวล และคลาสเอง แล้วตั้ง Attribute
-- TurretClass / TurretBranch กลับมา — UI อ่านผลจาก Attribute เท่านั้น ไม่ถือว่าเลือกสำเร็จเอง
-- สเปก: design/turret-classes.md
-- ใครใช้: UI/ClassUI · ตัวรับฝั่ง Server: src/server/Network/TurretClassHandler.luau
--
-- 📖 อ่านตามลำดับนี้ (เส้นทางของคำขอ 1 ครั้ง):
--   1) ผู้เล่นกดปุ่ม "เลือก" ใน UI/ClassUI (buildClassView / buildBranchView)
--   2) ClassUI เรียก ClassController.requestClass(id) หรือ requestBranch(id) ในไฟล์นี้
--   3) fire() ส่ง id ผ่าน RemoteEvent ไป Server
--   4) Server: Network/TurretClassHandler ตรวจ (Guard + rate limit) → Services/TurretClassService.choose / chooseBranch
--   5) ถ้าผ่าน Server ตั้ง Attribute TurretClass / TurretBranch ของผู้เล่นใหม่
--   6) ClassUI.Start ฟัง Attribute นั้นอยู่ → วาดหน้าจอใหม่ (ไฟล์นี้ไม่ได้รับผลตอบกลับโดยตรง)
-- ⚠️ ระวัง: ไฟล์นี้ห้ามตั้ง Attribute เอง/ห้ามเดาว่าเลือกสำเร็จ — Client แก้ได้ แต่ Server ไม่เชื่อ

-- game:GetService("ชื่อ") = ดึงบริการของ Roblox มาใช้ · ReplicatedStorage = ที่เก็บของที่ Server และ Client เห็นร่วมกัน
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- require(...) = โหลด ModuleScript อื่นมาใช้ · Remotes = ตัวช่วยหา RemoteEvent ตามชื่อ (src/shared/Remotes.luau)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ตารางของโมดูล: ใส่ฟังก์ชันที่ไฟล์อื่นเรียกได้ แล้ว return ท้ายไฟล์
-- (ไฟล์นี้ไม่มี Init/Start เพราะไม่ต้องเตรียมอะไรตอนเริ่มเกม)
local ClassController = {}

-- ส่ง id ไป Server ผ่าน Remote ชื่อ name · id ว่าง/ไม่ใช่ข้อความ → ไม่ส่ง
local function fire(name: string, id: string)
	-- ตรวจเบื้องต้นแค่กันส่งของเปล่า · type(x) = บอกชนิดค่า เช่น "string", "number", "table"
	-- (การตรวจจริงว่า id มีอยู่/ได้สิทธิ์ไหม ทำที่ Server เสมอ)
	if type(id) ~= "string" or id == "" then
		return
	end
	-- `:: RemoteEvent` = บอกชนิดให้ตัวตรวจโค้ดรู้เฉยๆ (type hint) ไม่มีผลตอนเกมรัน
	local remote = Remotes.get(name) :: RemoteEvent
	-- FireServer(id) = ส่งข้อความไป Server ทางเดียว (ไม่รอคำตอบ) · Server ได้ (player, id) โดย player ปลอมไม่ได้
	remote:FireServer(id)
end

-- classId = คีย์ใน Skill_class_default.Classes
function ClassController.requestClass(classId: string)
	fire("ChooseTurretClass", classId)
end

-- branchId = คีย์ใน Skill_class_default.Branches (ต้องเป็นสายของคลาสตัวเอง · Server ตรวจอีกรอบ)
function ClassController.requestBranch(branchId: string)
	fire("ChooseTurretBranch", branchId)
end

return ClassController
