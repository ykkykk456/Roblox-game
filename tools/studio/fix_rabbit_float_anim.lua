-- แก้ท่า Motion Capture ของ Boss_rabbit ที่เท้าลอย (แก้ในข้อมูลท่า → เห็นผลในหน้า Animation Editor ด้วย ไม่ต้องกด Play)
-- ปัญหา: ท่างอเข่าแต่สะโพกไม่ลดตาม → ขาพับขึ้น เท้าลอย
-- วิธีแก้: ไล่ทุก Keyframe → คำนวณตำแหน่งทุกชิ้นตามท่า (FK ผ่าน AnimationConstraint) → หาจุดต่ำสุดของตัว
--   → เลื่อน LowerTorso ลง/ขึ้นในแนวดิ่งให้จุดต่ำสุดเท่ากับตอนยืนปกติ (เท้าแตะพื้นทุกเฟรม) · ข้อต่ออื่นไม่แตะ
-- ไม่ทับท่าเดิม: สร้างสำเนาชื่อ "Slam_fixed" ไว้ข้างท่าเดิม (รันซ้ำ = สร้างสำเนาใหม่ทับ Slam_fixed อันเก่า)
--   ชื่อมีคำว่า Slam → ตอนกด Play ใน Studio เกมใช้เป็นท่าทุบพื้นให้เอง (BossService.studioSequences)
-- วิธีใช้: กด Stop → (ถ้าต้องการ) คลิกเลือกท่าใน Explorer ที่ ServerStorage > RBX_ANIMSAVES > Boss_rabbit
--   ไม่เลือก = ใช้ท่าชื่อ autosave / Automatic Save ในโฟลเดอร์นั้น
--   → View → Command Bar → วางทั้งไฟล์ → Enter → ดู Output → Animation Editor: Load → Slam_fixed → Ctrl + S
-- สมมติฐาน: ข้อต่อ AnimationConstraint ใช้ค่า Pose.CFrame เป็น Transform แบบเดียวกับ Motor6D [Inferred]
--   ถ้าผลออกมาเพี้ยน (ตัวจม/บิด) → Ctrl + Z หรือลบ Slam_fixed แล้วส่ง Output ให้ Claude
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม · ใช้กับ Boss_rabbit (Slambot ถูกล็อก ห้ามใช้)

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local MODEL_NAME = "Boss_rabbit"
local OUTPUT_NAME = "Slam_fixed"
local TOLERANCE = 0.05 -- studs · ลอย/จมน้อยกว่านี้ไม่แก้

local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

-- ===== หาโมเดล =====
local model
for _, container in { workspace, ServerStorage } do
	for _, item in container:GetDescendants() do
		if item:IsA("Model") and simple(item.Name) == simple(MODEL_NAME) and item:FindFirstChild("HumanoidRootPart", true) then
			model = item
			break
		end
	end
	if model then
		break
	end
end
if not model then
	warn(`❌ ไม่เจอโมเดล {MODEL_NAME} ใน Workspace / ServerStorage`)
	return
end

-- ===== หาท่า =====
local sequence
for _, item in Selection:Get() do
	if item:IsA("KeyframeSequence") and item.Name ~= OUTPUT_NAME then
		sequence = item
	elseif item:IsA("KeyframeSequence") then
		warn(`⚠️ ข้าม {item.Name} (เป็นผลลัพธ์ของสคริปต์นี้) — เลือกท่าต้นฉบับแทน`)
	end
end
if not sequence then
	local store = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	local folder = store and store:FindFirstChild(model.Name)
	if folder then
		for _, item in folder:GetChildren() do
			local lower = string.lower(item.Name)
			if item:IsA("KeyframeSequence") and (string.find(lower, "auto") or string.find(lower, "slam")) and item.Name ~= OUTPUT_NAME then
				sequence = item
				break
			end
		end
	end
end
if not sequence then
	warn("❌ ไม่เจอท่า — คลิกเลือกท่า (KeyframeSequence) ใน ServerStorage > RBX_ANIMSAVES > Boss_rabbit แล้วรันใหม่")
	return
end
print(`--- แก้เท้าลอย: {sequence:GetFullName()} (โมเดล {model:GetFullName()}) ---`)

-- ===== โครงข้อต่อ (AnimationConstraint ต่อชิ้นผ่าน Attachment) =====
local neighbors = {}
local function add(a, b, joint)
	neighbors[a] = neighbors[a] or {}
	table.insert(neighbors[a], { other = b, joint = joint })
end
for _, item in model:GetDescendants() do
	if item:IsA("AnimationConstraint") and item.Attachment0 and item.Attachment1 then
		local a, b = item.Attachment0.Parent, item.Attachment1.Parent
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			add(a, b, item)
			add(b, a, item)
		end
	end
end

-- ตัวราก = HumanoidRootPart ที่ต่อกับชิ้นอื่นมากที่สุด (เหมือน BossService)
local root, best = nil, -1
for _, item in model:GetDescendants() do
	if item:IsA("BasePart") and item.Name == "HumanoidRootPart" then
		local seen, queue, n = { [item] = true }, { item }, 0
		while #queue > 0 do
			for _, link in neighbors[table.remove(queue)] or {} do
				if not seen[link.other] then
					seen[link.other] = true
					n += 1
					table.insert(queue, link.other)
				end
			end
		end
		if n > best then
			root, best = item, n
		end
	end
end
if not root or best <= 0 then
	warn("❌ ไม่เจอตัวรากที่ต่อกับข้อต่อ AnimationConstraint")
	return
end

-- ลำดับจากรากออกไป: ชิ้นลูกแต่ละชิ้นรู้ชิ้นแม่และข้อต่อ
local order, parentOf = {}, {}
do
	local seen, queue = { [root] = true }, { root }
	while #queue > 0 do
		local part = table.remove(queue, 1)
		for _, link in neighbors[part] or {} do
			if not seen[link.other] then
				seen[link.other] = true
				parentOf[link.other] = { parent = part, joint = link.joint }
				table.insert(order, link.other)
				table.insert(queue, link.other)
			end
		end
	end
end
print(`ตัวราก {root:GetFullName()} · ข้อต่อ {#order} จุด`)

-- ข้อต่อกลับด้าน (Attachment0 อยู่ชิ้นลูก) = ไม่แน่ใจว่า Animator ใช้ Pose ชื่อไหนกับข้อต่อนั้น [Unverified] → แจ้งไว้
local reversed = 0
for _, child in order do
	if parentOf[child].joint.Attachment0.Parent ~= parentOf[child].parent then
		reversed += 1
		warn(`⚠️ ข้อต่อกลับด้าน: {parentOf[child].joint:GetFullName()} (Attachment0 อยู่ที่ {child.Name}) — ผลตรงชิ้นนี้อาจเพี้ยน`)
	end
end

local lowerTorso = model:FindFirstChild("LowerTorso", true)
local rootLink = lowerTorso and parentOf[lowerTorso]
if not rootLink or rootLink.parent ~= root then
	warn("❌ ไม่เจอ LowerTorso ที่ต่อกับตัวรากโดยตรง — ส่ง Output นี้ให้ Claude")
	return
end

-- ชิ้นที่ใช้วัด "จุดต่ำสุด": เฉพาะชิ้นที่มองเห็น ไม่นับกล่องช่วย (HumanoidRootPart / UnusedRootBox ทุกอัน รวมตัวราก)
--   ตัวรากไม่ขยับตามท่า ถ้านับด้วย การเลื่อน LowerTorso จะไม่ทำให้จุดต่ำสุดเลื่อนตาม delta
--   ถ้ามีชิ้นชื่อ Foot ที่มองเห็น → วัดแค่เท้า (ท่าทุบพื้นมือลงต่ำกว่าเท้าได้ ถ้าวัดมือ ตัวจะถูกยกจนเท้าลอยอีก)
local measured = {}
local feet = {}
for _, part in order do
	if part.Transparency < 1 and part.Name ~= "HumanoidRootPart" and part.Name ~= "UnusedRootBox" then
		table.insert(measured, part)
		if string.find(string.lower(part.Name), "foot") then
			table.insert(feet, part)
		end
	end
end
if #feet > 0 then
	measured = feet
end
if #measured == 0 then
	warn("❌ ไม่มีชิ้นที่มองเห็นซึ่งต่อกับข้อต่อ AnimationConstraint")
	return
end
local names = {}
for _, part in measured do
	table.insert(names, part.Name)
end
print(`วัดจุดต่ำสุดจาก: {table.concat(names, ", ")}`)

local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- คำนวณ CFrame ทุกชิ้นตามท่า (transforms: ชื่อชิ้น → Pose.CFrame) แล้วคืนจุดต่ำสุดของชิ้นที่วัด
--   ปกติ: ลูก = แม่ · Attachment0 · Transform · Attachment1⁻¹ (Attachment1.WorldCFrame = Attachment0.WorldCFrame · Transform) [Inferred]
local function lowestPoint(transforms)
	local world = { [root] = root.CFrame }
	for _, child in order do
		local info = parentOf[child]
		local joint, parentCF = info.joint, world[info.parent]
		local t = transforms[child.Name] or CFrame.identity
		if joint.Attachment0.Parent == info.parent then
			world[child] = parentCF * joint.Attachment0.CFrame * t * joint.Attachment1.CFrame:Inverse()
		else
			world[child] = parentCF * joint.Attachment1.CFrame * t:Inverse() * joint.Attachment0.CFrame:Inverse()
		end
	end
	local lowest = math.huge
	for _, part in measured do
		local cf, half = world[part], part.Size / 2
		for _, corner in CORNERS do
			lowest = math.min(lowest, (cf * (half * corner)).Y)
		end
	end
	return lowest
end

local restLowest = lowestPoint({})
print(string.format("ท่ายืนปกติ: จุดต่ำสุด Y = %.2f (ถือเป็นพื้น)", restLowest))

local sourceKeyframes = sequence:GetKeyframes()
if #sourceKeyframes == 0 then
	warn("❌ ท่านี้ไม่มี Keyframe")
	return
end

-- ===== สร้างสำเนาแล้วแก้ (บันทึกประวัติให้ Ctrl + Z ย้อนได้) =====
local began, recording = pcall(function()
	return ChangeHistoryService:TryBeginRecording("Fix Boss_rabbit floating feet")
end)
if not began then
	recording = nil -- pcall ล้ม = recording เป็นข้อความ error ห้ามส่งให้ FinishRecording
end
local old = sequence.Parent:FindFirstChild(OUTPUT_NAME)
if old and old ~= sequence then
	old:Destroy()
end
local fixed = sequence:Clone()
fixed.Name = OUTPUT_NAME
fixed.Parent = sequence.Parent

local ok, err = pcall(function()
	local keyframes = fixed:GetKeyframes()
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)

	-- Pose ที่ Weight = 0 = ตัวยึดโครง (ให้ Pose ลูกมีที่อยู่) ไม่ใช่ค่าท่าจริงของชิ้นนั้น [Inferred]
	-- เก็บค่าท่าเดิมทุกชิ้น: ชื่อชิ้น → รายการ { time, cf, style } เรียงตามเวลา
	local keys = {}
	local placeholders = 0
	local template -- Pose LowerTorso ตัวอย่าง (ไว้ดูว่าอยู่ใต้ Pose ชื่ออะไร)
	for _, keyframe in keyframes do
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") then
				if pose.Name == "LowerTorso" and not template then
					template = pose
				end
				if pose.Weight > 0 then
					keys[pose.Name] = keys[pose.Name] or {}
					table.insert(keys[pose.Name], { time = keyframe.Time, cf = pose.CFrame, style = pose.EasingStyle, dir = pose.EasingDirection })
				else
					placeholders += 1
				end
			end
		end
	end
	if placeholders > 0 then
		print(`พบ Pose ตัวยึดโครง (Weight 0) {placeholders} อัน → ใช้ค่าที่ Animator ประมาณระหว่าง Keyframe แทน`)
	end

	-- ค่าท่าของชิ้นหนึ่ง ณ เวลา t: ช่วงระหว่าง Key = ประมาณเส้นตรง (ตรงเป๊ะเฉพาะ Linear) · Constant = ค้างค่าเดิม [Inferred]
	local function valueAt(list, t)
		local prev, nextKey
		for _, key in list do
			if key.time <= t then
				prev = key
			elseif not nextKey then
				nextKey = key
			end
		end
		if not prev then
			return nextKey.cf, nil -- ก่อน Key แรก = ใช้ค่า Key แรก [Unverified]
		end
		if prev.time == t or not nextKey or prev.style == Enum.PoseEasingStyle.Constant then
			return prev.cf, prev
		end
		return prev.cf:Lerp(nextKey.cf, (t - prev.time) / (nextKey.time - prev.time)), prev
	end

	local changed, added, maxFix = 0, 0, 0
	local joint = rootLink.joint
	local rootSide = if joint.Attachment0.Parent == root then joint.Attachment0 else joint.Attachment1
	local frame = root.CFrame * rootSide.CFrame -- กรอบข้อต่อฝั่งตัวราก (ไม่ขึ้นกับท่า)

	for _, keyframe in keyframes do
		local transforms = {}
		for name, list in keys do
			transforms[name] = valueAt(list, keyframe.Time)
		end
		local delta = restLowest - lowestPoint(transforms) -- บวก = ต้องยกขึ้น (จม) · ลบ = ต้องกดลง (ลอย)
		if math.abs(delta) > TOLERANCE then
			-- เลื่อน LowerTorso (และทุกชิ้นที่ห้อยจากมัน) ในแนวดิ่งของโลก: T' = P⁻¹ · เลื่อน · P · T (P = กรอบข้อต่อฝั่งตัวราก)
			local current = transforms.LowerTorso or CFrame.identity
			local shift = frame:Inverse() * CFrame.new(0, delta, 0) * frame
			local newT = shift * current
			if joint.Attachment0.Parent ~= root then
				-- ข้อต่อกลับด้าน: Transform อยู่ฝั่งตรงข้าม (ลูก = แม่ · A1 · T⁻¹ · A0⁻¹) [Inferred]
				newT = (shift * current:Inverse()):Inverse()
			end

			-- หา Pose LowerTorso ของ Keyframe นี้ (ไม่มี = สร้างใหม่ใต้ Pose แม่แบบเดียวกับ Keyframe อื่น)
			local pose
			for _, item in keyframe:GetDescendants() do
				if item:IsA("Pose") and item.Name == "LowerTorso" then
					pose = item
					break
				end
			end
			local prevKey = nil
			if keys.LowerTorso then
				_, prevKey = valueAt(keys.LowerTorso, keyframe.Time)
			end
			if not pose or pose.Weight <= 0 then
				added += 1
			end
			if not pose then
				local parentName = if template and template.Parent and template.Parent:IsA("Pose")
					then template.Parent.Name
					else "HumanoidRootPart"
				local parentPose
				for _, item in keyframe:GetDescendants() do
					if item:IsA("Pose") and item.Name == parentName then
						parentPose = item
						break
					end
				end
				if not parentPose then
					if template and template.Parent and template.Parent:IsA("Pose") then
						parentPose = template.Parent:Clone() -- เลียนแบบโครงเดิม (Weight/CFrame เดียวกับของเดิม)
						parentPose:ClearAllChildren()
					else
						parentPose = Instance.new("Pose")
						parentPose.Name = parentName
						parentPose.Weight = 0 -- ตัวยึดโครง ไม่ใช่ค่าท่า [Inferred]
					end
					parentPose.Parent = keyframe
				end
				pose = Instance.new("Pose")
				pose.Name = "LowerTorso"
				pose.Parent = parentPose
			end
			if pose.Weight <= 0 then
				pose.Weight = 1
				if prevKey then
					-- Key ใหม่ใช้ Easing เดียวกับ Key ก่อนหน้า → ช่วงถัดไปโค้งแบบเดิม
					pose.EasingStyle = prevKey.style
					pose.EasingDirection = prevKey.dir
				end
			end
			pose.CFrame = newT
			changed += 1
			maxFix = math.max(maxFix, math.abs(delta))
		end
	end
	print(
		string.format(
			"✅ แก้ %d จาก %d Keyframe (เพิ่ม Key LowerTorso ใหม่ %d) · เลื่อนมากสุด %.2f studs → สร้าง %s",
			changed,
			#keyframes,
			added,
			maxFix,
			fixed:GetFullName()
		)
	)
end)

if not ok then
	fixed:Destroy()
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
	end
	warn(`❌ แก้ไม่สำเร็จ (ไม่ได้สร้าง {OUTPUT_NAME}): {err} — ส่ง Output นี้ให้ Claude`)
	return
end
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
if reversed > 0 then
	warn(`⚠️ มีข้อต่อกลับด้าน {reversed} จุด — เช็กผลใน Animation Editor ให้ดี`)
end
print("ต่อไป: Animation Editor → Load → " .. OUTPUT_NAME .. " → เล่นดูว่าเท้าติดพื้น → Ctrl + S (ผลไม่ดี = Ctrl + Z)")
