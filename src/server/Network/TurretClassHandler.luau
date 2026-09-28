-- รับคำขอเลือกคลาสป้อม/สายธาตุจาก Client (เจ้าของ: Networking_Specialist)
-- ตรวจที่นี่: ชนิด + rate (Guard) · id ต้องมีจริงใน Config/Skill_class_default
-- ตรวจใน TurretClassService: ยังไม่มีสาย · สายเป็นของคลาสตัวเอง · เลเวลถึง BranchLevel
--
-- อยากเพิ่ม/แก้คลาสหรือสายธาตุ → src/shared/Config/Skill_class_default.luau (Classes / Branches)
-- คุยกับ: Guard · Services/TurretClassService (บันทึกตัวเลือกลง PlayerData) · Remotes
-- ห้ามแก้: ต้องเช็ก id กับ Config ก่อนส่งต่อเสมอ (Client ส่ง string อะไรมาก็ได้)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassConfig = require(ReplicatedStorage.Shared.Config.Skill_class_default)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Guard = require(script.Parent.Guard)
local TurretClassService = require(script.Parent.Parent.Services.TurretClassService)

local TurretClassHandler = {}

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูก Remote เลือกคลาส/เลือกสายธาตุ (รับ id เป็น string 1 ตัว, สูงสุด 3 ครั้ง/วินาที)
function TurretClassHandler.Init()
	Guard.connect(Remotes.get("ChooseTurretClass"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		-- id ไม่มีใน Config = ไม่ทำอะไรเลย (เงียบ ไม่ตอบกลับ)
		if ClassConfig.Classes[id] then
			TurretClassService.choose(player, id)
		end
	end)
	Guard.connect(Remotes.get("ChooseTurretBranch"), { rate = 3, per = 1, args = { "string" } }, function(player, id)
		if ClassConfig.Branches[id] then
			TurretClassService.chooseBranch(player, id)
		end
	end)
end

return TurretClassHandler
