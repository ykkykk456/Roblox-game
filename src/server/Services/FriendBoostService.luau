-- Friend Boost: +% รายได้และดาเมจ ตามจำนวนเพื่อนที่อยู่เซิร์ฟเดียวกัน (เจ้าของ: Gameplay_Scripter)
-- Server เช็กความเป็นเพื่อนเองด้วย Player:IsFriendsWith [Verified: API มีอยู่จริง, เรียกเว็บจึง yield ได้]
-- เช็กครั้งเดียวต่อคู่ตอนเข้าเซิร์ฟแล้วจำไว้ [Inferred: ลดการเรียกเว็บ]
-- ค่าที่ได้ส่งให้ Client ดูผ่าน Attribute "FriendBoost" (0–Max) เพื่อแสดงผลเท่านั้น

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local friendsOf: { [Player]: { [Player]: true } } = {}
local boostOf: { [Player]: number } = {}

local function refresh(player: Player)
	local set = friendsOf[player]
	if not set then
		return
	end
	local count = 0
	for _ in set do
		count += 1
	end
	local boost = math.min(count * Economy.FriendBoost.PerFriend, Economy.FriendBoost.Max)
	boostOf[player] = boost
	player:SetAttribute("FriendBoost", boost)
end

local function checkPair(a: Player, b: Player)
	local ok, isFriend = pcall(a.IsFriendsWith, a, b.UserId)
	-- ระหว่างรอผล อาจมีคนออกไปแล้ว
	if not ok or not isFriend or not friendsOf[a] or not friendsOf[b] then
		return
	end
	friendsOf[a][b] = true
	friendsOf[b][a] = true
	refresh(a)
	refresh(b)
end

local function onPlayerAdded(player: Player)
	if friendsOf[player] then
		return
	end
	friendsOf[player] = {}
	refresh(player)
	for _, other in Players:GetPlayers() do
		if other ~= player and friendsOf[other] then
			task.spawn(checkPair, player, other)
		end
	end
end

local FriendBoostService = {}

-- ตัวคูณเพิ่มเติม (0 = ไม่มีโบนัส, 0.2 = +20%)
function FriendBoostService.get(player: Player): number
	return boostOf[player] or 0
end

function FriendBoostService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local set = friendsOf[player]
		friendsOf[player] = nil
		boostOf[player] = nil
		if set then
			for other in set do
				local otherSet = friendsOf[other]
				if otherSet then
					otherSet[player] = nil
					refresh(other)
				end
			end
		end
	end)
end

return FriendBoostService
