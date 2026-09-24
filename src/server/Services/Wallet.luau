-- จุดเดียวที่ "ให้เงิน" ผู้เล่น (เจ้าของ: Gameplay_Scripter)
-- ทุกระบบที่ให้รางวัลเรียก Wallet.earn → ใช้ Friend Boost และเพดาน MaxCoins ชุดเดียวกันเสมอ
-- โมดูล helper: ไม่มี Init/Start

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local FriendBoostService = require(script.Parent.FriendBoostService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local Wallet = {}

-- ให้รายได้ (คูณ Friend Boost แล้ว ปัดลง ขั้นต่ำ 1) · คืนจำนวนที่เพิ่มจริง
function Wallet.earn(player: Player, baseAmount: number): number
	if baseAmount ~= baseAmount or baseAmount <= 0 or not player.Parent then
		return 0
	end
	local amount = math.max(1, math.floor(baseAmount * (1 + FriendBoostService.get(player))))
	local granted = 0
	PlayerData.update(player, function(data)
		local before = data.Coins
		data.Coins = math.min(before + amount, Economy.MaxCoins)
		granted = data.Coins - before
	end)
	return granted
end

return Wallet
