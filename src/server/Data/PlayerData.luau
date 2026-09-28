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
--   • สกิลเริ่มต้น → src/shared/Config/Skills.luau (StarterSkill)
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
local Skills = require(ReplicatedStorage.Shared.Config.Skills)

-- ===== ค่าคงที่ =====
-- ชื่อ DataStore · ห้ามแก้
local STORE_NAME = "PlayerData"
-- เวอร์ชันโครงข้อมูลปัจจุบัน · แก้ได้เฉพาะตอนเพิ่ม migration (เพิ่มทีละ 1)
local VERSION = 5
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
	GachaTickets = 0, -- v3
	Skills = { [Skills.StarterSkill] = { Level = 1, Copies = 0 } }, -- v3: [skillId] = { Level, Copies }
	EquippedSkill = Skills.StarterSkill, -- v3
	Upgrades = { Bag = 1, Magazine = 1, House = 1, Speed = 1 }, -- v4: เลเวลอัปตัวเอง (ค่าพลังคำนวณจาก Config)
	Gear = {}, -- v4: ["<ช่อง>_<ระดับ>"] = จำนวน เช่น Barrel_Rare = 2
	Rebirths = 0, -- v4
	LastSeen = 0, -- v4: os.time() ฝั่ง Server ตอนออกเกม (คิดเงิน idle ตอนออฟไลน์)
	Login = { Day = 0, Streak = 0 }, -- v4: Day = เลขวัน UTC ที่รับรางวัลล่าสุด
	TurretClass = "", -- v5: คลาสป้อม ("" = ยังไม่เลือก → Unchosen) · ค่าอยู่ใน Config/Skill_class_default
	TurretBranch = "", -- v5: สายธาตุ ("" = ยังไม่เลือก · เลือกแล้วล็อก)
}

-- MIGRATIONS[n] แปลงข้อมูลจากเวอร์ชัน n เป็น n + 1
-- เพิ่ม field ใหม่: ใส่ใน DEFAULT + VERSION = 6 + เพิ่ม [5] = function(data) ... return data end ต่อท้าย
local MIGRATIONS: { [number]: (any) -> any } = {
	-- v1 → v2: เพิ่มเลเวลป้อม
	[1] = function(data)
		data.TurretLevel = 1
		return data
	end,
	-- v2 → v3: เพิ่มตั๋วกาชาและคลังสกิล (ทุกคนได้สกิลเริ่มต้น)
	[2] = function(data)
		data.GachaTickets = 0
		data.Skills = { [Skills.StarterSkill] = { Level = 1, Copies = 0 } }
		data.EquippedSkill = Skills.StarterSkill
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
-- ตัวอย่าง: PlayerData.update(player, function(data) data.GachaTickets += 1 end)
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
