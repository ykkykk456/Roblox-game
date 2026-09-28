-- ป้อมฝั่ง Client: ส่งคำขอ อัปเกรด/ใช้สกิล · วาดเอฟเฟกต์กระสุนตามคลาส/สายจากข้อมูลที่ Server ส่งมา (เจ้าของ: Client_UI_Scripter)
-- Client ไม่ได้คำนวณดาเมจหรือเงิน — TurretFx เป็นเอฟเฟกต์ล้วน (สเปก: design/turret-classes.md)
-- ปุ่มลัด: สกิล = Q / ปุ่ม X (Gamepad) · อัปเกรด = U / ปุ่ม Y (Gamepad) · มือถือใช้ปุ่มบนจอ (CombatUI)
--
-- TurretFx (Server → Client): { { Kind, From: Vector3, To: Vector3, Color: Color3, Radius: number?, Duration: number? } }
--   Kind = ค่า Fx ใน Config/Skill_class_default · Kind ที่ไม่รู้จัก → วาดเป็น Tracer
-- ประสิทธิภาพ (มือถือ): ชิ้นส่วน Neon แบบ Anchored + Debris · จำกัดจำนวนต่ออีเวนต์ + จำนวนชิ้นพร้อมกัน · ไม่วาดที่ไกลกล้อง
--
-- อยากปรับ:
--   หน้าตากระสุนของแต่ละคลาส/สาย → ฟังก์ชัน drawXxx ในหมวด "วาดตาม Kind" (ขนาด = Vector3 · ความเร็ว = ตัวเลขท้าย projectile เป็น studs/วินาที)
--   เพิ่มเอฟเฟกต์ชนิดใหม่ → เขียน drawXxx ใหม่ + เพิ่มใน DRAWERS + ตั้ง Fx ใน Config/Skill_class_default ให้ตรงชื่อ
--   เครื่องกระตุก → ลด MAX_ACTIVE_PARTS / MAX_FX_PER_EVENT / CULL_DISTANCE
--   เปลี่ยนปุ่มลัด → Enum.KeyCode ใน TurretController.Init (ข้อความบอกปุ่มบนจออยู่ที่ UI/CombatUI keyHint)
-- ใครใช้: UI/CombatUI (ปุ่มอัป/ปุ่มสกิล) · ตัวรับฝั่ง Server: src/server/Network/TurretHandler.luau
--
-- 📖 อ่านตามลำดับนี้:
--   1) TurretController.Init (ท้ายไฟล์) สร้างโฟลเดอร์ TurretEffects + ผูกปุ่มลัด Q/U → requestSkill / requestUpgrade → fire()
--   2) TurretController.Start ฟัง Remote TurretFx → ทุกครั้งที่ Server ส่งรายการเอฟเฟกต์มา จะเรียก onTurretFx
--      (ฝั่งส่ง = server/Services/TurretService: ป้อมยิงจริง แล้วแนบ Kind/From/To/Color ของคลาส-สาย)
--   3) onTurretFx วนแต่ละรายการ → readFx ตรวจข้อมูล (validVector / optionalNumber) → isNearCamera ตัดของไกล
--   4) เลือกฟังก์ชันวาดจาก DRAWERS[Kind] (เช่น "Bolt" → drawBolt) · ไม่รู้จัก → drawTracer
--   5) drawXxx ประกอบจาก "ชิ้นพื้นฐาน": segment (แท่งเส้น) · projectile (กระสุนวิ่ง) · burst (ลูกกลมระเบิด) · ring (วงบนพื้น)
--   6) ทุกชิ้นสร้างผ่าน makePart (นับโควตา + ลบเองเมื่อหมดเวลา) และขยับด้วย tween
-- ⚠️ ระวัง: ไฟล์นี้วาดอย่างเดียว ห้ามคำนวณดาเมจ/เงิน/การโดนเป้าที่นี่ — ผลจริงอยู่ที่ Server ทั้งหมด

-- บริการของ Roblox ที่ใช้: ContextActionService = ผูกปุ่มลัด · Debris = ลบของอัตโนมัติเมื่อครบเวลา
-- TweenService = เปลี่ยนค่า (ตำแหน่ง/ขนาด/ความใส) แบบค่อยๆ เป็นแอนิเมชัน
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ===== ค่าคงที่ของเอฟเฟกต์ =====
-- ✏️ แก้ตรงนี้ถ้าอยาก: ลดภาระเครื่อง (ลด MAX_*/CULL_DISTANCE) · เปลี่ยนสีสำรอง · ปรับลำแสงรุ้ง (BEAM_TIME/RAINBOW_STEPS)
-- (ตัวเลขที่มี 1e5 = 1 × 10⁵ = 100000)
local MAX_FX_PER_EVENT = 60 -- รายการที่วาดต่อ 1 อีเวนต์ (ที่เกินทิ้ง)
local MAX_ACTIVE_PARTS = 300 -- ชิ้นเอฟเฟกต์ที่มีอยู่พร้อมกันทั้งหมด
local MAX_LENGTH = 300 -- เส้นทาง From→To ยาวเกินนี้ไม่วาด (ข้อมูลผิดปกติ)
-- พิกัดที่ใหญ่เกินนี้ถือว่าข้อมูลเสีย (studs)
local MAX_COORD = 1e5
local CULL_DISTANCE = 450 -- ทั้งต้นและปลายไกลกล้องเกินนี้ = ไม่วาด
-- ความยาวชื่อ Kind สูงสุด (ตัวอักษร) · รัศมีหลุมดำสูงสุด (studs) · เวลาหลุมดำนานสุด (วินาที)
local MAX_KIND_LENGTH = 32
local MAX_RADIUS = 40
local MAX_DURATION = 8
-- สีสำรองเมื่อ Server ไม่ส่งสีมา · สีขาว · สีแกนหลุมดำ
local DEFAULT_COLOR = Color3.fromRGB(255, 220, 90)
local WHITE = Color3.new(1, 1, 1)
local VOID_COLOR = Color3.fromRGB(12, 6, 22)
-- ลำแสงรุ้ง (สาย Alchemist): อยู่นานกี่วินาที · เปลี่ยนสีกี่ครั้งระหว่างนั้น
local BEAM_TIME = 0.25
local RAINBOW_STEPS = 6

-- ข้อมูลเอฟเฟกต์ 1 รายการ (หลังตรวจแล้ว)

-- `type` = ประกาศรูปร่างของตาราง ให้ตัวตรวจโค้ดช่วยเตือนถ้าพิมพ์ชื่อช่องผิด (ไม่มีผลตอนรัน)
-- `number?` = เครื่องหมาย ? แปลว่า "อาจเป็น nil ได้" (ไม่ได้ส่งมาก็ได้)
type Fx = {
	Kind: string,
	From: Vector3,
	To: Vector3,
	Color: Color3,
	Radius: number?,
	Duration: number?,
}

-- โฟลเดอร์เก็บชิ้นเอฟเฟกต์ใน Workspace · จำนวนชิ้นที่มีอยู่ตอนนี้ · ตัวสุ่ม (ใช้ทำสายฟ้าหยัก)
-- ตัวแปรระดับไฟล์: ทุกฟังก์ชันในไฟล์นี้ใช้ร่วมกัน · effects ยังไม่มีค่าจนกว่า Init จะสร้าง
local effects: Folder
local active = 0
local random = Random.new()

-- ชิ้นเอฟเฟกต์ 1 ชิ้น · คืน nil เมื่อเกินโควตา (ผู้เรียกต้องรับมือ nil เสมอ)
local function makePart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, lifetime: number): Part?
	-- โควตา: มีชิ้นเยอะเกินแล้ว → ไม่สร้าง (กันเครื่องมือถือกระตุก)
	if active >= MAX_ACTIVE_PARTS then
		return nil
	end
	-- นับเพิ่ม 1 ชิ้น แล้วตั้งเวลาให้นับลดคืนเมื่อชิ้นหมดอายุ
	-- task.delay(วินาที, ฟังก์ชัน) = เรียกฟังก์ชันนั้นทีหลัง โดยไม่หยุดโค้ดบรรทัดถัดไป
	-- `active += 1` = ย่อของ active = active + 1
	active += 1
	task.delay(lifetime, function()
		active -= 1
	end)

	-- Instance.new("Part") = สร้างชิ้นส่วนใหม่ (ยังไม่อยู่ในโลก จนกว่าจะตั้ง .Parent)
	-- ตั้งให้: ลอยนิ่ง (Anchored) · ไม่ชน/ไม่โดนตรวจจับ/ไม่มีเงา → เบาเครื่องและไม่กวนการเล่น · Neon = เรืองแสง
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
	-- .Parent = ใส่ชิ้นเข้าไปในโฟลเดอร์ TurretEffects → ตอนนี้ผู้เล่นจึงเห็น
	part.Parent = effects
	-- Debris:AddItem(ของ, วินาที) = ลบของชิ้นนั้นทิ้งเองเมื่อครบเวลา (ไม่ต้องจำไว้ลบเอง)
	Debris:AddItem(part, lifetime)
	return part
end

-- เปลี่ยนค่าของชิ้นแบบนุ่มนวลภายใน seconds วินาที (style/direction ไม่ใส่ = เส้นตรง)
local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	-- TweenService:Create(ของ, TweenInfo, เป้าหมาย):Play() = ค่อยๆ เปลี่ยนค่าในตาราง goal ให้ถึงเป้าภายในเวลาที่กำหนด
	-- เช่น goal = { Transparency = 1 } → ค่อยๆ ใสจนหาย · EasingStyle = ลักษณะความเร็ว (Linear = คงที่, Quad = เร่ง/ผ่อน)
	-- `a or b` = ใช้ a ถ้ามีค่า ไม่งั้นใช้ b (ใช้ทำค่าเริ่มต้น)
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
	-- ความยาวเส้น = ระยะห่างของ 2 จุด (.Magnitude = ความยาวของเวกเตอร์) · สั้นมากจนมองไม่เห็น → ไม่สร้าง
	local length = (to - from).Magnitude
	if length < 0.05 then
		return nil
	end
	-- ทำแท่งยาวตามแกน Z: CFrame.lookAt(from, to) = วางที่ from หันหน้าไป to
	-- แล้วเลื่อนไปข้างหน้าครึ่งความยาว (-Z คือด้านหน้า) → แท่งอยู่กึ่งกลางระหว่าง from กับ to พอดี
	local part = makePart(
		Enum.PartType.Block,
		Vector3.new(thickness, thickness, length),
		CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2),
		color,
		lifetime
	)
	-- makePart อาจคืน nil (เกินโควตา) → ต้องเช็ก `if part` ก่อนใช้เสมอ
	if part and fade then
		tween(part, lifetime, { Transparency = 1 })
	end
	return part
end

-- ลูกกลมขยายแล้วจาง (จุดระเบิด/จุดโดน)
local function burst(position: Vector3, radius: number, color: Color3, seconds: number)
	-- เริ่มจากลูกเล็ก 0.4 แล้ว tween ให้โตเป็นเส้นผ่านศูนย์กลาง radius × 2 พร้อมจางหาย
	-- Vector3.one = (1, 1, 1) · คูณตัวเลข = ขนาดเท่ากันทุกแกน
	local part = makePart(Enum.PartType.Ball, Vector3.one * 0.4, CFrame.new(position), color, seconds)
	if part then
		part.Transparency = 0.2
		tween(part, seconds, { Size = Vector3.one * radius * 2, Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end

-- วงแบนบนพื้น (กระเซ็น) · Cylinder วางแกน X ขึ้นฟ้า
local function ring(position: Vector3, diameter: number, color: Color3, seconds: number, transparency: number): Part?
	-- Cylinder ของ Roblox ยาวตามแกน X → หมุน 90° (math.pi / 2 เรเดียน) รอบแกน Z ให้แกน X ชี้ขึ้น = วงแบนบนพื้น
	-- Size = (ความหนา 0.15, เส้นผ่านศูนย์กลาง, เส้นผ่านศูนย์กลาง)
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
	-- เวลาเดินทาง = ระยะ ÷ ความเร็ว · math.clamp(x, ต่ำสุด, สูงสุด) = บีบค่าให้อยู่ในช่วง (ไม่เร็ว/ช้าเกินไป)
	local travel = math.clamp((to - from).Magnitude / speed, 0.04, 0.6)
	-- สร้างกระสุนที่ from หันไปทาง to แล้ว tween ให้เลื่อนไปที่ to (look.Rotation + to = ทิศเดิม ตำแหน่งใหม่)
	local look = CFrame.lookAt(from, to)
	local part = makePart(shape, size, look, color, travel + 0.03)
	if part then
		tween(part, travel, { CFrame = look.Rotation + to })
	end
	return travel
end

-- ---------------------------------------------------------------- วาดตาม Kind
-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหน้าตากระสุนของแต่ละคลาส/สาย — รูปแบบตัวเลขที่พบบ่อย:
--   segment(from, to, ความหนา, สี, อายุวินาที, จางไหม)
--   projectile(from, to, รูปทรง, ขนาด Vector3, สี, ความเร็ว studs/วินาที)
--   burst(จุด, รัศมี, สี, วินาที) · ring(จุด, เส้นผ่านศูนย์กลาง, สี, วินาที, ความใส)
-- fx.Color มาจาก Server (สีคลาส/สาย หรือสีบอลไฟตามเลเวล) · อยากได้สีตายตัว → ใส่ Color3.fromRGB(...) แทน fx.Color

-- Tracer: เส้นกระสุนธรรมดา (ป้อมที่ยังไม่เลือกคลาส / Kind ที่ไม่รู้จัก)
local function drawTracer(fx: Fx)
	segment(fx.From, fx.To, 0.25, fx.Color, 0.06)
end

-- Gatling: ปืนกล (สาย Gatling)
local function drawGatling(fx: Fx)
	-- ยิงรัวมาก: เส้นบางอายุสั้นที่สุด
	segment(fx.From, fx.To, 0.12, fx.Color, 0.045)
end

-- Bolt: ลูกเวทกลม + แตกตอนถึง (คลาสนักเวท)
local function drawBolt(fx: Fx)
	-- ✏️ ลูกเวทขนาด 0.9 ความเร็ว 170 · ระเบิดรัศมี 1.2 นาน 0.15 วิ
	-- task.delay(travel, burst, ...) = รอจนกระสุนถึงเป้า แล้วเรียก burst(...) ด้วยค่าที่ต่อท้าย
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 0.9, fx.Color, 170)
	task.delay(travel, burst, fx.To, 1.2, fx.Color, 0.15)
end

-- Arrow: ลูกธนูยาวบาง (คลาสนักธนู)
local function drawArrow(fx: Fx)
	-- ✏️ ขนาด (กว้าง, สูง, ยาว) = (0.15, 0.15, 2.4) · ความเร็ว 230 (เร็วที่สุดในกลุ่ม)
	projectile(fx.From, fx.To, Enum.PartType.Block, Vector3.new(0.15, 0.15, 2.4), fx.Color, 230)
end

-- Dagger: มีดสั้น (คลาสนักฆ่า)
local function drawDagger(fx: Fx)
	-- ใบมีดแบนสั้น
	projectile(fx.From, fx.To, Enum.PartType.Block, Vector3.new(0.1, 0.55, 1.3), fx.Color, 170)
end

-- Shell: ลูกปืนใหญ่ + ระเบิดตอนถึง (คลาสปืนใหญ่)
local function drawShell(fx: Fx)
	-- ✏️ ลูกปืนใหญ่ขนาด 1.4 ช้ากว่า (120) · ระเบิดใหญ่รัศมี 2.5
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 1.4, fx.Color, 120)
	task.delay(travel, burst, fx.To, 2.5, fx.Color, 0.2)
end

-- Wind: เส้นลม (สายลม)
local function drawWind(fx: Fx)
	-- เส้นลมบาง ค้างนานกว่ากระสุนปกติเล็กน้อยแล้วจาง
	segment(fx.From, fx.To, 0.1, fx.Color, 0.15, true)
end

-- Lightning: สายฟ้า (สายสายฟ้า)
local function drawLightning(fx: Fx)
	-- สายฟ้าหยัก: แบ่งเป็นท่อนๆ แต่ละจุดต่อเบี่ยงแบบสุ่มตั้งฉากกับทิศยิง
	-- count = จำนวนท่อน (ทุก 5 studs = 1 ท่อน อย่างน้อย 3 มากสุด 8) · jitter = ระยะเบี่ยงสูงสุด
	-- ✏️ อยากให้หยักมากขึ้น → เพิ่ม 0.08 / 2.5 · อยากให้ท่อนถี่ขึ้น → ลด 5
	local delta = fx.To - fx.From
	local length = delta.Magnitude
	local count = math.clamp(math.floor(length / 5), 3, 8)
	local basis = CFrame.lookAt(fx.From, fx.To)
	local jitter = math.min(length * 0.08, 2.5)
	local previous = fx.From
	-- วนสร้างทีละท่อน: จุดถัดไป = จุดบนเส้นตรง + เบี่ยงซ้าย/ขวา (RightVector) และขึ้น/ลง (UpVector) แบบสุ่ม
	-- ท่อนสุดท้ายต้องจบที่เป้าพอดี จึงไม่เบี่ยง
	for index = 1, count do
		local point = fx.To
		if index < count then
			point = fx.From
				+ delta * (index / count)
				+ basis.RightVector * random:NextNumber(-jitter, jitter)
				+ basis.UpVector * random:NextNumber(-jitter, jitter)
		end
		-- ต่อท่อนจากจุดก่อนหน้า → จุดใหม่ แล้วจำจุดใหม่ไว้เป็นต้นท่อนถัดไป
		segment(previous, point, 0.18, fx.Color, 0.12)
		previous = point
	end
	burst(fx.To, 1.2, fx.Color, 0.12)
end

-- Beam: ลำแสงรุ้ง (สายนักแปรธาตุ)
local function drawBeam(fx: Fx)
	-- ลำแสงรุ้ง: หลายท่อนต่างสี แล้วหมุนเฉดสีระหว่างที่แสดง · แกนกลางสีขาว
	-- แบ่งเส้นเป็น 5 ท่อน · a:Lerp(b, t) = จุดระหว่าง a กับ b ที่สัดส่วน t (0 = a, 1 = b)
	-- Color3.fromHSV(เฉดสี 0–1, ความสด, ความสว่าง) → เฉดสีไล่ตามลำดับท่อน = รุ้ง
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
	-- `#ตาราง` = จำนวนช่องในตาราง · ไม่มีท่อนไหนถูกสร้าง (เกินโควตา) → ไม่ต้องหมุนสี
	if #parts == 0 then
		return
	end
	-- task.spawn = รันฟังก์ชันแยกไปอีกทาง (task.wait ข้างในจะไม่ทำให้ onTurretFx ค้าง)
	-- ทุกจังหวะเลื่อนเฉดสีไปเรื่อยๆ · `% 1` = เอาเศษ ให้เฉดวนกลับมาอยู่ใน 0–1
	-- `entry.part.Parent` เป็น nil = ชิ้นถูกลบไปแล้ว → ข้าม
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

-- Poison: ลูกพิษ (สายพิษ)
local function drawPoison(fx: Fx)
	-- ลูกพิษโค้งขึ้นแล้วตกใส่เป้า (2 ช่วง) + กระเซ็นเป็นวงเขียว
	-- apex = จุดสูงสุดของโค้ง: กึ่งกลางทาง ยกขึ้นตามระยะ (2–20 studs) · ✏️ ความเร็ว 70 / ความสูง 0.25
	local length = (fx.To - fx.From).Magnitude
	local travel = math.clamp(length / 70, 0.15, 0.6)
	local apex = (fx.From + fx.To) / 2 + Vector3.new(0, math.clamp(length * 0.25, 2, 20), 0)
	local ball = makePart(Enum.PartType.Ball, Vector3.one * 1.1, CFrame.new(fx.From), fx.Color, travel + 0.05)
	-- ครึ่งแรก: ลอยขึ้นไป apex (Out = ช้าลงตอนใกล้ยอด) · ครึ่งหลัง: ตกลงเป้า (In = เร่งตอนตก)
	if ball then
		local part = ball
		tween(part, travel / 2, { CFrame = CFrame.new(apex) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(travel / 2, function()
			if part.Parent then
				tween(part, travel / 2, { CFrame = CFrame.new(fx.To) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end
	-- ถึงเป้าแล้ว: วงพิษขยายจาก 1 → 7 studs พร้อมจาง + ลูกกลมเล็ก · ✏️ ขนาดวงกระเซ็น = 7
	task.delay(travel, function()
		local splash = ring(fx.To, 1, fx.Color, 0.35, 0.2)
		if splash then
			tween(splash, 0.35, { Size = Vector3.new(0.15, 7, 7), Transparency = 1 }, Enum.EasingStyle.Quad)
		end
		burst(fx.To, 1.5, fx.Color, 0.25)
	end)
end

-- BlackHole: หลุมดำ (สายมืด) · ขนาด/เวลามาจาก Radius/Duration ที่ Server ส่ง
local function drawBlackHole(fx: Fx)
	-- หลุมดำที่ To: แกนมืด + เปลือกเรืองแสง + วงแสดงรัศมี · โผล่ → เต้นเป็นจังหวะ → หดหายตอนหมดเวลา
	-- ขนาด/เวลาจริงมาจาก Config (Branches.Dark.Effect) ผ่าน Server · ไม่ส่งมา → ใช้ 8 studs / 3 วิ
	-- pulses = จำนวนครั้งที่เต้น ให้พอดีกับเวลาที่เหลือหลังโผล่และก่อนหด
	local radius = math.clamp(fx.Radius or 8, 1, MAX_RADIUS)
	local duration = math.clamp(fx.Duration or 3, 0.3, MAX_DURATION)
	local lifetime = duration + 0.05
	local core = math.clamp(radius * 0.5, 1.5, 7) -- เส้นผ่านศูนย์กลางแกน (ไม่บังจอเต็มรัศมี)
	local pulseTime = 0.4
	local pulses = math.max(0, math.floor((duration - 0.5) / (pulseTime * 2)))

	-- 3 ชิ้น: area = วงบนพื้นบอกรัศมีดาเมจ · shell = ลูกเรืองแสงโปร่ง · void = แกนดำด้าน (ไม่เรืองแสง)
	-- ✏️ ความใสของวง = 0.75 · ของเปลือก = 0.6 · สีแกน = VOID_COLOR ด้านบนไฟล์
	local area = ring(fx.To, radius * 2, fx.Color, lifetime, 0.75)
	local shell = makePart(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(fx.To), fx.Color, lifetime)
	local void = makePart(Enum.PartType.Ball, Vector3.one * 0.5, CFrame.new(fx.To), VOID_COLOR, lifetime)
	if void then
		void.Material = Enum.Material.SmoothPlastic
	end
	if shell then
		shell.Transparency = 0.6
	end

	-- เก็บชิ้นที่สร้างสำเร็จพร้อมขนาดเป้าหมาย ไว้ใน list เดียว จะได้วนสั่ง tween ทีเดียว
	local sized: { { part: Part, size: number } } = {}
	if shell then
		table.insert(sized, { part = shell, size = core * 1.35 })
	end
	if void then
		table.insert(sized, { part = void, size = core })
	end

	-- ช่วงที่ 1 (0.2 วิ): โผล่ขยายจากจุดเล็ก · Back = เด้งเกินนิดแล้วกลับ
	for _, entry in sized do
		tween(entry.part, 0.2, { Size = Vector3.one * entry.size }, Enum.EasingStyle.Back)
	end
	-- ช่วงที่ 2: เต้นหด-ขยาย · TweenInfo.new(เวลา, สไตล์, ทิศ, จำนวนซ้ำ, true = เล่นย้อนกลับ) → หดถึง 75% แล้วกลับ
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
	-- ช่วงที่ 3 (0.25 วิสุดท้าย): หดหาย + วงจาง · Debris จะลบชิ้นเองตอนครบ lifetime
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

-- Fireball: บอลไฟ (สายไฟ)
local function drawFireball(fx: Fx)
	-- บอลไฟสีตามเลเวล (Server ส่งสีมาใน Color) + ระเบิดเล็กตอนถึง
	-- ✏️ บอลไฟขนาด 1.8 ความเร็ว 95 (ช้าสุด ดูหนัก) · ตอนถึง: ระเบิดสีไฟรัศมี 3 + แกนขาว 1.5
	-- ⚠️ สีบอลไฟตามเลเวลตัดสินที่ Server (ClassMath.fireColor) — ที่นี่แค่ใช้ fx.Color ที่ได้รับ
	local travel = projectile(fx.From, fx.To, Enum.PartType.Ball, Vector3.one * 1.8, fx.Color, 95)
	task.delay(travel, function()
		burst(fx.To, 3, fx.Color, 0.25)
		burst(fx.To, 1.5, WHITE, 0.15)
	end)
end

-- ตารางจับคู่ ชื่อ Kind → ฟังก์ชันวาด (ชื่อต้องตรงกับ Fx ใน Config/Skill_class_default)
-- `{ [string]: (Fx) -> () }` = ตารางที่คีย์เป็นข้อความ ค่าเป็นฟังก์ชันที่รับ Fx (type hint เท่านั้น)
-- ✏️ แก้ตรงนี้ถ้าอยากเพิ่ม Kind ใหม่: เขียน drawXxx ข้างบน แล้วเพิ่มบรรทัด Xxx = drawXxx ที่นี่
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

-- ข้อมูลจากเครือข่ายเชื่อไม่ได้ 100% → ตรวจก่อนวาดทุกครั้ง
-- true ถ้าเป็น Vector3 ที่ไม่ใช่ NaN และไม่ไกลเกิน MAX_COORD
local function validVector(value: any): boolean
	-- typeof(x) = เหมือน type() แต่รู้จักชนิดของ Roblox ด้วย เช่น "Vector3", "Color3" (type() จะตอบแค่ "userdata")
	-- `value.X == value.X` ดูแปลกแต่ตั้งใจ: NaN (ค่าเสีย) เป็นค่าเดียวที่ไม่เท่ากับตัวเอง → กรอง NaN ออก
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
	-- ด่านที่ 1: ต้องเป็นตาราง · ด่านที่ 2: From/To ต้องเป็นพิกัดที่ใช้ได้
	if type(raw) ~= "table" then
		return nil
	end
	local from, to = raw.From, raw.To
	if not validVector(from) or not validVector(to) then
		return nil
	end
	-- `if เงื่อนไข then ค่าA else ค่าB` = เลือกค่าในบรรทัดเดียว (ไม่ใช่ if ปกติ) · Kind เสีย → ใช้ "Tracer"
	-- หลุมดำมีแค่จุดเดียว (From/To อาจใกล้กันมาก) จึงไม่ตรวจความยาวเส้น · อื่นๆ ต้องยาว 0.1–MAX_LENGTH
	local kind = if type(raw.Kind) == "string" and #raw.Kind <= MAX_KIND_LENGTH then raw.Kind else "Tracer"
	if kind ~= "BlackHole" then
		local length = (to - from).Magnitude
		if length < 0.1 or length > MAX_LENGTH then
			return nil
		end
	end
	-- สร้างตาราง Fx ใหม่ที่ใช้เฉพาะค่าที่ตรวจแล้ว (ไม่ส่ง raw ต่อตรงๆ) · สีเสีย → DEFAULT_COLOR
	return {
		Kind = kind,
		From = from,
		To = to,
		Color = if typeof(raw.Color) == "Color3" then raw.Color else DEFAULT_COLOR,
		Radius = optionalNumber(raw.Radius),
		Duration = optionalNumber(raw.Duration),
	}
end

-- true ถ้าต้นหรือปลายเส้นอยู่ใกล้กล้องภายใน CULL_DISTANCE (ไกลกว่านั้นไม่ต้องวาด)
local function isNearCamera(fx: Fx): boolean
	-- workspace.CurrentCamera = กล้องของผู้เล่นคนนี้ · ยังไม่มีกล้อง → วาดไว้ก่อน (ปลอดภัยกว่าไม่วาด)
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local eye = camera.CFrame.Position
	return (fx.From - eye).Magnitude <= CULL_DISTANCE or (fx.To - eye).Magnitude <= CULL_DISTANCE
end

-- รับรายการเอฟเฟกต์จาก Server (Remote TurretFx) → ตรวจ → วาดตาม Kind · เกินโควตาหยุดวาด
local function onTurretFx(list: any)
	-- Server ส่งมาเป็น list หลายรายการในครั้งเดียว (ป้อมหลายตัวยิงพร้อมกัน) · วนไม่เกิน MAX_FX_PER_EVENT
	if type(list) ~= "table" then
		return
	end
	for index = 1, math.min(#list, MAX_FX_PER_EVENT) do
		if active >= MAX_ACTIVE_PARTS then
			return
		end
		local fx = readFx(list[index])
		if fx and isNearCamera(fx) then
			-- หาฟังก์ชันวาดจากชื่อ Kind (ไม่มีในตาราง → Tracer)
			-- pcall(ฟังก์ชัน, ค่า) = เรียกแบบกัน error: ถ้าวาดพัง เกมไม่หยุด ได้ ok = false + ข้อความ err แทน
			local draw = DRAWERS[fx.Kind] or drawTracer
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
	-- ⚠️ ระวัง: ส่งแค่ "ขอ" ไม่แนบเงิน/เลเวล/ดาเมจ · Server เช็กเงิน คูลดาวน์ แล้วตัดสินเอง
	-- `:: RemoteEvent` = type hint บอกตัวตรวจโค้ดว่าเป็น RemoteEvent (ไม่มีผลตอนรัน)
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer()
end

-- ขออัปเลเวลป้อม (ปุ่มบนจอ / U / Y) · Server เช็กเงินและหักเงินเอง
function TurretController.requestUpgrade()
	fire("UpgradeTurret")
end

-- ขอใช้สกิลที่เลือกไว้ (ปุ่มบนจอ / Q / X) · Server เช็กคูลดาวน์เอง
function TurretController.requestSkill()
	fire("UseTurretSkill")
end

-- ตอนเริ่มเกม: สร้างโฟลเดอร์ TurretEffects + ผูกปุ่มลัด
function TurretController.Init()
	-- โฟลเดอร์ใน workspace ของเครื่องนี้เท่านั้น (Client สร้าง = คนอื่นไม่เห็น ไม่กระทบ Server)
	effects = Instance.new("Folder")
	effects.Name = "TurretEffects"
	effects.Parent = workspace

	-- ContextActionService:BindAction(ชื่อ, ฟังก์ชัน, สร้างปุ่มมือถือไหม, ปุ่ม...) = ผูกปุ่มลัด
	--   ฟังก์ชันถูกเรียกทั้งตอนกดและปล่อย → เช็ก Begin = ทำงานตอนกดลงเท่านั้น
	--   return Sink = "กินปุ่มนี้แล้ว" ไม่ส่งต่อให้ระบบอื่น · false = ไม่สร้างปุ่มบนจอมือถือ (ใช้ปุ่มของ CombatUI แทน)
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนปุ่มลัด: Enum.KeyCode.Q / ButtonX (อย่าลืมแก้ keyHint ใน UI/CombatUI ด้วย)
	-- ปุ่มลัดสกิล: Q (คีย์บอร์ด) / X (Gamepad)
	ContextActionService:BindAction("TurretSkill", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestSkill()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนปุ่มลัดอัปเกรด: Enum.KeyCode.U / ButtonY
	-- ปุ่มลัดอัปเกรด: U (คีย์บอร์ด) / Y (Gamepad)
	ContextActionService:BindAction("TurretUpgrade", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TurretController.requestUpgrade()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.U, Enum.KeyCode.ButtonY)
end

-- เริ่มฟังเอฟเฟกต์การยิงจาก Server
function TurretController.Start()
	-- OnClientEvent:Connect(ฟังก์ชัน) = "ทุกครั้งที่ Server ส่ง TurretFx มา ให้เรียก onTurretFx"
	-- (Start ถูกเรียกหลัง Init ของทุกโมดูล → effects สร้างเสร็จแล้วก่อนเริ่มวาด) [Verified: init.client.luau]
	local remote = Remotes.get("TurretFx") :: RemoteEvent
	remote.OnClientEvent:Connect(onTurretFx)
end

return TurretController
