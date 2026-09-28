-- แอ่งกลางแมพ = ที่เก็บของ + จุดบอสเกิด (เจ้าของ: Gameplay_Scripter) · ยืนยัน 2026-09-26
-- ก่อนบอสมา Map.Pit.WarnSeconds วินาที → ปิดแอ่ง (ระบบเก็บของต้องเช็ก PitService.isOpen ก่อนให้ของเกิด)
-- ระหว่างบอสอยู่ → ย้ายตัวละครที่อยู่ในแอ่งขึ้นไปยืนบนถนนวงแหวน (Server ทำเอง ไม่รับคำขอจาก Client)
-- บอสจบ → เปิดแอ่ง · สถานะเผยแพร่ที่ Attribute "PitOpen" ของ ReplicatedStorage.BossState ให้ UI อ่าน
--
-- อยากปรับ:
--   • เตือนก่อนบอสมากี่วินาที → src/shared/Config/Map.luau (Pit.WarnSeconds)
--   • ขนาดเขตที่ดันผู้เล่นออก (ผังวงกลม) → Config/Map.luau (Pit.Radius) · จุดที่ไปยืน → Road.Inner/Outer
--   • แมพสร้างมือ: เขต = ครึ่งระยะจากจุดบอสถึงป้อมที่ใกล้สุด (คำนวณเองใน layoutZone)
-- คุยกับ: BossService (ตั้ง Attribute Active / NextAt บน ReplicatedStorage.BossState) · LayoutService (ตำแหน่งจาก Tag)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local LayoutService = require(script.Parent.LayoutService)

-- ===== ค่าคงที่ =====
-- เช็กสถานะบอสทุกกี่วินาที (ปรับได้ · ต่ำ = ดันผู้เล่นออกไวขึ้นแต่กินเครื่องขึ้นนิดหน่อย)
local CHECK_INTERVAL = 0.25

-- ===== สถานะ =====
-- state = ReplicatedStorage.BossState (ได้ตอน Start) · open = แอ่งเปิดอยู่ไหม
local state: Instance? = nil
local open = true

-- ตั้งสถานะเปิด/ปิด และเผยแพร่ให้ Client ผ่าน Attribute "PitOpen"
local function setOpen(value: boolean)
	open = value
	if state then
		state:SetAttribute("PitOpen", value)
	end
end

-- ===== ดันผู้เล่นออกจากแอ่ง =====
-- จุดยืนบนถนนวงแหวน ในทิศเดียวกับที่ผู้เล่นอยู่
-- (ยืนกลางแมพพอดี → ไม่มีทิศ → ใช้ทิศเหนือ −Z แทน · ยกสูง 3 studs กันจมพื้น)
local function roadPoint(from: Vector3): CFrame
	local flat = Vector3.new(from.X, 0, from.Z)
	local outward = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, -1)
	local radius = (Map.Road.Inner + Map.Road.Outer) / 2
	local position = outward * radius + Vector3.new(0, Map.GroundY + 3, 0)
	return CFrame.lookAt(position, position + outward)
end

-- ผังจากแมพ (Tag): เขตบอส = รอบ BossSpawn รัศมีครึ่งระยะถึงป้อมที่ใกล้สุด · ดันออกไปทางเดิมที่ผู้เล่นยืน
-- คืน (จุดกลาง, รัศมี) · ไม่มีป้อมเลย → ใช้ Map.Pit.Radius
local function layoutZone(): (Vector3, number)
	local center = LayoutService.bossCenter()
	local nearest = math.huge
	for _, slot in LayoutService.slots() do
		local turret = LayoutService.turretTop(slot)
		nearest = math.min(nearest, Vector3.new(turret.X - center.X, 0, turret.Z - center.Z).Magnitude)
	end
	return center, if nearest < math.huge then nearest / 2 else Map.Pit.Radius
end

-- ย้ายทุกคนที่ยืนอยู่ในเขตบอสออกไปนอกเขต (เรียกซ้ำทุก CHECK_INTERVAL ขณะบอสอยู่)
-- แมพสร้างมือ: วางไว้ห่างขอบเขต 8 studs บนพื้นจริง (floorAt ยิงหาพื้น) · ผังวงกลม: วางบนถนนวงแหวน
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
			-- ระยะแนวราบจากจุดกลาง (ไม่นับความสูง)
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

-- ===== API =====
local PitService = {}

-- ระบบเก็บของใช้ตัดสินว่าให้ของเกิด/เก็บได้ไหม
function PitService.isOpen(): boolean
	return open
end

-- วนตลอดเกม: ดูสถานะบอส แล้วเปิด/ปิดแอ่ง
--   บอสอยู่ (Active) → ปิด + ดันคนออก · ใกล้เวลาบอสมา (NextAt - ตอนนี้ <= WarnSeconds) → ปิด · อื่นๆ → เปิด
function PitService.Start()
	-- รอให้ BossService สร้าง BossState ก่อน
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
