-- รับคำขอเลือกคลาสป้อม/สายธาตุจาก Client (เจ้าของ: Networking_Specialist)
-- ตรวจที่นี่: ชนิด + rate (Guard) · id ต้องมีจริงใน Config/Skill_class_default
-- ตรวจใน TurretClassService: ยังไม่มีสาย · สายเป็นของคลาสตัวเอง · เลเวลถึง BranchLevel
--
-- อยากเพิ่ม/แก้คลาสหรือสายธาตุ → src/shared/Config/Skill_class_default.luau (Classes / Branches)
-- คุยกับ: Guard · Services/TurretClassService (บันทึกตัวเลือกลง PlayerData) · Remotes
-- ห้ามแก้: ต้องเช็ก id กับ Config ก่อนส่งต่อเสมอ (Client ส่ง string อะไรมาก็ได้)
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์สั้น มีฟังก์ชันเดียว)
--   1) Init — init.server.luau เรียกให้ตอนเซิร์ฟเริ่ม · ผูก Remote 2 ตัวเข้ากับ Guard
--   2) ผู้เล่นกดปุ่มในหน้าเลือกคลาส (Client: UI/ClassUI → Controllers/ClassController) → ส่ง Remote มาที่นี่
--   3) Guard (Network/Guard.luau:connect) ตรวจชนิด + ความถี่ก่อน · ไม่ผ่าน = เงียบ ไม่เรียกฟังก์ชันข้างล่างเลย
--   4) ผ่านแล้ว → เช็กว่า id มีใน Config → ส่งต่อ Services/TurretClassService.luau:choose หรือ :chooseBranch
--      (ที่นั่นตรวจกฎเต็มอีกรอบ แล้วบันทึกลง PlayerData)

-- game:GetService = ขอ "บริการ" ของ Roblox มาใช้ · ReplicatedStorage = ที่เก็บของที่ทั้ง Server และ Client เห็น
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.Skill_class_default)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretClassService = require(script.Parent.Parent.Services.TurretClassService)

local TurretClassHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูก Remote เลือกคลาส/เลือกสายธาตุ (รับ id เป็น string 1 ตัว, สูงสุด 3 ครั้ง/วินาที)
function TurretClassHandler.Init()
	-- Guard.connect(remote, กฎ, ฟังก์ชัน) = "เมื่อ Client ยิง Remote นี้มา และผ่านกฎ → เรียกฟังก์ชันนี้"
	--   rate = 3, per = 1 → ไม่เกิน 3 ครั้งต่อ 1 วินาทีต่อผู้เล่น · args = { "string" } → ต้องส่งมา 1 ค่าเป็นข้อความ
	--   function(player, id) ... end = ฟังก์ชันไม่มีชื่อ (ส่งเป็นค่าให้ Guard เก็บไว้เรียกทีหลัง)
	--   player = ผู้ส่ง (Roblox ใส่ให้เอง ปลอมไม่ได้) · id = ค่าที่ Client ส่งมา (ปลอมได้ ต้องตรวจ!)
	-- ⚠️ ระวัง: ห้ามเปลี่ยนไปใช้ OnServerEvent ตรงๆ หรือเอา args ออก — จะไม่มีการกันส่งรัว/ส่งชนิดมั่ว
	Guard.connect(Remotes.get("ChooseTurretClass"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		-- id ไม่มีใน Config = ไม่ทำอะไรเลย (เงียบ ไม่ตอบกลับ)
		-- ⚠️ ระวัง: บรรทัด if นี้คือด่านกัน id มั่ว (เช่น "SuperMage") ห้ามลบ
		if ClassConfig.Classes[id] then
			-- ส่งต่อให้ Service ตัดสินจริง (ตรวจกฎล็อกคลาส + บันทึก) → TurretClassService.luau:choose
			TurretClassService.choose(player, id)
		end
	end)
	-- เหมือนข้างบน แต่สำหรับเลือกสายธาตุ (ต้องมีใน Branches)
	-- ด่านที่เหลือ (สายของคลาสตัวเอง? เลเวลถึง? เลือกไปแล้วหรือยัง?) อยู่ใน TurretClassService.luau:chooseBranch
	Guard.connect(Remotes.get("ChooseTurretBranch"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		if ClassConfig.Branches[id] then
			TurretClassService.chooseBranch(player, id)
		end
	end)
end

return TurretClassHandler
