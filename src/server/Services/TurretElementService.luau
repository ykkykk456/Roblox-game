-- ธาตุป้อม + ผลต่อเนื่องของธาตุ (เจ้าของ: Gameplay_Scripter) · สเปก: design/element-skills.md · ค่า: Config/Elements
-- แทน TurretClassService เดิม (คลาส Mage/Archer/Assassin/Cannon) · ตอนนี้มีแค่ธาตุพื้นฐาน 4 ธาตุ (วิวัฒนาการ = แผน ยังไม่ทำ)
-- เลือก/เปลี่ยนธาตุ: รับจาก Network/ElementHandler (ผ่าน Guard แล้ว) → ตรวจกฎซ้ำ + หักเงินใน PlayerData.update (Server Authority)
-- ผลต่อเนื่อง (Server คำนวณทั้งหมด · เวลาใช้ os.clock()):
--   Dot        = ดาเมจต่อเนื่องต่อเป้า ต่อผู้ยิง ต่อชนิด (Burn เผาไหม้ · เตรียมไว้: Shock / Poison) · ยิงซ้ำ = ไม่ซ้อน (ค่าแรงกว่าชนะ)
--   เตรียมไว้ให้วิวัฒนาการ (ยังไม่มีธาตุไหนใช้):
--     ArmorBreak = บอสรับดาเมจจากทุกคนเพิ่ม · ค่าสูงสุดชนะ · สกิลให้เครดิตคนใช้ (AssistCredit)
--     Zone       = บ่อพิษ / หลุมดำ 1 โซนต่อเจ้าของ · SlamDelay = หน่วงผลการทุบครั้งถัดไป (TurretService.onSlammed เป็นคนหน่วง)
-- ป้อมช็อตไม่หยุดผลที่ปล่อยไปแล้ว · บอสจากไป = ล้างผลที่ติดบอสทั้งหมด
-- update(now) ถูกเรียกจากรอบ tick ของ TurretService เท่านั้น (ไม่มี loop ของตัวเอง กันนับซ้ำ)
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ตัวคูณ/ค่า Passive/Status/Pattern ของแต่ละธาตุ, ราคาเปลี่ยนธาตุ → src/shared/Config/Elements.luau
--   • กฎการเลือก → src/shared/Util/ElementMath.luau (canChooseElement)
--
-- คุยกับไฟล์ไหนบ้าง:
--   • Network/ElementHandler — เรียก choose · TurretService + ElementSkillService — เรียก damage*/apply*/spawnZone/update
--   • BossService — นับดาเมจบอส · MonsterService — ทำดาเมจ/ช้าลง/ถอย/ดูดมอน · PlayerData — เก็บธาตุ (+ หักเงินเปลี่ยนธาตุ)
--
-- ⚠️ ห้ามแก้: การเปลี่ยนธาตุ/หักเงิน ต้องอยู่ใน PlayerData.update และตรวจกฎซ้ำเสมอ (ห้ามเชื่อค่าที่ Client ส่งมา)
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์นี้มี 2 งานแยกกัน)
--   งาน A: เลือกธาตุ
--     1) Network/ElementHandler.luau ส่งคำขอมา → choose
--     2) ใน PlayerData.update: ตรวจกฎด้วย Util/ElementMath.luau:canChooseElement → เงินพอ → หักเงิน + เขียนธาตุ
--     3) สำเร็จ → changedEvent:Fire → TurretService.luau:onElementChanged (ปั้นป้อมใหม่ + รีเซ็ตคูลดาวน์สกิล)
--   งาน B: ผลของธาตุตอนยิง/ใช้สกิล
--     4) TurretService.luau:hit (ยิงปกติ) → applyShot (Splash, ช้าลง, ถอย, ทะลุ, Passive)
--        ElementSkillService (สกิล) → damageBoss / damageMonster / applyStatus
--     5) ผลที่ "ค้าง" (DoT, โซน) แค่จดไว้ในตาราง dots / zones → update(now) ทุก 0.1 วิ ทำดาเมจตามเวลาที่ผ่านไป
--     6) ทุกครั้งที่ตีบอส ผ่าน damageBoss → คูณเกราะแตก (ถ้ามี) → BossService.damage
--   ✏️ อยากเพิ่ม Passive/Status ชนิดใหม่ → applyShot / applyStatus (+ ใส่ Kind ใน Config)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local BossService = require(script.Parent.BossService)
local MonsterService = require(script.Parent.MonsterService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== ค่าคงที่ =====
-- MAX_STEP (ปรับได้): เซิร์ฟค้างนานแค่ไหนก็นับดาเมจต่อเนื่องได้ไม่เกินเท่านี้ต่อรอบ
local MAX_STEP = 0.5
-- BOSS = ตารางว่างที่ใช้เป็น "ป้ายชื่อ" แทนบอสในตาราง DoT (ห้ามแก้) · ตารางแต่ละอันไม่ซ้ำ จึงไม่ชนกับมอนตัวไหน
local BOSS = table.freeze({})

-- ===== ชนิดข้อมูล =====
-- Dot = ดาเมจต่อเนื่อง 1 ชั้น (perSecond ต่อวินาที ตั้งแต่ startAt ถึง untilAt)
type Dot = { perSecond: number, startAt: number, untilAt: number }
-- Zone = บ่อพิษ/หลุมดำ 1 โซน · perSecond ใส่มอน · bossPerSecond ใส่บอส · pull = ดูดมอนกี่ studs/วิ (0 = ไม่ดูด)
export type Zone = {
	position: Vector3,
	radius: number,
	perSecond: number,
	bossPerSecond: number,
	pull: number,
	startAt: number,
	untilAt: number,
	onBoss: boolean, -- เกิดบนบอส → บอสไป = หายด้วย
}

-- ===== สถานะผลที่กำลังทำงาน =====
-- dots[ผู้ยิง][เป้า][ชนิด] = Dot · zones[เจ้าของ] = โซน 1 อัน · armor = เกราะแตกของบอสตอนนี้
-- ⚠️ ระวัง: ข้อมูลพวกนี้อยู่ในหน่วยความจำเท่านั้น ไม่บันทึกลง DataStore (เซิร์ฟปิด = หายหมด ซึ่งถูกต้องแล้ว)
local dots: { [Player]: { [any]: { [string]: Dot } } } = {}
local zones: { [Player]: Zone } = {}
-- value = 0.2 → บอสโดนแรงขึ้น 20% · creditOwner/credit = ใครได้เครดิตส่วนเพิ่ม และสัดส่วนเท่าไร (สกิลพิษ)
local armor: { value: number, untilAt: number, creditOwner: Player?, credit: number } =
	{ value = 0, untilAt = 0, creditOwner = nil, credit = 0 }
-- หน่วงทุบ: pending = วินาทีที่จะหน่วงการทุบครั้งถัดไป · readyAt = ทั้งเซิร์ฟใช้ได้อีกเมื่อไร (os.clock)
local slamDelay = { pending = 0, readyAt = 0 }
local lastUpdate: number? = nil
-- BindableEvent = "กริ่ง" ส่งสัญญาณระหว่างสคริปต์ฝั่ง Server · ดังเมื่อธาตุของผู้เล่นเปลี่ยน
local changedEvent = Instance.new("BindableEvent")

-- ช่วงเวลาที่ผลทำงานจริงในรอบนี้ (from, now] · ไม่ติดลบ
-- ตัวอย่าง: รอบ 10.0 → 10.1 · DoT หมดที่ 10.05 → นับ 0.05 วิ
local function activeSeconds(from: number, now: number, startAt: number, untilAt: number): number
	return math.max(0, math.min(now, untilAt) - math.max(from, startAt))
end

-- ระยะแนวราบ (ไม่นับความสูง) · ใช้กับโซนบนพื้น: บอส/มอนตัวสูงต่ำต่างกันก็ยังนับว่าอยู่ในวง
local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ===== API: เลือกธาตุ =====
local TurretElementService = {}

-- ดังเมื่อธาตุของผู้เล่นเปลี่ยน: (player) · TurretService ใช้ปั้นป้อมใหม่ + รีเซ็ตคูลดาวน์
TurretElementService.Changed = changedEvent.Event

-- ธาตุปัจจุบัน ("" = ยังไม่เลือก / ข้อมูลยังไม่โหลด / ข้อมูลเสีย)
function TurretElementService.get(player: Player): string
	local data = PlayerData.get(player)
	if not data then
		return ""
	end
	-- กันข้อมูลเสีย: ไม่ใช่ธาตุที่รู้จัก → ""
	return if ElementMath.isElement(data.Element) then data.Element else ""
end

-- เลือกธาตุครั้งแรก (ฟรี) หรือเปลี่ยนธาตุ (เสียเงิน ChangeElementCost · ห้ามระหว่างบอส · เลเวลป้อมคงเดิม)
-- คืน true ถ้าเปลี่ยนสำเร็จ
function TurretElementService.choose(player: Player, id: string): boolean
	local changed = false
	local bossActive = BossService.isActive()
	-- ⚠️ ระวัง: ส่วนนี้แตะเงินจริง · ห้ามย้ายการแก้ data ออกนอก update และห้ามตัดการตรวจ if ข้างล่าง
	PlayerData.update(player, function(data)
		local current = if ElementMath.isElement(data.Element) then data.Element else ""
		-- กฎ: มีธาตุนี้จริง · ไม่ใช่ธาตุเดิม · เปลี่ยน = บอสต้องไม่อยู่ → Util/ElementMath.luau:canChooseElement
		local allowed, cost = ElementMath.canChooseElement(current, id, bossActive)
		if not allowed then
			return
		end
		-- เงินไม่พอ = ไม่ทำอะไร (เลือกครั้งแรก cost = 0 ผ่านเสมอ)
		local coins = if type(data.Coins) == "number" then data.Coins else 0
		if coins < cost then
			return
		end
		data.Coins = coins - cost
		data.Element = id
		changed = true
	end)
	if changed then
		changedEvent:Fire(player)
	end
	return changed
end

-- ===== API: ดาเมจ =====
-- ตัวคูณดาเมจที่บอสได้รับตอนนี้ (เกราะแตก) · ตัวอย่าง: armor.value 0.2 → 1.2
function TurretElementService.bossDamageMultiplier(now: number): number
	if now < armor.untilAt and BossService.isActive() then
		return 1 + armor.value
	end
	return 1
end

-- ทำดาเมจบอส (จุดเดียวที่ป้อมตีบอส): คูณเกราะแตก → BossService.damage
-- เครดิตซัพพอร์ต (เตรียมไว้ให้ปฐพีพิษ): คนอื่นตีบอสตอนเกราะแตกจากสกิล → คนใช้ได้ดาเมจเพิ่มในตาราง = ส่วนเพิ่ม × AssistCredit
-- ตัวอย่าง: B ตี 100 ตอนเกราะแตก 20% (A ใช้สกิล, credit 0.5) → B ได้ 120 · A ได้เครดิต 20 × 0.5 = 10 · ไม่มีเกราะแตก = ×1
-- ⚠️ ระวัง: ดาเมจบอส = รางวัลผู้เล่น (BossService แจกตามดาเมจ) · ตีบอสจากที่อื่นต้องผ่านฟังก์ชันนี้เสมอ
function TurretElementService.damageBoss(owner: Player, amount: number, now: number)
	if amount ~= amount or amount <= 0 then
		return
	end
	local multiplier = TurretElementService.bossDamageMultiplier(now)
	BossService.damage(owner, amount * multiplier)
	local creditOwner = armor.creditOwner
	if multiplier > 1 and creditOwner and creditOwner ~= owner and creditOwner.Parent and armor.credit > 0 then
		BossService.damage(creditOwner, amount * (multiplier - 1) * armor.credit)
	end
end

-- ทำดาเมจมอน (ผ่าน MonsterService ที่แบ่งเงินตามดาเมจ)
function TurretElementService.damageMonster(monster: any, owner: Player, amount: number)
	if amount ~= amount or amount <= 0 then
		return
	end
	MonsterService.damage(monster, owner, amount)
end

-- มอนที่ยังมีชีวิตในรัศมี radius รอบ center (วัดแนวราบ: จุดระเบิดบนตัวบอสสูงๆ ก็ยังโดนมอนบนพื้น)
-- slot = เฉพาะเลนนั้น (nil = ทุกเลน) · except = ข้ามตัวนี้
function TurretElementService.monstersNear(center: Vector3, radius: number, now: number, slot: number?, except: any?): { any }
	local found = {}
	for _, monster in MonsterService.getAlive() do
		if monster.alive and monster ~= except and (slot == nil or monster.slot == slot) then
			if flatDistance(MonsterService.positionOf(monster, now), center) <= radius then
				table.insert(found, monster)
			end
		end
	end
	return found
end

-- มอนในเลน slot เรียงจากใกล้ point → ไกล (ไม่เกิน limit ตัว) · ใช้กับทะลุ/สายฟ้ากระโดด
function TurretElementService.nearestInLane(slot: number, point: Vector3, now: number, limit: number, except: any?): { any }
	local list: { { monster: any, distance: number } } = {}
	for _, monster in MonsterService.getAlive() do
		if monster.alive and monster.slot == slot and monster ~= except then
			local distance = (MonsterService.positionOf(monster, now) - point).Magnitude
			table.insert(list, { monster = monster, distance = distance })
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	local result = {}
	for index = 1, math.min(limit, #list) do
		table.insert(result, list[index].monster)
	end
	return result
end

-- ===== API: ผลต่อเนื่อง =====
-- ติด DoT ชนิด kind ("Burn" / "Shock" / "Poison") ที่เป้า (monster = nil → บอส)
-- ไม่ซ้อน: ชั้นเดิมยังอยู่และแรงกว่า → เก็บของเดิม · ใหม่แรงกว่า/เท่ากัน → ทับค่า + รีเซ็ตเวลา (นับต่อจากเดิม ไม่นับซ้ำ)
-- ตัวอย่าง: D = 30 · เผาไหม้ 0.1D/วิ = 3/วิ นาน 3 วิ = 9 · โดนซ้ำ → เวลานับใหม่ 3 วิ
function TurretElementService.applyDot(owner: Player, monster: any?, kind: string, perSecond: number, seconds: number, now: number)
	if perSecond ~= perSecond or perSecond <= 0 or seconds <= 0 then
		return
	end
	if monster == nil and not BossService.isActive() then
		return
	end
	local target = if monster then monster else BOSS
	local perOwner = dots[owner]
	if not perOwner then
		perOwner = {}
		dots[owner] = perOwner
	end
	local perTarget = perOwner[target]
	if not perTarget then
		perTarget = {}
		perOwner[target] = perTarget
	end
	local current = perTarget[kind]
	local active = current ~= nil and now < current.untilAt
	if active and current and current.perSecond > perSecond then
		return -- ชั้นเดิมแรงกว่า (เช่น เผาไหม้จากสกิล) → ไม่ทับด้วยของอ่อนกว่า
	end
	local startAt = if active and current then current.startAt else now
	perTarget[kind] = { perSecond = perSecond, startAt = startAt, untilAt = now + seconds }
end

-- เกราะแตก: บอสรับดาเมจจากทุกคน +value นาน seconds · ค่าสูงสุดชนะ ไม่ซ้อน · credit > 0 = ผู้ใช้ได้เครดิตส่วนเพิ่ม
function TurretElementService.applyArmorBreak(owner: Player, value: number, seconds: number, credit: number, now: number)
	if not BossService.isActive() or value <= 0 then
		return
	end
	if now >= armor.untilAt then
		armor.value = value
		armor.creditOwner = nil
		armor.credit = 0
	else
		armor.value = math.max(armor.value, value)
	end
	-- เครดิตไปที่คนที่ทำค่าสูงสุดล่าสุดด้วยสกิล (Passive credit = 0 ไม่แย่งเครดิตสกิล)
	if credit > 0 and value >= armor.value then
		armor.creditOwner = owner
		armor.credit = credit
	end
	armor.untilAt = math.max(armor.untilAt, now + seconds)
end

-- สร้างโซน (บ่อพิษ/หลุมดำ) · แทนโซนเดิมของเจ้าของ (1 โซนต่อป้อม)
function TurretElementService.spawnZone(owner: Player, zone: Zone)
	zones[owner] = zone
end

-- ขอหน่วงการทุบครั้งถัดไปของบอส seconds วิ · ทั้งเซิร์ฟใช้ได้ 1 ครั้งต่อ cooldown วิ · คืน true ถ้าได้
function TurretElementService.requestSlamDelay(seconds: number, cooldown: number, now: number): boolean
	if not BossService.isActive() or now < slamDelay.readyAt then
		return false
	end
	slamDelay.pending = math.max(slamDelay.pending, seconds)
	slamDelay.readyAt = now + cooldown
	return true
end

-- TurretService.onSlammed เรียกตอนบอสทุบ: คืนวินาทีที่ต้องหน่วง (0 = ไม่หน่วง) แล้วล้างค่า (ใช้ได้ครั้งเดียว)
function TurretElementService.takeSlamDelay(): number
	local seconds = slamDelay.pending
	slamDelay.pending = 0
	return seconds
end

-- ผลของ Status (จาก Config Skill.Status) ที่เป้า 1 ตัว · monster = nil → บอส · D = ดาเมจพื้นฐานต่อนัด (ก่อนตัวคูณธาตุ)
-- slot = เลนของผู้ใช้ (ใช้กับ MonsterFreeze) · isLast = นัดสุดท้ายของชุด (BossSlamDelay ใช้เฉพาะนัดสุดท้าย)
-- ✏️ แก้ตรงนี้ถ้าเพิ่ม Status.Kind ใหม่ (เพิ่ม elseif + ใส่ Kind ใน Config/Elements.luau)
function TurretElementService.applyStatus(
	owner: Player,
	slot: number,
	monster: any?,
	status: any?,
	D: number,
	isLast: boolean,
	now: number
): boolean
	if not status then
		return false
	end
	local kind = status.Kind
	if kind == "Burn" or kind == "Shock" or kind == "Poison" then
		TurretElementService.applyDot(owner, monster, kind, D * status.DotPerSecond, status.Seconds, now)
	elseif kind == "Knockback" then
		-- ถอย + ช้าลง (มีผลกับมอนเท่านั้น · บอสไม่ขยับ)
		if monster then
			MonsterService.knockback(monster, status.Studs or 0)
			if status.Slow and status.SlowSeconds then
				MonsterService.slow(monster, status.Slow, status.SlowSeconds)
			end
		end
	elseif kind == "ArmorBreak" then
		if monster == nil then
			TurretElementService.applyArmorBreak(owner, status.Amount, status.Seconds, status.AssistCredit or 0, now)
		end
	elseif kind == "BossSlamDelay" then
		-- นัดสุดท้าย: แช่แข็งมอนในเลนตัวเอง · โดนบอส → ขอหน่วงทุบ (คืน true = ได้ ให้ผู้เรียกวาดน้ำแข็งที่บอส)
		if isLast then
			if status.MonsterFreeze then
				for _, other in MonsterService.getAlive() do
					if other.alive and other.slot == slot then
						MonsterService.slow(other, 1, status.MonsterFreeze)
					end
				end
			end
			if monster == nil then
				return TurretElementService.requestSlamDelay(status.Seconds, status.ServerCooldown, now)
			end
		end
	end
	return false
end

-- ผลของ "การยิงปกติ" ที่โดนเป้าแล้ว (TurretService.hit เรียกตอนกระสุนถึง)
--   stats = ElementMath.stats ของผู้ยิง · monster = เป้า (nil = บอส) · point = จุดโดน
--   D = ดาเมจพื้นฐานต่อนัด (ก่อนตัวคูณธาตุ) · amount = ดาเมจที่เป้าหลักได้ (ใช้กับ Splash/Pierce)
-- ✏️ แก้ตรงนี้ถ้าเพิ่ม Shot/Passive ชนิดใหม่
function TurretElementService.applyShot(
	owner: Player,
	slot: number,
	stats: ElementMath.Stats,
	monster: any?,
	point: Vector3,
	D: number,
	amount: number,
	now: number
)
	local shot = stats.Shot
	-- Splash: มอนตัวอื่นในรัศมีรอบจุดโดน ได้ดาเมจเท่าเป้าหลัก (ระเบิดลูกไฟ)
	local splashed: { any } = {}
	if type(shot.Splash) == "number" and shot.Splash > 0 then
		splashed = TurretElementService.monstersNear(point, shot.Splash, now, nil, monster)
		for _, other in splashed do
			TurretElementService.damageMonster(other, owner, amount)
		end
	end
	-- Pierce: ทะลุไปโดนมอนในเลนตัวเองที่อยู่ถัดจากเป้า (ใกล้จุดโดนที่สุด) เพิ่ม Pierce ตัว
	if type(shot.Pierce) == "number" and shot.Pierce > 0 then
		for _, other in TurretElementService.nearestInLane(slot, point, now, shot.Pierce, monster) do
			TurretElementService.damageMonster(other, owner, amount)
		end
	end
	if monster then
		-- ช้าลง / ถอย (เฉพาะเป้าหลัก)
		if shot.MonsterSlow then
			MonsterService.slow(monster, shot.MonsterSlow.Amount, shot.MonsterSlow.Seconds)
		end
		if type(shot.Knockback) == "number" and shot.Knockback > 0 then
			MonsterService.knockback(monster, shot.Knockback)
		end
	end
	-- พิษติดเป้า (ปฐพีพิษ)
	if shot.Dot then
		TurretElementService.applyDot(owner, monster, "Poison", D * shot.Dot.DotPerSecond, shot.Dot.Seconds, now)
	end
	-- Passive ที่ติดเป้า (Passive ของป้อมเอง เช่น Regen/SlamReduce อยู่ที่ TurretService)
	local passive = stats.Passive
	if passive then
		if passive.Kind == "Burn" or passive.Kind == "Shock" then
			TurretElementService.applyDot(owner, monster, passive.Kind, D * passive.DotPerSecond, passive.Seconds, now)
			-- ระเบิดลูกไฟ: มอนที่โดน Splash ติดไฟด้วย
			for _, other in splashed do
				TurretElementService.applyDot(owner, other, passive.Kind, D * passive.DotPerSecond, passive.Seconds, now)
			end
		elseif passive.Kind == "ArmorBreak" and monster == nil then
			TurretElementService.applyArmorBreak(owner, passive.Amount, passive.Seconds, 0, now)
		end
	end
end

-- ===== อัปเดตทุกรอบ =====
-- ล้างผลที่ติดบอส (บอสจากไป)
local function clearBoss()
	armor.value = 0
	armor.untilAt = 0
	armor.creditOwner = nil
	armor.credit = 0
	slamDelay.pending = 0
	for _, perOwner in dots do
		perOwner[BOSS] = nil
	end
	-- โซนที่ปล่อยใส่บอส หายไปพร้อมบอส · โซนที่ปล่อยใส่มอนยังอยู่ต่อจนหมดเวลา
	for owner, zone in zones do
		if zone.onBoss then
			zones[owner] = nil
		end
	end
end

-- เรียกทุกรอบ tick ของ TurretService: ทำดาเมจ DoT/โซน ตามเวลาที่ผ่านไป (ต่อวินาที × วินาทีที่ผ่าน)
-- ⚠️ ระวัง: ห้ามเรียก update จากที่อื่นเพิ่ม — ดาเมจจะถูกนับซ้ำ
function TurretElementService.update(now: number)
	local from = math.max(lastUpdate or now, now - MAX_STEP)
	lastUpdate = now
	local bossActive = BossService.isActive()
	if not bossActive then
		clearBoss()
	end

	-- ส่วนที่ 1: DoT · วน 3 ชั้น: ผู้ยิง → เป้า → ชนิด (เผาไหม้/ช็อต/พิษ ซ้อนกันได้เพราะคนละชนิด)
	for owner, perOwner in dots do
		for target, perTarget in perOwner do
			local alive = if target == BOSS then bossActive else target.alive
			for kind, dot in perTarget do
				local seconds = activeSeconds(from, now, dot.startAt, dot.untilAt)
				if alive and seconds > 0 then
					if target == BOSS then
						TurretElementService.damageBoss(owner, dot.perSecond * seconds, now)
					else
						MonsterService.damage(target, owner, dot.perSecond * seconds)
					end
				end
				if not alive or now >= dot.untilAt then
					perTarget[kind] = nil -- ลบ key ระหว่างวนได้ [Verified: Luau อนุญาตตั้ง nil ให้ key ปัจจุบันขณะวน]
				end
			end
			if next(perTarget) == nil then
				perOwner[target] = nil
			end
		end
		if next(perOwner) == nil then
			dots[owner] = nil
		end
	end

	-- ส่วนที่ 2: โซน (บ่อพิษ / หลุมดำ) · ดาเมจทุกอย่างในรัศมี (วัดแนวราบ) · หลุมดำดูดมอน + หยุดเดินระหว่างอยู่ในหลุม
	local bossPosition = BossService.getTarget()
	for owner, zone in zones do
		local seconds = activeSeconds(from, now, zone.startAt, zone.untilAt)
		if seconds > 0 then
			if bossPosition and flatDistance(bossPosition, zone.position) <= zone.radius then
				TurretElementService.damageBoss(owner, zone.bossPerSecond * seconds, now)
			end
			for _, monster in MonsterService.getAlive() do
				if monster.alive then
					local distance = flatDistance(MonsterService.positionOf(monster, now), zone.position)
					if distance <= zone.radius then
						MonsterService.damage(monster, owner, zone.perSecond * seconds)
						if zone.pull > 0 and monster.alive then
							MonsterService.pullToward(monster, zone.position, zone.pull * seconds)
							MonsterService.slow(monster, 1, 0.2) -- หยุดเดินระหว่างอยู่ในหลุม (ต่ออายุทุกรอบ)
						end
					end
				end
			end
		end
		if now >= zone.untilAt then
			zones[owner] = nil
		end
	end
end

-- ผู้เล่นออกเกม → ลบ DoT/โซนของคนนั้นทิ้ง (ไม่ทำดาเมจแทนคนที่ไม่อยู่แล้ว)
function TurretElementService.Init()
	Players.PlayerRemoving:Connect(function(player)
		dots[player] = nil
		zones[player] = nil
		if armor.creditOwner == player then
			armor.creditOwner = nil
			armor.credit = 0
		end
	end)
end

return TurretElementService
