-- เจ้าของฐาน: จับคู่ผู้เล่น ↔ ช่องฐานรอบหลุม (เจ้าของ: Gameplay_Scripter)
-- ช่อง = บ้าน+ป้อมจาก Tag ในแมพ (1 คน = 1 บ้าน + 1 ป้อม) · ไม่มี Tag → Map.BaseCount ช่องแบบเดิม
-- ระบบอื่น (ป้อม มอน) ฟัง BaseService.Changed แทนการจับ PlayerAdded เอง
--
-- อยากปรับ:
--   • จำนวนบ้าน/ป้อม (แมพสร้างมือ) → ติด Tag Turret1-6 / House1-6 ในแมพ · สูงสุด Config/Map.luau (Layout.MaxSlots)
--   • จำนวนฐาน (ผังวงกลมเดิม) → src/shared/Config/Map.luau (BaseCount / MaxBases)
-- คุยกับ: LayoutService (อ่านช่องจาก Tag) · MapService (จุดเกิดของแต่ละช่อง) · TurretService/MonsterService ฟัง Changed
-- หมายเหตุ: ผู้เล่นได้ช่องว่างช่องแรกที่เจอ (เรียงเลขน้อยไปมาก) · เต็มแล้ว = ไม่มีบ้าน (มีแค่ warn)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local LayoutService = require(script.Parent.LayoutService)
local MapService = require(script.Parent.MapService)

-- ===== สถานะ =====
-- สองตารางนี้ต้องตรงกันเสมอ: slotOwner[ช่อง] = ผู้เล่น · playerSlot[ผู้เล่น] = ช่อง
local slotOwner: { [number]: Player } = {}
local playerSlot: { [Player]: number } = {}
local changedEvent = Instance.new("BindableEvent")

-- ===== API =====
local BaseService = {}

-- ยิงเมื่อผู้เล่นได้ฐาน (player, slot) หรือเสียฐาน (player, nil)
BaseService.Changed = changedEvent.Event

-- เลขช่องของผู้เล่น หรือ nil ถ้ายังไม่มีบ้าน
function BaseService.slotOf(player: Player): number?
	return playerSlot[player]
end

-- เลขช่องบ้าน/ป้อมทั้งหมด: จาก Tag Turret1-6 ในแมพ · ไม่มี Tag → 1..Map.BaseCount (ผังเดิม)
function BaseService.slots(): { number }
	if LayoutService.hasLayout() then
		return LayoutService.slots()
	end
	local list = {}
	for slot = 1, math.min(Map.BaseCount, Map.MaxBases) do
		table.insert(list, slot)
	end
	return list
end

-- ตาราง [slot] = เจ้าของ (อ่านอย่างเดียว)
function BaseService.owners(): { [number]: Player }
	return slotOwner
end

-- ===== แจก/คืนบ้าน =====
-- ให้ผู้เล่นได้ช่องว่างช่องแรก · ตั้งจุดเกิดใหม่ให้อยู่หน้าบ้าน · ยิง Changed(player, slot)
local function assign(player: Player)
	if playerSlot[player] then
		return
	end
	for _, slot in BaseService.slots() do
		if not slotOwner[slot] then
			slotOwner[slot] = player
			playerSlot[player] = slot
			player.RespawnLocation = MapService.spawnOf(slot)
			changedEvent:Fire(player, slot)
			return
		end
	end
	warn(`[BaseService] บ้านเต็ม ({#BaseService.slots()}) — {player.Name} ยังไม่มีบ้าน`)
end

-- ผู้เล่นออก: คืนช่องให้ว่าง · ยิง Changed(player, nil) ให้ระบบอื่นเก็บป้อม/มอนของช่องนั้น
local function release(player: Player)
	local slot = playerSlot[player]
	if not slot then
		return
	end
	playerSlot[player] = nil
	slotOwner[slot] = nil
	changedEvent:Fire(player, nil)
end

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูกเข้า/ออกเกม และแจกบ้านให้คนที่อยู่แล้ว
function BaseService.Init()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return BaseService
