-- สกอร์บอร์ดเซิร์ฟเวอร์: "ดาเมจรวม" ของแต่ละคน สะสมทุกรอบบอสตั้งแต่เข้าเซิร์ฟนี้ (เจ้าของ: Gameplay_Scripter)
-- แสดงในรายชื่อผู้เล่นมุมขวาบนของ Roblox (leaderstats) · ไม่บันทึกลง DataStore · ออกเกม = หาย
-- แยกจากตารางซ้ายบน "ดาเมจบอสรอบนี้" ที่รีเซ็ตทุกครั้งที่บอสใหม่มา (ใช้แจกรางวัลตามดาเมจของรอบนั้น · BossService)
--
-- 📖 อ่านตามลำดับนี้
--   1) Init: ผู้เล่นเข้า → สร้าง leaderstats/<STAT_NAME> = 0
--   2) ฟัง Player Attribute "BossDamage" (BossService ตั้งให้ = ดาเมจรอบนี้ของคนนั้น)
--      ค่าเพิ่มขึ้น → บวกส่วนที่เพิ่มเข้าดาเมจรวม · ค่ากลับเป็น 0 (บอสใหม่) → แค่จำค่าใหม่ ไม่ลบดาเมจรวม
-- ⚠️ ไม่แตะ BossService (ล็อก) · อ่านจาก Attribute ที่มันตั้งอยู่แล้วเท่านั้น
-- [Inferred] โฟลเดอร์ชื่อ "leaderstats" ใต้ Player → Roblox แสดงค่าในรายชื่อผู้เล่นให้เอง

local Players = game:GetService("Players")

local STAT_NAME = "ดาเมจรวม" -- ✏️ ชื่อคอลัมน์ในรายชื่อผู้เล่น

local ServerBoardService = {}

local function track(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local total = Instance.new("IntValue")
	total.Name = STAT_NAME
	total.Value = 0
	total.Parent = stats

	local last = 0 -- BossDamage ล่าสุดที่นับไปแล้ว (ของรอบปัจจุบัน)
	player:GetAttributeChangedSignal("BossDamage"):Connect(function()
		local value = player:GetAttribute("BossDamage")
		if type(value) ~= "number" or value ~= value then
			return
		end
		if value > last then
			total.Value += math.floor(value - last)
		end
		last = value -- ค่าลดลง (= รอบใหม่รีเซ็ตเป็น 0) → แค่จำไว้
	end)
end

function ServerBoardService.Init()
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return ServerBoardService
