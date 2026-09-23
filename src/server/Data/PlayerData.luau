-- ข้อมูลถาวรของผู้เล่น (เจ้าของ: DataStore_Backend)
-- โค้ดอื่นแก้เงิน/ไอเทม/ความก้าวหน้า ผ่าน PlayerData.get / PlayerData.update เท่านั้น
--
-- Data Safety:
--   • ทุกการเรียก DataStore ครอบ pcall + retry
--   • โหลดไม่สำเร็จ → loaded = false → ไม่บันทึกทับเด็ดขาด (นอก Studio จะ kick ให้เข้าใหม่)
--   • ข้อมูลเวอร์ชันใหม่กว่าเซิร์ฟเวอร์นี้ → ไม่บันทึกทับ
--   • field ที่ขาดเติมจาก DEFAULT อัตโนมัติ · เปลี่ยนโครงข้อมูล → เพิ่ม VERSION และ MIGRATIONS
--   • ยังไม่มี session lock [Proposed: เพิ่มเมื่อมีระบบแลกเปลี่ยน/ของมีค่าสูง]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local STORE_NAME = "PlayerData"
local VERSION = 1
local MAX_ATTEMPTS = 3
local AUTOSAVE_INTERVAL = 120

local DEFAULT = {
	Version = VERSION,
	Coins = Economy.StartingCoins,
}

-- MIGRATIONS[n] แปลงข้อมูลจากเวอร์ชัน n เป็น n + 1
local MIGRATIONS: { [number]: (any) -> any } = {}

type Profile = { data: any, loaded: boolean }

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

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

local function keyFor(player: Player): string
	return `u_{player.UserId}`
end

local function onLoadFailed(player: Player)
	profiles[player] = { data = deepCopy(DEFAULT), loaded = false }
	if RunService:IsStudio() then
		warn("[PlayerData] ใช้ข้อมูลชั่วคราวและจะไม่บันทึก (เปิด Game Settings > Security > Enable Studio Access to API Services เพื่อทดสอบ DataStore จริง)")
	else
		player:Kick("โหลดข้อมูลไม่สำเร็จ กรุณาเข้าเกมใหม่อีกครั้ง")
	end
end

local function load(player: Player)
	if not store then
		onLoadFailed(player)
		return
	end
	local activeStore = store :: DataStore
	local ok, stored = withRetry(`load {player.UserId}`, function()
		return activeStore:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return
	end
	if not ok then
		onLoadFailed(player)
		return
	end
	if type(stored) ~= "table" then
		profiles[player] = { data = deepCopy(DEFAULT), loaded = true }
		return
	end
	if type(stored.Version) == "number" and stored.Version > VERSION then
		warn(`[PlayerData] ข้อมูลของ {player.UserId} ใหม่กว่าเซิร์ฟเวอร์นี้ (v{stored.Version}) — จะไม่บันทึกทับ`)
		onLoadFailed(player)
		return
	end
	local data = migrate(stored)
	reconcile(data, DEFAULT, `u_{player.UserId}`)
	profiles[player] = { data = data, loaded = true }
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not profile.loaded or not store then
		return
	end
	local activeStore = store :: DataStore
	local snapshot = deepCopy(profile.data)
	withRetry(`save {player.UserId}`, function()
		activeStore:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
end

local PlayerData = {}

-- คืนข้อมูลของผู้เล่น (อ่านอย่างเดียว) หรือ nil ถ้ายังโหลดไม่เสร็จ
function PlayerData.get(player: Player): any?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

-- แก้ข้อมูลผ่าน callback · คืน false ถ้ายังไม่มีข้อมูลของผู้เล่นคนนี้
function PlayerData.update(player: Player, callback: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	callback(profile.data)
	return true
end

-- รอจนข้อมูลพร้อม (คืน nil ถ้าผู้เล่นออกก่อน)
function PlayerData.waitFor(player: Player): any?
	while not profiles[player] and player.Parent do
		task.wait()
	end
	return PlayerData.get(player)
end

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
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)

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

function PlayerData.Start()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player in profiles do
			task.spawn(save, player)
		end
	end
end

return PlayerData
