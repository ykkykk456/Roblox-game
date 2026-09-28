-- ส่งคำขอกาชา/สกิลไป Server และส่งต่อผลการสุ่มให้ UI (เจ้าของ: Client_UI_Scripter)
-- Client ไม่สุ่มเอง ไม่ตัดสินว่าได้อะไร — แค่ขอ แล้วแสดงผลที่ Server ส่งกลับมา
-- ใครใช้: UI/GachaUI (ปุ่มสุ่ม/ใช้/อัปสกิล) · ตัวรับฝั่ง Server: src/server/Network/SkillHandler.luau
-- อยากเพิ่มคำขอใหม่ → เพิ่มชื่อใน shared/Remotes.luau + ตัวรับใน SkillHandler ก่อน แล้วค่อยเพิ่มฟังก์ชันที่นี่

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- สัญญาณภายในเครื่อง ใช้ส่งผลสุ่มต่อให้ UI
local resultEvent = Instance.new("BindableEvent")

-- ส่ง Remote ชื่อ name ไป Server พร้อมข้อมูล ...

local function fire(name: string, ...: any)
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer(...)
end

local SkillController = {}

-- ยิงเมื่อ Server ส่งผลการสุ่มมา: ({ { id: string, new: boolean } })
SkillController.Result = resultEvent.Event

-- ===== คำขอไป Server =====
-- ขอสุ่มกาชา count ครั้ง (Server เช็กตั๋ว/จำนวนที่อนุญาตเอง)
function SkillController.roll(count: number)
	fire("RollGacha", count)
end

-- ขอใช้สกิล id เป็นสกิลหลักของป้อม
function SkillController.equip(id: string)
	fire("EquipSkill", id)
end

-- ขออัปเลเวลสกิล id ด้วยสกิลซ้ำ
function SkillController.upgrade(id: string)
	fire("UpgradeSkill", id)
end

-- เริ่มฟังผลสุ่มจาก Server (เรียกอัตโนมัติจาก init.client) → ส่งต่อให้ UI ผ่าน Result
function SkillController.Start()
	local remote = Remotes.get("GachaResult") :: RemoteEvent
	remote.OnClientEvent:Connect(function(results)
		if type(results) == "table" then
			resultEvent:Fire(results)
		end
	end)
end

return SkillController
