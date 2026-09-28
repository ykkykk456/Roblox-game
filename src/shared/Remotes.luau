-- ทะเบียน Remote ที่เดียวของเกม (เจ้าของ: Networking_Specialist)
-- เพิ่ม Remote ใหม่ = เพิ่มชื่อใน NAMES เท่านั้น
-- Server: สร้าง Instance ทั้งหมดใน ReplicatedStorage.Remotes ตอน require ครั้งแรก
-- Client: รอ Instance ที่ Server สร้าง
-- ฝั่ง Server ต้องรับทุก Remote ผ่าน src/server/Network/Guard.luau เท่านั้น

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES: { [string]: "RemoteEvent" | "RemoteFunction" } = {
	-- ตัวอย่าง: BuyItem = "RemoteEvent",
	UpgradeTurret = "RemoteEvent", -- Client → Server: ขออัปเลเวลป้อม (ไม่มี argument)
	UseTurretSkill = "RemoteEvent", -- Client → Server: ขอใช้สกิลป้อม (ไม่มี argument)
	-- Server → Client: เอฟเฟกต์การยิงสำหรับวาดเท่านั้น (แทน TurretFired เดิม) · ส่งรวมทุกป้อมต่อรอบคำนวณ
	-- payload: { { Kind: string, From: Vector3, To: Vector3, Color: Color3, Radius: number?, Duration: number? } }
	-- Kind = ค่า Fx ใน Config/Skill_class_default (ไม่รู้จัก → วาดเป็น Tracer) · BlackHole: To = จุดหลุม + Radius + Duration
	TurretFx = "RemoteEvent",
	ChooseTurretClass = "RemoteEvent", -- Client → Server: (classId: string) เลือกคลาสป้อม
	ChooseTurretBranch = "RemoteEvent", -- Client → Server: (branchId: string) เลือกสายธาตุ
	RollGacha = "RemoteEvent", -- Client → Server: (count: number) สุ่มสกิลด้วยตั๋ว
	EquipSkill = "RemoteEvent", -- Client → Server: (skillId: string) เลือกสกิลที่ใช้
	UpgradeSkill = "RemoteEvent", -- Client → Server: (skillId: string) อัปขั้นด้วยสกิลซ้ำ
	GachaResult = "RemoteEvent", -- Server → Client: ผลการสุ่ม { { id, new } } สำหรับแสดงผลเท่านั้น
}

local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for name, className in NAMES do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Remotes = {}

function Remotes.get(name: string): Instance
	assert(NAMES[name], `Remote "{name}" ยังไม่ได้ประกาศใน Remotes.luau`)
	return folder:WaitForChild(name)
end

return Remotes
