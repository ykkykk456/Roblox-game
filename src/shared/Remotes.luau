-- ทะเบียน Remote ที่เดียวของเกม (เจ้าของ: Networking_Specialist)
-- เพิ่ม Remote ใหม่ = เพิ่มชื่อใน NAMES เท่านั้น
-- Server: สร้าง Instance ทั้งหมดใน ReplicatedStorage.Remotes ตอน require ครั้งแรก
-- Client: รอ Instance ที่ Server สร้าง
-- ฝั่ง Server ต้องรับทุก Remote ผ่าน src/server/Network/Guard.luau เท่านั้น
--
-- Remote คืออะไร: "ท่อส่งข้อความ" ระหว่างเครื่องผู้เล่น (Client) กับเซิร์ฟเวอร์ (Server)
--   RemoteEvent = ส่งทางเดียว ไม่รอคำตอบ · RemoteFunction = ส่งแล้วรอคำตอบ
-- อยากเพิ่ม Remote → เพิ่ม 1 บรรทัดใน NAMES ด้านล่าง แล้วไปเขียนตัวรับใน src/server/Network/ (ผ่าน Guard)
-- ใครใช้ไฟล์นี้: src/server/Network/*Handler.luau · Services/TurretService, SkillService ·
--   src/client/Controllers/TurretController, SkillController, ElementController
-- ⚠️ ไฟล์ shared = ผู้เล่นอ่านได้ · ข้อมูลที่ Client ส่งมาเชื่อไม่ได้ ต้องตรวจที่ Server เสมอ

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===== รายชื่อ Remote ทั้งหมด (ชื่อ = ชนิด) =====
local NAMES: { [string]: "RemoteEvent" | "RemoteFunction" } = {
	-- ตัวอย่าง: BuyItem = "RemoteEvent",
	UpgradeTurret = "RemoteEvent", -- Client → Server: ขออัปเลเวลป้อม (ไม่มี argument)
	UseTurretSkill = "RemoteEvent", -- Client → Server: ขอใช้สกิลธาตุของป้อม (ไม่มี argument · Server ดูธาตุเอง)
	-- Server → Client: เอฟเฟกต์การยิงสำหรับวาดเท่านั้น · ส่งรวมทุกป้อมต่อรอบคำนวณ (สกิลส่งแยกตอนเกิด)
	-- payload: { { Kind: string, From: Vector3, To: Vector3, Color: Color3,
	--              Radius: number?, Duration: number?, Travel: number?, Spread: number?, Arc: number? } }
	-- Kind = ค่า Fx ใน Config/Elements (ไม่รู้จัก → Tracer/ลูกกลมวิ่ง) · Travel = เวลาเดินทางจริงของกระสุนสกิล (วิ)
	-- Radius = รัศมีระเบิด/โซน · Duration = เวลาอยู่ของโซน/ลำแสง/บัฟ · Spread = มุมพัด (องศา) · Arc = ความสูงโค้ง
	TurretFx = "RemoteEvent",
	ChooseElement = "RemoteEvent", -- Client → Server: (elementId: string) เลือกธาตุ (ครั้งแรกฟรี · เปลี่ยน = เสียเงิน)
	RollGacha = "RemoteEvent", -- Client → Server: (count: number) สุ่มสกิลด้วยตั๋ว
	EquipSkill = "RemoteEvent", -- Client → Server: (skillId: string) เลือกสกิลที่ใช้
	UpgradeSkill = "RemoteEvent", -- Client → Server: (skillId: string) อัปขั้นด้วยสกิลซ้ำ
	GachaResult = "RemoteEvent", -- Server → Client: ผลการสุ่ม { { id, new } } สำหรับแสดงผลเท่านั้น
}

-- ===== สร้าง/หาโฟลเดอร์ Remotes =====
-- ชื่อโฟลเดอร์ใน ReplicatedStorage ที่เก็บ Remote ทุกตัว
local FOLDER_NAME = "Remotes"

-- Server สร้าง Remote ทุกตัวตาม NAMES · Client รอจนโฟลเดอร์ที่ Server สร้างโผล่มา
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

-- ดึง Remote ตามชื่อ เช่น Remotes.get("UpgradeTurret") → คืน RemoteEvent/RemoteFunction
-- ชื่อที่ไม่มีใน NAMES จะ error ทันที (กันพิมพ์ชื่อผิด)
function Remotes.get(name: string): Instance
	assert(NAMES[name], `Remote "{name}" ยังไม่ได้ประกาศใน Remotes.luau`)
	return folder:WaitForChild(name)
end

return Remotes
