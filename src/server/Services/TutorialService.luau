-- ระบบฝึกสอนตอนเข้าเกม 5 ขั้นแบบลงมือทำ (เจ้าของ: Gameplay_Scripter) · สเปก: design/tutorial.md · ค่า: Config/Tutorial.luau
-- Server เป็นคนเลื่อนขั้นคนเดียว (Client ไม่มี Remote "จบขั้น" ยกเว้นขั้น 5 กด "เข้าใจแล้ว!" = Remote TutorialAck ผ่าน Guard)
-- ขั้นที่ทำอยู่บันทึกใน PlayerData (TutorialStep / TutorialDone) → ออกกลางคัน = เข้าใหม่ทำต่อจากขั้นเดิม
-- Client เห็นผ่าน Player Attribute "TutorialStep" (1..5 · 6 = จบ) / "TutorialDone" (StatsService ส่งให้)
--
-- ขั้นตอน (ลำดับ/Id ใน Config/Tutorial.Steps · ห้ามเปลี่ยน Id):
--   1 ChooseElement — จบเมื่อมีธาตุ (TurretElementService.choose เรียก notify · ผู้เล่นเก่าที่มีธาตุแล้ว = ผ่านเองทันที)
--   2 WatchTurret   — ปล่อยมอนฝึก WatchMonsters ตัวในเลนตัวเอง → ตาย/ถึงปลายเลนครบ หรือครบ WatchTimeout วิ = จบ
--   3 UseSkill      — รีเซ็ตคูลดาวน์สกิล (TurretService ฟัง StepChanged) + มอนฝึก SkillMonsters ตัว (หมดแล้วปล่อยชุดใหม่)
--                     → TurretService.useSkill สำเร็จ = จบ
--   4 Upgrade       — เงินไม่พอค่าอัป 1 ครั้ง → เติมให้พอดีค่าอัป (ไม่เกิน MaxCoins) → TurretService.upgrade สำเร็จ = จบ
--   5 MeetBoss      — ครบ ReadSeconds วิ หรือกด "เข้าใจแล้ว!" (TutorialAck · ต้องผ่านไป ≥ MinReadSeconds วิ) = จบ
--   จบ → TutorialDone = true · โบนัส RewardCoins ผ่าน Wallet.earn (เพดาน/โบนัสเพื่อนชุดเดียวกับเงินอื่น)
--
-- บอสกับการฝึก (design/tutorial.md หัวข้อ "บอสมาระหว่างฝึก"):
--   • มีคนอยู่ขั้น 2–3 → holdBoss() คืน true → BossService เลื่อนบอสทีละ 1 วิ รวมไม่เกิน MaxBossHold วิ ต่อการเกิด 1 ครั้ง
--   • บอสอยู่แล้วตอนเข้าขั้น 2 → ขั้น 2 ผ่านเองทันที (ป้อมยิงบอสให้ดูอยู่แล้ว · มอนเกิดไม่ได้ตอนบอสอยู่)
--   • ขั้น 3 ระหว่างบอส → รอ: กดสกิลใส่บอสได้ถ้าบอสอยู่ในระยะ (ดาเมจไม่นับ) · ไม่งั้นบอสจบ → มอนฝึกเกิด → กดได้
--
-- สิทธิ์ระหว่างฝึก (ตรวจในไฟล์ที่ทำงานจริง · ไฟล์นี้แค่ตอบว่า "ได้ไหม"):
--   isDone = false → TurretElementService.damageBoss ไม่นับดาเมจ · เปลี่ยนธาตุ (หลังเลือกแล้ว) ไม่ได้ · GearService ทุกคำสั่งไม่ได้
--   allows(player, "Upgrade") = ขั้น 4 เท่านั้น · allows(player, "UseSkill") = ขั้น 3 เท่านั้น (TurretService)
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ข้อความ / จำนวนมอนฝึก / เลือดมอนฝึก / เวลา / โบนัสจบ / ปิดระบบฝึก → src/shared/Config/Tutorial.luau
--   • เพิ่ม/ลบ/สลับขั้น → ต้องแก้ทั้ง Config และไฟล์นี้ (โค้ดผูกกับ Id ของขั้น)
--
-- คุยกับไฟล์ไหนบ้าง:
--   • PlayerData — เก็บขั้น · MonsterService — มอนฝึก (spawnTraining / trainingLeft / cancelTraining)
--   • BaseService — เลนของผู้เล่น · BossService — มีบอสไหม · Wallet — โบนัสจบ
--   • ไฟล์ที่ถามสิทธิ์/แจ้งผล: TurretService (upgrade/useSkill/รีเซ็ตคูลดาวน์) · TurretElementService (เลือกธาตุ/ดาเมจบอส)
--     · GearService (lazy require) · BossService (holdBoss · lazy require) · Network/TutorialHandler (ack)
--   ⚠️ ไฟล์นี้ห้าม require TurretService / TurretElementService / GearService (พวกนั้น require ไฟล์นี้ → วนกัน = require พัง)
--
-- 📖 อ่านตามลำดับนี้
--   1) Init — ฟัง PlayerData.Changed: ข้อมูลโหลดเสร็จ → openSession (สร้างสถานะ + enterStep ขั้นที่ค้างไว้)
--   2) enterStep — เตรียมของของขั้นนั้น (มอนฝึก / เติมเงิน) + ยิง StepChanged
--   3) Start — ลูปทุก POLL วิ: เช็กขั้นที่จบเองได้ (ธาตุ / มอนฝึกหมด / หมดเวลา / ครบเวลาอ่าน) + ปล่อยมอนฝึกขั้น 3 ซ้ำ
--   4) notify / ack — ระบบอื่นแจ้ง "ทำสำเร็จ" → advance (เลื่อนขั้นใน PlayerData.update · ตรวจขั้นซ้ำข้างในเสมอ)
--   5) finish — ขั้นสุดท้ายจบ → TutorialDone + โบนัส + ยิง Finished

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BaseService = require(script.Parent.BaseService)
local BossService = require(script.Parent.BossService)
local MonsterService = require(script.Parent.MonsterService)
local Wallet = require(script.Parent.Wallet)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== ค่าคงที่ =====
-- POLL (ปรับได้): ทุกกี่วินาทีเช็กขั้นที่จบเองได้ · SKILL_RESPAWN_DELAY (ปรับได้): มอนฝึกขั้น 3 หมดแล้วรอกี่วิก่อนปล่อยชุดใหม่
local POLL = 0.25
local SKILL_RESPAWN_DELAY = 2
-- FINISHED = "ขั้น" ที่แปลว่าจบแล้ว (ถัดจากขั้นสุดท้าย · ตอนนี้ = 6)
local FINISHED = #Tutorial.Steps + 1

-- เลขขั้นจาก Id ใน Config (ห้ามแก้ · Config สลับลำดับได้ แต่ Id ต้องมีครบ)
local function indexOf(id: string): number
	for index, step in Tutorial.Steps do
		if step.Id == id then
			return index
		end
	end
	error(`[TutorialService] Config/Tutorial.Steps ไม่มีขั้น Id "{id}"`)
end
local STEP = table.freeze({
	ChooseElement = indexOf("ChooseElement"),
	WatchTurret = indexOf("WatchTurret"),
	UseSkill = indexOf("UseSkill"),
	Upgrade = indexOf("Upgrade"),
	MeetBoss = indexOf("MeetBoss"),
})

-- ===== สถานะ (หน่วยความจำเท่านั้น · ความจริงของขั้นอยู่ใน PlayerData) =====
-- Session = ผู้เล่น 1 คนที่ยังฝึกไม่จบ · step 0 = เพิ่งโหลด ยังไม่ได้ enterStep
type Session = {
	step: number,
	enteredAt: number, -- os.clock() ตอนเข้าขั้นนี้ (ใช้นับ WatchTimeout / ReadSeconds / MinReadSeconds)
	batch: MonsterService.TrainingBatch?, -- มอนฝึกชุดปัจจุบัน
	respawnAt: number, -- ขั้น 3: ปล่อยมอนฝึกชุดใหม่ได้เมื่อไร (os.clock)
}
local sessions: { [Player]: Session } = {}
-- เวลาที่เริ่มเลื่อนบอส (os.clock) ของการเกิดบอสครั้งที่รออยู่ · nil = ไม่ได้เลื่อน
local holdStartedAt: number? = nil
local stepEvent = Instance.new("BindableEvent")
local finishedEvent = Instance.new("BindableEvent")

-- ===== ตัวช่วย =====
-- ขั้นปัจจุบันจากข้อมูล: จบแล้ว/ปิดระบบ = FINISHED · ข้อมูลเสีย (ไม่ใช่เลขเต็ม 1..5) = 1
local function stepOf(data: any): number
	if not Tutorial.Enabled or data.TutorialDone == true then
		return FINISHED
	end
	local step = data.TutorialStep
	if type(step) ~= "number" or step ~= step or step % 1 ~= 0 or step < 1 or step > #Tutorial.Steps then
		return 1
	end
	return step
end

-- เลนของผู้เล่น (nil = ยังไม่มีบ้าน/บ้านเต็ม)
local function slotOf(player: Player): number?
	return BaseService.slotOf(player)
end

-- ปล่อยมอนฝึก count ตัวในเลนของผู้เล่น · ไม่มีเลน = ไม่ปล่อย
-- hp: เลือดมอนฝึก (ขั้น 3 ใช้ SkillMonsterHp ที่หนากว่า ให้ผู้เล่นมีเวลากด Q ก่อนป้อมยิงตาย)
local function spawnBatch(player: Player, session: Session, count: number, hp: number?)
	local slot = slotOf(player)
	if not slot then
		return
	end
	session.batch = MonsterService.spawnTraining(slot, count, hp or Tutorial.TrainingMonsterHp, Tutorial.TrainingSpawnGap)
end

-- ขั้น 4: เงินไม่พอค่าอัป 1 ครั้ง → เติมให้ "พอดี" ค่าอัป (ไม่เกิน MaxCoins) · คืน false ถ้าเลเวลเต็มแล้ว (อัปไม่ได้)
-- ⚠️ แตะเงินจริง: เติมได้เฉพาะตอนเข้าขั้น 4 (ผ่าน PlayerData.update) · ระหว่างฝึกใช้เงินอื่นไม่ได้ (Gear/เปลี่ยนธาตุถูกล็อก)
-- ตัวอย่าง: Lv.1 ค่าอัป 25 · มี 10 → เป็น 25 · มี 40 → ไม่เติม
local function topUpForUpgrade(player: Player): boolean
	local canUpgrade = true
	PlayerData.update(player, function(data)
		local level = TurretMath.clampLevel(data.TurretLevel)
		if level >= Combat.Turret.MaxLevel then
			canUpgrade = false
			return
		end
		local cost = TurretMath.upgradeCost(level)
		local coins = if type(data.Coins) == "number" and data.Coins == data.Coins then data.Coins else 0
		if coins < cost then
			data.Coins = math.min(cost, Economy.MaxCoins)
		end
	end)
	return canUpgrade
end

-- ===== เลื่อนขั้น =====
local advance: (Player, number) -> ()

-- เข้าขั้น step: เตรียมของของขั้นนั้น · ยิง StepChanged(player, step)
local function enterStep(player: Player, step: number)
	local session = sessions[player]
	if not session or not player.Parent then
		return
	end
	if session.batch then
		MonsterService.cancelTraining(session.batch) -- ขั้นก่อนจบแล้ว → หยุดปล่อยมอนฝึกที่เหลือ
	end
	session.step = step
	session.enteredAt = os.clock()
	session.batch = nil
	session.respawnAt = 0
	stepEvent:Fire(player, step)

	if step == STEP.WatchTurret then
		-- ไม่มีเลน หรือบอสอยู่ (มอนเกิดไม่ได้) → ผ่านเอง (เลือกทางง่าย/ไม่ค้าง · design/tutorial.md)
		if not slotOf(player) or BossService.isActive() then
			task.defer(advance, player, step)
			return
		end
		spawnBatch(player, session, Tutorial.WatchMonsters)
	elseif step == STEP.UseSkill then
		-- ไม่มีเลน = ไม่มีป้อม → กดสกิลไม่ได้แน่ → ผ่านเอง · มอนฝึกปล่อยในลูป Start (รอบอสจบได้)
		if not slotOf(player) then
			task.defer(advance, player, step)
		end
	elseif step == STEP.Upgrade then
		if not topUpForUpgrade(player) then
			task.defer(advance, player, step) -- เลเวลเต็มแล้ว อัปไม่ได้ → ผ่านเอง
		end
	end
end

-- ฝึกจบ: เก็บ session · โบนัสเหรียญ · ยิง StepChanged(FINISHED) + Finished
local function finish(player: Player)
	local session = sessions[player]
	if session and session.batch then
		MonsterService.cancelTraining(session.batch)
	end
	sessions[player] = nil
	Wallet.earn(player, Tutorial.RewardCoins)
	stepEvent:Fire(player, FINISHED)
	finishedEvent:Fire(player)
end

-- เลื่อนจากขั้น from → from + 1 · ตรวจ "ยังอยู่ขั้น from จริง" ข้างใน update เสมอ (เรียกซ้ำ/ช้า = ไม่มีผล ไม่ข้ามขั้น)
advance = function(player: Player, from: number)
	local moved = false
	PlayerData.update(player, function(data)
		if stepOf(data) ~= from then
			return
		end
		data.TutorialStep = from + 1
		if from + 1 >= FINISHED then
			data.TutorialDone = true
		end
		moved = true
	end)
	if not moved then
		return
	end
	if from + 1 >= FINISHED then
		finish(player)
	else
		enterStep(player, from + 1)
	end
end

-- ข้อมูลโหลดเสร็จ (หรือเปลี่ยน) → ยังไม่มี session และยังไม่จบ → สร้าง แล้วเข้าขั้นที่ค้างไว้ (ขั้น 2–3 = ปล่อยมอนฝึกใหม่)
local function openSession(player: Player, data: any)
	if sessions[player] or not player.Parent then
		return
	end
	local step = stepOf(data)
	if step >= FINISHED then
		return
	end
	sessions[player] = { step = 0, enteredAt = os.clock(), batch = nil, respawnAt = 0 }
	-- defer: ห้ามแก้ PlayerData ซ้อนอยู่ใน PlayerData.Changed (ขั้น 4 เติมเงิน)
	task.defer(enterStep, player, step)
end

-- ===== API ให้ไฟล์อื่นเรียก =====
local TutorialService = {}

-- ยิงทุกครั้งที่เข้าขั้นใหม่ (รวมตอนเข้าเกมแล้วทำต่อ): (player, step) · step = FINISHED (6) เมื่อจบ
-- TurretService ใช้รีเซ็ตคูลดาวน์สกิลตอนเข้าขั้น UseSkill
TutorialService.StepChanged = stepEvent.Event
-- ยิงครั้งเดียวตอนฝึกจบ: (player)
TutorialService.Finished = finishedEvent.Event
-- เลขขั้นตาม Id (อ่านอย่างเดียว) เช่น TutorialService.STEP.UseSkill = 3
TutorialService.STEP = STEP
TutorialService.FINISHED = FINISHED

-- ฝึกจบแล้วหรือยัง · ปิดระบบฝึก = true เสมอ · ข้อมูลยังไม่โหลด = false (ปลอดภัยไว้ก่อน: ยังทำอะไรไม่ได้อยู่ดี)
function TutorialService.isDone(player: Player): boolean
	if not Tutorial.Enabled then
		return true
	end
	local data = PlayerData.get(player)
	return data ~= nil and data.TutorialDone == true
end

-- ขั้นปัจจุบัน 1..5 · FINISHED (6) = จบ/ปิดระบบ · 0 = ข้อมูลยังไม่โหลด
function TutorialService.step(player: Player): number
	if not Tutorial.Enabled then
		return FINISHED
	end
	local data = PlayerData.get(player)
	return if data then stepOf(data) else 0
end

-- ทำ "การกระทำของขั้น id" ได้ไหม (เช่น "Upgrade" / "UseSkill"): จบแล้ว = ได้ทุกอย่าง · ยังฝึก = ได้เฉพาะตอนอยู่ขั้นนั้น
function TutorialService.allows(player: Player, id: string): boolean
	if TutorialService.isDone(player) then
		return true
	end
	local index = STEP[id]
	return index ~= nil and TutorialService.step(player) == index
end

-- ระบบอื่นแจ้งว่า "ทำการกระทำของขั้น id สำเร็จแล้ว" → อยู่ขั้นนั้นพอดี = เลื่อนขั้น · ไม่ใช่ = ไม่มีผล
-- เรียกจาก: TurretElementService.choose ("ChooseElement") · TurretService.useSkill ("UseSkill") · TurretService.upgrade ("Upgrade")
function TutorialService.notify(player: Player, id: string)
	local index = STEP[id]
	if index and sessions[player] and TutorialService.step(player) == index then
		advance(player, index)
	end
end

-- Remote TutorialAck (Network/TutorialHandler ผ่าน Guard แล้ว): กด "เข้าใจแล้ว!" ขั้น 5
-- รับเฉพาะตอนอยู่ขั้น MeetBoss และอยู่มาแล้ว ≥ MinReadSeconds วิ · ไม่ผ่าน = เงียบ
function TutorialService.ack(player: Player)
	local session = sessions[player]
	if session and session.step == STEP.MeetBoss and os.clock() - session.enteredAt >= Tutorial.MinReadSeconds then
		advance(player, STEP.MeetBoss)
	end
end

-- BossService ถามก่อนเกิดบอส: true = "เลื่อนไปก่อน" (มีคนอยู่ขั้นมอนฝึก 2–3)
-- เลื่อนรวมไม่เกิน MaxBossHold วิ ต่อการเกิด 1 ครั้ง (กันบอสไม่มาเลย) · ครบแล้ว/ไม่มีคนฝึก = false แล้วเริ่มนับใหม่รอบหน้า
function TutorialService.holdBoss(): boolean
	local training = false
	for player, session in sessions do
		if player.Parent and (session.step == STEP.WatchTurret or session.step == STEP.UseSkill) then
			training = true
			break
		end
	end
	local now = os.clock()
	if not training then
		holdStartedAt = nil
		return false
	end
	local startedAt = holdStartedAt or now
	holdStartedAt = startedAt
	if now - startedAt >= Tutorial.MaxBossHold then
		holdStartedAt = nil
		return false
	end
	return true
end

-- ===== เริ่มระบบ =====
-- ฟังข้อมูลโหลดเสร็จ · ผู้เล่นออก = เก็บ session (ขั้นอยู่ในเซฟแล้ว เข้าใหม่ทำต่อ)
function TutorialService.Init()
	if not Tutorial.Enabled then
		return -- ปิดระบบฝึก: ทุกคนถือว่าจบ (isDone = true) ไม่มี session ไม่เขียนข้อมูล
	end
	PlayerData.Changed:Connect(openSession)
	for _, player in Players:GetPlayers() do
		local data = PlayerData.get(player)
		if data then
			openSession(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session and session.batch then
			MonsterService.cancelTraining(session.batch)
		end
		sessions[player] = nil
	end)
end

-- ลูปทุก POLL วิ: ขั้นที่จบเองได้ + ปล่อยมอนฝึกขั้น 3 ซ้ำเมื่อหมด (ไม่มี Remote ให้ Client สั่งเลื่อนขั้น)
-- ⚠️ ระวัง: ห้ามลบ task.wait — ลูปจะวนไม่หยุดจนเซิร์ฟค้าง
function TutorialService.Start()
	if not Tutorial.Enabled then
		return
	end
	while true do
		task.wait(POLL)
		local now = os.clock()
		for player, session in sessions do
			if not player.Parent then
				-- ผู้เล่นออกแล้วแต่ session ถูกสร้างค้าง (PlayerData.Changed มาหลัง PlayerRemoving) → เก็บทิ้ง
				if session.batch then
					MonsterService.cancelTraining(session.batch)
				end
				sessions[player] = nil
				continue
			end
			-- pcall: ผู้เล่นคนเดียวพัง (error ใน advance/โบนัส) ห้ามทำให้ลูปนี้หยุด = ทุกคนค้างขั้นเดิม
			local ok, err = pcall(function()
				local elapsed = now - session.enteredAt
				local step = session.step
				if step == STEP.ChooseElement then
					-- กันพลาด/ผู้เล่นเก่าที่มีธาตุอยู่แล้ว (ปกติ TurretElementService.choose แจ้งมาทันที)
					local data = PlayerData.get(player)
					if data and ElementMath.isElement(data.Element) then
						advance(player, step)
					end
				elseif step == STEP.WatchTurret then
					local batch = session.batch
					if (batch and MonsterService.trainingLeft(batch) == 0) or elapsed >= Tutorial.WatchTimeout then
						advance(player, step)
					end
				elseif step == STEP.UseSkill then
					-- มอนฝึกเป็นเป้า: หมดชุด → รอ SKILL_RESPAWN_DELAY → ปล่อยใหม่ · บอสอยู่ = ไม่ปล่อย (กฎเดิม) แต่กดใส่บอสได้
					local batch = session.batch
					if batch and MonsterService.trainingLeft(batch) == 0 then
						session.batch = nil
						session.respawnAt = now + SKILL_RESPAWN_DELAY
					elseif not batch and now >= session.respawnAt and not BossService.isActive() then
						spawnBatch(player, session, Tutorial.SkillMonsters, Tutorial.SkillMonsterHp)
					end
				elseif step == STEP.MeetBoss then
					if elapsed >= Tutorial.ReadSeconds then
						advance(player, step)
					end
				end
			end)
			if not ok then
				warn(`[TutorialService] {player.Name} ขั้น {session.step} ผิดพลาด: {err}`)
			end
		end
	end
end

return TutorialService
