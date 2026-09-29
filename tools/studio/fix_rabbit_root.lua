-- ซ่อมตัวรากของบอส Boss_rabbit ใน Roblox Studio (ใช้ในหน้าแก้งาน ไม่เข้าเกม)
-- ปัญหา: โมเดลจาก FBX มี HumanoidRootPart 2 อัน · อันหนึ่งเป็นกล่องเปล่าที่ไม่ต่อกับข้อต่อไหนเลย
--   ถ้า Humanoid / Animation Editor ไปใช้กล่องเปล่าเป็นราก → ท่า Motion Capture คำนวณทุกชิ้นจากกล่องผิด
--   → แขนขา "ดูด" เข้าหากล่อง / เท้าลอย [Inferred]
-- วิธีใช้: กด Stop ก่อน → คลิกเลือก Boss_rabbit ใน Explorer (ไม่เลือก = หาชื่อ Boss_rabbit ให้เอง)
--   → View → Command Bar → วางทั้งไฟล์นี้ → Enter → ดู Output → Ctrl + S
-- สิ่งที่ทำ (Ctrl + Z ย้อนได้ทั้งหมด):
--   1. หา HumanoidRootPart ทุกอัน · ตัวรากจริง = อันที่ต่อกับชิ้นอื่นมากที่สุด (วิธีเดียวกับ BossService.connectedToRoot)
--   2. อันที่ไม่ใช่ตัวรากจริง → เปลี่ยนชื่อเป็น UnusedRootBox, ซ่อน, ไม่มีน้ำหนัก, เชื่อมติดตัวรากจริง (ไม่ลบทิ้ง)
--   3. ย้ายตัวรากจริงให้อยู่ระดับเดียวกับ Humanoid (Humanoid หาตัวรากจากชื่อ HumanoidRootPart ข้างๆ ตัวมัน [Inferred])
--   4. ตั้ง PrimaryPart = ตัวรากจริง · ยึดตัวรากจริงอย่างเดียว ชิ้นอื่นปลด Anchored (ทำท่าได้)
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม · ใช้กับ Boss_rabbit เท่านั้น (Slambot ถูกล็อก ดู docs/boss-slambot-known-good.md)

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local NAME = "Boss_rabbit"

local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

local function findModel()
	for _, item in Selection:Get() do
		local model = if item:IsA("Model") then item else item:FindFirstAncestorOfClass("Model")
		if model and simple(model.Name) == simple(NAME) then
			return model
		end
	end
	for _, container in { workspace, ServerStorage } do
		for _, item in container:GetDescendants() do
			if item:IsA("Model") and simple(item.Name) == simple(NAME) then
				return item
			end
		end
	end
	return nil
end

local model = findModel()
if not model then
	warn(`❌ ไม่เจอโมเดล {NAME} — คลิกเลือกโมเดลใน Explorer แล้วรันใหม่`)
	return
end
if simple(model.Name) == simple("boss_slambot") then
	warn("❌ นี่คือ Slambot (ถูกล็อก) — สคริปต์นี้ใช้กับ Boss_rabbit เท่านั้น")
	return
end

-- ===== กราฟข้อต่อ (เหมือน BossService.connectedToRoot) =====
local links = {}
local function link(a, b)
	if typeof(a) == "Instance" and typeof(b) == "Instance" and a:IsA("BasePart") and b:IsA("BasePart") then
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], b)
		table.insert(links[b], a)
	end
end
for _, item in model:GetDescendants() do
	if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
		link(item.Part0, item.Part1)
	elseif item:IsA("Constraint") and item.Attachment0 and item.Attachment1 then
		link(item.Attachment0.Parent, item.Attachment1.Parent)
	end
end
local function countConnected(root)
	local seen, queue, n = { [root] = true }, { root }, 0
	while #queue > 0 do
		local part = table.remove(queue)
		for _, other in links[part] or {} do
			if not seen[other] then
				seen[other] = true
				n += 1
				table.insert(queue, other)
			end
		end
	end
	return n
end

-- ===== หาตัวรากจริง =====
local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
print(`--- {model:GetFullName()} ---`)
print("ก่อนแก้: Humanoid.RootPart =", humanoid and humanoid.RootPart and humanoid.RootPart:GetFullName() or "ไม่มี")
local roots, real, best = {}, nil, -1
for _, item in model:GetDescendants() do
	if item:IsA("BasePart") and item.Name == "HumanoidRootPart" then
		local n = countConnected(item)
		table.insert(roots, item)
		print(`  HumanoidRootPart: {item:GetFullName()} · ต่อกับ {n} ชิ้น · ขนาด {item.Size}`)
		if n > best then
			real, best = item, n
		end
	end
end
if not real then
	warn("❌ ไม่มี HumanoidRootPart ในโมเดลนี้")
	return
end
print(`✅ ตัวรากจริง = {real:GetFullName()} (ต่อกับ {best} ชิ้น)`)

-- ===== แก้ (บันทึกประวัติให้ Ctrl + Z ย้อนได้) =====
local _, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Fix Boss_rabbit root")
end)

for _, box in roots do
	if box ~= real then
		box.Name = "UnusedRootBox"
		box.Transparency = 1
		box.CanCollide = false
		box.CanTouch = false
		box.CanQuery = false
		box.Massless = true
		box.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = real
		weld.Part1 = box
		weld.Parent = box
		print(`🔧 เปลี่ยนชื่อกล่องเปล่า → {box:GetFullName()} (ซ่อน + เชื่อมติดตัวรากจริง)`)
	end
end

if humanoid and real.Parent ~= humanoid.Parent then
	print(`🔧 ย้ายตัวรากจริงไปอยู่ข้าง Humanoid: {humanoid.Parent:GetFullName()}`)
	real.Parent = humanoid.Parent
end
model.PrimaryPart = real

local freed = 0
for _, item in model:GetDescendants() do
	if item:IsA("BasePart") then
		if item == real then
			item.Anchored = true
		elseif item.Anchored then
			item.Anchored = false
			freed += 1
		end
	end
end
print(`🔧 ยึดตัวรากจริง · ปลด Anchored ชิ้นอื่น {freed} ชิ้น · PrimaryPart = ตัวรากจริง`)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

task.wait()
local now = humanoid and humanoid.RootPart
if now == real then
	print("✅ หลังแก้: Humanoid.RootPart = ตัวรากจริงแล้ว")
elseif humanoid then
	warn(`⚠️ หลังแก้: Humanoid.RootPart = {now and now:GetFullName() or "ไม่มี"} (ยังไม่ใช่ตัวรากจริง) — ส่ง Output นี้ให้ Claude`)
end
print("ต่อไป: ปิด Animation Editor แล้วเลือกริกใหม่ → เปิดท่าทุบพื้นดูอีกครั้ง · ผลดีแล้วกด Ctrl + S")
