-- ส่งคำขอเลือกคลาสป้อม / สายธาตุ ไป Server (เจ้าของ: Client_UI_Scripter)
-- Client ส่งแค่ "เจตนา" (id ที่อยากได้) · Server ตรวจสิทธิ์ เลเวล และคลาสเอง แล้วตั้ง Attribute
-- TurretClass / TurretBranch กลับมา — UI อ่านผลจาก Attribute เท่านั้น ไม่ถือว่าเลือกสำเร็จเอง
-- สเปก: design/turret-classes.md

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ClassController = {}

local function fire(name: string, id: string)
	if type(id) ~= "string" or id == "" then
		return
	end
	local remote = Remotes.get(name) :: RemoteEvent
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
