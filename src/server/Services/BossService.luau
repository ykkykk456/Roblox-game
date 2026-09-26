-- บอสอีเวนต์: เกิดตามเวลา ทั้งเซิร์ฟช่วยกันตี แบ่งรางวัล "ขั้นต่ำ + ตามดาเมจ" (เจ้าของ: Gameplay_Scripter)
-- ชนะ = เงิน + ตั๋วกาชา (อันดับต้นได้โบนัส) · หนี = เงินลดลง ไม่มีตั๋ว
-- สถานะส่งให้ Client ผ่าน Attribute ของ ReplicatedStorage.BossState (อ่านอย่างเดียว ใช้แสดงผล):
--   Active: boolean · Hp / MaxHp: number · EndsAt / NextAt: เวลา workspace:GetServerTimeNow()
--   Top: JSON [{ n = ชื่อ, d = ดาเมจ }] 5 อันดับ · Result: ข้อความผลรอบล่าสุด
-- ดาเมจของตัวเองส่งผ่าน Player Attribute "BossDamage"
--
-- หน้าตา/ท่าทาง (ยืนยัน 2026-09-26):
--   • โมเดลจริงวางเองใน Studio ที่ ServerStorage > Bosses > <Combat.Boss.Model> (ริก R15 มี Humanoid)
--     ไม่มีโมเดล → ใช้ลูกบอลสำรอง · clone แล้วลบสคริปต์ที่ติดมากับโมเดล (กันสคริปต์แฝง)
--   • เปิดตัว: ท่า Walk เดินจากขอบแอ่งเข้ากลาง → ยืน Idle วน · ทุก SlamInterval วินาทีเล่นท่า Slam
--   • จังหวะกระแทก: เอฟเฟกต์พื้นแตก + ยิงสัญญาณ BossService.Slammed (TurretService ลดเลือดป้อม)
--   • เล่นอนิเมชันที่ Server ผ่าน Animator → ผู้เล่นทุกคนเห็นท่าเดียวกัน

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local SkillService = require(script.Parent.SkillService)
local Wallet = require(script.Parent.Wallet)

local PUBLISH_INTERVAL = 0.2
local TOP_COUNT = 5

type Entry = { userId: number, name: string, damage: number }
type Boss = {
	body: Instance, -- ของที่ลบทิ้งตอนบอสจบ (Model หรือลูกบอล)
	part: BasePart, -- จุดที่ป้อมเล็ง
	root: BasePart?, -- HumanoidRootPart (มีเฉพาะโมเดลจริง ใช้ขยับตอนเปิดตัว)
	tracks: { [string]: AnimationTrack },
	hp: number,
	maxHp: number,
	endsAt: number,
	damageBy: { [number]: Entry }, -- key = UserId (คนที่ออกไปแล้วยังอยู่ในตาราง แต่ไม่ได้รางวัล)
}

local state: Folder
local boss: Boss? = nil
local dirty = false
local slammedEvent = Instance.new("BindableEvent")

-- มุมทั้ง 8 ของกล่อง (ใช้หาจุดต่ำสุดของชิ้นส่วน)
local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- ความสูงผิวพื้นที่รัศมี r จากกลางแมพ (แอ่งลึกเป็นขั้น)
local function floorAt(r: number): number
	local depth = 0
	for _, step in Map.Pit.Steps do
		if r < step.Outer then
			depth = math.max(depth, step.Depth)
		end
	end
	return Map.GroundY - depth
end

-- ความลึกของพื้นกลางแอ่ง (ขั้นในสุด)
local function pitFloorY(): number
	local deepest = 0
	for _, step in Map.Pit.Steps do
		deepest = math.max(deepest, step.Depth)
	end
	return Map.GroundY - deepest
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function addLabel(parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "👹 BOSS"
	label.Parent = gui
end

-- บอสสำรอง: ลูกบอลลอยกลางแมพ (ใช้เมื่อยังไม่ได้วางโมเดลใน ServerStorage)
local function makeBall(): (Instance, BasePart)
	local part = Instance.new("Part")
	part.Name = "Boss"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(14, 14, 14)
	part.Color = Color3.fromRGB(130, 60, 200)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(0, Combat.Boss.Height, 0)
	addLabel(part, 10)
	part.Parent = workspace
	return part, part
end

local ANIMATION_NAMES = { "Idle", "Walk", "Slam" }

-- หา ID ของท่า: เลขใน Config (ถ้าไม่ใช่ 0) ก่อน → ไม่งั้นใช้ Animation ชื่อเดียวกันในโฟลเดอร์ Animations ของโมเดล
-- (ใส่ AnimationId ในหน้าต่าง Properties ของ Studio ได้เลย) · คืน nil = ยังไม่มีท่านี้
local function animationIdFor(name: string, folder: Instance?): string?
	local fromConfig = Combat.Boss.Animations[name]
	if type(fromConfig) == "number" and fromConfig > 0 then
		-- %d กันเลขยาวถูกแปลงเป็นรูป 9.3e+13
		return `rbxassetid://{string.format("%d", fromConfig)}`
	end
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("Animation") and item.AnimationId ~= "" then
		local id = item.AnimationId
		-- พิมพ์แค่ตัวเลข → เติม rbxassetid:// ให้
		return if string.match(id, "^%d+$") then `rbxassetid://{id}` else id
	end
	return nil
end

-- โหลดท่าที่มี ID (ข้ามท่าที่ยังไม่มี) · คืนตาราง ชื่อท่า → AnimationTrack
local function loadTracks(model: Model): { [string]: AnimationTrack }
	local tracks = {}
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local controller: Instance? = humanoid or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		warn(`[BossService] โมเดล {model.Name} ไม่มี Humanoid หรือ AnimationController — เล่นท่าไม่ได้`)
		return tracks
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	local folder = model:FindFirstChild("Animations")
	for _, name in ANIMATION_NAMES do
		local id = animationIdFor(name, folder)
		if id then
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = id
			local ok, result = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok then
				result.Looped = name ~= "Slam"
				result.Priority = if name == "Slam" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Idle
				tracks[name] = result
			else
				warn(`[BossService] โหลดท่า {name} ({id}) ไม่สำเร็จ: {result}`)
			end
		end
	end
	if next(tracks) == nil then
		warn(
			`[BossService] บอส {model.Name} ยังไม่มีท่า — ใส่ AnimationId ที่ ServerStorage > Bosses > {model.Name} > Animations`
				.. " หรือใส่เลขใน Config/Combat.luau (Boss.Animations)"
		)
	end
	return tracks
end

-- บอสจริงจาก ServerStorage > Bosses > <Model> · คืน nil ถ้าไม่มีโมเดล
local function makeModel(): (Model?, BasePart?, BasePart?)
	local folder = ServerStorage:FindFirstChild("Bosses")
	local template = folder and folder:FindFirstChild(Combat.Boss.Model)
	if not template then
		return nil, nil, nil
	end
	if not template:IsA("Model") then
		warn(`[BossService] ServerStorage.Bosses.{Combat.Boss.Model} ต้องเป็น Model — ใช้ลูกบอลแทน`)
		return nil, nil, nil
	end

	local model = template:Clone()
	-- AnimSaves = ท่าร่างที่ Animation Editor เก็บไว้ในโมเดล ไม่ต้องใช้ตอนเล่นจริง
	local drafts = model:FindFirstChild("AnimSaves")
	if drafts then
		drafts:Destroy()
	end
	local root: BasePart? = nil
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy() -- โมเดลจากภายนอกห้ามพาสคริปต์เข้ามา
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Anchored = false
			if item.Name == "HumanoidRootPart" then
				root = item
			end
		end
	end
	root = root or model.PrimaryPart
	if not root then
		warn(`[BossService] โมเดล {model.Name} ไม่มี HumanoidRootPart — ใช้ลูกบอลแทน`)
		model:Destroy()
		return nil, nil, nil
	end
	-- ยึดแค่ตัวราก ชิ้นอื่นขยับตาม Motor6D ตามท่า
	root.Anchored = true
	model.PrimaryPart = root

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false -- ริกจากภายนอกอาจไม่มีข้อต่อคอ → ไม่ให้ Humanoid ถือว่าตาย
	end

	-- วางให้เท้าแตะพื้นที่ขอบแอ่ง: หันหน้าเข้ากลางก่อน แล้ววัดจุดต่ำสุดของตัวจริงในโลก
	-- (ไม่ใช้ GetBoundingBox เพราะกล่องหมุนตามตัวราก ถ้าโมเดลจาก Blender หมุนแกนมา ความสูงจะผิด → จม/ลอย)
	local startXZ = Vector3.new(0, 0, -Combat.Boss.EntranceFrom)
	model:PivotTo(CFrame.lookAt(startXZ, Vector3.new(0, 0, 0)))
	local lowest, highest = math.huge, -math.huge
	for _, item in model:GetDescendants() do
		-- ข้ามชิ้นล่องหน (HumanoidRootPart / ชิ้นช่วย) ที่อาจยื่นเลยเท้า
		if item:IsA("BasePart") and item.Transparency < 1 then
			local half = item.Size / 2
			for _, corner in CORNERS do
				local y = (item.CFrame * (half * corner)).Y
				lowest = math.min(lowest, y)
				highest = math.max(highest, y)
			end
		end
	end
	if lowest == math.huge then
		lowest, highest = root.Position.Y, root.Position.Y
	end
	local rootToBottom = model:GetPivot().Y - lowest + Combat.Boss.GroundOffset
	local floor = floorAt(Combat.Boss.EntranceFrom)
	model:SetAttribute("RootToBottom", rootToBottom)
	model:PivotTo(model:GetPivot() + Vector3.new(0, floor + rootToBottom - model:GetPivot().Y, 0))
	print(
		`[BossService] วาง {model.Name}: ตัวสูง {math.floor(highest - lowest + 0.5)} studs · เท้าห่างจุดหมุน {string.format("%.1f", rootToBottom)} · พื้นขอบแอ่ง Y={floor}`
			.. ` (ยังจม/ลอย → ปรับ Boss.GroundOffset ใน Config/Combat.luau)`
	)
	local height = highest - lowest

	local aim = model:FindFirstChild("UpperTorso", true)
	local target = if aim and aim:IsA("BasePart") then aim else root
	addLabel(target, height * 0.6)
	model.Parent = workspace
	return model, target, root
end

-- เอฟเฟกต์ทุบพื้น: วงคลื่นกระแทก + ก้อนบล็อกกระเด็น (ลบเองอัตโนมัติ)
local function slamEffect(center: Vector3)
	local y = pitFloorY()
	local ring = Instance.new("Part")
	ring.Name = "SlamWave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 196, 92)
	ring.Size = Vector3.new(0.6, 8, 8)
	ring.CFrame = CFrame.new(center.X, y + 0.4, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local reach = Map.Base.TurretDistance * 2
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.6, reach, reach),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)

	local rng = Random.new()
	for _ = 1, 12 do
		local chunk = Instance.new("Part")
		chunk.Name = "SlamDebris"
		chunk.Size = Vector3.one * rng:NextNumber(1.5, 3)
		chunk.Color = Color3.fromRGB(255, 214, 110):Lerp(Color3.fromRGB(200, 116, 42), rng:NextNumber())
		chunk.Material = Enum.Material.Plastic
		chunk.CanCollide = false
		chunk.CanTouch = false
		chunk.CanQuery = false
		local angle = rng:NextNumber(0, 2 * math.pi)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
		chunk.CFrame = CFrame.new(Vector3.new(center.X, y + 1, center.Z) + offset * rng:NextNumber(4, 10))
		chunk.AssemblyLinearVelocity = offset * rng:NextNumber(20, 45) + Vector3.new(0, rng:NextNumber(30, 55), 0)
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1.5)
	end
end

-- จังหวะกระแทกของท่า Slam ครั้งเดียว (ลบเอฟเฟกต์เองถ้าบอสจบกลางท่า)
local function slam(current: Boss)
	local track = current.tracks.Slam
	local hit = false
	local function onHit()
		if hit or boss ~= current then
			return
		end
		hit = true
		slamEffect(current.part.Position)
		slammedEvent:Fire(Combat.Boss.SlamDamage)
	end
	if track then
		local connection = track:GetMarkerReachedSignal("Hit"):Connect(onHit)
		track:Play()
		task.delay(track.Length > 0 and track.Length or 3, function()
			connection:Disconnect()
		end)
	end
	-- ไม่มี Marker "Hit" (หรือไม่มีท่า) → ใช้เวลาใน Config แทน
	task.delay(Combat.Boss.SlamHitDelay, onHit)
end

-- เปิดตัว (เดินเข้ากลาง) → Idle → วนทุบทุก SlamInterval จนบอสจบ
local function runBehaviour(current: Boss)
	local tracks = current.tracks
	local root = current.root
	if root then
		if tracks.Walk then
			tracks.Walk:Play()
		end
		local model = current.body :: Model
		local lift = model:GetAttribute("RootToBottom") or 0
		local from = model:GetPivot().Position
		local to = Vector3.new(0, from.Y, 0)
		local started = os.clock()
		while boss == current do
			local t = math.min((os.clock() - started) / Combat.Boss.EntranceSeconds, 1)
			local flat = from:Lerp(to, t)
			-- เดินลงขั้นบันไดของแอ่ง: ปรับความสูงตามพื้นใต้เท้า
			local position = Vector3.new(flat.X, floorAt(Vector3.new(flat.X, 0, flat.Z).Magnitude) + lift, flat.Z)
			model:PivotTo(CFrame.lookAt(position, position + (to - from)))
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if tracks.Walk then
			tracks.Walk:Stop(0.3)
		end
	end
	if boss ~= current then
		return
	end
	if tracks.Idle then
		tracks.Idle:Play(0.3)
	end
	while boss == current do
		task.wait(Combat.Boss.SlamInterval)
		if boss ~= current then
			break
		end
		slam(current)
	end
end

local function sortedEntries(current: Boss): { Entry }
	local list = {}
	for _, entry in current.damageBy do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.damage > b.damage
	end)
	return list
end

local function publish(current: Boss)
	state:SetAttribute("Hp", math.ceil(current.hp))
	local top = {}
	for index, entry in sortedEntries(current) do
		if index > TOP_COUNT then
			break
		end
		table.insert(top, { n = entry.name, d = math.floor(entry.damage) })
	end
	state:SetAttribute("Top", HttpService:JSONEncode(top))
	for userId, entry in current.damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("BossDamage", math.floor(entry.damage))
		end
	end
end

local function spawnBoss()
	local maxHp = Combat.Boss.BaseHp + Combat.Boss.HpPerPlayer * #Players:GetPlayers()
	local body: Instance, part: BasePart
	local tracks = {}
	local model, target, root = makeModel()
	if model and target then
		body, part = model, target
		tracks = loadTracks(model)
	else
		body, part = makeBall()
	end
	local current: Boss = {
		body = body,
		part = part,
		root = root,
		tracks = tracks,
		hp = maxHp,
		maxHp = maxHp,
		endsAt = now() + Combat.Boss.Duration,
		damageBy = {},
	}
	boss = current
	task.spawn(runBehaviour, current)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BossDamage", 0)
	end
	state:SetAttribute("MaxHp", maxHp)
	state:SetAttribute("Hp", maxHp)
	state:SetAttribute("EndsAt", boss.endsAt)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state:SetAttribute("Active", true)
end

local function finish(current: Boss, killed: boolean)
	boss = nil
	current.body:Destroy()
	publish(current)

	local ranking = sortedEntries(current)
	local total = 0
	for _, entry in ranking do
		total += entry.damage
	end
	-- เงิน: ขั้นต่ำทุกคน + ตามสัดส่วนดาเมจ · บอสหนีได้เงินลดลงและไม่ได้ตั๋ว (IDEA.md)
	local moneyMultiplier = if killed then 1 else Economy.Boss.EscapeMoneyMultiplier
	for rank, entry in ranking do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player and total > 0 then
			local money = Economy.Boss.BaseReward + Economy.Boss.DamageRewardPool * entry.damage / total
			Wallet.earn(player, money * moneyMultiplier)
			if killed then
				local bonus = if rank <= Economy.Gacha.TopBonusRanks then Economy.Gacha.TopBonusTickets else 0
				SkillService.grantTickets(player, Economy.Gacha.TicketsPerBossKill + bonus)
			end
		end
	end

	local mvp = if ranking[1] then ranking[1].name else "-"
	if killed then
		state:SetAttribute(
			"Result",
			`ชนะบอสแล้ว! 🏆 {mvp} · ได้เงิน + 🎟 ตั๋วกาชา`
		)
	else
		state:SetAttribute(
			"Result",
			"บอสหนีไปแล้ว… ได้เงินบางส่วน (ไม่ได้ตั๋ว)"
		)
	end
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.Interval)
end

local BossService = {}

-- ยิงเมื่อบอสทุบพื้นถึงจังหวะกระแทก: (ดาเมจต่อป้อม)
BossService.Slammed = slammedEvent.Event

-- มีบอสอยู่ในแมพตอนนี้หรือไม่ (ตั้งแต่เกิดจนตาย/หนี)
function BossService.isActive(): boolean
	return boss ~= nil
end

-- บอสที่ตีได้ตอนนี้ (nil ถ้าไม่มี)
function BossService.getTarget(): Vector3?
	if boss and boss.hp > 0 then
		return boss.part.Position
	end
	return nil
end

function BossService.damage(player: Player, amount: number)
	local current = boss
	if not current or current.hp <= 0 then
		return
	end
	local applied = math.min(amount, current.hp)
	current.hp -= applied
	local entry = current.damageBy[player.UserId]
	if not entry then
		entry = { userId = player.UserId, name = player.DisplayName, damage = 0 }
		current.damageBy[player.UserId] = entry
	end
	entry.damage += applied
	dirty = true
end

function BossService.Init()
	state = Instance.new("Folder")
	state.Name = "BossState"
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.FirstDelay)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state.Parent = ReplicatedStorage
end

function BossService.Start()
	while true do
		task.wait(PUBLISH_INTERVAL)
		local current = boss
		if current then
			if current.hp <= 0 then
				finish(current, true)
			elseif now() >= current.endsAt then
				finish(current, false)
			elseif dirty then
				dirty = false
				publish(current)
			end
		elseif now() >= state:GetAttribute("NextAt") then
			if #Players:GetPlayers() > 0 then
				spawnBoss()
			else
				state:SetAttribute("NextAt", now() + 5)
			end
		end
	end
end

return BossService
