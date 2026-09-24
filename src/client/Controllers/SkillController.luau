-- ส่งคำขอกาชา/สกิลไป Server และส่งต่อผลการสุ่มให้ UI (เจ้าของ: Client_UI_Scripter)
-- Client ไม่สุ่มเอง ไม่ตัดสินว่าได้อะไร — แค่ขอ แล้วแสดงผลที่ Server ส่งกลับมา

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local resultEvent = Instance.new("BindableEvent")

local function fire(name: string, ...: any)
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer(...)
end

local SkillController = {}

-- ยิงเมื่อ Server ส่งผลการสุ่มมา: ({ { id: string, new: boolean } })
SkillController.Result = resultEvent.Event

function SkillController.roll(count: number)
	fire("RollGacha", count)
end

function SkillController.equip(id: string)
	fire("EquipSkill", id)
end

function SkillController.upgrade(id: string)
	fire("UpgradeSkill", id)
end

function SkillController.Start()
	local remote = Remotes.get("GachaResult") :: RemoteEvent
	remote.OnClientEvent:Connect(function(results)
		if type(results) == "table" then
			resultEvent:Fire(results)
		end
	end)
end

return SkillController
