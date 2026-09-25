-- ป้อมของผู้เล่น: วาง · เล็ง · ยิง · อัปเลเวล · ใช้สกิล (เจ้าของ: Gameplay_Scripter)
-- คลังสกิล/กาชา/คูลดาวน์อยู่ที่ SkillService · ที่นี่แค่นำผลสกิลมาใช้ตอนยิง
-- Server เลือกเป้าและคำนวณดาเมจเองทั้งหมด · Client ส่งได้แค่ "ขออัป" / "ขอใช้สกิล" (ผ่าน TurretHandler)
-- ลำดับเป้า: บอส (ถ้ามีและอยู่ในระยะ) → มอนที่ใกล้ที่สุดในระยะ
-- [Proposed] prototype: ผู้เล่น 1 คน = ป้อม 1 ตัว วางอัตโนมัติรอบวงกลางแมพ · หน้าตาเป็น Part ธรรมดา
-- (ตาม IDEA.md หน้าตาไม่เปลี่ยนตามเลเวล — จะเปลี่ยนตามอุปกรณ์แต่งปืนในเฟสหลัง)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SkillMath = require(ReplicatedStorage.Shared.Util.SkillMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BossService = require(script.Parent.BossService)
local FriendBoostService = require(script.Parent.FriendBoostService)
local MonsterService = require(script.Parent.MonsterService)
local SkillService = require(script.Parent.SkillService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local GROUND_Y = 1
local HEAD_HEIGHT = 5
local BARREL_LENGTH = 4
local MAX_SHOTS_PER_TICK = 5 -- กันอัตรายิงสูงเกินรอบคำนวณ: รวมหลายนัดเป็นครั้งเดียว

type Turret = {
	owner: Player,
	slot: number,
	model: Model,
	head: BasePart,
	barrel: BasePart,
	label: TextLabel,
	headPosition: Vector3,
	nextFireAt: number,
}

local turrets: { [Player]: Turret } = {}
local slotOwner: { [number]: Player } = {}
local folder: Folder

local function levelOf(player: Player): number
	local data = PlayerData.get(player)
	return TurretMath.clampLevel(if data then data.TurretLevel else 1)
end

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function aim(turret: Turret, target: Vector3)
	local flat = Vector3.new(target.X, turret.headPosition.Y, target.Z)
	if (flat - turret.headPosition).Magnitude > 0.01 then
		turret.head.CFrame = CFrame.lookAt(turret.headPosition, flat)
	end
	turret.barrel.CFrame = CFrame.lookAt(turret.headPosition, target) * CFrame.new(0, 0, -BARREL_LENGTH / 2 - 1)
end

local function refreshLabel(turret: Turret)
	turret.label.Text = `{turret.owner.DisplayName} · Lv.{levelOf(turret.owner)}`
end

local function build(owner: Player, slot: number): Turret
	local angle = (slot - 1) / Combat.Turret.Slots * 2 * math.pi
	local base = Vector3.new(math.cos(angle), 0, math.sin(angle)) * Combat.Turret.RingRadius
	local headPosition = base + Vector3.new(0, GROUND_Y + HEAD_HEIGHT, 0)

	local model = Instance.new("Model")
	model.Name = `Turret_{owner.UserId}`
	model:SetAttribute("OwnerUserId", owner.UserId)

	local pedestal = newPart("Pedestal", Vector3.new(HEAD_HEIGHT - 1, 6, 6), Color3.fromRGB(70, 74, 86), model)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(base + Vector3.new(0, GROUND_Y + (HEAD_HEIGHT - 1) / 2, 0))
		* CFrame.Angles(0, 0, math.pi / 2)

	local head = newPart("Head", Vector3.new(3, 2.5, 3), Color3.fromRGB(60, 160, 170), model)
	head.CanCollide = false
	local barrel = newPart("Barrel", Vector3.new(0.8, 0.8, BARREL_LENGTH), Color3.fromRGB(40, 42, 50), model)
	barrel.CanCollide = false
	barrel.CanQuery = false

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 28)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 150
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	model.PrimaryPart = pedestal
	model.Parent = folder

	local turret: Turret = {
		owner = owner,
		slot = slot,
		model = model,
		head = head,
		barrel = barrel,
		label = label,
		headPosition = headPosition,
		nextFireAt = 0,
	}
	aim(turret, Vector3.new(0, headPosition.Y, 0)) -- หันเข้ากลางแมพ
	refreshLabel(turret)
	return turret
end

local function onPlayerAdded(player: Player)
	if turrets[player] then
		return
	end
	for slot = 1, Combat.Turret.Slots do
		if not slotOwner[slot] then
			slotOwner[slot] = player
			turrets[player] = build(player, slot)
			return
		end
	end
	warn(
		`[TurretService] จุดวางป้อมเต็ม ({Combat.Turret.Slots}) — {player.Name} ยังไม่มีป้อม`
	)
end

local function onPlayerRemoving(player: Player)
	local turret = turrets[player]
	if turret then
		turrets[player] = nil
		slotOwner[turret.slot] = nil
		turret.model:Destroy()
	end
end

-- คืน (ตำแหน่งเป้า, ฟังก์ชันทำดาเมจ, เป็นบอสไหม) หรือ nil ถ้าไม่มีเป้าในระยะ
local function pickTarget(turret: Turret, bossPosition: Vector3?, now: number): (Vector3?, ((number) -> ())?, boolean)
	local range = Combat.Turret.Range
	if bossPosition and (bossPosition - turret.headPosition).Magnitude <= range then
		return bossPosition, function(amount)
			BossService.damage(turret.owner, amount)
		end, true
	end
	local best, bestPosition, bestDistance = nil, nil, range
	for _, monster in MonsterService.getAlive() do
		if monster.alive then
			local position = MonsterService.positionOf(monster, now)
			local distance = (position - turret.headPosition).Magnitude
			if distance <= bestDistance then
				best, bestPosition, bestDistance = monster, position, distance
			end
		end
	end
	if best then
		local monster = best
		return bestPosition, function(amount)
			MonsterService.damage(monster, turret.owner, amount)
		end, false
	end
	return nil, nil, false
end

-- ตำแหน่งปากกระบอกปืนเมื่อยิงไปที่เป้า
local function muzzleOf(turret: Turret, target: Vector3): Vector3
	return turret.headPosition + (target - turret.headPosition).Unit * (BARREL_LENGTH + 1)
end

local function tick(firedRemote: RemoteEvent)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local bossPosition = BossService.getTarget()
	local shots = {}

	for owner, turret in turrets do
		if now < turret.nextFireAt then
			continue
		end
		local targetPosition, dealDamage, isBoss = pickTarget(turret, bossPosition, now)
		if not targetPosition or not dealDamage then
			turret.nextFireAt = now -- ไม่มีเป้า: พร้อมยิงทันทีที่เจอ แต่ไม่สะสมนัดค้าง
			continue
		end

		local level = levelOf(owner)
		local fireRateMul, damageMul, bossDamageMul = SkillService.modifiers(owner, serverNow)
		local rate = TurretMath.fireRate(level) * fireRateMul
		local interval = 1 / rate
		local count = math.min(1 + math.floor((now - turret.nextFireAt) / interval), MAX_SHOTS_PER_TICK)
		turret.nextFireAt = math.max(turret.nextFireAt, now - interval) + count * interval

		local multiplier = damageMul * (if isBoss then bossDamageMul else 1) * (1 + FriendBoostService.get(owner))
		aim(turret, targetPosition)
		dealDamage(TurretMath.damage(level) * multiplier * count)

		table.insert(shots, muzzleOf(turret, targetPosition))
		table.insert(shots, targetPosition)
	end

	if #shots > 0 then
		firedRemote:FireAllClients(shots)
	end
end

local TurretService = {}

-- เรียกจาก TurretHandler หลังผ่าน Guard แล้ว · คืน true ถ้าอัปสำเร็จ
function TurretService.upgrade(player: Player): boolean
	local upgraded = false
	PlayerData.update(player, function(data)
		local level = TurretMath.clampLevel(data.TurretLevel)
		if level >= Combat.Turret.MaxLevel then
			return
		end
		local cost = TurretMath.upgradeCost(level)
		if data.Coins < cost then
			return
		end
		data.Coins -= cost
		data.TurretLevel = level + 1
		upgraded = true
	end)
	local turret = turrets[player]
	if upgraded and turret then
		refreshLabel(turret)
	end
	return upgraded
end

-- เรียกจาก TurretHandler หลังผ่าน Guard แล้ว · ใช้สกิลที่เลือกไว้ · คืน true ถ้าสำเร็จ
function TurretService.useSkill(player: Player): boolean
	local turret = turrets[player]
	local id, def, level = SkillService.equipped(player)
	if not turret or not id or not def or not level then
		return false
	end
	local serverNow = workspace:GetServerTimeNow()
	if not SkillService.isReady(player, serverNow) then
		return false
	end

	-- สกิลยิงทันที: ต้องมีเป้าในระยะ ไม่งั้นไม่เสียคูลดาวน์
	local burst = SkillMath.burst(def.Burst, level)
	local targetPosition, dealDamage, isBoss = nil, nil, false
	if burst > 0 then
		targetPosition, dealDamage, isBoss = pickTarget(turret, BossService.getTarget(), os.clock())
		if not targetPosition or not dealDamage then
			return false
		end
	end

	SkillService.activate(player, id, def, level, serverNow)

	if targetPosition and dealDamage then
		local _, damageMul, bossDamageMul = SkillService.modifiers(player, serverNow)
		local multiplier = damageMul * (if isBoss then bossDamageMul else 1) * (1 + FriendBoostService.get(player))
		aim(turret, targetPosition)
		dealDamage(TurretMath.damage(levelOf(player)) * burst * multiplier)
		local firedRemote = Remotes.get("TurretFired") :: RemoteEvent
		firedRemote:FireAllClients({ muzzleOf(turret, targetPosition), targetPosition })
	end
	return true
end

function TurretService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Turrets"
	folder.Parent = workspace

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	PlayerData.Changed:Connect(function(player: Player)
		local turret = turrets[player]
		if turret then
			refreshLabel(turret)
		end
	end)
end

function TurretService.Start()
	local firedRemote = Remotes.get("TurretFired") :: RemoteEvent
	local step = 1 / Combat.TickRate
	while true do
		task.wait(step)
		tick(firedRemote)
	end
end

return TurretService
