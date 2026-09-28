-- จุดเดียวที่ "ให้เงิน" ผู้เล่น (เจ้าของ: Gameplay_Scripter)
-- ทุกระบบที่ให้รางวัลเรียก Wallet.earn → ใช้ Friend Boost และเพดาน MaxCoins ชุดเดียวกันเสมอ
-- โมดูล helper: ไม่มี Init/Start
--
-- อยากปรับ:
--   • เพดานเงินสูงสุด → src/shared/Config/Economy.luau (MaxCoins)
--   • โบนัสเพื่อน → src/shared/Config/Economy.luau (FriendBoost.PerFriend / Max)
-- คุยกับ: FriendBoostService (อ่าน % โบนัส) · Data/PlayerData (เขียน Coins)
-- ห้ามแก้: ระบบใหม่ที่ให้เงินต้องเรียก Wallet.earn อย่าไปบวก data.Coins เองที่อื่น (จะหลุดเพดาน/โบนัส)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local FriendBoostService = require(script.Parent.FriendBoostService)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local Wallet = {}

-- ให้รายได้ (คูณ Friend Boost แล้ว ปัดลง ขั้นต่ำ 1) · คืนจำนวนที่เพิ่มจริง
-- ถ้าชนเพดาน MaxCoins ค่าที่คืนจะน้อยกว่าที่ขอ · คืน 0 ถ้าค่าไม่ถูกต้องหรือผู้เล่นออกไปแล้ว
function Wallet.earn(player: Player, baseAmount: number): number
	-- baseAmount ~= baseAmount = เช็ก NaN (NaN เป็นค่าเดียวที่ไม่เท่ากับตัวเอง) · player.Parent == nil = ออกเกมแล้ว
	if baseAmount ~= baseAmount or baseAmount <= 0 or not player.Parent then
		return 0
	end
	-- FriendBoostService.get คืนค่าเป็นสัดส่วน เช่น 0.2 = +20%
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
