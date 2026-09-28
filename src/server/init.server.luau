-- จุดเริ่มต้นฝั่ง Server (Script เดียวของฝั่งนี้)
-- โหลดทุก ModuleScript ใน Data/ → Network/ → Services/ แล้วเรียก Init() ทุกตัวก่อน จากนั้นค่อย Start()
-- ไฟล์ใหม่ไม่ต้องลงทะเบียนที่นี่: แค่วางไฟล์ .luau ในโฟลเดอร์และคืนตาราง { Init = fn?, Start = fn? }
--
-- สรุปสำหรับคนแก้โค้ด:
--   • Init()  = ช่วงเตรียมตัว (ต่อ Remote, สร้างของ, ฟัง event) · ทุกโมดูลรันทีละตัวตามลำดับ ห้ามรอนาน (ห้ามวนลูปไม่รู้จบ)
--   • Start() = ช่วงทำงานจริง · แต่ละตัวรันแยกกันด้วย task.spawn จึงวนลูป while true ได้
--   • ถ้าโมดูลไหน require/Init พัง จะขึ้น warn ใน Output แต่โมดูลอื่นยังทำงานต่อ → ดู Output ก่อนเสมอเวลามีอะไรไม่ทำงาน
-- ห้ามแก้: ลำดับ LOAD_ORDER (Data ต้องมาก่อน เพราะ Service อื่นอ่าน PlayerData) และบรรทัด require Remotes ด้านล่าง

-- สร้าง Remote ทั้งหมดก่อนเสมอ ไม่เช่นนั้น Client ที่ require Remotes จะรอค้างตลอดไปถ้าไม่มีโมดูลฝั่ง Server ใช้มัน
require(game:GetService("ReplicatedStorage").Shared.Remotes)

-- ลำดับโฟลเดอร์ที่จะโหลด (ภายในโฟลเดอร์เดียวกัน ลำดับไม่แน่นอน อย่าเขียนโค้ดที่พึ่งลำดับนั้น)
local LOAD_ORDER = { "Data", "Network", "Services" }

-- รายการโมดูลที่ require สำเร็จ: { name = ชื่อเต็ม, module = ตารางที่โมดูลคืนมา }
local modules = {}

-- ===== ขั้น 1: require ทุกโมดูล =====
for _, folderName in LOAD_ORDER do
	local folder = script:FindFirstChild(folderName)
	if not folder then
		continue
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			-- pcall = กันโมดูลที่พังไม่ให้ลากทั้งเซิร์ฟเวอร์พังตาม
			local ok, result = pcall(require, child)
			if ok then
				table.insert(modules, { name = child:GetFullName(), module = result })
			else
				warn(`[Server] require ล้มเหลว {child:GetFullName()}: {result}`)
			end
		end
	end
end

-- ===== ขั้น 2: เรียก Init() ทุกตัว (ทีละตัว รอให้เสร็จก่อนไปตัวถัดไป) =====
for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Init) == "function" then
		local ok, err = pcall(entry.module.Init)
		if not ok then
			warn(`[Server] Init ล้มเหลว {entry.name}: {err}`)
		end
	end
end

-- ===== ขั้น 3: เรียก Start() ทุกตัว (แยกเธรด ทำงานพร้อมกัน) =====
for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Start) == "function" then
		task.spawn(entry.module.Start)
	end
end
