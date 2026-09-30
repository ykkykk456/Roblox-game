-- ป้อมฝั่ง Client: ส่งคำขอ อัปเกรด/ใช้สกิล · วาดเอฟเฟกต์กระสุน/สกิลตามธาตุจากข้อมูลที่ Server ส่งมา (เจ้าของ: Client_UI_Scripter)
-- Client ไม่ได้คำนวณดาเมจหรือเงิน — TurretFx เป็นเอฟเฟกต์ล้วน (สเปก: design/element-skills.md หัวข้อ 2.3 · VFX)
-- ปุ่มลัด: สกิล = Q / ปุ่ม X (Gamepad) · อัปเกรด = U / ปุ่ม Y (Gamepad) · มือถือใช้ปุ่มบนจอ (CombatUI)
--
-- TurretFx (Server → Client): { { Kind, From, To, Color, Radius?, Duration?, Travel?, Spread?, Arc? } }
--   Kind = ค่า Fx ใน Config/Elements · Kind ที่ไม่รู้จัก → Tracer (ถ้าอยู่ใน Projectile.Instant) หรือลูกกลมวิ่ง
--   Travel = เวลาเดินทางจริงของกระสุนสกิล (Server ส่งมา) · ไม่มี = คำนวณจาก Config/Combat.Turret.Projectile (สูตรเดียวกับ Server)
-- ประสิทธิภาพ (มือถือ): ชิ้นส่วน Neon แบบ Anchored + Debris · จำกัดจำนวนต่ออีเวนต์ + จำนวนชิ้นพร้อมกัน · ไม่วาดที่ไกลกล้อง
--
-- อยากปรับ:
--   หน้าตากระสุน/สกิลของแต่ละธาตุ → ฟังก์ชัน drawXxx ในหมวด "วาดตาม Kind" (ขนาด = Vector3)
--   ความเร็วกระสุนปกติ → src/shared/Config/Combat.luau (Turret.Projectile) · ภาพกระสุนถึงเป้า = จังหวะที่ดาเมจเข้า
--   เพิ่มเอฟเฟกต์ชนิดใหม่ → เขียน drawXxx ใหม่ + เพิ่มใน DRAWERS + ตั้ง Fx ใน Config/Elements + ลงทะเบียนใน Projectile
--   เครื่องกระตุก → ลด MAX_ACTIVE_PARTS / MAX_FX_PER_EVENT / CULL_DISTANCE
--   เปลี่ยนปุ่มลัด → Enum.KeyCode ใน TurretController.Init (ข้อความบอกปุ่มบนจออยู่ที่ UI/CombatUI keyHint)
-- ใครใช้: UI/CombatUI (ปุ่มอัป/ปุ่มสกิล) · ตัวรับฝั่ง Server: src/server/Network/TurretHandler.luau
--
-- 📖 อ่านตามลำดับนี้:
--   1) TurretController.Init (ท้ายไฟล์) สร้างโฟลเดอร์ TurretEffects + ผูกปุ่มลัด Q/U → requestSkill / requestUpgrade → fire()
--   2) TurretController.Start ฟัง Remote TurretFx → onTurretFx
--      (ฝั่งส่ง = server/Services/TurretService (ยิงปกติ) + ElementSkillService (สกิล))
--   3) onTurretFx วนแต่ละรายการ → readFx ตรวจข้อมูล → isNearCamera ตัดของไกล → DRAWERS[Kind] (ไม่รู้จัก → Tracer/ลูกกลม)
--   4) drawXxx ประกอบจาก "ชิ้นพื้นฐาน": segment · projectile (วิ่งตรง) · flyPath (วิ่งโค้ง) · burst · ring · addTrail
--   5) ทุกชิ้นสร้างผ่าน makePart (นับโควตา + ลบเองเมื่อหมดเวลา)
-- ⚠️ ระวัง: ไฟล์นี้วาดอย่างเดียว ห้ามคำนวณดาเมจ/เงิน/การโดนเป้าที่นี่ — ผลจริงอยู่ที่ Server ทั้งหมด

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)

-- ===== ค่าคงที่ของเอฟเฟกต์ =====
-- ✏️ แก้ตรงนี้ถ้าอยากลดภาระเครื่อง (ลด MAX_*/CULL_DISTANCE)
local MAX_FX_PER_EVENT = 60 -- รายการที่วาดต่อ 1 อีเวนต์ (ที่เกินทิ้ง)
local MAX_ACTIVE_PARTS = 300 -- ชิ้นเอฟเฟกต์ที่มีอยู่พร้อมกันทั้งหมด
local MAX_LENGTH = 400 -- เส้นทาง From→To ยาวเกินนี้ไม่วาด (ข้อมูลผิดปกติ)
local MAX_COORD = 1e5 -- พิกัดที่ใหญ่เกินนี้ถือว่าข้อมูลเสีย (studs)
local CULL_DISTANCE = 450 -- ทั้งต้นและปลายไกลกล้องเกินนี้ = ไม่วาด
local MAX_KIND_LENGTH = 32
local MAX_RADIUS = 40 -- รัศมีระเบิด/วงสูงสุด (studs)
local MAX_DURATION = 8 -- เวลาอยู่/เวลาเดินทางนานสุด (วินาที)
local DEFAULT_COLOR = Color3.fromRGB(255, 220, 90)
local WHITE = Color3.new(1, 1, 1)
local AMBER = Color3.fromRGB(255, 190, 60)
local ROCK_COLOR = Color3.fromRGB(125, 95, 65)

-- ข้อมูลเอฟเฟกต์ 1 รายการ (หลังตรวจแล้ว) · `number?` = อาจไม่มี
type Fx = {
	Kind: string,
	From: Vector3,
	To: Vector3,
	Color: Color3,
	Radius: number?,
	Duration: number?,
	Travel: number?,
	Spread: number?,
	Arc: number?,
}

local effects: Folder
local active = 0

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

-- เปลี่ยนค่าของชิ้นแบบนุ่มนวลภายใน seconds วินาที
local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Linear, direction or Enum.EasingDirection.Out),
		goal
	):Play()
end

-- ---------------------------------------------------------------- ชิ้นพื้นฐาน

-- แท่งตรง from→to (เส้นกระสุน/ลำแสง) · fade = ค่อยๆ จางจนหาย
local function segment(from: Vector3, to: Vector3, thickness: number, color: Color3, lifetime: number, fade: boolean?): Part?
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

-- ลูกกลมขยายแล้วจาง (จุดระเบิด/จุดโดน) · radius = รัศมีตอนโตสุด
local function burst(position: Vector3, radius: number, color: Color3, seconds: number)
	local part = makePart(Enum.PartType.Ball, Vector3.one * 0.4, CFrame.new(position), color, seconds)
	if part then
		part.Transparency = 0.2
		tween(part, seconds, { Size = Vector3.one * radius * 2, Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end

-- วงแบนบนพื้น · Cylinder วางแกน X ขึ้นฟ้า
local function ring(position: Vector3, diameter: number, color: Color3, seconds: number, transparency: number): Part?
	local flat = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	local part = makePart(Enum.PartType.Cylinder, Vector3.new(0.15, diameter, diameter), flat, color, seconds)
	if part then
		part.Transparency = transparency
	end
	return part
end

-- วงกระแทกขยายจาก 0 → diameter แล้วจาง (ใช้ตอนหินตก/คลื่นแตก)
local function shockwave(position: Vector3, diameter: number, color: Color3, seconds: number)
	local wave = ring(position, 0.5, color, seconds, 0.15)
	if wave then
		tween(wave, seconds, { Size = Vector3.new(0.15, diameter, diameter), Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end

-- หางกระสุน (Trail) ติดกับชิ้น · width = ความกว้างหาง · lifetime = หางยาวแค่ไหน (วินาที)
local function addTrail(part: BasePart, color: Color3, width: number, lifetime: number)
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, width / 2, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -width / 2, 0)
	bottom.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = lifetime
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = part
end

-- เวลาเดินทางของภาพนี้: Server ส่ง Travel มา (สกิล) → ใช้เลย · ไม่มี → สูตรเดียวกับ Server (TurretMath.travelTime)
local function travelOf(fx: Fx): number
	if fx.Travel then
		return math.clamp(fx.Travel, 0, MAX_DURATION)
	end
	return TurretMath.travelTime(fx.Kind, (fx.To - fx.From).Magnitude)
end

-- กระสุนวิ่งตรง from→to ความเร็วคงที่ (tween) · คืน (เวลาเดินทาง, ชิ้น)
local function projectile(fx: Fx, shape: Enum.PartType, size: Vector3, color: Color3): (number, Part?)
	local travel = math.max(travelOf(fx), 0.04)
	local look = CFrame.lookAt(fx.From, fx.To)
	local part = makePart(shape, size, look, color, travel + 0.03)
	if part then
		tween(part, travel, { CFrame = look.Rotation + fx.To })
	end
	return travel, part
end

-- กระสุนวิ่งตามเส้นโค้ง: pathAt(alpha 0→1) = ตำแหน่ง · spin = หมุนตัวระหว่างบิน (เรเดียน/วิ) · ขยับทุกเฟรมจนถึง
local function flyPath(part: BasePart, travel: number, pathAt: (number) -> Vector3, spin: number?)
	task.spawn(function()
		local start = os.clock()
		while part.Parent do
			local elapsed = os.clock() - start
			local alpha = math.min(elapsed / travel, 1)
			local position = pathAt(alpha)
			local ahead = pathAt(math.min(alpha + 0.02, 1))
			local frame = if (ahead - position).Magnitude > 0.01 then CFrame.lookAt(position, ahead) else CFrame.new(position)
			if spin then
				frame *= CFrame.Angles(elapsed * spin, elapsed * spin * 0.6, 0)
			end
			part.CFrame = frame
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- เส้นโค้งพาราโบลา from→to สูง height ตรงกลาง
local function arcPath(from: Vector3, to: Vector3, height: number): (number) -> Vector3
	return function(alpha: number): Vector3
		return from:Lerp(to, alpha) + Vector3.new(0, 4 * height * alpha * (1 - alpha), 0)
	end
end

-- เส้นโค้งพัด: ออกจาก from เบนไปด้านข้าง spread องศา แล้วโค้งเข้าหา to (Bezier 2 จุด)
local function fanPath(from: Vector3, to: Vector3, spread: number): (number) -> Vector3
	local direction = to - from
	local control = from + (CFrame.Angles(0, math.rad(spread), 0) * direction) * 0.5
	return function(alpha: number): Vector3
		local a = from:Lerp(control, alpha)
		local b = control:Lerp(to, alpha)
		return a:Lerp(b, alpha)
	end
end

-- ---------------------------------------------------------------- วาดตาม Kind
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหน้าตากระสุน/สกิลของแต่ละธาตุ · fx.Color มาจาก Server (สีธาตุ / สีบอลไฟตามเลเวล)

-- Tracer: เส้นกระสุนธรรมดา (ป้อมที่ยังไม่เลือกธาตุ / Kind ที่ไม่รู้จัก)
local function drawTracer(fx: Fx)
	segment(fx.From, fx.To, 0.25, fx.Color, 0.06)
end

-- 🔥 Fireball (ไฟ ยิงปกติ): ลูกไฟ Ø1.4 + หางไฟ · ถึงเป้า = ระเบิดขนาดตาม Radius (Splash)
local function drawFireball(fx: Fx)
	local travel, part = projectile(fx, Enum.PartType.Ball, Vector3.one * 1.4, fx.Color)
	if part then
		addTrail(part, Color3.fromRGB(255, 70, 30), 1, 0.2)
	end
	local radius = math.clamp(fx.Radius or 2, 1, MAX_RADIUS)
	task.delay(travel, function()
		burst(fx.To, radius * 0.6, fx.Color, 0.25)
		burst(fx.To, 1.2, WHITE, 0.12)
	end)
end

-- 💧 WaterBolt (น้ำ ยิงปกติ): หยดน้ำ Ø0.8 + หางยาว · ถึงเป้า = กระเซ็นเล็ก
local function drawWaterBolt(fx: Fx)
	local travel, part = projectile(fx, Enum.PartType.Ball, Vector3.one * 0.8, fx.Color)
	if part then
		addTrail(part, fx.Color, 0.6, 0.3)
	end
	task.delay(travel, burst, fx.To, 1.2, fx.Color:Lerp(WHITE, 0.4), 0.15)
end

-- 🪨 Rock (ดิน ยิงปกติ): ก้อนหิน 1.6³ Slate โค้งลง (สูง 8) หมุนระหว่างบิน · ถึงเป้า = ฝุ่นอำพัน
local function drawRock(fx: Fx)
	local travel = math.max(travelOf(fx), 0.05)
	local part = makePart(Enum.PartType.Block, Vector3.one * 1.6, CFrame.new(fx.From), ROCK_COLOR, travel + 0.05)
	if part then
		part.Material = Enum.Material.Slate
		flyPath(part, travel, arcPath(fx.From, fx.To, fx.Arc or 8), 8)
	end
	task.delay(travel, burst, fx.To, 1.6, AMBER, 0.2)
end

-- 🌪️ WindBlade (ลม ยิงปกติ): ใบมีดลม Wedge บาง 0.2×1×2.5 ใส 0.3 (เร็วมาก)
local function drawWindBlade(fx: Fx)
	local _, part = projectile(fx, Enum.PartType.Wedge, Vector3.new(0.2, 1, 2.5), fx.Color)
	if part then
		part.Transparency = 0.3
	end
end

-- 🔥 FireVolley (สกิลลูกไฟพัด): ลูกไฟ Ø2 + หางแดง บินโค้งเป็นพัด (Spread) เข้าหาเป้า · ถึง = ลูกไฟขยาย Ø2→8 จาง 0.3 วิ
local function drawFireVolley(fx: Fx)
	local travel = math.max(travelOf(fx), 0.05)
	local part = makePart(Enum.PartType.Ball, Vector3.one * 2, CFrame.new(fx.From), fx.Color, travel + 0.05)
	if part then
		addTrail(part, Color3.fromRGB(235, 50, 30), 1.4, 0.3)
		flyPath(part, travel, fanPath(fx.From, fx.To, fx.Spread or 0))
	end
	task.delay(travel, function()
		burst(fx.To, 4, fx.Color, 0.3)
		if fx.Radius then
			ring(fx.To, math.clamp(fx.Radius, 1, MAX_RADIUS) * 2, fx.Color, 0.3, 0.6)
		end
	end)
end

-- 💧 Wave (สกิลคลื่นยักษ์): กำแพงน้ำ 10×6×2 Neon ฟ้าใส + โฟมขาวด้านบน วิ่งตามเลนไปหาบอส · ถึง = วงน้ำแตก Ø20 จาง
local function drawWave(fx: Fx)
	local travel = math.max(travelOf(fx), 0.1)
	local look = CFrame.lookAt(fx.From, fx.To)
	local wall = makePart(Enum.PartType.Block, Vector3.new(10, 6, 2), look, fx.Color, travel + 0.05)
	local foam = makePart(Enum.PartType.Block, Vector3.new(10.2, 0.6, 2.2), look * CFrame.new(0, 3.1, 0), WHITE, travel + 0.05)
	if wall then
		wall.Transparency = 0.4
		tween(wall, travel, { CFrame = look.Rotation + fx.To })
	end
	if foam then
		foam.Transparency = 0.2
		tween(foam, travel, { CFrame = (look.Rotation + fx.To) * CFrame.new(0, 3.1, 0) })
	end
	task.delay(travel, function()
		local splash = ring(fx.To, 4, fx.Color, 0.6, 0.3)
		if splash then
			tween(splash, 0.6, { Size = Vector3.new(0.15, 20, 20), Transparency = 1 }, Enum.EasingStyle.Quad)
		end
	end)
end

-- 🪨 Boulder (สกิลหินถล่ม): หิน Slate 5×5×5 โยนโค้ง (Arc) หมุนระหว่างบิน · ตก = วงแรงกระแทก Neon อำพัน Ø0→(Radius×2) ใน 0.4 วิ
local function drawBoulder(fx: Fx)
	local travel = math.max(travelOf(fx), 0.1)
	local part = makePart(Enum.PartType.Block, Vector3.one * 5, CFrame.new(fx.From), ROCK_COLOR, travel + 0.05)
	if part then
		part.Material = Enum.Material.Slate
		flyPath(part, travel, arcPath(fx.From, fx.To, fx.Arc or 20), 4)
	end
	local diameter = math.clamp(fx.Radius or 16, 1, MAX_RADIUS) * 2
	task.delay(travel, function()
		shockwave(fx.To, diameter, AMBER, 0.4)
		burst(fx.To, 3, ROCK_COLOR, 0.3)
	end)
end

-- 🌪️ GaleBlade (สกิลลมกรด 5 ดาบ): ใบลม Wedge Neon 0.3×2×4 + หาง
local function drawGaleBlade(fx: Fx)
	local _, part = projectile(fx, Enum.PartType.Wedge, Vector3.new(0.3, 2, 4), fx.Color)
	if part then
		part.Transparency = 0.3
		addTrail(part, fx.Color, 1.5, 0.15)
	end
end

-- 🌪️ WindCharge (ชาร์จลมกรด): วงแหวน Neon เขียว 3 วงหมุนรอบลำกล้อง เร็วขึ้นเรื่อยๆ ตลอด Duration
local function drawWindCharge(fx: Fx)
	local duration = math.clamp(fx.Duration or 1, 0.1, MAX_DURATION)
	local direction = fx.To - fx.From
	local basis = if direction.Magnitude > 0.01 then CFrame.lookAt(fx.From, fx.To) else CFrame.new(fx.From)
	local rings: { Part } = {}
	for index = 1, 3 do
		-- วงแหวนตั้งฉากกับลำกล้อง: Cylinder แกน X → หมุนให้แกนชี้ไปทางยิง
		local part = makePart(Enum.PartType.Cylinder, Vector3.new(0.12, 2 + index * 0.6, 2 + index * 0.6), basis, fx.Color, duration)
		if part then
			part.Transparency = 0.25
			table.insert(rings, part)
		end
	end
	if #rings == 0 then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while true do
			local elapsed = os.clock() - start
			if elapsed >= duration then
				break
			end
			-- ความเร็วหมุนเพิ่มตามเวลา (มุม ∝ เวลา²) · แต่ละวงเอียงต่างกันเล็กน้อย
			local angle = elapsed * elapsed * 12
			for index, part in rings do
				if part.Parent then
					part.CFrame = basis * CFrame.new(0, 0, -0.4 * index) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(angle * (1 + index * 0.3), 0, 0.25 * index)
				end
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Kind ที่ไม่มีฟังก์ชันวาด แต่เป็นกระสุนวิ่ง → ลูกกลมวิ่ง (ภาพถึงเป้าตรงกับจังหวะดาเมจ)
local function drawGenericProjectile(fx: Fx)
	local travel = projectile(fx, Enum.PartType.Ball, Vector3.one * 0.8, fx.Color)
	task.delay(travel, burst, fx.To, 1, fx.Color, 0.12)
end

-- ตารางจับคู่ ชื่อ Kind → ฟังก์ชันวาด (ชื่อต้องตรงกับ Fx ใน Config/Elements)
-- ✏️ เพิ่ม Kind ใหม่: เขียน drawXxx ข้างบน แล้วเพิ่มบรรทัด Xxx = drawXxx ที่นี่ (+ ลงทะเบียนใน Combat.Turret.Projectile)
local DRAWERS: { [string]: (Fx) -> () } = {
	Tracer = drawTracer,
	Fireball = drawFireball,
	WaterBolt = drawWaterBolt,
	Rock = drawRock,
	WindBlade = drawWindBlade,
	FireVolley = drawFireVolley,
	Wave = drawWave,
	Boulder = drawBoulder,
	GaleBlade = drawGaleBlade,
	WindCharge = drawWindCharge,
}
-- Kind ที่ From/To ใกล้กันได้ (ภาพที่จุดเดียว) → ไม่ตรวจความยาวเส้นขั้นต่ำ
local POINT_KINDS: { [string]: boolean } = {
	WindCharge = true,
}

-- ---------------------------------------------------------------- ตรวจข้อมูลจาก Server

-- ข้อมูลจากเครือข่ายเชื่อไม่ได้ 100% → ตรวจก่อนวาดทุกครั้ง · true ถ้าเป็น Vector3 ที่ไม่ใช่ NaN และไม่ไกลเกิน
local function validVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < MAX_COORD
		and math.abs(value.Y) < MAX_COORD
		and math.abs(value.Z) < MAX_COORD
end

-- คืนตัวเลขถ้าเป็นตัวเลขปกติ (ไม่ใช่ NaN/อนันต์) ไม่งั้น nil
local function optionalNumber(value: any): number?
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then
		return value
	end
	return nil
end

-- แปลงข้อมูลดิบ 1 รายการเป็น Fx ที่ปลอดภัย · ข้อมูลเสีย/เส้นยาวผิดปกติ → nil (ไม่วาด)
local function readFx(raw: any): Fx?
	if type(raw) ~= "table" then
		return nil
	end
	local from, to = raw.From, raw.To
	if not validVector(from) or not validVector(to) then
		return nil
	end
	local kind = if type(raw.Kind) == "string" and #raw.Kind <= MAX_KIND_LENGTH then raw.Kind else "Tracer"
	local length = (to - from).Magnitude
	if length > MAX_LENGTH or (length < 0.1 and not POINT_KINDS[kind]) then
		return nil
	end
	return {
		Kind = kind,
		From = from,
		To = to,
		Color = if typeof(raw.Color) == "Color3" then raw.Color else DEFAULT_COLOR,
		Radius = optionalNumber(raw.Radius),
		Duration = optionalNumber(raw.Duration),
		Travel = optionalNumber(raw.Travel),
		Spread = optionalNumber(raw.Spread),
		Arc = optionalNumber(raw.Arc),
	}
end

-- true ถ้าต้นหรือปลายเส้นอยู่ใกล้กล้องภายใน CULL_DISTANCE
local function isNearCamera(fx: Fx): boolean
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local eye = camera.CFrame.Position
	return (fx.From - eye).Magnitude <= CULL_DISTANCE or (fx.To - eye).Magnitude <= CULL_DISTANCE
end

-- รับรายการเอฟเฟกต์จาก Server (Remote TurretFx) → ตรวจ → วาดตาม Kind · เกินโควตาหยุดวาด
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
			-- ไม่มีในตาราง → โดนทันที = Tracer · กระสุนวิ่ง = ลูกกลมทั่วไป · pcall = วาดพังเกมไม่หยุด
			local draw = DRAWERS[fx.Kind]
			if not draw then
				draw = if travelOf(fx) > 0 then drawGenericProjectile else drawTracer
			end
			local ok, err = pcall(draw, fx)
			if not ok then
				warn(`[TurretController] วาด {fx.Kind} ล้มเหลว: {err}`)
			end
		end
	end
end

-- ---------------------------------------------------------------- คำขอไป Server + ปุ่มลัด

local TurretController = {}

-- ส่ง Remote ชื่อ name ไป Server (ไม่มีข้อมูลแนบ · Server ตัดสินเองว่าทำได้ไหม)
local function fire(name: string)
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer()
end

-- ขออัปเลเวลป้อม (ปุ่มบนจอ / U / Y) · Server เช็กเงินและหักเงินเอง
function TurretController.requestUpgrade()
	fire("UpgradeTurret")
end

-- ขอใช้สกิลธาตุ (ปุ่มบนจอ / Q / X) · Server เช็กธาตุ/ช็อต/คูลดาวน์/เป้าเอง
function TurretController.requestSkill()
	fire("UseTurretSkill")
end

-- ตอนเริ่มเกม: สร้างโฟลเดอร์ TurretEffects + ผูกปุ่มลัด
function TurretController.Init()
	effects = Instance.new("Folder")
	effects.Name = "TurretEffects"
	effects.Parent = workspace

	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนปุ่มลัด: Enum.KeyCode.Q / ButtonX (อย่าลืมแก้ keyHint ใน UI/CombatUI ด้วย)
	ContextActionService:BindAction("TurretSkill", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestSkill()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนปุ่มลัดอัปเกรด: Enum.KeyCode.U / ButtonY
	ContextActionService:BindAction("TurretUpgrade", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestUpgrade()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.U, Enum.KeyCode.ButtonY)
end

-- เริ่มฟังเอฟเฟกต์การยิงจาก Server
function TurretController.Start()
	local remote = Remotes.get("TurretFx") :: RemoteEvent
	remote.OnClientEvent:Connect(onTurretFx)
end

return TurretController
