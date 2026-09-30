-- มอนเล็ก/กลางแบบ Tower Defense (เจ้าของ: Gameplay_Scripter) · ยืนยัน 2026-09-26 แทนการเดินสุ่ม
-- เลนละช่อง: เกิดที่จุดบอส → เดินตรงไปหาป้อมของช่องนั้น · ผังจากแมพ (Tag BossSpawn/TurretN) หรือผังวงกลมเดิม (Config/Map.Lane)
-- ปล่อยเป็น wave: เลนละ Combat.Monster.WaveSize ตัว ทยอยออกทีละตัว · ทั้ง wave ตาย/ถึงปลายทางหมด → พัก WaveDelay → wave ถัดไป
-- ถึงปลายเลนแล้วหายไป ไม่มีรางวัล · ปล่อยเฉพาะเลนที่มีเจ้าของ (Combat.Monster.AllLanesForTest = true → ทุกเลน)
-- ระหว่างตีบอส: หยุดปล่อยมอนทุกเลน (ตัวที่เดินอยู่แล้วเดินต่อ) · บอสจบ → wave เดิมปล่อยต่อจากที่ค้างไว้ (ยืนยัน 2026-09-26)
-- ตำแหน่ง/HP/ผลการตาย คำนวณที่ Server ทั้งหมด · ตายแล้วแบ่งเงินตามสัดส่วนดาเมจ
-- ความสูง (ผังจากแมพ): วัดพื้นทีละช่วงตามเลนตอนเกิด (laneHeights) · มอนเดินติดพื้น ไม่ปีนหลังคา/แท่นป้อม (แก้ 2026-09-30)
-- หน้าตา: สัตว์บล็อกทรงกล่อง (ตัว หู ตา ปาก) สไตล์ voxel · [Proposed] ยังไม่มีอนิเมชันนอกจากเด้งตอนเดิน
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • จำนวนมอนต่อ wave / ระยะห่างการเกิด / เวลาพักระหว่าง wave → Combat.Monster.WaveSize / SpawnGap / WaveDelay
--   • ชนิดมอน (HP, ความเร็ว, ขนาด, โอกาสเกิด, สี) → Combat.Monster.Types + TypeOrder (src/shared/Config/Combat.luau)
--   • ให้มอนออกทุกเลนตอนเทส → Combat.Monster.AllLanesForTest (เกมจริงตั้ง false)
--   • เงินต่อมอน → Economy.MonsterReward / MonsterRewardMultiplier (src/shared/Config/Economy.luau)
--   • ความกว้าง/ระยะเลน → Map.Lane (ผังเดิม) · Map.Layout.LaneStart / LaneStopBefore (ผังจาก Tag) ใน src/shared/Config/Map.luau
--   • การวัดพื้นตามเลน (ผังจาก Tag) → Map.Layout.FloorSampleStep / FloorMaxClimb / FloorProbeDepth
--   • หน้าตามอน (หู ตา ปาก) → ฟังก์ชัน makeBody ในไฟล์นี้ (แก้ได้ปลอดภัย ไม่มีผลกับเกมเพลย์)
--
-- คุยกับไฟล์ไหนบ้าง:
--   • BaseService — ช่องไหนมีเจ้าของ (ปล่อยมอนเลนนั้น) · BossService — มีบอสอยู่ไหม (พักปล่อยมอน)
--   • LayoutService — จุดบอส/แท่นป้อม/พื้นจากแมพ · Wallet — แจกเงินตอนมอนตาย
--   • TurretService / TurretElementService / ElementSkillService — เรียก getAlive, positionOf, damage เพื่อเล็งและทำดาเมจ
--     (monster.slot = เลขเลน/ช่อง · TurretService ให้ป้อมยิงเฉพาะมอนที่ slot ตรงกับป้อม)
--   • ธาตุป้อม (design/element-skills.md) เรียก slow / knockback / pullToward เพื่อหน่วง/ผลัก/ดูดมอน
--     วิธีทำ: มอนเดินตามเวลา (legStart) → "เลื่อน legStart ไปข้างหน้า" = มอนถอยหลัง/ช้าลง โดยไม่ต้องขยับโมเดลเอง

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local LayoutService = require(script.Parent.LayoutService)
local Wallet = require(script.Parent.Wallet)

-- ===== ชนิดข้อมูล =====
-- Monster = มอน 1 ตัว (hp เลือดตอนนี้ · damageBy = ใครตีไปเท่าไร ใช้แบ่งเงิน)
export type Monster = {
	model: Model,
	part: BasePart, -- ตัวหลัก (ชิ้นอื่นเชื่อมกับชิ้นนี้)
	bar: Frame,
	kind: string,
	slot: number,
	hp: number,
	maxHp: number,
	speed: number,
	-- เดินเส้นตรงจาก from ไป to (ระดับพื้น) เริ่มที่ legStart ใช้เวลา legTime วินาที · lift = ความสูงตัวจากพื้น
	from: Vector3,
	to: Vector3,
	legStart: number,
	legTime: number,
	lift: number,
	-- ผังจากแมพ: ความสูงพื้นตามเลน วัดทีละช่วงเท่าๆ กันจาก from ถึง to (laneHeights) · nil = ผังเดิม (ขั้นแอ่ง)
	heights: { number }?,
	alive: boolean,
	damageBy: { [Player]: number },
	-- ช้าลง: slowAmount (0.2 = ช้าลง 20% · 1 = หยุดเดิน/แช่แข็ง) จนถึงเวลา slowUntil (os.clock) · 0 = ไม่ช้า
	slowAmount: number,
	slowUntil: number,
}

-- Wave = สถานะการปล่อยมอนของ 1 เลน
type Wave = {
	index: number, -- wave ที่เท่าไรของเลนนี้
	toSpawn: number, -- ยังเหลือปล่อยอีกกี่ตัว
	nextSpawnAt: number,
	restUntil: number?, -- ตั้งค่าเมื่อ wave จบ (ไม่มีมอนเหลือ)
}

-- ===== สถานะระหว่างเกม (ระบบใช้เอง) =====
-- monsters = มอนทุกตัวในแมพ · waves[ช่อง] = wave ของเลนนั้น · folder = Workspace.Monsters · rng = ตัวสุ่ม
local monsters: { Monster } = {}
local waves: { [number]: Wave } = {}
local folder: Folder
local rng = Random.new()

-- ===== สร้างมอน =====
-- สุ่มชนิดมอนตาม Weight (Weight 3 กับ 1 = ตัวแรกออกบ่อยกว่า 3 เท่า) · คืนชื่อชนิด เช่น "Small"
local function pickKind(): string
	local kinds = Combat.Monster.Types
	local total = 0
	for _, id in Combat.Monster.TypeOrder do
		total += kinds[id].Weight
	end
	local roll = rng:NextNumber() * total
	for _, id in Combat.Monster.TypeOrder do
		roll -= kinds[id].Weight
		if roll < 0 then
			return id
		end
	end
	return Combat.Monster.TypeOrder[1]
end

-- สร้างชิ้นกล่อง 1 ชิ้นของตัวมอน (ชน/แตะ/ยิง ray ไม่โดน ไม่มีเงา = เบาเครื่อง)
local function voxel(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- สัตว์บล็อก: ตัวกล่อง + หู 2 + ตา 2 + ปาก · หันหน้าไปทาง −Z ของตัวหลัก
local function makeBody(size: number, color: Color3): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = "Monster"

	local body = voxel(model, "Body", Vector3.new(size, size * 0.8, size), color)
	body.Anchored = true
	model.PrimaryPart = body

	-- ติดชิ้นประดับกับตัวหลัก: ขนาด/ตำแหน่งเป็นสัดส่วนของ size (มอนตัวใหญ่ → หูตาใหญ่ตาม)
	local function attach(name: string, partSize: Vector3, offset: Vector3, partColor: Color3)
		local piece = voxel(model, name, partSize * size, partColor)
		piece.Anchored = false
		piece.Massless = true
		piece.CFrame = body.CFrame * CFrame.new(offset * size)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = piece
		weld.Parent = piece
	end

	local dark = Color3.fromRGB(28, 24, 24)
	local ear = color:Lerp(Color3.new(0, 0, 0), 0.15)
	attach("EarL", Vector3.new(0.22, 0.22, 0.16), Vector3.new(-0.32, 0.51, 0.1), ear)
	attach("EarR", Vector3.new(0.22, 0.22, 0.16), Vector3.new(0.32, 0.51, 0.1), ear)
	attach("EyeL", Vector3.new(0.14, 0.18, 0.04), Vector3.new(-0.2, 0.08, -0.51), dark)
	attach("EyeR", Vector3.new(0.14, 0.18, 0.04), Vector3.new(0.2, 0.08, -0.51), dark)
	attach("Mouth", Vector3.new(0.5, 0.14, 0.04), Vector3.new(0, -0.2, -0.51), Color3.fromRGB(245, 240, 232))

	-- หลอดเลือดลอยเหนือหัว (bar = แถบสีเขียว หดตามเลือด) · ไกลเกิน 120 studs ไม่แสดง
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 6)
	gui.StudsOffset = Vector3.new(0, size, 0)
	gui.MaxDistance = 120
	gui.Parent = body

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(96, 186, 84)
	bar.BorderSizePixel = 0
	bar.Parent = back

	return model, body, bar
end

-- ===== ตำแหน่ง/พื้น =====
-- ความสูงผิวพื้นที่รัศมี r (แอ่งกลางแมพลึกเป็นขั้น)
local function groundAt(r: number): number
	local depth = 0
	for _, step in Map.Pit.Steps do
		if r < step.Outer then
			depth = step.Depth
		end
	end
	return Map.GroundY - depth
end

-- ค่ากลางของ 3 ตัวเลข (ใช้ตัดค่าโดดของพื้น เช่น ม้านั่ง/รั้วเตี้ยจุดเดียว)
local function median3(a: number, b: number, c: number): number
	return math.max(math.min(a, b), math.min(math.max(a, b), c))
end

-- ความสูงพื้นตามเลน (ผังจากแมพ) จาก from ถึง to · startY = พื้นจุดบอส (เชื่อได้ บอสยืนตรงนั้น)
-- เดินวัดทีละ FloorSampleStep studs: แต่ละจุดยิงลำแสงจาก "พื้นจุดก่อนหน้า + FloorMaxClimb" ลงมา (LayoutService.laneFloorAt)
--   → ของที่สูงเหนือทางเดิน (หลังคา ต้นไม้ แท่นป้อม) ไม่ถูกนับเป็นพื้น · ไม่เจอพื้น = ใช้ความสูงจุดก่อนหน้า
-- แล้วเกลี่ยด้วยค่ากลาง 3 จุด ตัดสิ่งกีดขวางเตี้ยจุดเดียว
-- ตัวอย่าง: เลนยาว 100 · Step 5 → วัด 21 จุด
-- สาเหตุบั๊กเดิม (มอนลอยขึ้นฟ้า): วัดแค่ต้นเลน/ปลายเลนด้วย floorAt ที่ยิงจาก Y = 1000 → ได้ "ของชิ้นบนสุด" (แท่นป้อม/หลังคา/ต้นไม้)
--   แล้วไล่ความสูงเป็นเส้นตรง → มอนค่อยๆ ลอยสูงขึ้นตลอดเลน
local function laneHeights(from: Vector3, to: Vector3, startY: number): { number }
	local layout = Map.Layout
	local length = (to - from).Magnitude
	local count = math.max(2, math.ceil(length / layout.FloorSampleStep) + 1)
	local raw: { number } = {}
	local previous = startY
	for index = 1, count do
		local point = from:Lerp(to, (index - 1) / (count - 1))
		local y = LayoutService.laneFloorAt(point, previous + layout.FloorMaxClimb)
		if y then
			previous = y
		end
		raw[index] = previous
	end
	-- เกลี่ยค่าโดด: แต่ละจุด = ค่ากลางของตัวเองกับเพื่อนบ้าน (หัว/ท้ายใช้ 3 จุดแรก/สุดท้าย) · วัดได้ไม่ถึง 3 จุด = ใช้ค่าดิบ
	if count < 3 then
		return raw
	end
	local heights: { number } = {}
	for index = 1, count do
		local center = math.clamp(index, 2, count - 1)
		heights[index] = median3(raw[center - 1], raw[center], raw[center + 1])
	end
	return heights
end

-- ปล่อยมอน 1 ตัวที่ต้นเลนของช่อง slot แล้วเพิ่มเข้า monsters · เรียกจาก stepWave
local function spawnMonster(slot: number)
	local kind = pickKind()
	local def = Combat.Monster.Types[kind]
	local lane = Map.Lane
	-- แต่ละตัวเดินเยื้องซ้าย/ขวาในเลนแบบสุ่ม ไม่ให้ซ้อนเป็นเส้นเดียว
	local offset = rng:NextNumber(-1, 1) * lane.HalfWidth
	local from = MapMath.point(slot, lane.Start, offset)
	local to = MapMath.point(slot, lane.End, offset)
	local heights: { number }? = nil
	if LayoutService.hasLayout() then
		-- ผังจากแมพ (Tag): เลน = จากจุดบอสตรงไปหาแท่นป้อมของช่องนี้ หยุดก่อนถึงแท่น
		local layout = Map.Layout
		local boss = LayoutService.bossCenter()
		local turret = LayoutService.turretTop(slot)
		local flatBoss = Vector3.new(boss.X, 0, boss.Z)
		local toward = Vector3.new(turret.X, 0, turret.Z) - flatBoss
		local dir = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, 1)
		local side = Vector3.new(-dir.Z, 0, dir.X) * offset
		local length = math.max(toward.Magnitude - layout.LaneStopBefore, layout.LaneStart + 1)
		from = flatBoss + dir * layout.LaneStart + side
		to = flatBoss + dir * length + side
		-- ความสูงพื้นตามเลน เริ่มจากพื้นจุดบอส (boss.Y) · เดิมใช้ floorAt ต้น/ปลายเลน = สาเหตุมอนลอย (ดู laneHeights)
		heights = laneHeights(from, to, boss.Y)
	end
	local lift = def.Size * 0.4

	local model, part, bar = makeBody(def.Size, def.Color)
	-- ย้ายทั้งโมเดล (ทุกชิ้นพร้อมกัน) ก่อนเข้า workspace · ถ้าย้ายแค่ตัวหลัก WeldConstraint จะจำระยะผิด
	-- แล้วหู/ตา/ปากลอยแยกจากตัว (บั๊กที่เจอ 2026-09-26)
	local startGround = if heights then heights[1] else groundAt(from.Magnitude)
	model:PivotTo(CFrame.lookAt(from, to) + Vector3.new(0, startGround + lift, 0))
	model.Parent = folder

	local monster: Monster = {
		model = model,
		part = part,
		bar = bar,
		kind = kind,
		slot = slot,
		hp = def.Hp,
		maxHp = def.Hp,
		speed = def.Speed,
		from = from,
		to = to,
		legStart = os.clock(),
		legTime = (to - from).Magnitude / def.Speed,
		lift = lift,
		heights = heights,
		alive = true,
		damageBy = {},
		slowAmount = 0,
		slowUntil = 0,
	}
	table.insert(monsters, monster)
end

-- ===== รางวัล / นับมอน =====
-- มอนตาย: แบ่งเงิน (MonsterReward × ตัวคูณชนิด) ให้ทุกคนที่ตีตามสัดส่วนดาเมจ
local function reward(monster: Monster)
	local total = 0
	for _, amount in monster.damageBy do
		total += amount
	end
	if total <= 0 then
		return
	end
	local value = Economy.MonsterReward * (Economy.MonsterRewardMultiplier[monster.kind] or 1)
	for player, amount in monster.damageBy do
		Wallet.earn(player, value * amount / total)
	end
end

-- นับมอนที่ยังมีชีวิตในเลน slot (ใช้เช็กว่า wave จบหรือยัง)
local function aliveIn(slot: number): number
	local count = 0
	for _, monster in monsters do
		if monster.alive and monster.slot == slot then
			count += 1
		end
	end
	return count
end

-- ===== API ให้ไฟล์อื่นเรียก =====
local MonsterService = {}

-- มอนที่ยังมีชีวิต (อ่านอย่างเดียว)
function MonsterService.getAlive(): { Monster }
	return monsters
end

-- ตำแหน่งมอนตอนเวลา now: คำนวณจากเวลาที่เดินมาแล้ว (ไม่ต้องขยับโมเดลจริงก็รู้ตำแหน่ง) · t = 0 ต้นเลน → 1 ปลายเลน
function MonsterService.positionOf(monster: Monster, now: number): Vector3
	local t = if monster.legTime > 0 then math.clamp((now - monster.legStart) / monster.legTime, 0, 1) else 1
	local flat = monster.from:Lerp(monster.to, t)
	local ground
	local heights = monster.heights
	if heights then
		-- ผังจากแมพ: หาช่วงที่มอนอยู่ (ระหว่างจุดวัด index กับ index + 1) แล้วไล่ความสูงเป็นเส้นตรงในช่วงนั้น
		-- ตัวอย่าง: วัด 21 จุด · t = 0.5 → x = 10 → อยู่ที่จุดที่ 11 พอดี
		local x = t * (#heights - 1)
		local index = math.min(math.floor(x), #heights - 2)
		local a, b = heights[index + 1], heights[index + 2]
		ground = a + (b - a) * (x - index)
	else
		ground = groundAt(flat.Magnitude)
	end
	return Vector3.new(flat.X, ground + monster.lift, flat.Z)
end

-- ทำดาเมจ amount ใส่มอน (จด player ไว้แบ่งเงิน) · เลือดหมด = ลบโมเดล + แจกเงิน · เรียกจาก TurretService/TurretElementService
function MonsterService.damage(monster: Monster, player: Player, amount: number)
	if not monster.alive then
		return
	end
	local applied = math.min(amount, monster.hp)
	monster.hp -= applied
	monster.damageBy[player] = (monster.damageBy[player] or 0) + applied
	monster.bar.Size = UDim2.fromScale(math.max(monster.hp / monster.maxHp, 0), 1)
	if monster.hp <= 0 then
		monster.alive = false
		monster.model:Destroy()
		reward(monster)
	end
end

-- ===== ผลจากป้อมธาตุ: ช้าลง / ถอย / ดูด (design/element-skills.md) =====
-- ช้าลง amount (0–1) นาน seconds · ติดซ้ำ = ใช้ค่าที่แรงกว่า และเวลาที่ยาวกว่า (ไม่ซ้อนกันจนหยุดถาวร)
-- ตัวอย่าง: slow(มอน, 0.2, 1.5) = เดินเหลือ 80% นาน 1.5 วิ · slow(มอน, 1, 2) = หยุดเดิน 2 วิ (แช่แข็ง)
function MonsterService.slow(monster: Monster, amount: number, seconds: number)
	if not monster.alive or amount ~= amount or seconds ~= seconds then
		return
	end
	local now = os.clock()
	amount = math.clamp(amount, 0, 1)
	if now >= monster.slowUntil then
		monster.slowAmount = amount
	else
		monster.slowAmount = math.max(monster.slowAmount, amount)
	end
	monster.slowUntil = math.max(monster.slowUntil, now + math.max(seconds, 0))
end

-- ผลักมอนถอยกลับไปทางต้นเลน studs หน่วย · ไม่ถอยเลยจุดเกิด
-- วิธีทำ: เลื่อนเวลาเริ่มเดิน (legStart) ไปข้างหน้า = มอน "เพิ่งเดินมาได้น้อยลง" → ตำแหน่งถอยหลัง
-- ตัวอย่าง: มอนเร็ว 8 studs/วิ ถอย 4 studs → legStart + 0.5 วิ
function MonsterService.knockback(monster: Monster, studs: number)
	if not monster.alive or studs ~= studs or studs <= 0 or monster.speed <= 0 then
		return
	end
	monster.legStart = math.min(monster.legStart + studs / monster.speed, os.clock())
end

-- ดูดมอนเข้าหาจุด point ตามแนวเลน (ไม่เกิน studs หน่วยต่อครั้ง) · ใช้กับหลุมดำ
-- เลนเป็นเส้นตรง from → to จึงเลื่อนได้แค่ "หน้า/หลัง" ตามเลน (ไม่หลุดออกนอกเลน)
function MonsterService.pullToward(monster: Monster, point: Vector3, studs: number)
	if not monster.alive or studs ~= studs or studs <= 0 or monster.legTime <= 0 then
		return
	end
	local now = os.clock()
	local lane = monster.to - monster.from
	local length = Vector3.new(lane.X, 0, lane.Z).Magnitude
	if length < 0.1 then
		return
	end
	-- t = ตำแหน่งตามเลน 0 (ต้นเลน) → 1 (ปลายเลน) · tPoint = ตำแหน่งของจุดดูดบนเลนเดียวกัน
	local flatDir = Vector3.new(lane.X, 0, lane.Z) / length
	local offset = point - monster.from
	local tPoint = math.clamp((offset.X * flatDir.X + offset.Z * flatDir.Z) / length, 0, 1)
	local t = math.clamp((now - monster.legStart) / monster.legTime, 0, 1)
	local step = studs / length
	local newT = t + math.clamp(tPoint - t, -step, step)
	-- กันดูดจนถึงปลายเลน (= หายไปหน้าป้อม) · 0.98 = เผื่อไว้นิดหน่อย
	newT = math.clamp(newT, 0, 0.98)
	monster.legStart = now - newT * monster.legTime
end

-- ===== ลูปเดิน + ลูปปล่อย wave =====
-- Init: สร้างโฟลเดอร์ Monsters + ขยับมอนทุกเฟรม (Heartbeat) · วนจากท้ายไปหน้าเพื่อลบออกจากรายการได้ระหว่างวน
function MonsterService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace

	-- lastBeat = เวลาเฟรมก่อน (ใช้คิดว่ามอนที่โดนช้าลงต้อง "เสียเวลาเดิน" ไปเท่าไรในเฟรมนี้)
	local lastBeat = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.min(now - lastBeat, 0.5) -- เซิร์ฟกระตุกนานๆ ไม่ให้มอนถอยหลังก้อนใหญ่
		lastBeat = now
		for index = #monsters, 1, -1 do
			local monster = monsters[index]
			-- ช้าลง: เลื่อน legStart ตาม dt × ความช้า (1 = หยุดนิ่ง) · หมดเวลา = เดินปกติ
			if monster.alive and now < monster.slowUntil then
				monster.legStart = math.min(monster.legStart + dt * monster.slowAmount, now)
			end
			if not monster.alive then
				table.remove(monsters, index)
			elseif now >= monster.legStart + monster.legTime then
				-- ถึงปลายเลน (หน้าป้อม) → หายไป ไม่มีรางวัล
				monster.alive = false
				monster.model:Destroy()
				table.remove(monsters, index)
			else
				local position = MonsterService.positionOf(monster, now)
				local direction = monster.to - monster.from
				-- hop = เด้งขึ้นลงตอนเดิน (เร็วตามความเร็วมอน สูงสุด 0.4 studs) เฉพาะภาพ ไม่มีผลกับการเล็ง
				local hop = math.abs(math.sin(now * monster.speed * 1.5)) * 0.4
				local lifted = position + Vector3.new(0, hop, 0)
				monster.part.CFrame = CFrame.lookAt(lifted, lifted + direction)
			end
		end
	end)
end

-- คุมจังหวะ wave ของเลนเดียว
-- ไม่มี wave → เริ่ม wave 1 · ยังเหลือต้องปล่อย → ปล่อยทีละตัวทุก SpawnGap · ปล่อยครบและตายหมด → พัก WaveDelay แล้วเริ่ม wave ถัดไป
local function stepWave(slot: number, now: number)
	local config = Combat.Monster
	local wave = waves[slot]
	if not wave then
		waves[slot] = { index = 1, toSpawn = config.WaveSize, nextSpawnAt = now }
		return
	end
	if wave.toSpawn > 0 then
		if now >= wave.nextSpawnAt then
			spawnMonster(slot)
			wave.toSpawn -= 1
			wave.nextSpawnAt = now + config.SpawnGap
		end
	elseif aliveIn(slot) == 0 then
		if not wave.restUntil then
			wave.restUntil = now + config.WaveDelay
		elseif now >= wave.restUntil then
			waves[slot] = { index = wave.index + 1, toSpawn = config.WaveSize, nextSpawnAt = now }
		end
	end
end

-- ลูปหลักทุก 0.1 วิ: หาเลนที่ต้องปล่อย → ถ้ามีบอสพักทุกเลน → ไม่งั้นเดิน wave ของแต่ละเลน
function MonsterService.Start()
	while true do
		task.wait(0.1)
		local now = os.clock()
		-- เลนที่ปล่อยมอน: ทุกช่อง (โหมดเทส AllLanesForTest) หรือเฉพาะช่องที่มีเจ้าของ
		local owners: { [number]: any } = BaseService.owners()
		if Combat.Monster.AllLanesForTest then
			local all = {}
			for _, slot in BaseService.slots() do
				all[slot] = true
			end
			owners = all
		end
		for slot in waves do
			if not owners[slot] then
				-- เจ้าของออกจากเกม → หยุดเลนนี้ (มอนที่เดินอยู่เดินต่อจนถึงปลายทาง) · คนใหม่เริ่ม wave 1
				waves[slot] = nil
			end
		end
		if BossService.isActive() then
			-- พักทุกเลนระหว่างตีบอส · เลื่อนเวลานัดออกไปเรื่อยๆ ให้เริ่มนับใหม่หลังบอสจบ
			for _, wave in waves do
				wave.nextSpawnAt = now + Combat.Monster.SpawnGap
				if wave.restUntil then
					wave.restUntil = now + Combat.Monster.WaveDelay
				end
			end
			continue
		end
		for slot in owners do
			stepWave(slot, now)
		end
	end
end

return MonsterService
