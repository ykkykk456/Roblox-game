-- เจ้าของฐาน: จับคู่ผู้เล่น ↔ ช่องฐานรอบหลุม (เจ้าของ: Gameplay_Scripter)
-- มี Map.BaseCount ช่อง · ผู้เล่นเกินจำนวนช่องยังไม่ได้ฐาน/ป้อม (prototype สร้างฐานเดียวก่อน)
-- ระบบอื่น (ป้อม มอน) ฟัง BaseService.Changed แทนการจับ PlayerAdded เอง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Map = require(ReplicatedStorage.Shared.Config.Map)
local MapService = require(script.Parent.MapService)

local slotOwner: { [number]: Player } = {}
local playerSlot: { [Player]: number } = {}
local changedEvent = Instance.new("BindableEvent")

local BaseService = {}

-- ยิงเมื่อผู้เล่นได้ฐาน (player, slot) หรือเสียฐาน (player, nil)
BaseService.Changed = changedEvent.Event

function BaseService.slotOf(player: Player): number?
	return playerSlot[player]
end

-- ตาราง [slot] = เจ้าของ (อ่านอย่างเดียว)
function BaseService.owners(): { [number]: Player }
	return slotOwner
end

local function assign(player: Player)
	if playerSlot[player] then
		return
	end
	for slot = 1, math.min(Map.BaseCount, Map.MaxBases) do
		if not slotOwner[slot] then
			slotOwner[slot] = player
			playerSlot[player] = slot
			player.RespawnLocation = MapService.spawnOf(slot)
			changedEvent:Fire(player, slot)
			return
		end
	end
	warn(`[BaseService] ฐานเต็ม ({Map.BaseCount}) — {player.Name} ยังไม่มีฐาน`)
end

local function release(player: Player)
	local slot = playerSlot[player]
	if not slot then
		return
	end
	playerSlot[player] = nil
	slotOwner[slot] = nil
	changedEvent:Fire(player, nil)
end

function BaseService.Init()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return BaseService
