-- ข้อมูลถาวรของผู้เล่น (เจ้าของ: DataStore_Backend)
-- โค้ดอื่นแก้เงิน/ไอเทม/ความก้าวหน้า ผ่าน PlayerData.get / PlayerData.update เท่านั้น
--
-- Data Safety:
--   • ทุกการเรียก DataStore ครอบ pcall + retry
--   • โหลดไม่สำเร็จ → loaded = false → ไม่บันทึกทับเด็ดขาด (นอก Studio จะ kick ให้เข้าใหม่)
--   • ข้อมูลเวอร์ชันใหม่กว่าเซิร์ฟเวอร์นี้ → ไม่บันทึกทับ
--   • field ที่ขาดเติมจาก DEFAULT อัตโนมัติ · เปลี่ยนโครงข้อมูล → เพิ่ม VERSION และ MIGRATIONS
--   • ยังไม่มี session lock [Proposed: เพิ่มเมื่อมีระบบแลกเปลี่ยน/ของมีค่าสูง]
--
-- ภาพรวมการทำงาน: ผู้เล่นเข้า → load (อ่าน DataStore → migrate → reconcile) → เก็บใน profiles
--   ระหว่างเล่น → ระบบอื่นเรียก update → ยิง Changed · ทุก AUTOSAVE_INTERVAL วิ / ตอนออก / ตอนปิดเซิร์ฟ → save
--
-- อยากปรับ:
--   • เงินเริ่มต้น → src/shared/Config/Economy.luau (StartingCoins) ไม่ต้องแก้ไฟล์นี้
--   • อุปกรณ์ป้อม (ช่องเริ่มต้น, ขนาดกระเป๋า, ตั๋วเก่า → เหรียญ) → src/shared/Config/Equipment.luau
-- คุยกับ: เกือบทุก Service (get/update/waitFor/Changed) · StatsService ส่งค่าไป HUD
--
-- ห้ามแก้ (ข้อมูลผู้เล่นจริงหายได้):
--   • เพิ่ม/ลบ/เปลี่ยนชื่อ field ใน DEFAULT → ต้องเพิ่ม VERSION ขึ้น 1 และเขียน MIGRATIONS[เวอร์ชันเดิม] ทุกครั้ง
--   • ห้ามเปลี่ยน STORE_NAME หรือ keyFor (ข้อมูลเก่าทุกคนจะหาไม่เจอ = เหมือนเริ่มใหม่หมด)
--   • ห้ามลดเลข VERSION และห้ามลบ migration เก่า (คนที่ไม่ได้เข้าเกมนานยังต้องใช้)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)

-- ===== ค่าคงที่ =====
-- ชื่อ DataStore · ห้ามแก้
local STORE_NAME = "PlayerData"
-- เวอร์ชันโครงข้อมูลปัจจุบัน · แก้ได้เฉพาะตอนเพิ่ม migration (เพิ่มทีละ 1)
local VERSION = 8
-- ลองเรียก DataStore กี่ครั้งก่อนยอมแพ้ (ปรับได้ 3–5 · มากไป = ผู้เล่นรอนานตอนโหลดพัง)
local MAX_ATTEMPTS = 3
-- บันทึกอัตโนมัติทุกกี่วินาที (ปรับได้ · ต่ำไปเสี่ยงชนโควตา DataStore · สูงไปเสียข้อมูลมากขึ้นถ้าเซิร์ฟล่ม)
local AUTOSAVE_INTERVAL = 120

-- ===== โครงข้อมูล =====
-- ข้อมูลตั้งต้นของผู้เล่นใหม่ และแม่แบบที่ reconcile ใช้เติม field ที่ขาด · "-- vN" = field นี้เพิ่มในเวอร์ชัน N
local DEFAULT = {
	Version = VERSION,
	Coins = Economy.StartingCoins,
	TurretLevel = 1, -- v2
	-- v3 GachaTickets / Skills / EquippedSkill (กาชาสกิล) → ถูกลบใน v7 (ดู MIGRATIONS[6])
	Upgrades = { Bag = 1, Magazine = 1, House = 1, Speed = 1 }, -- v4: เลเวลอัปตัวเอง (ค่าพลังคำนวณจาก Config)
	-- v7: อุปกรณ์ป้อม (design/equipment.md หัวข้อ 7) · แก้ผ่าน Services/GearService เท่านั้น
	--   Items = ["<ช่อง>_<แบบ>_<ระดับ>"] = จำนวน · Equipped = [ช่อง] = id หรือ "" · Slots = ช่องที่เปิด · Pity = นับ rolls ไม่ได้ Epic+
	-- ⚠️ reconcile ไม่ตรวจ key ใน Items → load เรียก GearMath.sanitize ทุกครั้ง (ทิ้ง id มั่ว/จำนวนเสีย/ใส่ช่องล็อก)
	Gear = GearMath.newGear(),
	Rebirths = 0, -- v4
	LastSeen = 0, -- v4: os.time() ฝั่ง Server ตอนออกเกม (คิดเงิน idle ตอนออฟไลน์)
	Login = { Day = 0, Streak = 0 }, -- v4: Day = เลขวัน UTC ที่รับรางวัลล่าสุด
	-- v5 TurretClass / TurretBranch (คลาสป้อมเดิม) → ถูกแทนด้วย Element ใน v6 (ดู MIGRATIONS[5])
	Element = "", -- v6: ธาตุป้อม ("" = ยังไม่เลือก → Unchosen · UI เด้งให้เลือก) · id อยู่ใน Config/Elements
	-- (วิวัฒนาการยังไม่ทำ → ยังไม่มี field Evolution · ตอนทำค่อยเพิ่มเวอร์ชันถัดไป)
	-- v8: ระบบฝึกสอน (design/tutorial.md) · แก้ผ่าน Services/TutorialService เท่านั้น
	--   TutorialStep = ขั้นที่กำลังทำ 1..5 (6 = จบ) · TutorialDone = ฝึกจบแล้ว (true = ไม่ต้องฝึกอีก)
	TutorialStep = 1, -- v8
	TutorialDone = false, -- v8
}

-- MIGRATIONS[n] แปลงข้อมูลจากเวอร์ชัน n เป็น n + 1
-- เพิ่ม field ใหม่: ใส่ใน DEFAULT + VERSION = 9 + เพิ่ม [8] = function(data) ... return data end ต่อท้าย
local MIGRATIONS: { [number]: (any) -> any } = {
	-- v1 → v2: เพิ่มเลเวลป้อม
	[1] = function(data)
		data.TurretLevel = 1
		return data
	end,
	-- v2 → v3: เพิ่มตั๋วกาชาและคลังสกิล (ทุกคนได้สกิลเริ่มต้น)
	-- ⚠️ Config/Skills ถูกลบแล้ว (ถอดกาชา v7) → เขียนค่าเดิมตรงๆ ("Overdrive" = StarterSkill เดิม) · field พวกนี้ถูกลบต่อใน [6]
	[2] = function(data)
		data.GachaTickets = 0
		data.Skills = { Overdrive = { Level = 1, Copies = 0 } }
		data.EquippedSkill = "Overdrive"
		return data
	end,
	-- v3 → v4: อัปตัวเอง · อุปกรณ์แต่ง · Rebirth · เวลาออกเกม · รางวัล Login (design/crater-map.md)
	[3] = function(data)
		data.Upgrades = { Bag = 1, Magazine = 1, House = 1, Speed = 1 }
		data.Gear = {}
		data.Rebirths = 0
		data.LastSeen = 0
		data.Login = { Day = 0, Streak = 0 }
		return data
	end,
	-- v4 → v5: คลาสป้อมเริ่มต้น + สายธาตุ (design/turret-classes.md) · ผู้เล่นเดิมยังไม่เลือก → UI เด้งให้เลือก
	[4] = function(data)
		data.TurretClass = ""
		data.TurretBranch = ""
		return data
	end,
	-- v5 → v6: คลาสป้อม → ธาตุป้อม (design/element-skills.md หัวข้อ 6.2) [Proposed]
	-- คลาสเก่ากับธาตุใหม่เทียบกันไม่ตรง → รีเซ็ตให้เลือกใหม่ฟรี (ไม่แมป) · TurretLevel / เงิน / ของอื่นไม่แตะ
	-- ลบแค่ TurretClass / TurretBranch (field ที่ถูกแทน) · field กาชา (Skills, EquippedSkill, GachaTickets) คงไว้ก่อน
	--   (ถอดกาชาแล้วใน v7 → field พวกนี้ถูกลบที่ MIGRATIONS[6])
	[5] = function(data)
		data.Element = ""
		data.TurretClass = nil
		data.TurretBranch = nil
		return data
	end,
	-- v6 → v7: ถอดกาชาสกิล → อุปกรณ์ป้อม (design/equipment.md หัวข้อ 7.2) [Proposed]
	--   • Gear รูปแบบเก่า ["<ช่อง>_<ระดับ>"] → Items ["<ช่อง>_Neutral_<ระดับ>"] (GearMath.fromLegacy · ช่อง/ระดับไม่รู้จัก = ทิ้ง + warn)
	--   • ตั๋วกาชาที่เหลือ → เหรียญ ใบละ Equipment.TicketToCoins (50) · รวมแล้วไม่เกิน Economy.MaxCoins
	--   • ลบ GachaTickets / Skills / EquippedSkill · ของอื่น (เลเวล ธาตุ เงินเดิม) ไม่แตะ
	-- ตัวอย่าง: Coins 100 + ตั๋ว 3 ใบ → Coins 250
	[6] = function(data)
		local items, dropped = GearMath.fromLegacy(data.Gear)
		if dropped > 0 then
			warn(`[PlayerData] migration v6→v7: ทิ้งอุปกรณ์รูปแบบเก่าที่ไม่รู้จัก {dropped} รายการ`)
		end
		local gear = GearMath.newGear()
		gear.Items = items
		data.Gear = gear
		local rawTickets = data.GachaTickets
		local tickets = if type(rawTickets) == "number" and rawTickets == rawTickets and rawTickets < math.huge
			then math.max(0, math.floor(rawTickets))
			else 0
		local rawCoins = data.Coins
		local coins = if type(rawCoins) == "number" and rawCoins == rawCoins and math.abs(rawCoins) < math.huge
			then rawCoins
			else 0
		data.Coins = math.min(coins + tickets * Equipment.TicketToCoins, Economy.MaxCoins)
		data.GachaTickets = nil
		data.Skills = nil
		data.EquippedSkill = nil
		return data
	end,
	-- v7 → v8: ระบบฝึกสอน 5 ขั้น (design/tutorial.md) [Proposed]
	--   บังคับฝึกทุกคน รวมผู้เล่นเก่า → ทุกคนเริ่มขั้น 1 · ยังไม่จบ · ของอื่น (เงิน เลเวล ธาตุ อุปกรณ์) ไม่แตะ
	--   ผู้เล่นเก่าที่มีธาตุแล้ว → ขั้น 1 (เลือกธาตุ) ผ่านเองทันทีตอนเข้าเกม (TutorialService) ไม่ต้องเสียเงินเลือกใหม่
	[7] = function(data)
		data.TutorialStep = 1
		data.TutorialDone = false
		return data
	end,
}

-- ===== สถานะในหน่วยความจำ =====
-- loaded = false แปลว่าเป็นข้อมูลชั่วคราว (โหลดพัง) → save จะไม่เขียนทับของจริง
type Profile = { data: any, loaded: boolean }

-- ข้อมูลของผู้เล่นที่อยู่ในเซิร์ฟตอนนี้
local profiles: { [Player]: Profile } = {}
-- ตัวยิง PlayerData.Changed
local changedEvent = Instance.new("BindableEvent")
-- nil = เปิด DataStore ไม่ได้ (เช่น Studio ที่ไม่เปิด API Access) → ทุกคนได้ข้อมูลชั่วคราว
local store: DataStore? = nil

-- ===== ตัวช่วย =====
-- คัดลอกตารางแบบลึก (ตารางซ้อนก็ถูกคัดลอกใหม่หมด) กันผู้เล่นหลายคนแชร์ตารางเดียวกันจาก DEFAULT
local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- เติม field ที่ขาด และแทน field ที่ชนิดผิด/เป็น NaN/inf ด้วยค่าจาก DEFAULT (ข้อมูลจาก DataStore ห้ามเชื่อโดยไม่ตรวจ)
-- path ใช้แค่เขียนใน warn ให้รู้ว่า field ไหนเสีย · ทำงานซ้อนลงไปในตารางย่อยด้วย
local function reconcile(data: any, template: any, path: string)
	for key, value in template do
		local current = data[key]
		local invalid = current ~= nil
			and (
				type(current) ~= type(value)
				or (type(current) == "number" and (current ~= current or current == math.huge or current == -math.huge))
			)
		if invalid then
			warn(`[PlayerData] {path}.{key} ชนิดหรือค่าไม่ถูกต้อง ({current}) — ใช้ค่าเริ่มต้นแทน`)
		end
		if current == nil or invalid then
			data[key] = deepCopy(value)
		elseif type(value) == "table" then
			reconcile(current, value, `{path}.{key}`)
		end
	end
end

-- ไล่แปลงข้อมูลเก่าทีละขั้นจนถึง VERSION ปัจจุบัน (เช่น v2 → v3 → v4 → v5) · ข้อมูลไม่มี Version = ถือเป็น v0
local function migrate(data: any): any
	local version = if type(data.Version) == "number" then data.Version else 0
	while version < VERSION do
		local step = MIGRATIONS[version]
		if step then
			data = step(data)
		end
		version += 1
		data.Version = version
	end
	return data
end

-- เรียก callback (ที่คุยกับ DataStore) สูงสุด MAX_ATTEMPTS ครั้ง · พังแต่ละครั้งรอนานขึ้น (2, 4 วินาที)
-- คืน (true, ผลลัพธ์) ถ้าสำเร็จ หรือ (false, error สุดท้าย)
local function withRetry(label: string, callback: () -> any): (boolean, any)
	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		warn(`[PlayerData] {label} ครั้งที่ {attempt} ล้มเหลว: {result}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastError
end

-- key ใน DataStore ของผู้เล่นแต่ละคน เช่น "u_12345" · ห้ามแก้
local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

-- เก็บ profile แล้วแจ้งทุกระบบว่าข้อมูลพร้อม
local function setProfile(player: Player, profile: Profile)
	profiles[player] = profile
	changedEvent:Fire(player, profile.data)
end

-- โหลดพัง: ให้ข้อมูลชั่วคราว (ไม่บันทึก) · ใน Studio แค่เตือน · เกมจริง kick ให้เข้าใหม่ (กันเล่นบนข้อมูลปลอมแล้วเสียของ)
local function onLoadFailed(player: Player)
	setProfile(player, { data = deepCopy(DEFAULT), loaded = false })
	if RunService:IsStudio() then
		warn("[PlayerData] ใช้ข้อมูลชั่วคราวและจะไม่บันทึก (เปิด Game Settings > Security > Enable Studio Access to API Services เพื่อทดสอบ DataStore จริง)")
	else
		player:Kick("โหลดข้อมูลไม่สำเร็จ กรุณาเข้าเกมใหม่อีกครั้ง")
	end
end

-- ===== โหลด/บันทึก =====
-- โหลดข้อมูลผู้เล่น 1 คน (เรียกตอนผู้เล่นเข้าเกม)
-- ไม่มีข้อมูลเดิม = ผู้เล่นใหม่ → ใช้ DEFAULT · มีข้อมูล → migrate แล้ว reconcile
local function load(player: Player)
	if not store then
		onLoadFailed(player)
		return
	end
	local activeStore = store :: DataStore
	local ok, stored = withRetry(`load {player.UserId}`, function()
		return activeStore:GetAsync(keyFor(player))
	end)
	-- ผู้เล่นออกไประหว่างรอโหลด → ไม่ต้องทำอะไรต่อ
	if not player.Parent then
		return
	end
	if not ok then
		onLoadFailed(player)
		return
	end
	if type(stored) ~= "table" then
		setProfile(player, { data = deepCopy(DEFAULT), loaded = true })
		return
	end
	if type(stored.Version) == "number" and stored.Version > VERSION then
		warn(`[PlayerData] ข้อมูลของ {player.UserId} ใหม่กว่าเซิร์ฟเวอร์นี้ (v{stored.Version}) — จะไม่บันทึกทับ`)
		onLoadFailed(player)
		return
	end
	local data = migrate(stored)
	reconcile(data, DEFAULT, `u_{player.UserId}`)
	-- ล้างอุปกรณ์ (reconcile ไม่ตรวจ key ภายใน Items) → Util/GearMath.luau:sanitize
	local gear, fixes = GearMath.sanitize(data.Gear)
	if fixes > 0 then
		warn(`[PlayerData] u_{player.UserId}.Gear ข้อมูลเสีย {fixes} จุด — ล้างแล้ว`)
	end
	data.Gear = gear
	setProfile(player, { data = data, loaded = true })
end

-- บันทึกข้อมูลผู้เล่น 1 คน · ข้ามถ้าไม่เคยโหลดสำเร็จ (loaded = false) = กฎ "โหลดไม่สำเร็จ ห้ามบันทึกทับ"
local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded or not store then
		return
	end
	local activeStore = store :: DataStore
	-- ถ่ายสำเนาไว้ก่อน เพราะระหว่างรอ DataStore ข้อมูลจริงอาจถูกแก้ต่อ
	local snapshot = deepCopy(profile.data)
	withRetry(`save {player.UserId}`, function()
		activeStore:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
end

-- ===== API ให้ระบบอื่นใช้ =====
local PlayerData = {}

-- ยิงเมื่อข้อมูลโหลดเสร็จ และหลัง update ทุกครั้ง: (player, data)
PlayerData.Changed = changedEvent.Event

-- คืนข้อมูลของผู้เล่น (อ่านอย่างเดียว) หรือ nil ถ้ายังโหลดไม่เสร็จ
function PlayerData.get(player: Player): any?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- แก้ข้อมูลผ่าน callback · คืน false ถ้ายังไม่มีข้อมูลของผู้เล่นคนนี้
-- ตัวอย่าง: PlayerData.update(player, function(data) data.TurretLevel += 1 end)
function PlayerData.update(player: Player, callback: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	callback(profile.data)
	changedEvent:Fire(player, profile.data)
	return true
end

-- รอจนข้อมูลพร้อม (คืน nil ถ้าผู้เล่นออกก่อน)
function PlayerData.waitFor(player: Player): any?
	while not profiles[player] and player.Parent do
		task.wait()
	end
	return PlayerData.get(player)
end

-- ===== เริ่มระบบ =====
-- เรียกตอนเซิร์ฟเวอร์เริ่ม (ก่อน Service อื่น เพราะโฟลเดอร์ Data โหลดก่อน)
-- เปิด DataStore · ผูกโหลดตอนเข้า / บันทึกตอนออก / บันทึกทุกคนตอนปิดเซิร์ฟ
function PlayerData.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(`[PlayerData] เปิด DataStore ไม่ได้: {result}`)
	end

	Players.PlayerAdded:Connect(load)
	-- ผู้เล่นที่เข้ามาก่อนสคริปต์นี้เริ่ม (เกิดได้ใน Studio)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

	-- ตอนปิดเซิร์ฟ: บันทึกทุกคนพร้อมกัน แล้วรอจนเสร็จหมด (pending = จำนวนที่ยังบันทึกไม่เสร็จ)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

-- วนบันทึกอัตโนมัติทุก AUTOSAVE_INTERVAL วินาที ตลอดอายุเซิร์ฟ
function PlayerData.Start()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in profiles do
			task.spawn(save, player)
		end
	end
end

return PlayerData
