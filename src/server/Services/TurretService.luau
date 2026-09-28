-- ป้อมของผู้เล่น: วาง · เล็ง · ยิง · อัปเลเวล · ใช้สกิล (เจ้าของ: Gameplay_Scripter)
-- คลังสกิล/กาชา/คูลดาวน์อยู่ที่ SkillService · ที่นี่แค่นำผลสกิลมาใช้ตอนยิง
-- คลาส/สายธาตุ + effect ต่อเนื่องอยู่ที่ TurretClassService · หน้าตาป้อมสร้างที่ TurretLook (design/turret-classes.md)
-- Server เลือกเป้าและคำนวณดาเมจเองทั้งหมด · Client ส่งได้แค่ "ขออัป" / "ขอใช้สกิล" (ผ่าน TurretHandler)
-- ลำดับเป้า: บอส (ถ้ามีและอยู่ในระยะ) → มอนที่ใกล้ที่สุดในระยะ
-- ดาเมจต่อนัด = TurretMath.damage × ตัวคูณคลาส/สาย × สกิลกาชา × Friend boost (× ลดเกราะ เมื่อตีบอส)
-- อัตรายิง   = TurretMath.fireRate × ตัวคูณคลาส/สาย × สกิลกาชา · สายลมยิงเป็นชุด (ชาร์จ → รัว) แทน
-- เลือดป้อม: บอสทุบพื้น (BossService.Slammed) → ลดเลือดทุกป้อม · หมด = ช็อต หยุดยิง/หยุดชาร์จ Combat.Turret.StunSeconds แล้วฟื้นเต็ม
--   บอสจบ = เลือดเต็มทันที · ไม่บันทึกลง DataStore (ยืนยัน 2026-09-26)
-- [Proposed] prototype: ผู้เล่น 1 คน = ป้อม 1 ตัว วางหน้าฐานของตัวเอง (BaseService)
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ระยะยิง / ดาเมจ / อัตรายิง / เลเวลสูงสุด / เลือดป้อม / เวลาช็อต → Combat.Turret.* (src/shared/Config/Combat.luau)
--   • รอบคำนวณการยิงต่อวินาที → Combat.TickRate
--   • ราคาอัปเลเวล → Economy.Turret.* (src/shared/Config/Economy.luau) · สูตรอยู่ที่ src/shared/Util/TurretMath.luau
--   • ตัวคูณคลาส/สายธาตุ, effect (DoT, ลดเกราะ, หลุมดำ, ชาร์จลม) → src/shared/Config/Skill_class_default.luau
--   • บอสทุบแรงแค่ไหน → Combat.Boss.SlamDamage · ตำแหน่งป้อม → แท่น Tag TurretN ในแมพ หรือ Map.Base.TurretDistance
--   • หน้าตาป้อม → TurretLook.luau
--
-- คุยกับไฟล์ไหนบ้าง:
--   • TurretHandler (Network) — เรียก upgrade / useSkill หลังตรวจ Guard แล้ว
--   • BaseService — แจ้งว่าใครได้/เสียฐาน · BossService — จุดบอส + สัญญาณทุบพื้น · MonsterService — รายชื่อมอน + ทำดาเมจ
--   • TurretClassService — คลาส/สาย, ดาเมจบอส, effect ต่อเนื่อง · SkillService — สกิลกาชา · FriendBoostService — โบนัสเพื่อน
--   • PlayerData — เลเวลป้อม + เงิน · Remote "TurretFx" — ส่งภาพกระสุนให้ Client วาด
--
-- ⚠️ ระวัง: upgrade หักเงิน (ต้องทำใน PlayerData.update เท่านั้น) · อย่าให้ Client ส่งดาเมจ/เป้ามาเอง (กฎ Server Authority)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassMath = require(ReplicatedStorage.Shared.Util.ClassMath)
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
local TurretClassService = require(script.Parent.TurretClassService)
local TurretLook = require(script.Parent.TurretLook)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== ค่าคงที่ =====
-- GROUND_Y = ความสูงพื้นจาก Map.GroundY (ห้ามแก้ที่นี่) · HEAD_HEIGHT = ความสูงหัวป้อมจาก TurretLook (แก้ที่ TurretLook)
-- MAX_SHOTS_PER_TICK = ยิงได้สูงสุดกี่นัดต่อ 1 รอบคำนวณ (ปรับได้): ลดลง = ป้อมยิงเร็วมากๆ จะโดนตัดนัดทิ้ง · เพิ่ม = เร็วได้เต็มที่
-- STUNNED_COLOR = สีเทาของป้อมว่าง (ปรับได้ปลอดภัย)
local GROUND_Y = Map.GroundY
local HEAD_HEIGHT = TurretLook.HEAD_HEIGHT
local MAX_SHOTS_PER_TICK = 5 -- กันอัตรายิงสูงเกินรอบคำนวณ: รวมหลายนัดเป็นครั้งเดียว
local STUNNED_COLOR = Color3.fromRGB(110, 110, 116)

-- ===== ชนิดข้อมูล =====
-- Turret = ป้อม 1 ตัวของผู้เล่น (hp = เลือดตอนนี้ · nextFireAt = เวลาที่ยิงนัดถัดไปได้)
type Turret = {
	owner: Player,
	slot: number,
	look: TurretLook.Look,
	nextFireAt: number,
	hp: number,
	stunnedUntil: number, -- os.clock() · 0 = ไม่ช็อต
	-- สายลม (ChargeBurst): เริ่มชาร์จเมื่อไร · เหลือกี่ดอกในชุด · ดอกถัดไปยิงเมื่อไร
	chargeStartAt: number,
	burstLeft: number,
	nextBurstAt: number,
}

-- เป้าที่เลือกแล้ว: monster = nil เมื่อเป็นบอส
type Target = { position: Vector3, monster: any?, isBoss: boolean }

-- เอฟเฟกต์ที่ส่งให้ Client (ดู TurretFx ใน Remotes.luau)
type Fx = { Kind: string, From: Vector3, To: Vector3, Color: Color3, Radius: number?, Duration: number? }

-- ===== สถานะระหว่างเกม =====
-- turrets = ป้อมของผู้เล่นแต่ละคน · folder = โฟลเดอร์ Workspace.Turrets ที่เก็บโมเดลป้อมทั้งหมด
local turrets: { [Player]: Turret } = {}
local folder: Folder

-- ===== ตัวช่วย: เลเวล/ค่าพลัง/ชิ้นส่วน =====
-- เลเวลป้อมของผู้เล่น (จาก PlayerData) · ยังโหลดข้อมูลไม่เสร็จ = Lv.1
local function levelOf(player: Player): number
	local data = PlayerData.get(player)
	return TurretMath.clampLevel(if data then data.TurretLevel else 1)
end

-- ค่าพลังรวมของป้อม (ตัวคูณดาเมจ/อัตรายิง/effect) ตามคลาส + สาย + เลเวลของผู้เล่น
local function statsOf(player: Player): ClassMath.Stats
	local classId, branchId = TurretClassService.get(player)
	return ClassMath.stats(classId, branchId, levelOf(player))
end

-- สร้างชิ้น Part ยึดอยู่กับที่ (Anchored) ใส่ใน parent · ใช้สร้างป้อมว่าง
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

-- อัปเดตป้ายเหนือป้อม: ชื่อเจ้าของ · เลเวล · เลือด (หรือ "ช็อต!")
local function refreshLabel(turret: Turret)
	local status = if turret.stunnedUntil > 0 then "⚡ ช็อต!" else `❤ {math.ceil(turret.hp)}`
	turret.look.label.Text = `{turret.owner.DisplayName} · Lv.{levelOf(turret.owner)} · {status}`
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

-- ===== ป้อมว่าง / สร้างป้อม =====
-- ป้อมว่าง (ช่องที่ยังไม่มีเจ้าของ): โชว์ไว้เฉยๆ สีเทา ไม่ยิง (ยืนยัน 2026-09-27)
local idleTurrets: { [number]: Model } = {}

-- สร้างป้อมว่างสีเทาที่ช่อง slot (ถ้ามีอยู่แล้วไม่สร้างซ้ำ)
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

-- ลบป้อมว่างที่ช่อง slot (เรียกตอนมีคนมาเป็นเจ้าของ)
local function removeIdle(slot: number)
	local model = idleTurrets[slot]
	if model then
		idleTurrets[slot] = nil
		model:Destroy()
	end
end

-- สร้างหน้าตาป้อมตามคลาส/สายปัจจุบันของเจ้าของ
local function buildLook(owner: Player, slot: number): TurretLook.Look
	local classId, branchId = TurretClassService.get(owner)
	local look = TurretLook.build(footOf(slot), classId, branchId, levelOf(owner), bossPoint())
	look.model.Name = `Turret_{owner.UserId}`
	look.model:SetAttribute("OwnerUserId", owner.UserId)
	look.model:SetAttribute("TurretClass", classId)
	look.model:SetAttribute("TurretBranch", branchId)
	look.model.Parent = folder
	return look
end

-- สร้างข้อมูลป้อมใหม่ของ owner ที่ช่อง slot: เลือดเต็ม ยังไม่ช็อต · คืนตาราง Turret
local function build(owner: Player, slot: number): Turret
	local now = os.clock()
	local turret: Turret = {
		owner = owner,
		slot = slot,
		look = buildLook(owner, slot),
		nextFireAt = 0,
		hp = Combat.Turret.MaxHp,
		stunnedUntil = 0,
		chargeStartAt = now,
		burstLeft = 0,
		nextBurstAt = 0,
	}
	refreshLabel(turret)
	return turret
end

-- คลาส/สายเปลี่ยน หรือสายไฟข้ามขั้นสี → สร้างหน้าตาใหม่ (เลือด/ช็อตคงเดิม · ชาร์จลมเริ่มใหม่)
local function rebuildIfNeeded(player: Player)
	local turret = turrets[player]
	if not turret then
		return
	end
	local classId, branchId = TurretClassService.get(player)
	if TurretLook.keyOf(classId, branchId, levelOf(player)) ~= turret.look.key then
		turret.look.model:Destroy()
		turret.look = buildLook(player, turret.slot)
		turret.chargeStartAt = os.clock()
		turret.burstLeft = 0
		TurretLook.setStunned(turret.look, turret.stunnedUntil > 0)
	end
	refreshLabel(turret)
end

-- ได้ฐาน = ได้ป้อมหน้าฐาน · เสียฐาน (ออกเกม) = ลบป้อม
local function onBaseChanged(player: Player, slot: number?)
	local turret = turrets[player]
	if turret and turret.slot ~= slot then
		turrets[player] = nil
		turret.look.model:Destroy()
		buildIdle(turret.slot) -- เจ้าของออก → กลับเป็นป้อมว่าง
	end
	if slot and not turrets[player] then
		removeIdle(slot)
		turrets[player] = build(player, slot)
	end
end

-- ===== เลือดป้อม (โดนบอสทุบ) =====
-- ฟื้นป้อมเป็นเลือดเต็ม + เลิกช็อต + เปลี่ยนสีกลับ
local function setHealthy(turret: Turret)
	turret.hp = Combat.Turret.MaxHp
	turret.stunnedUntil = 0
	TurretLook.setStunned(turret.look, false)
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
				TurretLook.setStunned(turret.look, true)
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

-- ===== การเล็งและการยิง =====
-- เลือกเป้า: บอสในระยะก่อน → มอนที่ใกล้ที่สุดในระยะ · nil ถ้าไม่มี
local function pickTarget(turret: Turret, bossPosition: Vector3?, now: number): Target?
	local range = Combat.Turret.Range
	local origin = turret.look.headPosition
	if bossPosition and (bossPosition - origin).Magnitude <= range then
		return { position = bossPosition, monster = nil, isBoss = true }
	end
	local best, bestPosition, bestDistance = nil, nil, range
	for _, monster in MonsterService.getAlive() do
		if monster.alive then
			local position = MonsterService.positionOf(monster, now)
			local distance = (position - origin).Magnitude
			if distance <= bestDistance then
				best, bestPosition, bestDistance = monster, position, distance
			end
		end
	end
	if best and bestPosition then
		return { position = bestPosition, monster = best, isBoss = false }
	end
	return nil
end

-- ดาเมจต่อนัด (ยังไม่รวมลดเกราะ ซึ่งใส่ตอนทำดาเมจบอส): (ใส่มอน, ใส่บอส)
local function shotDamage(owner: Player, level: number, stats: ClassMath.Stats, serverNow: number): (number, number)
	local _, damageMul, bossDamageMul = SkillService.modifiers(owner, serverNow)
	local base = TurretMath.damage(level) * stats.Damage * damageMul * (1 + FriendBoostService.get(owner))
	local effect = stats.Effect
	local bossBonus = if effect and effect.Kind == "BossBonus" then effect.BossDamage else 1 -- นักแปรธาตุ: เฉพาะบอส
	return base, base * bossDamageMul * bossBonus
end

-- ยิงใส่เป้า count นัด: ดาเมจตรง + effect ของสาย + เอฟเฟกต์ภาพ
local function hit(
	turret: Turret,
	stats: ClassMath.Stats,
	target: Target,
	count: number,
	fx: { Fx },
	now: number,
	serverNow: number
)
	local owner = turret.owner
	local base, bossShot = shotDamage(owner, levelOf(owner), stats, serverNow)
	local perShot = if target.isBoss then bossShot else base

	TurretLook.aim(turret.look, target.position)
	if target.isBoss then
		TurretClassService.damageBoss(owner, perShot * count, now)
	elseif target.monster then
		MonsterService.damage(target.monster, owner, perShot * count)
	end

	local entry: Fx = {
		Kind = stats.Fx,
		From = TurretLook.muzzleOf(turret.look, target.position),
		To = target.position,
		Color = stats.Color,
	}
	local effect = stats.Effect
	if effect then
		if effect.Kind == "Dot" then
			TurretClassService.applyDot(owner, target.monster, perShot * effect.DotPerSecond, effect.DotSeconds, now)
		elseif effect.Kind == "ArmorBreak" then
			if target.isBoss then
				TurretClassService.applyArmorBreak(effect.ArmorBreak, effect.ArmorSeconds, now)
			end
		elseif effect.Kind == "BlackHole" then
			TurretClassService.spawnBlackHole(
				owner,
				target.position,
				effect.Radius,
				effect.Seconds,
				base * effect.DotPerSecond,
				bossShot * effect.DotPerSecond,
				target.isBoss,
				now
			)
			entry.Radius = effect.Radius
			entry.Duration = effect.Seconds
		end
	end
	table.insert(fx, entry)
end

-- สายลม: ชาร์จ ChargeSeconds → ยิงรัว BurstCount ดอก ห่างกัน BurstGap → ชาร์จใหม่
-- [Proposed] สกิลกาชาเพิ่มอัตรายิง = ชาร์จเร็วขึ้น · เลเวลป้อมเพิ่มแค่ดาเมจ (Config ไม่ได้ระบุ)
local function stepWind(
	turret: Turret,
	stats: ClassMath.Stats,
	bossPosition: Vector3?,
	fx: { Fx },
	now: number,
	serverNow: number
)
	local effect = stats.Effect
	if turret.burstLeft <= 0 then
		local fireRateMul = SkillService.modifiers(turret.owner, serverNow)
		if now - turret.chargeStartAt < effect.ChargeSeconds / fireRateMul then
			return
		end
		if not pickTarget(turret, bossPosition, now) then
			return -- ชาร์จเต็มแล้ว รอเป้า
		end
		turret.burstLeft = effect.BurstCount
		turret.nextBurstAt = now
	end
	local fired = 0
	while turret.burstLeft > 0 and now >= turret.nextBurstAt and fired < MAX_SHOTS_PER_TICK do
		local target = pickTarget(turret, bossPosition, now)
		if not target then
			turret.nextBurstAt = now -- เป้าหาย: ค้างดอกที่เหลือไว้ยิงเมื่อเจอเป้า
			return
		end
		hit(turret, stats, target, 1, fx, now, serverNow)
		turret.burstLeft -= 1
		turret.nextBurstAt += effect.BurstGap
		fired += 1
	end
	if turret.burstLeft <= 0 then
		turret.chargeStartAt = now
	end
end

-- ===== รอบคำนวณหลัก =====
-- ทำงานทุก 1/Combat.TickRate วินาที (จาก Start): ฟื้นเลือด → อัปเดต effect → ให้ป้อมแต่ละตัวเลือกเป้าและยิง
-- สุดท้ายส่งภาพกระสุนทั้งหมดของรอบนี้ให้ Client ครั้งเดียว (ประหยัดกว่าส่งทีละนัด)
local function tick(fxRemote: RemoteEvent)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local bossPosition = BossService.getTarget()
	local fx: { Fx } = {}
	updateHealth(now)
	TurretClassService.update(now) -- DoT/หลุมดำ/ลดเกราะ (เรียกที่นี่ที่เดียว)

	for owner, turret in turrets do
		local stats = statsOf(owner)
		local effect = stats.Effect
		if turret.stunnedUntil > 0 then
			turret.nextFireAt = now -- ช็อต: ไม่ยิง และไม่สะสมนัดค้างไว้ยิงทีเดียวหลังฟื้น
			turret.chargeStartAt = now -- ช็อต = หยุดชาร์จ (ลม) เริ่มใหม่หลังฟื้น
			turret.burstLeft = 0
			continue
		end
		if effect and effect.Kind == "ChargeBurst" then
			stepWind(turret, stats, bossPosition, fx, now, serverNow)
			continue
		end
		if now < turret.nextFireAt then
			continue
		end
		local target = pickTarget(turret, bossPosition, now)
		if not target then
			turret.nextFireAt = now -- ไม่มีเป้า: พร้อมยิงทันทีที่เจอ แต่ไม่สะสมนัดค้าง
			continue
		end

		-- ป้อมยิงเร็วกว่ารอบคำนวณ → รวมหลายนัดในรอบเดียว (count นัด, ไม่เกิน MAX_SHOTS_PER_TICK)
		-- แล้วเลื่อนเวลานัดถัดไป · math.max(..., now - interval) กันการสะสมนัดค้างนานเกินไป
		local fireRateMul = SkillService.modifiers(owner, serverNow)
		local rate = TurretMath.fireRate(levelOf(owner)) * stats.FireRate * fireRateMul
		local interval = 1 / rate
		local count = math.min(1 + math.floor((now - turret.nextFireAt) / interval), MAX_SHOTS_PER_TICK)
		turret.nextFireAt = math.max(turret.nextFireAt, now - interval) + count * interval

		hit(turret, stats, target, count, fx, now, serverNow)
	end

	if #fx > 0 then
		fxRemote:FireAllClients(fx)
	end
end

-- ===== API ให้ไฟล์อื่นเรียก =====
local TurretService = {}

-- เรียกจาก TurretHandler หลังผ่าน Guard แล้ว · คืน true ถ้าอัปสำเร็จ
function TurretService.upgrade(player: Player): boolean
	local upgraded = false
	-- หักเงิน + เพิ่มเลเวลใน PlayerData.update (บันทึกอย่างปลอดภัย) · เลเวลเต็มหรือเงินไม่พอ = ไม่ทำอะไร
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
	if upgraded then
		rebuildIfNeeded(player) -- สายไฟข้ามขั้นสี (PlayerData.Changed ก็เรียกซ้ำได้ ไม่สร้างซ้ำเพราะคีย์ตรงกันแล้ว)
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
	local now = os.clock()
	local burst = SkillMath.burst(def.Burst, level)
	local target: Target? = nil
	if burst > 0 then
		target = pickTarget(turret, BossService.getTarget(), now)
		if not target then
			return false
		end
	end

	SkillService.activate(player, id, def, level, serverNow)

	if target then
		-- ดาเมจสกิลคงสูตรเดิม (ไม่คูณตัวคูณคลาส) · ตีบอส = คูณลดเกราะด้วย
		local _, damageMul, bossDamageMul = SkillService.modifiers(player, serverNow)
		local bossMul = if target.isBoss then bossDamageMul else 1
		local multiplier = damageMul * bossMul * (1 + FriendBoostService.get(player))
		local amount = TurretMath.damage(levelOf(player)) * burst * multiplier
		TurretLook.aim(turret.look, target.position)
		if target.isBoss then
			TurretClassService.damageBoss(player, amount, now)
		elseif target.monster then
			MonsterService.damage(target.monster, player, amount)
		end
		-- เอฟเฟกต์ใช้ Kind ของคลาส/สาย · หลุมดำไม่เกิดจากสกิล → ใช้ Fx ของคลาส (มีด) แทน
		local stats = statsOf(player)
		local kind = stats.Fx
		if kind == "BlackHole" then
			local classId = TurretClassService.get(player)
			kind = ClassMath.stats(classId, "", levelOf(player)).Fx
		end
		local fxRemote = Remotes.get("TurretFx") :: RemoteEvent
		fxRemote:FireAllClients({
			{
				Kind = kind,
				From = TurretLook.muzzleOf(turret.look, target.position),
				To = target.position,
				Color = stats.Color,
			},
		})
	end
	return true
end

-- เรียกครั้งเดียวตอนเซิร์ฟเริ่ม: สร้างโฟลเดอร์ Turrets, ต่อสัญญาณจากไฟล์อื่น, สร้างป้อมว่าง/ป้อมของคนที่มีฐานแล้ว
function TurretService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Turrets"
	folder.Parent = workspace

	BaseService.Changed:Connect(onBaseChanged)
	BossService.Slammed:Connect(onSlammed)
	TurretClassService.Changed:Connect(rebuildIfNeeded)
	local owners = BaseService.owners()
	for _, slot in BaseService.slots() do
		if not owners[slot] then
			buildIdle(slot)
		end
	end
	for slot, player in owners do
		onBaseChanged(player, slot)
	end

	-- ข้อมูลโหลดเสร็จ/เปลี่ยน: อัปเดตป้าย และสร้างหน้าตาใหม่ถ้าคลาส/สาย/ขั้นสีไฟเปลี่ยน
	PlayerData.Changed:Connect(rebuildIfNeeded)
end

-- ลูปยิงหลัก: เรียก tick ทุก 1/Combat.TickRate วินาทีตลอดเกม
function TurretService.Start()
	local fxRemote = Remotes.get("TurretFx") :: RemoteEvent
	local step = 1 / Combat.TickRate
	while true do
		task.wait(step)
		tick(fxRemote)
	end
end

return TurretService
