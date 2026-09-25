-- มอนเล็กที่เดินผ่านแมพตลอดเวลา ให้ป้อมยิงหาเงินระหว่างรอบอส (เจ้าของ: Gameplay_Scripter)
-- ตำแหน่ง/HP/ผลการตาย คำนวณที่ Server ทั้งหมด · ตายแล้วแบ่งเงินตามสัดส่วนดาเมจ
-- [Proposed] prototype: ตัวมอนเป็นลูกบอล Anchored เดินเส้นตรง ยังไม่มีโมเดล/อนิเมชัน

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Wallet = require(script.Parent.Wallet)

export type Monster = {
	part: BasePart,
	bar: Frame,
	hp: number,
	maxHp: number,
	start: Vector3,
	direction: Vector3,
	travel: number,
	spawnedAt: number,
	alive: boolean,
	damageBy: { [Player]: number },
}

local GROUND_Y = 1 -- ผิวบนของพื้นหญ้าใน default.project.json
local SIZE = 3

local monsters: { Monster } = {}
local folder: Folder

local function makeBody(): (BasePart, Frame)
	local part = Instance.new("Part")
	part.Name = "Monster"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(SIZE, SIZE, SIZE)
	part.Color = Color3.fromRGB(205, 72, 72)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 6)
	gui.StudsOffset = Vector3.new(0, SIZE, 0)
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

local function spawnMonster()
	local radius = Combat.Monster.SpawnRadius
	local angle = math.random() * 2 * math.pi
	local exitAngle = angle + math.pi + (math.random() - 0.5) * 1.2
	local y = GROUND_Y + SIZE / 2
	local start = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
	local finish = Vector3.new(math.cos(exitAngle) * radius, y, math.sin(exitAngle) * radius)

	local part, bar = makeBody()
	part.CFrame = CFrame.new(start)
	part.Parent = folder

	table.insert(monsters, {
		part = part,
		bar = bar,
		hp = Combat.Monster.Hp,
		maxHp = Combat.Monster.Hp,
		start = start,
		direction = (finish - start).Unit,
		travel = (finish - start).Magnitude,
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
	for player, amount in monster.damageBy do
		Wallet.earn(player, Economy.MonsterReward * amount / total)
	end
end

local MonsterService = {}

-- มอนที่ยังมีชีวิต (อ่านอย่างเดียว)
function MonsterService.getAlive(): { Monster }
	return monsters
end

function MonsterService.positionOf(monster: Monster, now: number): Vector3
	local distance = math.min(Combat.Monster.Speed * (now - monster.spawnedAt), monster.travel)
	return monster.start + monster.direction * distance
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
			elseif Combat.Monster.Speed * (now - monster.spawnedAt) >= monster.travel then
				-- เดินหลุดแมพไปแล้ว ไม่มีรางวัล
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
		if #Players:GetPlayers() > 0 and #monsters < Combat.Monster.MaxAlive then
			spawnMonster()
		end
	end
end

return MonsterService
