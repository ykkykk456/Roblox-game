-- มอนเล็ก/กลางที่เกิดในสวนหลังบ้านของแต่ละฐาน แล้วเดินสุ่มไปมารอบฐานตัวเอง (เจ้าของ: Gameplay_Scripter)
-- ไม่เข้าลานฐาน/บ้าน และไม่ล้ำไปฐานข้างๆ (พื้นที่: Config/Map.MonsterWander) · อยู่ครบ Lifetime แล้วหายไป ไม่มีรางวัล
-- เกิดเฉพาะฐานที่มีเจ้าของ และจำนวนเท่ากันทุกฐาน
-- ตำแหน่ง/HP/ผลการตาย คำนวณที่ Server ทั้งหมด · ตายแล้วแบ่งเงินตามสัดส่วนดาเมจ
-- หน้าตา: สัตว์บล็อกทรงกล่อง (ตัว หู ตา ปาก) สไตล์ voxel · [Proposed] ยังไม่มีอนิเมชันนอกจากเด้งตอนเดิน

local Players = game:GetService("Players")
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
	-- ช่วงเดินปัจจุบัน: จาก from ไป to เริ่มที่ legStart ใช้เวลา legTime วินาที
	from: Vector3,
	to: Vector3,
	legStart: number,
	legTime: number,
	restUntil: number, -- 0 = ยังไม่ได้เริ่มพัก
	expiresAt: number,
	alive: boolean,
	damageBy: { [Player]: number },
}

local monsters: { Monster } = {}
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

-- จุดนี้อยู่ในลานฐานของช่องนี้ (บวกระยะกันห่าง) หรือไม่
local function insidePad(slot: number, point: Vector3): boolean
	local out, right = MapMath.axes(slot)
	local flat = Vector3.new(point.X, 0, point.Z)
	local u, v = flat:Dot(out), flat:Dot(right)
	local half = Map.Base.Size / 2 + Map.MonsterWander.PadMargin
	return math.abs(u - Map.Base.Distance) <= half and math.abs(v) <= half
end

-- จุดสุ่มในพื้นที่เดินของฐาน (กระจายเท่ากันทั้งพื้นที่) · minRadius ใช้บังคับให้เกิดในสวนหลังบ้าน
local function randomPoint(slot: number, y: number, minRadius: number?): Vector3?
	local wander = Map.MonsterWander
	local r0 = math.max(minRadius or wander.Inner, wander.Inner)
	for _ = 1, 20 do
		local angle = MapMath.angle(slot) + rng:NextNumber(-1, 1) * wander.HalfAngle
		local radius = math.sqrt(rng:NextNumber(r0 * r0, wander.Outer * wander.Outer))
		local point = MapMath.polar(angle, radius, y)
		if not insidePad(slot, point) then
			return point
		end
	end
	return nil
end

-- เส้นทางตรงจาก a ไป b ไม่ตัดผ่านลานฐาน
local function clearPath(slot: number, a: Vector3, b: Vector3): boolean
	for step = 1, 10 do
		if insidePad(slot, a:Lerp(b, step / 10)) then
			return false
		end
	end
	return true
end

local function startLeg(monster: Monster, now: number)
	local y = monster.from.Y
	for _ = 1, 8 do
		local target = randomPoint(monster.slot, y)
		if target and clearPath(monster.slot, monster.to, target) then
			monster.from = monster.to
			monster.to = target
			monster.legStart = now
			monster.legTime = (target - monster.from).Magnitude / monster.speed
			monster.restUntil = 0
			return
		end
	end
	-- หาทางไม่ได้รอบนี้ → ยืนพักแล้วลองใหม่
	monster.restUntil = now + Map.MonsterWander.PauseMax
end

local function spawnMonster(slot: number)
	local kind = pickKind()
	local def = Combat.Monster.Types[kind]
	local y = Map.GroundY + def.Size * 0.4
	local start = randomPoint(slot, y, Map.Yard.Inner)
		or MapMath.point(slot, (Map.Yard.Inner + Map.Yard.Outer) / 2, 0, y)

	local model, part, bar = makeBody(def.Size, def.Color)
	-- ย้ายทั้งโมเดล (ทุกชิ้นพร้อมกัน) ก่อนเข้า workspace · ถ้าย้ายแค่ตัวหลัก WeldConstraint จะจำระยะผิด
	-- แล้วหู/ตา/ปากลอยแยกจากตัว (บั๊กที่เจอ 2026-09-26)
	model:PivotTo(CFrame.new(start))
	model.Parent = folder

	local now = os.clock()
	local monster: Monster = {
		model = model,
		part = part,
		bar = bar,
		kind = kind,
		slot = slot,
		hp = def.Hp,
		maxHp = def.Hp,
		speed = def.Speed,
		from = start,
		to = start,
		legStart = now,
		legTime = 0,
		restUntil = 0,
		expiresAt = now + Combat.Monster.Lifetime,
		alive = true,
		damageBy = {},
	}
	startLeg(monster, now)
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
	if monster.legTime <= 0 then
		return monster.to
	end
	return monster.from:Lerp(monster.to, math.clamp((now - monster.legStart) / monster.legTime, 0, 1))
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
		local wander = Map.MonsterWander
		for index = #monsters, 1, -1 do
			local monster = monsters[index]
			if not monster.alive then
				table.remove(monsters, index)
			elseif now >= monster.expiresAt then
				-- อยู่ครบเวลาแล้ว หายไป ไม่มีรางวัล
				monster.alive = false
				monster.model:Destroy()
				table.remove(monsters, index)
			else
				local arrived = now >= monster.legStart + monster.legTime
				if arrived and monster.restUntil == 0 then
					monster.restUntil = now + rng:NextNumber(wander.PauseMin, wander.PauseMax)
				elseif arrived and now >= monster.restUntil then
					startLeg(monster, now)
				end

				local position = MonsterService.positionOf(monster, now)
				local direction = Vector3.new(monster.to.X - monster.from.X, 0, monster.to.Z - monster.from.Z)
				local moving = not arrived and direction.Magnitude > 0.1
				local hop = if moving then math.abs(math.sin(now * monster.speed * 1.5)) * 0.4 else 0
				local lifted = position + Vector3.new(0, hop, 0)
				monster.part.CFrame = if direction.Magnitude > 0.1
					then CFrame.lookAt(lifted, lifted + direction)
					else CFrame.new(lifted) * monster.part.CFrame.Rotation
			end
		end
	end)
end

function MonsterService.Start()
	while true do
		task.wait(Combat.Monster.SpawnInterval)
		if #Players:GetPlayers() == 0 then
			continue
		end
		for slot in BaseService.owners() do
			if aliveIn(slot) < Combat.Monster.MaxAlivePerBase then
				spawnMonster(slot)
			end
		end
	end
end

return MonsterService
