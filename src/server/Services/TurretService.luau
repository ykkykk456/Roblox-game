-- ป้อมของผู้เล่น: วาง · เล็ง · ยิง · อัปเลเวล · ใช้สกิลธาตุ · เลือดป้อม (เจ้าของ: Gameplay_Scripter)
-- ธาตุ + ผลติดเป้าอยู่ที่ TurretElementService · สกิลกดอยู่ที่ ElementSkillService · หน้าตาที่ TurretLook (อัปทุก 10 เลเวล)
-- สเปก: design/element-skills.md (แทนคลาสป้อม + สกิลกาชาเดิม · ระบบกาชาถูกถอดแล้ว) · อุปกรณ์ป้อม: design/equipment.md
-- Server เลือกเป้าและคำนวณดาเมจเองทั้งหมด · Client ส่งได้แค่ "ขออัป" / "ขอใช้สกิล" (ผ่าน TurretHandler)
-- ลำดับเป้า: บอส (ถ้ามีและอยู่ในระยะ) → มอนที่ใกล้ที่สุดในระยะ "เฉพาะเลนของป้อมตัวเอง" (monster.slot == turret.slot · แก้ 2026-09-30)
-- กระสุนวิ่ง: ดาเมจ + ผลติดเป้าเข้าตอนกระสุน "ถึงเป้า" (task.delay ตามเวลาเดินทาง) · เส้น/ลำแสง/สายฟ้าโดนทันที
--   เวลาเดินทาง = TurretMath.travelTime (สูตรเดียวกับที่ Client วาด) · ค่าความเร็วที่ Combat.Turret.Projectile
-- ดาเมจต่อนัด = TurretMath.damage × Friend boost × อุปกรณ์ดาเมจ (= D) × ตัวคูณธาตุ (× ทุกนัดที่ N ของลำแสงรุ้ง)
--               (× อุปกรณ์ดาเมจบอส × เกราะแตก เมื่อตีบอส → TurretElementService.damageBoss)
-- อัตรายิง   = TurretMath.fireRate × ตัวคูณธาตุ × บัฟสกิล (พายุกระสุน) × อุปกรณ์อัตรายิง
-- อุปกรณ์ป้อม (design/equipment.md หัวข้อ 10 · โบนัสจาก GearService.bonus): ดาเมจ · อัตรายิง · คูลดาวน์สกิล · ดาเมจสกิล
--   · เลือดป้อม (maxHpOf) · เวลาช็อต · ชิ้นบนป้อม (TurretLook.setGear) · เปลี่ยนอุปกรณ์ (นอกบอส) = เลือดเต็มใหม่
-- เลือดป้อม: บอสทุบพื้น (BossService.Slammed) → ลดเลือดทุกป้อม · หมด = ช็อต หยุดยิง Combat.Turret.StunSeconds แล้วฟื้นเต็ม
--   Passive ของป้อม: ผิวหิน (ทุบเบาลง) · ตัวเบา (ช็อตสั้นลง) · ชุ่มชื่น (ฟื้นเลือดเอง) · เกราะหิน (สกิลดิน กันทุบ 1 ครั้ง)
--   เตรียมไว้ให้วิวัฒนาการ (ยังไม่มีธาตุไหนใช้): คืนชีพ (Revive) · ทุกนัดที่ N (EveryNth) · บัฟอัตรายิง/กันช็อต (Buff)
--   บอสจบ = เลือดเต็มทันที · ไม่บันทึกลง DataStore (ยืนยัน 2026-09-26)
-- [Proposed] prototype: ผู้เล่น 1 คน = ป้อม 1 ตัว วางหน้าฐานของตัวเอง (BaseService)
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ระยะยิง / ดาเมจ / อัตรายิง / เลเวลสูงสุด / เลือดป้อม / เวลาช็อต → Combat.Turret.* (src/shared/Config/Combat.luau)
--   • รอบคำนวณการยิงต่อวินาที → Combat.TickRate
--   • ราคาอัปเลเวล → Economy.Turret.* · สูตรอยู่ที่ src/shared/Util/TurretMath.luau
--   • ตัวคูณธาตุ, Passive, สกิล (คูลดาวน์/ดาเมจ/รูปแบบ) → src/shared/Config/Elements.luau
--   • บอสทุบแรงแค่ไหน → Combat.Boss.SlamDamage · ตำแหน่งป้อม → แท่น Tag TurretN ในแมพ หรือ Map.Base.TurretDistance
--   • หน้าตาป้อม / โมเดลที่ import เอง → TurretLook.luau (+ Elements.LookTiers / CustomModel)
--
-- คุยกับไฟล์ไหนบ้าง:
--   • TurretHandler (Network) — เรียก upgrade / useSkill หลังตรวจ Guard แล้ว
--   • BaseService — แจ้งว่าใครได้/เสียฐาน · BossService — จุดบอส + สัญญาณทุบพื้น · MonsterService — รายชื่อมอน
--   • TurretElementService — ธาตุของผู้เล่น, ดาเมจบอส/มอน, ผลติดเป้า · ElementSkillService — สกิลกด
--   • FriendBoostService — โบนัสเพื่อน · GearService — โบนัสอุปกรณ์ + ชิ้นที่ใส่ (ฟัง GearService.Changed) · PlayerData — เลเวลป้อม + เงิน · Remote "TurretFx" — ส่งภาพให้ Client วาด
--   • Player Attribute "SkillReadyAt" / "SkillActiveUntil" — ให้ปุ่มสกิลใน UI/CombatUI นับถอยหลัง (ค่าจริงอยู่ที่ Server)
--
-- ⚠️ ระวัง: upgrade หักเงิน (ต้องทำใน PlayerData.update เท่านั้น) · อย่าให้ Client ส่งดาเมจ/เป้ามาเอง (กฎ Server Authority)
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์ยาว อ่านจากล่างขึ้นบนจะเข้าใจง่ายกว่า เพราะฟังก์ชันหลักอยู่ท้ายไฟล์)
--   1) Init (ท้ายไฟล์) — สร้างโฟลเดอร์ Turrets · ต่อสัญญาณ · สร้างป้อม
--        ได้ฐาน → onBaseChanged → build → buildLook → TurretLook.luau:build (ปั้นหน้าตาตามธาตุ + ขั้นเลเวล)
--        ไม่มีเจ้าของ → buildIdle (ป้อมเทาว่าง)
--   2) Start — วนตลอดเกม ทุก 1/Combat.TickRate วิ เรียก tick
--   3) tick — หัวใจของไฟล์:
--        updateHealth (ฟื้นช็อต / ฟื้นเลือด / บัฟหมด) → TurretElementService.luau:update (DoT/โซน)
--        → วนป้อมทุกตัว: statsOf (ElementMath.luau:stats) → ช็อตอยู่? ข้าม → ถึงเวลายิงหรือยัง → pickTarget → hit
--        → hit: ดาเมจต่อนัด → aimOf (จุดเล็ง + เวลาเดินทาง) → TurretLook.luau:aim → ใส่รายการภาพ
--             → กระสุนถึงเป้า (afterTravel) → stillHittable → ทำดาเมจ → TurretElementService.applyShot (ผลของธาตุ)
--        → ท้ายรอบ: ส่งรายการภาพทั้งหมดให้ Client วาดทีเดียว (Remote "TurretFx")
--   4) อ่านเสริม: onSlammed (บอสทุบ → เกราะหิน/ลดเลือด/ช็อต) · upgrade (อัปเลเวล → ขั้นหน้าตาเปลี่ยน = ปั้นใหม่)
--        · useSkill (สร้าง Caster → ElementSkillService.cast) · onElementChanged (เปลี่ยนธาตุ → ปั้นป้อมใหม่ + รีเซ็ตคูลดาวน์)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapMath = require(ReplicatedStorage.Shared.Util.MapMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local ElementSkillService = require(script.Parent.ElementSkillService)
local FriendBoostService = require(script.Parent.FriendBoostService)
local GearService = require(script.Parent.GearService)
local LayoutService = require(script.Parent.LayoutService)
local MonsterService = require(script.Parent.MonsterService)
local TurretElementService = require(script.Parent.TurretElementService)
local TurretLook = require(script.Parent.TurretLook)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== ค่าคงที่ =====
-- GROUND_Y = ความสูงพื้นจาก Map.GroundY (ห้ามแก้ที่นี่) · HEAD_HEIGHT = ความสูงหัวป้อมว่าง (แก้ที่ TurretLook)
-- MAX_SHOTS_PER_TICK (ปรับได้): ยิงได้สูงสุดกี่นัดต่อ 1 รอบคำนวณ · STUNNED_COLOR = สีเทาของป้อมว่าง
local GROUND_Y = Map.GroundY
local HEAD_HEIGHT = TurretLook.HEAD_HEIGHT
local MAX_SHOTS_PER_TICK = 5 -- กันอัตรายิงสูงเกินรอบคำนวณ: รวมหลายนัดเป็นครั้งเดียว (ปืนกลตอนบัฟอาจโดนตัด)
local STUNNED_COLOR = Color3.fromRGB(110, 110, 116)

-- ===== ชนิดข้อมูล =====
-- Turret = ป้อม 1 ตัวของผู้เล่น · เวลาทุกช่องเป็น os.clock() (0 = ไม่มี)
type Turret = {
	owner: Player,
	slot: number,
	look: TurretLook.Look,
	nextFireAt: number,
	hp: number,
	stunnedUntil: number, -- 0 = ไม่ช็อต
	shownHp: number, -- เลือดที่โชว์บนป้ายล่าสุด (อัปเดตป้ายเมื่อเปลี่ยนจริงเท่านั้น)
	shotCount: number, -- นับนัด (ลำแสงรุ้ง: ทุกนัดที่ N แรงขึ้น)
	shieldBlocks: number, -- เกราะหิน: กันทุบได้อีกกี่ครั้ง
	shieldUntil: number,
	reviveReadyAt: number, -- (เตรียมไว้) คืนชีพได้อีกเมื่อไร
	buffUntil: number, -- (เตรียมไว้) บัฟอัตรายิงหมดเมื่อไร
	buffRate: number, -- ตัวคูณอัตรายิงตอนบัฟ
	buffStunImmune: boolean,
	pendingStun: boolean, -- เลือดหมดระหว่างบัฟกันช็อต → ช็อตทันทีที่บัฟจบ
	healPerSecond: number, -- (เตรียมไว้) สกิลฟื้นเลือดต่อวิ จนถึง healUntil
	healUntil: number,
}

-- เป้าที่เลือกแล้ว: monster = nil เมื่อเป็นบอส (หน้าตาเดียวกับ ElementSkillService.Target)
type Target = ElementSkillService.Target

-- ภาพที่ส่งให้ Client (ดู TurretFx ใน Remotes.luau)
type Fx = { Kind: string, From: Vector3, To: Vector3, Color: Color3, Radius: number?, Duration: number? }

-- ===== สถานะระหว่างเกม =====
local turrets: { [Player]: Turret } = {}
local folder: Folder
local fxRemote: RemoteEvent
-- คูลดาวน์สกิล (เวลา Server กลาง workspace:GetServerTimeNow · Client เห็นตรงกัน) · ออกเกม = ลบ
local skillReadyAt: { [Player]: number } = {}
-- เลขรอบบอส: เพิ่ม 1 ทุกครั้งที่บอสตัวใหม่เกิด · กระสุนที่ยิงใส่บอสตัวเก่าแล้วมาถึงตอนบอสตัวใหม่อยู่ → ไม่นับดาเมจ
local bossGeneration = 0
local bossWasActive = false
local lastTick = os.clock()

-- ===== ตัวช่วย: เลเวล/ค่าพลัง =====
-- เลเวลป้อมของผู้เล่น (จาก PlayerData) · ยังโหลดข้อมูลไม่เสร็จ = Lv.1
local function levelOf(player: Player): number
	local data = PlayerData.get(player)
	return TurretMath.clampLevel(if data then data.TurretLevel else 1)
end

-- ค่าพลังรวมของป้อมตามธาตุ + เลเวล → Util/ElementMath.luau:stats
-- ตัวอย่าง: ไฟ → { Damage = 1.4, FireRate = 0.7, Fx = "Fireball", Passive = Burn, Skill = ลูกไฟพัด ... }
local function statsOf(player: Player): ElementMath.Stats
	return ElementMath.stats(TurretElementService.get(player), levelOf(player))
end

-- D = ดาเมจต่อนัดตามเลเวล × (1 + โบนัสเพื่อน) × (1 + อุปกรณ์ดาเมจ) · "ก่อน" ตัวคูณธาตุ (สูตรในสเปกหัวข้อ 1)
-- ตัวอย่าง: Lv.5 → 10 + 5×4 = 30 · เพื่อน +20% → 36 · ลำกล้อง Legendary +22% → 43.9
-- ใช้ทั้งยิงปกติและสกิล (สกิลคูณ D) → อุปกรณ์ดาเมจมีผลกับสกิลด้วย (สเปก equipment หัวข้อ 2)
local function baseDamage(player: Player, level: number): number
	return TurretMath.damage(level) * (1 + FriendBoostService.get(player)) * (1 + GearService.bonus(player).Damage)
end

-- เลือดเต็มของป้อม = Combat.Turret.MaxHp × (1 + อุปกรณ์เลือดป้อม) · ตัวอย่าง: 100 × 1.5 = 150 (เกราะ Legendary)
-- ⚠️ ใช้ฟังก์ชันนี้แทน Combat.Turret.MaxHp ทุกที่ในไฟล์นี้ (ไม่งั้นเลือดเกินเพดาน/ไม่ฟื้นเต็ม)
local function maxHpOf(player: Player): number
	return Combat.Turret.MaxHp * (1 + GearService.bonus(player).TurretHp)
end

-- คูลดาวน์สกิลหลังอุปกรณ์ลด (แกนพลัง) · ตัวอย่าง: 25 วิ × (1 − 0.15) = 21.25 วิ · ลดรวมไม่เกิน 40% (Config/Equipment.Caps)
local function skillCooldownOf(player: Player, skill: any): number
	return skill.Cooldown * (1 - GearService.bonus(player).SkillCooldown)
end

-- Passive ชนิด kind ของผู้เล่น (nil = ไม่มี) เช่น passiveOf(stats, "Regen")
local function passiveOf(stats: ElementMath.Stats, kind: string): any?
	local passive = stats.Passive
	return if passive and passive.Kind == kind then passive else nil
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

-- อัปเดตป้ายเหนือป้อม: ชื่อเจ้าของ · ธาตุ · เลเวล · เลือด (หรือ "ช็อต!")
local function refreshLabel(turret: Turret)
	local stats = statsOf(turret.owner)
	local status = if turret.stunnedUntil > 0 then "⚡ ช็อต!" else `❤ {math.ceil(turret.hp)}`
	local element = if stats.Id ~= "" then ` · {stats.Name}` else ""
	turret.shownHp = math.ceil(turret.hp)
	turret.look.label.Text = `{turret.owner.DisplayName}{element} · Lv.{levelOf(turret.owner)} · {status}`
end

-- ฐานป้อม (ระดับพื้น): บนแท่น Tag TurretN ของแมพ · ไม่มี Tag → หน้าฐานผังวงกลมเดิม
local function footOf(slot: number): Vector3
	if LayoutService.hasLayout() then
		return LayoutService.turretTop(slot)
	end
	return MapMath.point(slot, Map.Base.TurretDistance, 0) + Vector3.new(0, GROUND_Y, 0)
end

-- จุดบอสบนพื้น (ปลายเลน) · ป้อมหันไปทางนี้ตอนยังไม่มีเป้า
local function bossPoint(): Vector3
	return if LayoutService.hasLayout() then LayoutService.bossCenter() else Vector3.new(0, GROUND_Y, 0)
end

-- ส่งภาพให้ Client ทุกคน (นอกรอบ tick เช่น สกิล/คืนชีพ)
local function emit(list: { any })
	if fxRemote and #list > 0 then
		fxRemote:FireAllClients(list)
	end
end

-- ===== ป้อมว่าง / สร้างป้อม =====
-- ป้อมว่าง (ช่องที่ยังไม่มีเจ้าของ): โชว์ไว้เฉยๆ สีเทา ไม่ยิง (ยืนยัน 2026-09-27)
local idleTurrets: { [number]: Model } = {}

local function buildIdle(slot: number)
	if idleTurrets[slot] then
		return
	end
	local foot = footOf(slot)
	local model = Instance.new("Model")
	model.Name = `TurretIdle_{slot}`
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหน้าตาป้อมว่าง (ขนาด/สีเทา)
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

-- สร้างหน้าตาป้อมตามธาตุ + ขั้นเลเวลปัจจุบันของเจ้าของ (Attribute บนโมเดล = Client ใช้รู้ว่าป้อมนี้ของใคร/ธาตุอะไร)
local function buildLook(owner: Player, slot: number): TurretLook.Look
	local element = TurretElementService.get(owner)
	local look = TurretLook.build(footOf(slot), element, levelOf(owner), bossPoint())
	TurretLook.setGear(look, GearService.visuals(owner)) -- ชิ้นอุปกรณ์ที่ใส่อยู่
	look.model.Name = `Turret_{owner.UserId}`
	look.model:SetAttribute("OwnerUserId", owner.UserId)
	look.model:SetAttribute("Element", element)
	look.model.Parent = folder
	return look
end

local function build(owner: Player, slot: number): Turret
	local turret: Turret = {
		owner = owner,
		slot = slot,
		look = buildLook(owner, slot),
		nextFireAt = 0,
		hp = maxHpOf(owner),
		stunnedUntil = 0,
		shownHp = -1,
		shotCount = 0,
		shieldBlocks = 0,
		shieldUntil = 0,
		reviveReadyAt = 0,
		buffUntil = 0,
		buffRate = 1,
		buffStunImmune = false,
		pendingStun = false,
		healPerSecond = 0,
		healUntil = 0,
	}
	refreshLabel(turret)
	return turret
end

-- ธาตุเปลี่ยน หรือเลเวลข้ามขั้นหน้าตา (ทุก 10 เลเวล) / ขั้นสีไฟ → สร้างหน้าตาใหม่ (เลือด/ช็อต/เกราะคงเดิม)
local function rebuildIfNeeded(player: Player)
	local turret = turrets[player]
	if not turret then
		return
	end
	if TurretLook.keyOf(TurretElementService.get(player), levelOf(player)) ~= turret.look.key then
		turret.look.model:Destroy()
		turret.look = buildLook(player, turret.slot)
		TurretLook.setStunned(turret.look, turret.stunnedUntil > 0)
		TurretLook.setShield(turret.look, turret.shieldBlocks > 0)
	end
	refreshLabel(turret)
end

-- ตั้งคูลดาวน์สกิล (เวลา Server กลาง) + บอก Client ผ่าน Attribute (แสดงผลเท่านั้น)
local function setCooldown(player: Player, readyAt: number, activeUntil: number)
	skillReadyAt[player] = readyAt
	player:SetAttribute("SkillReadyAt", readyAt)
	player:SetAttribute("SkillActiveUntil", activeUntil)
end

-- เปลี่ยนธาตุสำเร็จ → ปั้นป้อมใหม่ · คูลดาวน์รีเซ็ตเป็น "เต็ม" (กันกดสกิลรัวด้วยการสลับ · สเปก 6.3 ข้อ 5)
-- บัฟ/เกราะ/ฟื้นเลือดของธาตุเดิมหายไปด้วย · เลือกธาตุครั้งแรก (ยังไม่เคยมีคูลดาวน์ในรอบเล่นนี้) = ใช้สกิลได้ทันที [Proposed]
local function onElementChanged(player: Player)
	local turret = turrets[player]
	if turret then
		turret.buffUntil = 0
		turret.buffRate = 1
		turret.buffStunImmune = false
		turret.healUntil = 0
		turret.shieldBlocks = 0
		turret.shotCount = 0
		-- PlayerData.Changed อาจปั้นป้อมใหม่ไปก่อนแล้ว (พร้อมเกราะเดิม) → ถอดเกราะออกตรงนี้ให้แน่
		TurretLook.setShield(turret.look, false)
	end
	local skill = statsOf(player).Skill
	local serverNow = workspace:GetServerTimeNow()
	local firstPick = skillReadyAt[player] == nil
	setCooldown(player, if skill and not firstPick then serverNow + skillCooldownOf(player, skill) else 0, 0)
	rebuildIfNeeded(player)
end

-- อุปกรณ์ที่ใส่เปลี่ยน / ข้อมูลโหลดเสร็จ / ธาตุเปลี่ยน (GearService.Changed): ปั้นชิ้นอุปกรณ์บนป้อมใหม่ + ปรับเลือดตามเลือดเต็มใหม่
-- นอกบอส = เลือดเต็มใหม่ทันที (สเปก equipment หัวข้อ 10) · ระหว่างบอส (เช่น เพิ่งโหลดข้อมูล) = แค่บีบไม่ให้เกินเลือดเต็ม
local function onGearChanged(player: Player)
	local turret = turrets[player]
	if not turret then
		return
	end
	TurretLook.setGear(turret.look, GearService.visuals(player))
	TurretLook.setStunned(turret.look, turret.stunnedUntil > 0) -- ชิ้นใหม่ต้องเทาด้วยถ้าช็อตอยู่
	local maxHp = maxHpOf(player)
	if turret.stunnedUntil == 0 then
		turret.hp = if BossService.isActive() then math.min(turret.hp, maxHp) else maxHp
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
local function setHealthy(turret: Turret)
	turret.hp = maxHpOf(turret.owner)
	turret.stunnedUntil = 0
	turret.pendingStun = false
	TurretLook.setStunned(turret.look, false)
	refreshLabel(turret)
end

-- ช็อต: หยุดยิง StunSeconds × (1 − (ตัวเบา + อุปกรณ์เวลาช็อต)) · ลดรวมไม่เกิน 70% (GearMath.stunReduce)
-- ตัวอย่าง: ลม −40% → 6 × 0.6 = 3.6 วิ · ลม + เกราะลมเต็ม → 6 × 0.3 = 1.8 วิ
local function stun(turret: Turret, now: number)
	local reduce = passiveOf(statsOf(turret.owner), "StunReduce")
	local total = GearMath.stunReduce(if reduce then reduce.Amount else 0, GearService.bonus(turret.owner).StunReduce)
	local seconds = Combat.Turret.StunSeconds * (1 - total)
	turret.hp = 0
	turret.stunnedUntil = now + seconds
	turret.pendingStun = false
	TurretLook.setStunned(turret.look, true)
end

-- ลดเลือดป้อม 1 ตัวจากการทุบ damage (หลังหน่วงแล้ว)
-- ลำดับ: เกราะหินกัน → ผิวหินลดดาเมจ → เลือดหมด? คืนชีพ / บัฟกันช็อต (เตรียมไว้) / ช็อต
local function slamTurret(turret: Turret, damage: number, now: number)
	if turret.stunnedUntil > 0 then
		return -- ช็อตอยู่แล้วไม่โดนซ้ำ
	end
	-- เกราะหิน (สกิลดิน): กันทั้งครั้ง
	if turret.shieldBlocks > 0 and now < turret.shieldUntil then
		turret.shieldBlocks -= 1
		if turret.shieldBlocks <= 0 then
			TurretLook.setShield(turret.look, false)
		end
		return
	end
	local stats = statsOf(turret.owner)
	local reduce = passiveOf(stats, "SlamReduce")
	turret.hp = math.max(turret.hp - damage * (1 - (if reduce then reduce.Amount else 0)), 0)
	if turret.hp <= 0 then
		local revive = passiveOf(stats, "Revive")
		if revive and now >= turret.reviveReadyAt then
			-- (เตรียมไว้ให้นกเพลิง) คืนชีพ: ฟื้นทันที ไม่ช็อต (1 ครั้งต่อ Cooldown วิ)
			turret.hp = maxHpOf(turret.owner) * revive.HpFraction
			turret.reviveReadyAt = now + revive.Cooldown
			emit({ { Kind = "Revive", From = turret.look.headPosition, To = turret.look.headPosition, Color = stats.Color, Radius = 6 } })
		elseif turret.buffStunImmune and now < turret.buffUntil then
			turret.pendingStun = true -- (เตรียมไว้ให้พายุกระสุน) ช็อตหลังบัฟจบ
		else
			stun(turret, now)
		end
	end
	refreshLabel(turret)
end

-- บอสทุบพื้น: หน่วงผล (เตรียมไว้ให้หอกน้ำแข็ง · ตอนนี้ไม่มีใครขอหน่วง = 0) → ลดเลือดทุกป้อม
-- [Proposed] ท่าทุบของบอสยังเล่นตามเวลาเดิม (BossService ล็อกไว้) · หน่วงเฉพาะ "ผลกับป้อม" ออกไป N วิ
local function onSlammed(damage: number)
	local delay = TurretElementService.takeSlamDelay()
	if delay > 0 then
		local bossId = bossGeneration
		task.delay(delay, function()
			-- บอสตัวเดิมต้องยังอยู่ (บอสไปแล้ว = ไม่ทุบ)
			if BossService.isActive() and bossGeneration == bossId then
				local now = os.clock()
				for _, turret in turrets do
					slamTurret(turret, damage, now)
				end
			end
		end)
		return
	end
	local now = os.clock()
	for _, turret in turrets do
		slamTurret(turret, damage, now)
	end
end

-- ทุกรอบ: ฟื้นช็อตครบเวลา · บอสจบ = เต็ม · ชุ่มชื่นฟื้นเลือด · บัฟหมด (+ ช็อตค้าง) · เกราะหินหมดเวลา
local function updateHealth(now: number, dt: number)
	local bossActive = BossService.isActive()
	for _, turret in turrets do
		local maxHp = maxHpOf(turret.owner)
		local stunOver = turret.stunnedUntil > 0 and now >= turret.stunnedUntil
		local bossOver = not bossActive and (turret.stunnedUntil > 0 or turret.hp < maxHp)
		if stunOver or bossOver then
			setHealthy(turret)
		end
		-- บัฟจบ → ถ้าเลือดหมดระหว่างบัฟ ช็อตตอนนี้
		if turret.buffUntil > 0 and now >= turret.buffUntil then
			turret.buffUntil = 0
			turret.buffRate = 1
			turret.buffStunImmune = false
			if turret.pendingStun and bossActive then
				stun(turret, now)
				refreshLabel(turret)
			end
			turret.pendingStun = false
		end
		-- เกราะหินหมดเวลา
		if turret.shieldBlocks > 0 and now >= turret.shieldUntil then
			turret.shieldBlocks = 0
			TurretLook.setShield(turret.look, false)
		end
		-- ฟื้นเลือด (ไม่ฟื้นตอนช็อต · เต็มแล้วไม่ต้อง)
		if turret.stunnedUntil == 0 and turret.hp < maxHp and not turret.pendingStun then
			local regen = passiveOf(statsOf(turret.owner), "Regen")
			local perSecond = (if regen then regen.HpPerSecond else 0) + (if now < turret.healUntil then turret.healPerSecond else 0)
			if perSecond > 0 then
				turret.hp = math.min(turret.hp + perSecond * dt, maxHp)
				if math.ceil(turret.hp) ~= turret.shownHp then
					refreshLabel(turret)
				end
			end
		end
	end
end

-- ===== การเล็งและการยิง =====
-- เลขรอบบอสตอนนี้ (อัปเดตเมื่อเห็นบอสเปลี่ยนจาก "ไม่มี" → "มี")
local function currentBossGeneration(): number
	local active = BossService.isActive()
	if active and not bossWasActive then
		bossGeneration += 1
	end
	bossWasActive = active
	return bossGeneration
end

-- เลือกเป้า: บอสในระยะก่อน → มอนที่ใกล้ที่สุดในระยะ (เฉพาะเลนของป้อมนี้) · nil ถ้าไม่มี
-- มอนใกล้ป้อมที่สุด = มอน "หน้าสุด" ของเลน (ใช้เป็นเป้าสกิลด้วย ตามสเปกหัวข้อ 1)
local function pickTarget(turret: Turret, bossPosition: Vector3?, now: number): Target?
	local range = Combat.Turret.Range
	local origin = turret.look.headPosition
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนลำดับความสำคัญของเป้า (เช่น ยิงมอนก่อนบอส)
	if bossPosition and (bossPosition - origin).Magnitude <= range then
		return { position = bossPosition, monster = nil, isBoss = true }
	end
	-- ยิงเฉพาะมอนในเลนของตัวเอง (MonsterService ติด monster.slot ตอนเกิด) · บอสยังยิงได้ทุกป้อม
	local best, bestPosition, bestDistance = nil, nil, range
	for _, monster in MonsterService.getAlive() do
		if monster.alive and monster.slot == turret.slot then
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

-- จุดเล็ง + ปากกระบอก + เวลาเดินทางของกระสุน kind (0 = โดนทันที) · กระสุนวิ่งใส่มอน → เล็งดักหน้า
local function aimOf(turret: Turret, kind: string, target: Target, now: number): (Vector3, Vector3, number)
	local point = target.position
	local muzzle = TurretLook.muzzleOf(turret.look, point)
	local travel = TurretMath.travelTime(kind, (point - muzzle).Magnitude)
	if travel > 0 and target.monster then
		point = MonsterService.positionOf(target.monster, now + travel)
		muzzle = TurretLook.muzzleOf(turret.look, point)
		travel = TurretMath.travelTime(kind, (point - muzzle).Magnitude)
	end
	return point, muzzle, travel
end

-- ตอนกระสุนถึง: เป้ายังตีได้ไหม · ผู้ยิงออกจากเกม = ไม่นับ · บอส = ต้องยังอยู่และเป็นตัวเดิม · มอน = ยังไม่ตาย
local function stillHittable(owner: Player, target: Target, bossId: number): boolean
	if owner.Parent == nil then
		return false
	end
	if target.isBoss then
		return BossService.isActive() and currentBossGeneration() == bossId
	end
	return target.monster ~= nil and target.monster.alive
end

-- เรียก land ทันที (travel = 0) หรือรอให้กระสุนถึงก่อน
local function afterTravel(travel: number, land: () -> ())
	if travel > 0 then
		task.delay(travel, land)
	else
		land()
	end
end

-- ยิงใส่เป้า count นัด: ภาพ (ส่งทันที) + ดาเมจ + ผลของธาตุ (เข้าตอนกระสุนถึงเป้า)
local function hit(turret: Turret, stats: ElementMath.Stats, target: Target, count: number, fx: { Fx }, now: number)
	-- ขั้น 1: ดาเมจต่อนัด = D × ตัวคูณธาตุ · (เตรียมไว้ให้ลำแสงรุ้ง: ทุกนัดที่ N แรง × Multiplier)
	-- ตัวอย่าง: D 30 × น้ำ 0.8 = 24 ต่อนัด
	local owner = turret.owner
	local D = baseDamage(owner, levelOf(owner))
	local perShot = D * stats.Damage
	local total = perShot * count
	local nth = passiveOf(stats, "EveryNth")
	if nth and nth.N > 0 then
		local bonusShots = math.floor((turret.shotCount + count) / nth.N) - math.floor(turret.shotCount / nth.N)
		total += perShot * bonusShots * (nth.Multiplier - 1)
	end
	turret.shotCount += count

	-- ขั้น 2: หาจุดเล็ง + เวลาเดินทาง แล้วหันป้อม (แค่หน้าตา)
	local aimPoint, muzzle, travel = aimOf(turret, stats.Fx, target, now)
	TurretLook.aim(turret.look, aimPoint)

	-- ขั้น 3: ภาพกระสุน 1 รายการ (Kind = ชนิดภาพ, From = ปากกระบอก, To = เป้า) · Radius = รัศมีระเบิด (ถ้ามี)
	table.insert(fx, {
		Kind = stats.Fx,
		From = muzzle,
		To = aimPoint,
		Color = stats.Color,
		Radius = stats.Shot.Splash,
	})

	-- ขั้น 4: กระสุนถึงเป้า → เช็กเป้ายังอยู่ → ดาเมจ → ผลของธาตุ (Splash/ช้าลง/ถอย/ทะลุ/Passive)
	-- ⚠️ ระวัง: เวลาใน land ต้องใช้ os.clock() ตอนถึง (landedAt) ไม่ใช่ now ตอนยิง
	local bossId = currentBossGeneration()
	local slot = turret.slot
	afterTravel(travel, function()
		if not stillHittable(owner, target, bossId) then
			return -- เป้าตาย/ถึงปลายเลน/บอสไปแล้ว ระหว่างกระสุนวิ่ง → นัดนี้ไม่โดน
		end
		local landedAt = os.clock()
		if target.isBoss then
			TurretElementService.damageBoss(owner, total, landedAt)
		elseif target.monster then
			TurretElementService.damageMonster(target.monster, owner, total)
		end
		TurretElementService.applyShot(owner, slot, stats, target.monster, aimPoint, D, total, landedAt)
	end)
end

-- ===== รอบคำนวณหลัก =====
-- ทุก 1/Combat.TickRate วินาที: ฟื้นเลือด → อัปเดตผลต่อเนื่อง → ป้อมแต่ละตัวเลือกเป้าและยิง → ส่งภาพทีเดียว
local function tick()
	local now = os.clock()
	local dt = math.min(now - lastTick, 0.5)
	lastTick = now
	local bossPosition = BossService.getTarget()
	local fx: { Fx } = {}
	currentBossGeneration()
	updateHealth(now, dt)
	TurretElementService.update(now) -- DoT/โซน/เกราะแตก (เรียกที่นี่ที่เดียว)

	for owner, turret in turrets do
		-- ด่าน 1: ช็อตอยู่ → ไม่ยิง และไม่สะสมนัดค้าง
		if turret.stunnedUntil > 0 then
			turret.nextFireAt = now
			continue
		end
		-- ด่าน 2: ยังไม่ถึงเวลานัดถัดไป
		if now < turret.nextFireAt then
			continue
		end
		-- ด่าน 3: หาเป้า · ไม่มี = ไม่ยิง
		local target = pickTarget(turret, bossPosition, now)
		if not target then
			turret.nextFireAt = now
			continue
		end
		-- อัตรายิง (นัด/วิ) = ตามเลเวล × ตัวคูณธาตุ × บัฟ × (1 + อุปกรณ์อัตรายิง) · ยิงเร็วกว่ารอบคำนวณ → รวมหลายนัดในรอบเดียว
		-- ตัวอย่าง: Lv.5 → 1.4 × ลม 1.9 = 2.66 นัด/วิ → interval ≈ 0.38 วิ · กลไก +16% → 3.09 นัด/วิ
		-- ⚠️ อุปกรณ์อัตรายิงคูณแค่ตรงนี้ ไม่คูณในสกิล (ElementMath.skillScale) กันนับซ้ำ
		local stats = statsOf(owner)
		local buff = if now < turret.buffUntil then turret.buffRate else 1
		local rate = TurretMath.fireRate(levelOf(owner)) * stats.FireRate * buff * (1 + GearService.bonus(owner).FireRate)
		local interval = 1 / rate
		local count = math.min(1 + math.floor((now - turret.nextFireAt) / interval), MAX_SHOTS_PER_TICK)
		turret.nextFireAt = math.max(turret.nextFireAt, now - interval) + count * interval

		hit(turret, stats, target, count, fx, now)
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
	-- ⚠️ ระวัง: ส่วนนี้แตะเงินจริง · ต้องเช็ก "เงินพอ" ก่อนหักเสมอ และแก้ data ใน update เท่านั้น
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
		rebuildIfNeeded(player) -- ข้ามขั้นหน้าตา (Lv.10/20/30/40/50) / ขั้นสีไฟ → ปั้นใหม่
	end
	return upgraded
end

-- เรียกจาก TurretHandler หลังผ่าน Guard แล้ว · ใช้สกิลธาตุ · คืน true ถ้าสำเร็จ
-- ด่านตรวจ: มีป้อม · มีธาตุ (มีสกิล) · ไม่ช็อต · คูลดาวน์หมด · มีเป้าในระยะ — ไม่ผ่าน = ไม่ทำอะไร ไม่เสียคูลดาวน์
-- ⚠️ ระวัง: ห้ามลบด่านพวกนี้ ไม่งั้น Client กดรัวใช้สกิลได้ไม่จำกัด
function TurretService.useSkill(player: Player): boolean
	local turret = turrets[player]
	if not turret or turret.stunnedUntil > 0 then
		return false
	end
	local stats = statsOf(player)
	local skill = stats.Skill
	if not skill then
		return false -- ยังไม่เลือกธาตุ
	end
	local serverNow = workspace:GetServerTimeNow()
	if serverNow < (skillReadyAt[player] or 0) then
		return false
	end
	local now = os.clock()
	local target = pickTarget(turret, BossService.getTarget(), now)
	if not target then
		return false -- ไม่มีเป้าในระยะ = กดไม่ได้ ไม่เสียคูลดาวน์
	end

	-- Caster = ข้อมูล + ปุ่มควบคุมป้อมนี้ ให้ ElementSkillService ใช้ (ไฟล์นั้นไม่ต้อง require ไฟล์นี้)
	-- D ของสกิล = D × (1 + อุปกรณ์ดาเมจสกิล) · ตัวอย่าง: D 43.9 × ไฟตรง Legendary 1.25 = 54.9
	local level = levelOf(player)
	local caster: ElementSkillService.Caster = {
		owner = player,
		slot = turret.slot,
		level = level,
		D = baseDamage(player, level) * (1 + GearService.bonus(player).SkillDamage),
		color = stats.Color,
		stats = stats,
		foot = turret.look.foot,
		bossGround = bossPoint(),
		alive = function()
			return player.Parent ~= nil and turrets[player] == turret
		end,
		stunned = function()
			return turret.stunnedUntil > 0
		end,
		pick = function()
			return pickTarget(turret, BossService.getTarget(), os.clock())
		end,
		refresh = function(old: Target): Target?
			if old.isBoss then
				local position = BossService.getTarget()
				return if position then { position = position, monster = nil, isBoss = true } else nil
			end
			local monster = old.monster
			if monster and monster.alive then
				return { position = MonsterService.positionOf(monster, os.clock()), monster = monster, isBoss = false }
			end
			return nil
		end,
		predict = function(t: Target, seconds: number): Vector3
			if t.monster then
				return MonsterService.positionOf(t.monster, os.clock() + seconds)
			end
			return t.position
		end,
		muzzle = function(point: Vector3): Vector3
			return TurretLook.muzzleOf(turret.look, point)
		end,
		aim = function(point: Vector3)
			if turrets[player] == turret then
				TurretLook.aim(turret.look, point)
			end
		end,
		bossId = currentBossGeneration,
		hittable = function(t: Target, bossId: number): boolean
			return stillHittable(player, t, bossId)
		end,
		emit = emit,
		heal = function(amount: number)
			if turret.stunnedUntil == 0 then
				turret.hp = math.min(turret.hp + amount, maxHpOf(player))
				refreshLabel(turret)
			end
		end,
		healOverTime = function(perSecond: number, seconds: number)
			turret.healPerSecond = perSecond
			turret.healUntil = os.clock() + seconds
		end,
		shield = function(blocks: number, seconds: number)
			turret.shieldBlocks = blocks
			turret.shieldUntil = os.clock() + seconds
			TurretLook.setShield(turret.look, true)
		end,
		buff = function(rate: number, seconds: number, stunImmune: boolean)
			turret.buffRate = rate
			turret.buffUntil = os.clock() + seconds
			turret.buffStunImmune = stunImmune
		end,
	}

	local activeSeconds = ElementSkillService.cast(caster, skill, target)
	if not activeSeconds then
		return false -- รูปแบบไม่รู้จัก (Config ผิด) → ไม่เสียคูลดาวน์
	end
	setCooldown(player, serverNow + skillCooldownOf(player, skill), serverNow + activeSeconds)
	return true
end

-- เรียกครั้งเดียวตอนเซิร์ฟเริ่ม: สร้างโฟลเดอร์ Turrets, ต่อสัญญาณจากไฟล์อื่น, สร้างป้อมว่าง/ป้อมของคนที่มีฐานแล้ว
function TurretService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Turrets"
	folder.Parent = workspace
	fxRemote = Remotes.get("TurretFx") :: RemoteEvent

	-- ได้/เสียฐาน → onBaseChanged · บอสทุบพื้น → onSlammed · ธาตุเปลี่ยน → onElementChanged · อุปกรณ์เปลี่ยน → onGearChanged
	BaseService.Changed:Connect(onBaseChanged)
	BossService.Slammed:Connect(onSlammed)
	TurretElementService.Changed:Connect(onElementChanged)
	GearService.Changed:Connect(onGearChanged)
	local owners = BaseService.owners()
	for _, slot in BaseService.slots() do
		if not owners[slot] then
			buildIdle(slot)
		end
	end
	for slot, player in owners do
		onBaseChanged(player, slot)
	end

	-- ข้อมูลโหลดเสร็จ/เปลี่ยน: อัปเดตป้าย และสร้างหน้าตาใหม่ถ้าธาตุ/ขั้นหน้าตา/ขั้นสีไฟเปลี่ยน
	PlayerData.Changed:Connect(rebuildIfNeeded)
	Players.PlayerRemoving:Connect(function(player)
		skillReadyAt[player] = nil
	end)
end

-- ลูปยิงหลัก: เรียก tick ทุก 1/Combat.TickRate วินาทีตลอดเกม
-- ⚠️ ระวัง: ห้ามลบ task.wait — ลูปจะวนไม่หยุดจนเซิร์ฟค้าง
function TurretService.Start()
	local step = 1 / Combat.TickRate
	while true do
		task.wait(step)
		-- pcall: ถ้ารอบไหน error ป้อมทุกตัวไม่หยุดยิงถาวร (แค่ข้ามรอบนั้น + เตือนใน Output)
		local ok, err = pcall(tick)
		if not ok then
			warn(`[TurretService] tick error: {err}`)
		end
	end
end

return TurretService
