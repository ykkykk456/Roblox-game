-- Friend Boost: +% รายได้และดาเมจ ตามจำนวนเพื่อนที่อยู่เซิร์ฟเดียวกัน (เจ้าของ: Gameplay_Scripter)
-- Server เช็กความเป็นเพื่อนเองด้วย Player:IsFriendsWith [Verified: API มีอยู่จริง, เรียกเว็บจึง yield ได้]
-- เช็กครั้งเดียวต่อคู่ตอนเข้าเซิร์ฟแล้วจำไว้ [Inferred: ลดการเรียกเว็บ]
-- ค่าที่ได้ส่งให้ Client ดูผ่าน Attribute "FriendBoost" (0–Max) เพื่อแสดงผลเท่านั้น
--
-- อยากปรับ % ต่อเพื่อน / เพดาน → src/shared/Config/Economy.luau (FriendBoost.PerFriend / FriendBoost.Max)
-- คุยกับ: Wallet (คูณเงิน) และระบบดาเมจที่เรียก FriendBoostService.get · UI ฝั่ง Client อ่าน Attribute "FriendBoost"
-- ห้ามแก้: อย่าให้ Client บอกเองว่าใครเป็นเพื่อน (โกงได้) — Server ต้องเช็กเองแบบนี้

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

-- ===== สถานะ =====
-- friendsOf[ผู้เล่น] = ชุดเพื่อนที่อยู่เซิร์ฟเดียวกันตอนนี้ (nil = ออกไปแล้ว/ยังไม่เข้า)
local friendsOf: { [Player]: { [Player]: true } } = {}
-- boostOf[ผู้เล่น] = โบนัสที่คำนวณแล้ว (เช่น 0.2 = +20%)
local boostOf: { [Player]: number } = {}

-- ===== คำนวณโบนัส =====
-- นับเพื่อนของผู้เล่นแล้วคำนวณโบนัสใหม่ (จำนวนเพื่อน × PerFriend ไม่เกิน Max) · ตั้ง Attribute ให้ UI ด้วย
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

-- ถามเว็บ Roblox ว่า a กับ b เป็นเพื่อนกันไหม · ใช่ → จดทั้งสองฝั่งแล้วคำนวณโบนัสใหม่ทั้งคู่
-- ถูกเรียกด้วย task.spawn เพราะรอเว็บได้นาน · เว็บพัง (pcall ไม่ผ่าน) = ถือว่าไม่ใช่เพื่อน
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

-- ผู้เล่นเข้าเกม: สร้างชุดเพื่อนว่าง แล้วเช็กกับทุกคนที่อยู่ในเซิร์ฟแล้ว (แต่ละคู่แยกเธรด)
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

-- ===== API =====
local FriendBoostService = {}

-- ตัวคูณเพิ่มเติม (0 = ไม่มีโบนัส, 0.2 = +20%)
function FriendBoostService.get(player: Player): number
	return boostOf[player] or 0
end

-- เรียกตอนเซิร์ฟเวอร์เริ่ม · ผูกเข้า/ออกเกม
-- ตอนออก: ลบตัวเองออกจากชุดเพื่อนของคนอื่น แล้วคำนวณโบนัสของพวกเขาใหม่ (โบนัสลดลง)
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
