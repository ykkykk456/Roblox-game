-- ด่านตรวจของทุก Remote (เจ้าของ: Networking_Specialist)
-- ตรวจให้อัตโนมัติ: rate limit ต่อผู้เล่นต่อ Remote + ชนิดข้อมูล + จำนวน argument + NaN/inf + ความยาว string
-- handler ยังต้องตรวจ "ช่วงค่า" และ "สิทธิ์" เอง (ใช้ Guard.inRange / Guard.isInteger ช่วย)
--
-- ตัวอย่าง:
--   Guard.connect(Remotes.get("BuyItem"), { rate = 5, per = 1, args = { "string" } }, function(player, itemId)
--       local item = Economy.Items[itemId]
--       if not item then return end -- สิทธิ์/ความเป็นไปได้
--       ...
--   end)
--
-- ชนิดใน args ใช้ชื่อจาก typeof() เช่น "number", "string", "boolean", "Vector3", "Instance"
-- เติม "?" ท้ายชื่อเพื่อยอมให้เป็น nil ได้ เช่น "number?"
--
-- ห้ามแก้ (กฎเหล็กข้อ 1 Server Authority):
--   • ทุก Remote ในเกมต้องต่อผ่าน Guard.connect / Guard.bind เท่านั้น ห้ามใช้ OnServerEvent/OnServerInvoke ตรงๆ
--   • ถ้าคำขอไม่ผ่าน Guard จะ "เงียบ" (ไม่เรียก handler ไม่ตอบ error) — ตั้งใจ ไม่ใช่บั๊ก
-- อยากเปลี่ยนความถี่ของ Remote ตัวใดตัวหนึ่ง → แก้ rate/per ในไฟล์ handler ของ Remote นั้น (เช่น GearHandler) ไม่ใช่ที่นี่
-- คุยกับ: ไฟล์ *Handler ทุกตัวใน Network/ เรียกใช้โมดูลนี้

local Players = game:GetService("Players")

type Options = {
	rate: number?, -- จำนวนครั้งสูงสุดต่อช่วงเวลา (ค่าเริ่มต้น 10)
	per: number?, -- ความยาวช่วงเวลาเป็นวินาที (ค่าเริ่มต้น 1)
	args: { string }?, -- ชนิดของแต่ละ argument (ค่าเริ่มต้น: ห้ามส่ง argument)
}

-- ===== ค่าคงที่ =====
-- ใช้เมื่อ handler ไม่ได้ระบุ rate/per เอง: 10 ครั้งต่อ 1 วินาที (ปรับได้ แต่กระทบทุก Remote ที่ไม่ได้ระบุ)
local DEFAULT_RATE = 10
local DEFAULT_PER = 1
-- string ยาวเกินนี้ถูกปฏิเสธ (กันส่งข้อความยาวมหาศาลมาถ่วงเซิร์ฟ) · ปรับได้ถ้ามีช่องพิมพ์ข้อความยาว
local MAX_STRING_LENGTH = 200

-- ===== Rate limit =====
-- ตัวนับ: buckets[ผู้เล่น][ชื่อ Remote] = { นับไปกี่ครั้ง, เริ่มช่วงเวลานี้เมื่อไร }
local buckets: { [Player]: { [string]: { count: number, windowStart: number } } } = {}

-- ผู้เล่นออก → ลบตัวนับทิ้ง กันหน่วยความจำรั่ว
Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- คืน true ถ้าผู้เล่นยังเรียก Remote ชื่อ key ได้อีก (ไม่เกิน rate ครั้งในทุก per วินาที)
-- แบบ "หน้าต่างคงที่": พอครบ per วินาทีนับจากครั้งแรก ตัวนับรีเซ็ตเป็น 1
local function allow(player: Player, key: string, rate: number, per: number): boolean
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[key]
	if not bucket or now - bucket.windowStart >= per then
		perPlayer[key] = { count = 1, windowStart = now }
		return true
	end
	if bucket.count >= rate then
		return false
	end
	bucket.count += 1
	return true
end

-- ===== ตรวจชนิดข้อมูล =====
-- คืน true ถ้า value ตรงกับชนิด expected (เช่น "number", "string?") และค่าปลอดภัย
local function matches(value: any, expected: string): boolean
	local optional = string.sub(expected, -1) == "?"
	local typeName = if optional then string.sub(expected, 1, -2) else expected
	if value == nil then
		return optional
	end
	if typeof(value) ~= typeName then
		return false
	end
	if typeName == "number" then
		-- value == value ตัด NaN ออก · และห้ามเป็นอนันต์ (โกงด้วย 1/0 ได้)
		return value == value and value ~= math.huge and value ~= -math.huge
	end
	if typeName == "string" then
		return #value <= MAX_STRING_LENGTH
	end
	return true
end

local Guard = {}

-- ตรวจ argument ทั้งชุด: ห้ามส่งมาเกินจำนวนที่ประกาศ และแต่ละตัวต้องตรงชนิด
-- packed มาจาก table.pack(...) (มี .n = จำนวนจริง รวม nil)
function Guard.checkArgs(packed: { n: number, [number]: any }, types: { string }): boolean
	if packed.n > #types then
		return false
	end
	for index, expected in types do
		if not matches(packed[index], expected) then
			return false
		end
	end
	return true
end

-- ===== ตัวช่วยสำหรับ handler =====
-- true ถ้า min <= value <= max
function Guard.inRange(value: number, min: number, max: number): boolean
	return value >= min and value <= max
end

-- true ถ้าเป็นจำนวนเต็ม (ไม่มีทศนิยม) และอยู่ในช่วง min..max
function Guard.isInteger(value: number, min: number, max: number): boolean
	return value % 1 == 0 and value >= min and value <= max
end

-- ===== ผูก Remote =====
-- ผูก RemoteEvent กับ handler โดยตรวจ rate + ชนิดก่อนเสมอ · ไม่ผ่าน = ทิ้งคำขอเงียบๆ
-- เรียกจาก Init() ของไฟล์ *Handler · คืน connection (เผื่ออยาก Disconnect)
function Guard.connect(remote: Instance, options: Options, handler: (Player, ...any) -> ()): RBXScriptConnection
	assert(remote:IsA("RemoteEvent"), `{remote.Name} ไม่ใช่ RemoteEvent`)
	local rate = options.rate or DEFAULT_RATE
	local per = options.per or DEFAULT_PER
	local types = options.args or {}
	local remoteEvent = remote :: RemoteEvent
	return remoteEvent.OnServerEvent:Connect(function(player, ...)
		if not allow(player, remote.Name, rate, per) then
			return
		end
		local packed = table.pack(...)
		if not Guard.checkArgs(packed, types) then
			return
		end
		handler(player, table.unpack(packed, 1, packed.n))
	end)
end

-- ใช้กับ RemoteFunction เท่าที่จำเป็น (คำขอที่ถูกปฏิเสธจะได้ nil กลับไป)
function Guard.bind(remote: Instance, options: Options, handler: (Player, ...any) -> ...any)
	assert(remote:IsA("RemoteFunction"), `{remote.Name} ไม่ใช่ RemoteFunction`)
	local rate = options.rate or DEFAULT_RATE
	local per = options.per or DEFAULT_PER
	local types = options.args or {}
	local remoteFunction = remote :: RemoteFunction
	remoteFunction.OnServerInvoke = function(player, ...)
		if not allow(player, remote.Name, rate, per) then
			return nil
		end
		local packed = table.pack(...)
		if not Guard.checkArgs(packed, types) then
			return nil
		end
		return handler(player, table.unpack(packed, 1, packed.n))
	end
end

return Guard
