-- จุดเริ่มต้นฝั่ง Server (Script เดียวของฝั่งนี้)
-- โหลดทุก ModuleScript ใน Data/ → Network/ → Services/ แล้วเรียก Init() ทุกตัวก่อน จากนั้นค่อย Start()
-- ไฟล์ใหม่ไม่ต้องลงทะเบียนที่นี่: แค่วางไฟล์ .luau ในโฟลเดอร์และคืนตาราง { Init = fn?, Start = fn? }

-- สร้าง Remote ทั้งหมดก่อนเสมอ ไม่เช่นนั้น Client ที่ require Remotes จะรอค้างตลอดไปถ้าไม่มีโมดูลฝั่ง Server ใช้มัน
require(game:GetService("ReplicatedStorage").Shared.Remotes)

local LOAD_ORDER = { "Data", "Network", "Services" }

local modules = {}

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
				warn(`[Server] require ล้มเหลว {child:GetFullName()}: {result}`)
			end
		end
	end
end

for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Init) == "function" then
		local ok, err = pcall(entry.module.Init)
		if not ok then
			warn(`[Server] Init ล้มเหลว {entry.name}: {err}`)
		end
	end
end

for _, entry in modules do
	if type(entry.module) == "table" and type(entry.module.Start) == "function" then
		task.spawn(entry.module.Start)
	end
end
