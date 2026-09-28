-- สคริปต์ช่วยจัดบอส Slambot ใน Roblox Studio (ใช้ครั้งเดียว ไม่เข้าเกม)
-- วิธีใช้: Studio → แท็บ View → Command Bar → คัดลอกทั้งไฟล์นี้ไปวาง → กด Enter → ดูผลในหน้าต่าง Output
-- สิ่งที่ทำ:
--   1. สร้างโฟลเดอร์ ServerStorage > Bosses (ถ้ายังไม่มี)
--   2. หาโมเดลชื่อ Slambot ใน Workspace แล้วย้ายเข้า Bosses (ถ้าอยู่ใน Bosses แล้วไม่ทำอะไร)
--   3. ตรวจริก R15: Humanoid, HumanoidRootPart, ชิ้นส่วน 15 ชิ้น, ข้อต่อ Motor6D, สคริปต์แฝง
--   4. สร้างโฟลเดอร์ Slambot > Animations พร้อม Animation 3 ตัว (Idle, Walk, Slam) ให้ใส่ AnimationId
-- เสร็จแล้วกด Ctrl + S เพื่อบันทึก (Rojo ไม่บันทึก ServerStorage ให้)
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม ต้องคัดลอกไปวางเองทุกครั้ง · รันซ้ำได้ (ของที่มีแล้วจะไม่สร้างซ้ำ)
-- ⚠️ บอส Slambot ถูกล็อกไว้: อ่าน docs/boss-slambot-known-good.md ก่อนแก้สคริปต์นี้หรือตัวโมเดล
--   ห้ามแก้ให้ต่างจากเดิม ยกเว้นเพิ่มท่าทาง (เพิ่มชื่อใน ANIMATIONS ด้านล่าง)

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ===== ค่าคงที่ =====
local MODEL_NAME = "boss_slambot" -- ชื่อโมเดลที่ Import จาก boss_slambot.fbx
-- ชื่อชิ้นส่วนที่ริก R15 ต้องมี (ขาดชิ้นไหน = แจ้ง ❌)
local PARTS = {
	"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- ข้อต่อมาตรฐาน R15: ชื่อข้อต่อ → ชิ้นที่ข้อต่อนั้นอยู่ข้างใน
local JOINTS = {
	Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot",
}
-- ชื่อท่าที่จะสร้างช่องรอใส่ AnimationId · เพิ่มท่าใหม่ได้โดยเพิ่มชื่อในรายการนี้
local ANIMATIONS = { "Idle", "Walk", "Slam" }

-- problems = นับปัญหา · ok() พิมพ์บรรทัดสีปกติ · bad() พิมพ์บรรทัดสีแดงและนับปัญหา
local problems = 0
local function ok(text) print("✅ " .. text) end
local function bad(text)
	problems += 1
	warn("❌ " .. text)
end

-- บันทึกเป็นขั้นเดียว กด Ctrl + Z ย้อนได้ (ถ้า Studio รุ่นนี้ไม่รองรับก็ข้าม)
local _, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Setup Slambot")
end)

-- ===== ขั้น 1: โฟลเดอร์ ServerStorage > Bosses =====
local bosses = ServerStorage:FindFirstChild("Bosses")
if not bosses then
	bosses = Instance.new("Folder")
	bosses.Name = "Bosses"
	bosses.Parent = ServerStorage
	ok("สร้างโฟลเดอร์ ServerStorage > Bosses แล้ว")
end

-- ชื่อแบบยืดหยุ่น: "Slambot", "Slam-Bot", "boss_slambot" ถือว่าเป็นตัวเดียวกัน
local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end
-- หาโมเดลบอส (ชื่อตรงแบบยืดหยุ่น + มี HumanoidRootPart) ในทุกชั้นของ container · ไม่เจอ = nil
local function findIn(container)
	for _, item in container:GetDescendants() do
		if item:IsA("Model") and simple(item.Name) == simple(MODEL_NAME)
			and item:FindFirstChild("HumanoidRootPart", true) then
			return item
		end
	end
	return nil
end

-- ===== ขั้น 2: ย้ายโมเดลเข้า Bosses และตั้งชื่อให้ตรง =====
local model = findIn(bosses)
local inWorkspace = findIn(workspace)
if not model and inWorkspace then
	inWorkspace.Parent = bosses
	model = inWorkspace
	ok("ย้าย " .. inWorkspace.Name .. " จาก Workspace เข้า ServerStorage > Bosses แล้ว (บอสจะโผล่เฉพาะตอนบอสมา)")
elseif model and inWorkspace then
	bad("มีโมเดลบอสทั้งใน Workspace (" .. inWorkspace:GetFullName() .. ") และใน Bosses — ลบตัวใน Workspace ทิ้ง")
end
if model and model.Name ~= MODEL_NAME then
	ok("ตั้งชื่อ " .. model.Name .. " → " .. MODEL_NAME .. " ให้ตรงกับ Config")
	model.Name = MODEL_NAME
end

-- ===== ขั้น 3: ตรวจริก =====
if not model then
	bad("ไม่เจอโมเดลชื่อ " .. MODEL_NAME .. " ที่มี HumanoidRootPart ทั้งใน Workspace และ ServerStorage > Bosses")
elseif not model:IsA("Model") then
	bad(MODEL_NAME .. " ต้องเป็น Model (ตอนนี้เป็น " .. model.ClassName .. ")")
else
	ok("เจอโมเดล " .. model:GetFullName())

	if model:FindFirstChildWhichIsA("Humanoid", true) then
		ok("มี Humanoid")
	else
		print("ℹ️ ไม่มี Humanoid — ไม่เป็นไร เกมใช้ AnimationController เล่นท่าแทน")
	end

	for _, name in PARTS do
		local part = model:FindFirstChild(name, true)
		if not part or not part:IsA("BasePart") then
			bad("ไม่เจอชิ้นส่วน " .. name .. " (ชื่อต้องตรงตัวอักษรทุกตัว)")
		end
	end

	-- ข้อต่อที่ขาดแค่แจ้งเป็นข้อมูล (ไม่นับเป็นปัญหา) เพราะเกมซ่อมเองตอนบอสเกิด
	local missingJoints = 0
	for joint, partName in JOINTS do
		local part = model:FindFirstChild(partName, true)
		local motor = part and part:FindFirstChild(joint)
		if part and not (motor and motor:IsA("Motor6D")) then
			missingJoints += 1
			print("ℹ️ ไม่เจอข้อต่อ Motor6D ชื่อ " .. joint .. " ใน " .. partName)
		end
	end
	if missingJoints > 0 then
		print("ℹ️ ขาดข้อต่อ " .. missingJoints .. " จุด — ไม่ต้องแก้เอง เกมจะซ่อมให้ตอนบอสเกิด (ถ้าไม่ซ่อม ตัวจะร่วงทะลุแมพ)")
	end

	local root = model:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		root.Transparency = 1
		root.Anchored = true
		ok("ซ่อน HumanoidRootPart (บล็อกสีเข้มในตัว) และยึดไว้ไม่ให้ร่วง")
	end

	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") then
			bad("เจอสคริปต์แฝง " .. item:GetFullName() .. " (เกมจะลบให้ตอนบอสเกิด แต่ควรลบทิ้งเอง)")
		end
	end

	-- AnimSaves = ที่ Animation Editor เก็บท่าที่ทำไว้ (แค่แสดงรายชื่อ ไม่แก้อะไร)
	local saves = model:FindFirstChild("AnimSaves")
	if saves then
		local names = {}
		for _, item in saves:GetChildren() do
			table.insert(names, item.Name)
		end
		ok("ท่าที่ทำไว้ใน Animation Editor (AnimSaves): " .. table.concat(names, ", "))
	else
		print("ℹ️ ไม่เจอ AnimSaves ในโมเดล (ท่าที่ทำไว้อาจเก็บที่อื่น — ไม่เป็นไร ถ้า Publish แล้วได้เลข ID)")
	end

	-- ===== ขั้น 4: โฟลเดอร์ Animations + ช่อง Animation ของแต่ละท่า =====
	local folder = model:FindFirstChild("Animations")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Animations"
		folder.Parent = model
	end
	for _, name in ANIMATIONS do
		local animation = folder:FindFirstChild(name)
		if not animation then
			animation = Instance.new("Animation")
			animation.Name = name
			animation.Parent = folder
		end
		if animation.AnimationId == "" then
			print("⏳ ท่า " .. name .. ": ยังไม่มี ID → คลิก " .. animation:GetFullName() .. " แล้วใส่เลขในช่อง AnimationId (หน้าต่าง Properties)")
		else
			ok("ท่า " .. name .. ": " .. animation.AnimationId)
		end
	end
end

-- ===== จบ: ปิดการบันทึกประวัติ (Ctrl + Z) และสรุปผล =====
if recording then
	pcall(function()
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end)
end
print(if problems == 0
	then "🎉 เสร็จ ไม่พบปัญหา — กด Ctrl + S เพื่อบันทึก"
	else "⚠️ พบปัญหา " .. problems .. " ข้อ (บรรทัดสีแดงด้านบน) — แก้แล้วรันสคริปต์นี้ซ้ำได้")
