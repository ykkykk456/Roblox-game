-- ป้อมของผู้เล่น: วาง · เล็ง · ยิง · อัปเลเวล · ใช้สกิล (เจ้าของ: Gameplay_Scripter)
-- คลังสกิล/กาชา/คูลดาวน์อยู่ที่ SkillService · ที่นี่แค่นำผลสกิลมาใช้ตอนยิง
-- Server เลือกเป้าและคำนวณดาเมจเองทั้งหมด · Client ส่งได้แค่ "ขออัป" / "ขอใช้สกิล" (ผ่าน TurretHandler)
-- ลำดับเป้า: บอส (ถ้ามีและอยู่ในระยะ) → มอนที่ใกล้ที่สุดในระยะ
-- เลือดป้อม: บอสทุบพื้น (BossService.Slammed) → ลดเลือดทุกป้อม · หมด = ช็อต หยุดยิง Combat.Turret.StunSeconds แล้วฟื้นเต็ม
--   บอสจบ = เลือดเต็มทันที · ไม่บันทึกลง DataStore (ยืนยัน 2026-09-26)
-- [Proposed] prototype: ผู้เล่น 1 คน = ป้อม 1 ตัว วางหน้าฐานของตัวเอง (BaseService) · หน้าตาเป็น Part ธรรมดา
-- (ตาม IDEA.md หน้าตาไม่เปลี่ยนตามเลเวล — จะเปลี่ยนตามอุปกรณ์แต่งปืนในเฟสหลัง)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SkillMath = require(ReplicatedStorage.Shared.Util.SkillMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local LayoutService = require(script.Parent.LayoutService)
local FriendBoostService = require(script.Parent.FriendBoostService)
local MonsterService = require(script.Parent.MonsterService)
local SkillService = require(script.Parent.SkillService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local GROUND_Y = Map.GroundY
local HEAD_HEIGHT = 5
local BARREL_LENGTH = 4
local MAX_SHOTS_PER_TICK = 5 -- กันอัตรายิงสูงเกินรอบคำนวณ: รวมหลายนัดเป็นครั้งเดียว
local HEAD_COLOR = Color3.fromRGB(60, 160, 170)
local STUNNED_COLOR = Color3.fromRGB(110, 110, 116)

type Turret = {
	owner: Player,
	slot: number,
	model: Model,
	head: BasePart,
	barrel: BasePart,
	label: TextLabel,
	headPosition: Vector3,
	nextFireAt: number,
	hp: number,
	stunnedUntil: number, -- os.clock() · 0 = ไม่ช็อต
}

local turrets: { [Player]: Turret } = {}
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
	part.Material = Enum.Material.Plastic
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
	local status = if turret.stunnedUntil > 0 then "⚡ ช็อต!" else `❤ {math.ceil(turret.hp)}`
	turret.label.Text = `{turret.owner.DisplayName} · Lv.{levelOf(turret.owner)} · {status}`
end

-- ฐานป้อม (ระดับพื้น): บนแท่น Tag TurretN ของแมพ · ไม่มี Tag → หน้าฐานผังวงกลมเดิม
local function footOf(slot: number): Vector3
	if LayoutService.hasLayout() then
		return LayoutService.turretTop(slot)
	end
	return MapMath.point(slot, Map.Base.TurretDistance, 0) + Vector3.new(0, GROUND_Y, 0)
end

-- จุดที่ป้อมหันไปตอนยังไม่มีเป้า = จุดบอส
local function bossPoint(): Vector3
	return if LayoutService.hasLayout() then LayoutService.bossCenter() else Vector3.zero
end

-- ป้อมว่าง (ช่องที่ยังไม่มีเจ้าของ): โชว์ไว้เฉยๆ สีเทา ไม่ยิง (ยืนยัน 2026-09-27)
local idleTurrets: { [number]: Model } = {}

local function buildIdle(slot: number)
	if idleTurrets[slot] then
		return
	end
	local foot = footOf(slot)
	local model = Instance.new("Model")
	model.Name = `TurretIdle_{slot}`
	local pedestal = newPart("Pedestal", Vector3.new(HEAD_HEIGHT - 1, 6, 6), Color3.fromRGB(90, 92, 100), model)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(foot + Vector3.new(0, (HEAD_HEIGHT - 1) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local headPosition = foot + Vector3.new(0, HEAD_HEIGHT, 0)
	local target = bossPoint()
	local head = newPart("Head", Vector3.new(3, 2.5, 3), STUNNED_COLOR, model)
	head.CanCollide = false
	head.CFrame = CFrame.lookAt(headPosition, Vector3.new(target.X, headPosition.Y, target.Z))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 24)
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
	label.Text = `ป้อม {slot} · ว่าง`
	label.Parent = gui
	model.PrimaryPart = pedestal
	model.Parent = folder
	idleTurrets[slot] = model
end

local function removeIdle(slot: number)
	local model = idleTurrets[slot]
	if model then
		idleTurrets[slot] = nil
		model:Destroy()
	end
end

local function build(owner: Player, slot: number): Turret
	local base = footOf(slot)
	local headPosition = base + Vector3.new(0, HEAD_HEIGHT, 0)

	local model = Instance.new("Model")
	model.Name = `Turret_{owner.UserId}`
	model:SetAttribute("OwnerUserId", owner.UserId)

	local pedestal = newPart("Pedestal", Vector3.new(HEAD_HEIGHT - 1, 6, 6), Color3.fromRGB(70, 74, 86), model)
	pedestal.Shape = Enum.PartType.Cylinder
	pedestal.CFrame = CFrame.new(base + Vector3.new(0, (HEAD_HEIGHT - 1) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)

	local head = newPart("Head", Vector3.new(3, 2.5, 3), HEAD_COLOR, model)
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
		hp = Combat.Turret.MaxHp,
		stunnedUntil = 0,
	}
	local target = bossPoint()
	aim(turret, Vector3.new(target.X, headPosition.Y, target.Z)) -- หันเข้าหาจุดบอส
	refreshLabel(turret)
	return turret
end

-- ได้ฐาน = ได้ป้อมหน้าฐาน · เสียฐาน (ออกเกม) = ลบป้อม
local function onBaseChanged(player: Player, slot: number?)
	local turret = turrets[player]
	if turret and turret.slot ~= slot then
		turrets[player] = nil
		turret.model:Destroy()
		buildIdle(turret.slot) -- เจ้าของออก → กลับเป็นป้อมว่าง
	end
	if slot and not turrets[player] then
		removeIdle(slot)
		turrets[player] = build(player, slot)
	end
end

local function setHealthy(turret: Turret)
	turret.hp = Combat.Turret.MaxHp
	turret.stunnedUntil = 0
	turret.head.Color = HEAD_COLOR
	refreshLabel(turret)
end

-- บอสทุบพื้น: ลดเลือดทุกป้อม · หมดเลือด = ช็อต
local function onSlammed(damage: number)
	local now = os.clock()
	for _, turret in turrets do
		if turret.stunnedUntil == 0 then
			turret.hp = math.max(turret.hp - damage, 0)
			if turret.hp <= 0 then
				turret.stunnedUntil = now + Combat.Turret.StunSeconds
				turret.head.Color = STUNNED_COLOR
			end
			refreshLabel(turret)
		end
	end
end

-- ฟื้นป้อมที่ช็อตครบเวลา · บอสจบแล้ว = เลือดเต็มทุกป้อม
local function updateHealth(now: number)
	local bossActive = BossService.isActive()
	for _, turret in turrets do
		local stunOver = turret.stunnedUntil > 0 and now >= turret.stunnedUntil
		local bossOver = not bossActive and (turret.stunnedUntil > 0 or turret.hp < Combat.Turret.MaxHp)
		if stunOver or bossOver then
			setHealthy(turret)
		end
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
	updateHealth(now)

	for owner, turret in turrets do
		if turret.stunnedUntil > 0 then
			turret.nextFireAt = now -- ช็อต: ไม่ยิง และไม่สะสมนัดค้างไว้ยิงทีเดียวหลังฟื้น
			continue
		end
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
	if not turret or turret.stunnedUntil > 0 or not id or not def or not level then
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

	BaseService.Changed:Connect(onBaseChanged)
	BossService.Slammed:Connect(onSlammed)
	local owners = BaseService.owners()
	for _, slot in BaseService.slots() do
		if not owners[slot] then
			buildIdle(slot)
		end
	end
	for slot, player in owners do
		onBaseChanged(player, slot)
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
