-- ป้อมฝั่ง Client: ส่งคำขอ อัปเกรด/ใช้สกิล · วาดเส้นกระสุนจากข้อมูลที่ Server ส่งมา (เจ้าของ: Client_UI_Scripter)
-- Client ไม่ได้คำนวณดาเมจหรือเงิน — เส้นกระสุนเป็นเอฟเฟกต์ล้วน
-- ปุ่มลัด: สกิล = Q / ปุ่ม X (Gamepad) · อัปเกรด = U / ปุ่ม Y (Gamepad) · มือถือใช้ปุ่มบนจอ (CombatUI)

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TRACER_LIFETIME = 0.06
local TRACER_COLOR = Color3.fromRGB(255, 220, 90)
local MAX_TRACER_LENGTH = 300

local effects: Folder

local function tracer(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.1 or length > MAX_TRACER_LENGTH then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = TRACER_COLOR
	part.Size = Vector3.new(0.25, 0.25, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = effects
	Debris:AddItem(part, TRACER_LIFETIME)
end

local TurretController = {}

local function fire(name: string)
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer()
end

function TurretController.requestUpgrade()
	fire("UpgradeTurret")
end

function TurretController.requestSkill()
	fire("UseTurretSkill")
end

function TurretController.Init()
	effects = Instance.new("Folder")
	effects.Name = "TurretEffects"
	effects.Parent = workspace

	ContextActionService:BindAction("TurretSkill", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestSkill()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	ContextActionService:BindAction("TurretUpgrade", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestUpgrade()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.U, Enum.KeyCode.ButtonY)
end

function TurretController.Start()
	local fired = Remotes.get("TurretFired") :: RemoteEvent
	fired.OnClientEvent:Connect(function(points)
		if type(points) ~= "table" then
			return
		end
		for index = 1, #points - 1, 2 do
			local from, to = points[index], points[index + 1]
			if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
				tracer(from, to)
			end
		end
	end)
end

return TurretController
