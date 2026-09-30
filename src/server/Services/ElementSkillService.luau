-- สกิลกดของธาตุป้อม 6 รูปแบบ (เจ้าของ: Gameplay_Scripter) · โมดูลช่วยของ TurretService (ไม่มี Init/Start)
-- สเปก: design/element-skills.md หัวข้อ 2.3 / 4 / 7 · ค่าทั้งหมด: Config/Elements.luau (Skill.Pattern)
-- TurretService.useSkill ตรวจด่านครบแล้ว (มีป้อม · ไม่ช็อต · คูลดาวน์หมด · มีเป้า) จึงเรียก cast ที่นี่
-- Server คำนวณทุกอย่าง: เป้า เวลา ดาเมจ ผลติดเป้า · Client ได้แค่ภาพผ่าน Remote "TurretFx"
--
-- กฎรวม (สเปกหัวข้อ 1):
--   • ดาเมจสกิล = Pattern.Damage × D × ElementMath.skillScale (อัตรายิงตามเลเวล) · D = ดาเมจต่อนัดตามเลเวล × โบนัสเพื่อน
--   • สกิลแบบ "ช่อง" (ชาร์จ, ยิงรัวหลายนัด, ลำแสง, ฟ้าผ่าซ้ำ) หยุดทันทีเมื่อป้อมช็อต/เจ้าของออก
--   • ของที่ปล่อยไปแล้ว (กระสุนที่บินอยู่ คลื่น นก โซน DoT) ทำงานต่อจนจบ
--   • ดาเมจเข้าตอน "กระสุนถึงเป้า" (task.delay ตามเวลาเดินทางที่ส่งให้ Client วาดใน TurretFx.Travel)
--
-- 6 รูปแบบ (Pattern.Kind) · ตอนนี้ธาตุพื้นฐานใช้แค่ Volley (ไฟ/ดิน/ลม) + LaneWave (น้ำ) · อีก 4 แบบเตรียมไว้ให้วิวัฒนาการ (ยังไม่ทำ)
--   ⚠️ แบบที่เตรียมไว้ยังไม่ได้ทดสอบ และยังไม่มีภาพฝั่ง Client (Fx ใหม่ต้องเพิ่ม drawer ใน TurretController ก่อนใช้):
--   Volley   = ยิงกระสุนเป็นชุด (ชาร์จก่อนได้) · Splash/Pierce/Status       → runVolley
--   LaneWave = ของวิ่งตามเลนตัวเองไปหาบอส ชนมอนทุกตัวที่ผ่าน              → runLaneWave
--   Beam     = ลำแสงทันทีต่อเนื่อง ติกๆ                                     → runBeam
--   Strikes  = ฟ้าผ่าซ้ำๆ + กระโดดต่อมอนในเลน                              → runStrikes
--   Zone     = โยนแล้วเกิดโซน (บ่อพิษ/หลุมดำ) ที่เป้า                       → runZone
--   Buff     = บัฟป้อมตัวเอง (อัตรายิง/กันช็อต)                            → runBuff
--
-- คุยกับไฟล์ไหนบ้าง: TurretService (ส่ง Caster มา) · TurretElementService (ดาเมจ + ผลติดเป้า + โซน) · BossService / MonsterService
-- ⚠️ ระวัง: ห้ามรับตัวเลขดาเมจ/เป้าจาก Client · ทุก task.spawn/task.delay ต้องเช็กเจ้าของยังอยู่ (owner.Parent) ก่อนทำดาเมจ
--
-- 📖 อ่านตามลำดับนี้
--   1) ElementSkillService.cast (ท้ายไฟล์) — เลือกฟังก์ชันตาม Pattern.Kind แล้วคืน "วินาทีที่สกิลทำงาน" (ไว้โชว์บนปุ่ม)
--   2) run* แต่ละแบบ — ใช้ตัวช่วย waitChannel (รอแบบหยุดได้เมื่อช็อต) และ aimShot (หาจุดเล็ง + เวลาเดินทาง)
--   3) ดาเมจ/ผลจริงทั้งหมดส่งต่อ TurretElementService (damageBoss / damageMonster / applyStatus / spawnZone)
--   ✏️ อยากเพิ่มรูปแบบที่ 7 → เขียน runXxx + เพิ่ม elseif ใน cast + ใส่ Pattern.Kind ใหม่ใน Config

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local BossService = require(script.Parent.BossService)
local TurretElementService = require(script.Parent.TurretElementService)

-- ===== ค่าคงที่ =====
-- ✏️ ปรับได้ปลอดภัย (ไม่มีผลกับดาเมจรวม มีผลกับ "ความง่ายในการโดน")
local WAVE_HIT_RADIUS = 8 -- คลื่น/นก: มอนที่อยู่ห่างจากตัวคลื่นไม่เกินนี้ (studs) = โดน
local WAVE_STEP = 0.1 -- วินาทีต่อรอบเช็กการชนของคลื่น/นก
local CLOUD_HEIGHT = 40 -- ความสูงเมฆเหนือเป้า (ภาพ)
local SKY_HEIGHT = 60 -- ฟ้าผ่าเริ่มจากความสูงนี้เหนือเป้า (ภาพ)
local PHOENIX_ORBIT = 12 -- รัศมีที่นกวนรอบบอส (ภาพ)
local FREEZE_RADIUS = 8 -- ขนาดก้อนน้ำแข็งครอบเท้าบอส (ภาพ)

-- ===== ชนิดข้อมูล =====
-- Target = เป้า (monster = nil เมื่อเป็นบอส) · ต้องหน้าตาเหมือน Target ใน TurretService
export type Target = { position: Vector3, monster: any?, isBoss: boolean }

-- Caster = "ข้อมูล + ปุ่มควบคุม" ของป้อมผู้ใช้สกิล ที่ TurretService สร้างส่งมา (ไฟล์นี้ไม่ require TurretService กันวนกัน)
export type Caster = {
	owner: Player,
	slot: number,
	level: number,
	D: number, -- ดาเมจต่อนัดตามเลเวล × โบนัสเพื่อน (ก่อนตัวคูณธาตุ)
	color: Color3,
	stats: ElementMath.Stats,
	foot: Vector3, -- ฐานป้อม (ระดับพื้น)
	bossGround: Vector3, -- จุดบอสบนพื้น (ปลายเลน)
	alive: () -> boolean, -- ป้อมยังเป็นของผู้เล่นคนนี้ + ยังอยู่ในเกม
	stunned: () -> boolean,
	pick: () -> Target?, -- หาเป้าใหม่ (บอส → มอนหน้าสุดในเลนตัวเอง)
	refresh: (Target) -> Target?, -- ตำแหน่งล่าสุดของเป้าเดิม (nil = เป้าหาย/ตาย)
	predict: (Target, number) -> Vector3, -- ตำแหน่งเป้าอีก n วินาที (ดักหน้ามอน)
	muzzle: (Vector3) -> Vector3,
	aim: (Vector3) -> (),
	bossId: () -> number, -- เลขรอบบอสตอนนี้
	hittable: (Target, number) -> boolean, -- เป้ายังตีได้ไหม (บอสต้องเป็นตัวเดิม)
	emit: ({ any }) -> (), -- ส่งภาพให้ Client ทุกคน (TurretFx)
	heal: (number) -> (),
	healOverTime: (number, number) -> (), -- (ต่อวินาที, นานกี่วิ)
	shield: (number, number) -> (), -- (กันกี่ครั้ง, นานกี่วิ)
	buff: (number, number, boolean) -> (), -- (ตัวคูณอัตรายิง, นานกี่วิ, กันช็อตไหม)
}

-- ===== ตัวช่วย =====
-- รอ seconds วินาทีแบบ "ช่อง": ป้อมช็อต/เจ้าของออกระหว่างรอ → คืน false (ผู้เรียกต้องหยุดสกิล)
local function waitChannel(c: Caster, seconds: number): boolean
	local untilAt = os.clock() + seconds
	while true do
		if not c.alive() or c.stunned() then
			return false
		end
		local left = untilAt - os.clock()
		if left <= 0 then
			return true
		end
		task.wait(math.min(left, 0.1))
	end
end

-- ดาเมจเป้า 1 ตัว (บอสผ่าน damageBoss ที่คูณเกราะแตก · มอนผ่าน damageMonster)
local function damageTarget(c: Caster, target: Target, amount: number, now: number)
	if target.isBoss then
		TurretElementService.damageBoss(c.owner, amount, now)
	elseif target.monster then
		TurretElementService.damageMonster(target.monster, c.owner, amount)
	end
end

-- จุดเล็ง + ปากกระบอก + เวลาเดินทางของกระสุนสกิล (ดักหน้ามอนตามเวลาเดินทาง)
local function aimShot(c: Caster, pattern: any, target: Target): (Vector3, Vector3, number)
	local point = target.position
	local muzzle = c.muzzle(point)
	local travel = ElementMath.skillTravel(pattern, (point - muzzle).Magnitude)
	if target.monster then
		point = c.predict(target, travel)
		muzzle = c.muzzle(point)
		travel = ElementMath.skillTravel(pattern, (point - muzzle).Magnitude)
	end
	c.aim(point)
	return point, muzzle, travel
end

-- วาดน้ำแข็งครอบเท้าบอส (หน่วงทุบสำเร็จ)
local function emitFreeze(c: Caster, seconds: number)
	local position = BossService.getTarget()
	if not position then
		return
	end
	local feet = Vector3.new(position.X, c.bossGround.Y, position.Z)
	c.emit({
		{ Kind = "Freeze", From = feet, To = feet, Color = Color3.fromRGB(190, 235, 255), Radius = FREEZE_RADIUS, Duration = seconds },
	})
end

-- ===== 1) Volley: ยิงกระสุนเป็นชุด =====
-- ตัวอย่าง (ลูกไฟพัด Lv.1 D 10): 5 ลูก × 2.0 × 10 = 20 ต่อลูก + ระเบิด 20 ใส่มอนรอบๆ + เผาไหม้ 3/วิ 4 วิ
local function runVolley(c: Caster, skill: any, pattern: any, first: Target): number
	local scale = ElementMath.skillScale(skill, c.level)
	local mainAmount = pattern.Damage * c.D * scale
	local splashAmount = (pattern.SplashDamage or pattern.Damage) * c.D * scale
	local count = math.max(1, pattern.Count or 1)
	local interval = pattern.Interval or 0.1
	local charge = pattern.Charge or 0

	-- ยิง 1 นัด (index = นัดที่เท่าไร) · ภาพส่งทันที · ดาเมจเข้าตอนถึง
	local function fireOne(target: Target, index: number)
		local point, muzzle, travel = aimShot(c, pattern, target)
		-- Spread = มุมพัดของภาพ (องศา) · นัดแรกซ้ายสุด → นัดสุดท้ายขวาสุด · Client ใช้ทำโค้งเข้าหาเป้า
		local spread = 0
		if (pattern.Spread or 0) > 0 and count > 1 then
			spread = -pattern.Spread / 2 + (index - 1) * pattern.Spread / (count - 1)
		end
		c.emit({
			{
				Kind = skill.Fx,
				From = muzzle,
				To = point,
				Color = c.color,
				Travel = travel,
				Radius = pattern.Splash,
				Spread = spread,
				Arc = pattern.Arc,
			},
		})
		local bossId = c.bossId()
		local isLast = index == count
		task.delay(travel, function()
			if not c.owner.Parent then
				return
			end
			if target.isBoss and not c.hittable(target, bossId) then
				return -- บอสไปแล้วระหว่างกระสุนบิน
			end
			local now = os.clock()
			-- เป้าหลัก (ยังอยู่) → ดาเมจ + Status (BossSlamDelay ใช้เฉพาะนัดสุดท้าย)
			if c.hittable(target, bossId) then
				damageTarget(c, target, mainAmount, now)
				local frozen = TurretElementService.applyStatus(c.owner, c.slot, target.monster, skill.Status, c.D, isLast, now)
				if frozen then
					emitFreeze(c, skill.Status.Seconds)
				end
			elseif isLast and skill.Status and skill.Status.Kind == "BossSlamDelay" then
				-- เป้าหลักตายก่อนถึง: ยังแช่แข็งมอนในเลนตามสเปก (ไม่หน่วงทุบ เพราะไม่ได้โดนบอส)
				TurretElementService.applyStatus(c.owner, c.slot, {}, skill.Status, c.D, true, now)
			end
			-- ระเบิดรอบจุดตก (มอนตัวอื่น) + Status เดียวกัน (ไม่นับเป็นนัดสุดท้าย)
			if (pattern.Splash or 0) > 0 then
				for _, other in TurretElementService.monstersNear(point, pattern.Splash, now, nil, target.monster) do
					TurretElementService.damageMonster(other, c.owner, splashAmount)
					TurretElementService.applyStatus(c.owner, c.slot, other, skill.Status, c.D, false, now)
				end
			end
			-- ทะลุ: มอนในเลนตัวเองใกล้จุดโดนที่สุด Pierce ตัว (99 = ทุกตัวในเลน)
			if (pattern.Pierce or 0) > 0 then
				for _, other in TurretElementService.nearestInLane(c.slot, point, now, pattern.Pierce, target.monster) do
					TurretElementService.damageMonster(other, c.owner, mainAmount)
					TurretElementService.applyStatus(c.owner, c.slot, other, skill.Status, c.D, false, now)
				end
			end
		end)
	end

	-- เกราะหิน (ดิน) · ฟื้นเลือด (ถ้ามี) เกิดทันทีตอนกด
	if skill.SelfShield then
		c.shield(skill.SelfShield.Blocks, skill.SelfShield.Seconds)
	end
	if skill.SelfHeal then
		c.heal(skill.SelfHeal)
	end

	task.spawn(function()
		local target: Target? = first
		-- ชาร์จก่อนยิง: ภาพชาร์จที่ปากกระบอก · ช็อตระหว่างชาร์จ = ยกเลิก (คูลดาวน์เสียไปแล้ว)
		if charge > 0 then
			local point = first.position
			c.aim(point)
			-- From = ปากกระบอก · To = เป้า (Client ใช้แค่ "ทิศ" วาดวงแหวนรอบลำกล้อง)
			c.emit({
				{ Kind = skill.ChargeFx or "WindCharge", From = c.muzzle(point), To = point, Color = c.color, Duration = charge },
			})
			if not waitChannel(c, charge) then
				return
			end
		end
		for index = 1, count do
			if not c.alive() or c.stunned() then
				return -- ช็อตกลางชุด = หยุดยิงนัดที่เหลือ
			end
			-- เป้าเดิมยังอยู่ → ยิงต่อ · หาย → หาเป้าใหม่ · ไม่มีเลย → หยุด
			local current = if target then c.refresh(target) else nil
			if not current then
				current = c.pick()
			end
			if not current then
				return
			end
			target = current
			fireOne(current, index)
			if index < count and not waitChannel(c, interval) then
				return
			end
		end
	end)
	return charge + (count - 1) * interval
end

-- ===== 2) LaneWave: วิ่งตามเลนตัวเองไปหาบอส =====
-- คลื่นยักษ์: ชนมอน 3D ทุกตัวที่ผ่าน + ถอย 12 · ถึงปลายเลน = ซัดบอส 9D
-- (แผนวิวัฒนาการ) นกเพลิง: ชนมอน 5D · ถึงบอส = วน 12 ติก × 1.33D (4 ติก/วิ) · ป้อมฟื้นเลือดระหว่างบิน
local function runLaneWave(c: Caster, skill: any, pattern: any, _first: Target): number
	local scale = ElementMath.skillScale(skill, c.level)
	local monsterAmount = pattern.Damage * c.D * scale
	local endAmount = (pattern.EndDamage or 0) * c.D * scale
	-- เส้นทาง: จากหน้าป้อม (ระดับพื้น +2) → จุดบอสบนพื้น (+2)
	local lift = Vector3.new(0, 2, 0)
	local start = c.foot + lift
	local finish = c.bossGround + lift
	local distance = (finish - start).Magnitude
	local speed = math.max(pattern.Speed or 40, 1)
	local duration = math.max(distance / speed, 0.1)
	local endTicks = pattern.EndTicks or 1
	local endRate = pattern.EndTickRate or 1
	local endDuration = if pattern.EndTicks then endTicks / endRate else 0

	if skill.SelfHeal then
		c.heal(skill.SelfHeal)
	end
	if skill.SelfHealPerSecond then
		c.healOverTime(skill.SelfHealPerSecond, duration + endDuration)
	end
	c.emit({
		{
			Kind = skill.Fx,
			From = start,
			To = finish,
			Color = c.color,
			Travel = duration,
			Duration = if endDuration > 0 then endDuration else nil,
			Radius = PHOENIX_ORBIT,
		},
	})

	local bossId = c.bossId()
	local bossTarget: Target = { position = finish, monster = nil, isBoss = true }
	task.spawn(function()
		local hit: { [any]: boolean } = {} -- มอนที่โดนไปแล้ว (โดนได้ตัวละครั้งเดียว)
		local began = os.clock()
		while true do
			if not c.owner.Parent then
				return
			end
			local now = os.clock()
			local progress = math.min((now - began) / duration, 1)
			local position = start:Lerp(finish, progress)
			for _, monster in TurretElementService.monstersNear(position, WAVE_HIT_RADIUS, now, c.slot) do
				if not hit[monster] then
					hit[monster] = true
					TurretElementService.damageMonster(monster, c.owner, monsterAmount)
					TurretElementService.applyStatus(c.owner, c.slot, monster, skill.Status, c.D, false, now)
				end
			end
			if progress >= 1 then
				break
			end
			task.wait(WAVE_STEP)
		end
		-- ถึงปลายเลน: บอสต้องยังอยู่และเป็นตัวเดิม → ซัดบอส (EndTicks ครั้ง)
		for tick = 1, endTicks do
			if not c.owner.Parent or not c.hittable(bossTarget, bossId) or endAmount <= 0 then
				return
			end
			local now = os.clock()
			TurretElementService.damageBoss(c.owner, endAmount, now)
			if tick == 1 then
				TurretElementService.applyStatus(c.owner, c.slot, nil, skill.Status, c.D, true, now)
			end
			if tick < endTicks then
				task.wait(1 / endRate)
			end
		end
	end)
	return duration + endDuration
end

-- ===== 3) Beam: ลำแสงทันทีต่อเนื่อง =====
-- (แผนวิวัฒนาการ · ยังไม่ใช้) ลำแสงรุ้ง: 25 ติก × 0.7D ใน 2.5 วิ · ล็อกเป้าเดิม (ตาย → ย้ายเป้า) · ช็อต = หยุด
local function runBeam(c: Caster, skill: any, pattern: any, first: Target): number
	local scale = ElementMath.skillScale(skill, c.level)
	local amount = pattern.Damage * c.D * scale
	local rate = math.max(pattern.TickRate or 10, 1)
	local interval = 1 / rate
	local ticks = math.max(1, math.floor((pattern.Duration or 1) * rate + 0.5))
	task.spawn(function()
		local target: Target = first
		for tick = 1, ticks do
			if not c.alive() or c.stunned() then
				return
			end
			local current = c.refresh(target) or c.pick()
			if not current then
				return
			end
			target = current
			c.aim(current.position)
			damageTarget(c, current, amount, os.clock())
			-- ภาพ: ส่งทุก 2 ติก (ลดข้อมูลเครือข่าย) แต่ละชิ้นอยู่ 2 ติก
			if (tick - 1) % 2 == 0 then
				c.emit({
					{
						Kind = skill.Fx,
						From = c.muzzle(current.position),
						To = current.position,
						Color = c.color,
						Duration = interval * 2 + 0.03,
					},
				})
			end
			task.wait(interval)
		end
	end)
	return ticks * interval
end

-- ===== 4) Strikes: ฟ้าผ่าซ้ำๆ =====
-- (แผนวิวัฒนาการ · ยังไม่ใช้) พายุฟ้าคำราม: 6 ครั้ง × 2.5D ห่าง 0.5 วิ · ทุกครั้งกระโดดต่อมอนในเลน 2 ตัว (2D) · ติดช็อต (Passive) ทุกครั้ง
local function runStrikes(c: Caster, skill: any, pattern: any, first: Target): number
	local scale = ElementMath.skillScale(skill, c.level)
	local amount = pattern.Damage * c.D * scale
	local chainAmount = (pattern.ChainDamage or 0) * c.D * scale
	local count = math.max(1, pattern.Count or 1)
	local interval = pattern.Interval or 0.5
	local passive = c.stats.Passive -- ช็อต (Shock) ของพายุสายฟ้า
	local shock = if passive and (passive.Kind == "Shock" or passive.Kind == "Burn") then passive else nil
	if skill.CloudFx then
		local at = first.position
		c.emit({
			{
				Kind = skill.CloudFx,
				From = at + Vector3.new(0, CLOUD_HEIGHT, 0),
				To = at,
				Color = Color3.fromRGB(90, 95, 110),
				Duration = count * interval,
				Radius = 10,
			},
		})
	end
	task.spawn(function()
		local target: Target = first
		for index = 1, count do
			if not c.alive() or c.stunned() then
				return
			end
			local current = c.refresh(target) or c.pick()
			if not current then
				return
			end
			target = current
			local now = os.clock()
			local point = current.position
			c.aim(point)
			local list: { any } = {
				{ Kind = skill.Fx, From = point + Vector3.new(0, SKY_HEIGHT, 0), To = point, Color = c.color },
			}
			damageTarget(c, current, amount, now)
			TurretElementService.applyStatus(c.owner, c.slot, current.monster, shock, c.D, false, now)
			-- กระโดดต่อ: มอนในเลนตัวเองที่ใกล้จุดผ่าที่สุด Chain ตัว
			if (pattern.Chain or 0) > 0 then
				for _, monster in TurretElementService.nearestInLane(c.slot, point, now, pattern.Chain, current.monster) do
					TurretElementService.damageMonster(monster, c.owner, chainAmount)
					TurretElementService.applyStatus(c.owner, c.slot, monster, shock, c.D, false, now)
					local monsterPoint = monster.part and monster.part.Position or point
					table.insert(list, { Kind = skill.ChainFx or "Lightning", From = point, To = monsterPoint, Color = c.color })
				end
			end
			c.emit(list)
			if index < count and not waitChannel(c, interval) then
				return
			end
		end
	end)
	return count * interval
end

-- ===== 5) Zone: โยนแล้วเกิดโซนที่เป้า =====
-- (แผนวิวัฒนาการ · ยังไม่ใช้) บ่อพิษ: กระแทก 3D + 0.5D/วิ รัศมี 12 นาน 8 วิ · บอสเกราะแตก +20%
-- (แผนวิวัฒนาการ · ยังไม่ใช้) หลุมดำ: กระแทก 3D + 0.8D × 4 ติก/วิ รัศมี 16 นาน 4 วิ · ดูดมอน 3 studs/ติก
local function runZone(c: Caster, skill: any, pattern: any, first: Target): number
	local scale = ElementMath.skillScale(skill, c.level)
	local impact = (pattern.ImpactDamage or 0) * c.D * scale
	local rate = pattern.TickRate or 1
	local perSecond = (pattern.Damage or 0) * rate * c.D * scale
	local pull = (pattern.Pull or 0) * rate
	local duration = pattern.Duration or 4
	local radius = pattern.Radius or 10

	local point, muzzle, travel = aimShot(c, pattern, first)
	c.emit({
		{ Kind = skill.ProjectileFx or c.stats.Fx, From = muzzle, To = point, Color = c.color, Travel = travel, Arc = 8 },
	})
	local bossId = c.bossId()
	task.delay(travel, function()
		if not c.owner.Parent then
			return
		end
		if first.isBoss and not c.hittable(first, bossId) then
			return
		end
		local now = os.clock()
		if c.hittable(first, bossId) then
			damageTarget(c, first, impact, now)
		end
		-- โซนวางบนพื้น: บอส → ใช้ความสูงพื้นจุดบอส (ตัวบอสสูง จุดเล็งลอยกลางอากาศ)
		local center = if first.isBoss then Vector3.new(point.X, c.bossGround.Y, point.Z) else point
		TurretElementService.spawnZone(c.owner, {
			position = center,
			radius = radius,
			perSecond = perSecond,
			bossPerSecond = perSecond,
			pull = pull,
			startAt = now,
			untilAt = now + duration,
			onBoss = first.isBoss,
		})
		c.emit({
			{ Kind = skill.Fx, From = center, To = center, Color = c.color, Radius = radius, Duration = duration },
		})
		-- Status (เกราะแตก): บอสเป็นเป้า หรืออยู่ในรัศมีโซน
		if skill.Status then
			local bossPosition = BossService.getTarget()
			local flat = if bossPosition
				then Vector3.new(bossPosition.X - center.X, 0, bossPosition.Z - center.Z).Magnitude
				else math.huge
			if first.isBoss or flat <= radius then
				TurretElementService.applyStatus(c.owner, c.slot, nil, skill.Status, c.D, true, now)
			end
		end
	end)
	return travel + duration
end

-- ===== 6) Buff: บัฟป้อมตัวเอง =====
-- (แผนวิวัฒนาการ · ยังไม่ใช้) พายุกระสุน: อัตรายิง ×3 นาน 5 วิ · ระหว่างนั้นไม่ช็อต (TurretService จัดการ)
local function runBuff(c: Caster, skill: any, pattern: any, first: Target): number
	local duration = pattern.Duration or 5
	c.buff(pattern.FireRate or 1, duration, pattern.StunImmune == true)
	local muzzle = c.muzzle(first.position)
	c.emit({
		{ Kind = skill.Fx, From = c.foot, To = muzzle, Color = c.color, Duration = duration, Radius = 5 },
	})
	return duration
end

-- ===== API =====
local ElementSkillService = {}

-- ใช้สกิล skill (ตาราง Skill จาก Config) ใส่เป้าแรก first · คืนวินาทีที่สกิลทำงาน (โชว์บนปุ่ม) · Kind ไม่รู้จัก = nil
-- ✏️ แก้ตรงนี้ถ้าเพิ่ม Pattern.Kind ใหม่
function ElementSkillService.cast(c: Caster, skill: any, first: Target): number?
	local pattern = skill.Pattern
	if type(pattern) ~= "table" then
		return nil
	end
	local kind = pattern.Kind
	if kind == "Volley" then
		return runVolley(c, skill, pattern, first)
	elseif kind == "LaneWave" then
		return runLaneWave(c, skill, pattern, first)
	elseif kind == "Beam" then
		return runBeam(c, skill, pattern, first)
	elseif kind == "Strikes" then
		return runStrikes(c, skill, pattern, first)
	elseif kind == "Zone" then
		return runZone(c, skill, pattern, first)
	elseif kind == "Buff" then
		return runBuff(c, skill, pattern, first)
	end
	warn(`[ElementSkillService] ไม่รู้จัก Pattern.Kind "{tostring(kind)}"`)
	return nil
end

return ElementSkillService
