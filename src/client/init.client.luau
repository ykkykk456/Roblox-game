-- จุดเริ่มต้นฝั่ง Client (Script เดียวของฝั่งนี้)
-- โหลดทุก ModuleScript ใน Controllers/ → UI/ แล้วเรียก Init() ทุกตัวก่อน จากนั้นค่อย Start()
-- ไฟล์ใหม่ไม่ต้องลงทะเบียนที่นี่: แค่วางไฟล์ .luau ในโฟลเดอร์และคืนตาราง { Init = fn?, Start = fn? }
-- Init = เตรียมของ (สร้าง UI, ตั้งค่า) · Start = เริ่มทำงาน (ฟัง Remote, วนลูป) — Start เรียกหลัง Init ของทุกไฟล์เสร็จ
-- ⚠️ ปกติไม่ต้องแก้ไฟล์นี้ · Client เป็นแค่ "หน้าจอ + ปุ่ม" ห้ามตัดสินเงิน/ดาเมจ/ไอเทมเอง

-- ลำดับโฟลเดอร์ที่โหลด (Controllers ก่อน เพราะ UI เรียกใช้ Controllers)
local LOAD_ORDER = { "Controllers", "UI" }

local modules = {}

-- ===== ขั้น 1: require ทุก ModuleScript (ไฟล์ไหนพังจะ warn แล้วข้าม ไม่ทำให้ไฟล์อื่นพังตาม) =====
for _, folderName in LOAD_ORDER do
	local folder = script:FindFirstChild(folderName)
	if not folder then
		continue
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, result = pcall(require, child)
			if ok then
				table.insert(modules, { name = child:GetFullName(), module = result })
			else
				warn(`[Client] require ล้มเหลว {child:GetFullName()}: {result}`)
			end
		end
	end
end

-- ===== ขั้น 2: เรียก Init() ของทุกไฟล์ตามลำดับ =====
for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Init) == "function" then
		local ok, err = pcall(entry.module.Init)
		if not ok then
			warn(`[Client] Init ล้มเหลว {entry.name}: {err}`)
		end
	end
end

-- ===== ขั้น 3: เรียก Start() ของทุกไฟล์ (แยก thread กัน ตัวไหนรอนานไม่บล็อกตัวอื่น) =====
for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Start) == "function" then
		task.spawn(entry.module.Start)
	end
end
