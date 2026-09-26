-- แอ่งกลางแมพ = ที่เก็บของ + จุดบอสเกิด (เจ้าของ: Gameplay_Scripter) · ยืนยัน 2026-09-26
-- ก่อนบอสมา Map.Pit.WarnSeconds วินาที → ปิดแอ่ง (ระบบเก็บของต้องเช็ก PitService.isOpen ก่อนให้ของเกิด)
-- ระหว่างบอสอยู่ → ย้ายตัวละครที่อยู่ในแอ่งขึ้นไปยืนบนถนนวงแหวน (Server ทำเอง ไม่รับคำขอจาก Client)
-- บอสจบ → เปิดแอ่ง · สถานะเผยแพร่ที่ Attribute "PitOpen" ของ ReplicatedStorage.BossState ให้ UI อ่าน

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)

local CHECK_INTERVAL = 0.25

local state: Instance? = nil
local open = true

local function setOpen(value: boolean)
	open = value
	if state then
		state:SetAttribute("PitOpen", value)
	end
end

-- จุดยืนบนถนนวงแหวน ในทิศเดียวกับที่ผู้เล่นอยู่
local function roadPoint(from: Vector3): CFrame
	local flat = Vector3.new(from.X, 0, from.Z)
	local outward = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, -1)
	local radius = (Map.Road.Inner + Map.Road.Outer) / 2
	local position = outward * radius + Vector3.new(0, Map.GroundY + 3, 0)
	return CFrame.lookAt(position, position + outward)
end

local function ejectPlayers()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local position = root.Position
			if Vector3.new(position.X, 0, position.Z).Magnitude < Map.Pit.Radius then
				character:PivotTo(roadPoint(position))
			end
		end
	end
end

local PitService = {}

-- ระบบเก็บของใช้ตัดสินว่าให้ของเกิด/เก็บได้ไหม
function PitService.isOpen(): boolean
	return open
end

function PitService.Start()
	local bossState = ReplicatedStorage:WaitForChild("BossState")
	state = bossState
	setOpen(true)
	while true do
		task.wait(CHECK_INTERVAL)
		local active = bossState:GetAttribute("Active") == true
		local nextAt = bossState:GetAttribute("NextAt")
		local warning = not active
			and type(nextAt) == "number"
			and nextAt - workspace:GetServerTimeNow() <= Map.Pit.WarnSeconds
		if active or warning then
			if open then
				setOpen(false)
			end
			if active then
				ejectPlayers()
			end
		elseif not open then
			setOpen(true)
		end
	end
end

return PitService
