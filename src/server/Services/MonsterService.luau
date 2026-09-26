-- มอนเล็ก/กลางแบบ Tower Defense (เจ้าของ: Gameplay_Scripter) · ยืนยัน 2026-09-26 แทนการเดินสุ่ม
-- 8 เลนตามแนวฐาน: เกิดกลางแอ่ง (จุดบอส) → เดินตรงออกไปหาป้อมหน้าฐาน (ผัง: Config/Map.Lane)
-- ปล่อยเป็น wave: เลนละ Combat.Monster.WaveSize ตัว ทยอยออกทีละตัว · ทั้ง wave ตาย/ถึงปลายทางหมด → พัก WaveDelay → wave ถัดไป
-- ถึงปลายเลนแล้วหายไป ไม่มีรางวัล · ปล่อยเฉพาะเลนของฐานที่มีเจ้าของ
-- ตำแหน่ง/HP/ผลการตาย คำนวณที่ Server ทั้งหมด · ตายแล้วแบ่งเงินตามสัดส่วนดาเมจ
-- หน้าตา: สัตว์บล็อกทรงกล่อง (ตัว หู ตา ปาก) สไตล์ voxel · [Proposed] ยังไม่มีอนิเมชันนอกจากเด้งตอนเดิน

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)
local BaseService = require(script.Parent.BaseService)
local Wallet = require(script.Parent.Wallet)

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
	alive: boolean,
	damageBy: { [Player]: number },
}

type Wave = {
	index: number, -- wave ที่เท่าไรของเลนนี้
	toSpawn: number, -- ยังเหลือปล่อยอีกกี่ตัว
	nextSpawnAt: number,
	restUntil: number?, -- ตั้งค่าเมื่อ wave จบ (ไม่มีมอนเหลือ)
}

local monsters: { Monster } = {}
local waves: { [number]: Wave } = {}
local folder: Folder
local rng = Random.new()

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

local function spawnMonster(slot: number)
	local kind = pickKind()
	local def = Combat.Monster.Types[kind]
	local lane = Map.Lane
	-- แต่ละตัวเดินเยื้องซ้าย/ขวาในเลนแบบสุ่ม ไม่ให้ซ้อนเป็นเส้นเดียว
	local offset = rng:NextNumber(-1, 1) * lane.HalfWidth
	local from = MapMath.point(slot, lane.Start, offset)
	local to = MapMath.point(slot, lane.End, offset)
	local lift = def.Size * 0.4

	local model, part, bar = makeBody(def.Size, def.Color)
	-- ย้ายทั้งโมเดล (ทุกชิ้นพร้อมกัน) ก่อนเข้า workspace · ถ้าย้ายแค่ตัวหลัก WeldConstraint จะจำระยะผิด
	-- แล้วหู/ตา/ปากลอยแยกจากตัว (บั๊กที่เจอ 2026-09-26)
	model:PivotTo(CFrame.lookAt(from, to) + Vector3.new(0, groundAt(from.Magnitude) + lift, 0))
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
		alive = true,
		damageBy = {},
	}
	table.insert(monsters, monster)
end

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

local function aliveIn(slot: number): number
	local count = 0
	for _, monster in monsters do
		if monster.alive and monster.slot == slot then
			count += 1
		end
	end
	return count
end

local MonsterService = {}

-- มอนที่ยังมีชีวิต (อ่านอย่างเดียว)
function MonsterService.getAlive(): { Monster }
	return monsters
end

function MonsterService.positionOf(monster: Monster, now: number): Vector3
	local t = if monster.legTime > 0 then math.clamp((now - monster.legStart) / monster.legTime, 0, 1) else 1
	local flat = monster.from:Lerp(monster.to, t)
	return Vector3.new(flat.X, groundAt(flat.Magnitude) + monster.lift, flat.Z)
end

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

function MonsterService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for index = #monsters, 1, -1 do
			local monster = monsters[index]
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
				local hop = math.abs(math.sin(now * monster.speed * 1.5)) * 0.4
				local lifted = position + Vector3.new(0, hop, 0)
				monster.part.CFrame = CFrame.lookAt(lifted, lifted + direction)
			end
		end
	end)
end

-- คุมจังหวะ wave ของเลนเดียว
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

function MonsterService.Start()
	while true do
		task.wait(0.1)
		local now = os.clock()
		local owners = BaseService.owners()
		for slot in waves do
			if not owners[slot] then
				-- เจ้าของออกจากเกม → หยุดเลนนี้ (มอนที่เดินอยู่เดินต่อจนถึงปลายทาง) · คนใหม่เริ่ม wave 1
				waves[slot] = nil
			end
		end
		for slot in owners do
			stepWave(slot, now)
		end
	end
end

return MonsterService
