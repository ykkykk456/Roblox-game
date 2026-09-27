-- แอ่งกลางแมพ = ที่เก็บของ + จุดบอสเกิด (เจ้าของ: Gameplay_Scripter) · ยืนยัน 2026-09-26
-- ก่อนบอสมา Map.Pit.WarnSeconds วินาที → ปิดแอ่ง (ระบบเก็บของต้องเช็ก PitService.isOpen ก่อนให้ของเกิด)
-- ระหว่างบอสอยู่ → ย้ายตัวละครที่อยู่ในแอ่งขึ้นไปยืนบนถนนวงแหวน (Server ทำเอง ไม่รับคำขอจาก Client)
-- บอสจบ → เปิดแอ่ง · สถานะเผยแพร่ที่ Attribute "PitOpen" ของ ReplicatedStorage.BossState ให้ UI อ่าน

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local LayoutService = require(script.Parent.LayoutService)

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

-- ผังจากแมพ (Tag): เขตบอส = รอบ BossSpawn รัศมีครึ่งระยะถึงป้อมที่ใกล้สุด · ดันออกไปทางเดิมที่ผู้เล่นยืน
local function layoutZone(): (Vector3, number)
	local center = LayoutService.bossCenter()
	local nearest = math.huge
	for _, slot in LayoutService.slots() do
		local turret = LayoutService.turretTop(slot)
		nearest = math.min(nearest, Vector3.new(turret.X - center.X, 0, turret.Z - center.Z).Magnitude)
	end
	return center, if nearest < math.huge then nearest / 2 else Map.Pit.Radius
end

local function ejectPlayers()
	local layout = LayoutService.hasLayout()
	local center, radius = Vector3.zero, Map.Pit.Radius
	if layout then
		center, radius = layoutZone()
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local position = root.Position
			local flat = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
			if flat.Magnitude < radius then
				if layout then
					local outward = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, 1)
					local target = Vector3.new(center.X, 0, center.Z) + outward * (radius + 8)
					local y = LayoutService.floorAt(target, { character }) + 3
					character:PivotTo(CFrame.lookAt(Vector3.new(target.X, y, target.Z), Vector3.new(target.X, y, target.Z) + outward))
				else
					character:PivotTo(roadPoint(position))
				end
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
