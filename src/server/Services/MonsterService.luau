-- มอนเล็ก/กลางที่เกิดในสวนหลังบ้านของแต่ละฐาน แล้วเดินตามทางมอนเข้าหาหลุม (เจ้าของ: Gameplay_Scripter)
-- เกิดเฉพาะฐานที่มีเจ้าของ และจำนวนเท่ากันทุกฐาน · เดินถึงปลายทาง = ตกหลุมหายไป ไม่มีรางวัล
-- ตำแหน่ง/HP/ผลการตาย คำนวณที่ Server ทั้งหมด · ตายแล้วแบ่งเงินตามสัดส่วนดาเมจ
-- [Proposed] prototype: ตัวมอนเป็นลูกบอล Anchored ยังไม่มีโมเดล/อนิเมชัน

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
	part: BasePart,
	bar: Frame,
	kind: string,
	slot: number,
	hp: number,
	maxHp: number,
	speed: number,
	points: { Vector3 }, -- เส้นทางเดิน: จุดเกิด → ปากสวน → ปลายทางมอน
	lengths: { number }, -- ความยาวแต่ละช่วงของเส้นทาง
	travel: number,
	spawnedAt: number,
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

local function makeBody(size: number, color: Color3): (BasePart, Frame)
	local part = Instance.new("Part")
	part.Name = "Monster"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 6)
	gui.StudsOffset = Vector3.new(0, size, 0)
	gui.MaxDistance = 120
	gui.Parent = part

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

	return part, bar
end

local function spawnMonster(slot: number)
	local kind = pickKind()
	local def = Combat.Monster.Types[kind]
	local yard, lane = Map.Yard, Map.MonsterLane
	local y = Map.GroundY + def.Size / 2

	local angle = MapMath.angle(slot) + rng:NextNumber(-0.8, 0.8) * yard.HalfAngle
	local points = {
		MapMath.polar(angle, rng:NextNumber(yard.Inner + 8, yard.Outer - 4), y),
		MapMath.point(slot, yard.Inner, lane.Side, y),
		MapMath.point(slot, lane.End, lane.Side, y),
	}
	local lengths, travel = {}, 0
	for index = 2, #points do
		local length = (points[index] - points[index - 1]).Magnitude
		lengths[index - 1] = length
		travel += length
	end

	local part, bar = makeBody(def.Size, def.Color)
	part.CFrame = CFrame.new(points[1])
	part.Parent = folder

	table.insert(monsters, {
		part = part,
		bar = bar,
		kind = kind,
		slot = slot,
		hp = def.Hp,
		maxHp = def.Hp,
		speed = def.Speed,
		points = points,
		lengths = lengths,
		travel = travel,
		spawnedAt = os.clock(),
		alive = true,
		damageBy = {},
	})
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
	local distance = math.min(monster.speed * (now - monster.spawnedAt), monster.travel)
	for index, length in monster.lengths do
		if distance <= length then
			return monster.points[index]:Lerp(monster.points[index + 1], if length > 0 then distance / length else 1)
		end
		distance -= length
	end
	return monster.points[#monster.points]
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
		monster.part:Destroy()
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
			elseif monster.speed * (now - monster.spawnedAt) >= monster.travel then
				-- เดินถึงปากหลุมแล้ว ตกหลุมหายไป ไม่มีรางวัล
				monster.alive = false
				monster.part:Destroy()
				table.remove(monsters, index)
			else
				monster.part.CFrame = CFrame.new(MonsterService.positionOf(monster, now))
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
