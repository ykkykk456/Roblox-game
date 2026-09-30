-- ส่งคำขออุปกรณ์ป้อมไป Server (เจ้าของ: Client_UI_Scripter) · สเปก: design/equipment.md หัวข้อ 14 "สัญญากับ Client"
-- Client ส่งแค่ "เจตนา" (id ชิ้น / ชื่อช่อง / ระดับ / จำนวน) · Server ตรวจกฎทั้งหมดเอง (ของมีจริงไหม เงินพอไหม บอสอยู่ไหม)
-- แล้วตั้ง Attribute Gear / GearSlots / GearBonus / Coins กลับมา — UI อ่านผลจาก Attribute เท่านั้น ไม่ถือว่าสำเร็จเอง
-- คำขอผิดกฎ Server จะ "เงียบ" (ไม่ตอบ error) → UI ต้องทำปุ่มเทาเองก่อนส่ง (ดู UI/GearUI)
-- ใครใช้: UI/GearUI · ตัวรับฝั่ง Server: src/server/Network/GearHandler.luau (ผ่าน Guard + rate limit)
--
-- 📖 อ่านตามลำดับนี้ (เส้นทางของคำขอ 1 ครั้ง):
--   1) ผู้เล่นกดปุ่มใน UI/GearUI (ใส่ / ถอด / ปลดช่อง / ย่อย / รวม)
--   2) GearUI เรียกฟังก์ชันในไฟล์นี้ เช่น GearController.equip("Barrel_Fire_Rare")
--   3) ตรวจรูปแบบค่าเบื้องต้น (กันส่งค่าเสียเปล่าๆ) + กันกดรัว (MIN_INTERVAL) → fire() ส่งผ่าน RemoteEvent
--   4) Server: Network/GearHandler → Services/GearService · ผ่าน → ตั้ง Attribute ใหม่ → GearUI วาดใหม่
--   5) บอสจากไป Server ยิง GearDrops กลับมา → onDrops(callback) ส่งต่อให้ GearUI โชว์ป๊อปอัป
-- ⚠️ ระวัง: ไฟล์นี้ห้ามตั้ง Attribute เอง/ห้ามเดาผล — การตรวจที่นี่เป็นแค่ "กันส่งค่าขยะ" ไม่ใช่ความปลอดภัย (Server ตรวจซ้ำเสมอ)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- ✏️ แก้ตรงนี้ถ้าอยาก: เวลาขั้นต่ำระหว่างคำขอชนิดเดียวกัน (วินาที) · ต่ำกว่า rate ของ Server (1–5 ครั้ง/วิ) เล็กน้อยก็พอ
local MIN_INTERVAL = 0.25

-- เวลาที่ส่งคำขอแต่ละ Remote ล่าสุด (os.clock)
local lastSent: { [string]: number } = {}

local GearController = {}

-- ส่งคำขอผ่าน Remote ชื่อ name · กดรัวเร็วกว่า MIN_INTERVAL = ไม่ส่ง (คืน false)
local function fire(name: string, ...: any): boolean
	local now = os.clock()
	if now - (lastSent[name] or -math.huge) < MIN_INTERVAL then
		return false
	end
	lastSent[name] = now
	local remote = Remotes.get(name) :: RemoteEvent
	remote:FireServer(...)
	return true
end

-- ใส่ชิ้น key ในช่องของมัน (ห้ามระหว่างบอส · Server ตรวจ) · key = "<ช่อง>_<แบบ>_<ระดับ>"
function GearController.equip(key: string): boolean
	if not GearMath.isKey(key) then
		return false
	end
	return fire("EquipGear", key)
end

-- ถอดชิ้นในช่อง slot เช่น "Core" (ห้ามระหว่างบอส)
function GearController.unequip(slot: string): boolean
	if GearMath.slotIndex(slot) == nil then
		return false
	end
	return fire("UnequipGear", slot)
end

-- เปิดช่องถัดไปด้วยเหรียญ (ราคา = GearMath.nextSlotPrice)
function GearController.unlockSlot(): boolean
	return fire("UnlockGearSlot")
end

-- ย่อย key จำนวน count ชิ้นเป็นเหรียญ · count ต้องเป็นจำนวนเต็ม 1..StackCap
function GearController.salvage(key: string, count: number): boolean
	if not GearMath.isKey(key) or type(count) ~= "number" or count % 1 ~= 0 then
		return false
	end
	if count < 1 or count > Equipment.StackCap then
		return false
	end
	return fire("SalvageGear", key, count)
end

-- ย่อยทุกชิ้นที่ไม่ได้ใส่ของระดับ rarity ("Common"/"Rare"/"Epic" · Server ไม่รับ "Legendary")
function GearController.salvageRarity(rarity: string): boolean
	if GearMath.rarityIndex(rarity) == nil or rarity == "Legendary" then
		return false
	end
	return fire("SalvageRarity", rarity)
end

-- รวม 3 ชิ้น key (ที่ไม่ได้ใส่) → 1 ชิ้นระดับถัดไป (เสียเหรียญ GearMath.mergeCost)
function GearController.merge(key: string): boolean
	if not GearMath.isKey(key) then
		return false
	end
	return fire("MergeGear", key)
end

-- ฟังของที่ได้จากบอส (Server → Client · แสดงผลเท่านั้น) · callback(list) · คืน connection
-- list = { { Key: string, New: boolean, Salvaged: number?, Top: boolean? } } (ยังไม่ตรวจ → ผู้ใช้ต้องตรวจเอง)
function GearController.onDrops(callback: (any) -> ()): RBXScriptConnection
	local remote = Remotes.get("GearDrops") :: RemoteEvent
	return remote.OnClientEvent:Connect(callback)
end

return GearController
