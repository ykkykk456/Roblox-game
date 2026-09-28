-- คลาสป้อมเริ่มต้น + สายธาตุ (เจ้าของ: Gameplay_Scripter) · สเปก: design/turret-classes.md · ค่า: Config/Skill_class_default
-- เลือกคลาส/สาย: รับจาก TurretClassHandler (ผ่าน Guard แล้ว) → ตรวจกฎทั้งหมดอีกรอบใน PlayerData.update (Server Authority)
-- effect ต่อเนื่อง (Server คำนวณทั้งหมด · เวลาใช้ os.clock()):
--   Dot        = ดาเมจต่อเนื่องต่อเป้า ต่อผู้ยิง · ยิงซ้ำ = รีเซ็ตเวลา/ค่า ไม่ซ้อน
--   ArmorBreak = ตัวคูณดาเมจที่บอสได้รับจากทุกผู้เล่น · หลายคนโยน = ใช้ค่าสูงสุด ไม่ซ้อน
--   BlackHole  = หลุมดำ 1 หลุมต่อเจ้าของป้อม · ดาเมจบอส/มอนที่อยู่ในรัศมีทุกรอบ
-- ป้อมช็อตไม่หยุด effect ที่ปล่อยไปแล้ว · บอสจากไป = ล้าง effect ที่ติดบอส
-- update(now) ถูกเรียกจากรอบ tick ของ TurretService เท่านั้น (ไม่มี loop ของตัวเอง กันนับซ้ำ)
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • ตัวคูณดาเมจ/อัตรายิงของคลาส-สาย, เลเวลที่เลือกสายได้, ค่า effect (DotPerSecond, ArmorBreak, Radius, Seconds …)
--     → src/shared/Config/Skill_class_default.luau · กฎการเลือก → src/shared/Util/ClassMath.luau
--
-- คุยกับไฟล์ไหนบ้าง:
--   • TurretClassHandler (Network) — เรียก choose / chooseBranch · TurretService — เรียก get, damageBoss, apply*, update
--   • BossService — นับดาเมจบอส · MonsterService — ทำดาเมจมอน · PlayerData — เก็บคลาส/สายของผู้เล่น (บันทึกลง DataStore)
--
-- ⚠️ ห้ามแก้: การเปลี่ยนคลาส/สายต้องอยู่ใน PlayerData.update และตรวจกฎซ้ำเสมอ (ห้ามเชื่อค่าที่ Client ส่งมา)
--
-- 📖 อ่านตามลำดับนี้ (ไฟล์นี้มี 2 งานแยกกัน)
--   งาน A: เลือกคลาส/สาย
--     1) Network/TurretClassHandler.luau:Init ส่งคำขอมา → choose (เลือกคลาส) / chooseBranch (เลือกสาย)
--     2) ใน PlayerData.update: ตรวจกฎด้วย Util/ClassMath.luau:canChooseClass / canChooseBranch → ผ่าน = เขียนลงข้อมูล
--     3) สำเร็จ → changedEvent:Fire → TurretService.luau:rebuildIfNeeded สร้างหน้าตาป้อมใหม่ (TurretLook.luau:build)
--   งาน B: effect ต่อเนื่องของสายธาตุ (ดาเมจที่ "ค้าง" หลังยิงไปแล้ว)
--     4) TurretService.luau:hit ยิงโดนเป้า → เรียก applyDot (สายฟ้า) / applyArmorBreak (สายพิษ) / spawnBlackHole (สายมืด)
--        ฟังก์ชันพวกนี้แค่ "จดไว้" ในตาราง dots / armor / holes ยังไม่ทำดาเมจ
--     5) TurretService.luau:tick เรียก update(now) ทุก 0.1 วิ → update คิดว่าผ่านไปกี่วินาที → ทำดาเมจตามนั้น
--     6) ทุกครั้งที่ตีบอส ผ่าน damageBoss → คูณ bossDamageMultiplier (ลดเกราะจากพิษ) → BossService.damage
--   ✏️ อยากเปลี่ยน "พฤติกรรม" effect (ไม่ใช่ตัวเลข) → applyDot / applyArmorBreak / spawnBlackHole / update

-- game:GetService = ขอบริการของ Roblox · Players = รายชื่อผู้เล่น + สัญญาณเข้า/ออกเกม
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- require = โหลดโมดูลอื่นมาใช้ · script.Parent = โฟลเดอร์ที่ไฟล์นี้อยู่ (Services)
local ClassMath = require(ReplicatedStorage.Shared.Util.ClassMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local BossService = require(script.Parent.BossService)
local MonsterService = require(script.Parent.MonsterService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

-- ===== ค่าคงที่ =====
-- MAX_STEP (ปรับได้): เซิร์ฟค้างนานแค่ไหนก็นับดาเมจต่อเนื่องได้ไม่เกินเท่านี้ต่อรอบ · ลด = ปลอดภัยขึ้นแต่ดาเมจหายเมื่อเซิร์ฟกระตุก
local MAX_STEP = 0.5 -- วินาทีสูงสุดที่นับต่อรอบ (กันเซิร์ฟกระตุกแล้วดาเมจก้อนใหญ่)

-- BOSS = ตารางว่างที่ใช้เป็น "ป้ายชื่อ" แทนบอสในตาราง DoT (ห้ามแก้)
-- เป้าของ DoT: ตาราง Monster จาก MonsterService หรือ BOSS
-- ทำไมใช้ตาราง: ในลูอาใช้ "ตาราง" เป็นกุญแจ (key) ของอีกตารางได้ · ตารางแต่ละอันไม่ซ้ำกัน จึงไม่ชนกับมอนตัวไหน
-- table.freeze = ล็อกตารางไม่ให้ใครแก้ข้างใน
local BOSS = table.freeze({})

-- ===== ชนิดข้อมูล =====
-- type = ตั้งชื่อ "หน้าตาของตาราง" ไว้ช่วยตรวจโค้ด (แค่คำใบ้ ไม่เปลี่ยนการทำงาน)
-- Dot = ดาเมจต่อเนื่อง 1 ตัว (perSecond ต่อวินาที ตั้งแต่ startAt ถึง untilAt)
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

-- ===== สถานะ effect ที่กำลังทำงาน =====
-- dots[ผู้ยิง][เป้า] = DoT · holes[เจ้าของ] = หลุมดำ · armor = ค่าลดเกราะบอสตอนนี้ (value 0.2 = บอสโดนแรงขึ้น 20%)
-- lastUpdate = เวลาที่ update ทำงานครั้งก่อน · changedEvent = สัญญาณคลาส/สายเปลี่ยน
-- `{ [Player]: X }` = ตารางที่ใช้ผู้เล่นเป็นกุญแจ · `number?` = ตัวเลข หรือ nil (ยังไม่เคยมีค่า)
-- ⚠️ ระวัง: ข้อมูลพวกนี้อยู่ในหน่วยความจำเท่านั้น ไม่บันทึกลง DataStore (เซิร์ฟปิด = หายหมด ซึ่งถูกต้องแล้ว)
local dots: { [Player]: { [any]: Dot } } = {}
local holes: { [Player]: Hole } = {}
local armor = { value = 0, untilAt = 0 }
local lastUpdate: number? = nil
-- BindableEvent = "กริ่ง" ใช้ส่งสัญญาณระหว่างสคริปต์ฝั่งเดียวกัน (Server ↔ Server) · :Fire() = กดกริ่ง
-- ใครอยากรู้ก็ .Event:Connect(ฟังก์ชัน) ไว้ พอกริ่งดัง ฟังก์ชันนั้นจะถูกเรียก
local changedEvent = Instance.new("BindableEvent")

-- ช่วงเวลาที่ effect ทำงานจริงในรอบนี้ (from, now]
-- คืนจำนวนวินาทีที่ซ้อนกันระหว่างรอบนี้กับช่วงที่ effect ยังทำงาน (ไม่ติดลบ)
-- ตัวอย่าง: รอบนี้ from = 10.0, now = 10.1 · DoT ทำงาน startAt = 8, untilAt = 10.05
--   → min(10.1, 10.05) − max(10.0, 8) = 10.05 − 10.0 = 0.05 วินาที (DoT หมดกลางรอบ นับแค่ครึ่งรอบ)
--   ถ้า DoT หมดไปก่อนรอบนี้ ผลลบ → math.max(0, ...) ปัดเป็น 0 = ไม่ทำดาเมจ
local function activeSeconds(from: number, now: number, startAt: number, untilAt: number): number
	return math.max(0, math.min(now, untilAt) - math.max(from, startAt))
end

-- ===== API: เลือกคลาส/สาย =====
local TurretClassService = {}

-- ยิงเมื่อคลาส/สายของผู้เล่นเปลี่ยน: (player) · TurretService ใช้สร้างหน้าตาป้อมใหม่
-- เปิดให้ไฟล์อื่นเห็นแค่ .Event (ฟังได้อย่างเดียว) · กด Fire ได้เฉพาะในไฟล์นี้
TurretClassService.Changed = changedEvent.Event

-- คลาส/สายปัจจุบัน ("" = ยังไม่เลือก / ข้อมูลยังไม่โหลด)
-- `: (string, string)` = ฟังก์ชันนี้คืนค่า 2 ตัวพร้อมกัน · เรียกแบบ local classId, branchId = TurretClassService.get(p)
function TurretClassService.get(player: Player): (string, string)
	-- PlayerData.get = อ่านข้อมูลผู้เล่น (อ่านอย่างเดียว) · nil = ยังโหลดจาก DataStore ไม่เสร็จ
	local data = PlayerData.get(player)
	if not data then
		return "", ""
	end
	-- กันข้อมูลเสีย: ถ้าไม่ใช่ข้อความ ให้ถือว่า "" (ยังไม่เลือก)
	local classId = if type(data.TurretClass) == "string" then data.TurretClass else ""
	local branchId = if type(data.TurretBranch) == "string" then data.TurretBranch else ""
	return classId, branchId
end

-- เลือก/เปลี่ยนคลาส · คืน true ถ้าเปลี่ยนสำเร็จ
function TurretClassService.choose(player: Player, classId: string): boolean
	-- changed เริ่มเป็น false · ฟังก์ชันข้างในจะเปลี่ยนเป็น true ถ้าแก้ข้อมูลจริง (ฟังก์ชันซ้อนแก้ตัวแปรข้างนอกได้)
	local changed = false
	-- PlayerData.update(player, function(data) ... end) = วิธีเดียวที่ถูกต้องในการ "แก้" ข้อมูลที่บันทึก
	--   data ข้างในคือข้อมูลจริงของผู้เล่น · ถ้ายังโหลดไม่เสร็จ ฟังก์ชันข้างในจะไม่ถูกเรียกเลย (ปลอดภัย)
	-- ⚠️ ระวัง: ห้ามย้ายการแก้ data.TurretClass ออกไปนอก update และห้ามตัดการตรวจ if ข้างล่าง (กฎ Server Authority)
	PlayerData.update(player, function(data)
		-- ตรวจซ้ำที่นี่ถึงแม้ Handler ตรวจแล้ว: มีคลาสนี้จริง + ยังไม่ล็อก (ยังไม่มีสาย) → Util/ClassMath.luau:canChooseClass
		if not ClassMath.isClass(classId) or not ClassMath.canChooseClass(data.TurretClass, data.TurretBranch) then
			return -- ไม่มีคลาสนี้ / เลือกสายแล้ว = ล็อก
		end
		-- เลือกคลาสเดิมซ้ำ → ไม่ต้องทำอะไร (ไม่ต้องสร้างป้อมใหม่)
		if data.TurretClass == classId then
			return
		end
		data.TurretClass = classId
		data.TurretBranch = "" -- ข้อมูลสายเสีย (ไม่รู้จัก) ล้างทิ้งพร้อมกัน
		changed = true
	end)
	-- บอกไฟล์อื่นว่า "คลาสเปลี่ยนแล้ว" → TurretService.luau:rebuildIfNeeded สร้างหน้าตาป้อมใหม่
	if changed then
		changedEvent:Fire(player)
	end
	return changed
end

-- เลือกสายธาตุ (ครั้งเดียว) · คืน true ถ้าสำเร็จ
function TurretClassService.chooseBranch(player: Player, branchId: string): boolean
	local changed = false
	-- ⚠️ ระวัง: เหมือน choose — แก้ข้อมูลใน update เท่านั้น และต้องผ่าน canChooseBranch ก่อนเสมอ
	PlayerData.update(player, function(data)
		-- เลเวลจากข้อมูลบันทึกห้ามเชื่อตรงๆ → clampLevel บังคับให้อยู่ในช่วง 1..MaxLevel ก่อน
		local level = TurretMath.clampLevel(data.TurretLevel)
		-- ตรวจครบ 4 ข้อ (มีคลาส · ยังไม่มีสาย · สายของคลาสตัวเอง · เลเวลถึง) → Util/ClassMath.luau:canChooseBranch
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

-- ===== API: ดาเมจบอส + effect ของสาย =====
-- ตัวคูณดาเมจที่บอสได้รับ (ลดเกราะจากสายพิษ) · ใช้กับดาเมจบอสทุกแหล่ง
-- now มาจาก os.clock() = นาฬิกาของเซิร์ฟ (วินาที นับไปเรื่อยๆ) ใช้เทียบเวลาหมดอายุ
function TurretClassService.bossDamageMultiplier(now: number): number
	-- ยังไม่หมดเวลาพิษ และบอสยังอยู่ → คูณเพิ่ม
	-- ตัวอย่าง: armor.value = 0.25 → คืน 1.25 = บอสโดนแรงขึ้น 25%
	if now < armor.untilAt and BossService.isActive() then
		return 1 + armor.value
	end
	return 1
end

-- ทำดาเมจบอสผ่านตัวคูณลดเกราะ (จุดเดียวที่ป้อมตีบอส)
-- ตัวอย่าง: ยิง 100 ขณะบอสติดพิษ 0.25 → BossService ได้ 100 × 1.25 = 125
-- ⚠️ ระวัง: ดาเมจบอส = รางวัลผู้เล่น (BossService นับดาเมจแจกรางวัล) · ตีบอสจากที่อื่นควรผ่านฟังก์ชันนี้เสมอ
function TurretClassService.damageBoss(owner: Player, amount: number, now: number)
	BossService.damage(owner, amount * TurretClassService.bossDamageMultiplier(now))
end

-- สายพิษ: ลดเกราะบอส · ค่าสูงสุดชนะ ไม่ซ้อน · เวลาต่อจากเดิมถ้ายาวกว่า
-- ✏️ แก้ตรงนี้ถ้าอยากให้พิษ "ซ้อนกันได้" (เช่น armor.value += value) — ตอนนี้ตั้งใจให้ไม่ซ้อน
function TurretClassService.applyArmorBreak(value: number, seconds: number, now: number)
	if not BossService.isActive() then
		return
	end
	-- พิษเก่าหมดแล้ว → ใช้ค่าใหม่เลย · พิษเก่ายังอยู่ → เก็บค่าที่มากกว่า (math.max = เลือกตัวที่ใหญ่กว่า)
	if now >= armor.untilAt then
		armor.value = value
	else
		armor.value = math.max(armor.value, value)
	end
	-- ต่อเวลา: ใช้เวลาหมดที่ "ช้ากว่า" ระหว่างของเดิมกับของใหม่ (ไม่หดเวลาที่เหลือ)
	-- ตัวอย่าง: now = 100, seconds = 5 → หมดที่ 105 · ถ้าของเดิมหมดที่ 103 → เป็น 105
	armor.untilAt = math.max(armor.untilAt, now + seconds)
end

-- สายฟ้า: ติดดาเมจต่อเนื่องที่เป้า (monster = nil → บอส) · perSecond = ดาเมจต่อวินาที (ก่อนลดเกราะ)
-- ตัวอย่าง (สมมติดาเมจต่อนัด 50 · ตัวคูณจาก Config): 50 × DotPerSecond 0.4 = 20 ต่อวินาที × DotSeconds 3 วิ = รวม 60
-- ✏️ แก้ตรงนี้ถ้าอยากให้ DoT ซ้อนกันได้หลายชั้น (ตอนนี้ 1 ผู้ยิงต่อ 1 เป้ามีได้ 1 ชั้น ยิงซ้ำ = ทับของเดิม)
function TurretClassService.applyDot(owner: Player, monster: any?, perSecond: number, seconds: number, now: number)
	-- ไม่มีมอน = ยิงบอส → ใช้ป้าย BOSS เป็นกุญแจแทน
	local target = if monster then monster else BOSS
	-- หา "ลิ้นชัก" DoT ของผู้ยิงคนนี้ · ยังไม่มี → สร้างตารางว่างแล้วใส่ไว้ใน dots
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
-- ✏️ แก้ตรงนี้ถ้าอยากให้มีหลายหลุมพร้อมกัน (ต้องเปลี่ยน holes เป็นรายการ และแก้ลูปใน update ด้วย)
-- Vector3 = จุด/ทิศในโลก 3 มิติ (X, Y, Z)
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
	-- เขียนทับหลุมเดิมของเจ้าของเลย (holes มีได้ช่องเดียวต่อผู้เล่น)
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
-- `Hole?` = คืนตาราง Hole หรือ nil
function TurretClassService.holeOf(owner: Player, now: number): Hole?
	local hole = holes[owner]
	return if hole and now < hole.untilAt then hole else nil
end

-- ===== อัปเดตทุกรอบ =====
-- ล้าง effect ที่ติดบอส (บอสจากไป)
local function clearBoss()
	armor.value = 0
	armor.untilAt = 0
	-- `for _, v in t do` = วนทุกช่อง · `_` = ไม่สนกุญแจ (ตั้งชื่อ _ ไว้บอกว่า "ไม่ใช้")
	-- ตั้งค่าเป็น nil = ลบช่องนั้นออกจากตาราง
	for _, perOwner in dots do
		perOwner[BOSS] = nil
	end
	-- หลุมดำที่ปล่อยใส่บอส หายไปพร้อมบอส · หลุมที่ปล่อยใส่มอนยังอยู่ต่อจนหมดเวลา
	for owner, hole in holes do
		if hole.onBoss then
			holes[owner] = nil
		end
	end
end

-- เรียกทุกรอบ tick ของ TurretService: ทำดาเมจ DoT/หลุมดำ ตามเวลาที่ผ่านไป
-- แนวคิด: ไม่ได้ทำดาเมจ "ทีละวินาที" แต่ทุกรอบ (~0.1 วิ) คิดว่าผ่านไปกี่วิ แล้วทำดาเมจ = ต่อวินาที × วินาทีนั้น
--   ตัวอย่าง: DoT 20/วิ · รอบนี้ผ่านไป 0.1 วิ → ทำดาเมจ 2 · ครบ 3 วิ (30 รอบ) รวมได้ 60 พอดี
-- ⚠️ ระวัง: ห้ามเรียก update จากที่อื่นเพิ่ม (เช่นทำ loop ของตัวเอง) — ดาเมจจะถูกนับซ้ำ
function TurretClassService.update(now: number)
	-- from = เวลาเริ่มของรอบนี้ (ครั้งแรกเริ่มจาก now = ยังไม่นับอะไร · ไม่ย้อนเกิน MAX_STEP)
	-- `lastUpdate or now` = ถ้า lastUpdate เป็น nil (ครั้งแรก) ใช้ now แทน
	-- ตัวอย่าง: เซิร์ฟค้าง 2 วิ (lastUpdate = 8, now = 10) → from = max(8, 9.5) = 9.5 → นับแค่ 0.5 วิ
	local from = math.max(lastUpdate or now, now - MAX_STEP)
	lastUpdate = now
	local bossActive = BossService.isActive()
	if not bossActive then
		clearBoss()
	end

	-- ส่วนที่ 1: DoT (สายฟ้า) · วนสองชั้น: ผู้ยิงแต่ละคน → เป้าแต่ละตัวที่คนนั้นติด DoT ไว้
	for owner, perOwner in dots do
		for target, dot in perOwner do
			-- เป้ายังอยู่ไหม: บอส → ดูว่าบอสยังอยู่ · มอน → ดูช่อง alive ของมอนตัวนั้น
			local alive = if target == BOSS then bossActive else target.alive
			local seconds = activeSeconds(from, now, dot.startAt, dot.untilAt)
			if alive and seconds > 0 then
				-- ดาเมจรอบนี้ = ต่อวินาที × วินาทีที่ผ่านไป · บอสผ่าน damageBoss (โดนคูณพิษด้วย)
				if target == BOSS then
					TurretClassService.damageBoss(owner, dot.perSecond * seconds, now)
				else
					MonsterService.damage(target, owner, dot.perSecond * seconds)
				end
			end
			-- เป้าตาย หรือหมดเวลา → ลบ DoT นี้ทิ้ง
			if not alive or now >= dot.untilAt then
				perOwner[target] = nil -- ลบ key ระหว่างวนได้ [Verified: Luau อนุญาตตั้ง nil ให้ key ปัจจุบันขณะวน]
			end
		end
		-- next(ตาราง) == nil = ตารางว่างแล้ว → ลบลิ้นชักของผู้ยิงคนนี้ทิ้ง (ประหยัดหน่วยความจำ)
		if next(perOwner) == nil then
			dots[owner] = nil
		end
	end

	-- ส่วนที่ 2: หลุมดำ (สายมืด) · ทำดาเมจทุกอย่างที่อยู่ในรัศมี
	-- getTarget = ตำแหน่งบอสตอนนี้ (nil = ไม่มีบอส)
	local bossPosition = BossService.getTarget()
	for owner, hole in holes do
		local seconds = activeSeconds(from, now, hole.startAt, hole.untilAt)
		if seconds > 0 then
			-- (จุดA − จุดB).Magnitude = ระยะห่างระหว่าง 2 จุด (หน่วย studs) · ≤ radius = อยู่ในหลุม
			if bossPosition and (bossPosition - hole.position).Magnitude <= hole.radius then
				TurretClassService.damageBoss(owner, hole.bossPerSecond * seconds, now)
			end
			-- วนมอนทุกตัวที่ยังมีชีวิต ตัวไหนอยู่ในรัศมีโดนหมด (positionOf คำนวณตำแหน่งมอน ณ เวลา now)
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

-- ผู้เล่นออกเกม → ลบ DoT/หลุมดำของคนนั้นทิ้ง (ไม่ทำดาเมจแทนคนที่ไม่อยู่แล้ว)
-- Init = init.server.luau เรียกให้ครั้งเดียวตอนเซิร์ฟเริ่ม
-- :Connect(ฟังก์ชัน) = "เมื่อเหตุการณ์นี้เกิด ให้เรียกฟังก์ชันนี้" · PlayerRemoving เกิดตอนผู้เล่นกำลังออก
function TurretClassService.Init()
	Players.PlayerRemoving:Connect(function(player)
		dots[player] = nil
		holes[player] = nil
	end)
end

return TurretClassService
