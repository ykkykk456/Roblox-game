-- คลาสป้อมเริ่มต้น + สายธาตุ (เจ้าของ: Gameplay_Scripter) · สเปก: design/turret-classes.md · ค่า: Config/Skill_class_default
-- เลือกคลาส/สาย: รับจาก TurretClassHandler (ผ่าน Guard แล้ว) → ตรวจกฎทั้งหมดอีกรอบใน PlayerData.update (Server Authority)
-- effect ต่อเนื่อง (Server คำนวณทั้งหมด · เวลาใช้ os.clock()):
--   Dot        = ดาเมจต่อเนื่องต่อเป้า ต่อผู้ยิง · ยิงซ้ำ = รีเซ็ตเวลา/ค่า ไม่ซ้อน
--   ArmorBreak = ตัวคูณดาเมจที่บอสได้รับจากทุกผู้เล่น · หลายคนโยน = ใช้ค่าสูงสุด ไม่ซ้อน
--   BlackHole  = หลุมดำ 1 หลุมต่อเจ้าของป้อม · ดาเมจบอส/มอนที่อยู่ในรัศมีทุกรอบ
-- ป้อมช็อตไม่หยุด effect ที่ปล่อยไปแล้ว · บอสจากไป = ล้าง effect ที่ติดบอส
-- update(now) ถูกเรียกจากรอบ tick ของ TurretService เท่านั้น (ไม่มี loop ของตัวเอง กันนับซ้ำ)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassMath = require(ReplicatedStorage.Shared.Util.ClassMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BossService = require(script.Parent.BossService)
local MonsterService = require(script.Parent.MonsterService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local MAX_STEP = 0.5 -- วินาทีสูงสุดที่นับต่อรอบ (กันเซิร์ฟกระตุกแล้วดาเมจก้อนใหญ่)

-- เป้าของ DoT: ตาราง Monster จาก MonsterService หรือ BOSS
local BOSS = table.freeze({})

type Dot = { perSecond: number, startAt: number, untilAt: number }
type Hole = {
	position: Vector3,
	radius: number,
	perSecond: number, -- ใส่มอน
	bossPerSecond: number, -- ใส่บอส (รวมตัวคูณสกิลเฉพาะบอสแล้ว · ยังไม่รวมลดเกราะ)
	startAt: number,
	untilAt: number,
	onBoss: boolean,
}

local dots: { [Player]: { [any]: Dot } } = {}
local holes: { [Player]: Hole } = {}
local armor = { value = 0, untilAt = 0 }
local lastUpdate: number? = nil
local changedEvent = Instance.new("BindableEvent")

-- ช่วงเวลาที่ effect ทำงานจริงในรอบนี้ (from, now]
local function activeSeconds(from: number, now: number, startAt: number, untilAt: number): number
	return math.max(0, math.min(now, untilAt) - math.max(from, startAt))
end

local TurretClassService = {}

-- ยิงเมื่อคลาส/สายของผู้เล่นเปลี่ยน: (player) · TurretService ใช้สร้างหน้าตาป้อมใหม่
TurretClassService.Changed = changedEvent.Event

-- คลาส/สายปัจจุบัน ("" = ยังไม่เลือก / ข้อมูลยังไม่โหลด)
function TurretClassService.get(player: Player): (string, string)
	local data = PlayerData.get(player)
	if not data then
		return "", ""
	end
	local classId = if type(data.TurretClass) == "string" then data.TurretClass else ""
	local branchId = if type(data.TurretBranch) == "string" then data.TurretBranch else ""
	return classId, branchId
end

-- เลือก/เปลี่ยนคลาส · คืน true ถ้าเปลี่ยนสำเร็จ
function TurretClassService.choose(player: Player, classId: string): boolean
	local changed = false
	PlayerData.update(player, function(data)
		if not ClassMath.isClass(classId) or not ClassMath.canChooseClass(data.TurretClass, data.TurretBranch) then
			return -- ไม่มีคลาสนี้ / เลือกสายแล้ว = ล็อก
		end
		if data.TurretClass == classId then
			return
		end
		data.TurretClass = classId
		data.TurretBranch = "" -- ข้อมูลสายเสีย (ไม่รู้จัก) ล้างทิ้งพร้อมกัน
		changed = true
	end)
	if changed then
		changedEvent:Fire(player)
	end
	return changed
end

-- เลือกสายธาตุ (ครั้งเดียว) · คืน true ถ้าสำเร็จ
function TurretClassService.chooseBranch(player: Player, branchId: string): boolean
	local changed = false
	PlayerData.update(player, function(data)
		local level = TurretMath.clampLevel(data.TurretLevel)
		if not ClassMath.canChooseBranch(data.TurretClass, data.TurretBranch, branchId, level) then
			return -- ยังไม่มีคลาส / มีสายแล้ว / ไม่ใช่สายของคลาสตัวเอง / เลเวลไม่ถึง
		end
		data.TurretBranch = branchId
		changed = true
	end)
	if changed then
		changedEvent:Fire(player)
	end
	return changed
end

-- ตัวคูณดาเมจที่บอสได้รับ (ลดเกราะจากสายพิษ) · ใช้กับดาเมจบอสทุกแหล่ง
function TurretClassService.bossDamageMultiplier(now: number): number
	if now < armor.untilAt and BossService.isActive() then
		return 1 + armor.value
	end
	return 1
end

-- ทำดาเมจบอสผ่านตัวคูณลดเกราะ (จุดเดียวที่ป้อมตีบอส)
function TurretClassService.damageBoss(owner: Player, amount: number, now: number)
	BossService.damage(owner, amount * TurretClassService.bossDamageMultiplier(now))
end

-- สายพิษ: ลดเกราะบอส · ค่าสูงสุดชนะ ไม่ซ้อน · เวลาต่อจากเดิมถ้ายาวกว่า
function TurretClassService.applyArmorBreak(value: number, seconds: number, now: number)
	if not BossService.isActive() then
		return
	end
	if now >= armor.untilAt then
		armor.value = value
	else
		armor.value = math.max(armor.value, value)
	end
	armor.untilAt = math.max(armor.untilAt, now + seconds)
end

-- สายฟ้า: ติดดาเมจต่อเนื่องที่เป้า (monster = nil → บอส) · perSecond = ดาเมจต่อวินาที (ก่อนลดเกราะ)
function TurretClassService.applyDot(owner: Player, monster: any?, perSecond: number, seconds: number, now: number)
	local target = if monster then monster else BOSS
	local perOwner = dots[owner]
	if not perOwner then
		perOwner = {}
		dots[owner] = perOwner
	end
	local current = perOwner[target]
	-- รีเซ็ตเวลา ไม่ซ้อน: ยังไม่หมดเวลา → นับต่อจากเดิม (startAt เดิม) เพื่อไม่นับช่วงเดียวกันซ้ำ
	local startAt = if current and now < current.untilAt then current.startAt else now
	perOwner[target] = { perSecond = perSecond, startAt = startAt, untilAt = now + seconds }
end

-- สายมืด: สร้างหลุมดำที่จุดเป้า · แทนหลุมเดิมของเจ้าของ (1 หลุมต่อป้อม)
function TurretClassService.spawnBlackHole(
	owner: Player,
	position: Vector3,
	radius: number,
	seconds: number,
	perSecond: number,
	bossPerSecond: number,
	onBoss: boolean,
	now: number
)
	holes[owner] = {
		position = position,
		radius = radius,
		perSecond = perSecond,
		bossPerSecond = bossPerSecond,
		startAt = now,
		untilAt = now + seconds,
		onBoss = onBoss,
	}
end

-- คืนหลุมดำของเจ้าของที่ยังทำงาน (ใช้ส่งเอฟเฟกต์) หรือ nil
function TurretClassService.holeOf(owner: Player, now: number): Hole?
	local hole = holes[owner]
	return if hole and now < hole.untilAt then hole else nil
end

-- ล้าง effect ที่ติดบอส (บอสจากไป)
local function clearBoss()
	armor.value = 0
	armor.untilAt = 0
	for _, perOwner in dots do
		perOwner[BOSS] = nil
	end
	for owner, hole in holes do
		if hole.onBoss then
			holes[owner] = nil
		end
	end
end

-- เรียกทุกรอบ tick ของ TurretService: ทำดาเมจ DoT/หลุมดำ ตามเวลาที่ผ่านไป
function TurretClassService.update(now: number)
	local from = math.max(lastUpdate or now, now - MAX_STEP)
	lastUpdate = now
	local bossActive = BossService.isActive()
	if not bossActive then
		clearBoss()
	end

	for owner, perOwner in dots do
		for target, dot in perOwner do
			local alive = if target == BOSS then bossActive else target.alive
			local seconds = activeSeconds(from, now, dot.startAt, dot.untilAt)
			if alive and seconds > 0 then
				if target == BOSS then
					TurretClassService.damageBoss(owner, dot.perSecond * seconds, now)
				else
					MonsterService.damage(target, owner, dot.perSecond * seconds)
				end
			end
			if not alive or now >= dot.untilAt then
				perOwner[target] = nil -- ลบ key ระหว่างวนได้ [Verified: Luau อนุญาตตั้ง nil ให้ key ปัจจุบันขณะวน]
			end
		end
		if next(perOwner) == nil then
			dots[owner] = nil
		end
	end

	local bossPosition = BossService.getTarget()
	for owner, hole in holes do
		local seconds = activeSeconds(from, now, hole.startAt, hole.untilAt)
		if seconds > 0 then
			if bossPosition and (bossPosition - hole.position).Magnitude <= hole.radius then
				TurretClassService.damageBoss(owner, hole.bossPerSecond * seconds, now)
			end
			for _, monster in MonsterService.getAlive() do
				local distance = (MonsterService.positionOf(monster, now) - hole.position).Magnitude
				if monster.alive and distance <= hole.radius then
					MonsterService.damage(monster, owner, hole.perSecond * seconds)
				end
			end
		end
		if now >= hole.untilAt then
			holes[owner] = nil
		end
	end
end

function TurretClassService.Init()
	Players.PlayerRemoving:Connect(function(player)
		dots[player] = nil
		holes[player] = nil
	end)
end

return TurretClassService
