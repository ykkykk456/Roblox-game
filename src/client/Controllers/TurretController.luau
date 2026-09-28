-- ป้อมฝั่ง Client: ส่งคำขอ อัปเกรด/ใช้สกิล · วาดเอฟเฟกต์กระสุนตามคลาส/สายจากข้อมูลที่ Server ส่งมา (เจ้าของ: Client_UI_Scripter)
-- Client ไม่ได้คำนวณดาเมจหรือเงิน — TurretFx เป็นเอฟเฟกต์ล้วน (สเปก: design/turret-classes.md)
-- ปุ่มลัด: สกิล = Q / ปุ่ม X (Gamepad) · อัปเกรด = U / ปุ่ม Y (Gamepad) · มือถือใช้ปุ่มบนจอ (CombatUI)
--
-- TurretFx (Server → Client): { { Kind, From: Vector3, To: Vector3, Color: Color3, Radius: number?, Duration: number? } }
--   Kind = ค่า Fx ใน Config/Skill_class_default · Kind ที่ไม่รู้จัก → วาดเป็น Tracer
-- ประสิทธิภาพ (มือถือ): ชิ้นส่วน Neon แบบ Anchored + Debris · จำกัดจำนวนต่ออีเวนต์ + จำนวนชิ้นพร้อมกัน · ไม่วาดที่ไกลกล้อง

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MAX_FX_PER_EVENT = 60 -- รายการที่วาดต่อ 1 อีเวนต์ (ที่เกินทิ้ง)
local MAX_ACTIVE_PARTS = 300 -- ชิ้นเอฟเฟกต์ที่มีอยู่พร้อมกันทั้งหมด
local MAX_LENGTH = 300 -- เส้นทาง From→To ยาวเกินนี้ไม่วาด (ข้อมูลผิดปกติ)
local MAX_COORD = 1e5
local CULL_DISTANCE = 450 -- ทั้งต้นและปลายไกลกล้องเกินนี้ = ไม่วาด
local MAX_KIND_LENGTH = 32
local MAX_RADIUS = 40
local MAX_DURATION = 8
local DEFAULT_COLOR = Color3.fromRGB(255, 220, 90)
local WHITE = Color3.new(1, 1, 1)
local VOID_COLOR = Color3.fromRGB(12, 6, 22)
local BEAM_TIME = 0.25
local RAINBOW_STEPS = 6

type Fx = {
	Kind: string,
	From: Vector3,
	To: Vector3,
	Color: Color3,
	Radius: number?,
	Duration: number?,
}

local effects: Folder
local active = 0
local random = Random.new()

-- ชิ้นเอฟเฟกต์ 1 ชิ้น · คืน nil เมื่อเกินโควตา (ผู้เรียกต้องรับมือ nil เสมอ)
local function makePart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, lifetime: number): Part?
	if active >= MAX_ACTIVE_PARTS then
		return nil
	end
	active += 1
	task.delay(lifetime, function()
		active -= 1
	end)

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Parent = effects
	Debris:AddItem(part, lifetime)
	return part
end

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Linear, direction or Enum.EasingDirection.Out),
		goal
	):Play()
end

-- ---------------------------------------------------------------- ชิ้นพื้นฐาน

-- แท่งตรง from→to (เส้นกระสุน/ลำแสง) · fade = ค่อยๆ จางจนหาย
local function segment(
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	lifetime: number,
	fade: boolean?
): Part?
	local length = (to - from).Magnitude
	if length < 0.05 then
		return nil
	end
	local part = makePart(
		Enum.PartType.Block,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		color,
		lifetime
	)
	if part and fade then
		tween(part, lifetime, { Transparency = 1 })
	end
	return part
end

-- ลูกกลมขยายแล้วจาง (จุดระเบิด/จุดโดน)
local function burst(position: Vector3, radius: number, color: Color3, seconds: number)
	local part = makePart(Enum.PartType.Ball, Vector3.one * 0.4, CFrame.new(position), color, seconds)
	if part then
		part.Transparency = 0.2
		tween(part, seconds, { Size = Vector3.one * radius * 2, Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end

-- วงแบนบนพื้น (กระเซ็น) · Cylinder วางแกน X ขึ้นฟ้า
local function ring(position: Vector3, diameter: number, color: Color3, seconds: number, transparency: number): Part?
	local flat = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	local part = makePart(Enum.PartType.Cylinder, Vector3.new(0.15, diameter, diameter), flat, color, seconds)
	if part then
		part.Transparency = transparency
	end
	return part
end

-- กระสุนวิ่ง from→to ด้วยความเร็วคงที่ · คืนเวลาเดินทาง (ใช้ตั้งเวลาเอฟเฟกต์ตอนถึง)
local function projectile(
	from: Vector3,
	to: Vector3,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	speed: number
): number
	local travel = math.clamp((to - from).Magnitude / speed, 0.04, 0.6)
	local look = CFrame.lookAt(from, to)
	local part = makePart(shape, size, look, color, travel + 0.03)
	if part then
		tween(part, travel, { CFrame = look.Rotation + to })
	end
	return travel
end

-- ---------------------------------------------------------------- วาดตาม Kind

local function drawTracer(fx: Fx)
	segment(fx.From, fx.To, 0.25, fx.Color, 0.06)
end

local function drawGatling(fx: Fx)
	-- ยิงรัวมาก: เส้นบางอายุสั้นที่สุด
	segment(fx.From, fx.To, 0.12, fx.Color, 0.045)
end

local function drawBolt(fx: Fx)
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 0.9, fx.Color, 170)
	task.delay(travel, burst, fx.To, 1.2, fx.Color, 0.15)
end

local function drawArrow(fx: Fx)
	projectile(fx.From, fx.To, Enum.PartType.Block, Vector3.new(0.15, 0.15, 2.4), fx.Color, 230)
end

local function drawDagger(fx: Fx)
	-- ใบมีดแบนสั้น
	projectile(fx.From, fx.To, Enum.PartType.Block, Vector3.new(0.1, 0.55, 1.3), fx.Color, 170)
end

local function drawShell(fx: Fx)
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 1.4, fx.Color, 120)
	task.delay(travel, burst, fx.To, 2.5, fx.Color, 0.2)
end

local function drawWind(fx: Fx)
	-- เส้นลมบาง ค้างนานกว่ากระสุนปกติเล็กน้อยแล้วจาง
	segment(fx.From, fx.To, 0.1, fx.Color, 0.15, true)
end

local function drawLightning(fx: Fx)
	-- สายฟ้าหยัก: แบ่งเป็นท่อนๆ แต่ละจุดต่อเบี่ยงแบบสุ่มตั้งฉากกับทิศยิง
	local delta = fx.To - fx.From
	local length = delta.Magnitude
	local count = math.clamp(math.floor(length / 5), 3, 8)
	local basis = CFrame.lookAt(fx.From, fx.To)
	local jitter = math.min(length * 0.08, 2.5)
	local previous = fx.From
	for index = 1, count do
		local point = fx.To
		if index < count then
			point = fx.From
				+ delta * (index / count)
				+ basis.RightVector * random:NextNumber(-jitter, jitter)
				+ basis.UpVector * random:NextNumber(-jitter, jitter)
		end
		segment(previous, point, 0.18, fx.Color, 0.12)
		previous = point
	end
	burst(fx.To, 1.2, fx.Color, 0.12)
end

local function drawBeam(fx: Fx)
	-- ลำแสงรุ้ง: หลายท่อนต่างสี แล้วหมุนเฉดสีระหว่างที่แสดง · แกนกลางสีขาว
	local pieces = 5
	local parts: { { part: Part, hue: number } } = {}
	for index = 1, pieces do
		local a = fx.From:Lerp(fx.To, (index - 1) / pieces)
		local b = fx.From:Lerp(fx.To, index / pieces)
		local hue = (index - 1) / pieces
		local part = segment(a, b, 0.5, Color3.fromHSV(hue, 0.75, 1), BEAM_TIME)
		if part then
			part.Transparency = 0.25
			table.insert(parts, { part = part, hue = hue })
		end
	end
	segment(fx.From, fx.To, 0.16, WHITE, BEAM_TIME)
	if #parts == 0 then
		return
	end
	task.spawn(function()
		for step = 1, RAINBOW_STEPS - 1 do
			task.wait(BEAM_TIME / RAINBOW_STEPS)
			local shift = step / RAINBOW_STEPS
			for _, entry in parts do
				if entry.part.Parent then
					entry.part.Color = Color3.fromHSV((entry.hue + shift) % 1, 0.75, 1)
				end
			end
		end
	end)
end

local function drawPoison(fx: Fx)
	-- ลูกพิษโค้งขึ้นแล้วตกใส่เป้า (2 ช่วง) + กระเซ็นเป็นวงเขียว
	local length = (fx.To - fx.From).Magnitude
	local travel = math.clamp(length / 70, 0.15, 0.6)
	local apex = (fx.From + fx.To) / 2 + Vector3.new(0, math.clamp(length * 0.25, 2, 20), 0)
	local ball = makePart(Enum.PartType.Ball, Vector3.one * 1.1, CFrame.new(fx.From), fx.Color, travel + 0.05)
	if ball then
		local part = ball
		tween(part, travel / 2, { CFrame = CFrame.new(apex) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(travel / 2, function()
			if part.Parent then
				tween(part, travel / 2, { CFrame = CFrame.new(fx.To) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end
	task.delay(travel, function()
		local splash = ring(fx.To, 1, fx.Color, 0.35, 0.2)
		if splash then
			tween(splash, 0.35, { Size = Vector3.new(0.15, 7, 7), Transparency = 1 }, Enum.EasingStyle.Quad)
		end
		burst(fx.To, 1.5, fx.Color, 0.25)
	end)
end

local function drawBlackHole(fx: Fx)
	-- หลุมดำที่ To: แกนมืด + เปลือกเรืองแสง + วงแสดงรัศมี · โผล่ → เต้นเป็นจังหวะ → หดหายตอนหมดเวลา
	local radius = math.clamp(fx.Radius or 8, 1, MAX_RADIUS)
	local duration = math.clamp(fx.Duration or 3, 0.3, MAX_DURATION)
	local lifetime = duration + 0.05
	local core = math.clamp(radius * 0.5, 1.5, 7) -- เส้นผ่านศูนย์กลางแกน (ไม่บังจอเต็มรัศมี)
	local pulseTime = 0.4
	local pulses = math.max(0, math.floor((duration - 0.5) / (pulseTime * 2)))

	local area = ring(fx.To, radius * 2, fx.Color, lifetime, 0.75)
	local shell = makePart(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(fx.To), fx.Color, lifetime)
	local void = makePart(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(fx.To), VOID_COLOR, lifetime)
	if void then
		void.Material = Enum.Material.SmoothPlastic
	end
	if shell then
		shell.Transparency = 0.6
	end

	local sized: { { part: Part, size: number } } = {}
	if shell then
		table.insert(sized, { part = shell, size = core * 1.35 })
	end
	if void then
		table.insert(sized, { part = void, size = core })
	end

	for _, entry in sized do
		tween(entry.part, 0.2, { Size = Vector3.one * entry.size }, Enum.EasingStyle.Back)
	end
	task.delay(0.2, function()
		for _, entry in sized do
			if entry.part.Parent then
				TweenService:Create(
					entry.part,
					TweenInfo.new(pulseTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, pulses, true),
					{ Size = Vector3.one * entry.size * 0.75 }
				):Play()
			end
		end
	end)
	task.delay(math.max(duration - 0.25, 0.2), function()
		-- tween ใหม่บน Size แทนที่ tween เต้นเดิม [Inferred]
		for _, entry in sized do
			if entry.part.Parent then
				tween(entry.part, 0.25, { Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
		if area and area.Parent then
			tween(area, 0.25, { Transparency = 1 })
		end
	end)
end

local function drawFireball(fx: Fx)
	-- บอลไฟสีตามเลเวล (Server ส่งสีมาใน Color) + ระเบิดเล็กตอนถึง
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 1.8, fx.Color, 95)
	task.delay(travel, function()
		burst(fx.To, 3, fx.Color, 0.25)
		burst(fx.To, 1.5, WHITE, 0.15)
	end)
end

local DRAWERS: { [string]: (Fx) -> () } = {
	Tracer = drawTracer,
	Bolt = drawBolt,
	Arrow = drawArrow,
	Dagger = drawDagger,
	Shell = drawShell,
	Lightning = drawLightning,
	Beam = drawBeam,
	Wind = drawWind,
	Gatling = drawGatling,
	Poison = drawPoison,
	BlackHole = drawBlackHole,
	Fireball = drawFireball,
}

-- ---------------------------------------------------------------- ตรวจข้อมูลจาก Server

local function validVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < MAX_COORD
		and math.abs(value.Y) < MAX_COORD
		and math.abs(value.Z) < MAX_COORD
end

local function optionalNumber(value: any): number?
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return value
	end
	return nil
end

local function readFx(raw: any): Fx?
	if type(raw) ~= "table" then
		return nil
	end
	local from, to = raw.From, raw.To
	if not validVector(from) or not validVector(to) then
		return nil
	end
	local kind = if type(raw.Kind) == "string" and #raw.Kind <= MAX_KIND_LENGTH then raw.Kind else "Tracer"
	if kind ~= "BlackHole" then
		local length = (to - from).Magnitude
		if length < 0.1 or length > MAX_LENGTH then
			return nil
		end
	end
	return {
		Kind = kind,
		From = from,
		To = to,
		Color = if typeof(raw.Color) == "Color3" then raw.Color else DEFAULT_COLOR,
		Radius = optionalNumber(raw.Radius),
		Duration = optionalNumber(raw.Duration),
	}
end

local function isNearCamera(fx: Fx): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local eye = camera.CFrame.Position
	return (fx.From - eye).Magnitude <= CULL_DISTANCE or (fx.To - eye).Magnitude <= CULL_DISTANCE
end

local function onTurretFx(list: any)
	if type(list) ~= "table" then
		return
	end
	for index = 1, math.min(#list, MAX_FX_PER_EVENT) do
		if active >= MAX_ACTIVE_PARTS then
			return
		end
		local fx = readFx(list[index])
		if fx and isNearCamera(fx) then
			local draw = DRAWERS[fx.Kind] or drawTracer
			local ok, err = pcall(draw, fx)
			if not ok then
				warn(`[TurretController] วาด {fx.Kind} ล้มเหลว: {err}`)
			end
		end
	end
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
	local remote = Remotes.get("TurretFx") :: RemoteEvent
	remote.OnClientEvent:Connect(onTurretFx)
end

return TurretController
