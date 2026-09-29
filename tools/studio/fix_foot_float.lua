-- แก้ "เท้าลอย" ในท่า Motion Capture ของบอส Boss_rabbit (ใช้ในหน้าแก้งาน ไม่เข้าเกม) · รันครั้งเดียว ไม่ต้องแก้ Keyframe เอง
-- วิธีใช้:
--   1. กด Stop ให้อยู่โหมดแก้งาน (EDIT) — ห้ามรันตอนกด Play
--   2. แก้ค่าในหัวข้อ "ตั้งค่า" ด้านล่างถ้าจำเป็น (ครั้งแรกปล่อย DRY_RUN = true ไว้ = ดูรายงานอย่างเดียว ไม่เปลี่ยนอะไร)
--   3. Studio → แท็บ View → Command Bar → คัดลอก "ทั้งไฟล์" นี้ไปวาง → กด Enter → ดูผลในหน้าต่าง Output
--   4. ตัวเลขดูสมเหตุสมผล → ตั้ง DRY_RUN = false แล้วรันซ้ำ → ได้ท่าใหม่ชื่อ OUTPUT_NAME → ทำตาม "ขั้นต่อไป" ที่พิมพ์ท้าย Output
-- หลักการ:
--   กล้องวิดีโอประเมินท่าโดยยึด "สะโพก" เป็นหลัก ตอนย่อตัว/งอเข่า มันกะว่าสะโพกลงต่ำน้อยกว่าจริง → ขางอแล้วเท้าลอยขึ้น
--   สคริปต์นี้คำนวณตำแหน่งเท้าทุก Keyframe (Forward Kinematics = ต่อข้อต่อจากตัวรากไปถึงเท้า)
--   แล้วเลื่อน "ข้อต่อราก" (เช่น Root: HumanoidRootPart → LowerTorso) ลงให้เท้าที่ต่ำสุดแตะพื้นอ้างอิงพอดี · ทั้งตัวเลื่อนตามกันทั้งก้อน
-- ความปลอดภัย:
--   • ทำงานกับ "สำเนา" (Clone) ของท่าเท่านั้น — ท่าเดิมไม่ถูกแตะ · ตัวโมเดล/ข้อต่อ/Attachment/ชิ้นส่วน อ่านอย่างเดียว ไม่เขียน
--   • DRY_RUN = true → ไม่มีอะไรถูกบันทึกเลย · DRY_RUN = false → เพิ่มท่าใหม่ 1 อันใน ServerStorage > RBX_ANIMSAVES > <ชื่อโมเดล> (Ctrl + Z ย้อนได้)
-- ไฟล์นี้อยู่นอก src/ → Rojo ไม่ sync เข้าเกม ต้องคัดลอกไปวางเองทุกครั้ง · รันซ้ำได้
-- ⚠️ บอสถูกล็อกไว้: อ่าน docs/boss-slambot-known-good.md ก่อน · สคริปต์นี้ไม่แก้โมเดล แก้แค่ข้อมูลท่า (ถือเป็น "เพิ่ม/ปรับท่าทาง")
-- ป้ายหลักฐาน: [Verified] = ตรวจจากเอกสาร API ทางการแล้ว · [Inferred] = อนุมานจากเอกสาร/พฤติกรรมที่รู้ · [Unverified] = ยังไม่ได้ยืนยัน

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ===================== ตั้งค่า =====================
local RIG_NAME = "Boss_rabbit" -- ชื่อโมเดลบอส (หาแบบยืดหยุ่น: ตัวเล็ก/ใหญ่ ขีด _ และคำว่า boss ไม่มีผล)
local ANIM_ID = 133467149182708 -- เลข ID ท่า Idle ของกระต่าย (ตรงกับ Combat.luau · เปลี่ยน 2026-09-29 จากเดิม 99370436873239) · ใช้เมื่อ SOURCE_NAME ว่าง
local SOURCE_NAME = "" -- ชื่อท่าที่ Save ไว้ใน Animation Editor (RBX_ANIMSAVES) ที่จะใช้แทนเลข ID · "" = ใช้ ANIM_ID
local FOOT_NAMES = { "LeftFoot", "RightFoot" } -- ชื่อชิ้นเท้า (หรือ Bone เท้า) · ไม่เจอเลย = หาชื่อที่มี foot/toe ให้เอง
local REFERENCE = "first" -- พื้นอ้างอิง: "first" = ความสูงเท้าใน Keyframe แรก (ท่ายืน) · "lowest" = เท้าต่ำสุดตลอดท่า
local MODE = "both" -- "both" = ลอยก็กดลง จมก็ยกขึ้น · "lowerOnly" = แก้เฉพาะตอนลอย (กดลงอย่างเดียว)
local DRY_RUN = true -- true = พิมพ์รายงานอย่างเดียว ไม่เปลี่ยนอะไร · false = บันทึกท่าใหม่
local OUTPUT_NAME = "Idle_FootFix" -- ชื่อท่าใหม่ที่จะโผล่ในรายการ Load ของ Animation Editor
local TOLERANCE = 0.01 -- ต่างจากพื้นไม่เกินนี้ (studs) = ถือว่าแตะพื้นแล้ว ไม่ต้องแก้
local MAX_ROWS = 60 -- จำนวนแถวสูงสุดในตารางรายงาน (ท่ายาวจะพิมพ์ข้ามเป็นช่วง ๆ)
-- Pose ที่ Weight = 0 ถือเป็น "ช่องว่างโครงสร้าง" ไม่ใช่ท่าที่ตั้งไว้จริง (Animation Editor ใส่ไว้ให้ลำดับชั้นครบ)
-- [Unverified] PoseBase.Weight ถูกระบุว่า deprecated ในเอกสาร · ความหมาย 0 = ไม่ได้คีย์ เป็นธรรมเนียมที่รู้กัน ยังไม่ยืนยัน
local SKIP_ZERO_WEIGHT = true
-- ===================================================

-- ===== ตัวช่วยพิมพ์ =====
local function info(text) print("ℹ️ " .. text) end
local function good(text) print("✅ " .. text) end
local function stop(text) warn("⛔ STOP: " .. text) end

-- ทำชื่อให้เทียบง่าย: ตัวเล็ก ตัดสัญลักษณ์ ตัดคำว่า "boss" (เหมือน BossService)
local function simple(name)
	return (string.gsub(string.gsub(string.lower(name), "[^%w]", ""), "boss", ""))
end

-- ===== ขั้น 1: หาโมเดล =====
-- ลำดับเหมือนเกม: ServerStorage > Bosses → Workspace → ServerStorage (ทุกชั้น) · ต้องเป็น Model ที่มี HumanoidRootPart ข้างใน
local function findRig()
	local places = {}
	local bosses = ServerStorage:FindFirstChild("Bosses")
	if bosses then
		table.insert(places, bosses)
	end
	table.insert(places, workspace)
	table.insert(places, ServerStorage)
	for _, place in places do
		for _, item in place:GetDescendants() do
			if item:IsA("Model") and simple(item.Name) == simple(RIG_NAME)
				and item:FindFirstChild("HumanoidRootPart", true) then
				return item
			end
		end
	end
	return nil
end

-- นับว่า start ต่อถึงชิ้นอื่นกี่ชิ้น (ผ่าน Motor6D / Weld / WeldConstraint / Constraint ทาง Attachment) — เหมือน BossService
local function linkedCount(model, start)
	local links = {}
	local function link(a, b)
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			link(item.Part0, item.Part1)
		elseif item:IsA("Constraint") then -- AnimationConstraint สืบทอดจาก Constraint [Verified]
			local a0, a1 = item.Attachment0, item.Attachment1
			if a0 and a1 then
				link(a0.Parent, a1.Parent)
			end
		end
	end
	local seen, queue, count = { [start] = true }, { start }, 1
	while #queue > 0 do
		local part = table.remove(queue)
		for _, other in links[part] or {} do
			if not seen[other] then
				seen[other] = true
				count += 1
				table.insert(queue, other)
			end
		end
	end
	return count
end

-- ===== ขั้น 3: อ่านริก → แผนที่ข้อต่อ (อ่านอย่างเดียว) =====
-- node = ชิ้นส่วนหรือ Bone ที่ขยับได้ · joints[node] = { parent, frame0, frame1Inv, kind }
-- สูตร FK: world(ลูก) = world(แม่) * frame0 * pose.CFrame * frame1Inv
--   Motor6D:             frame0 = C0, frame1Inv = C1:Inverse()
--     [Verified] Weld: Part1.CFrame * C1 == Part0.CFrame * C0 · [Verified] Pose.CFrame ถูกใส่ใน Motor6D.Transform
--     [Inferred] Transform แทรกระหว่าง C0 กับ C1:Inverse() (สูตรมาตรฐาน Part0 * C0 * Transform * C1:Inverse())
--   AnimationConstraint: frame0 = Attachment0.CFrame, frame1Inv = Attachment1.CFrame:Inverse()
--     [Verified] C0/C1/Part0/Part1 = ชื่อเล่นอ่านอย่างเดียวของ Attachment0.CFrame/Attachment1.CFrame/Parent
--     [Verified] "Transform ทำงานเหมือน Motor6D.Transform" และ "Attachment ถูกบังคับให้ห่างกันเท่า Transform" → สูตรเดียวกัน [Inferred]
--   Bone:                frame0 = bone.CFrame, frame1Inv = identity (แม่ = ชิ้นส่วนหรือ Bone ที่ครอบอยู่)
--     [Verified] Bone สืบทอดจาก Attachment, Transform = offset จาก CFrame · [Inferred] world = world(แม่) * CFrame * Transform
local function buildJoints(model, root)
	local candidates = {} -- child → รายการ { parent, frame0, frame1Inv, kind }
	local counts = { Motor6D = 0, AnimationConstraint = 0, Bone = 0 }
	local function add(child, entry)
		candidates[child] = candidates[child] or {}
		table.insert(candidates[child], entry)
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			counts.Motor6D += 1
			if item.Part0 and item.Part1 then
				add(item.Part1, { parent = item.Part0, frame0 = item.C0, frame1Inv = item.C1:Inverse(), kind = "Motor6D", joint = item })
			end
		elseif item:IsA("AnimationConstraint") then -- IsA("Motor6D") ของตัวนี้เป็น false [Verified] จึงต้องแยกกรณี
			counts.AnimationConstraint += 1
			local a0, a1 = item.Attachment0, item.Attachment1
			if a0 and a1 and a0.Parent and a1.Parent and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
				add(a1.Parent, {
					parent = a0.Parent, frame0 = a0.CFrame, frame1Inv = a1.CFrame:Inverse(),
					kind = "AnimationConstraint", joint = item,
				})
			end
		elseif item:IsA("Bone") then
			counts.Bone += 1
			local parent = item.Parent
			if parent and (parent:IsA("BasePart") or parent:IsA("Bone")) then
				add(item, { parent = parent, frame0 = item.CFrame, frame1Inv = CFrame.identity, kind = "Bone", joint = item })
			end
		end
	end
	-- เดินจากตัวรากออกไป: เอาเฉพาะข้อต่อที่แม่ต่อถึงตัวรากแล้ว (กันชิ้นซ้ำ/กล่อง FBX ที่ไม่เกี่ยว)
	local joints, children = {}, {}
	local reached, queue = { [root] = true }, { root }
	local parentsOf = {} -- parent → รายการ child ที่รอ
	for child, list in candidates do
		for _, entry in list do
			parentsOf[entry.parent] = parentsOf[entry.parent] or {}
			table.insert(parentsOf[entry.parent], { child = child, entry = entry })
		end
	end
	while #queue > 0 do
		local node = table.remove(queue, 1)
		for _, pair in parentsOf[node] or {} do
			if not reached[pair.child] then
				reached[pair.child] = true
				joints[pair.child] = pair.entry
				children[node] = children[node] or {}
				table.insert(children[node], pair.child)
				table.insert(queue, pair.child)
			end
		end
	end
	return joints, children, counts
end

-- ===== ขั้น 2: โหลดท่า (ทำงานกับสำเนาเสมอ) =====
-- ที่เก็บท่าที่ Save ใน Animation Editor:
--   ServerStorage > RBX_ANIMSAVES > <ชื่อโมเดล> [Verified: avatar/animation-packs.md]
--   · <โมเดล>.AnimSaves เป็น ObjectValue ที่ .Value ชี้ไปที่เก็บนั้น [Verified: animation/editor.md]
--   ของเก่าบางเวอร์ชันเก็บไว้ใต้โมเดลโดยตรง [Inferred จาก BossService]
local function saveFolders(model)
	local list = {}
	local link = model:FindFirstChild("AnimSaves")
	if link and link:IsA("ObjectValue") and link.Value then
		table.insert(list, link.Value)
	end
	local store = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	if store then
		local byName = store:FindFirstChild(model.Name)
		if byName and not table.find(list, byName) then
			table.insert(list, byName)
		end
		for _, folder in store:GetChildren() do -- ชื่อโฟลเดอร์ไม่ตรงเป๊ะ (เช่นตัวเล็ก/ใหญ่ต่างกัน)
			if simple(folder.Name) == simple(model.Name) and not table.find(list, folder) then
				table.insert(list, folder)
			end
		end
	end
	if link and not link:IsA("ObjectValue") and not table.find(list, link) then
		table.insert(list, link) -- AnimSaves แบบโฟลเดอร์เก่า
	end
	return list
end

local function loadClip(model)
	if SOURCE_NAME ~= "" then
		local names = {}
		for _, folder in saveFolders(model) do
			for _, item in folder:GetDescendants() do
				if item:IsA("AnimationClip") then -- ทั้ง KeyframeSequence และ CurveAnimation [Verified: สืบทอด AnimationClip]
					if item.Name == SOURCE_NAME then
						return item, item:GetFullName()
					end
					table.insert(names, item.Name)
				end
			end
		end
		stop(`ไม่เจอท่าชื่อ "{SOURCE_NAME}" ใน RBX_ANIMSAVES ของ {model.Name}`
			.. ` · ท่าที่มี: {if #names > 0 then table.concat(names, ", ") else "(ไม่มีเลย)"}`
			.. ` · แก้ชื่อใน SOURCE_NAME หรือเว้นว่าง "" เพื่อโหลดจากเลข ID`)
		return nil
	end
	local assetId = "rbxassetid://" .. string.format("%.0f", ANIM_ID)
	-- วิธีแรก: AnimationClipProvider:GetAnimationClipAsync — ได้ทั้ง KeyframeSequence และ CurveAnimation
	-- [Verified] security: None, ต้องครอบ pcall (โหลดจากเว็บ) · [Unverified] โหลดได้เฉพาะท่าที่บัญชี/กลุ่มเจ้าของเกมมีสิทธิ์
	local ok, result = pcall(function()
		return game:GetService("AnimationClipProvider"):GetAnimationClipAsync(assetId)
	end)
	if ok and result then
		return result, assetId .. " (AnimationClipProvider)"
	end
	local firstError = result
	-- วิธีสำรอง: KeyframeSequenceProvider:GetKeyframeSequenceAsync (บริการเก่า deprecated แต่ยังใช้ได้) [Verified: security None]
	local ok2, result2 = pcall(function()
		return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(assetId)
	end)
	if ok2 and result2 then
		return result2, assetId .. " (KeyframeSequenceProvider)"
	end
	stop(`โหลดท่า {assetId} ไม่ได้ — {tostring(firstError)} / {tostring(result2)}`
		.. "\n   สาเหตุที่พบบ่อย: เลข ID ผิด · ท่าไม่ใช่ของบัญชี/กลุ่มเดียวกับเกม · ยังไม่ได้ Publish"
		.. "\n   ทางเลือก: Animation Editor → ⋯ → Import → From Roblox (ใส่เลข ID) → Save ตั้งชื่อ → ใส่ชื่อนั้นใน SOURCE_NAME แล้วรันใหม่")
	return nil
end

-- ===== ตัวอ่านท่า (sampler): ตอบว่า ณ เวลา t ข้อต่อชื่อ name มี pose CFrame เท่าไร =====

-- KeyframeSequence: เก็บ "เส้นทาง" ของแต่ละข้อต่อ = รายการ { time, cf, pose } เรียงตามเวลา
-- โครงสร้าง [Verified]: KeyframeSequence:GetKeyframes() → Keyframe:GetPoses() → Pose:GetSubPoses() (ซ้อนตามลำดับชั้นข้อต่อ)
-- ชื่อ Pose = ชื่อชิ้น Part1 ของข้อต่อ (หรือชื่อ Bone) [Verified: Pose docs]
local function keyframesOf(sequence)
	local list = {}
	for _, keyframe in sequence:GetKeyframes() do
		if keyframe:IsA("Keyframe") then
			table.insert(list, keyframe)
		end
	end
	table.sort(list, function(a, b) return a.Time < b.Time end)
	return list
end

local function isKey(pose)
	return not (SKIP_ZERO_WEIGHT and pose.Weight == 0)
end

local function sequenceTracks(keyframes)
	local tracks = {}
	for _, keyframe in keyframes do
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") and isKey(pose) then -- NumberPose (หน้า) ไม่ใช่ Pose → ข้าม
				tracks[pose.Name] = tracks[pose.Name] or {}
				table.insert(tracks[pose.Name], { time = keyframe.Time, cf = pose.CFrame, pose = pose })
			end
		end
	end
	return tracks
end

-- ค่า pose ณ เวลา t: มีคีย์ตรงเวลานั้น = ใช้เลย · ไม่มี = ประมาณเส้นตรง (Lerp) ระหว่างคีย์ก่อน/หลัง
-- คีย์ก่อนเป็น Constant = ค้างค่าเดิม · มีข้างเดียว = ใช้ข้างนั้น · ไม่มีเลย = identity (ท่าตั้งต้น)
-- [Inferred] ตัวเล่นจริงใช้ EasingStyle ของคีย์ก่อน (Linear/Cubic/…) · ท่า Motion Capture คีย์ถี่ ค่าต่างกันน้อยมาก
local function sampleTrack(track, t)
	if not track or #track == 0 then
		return CFrame.identity
	end
	local lo, hi = 1, #track
	if t <= track[1].time + 1e-6 then
		return track[1].cf
	end
	if t >= track[hi].time - 1e-6 then
		return track[hi].cf
	end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if track[mid].time <= t then lo = mid else hi = mid end
	end
	local a, b = track[lo], track[hi]
	if math.abs(a.time - t) < 1e-6 then return a.cf end
	if math.abs(b.time - t) < 1e-6 then return b.cf end
	if a.pose.EasingStyle == Enum.PoseEasingStyle.Constant then -- [Inferred] Constant = ค้างค่าจนถึงคีย์ถัดไป
		return a.cf
	end
	return a.cf:Lerp(b.cf, (t - a.time) / (b.time - a.time))
end

-- CurveAnimation: แต่ละข้อต่อเป็น Folder ชื่อเดียวกับ Pose · ข้างในมี Position (Vector3Curve) และ Rotation
-- (RotationCurve หรือ EulerRotationCurve) [Verified: CurveAnimation docs]
-- [Inferred] pose CFrame = CFrame.new(Position) * Rotation (เหมือน Transform = เลื่อนแล้วหมุน)
local function curveChannels(clip)
	local channels = {}
	for _, folder in clip:GetDescendants() do
		if folder:IsA("Folder") and not channels[folder.Name] then
			local position = folder:FindFirstChild("Position")
			local rotation = folder:FindFirstChild("Rotation")
			channels[folder.Name] = {
				folder = folder,
				position = if position and position:IsA("Vector3Curve") then position else nil,
				rotation = if rotation and (rotation:IsA("RotationCurve") or rotation:IsA("EulerRotationCurve")) then rotation else nil,
			}
		end
	end
	return channels
end

local function samplePosition(curve, t)
	if not curve then
		return Vector3.zero
	end
	local values = curve:GetValueAtTime(t) -- [Verified] คืน {x, y, z} · ช่องที่ไม่มีคีย์ = nil
	return Vector3.new(values[1] or 0, values[2] or 0, values[3] or 0)
end

local function sampleChannel(channel, t)
	if not channel then
		return CFrame.identity
	end
	local rotation = CFrame.identity
	local curve = channel.rotation
	if curve then
		local value
		if curve:IsA("RotationCurve") then
			value = curve:GetValueAtTime(t) -- [Verified] คืน CFrame? (ว่าง = identity)
		else
			value = curve:GetRotationAtTime(t) -- [Verified] EulerRotationCurve คืน CFrame ตาม RotationOrder
		end
		rotation = value or CFrame.identity
	end
	return CFrame.new(samplePosition(channel.position, t)) * rotation
end

-- เวลาที่มีคีย์ในเส้นโค้ง (รวมทุกข้อต่อที่เกี่ยวกับเท้า) → ใช้เป็น "Keyframe" ของ CurveAnimation
local function curveTimes(channels, names)
	local set, list = {}, {}
	local function addKeys(curve)
		if curve then
			local ok, keys = pcall(function() return curve:GetKeys() end)
			if ok then
				for _, key in keys do
					local rounded = math.floor(key.Time * 10000 + 0.5) / 10000
					if not set[rounded] then
						set[rounded] = true
						table.insert(list, rounded)
					end
				end
			end
		end
	end
	for name in names do
		local channel = channels[name]
		if channel then
			for _, owner in { channel.position, channel.rotation } do
				if owner then
					for _, child in owner:GetChildren() do
						if child:IsA("FloatCurve") then addKeys(child) end
					end
					if owner:IsA("RotationCurve") then addKeys(owner) end
				end
			end
		end
	end
	table.sort(list)
	return list
end

-- ===== ตัวหลัก =====
local function main()
	local model = findRig()
	if not model then
		stop(`ไม่เจอโมเดลชื่อ {RIG_NAME} ที่มี HumanoidRootPart ใน ServerStorage > Bosses, Workspace หรือ ServerStorage`
			.. " — ตรวจชื่อใน RIG_NAME หรือวางโมเดลไว้ใน Workspace แล้วรันใหม่")
		return
	end
	good("เจอโมเดล " .. model:GetFullName())

	-- ตัวราก = HumanoidRootPart ที่ต่อกับชิ้นอื่นมากที่สุด (FBX อาจมี 2 อัน — ดู docs/boss-slambot-known-good.md)
	local root, best, candidates = nil, -1, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name == "HumanoidRootPart" then
			candidates += 1
			local count = linkedCount(model, item)
			if count > best then
				root, best = item, count
			end
		end
	end
	if not root then
		stop("โมเดลไม่มี HumanoidRootPart ที่เป็นชิ้นส่วน (BasePart)")
		return
	end
	info(`HumanoidRootPart {candidates} อัน → ใช้ {root:GetFullName()} (ต่อกับ {best - 1} ชิ้น) เป็นตัวราก`)

	local joints, children, counts = buildJoints(model, root)
	info(`ข้อต่อในโมเดล: Motor6D {counts.Motor6D} · AnimationConstraint {counts.AnimationConstraint} · Bone {counts.Bone}`)

	-- ชื่อ Pose → node (ชิ้นส่วน/Bone) · ชื่อซ้ำใช้อันแรกที่ต่อถึงตัวราก
	local byName = {}
	for node in joints do
		if byName[node.Name] and byName[node.Name] ~= node then
			warn(`⚠️ มีข้อต่อชื่อซ้ำ "{node.Name}" — ท่าจับคู่ด้วยชื่อ อาจคำนวณผิดชิ้น`)
		else
			byName[node.Name] = node
		end
	end

	-- ===== หาเท้า =====
	local feet = {}
	for _, name in FOOT_NAMES do
		if byName[name] then
			table.insert(feet, byName[name])
		end
	end
	if #feet == 0 then
		-- สำรอง: ชื่อมี foot/toe · เลือกเฉพาะปลายสุด (ไม่มีข้อต่อลูก) ถ้ามี
		local matches, leaves = {}, {}
		for node in joints do
			local lower = string.lower(node.Name)
			if string.find(lower, "foot", 1, true) or string.find(lower, "toe", 1, true) then
				table.insert(matches, node)
				if not children[node] then
					table.insert(leaves, node)
				end
			end
		end
		feet = if #leaves > 0 then leaves else matches
		if #feet > 0 then
			info("ไม่เจอชื่อใน FOOT_NAMES → ใช้ชิ้นที่ชื่อมี foot/toe แทน")
		end
	end
	if #feet == 0 then
		local names = {}
		for node in joints do
			table.insert(names, node.Name)
		end
		table.sort(names)
		stop("ไม่เจอเท้าที่ต่อถึงตัวรากผ่านข้อต่อ — ใส่ชื่อที่ถูกใน FOOT_NAMES · ชื่อข้อต่อที่มี: " .. table.concat(names, ", "))
		return
	end
	local footNames = {}
	for _, foot in feet do
		table.insert(footNames, `{foot.Name} ({foot.ClassName})`)
	end
	info("เท้า: " .. table.concat(footNames, ", "))

	-- ===== ข้อต่อราก = ข้อต่อที่แม่คือตัวราก และทุกเท้าอยู่ใต้มัน =====
	local function topUnderRoot(node)
		while joints[node] and joints[node].parent ~= root do
			node = joints[node].parent
		end
		return if joints[node] then node else nil
	end
	local rootNode = topUnderRoot(feet[1])
	for _, foot in feet do
		if topUnderRoot(foot) ~= rootNode then
			rootNode = nil
		end
	end
	if not rootNode then
		stop("หา \"ข้อต่อราก\" ไม่ได้ (เท้าแต่ละข้างไม่ได้ต่อผ่านข้อต่อเดียวกันจาก HumanoidRootPart) — ริกแบบนี้สคริปต์ยังไม่รองรับ")
		return
	end
	local rootJoint = joints[rootNode]
	local ROOT_POSE = rootNode.Name -- ชื่อ Pose ของข้อต่อราก (R15 ปกติ = "LowerTorso" ใช้ข้อต่อชื่อ Root)
	info(`ข้อต่อราก: {rootJoint.joint.Name} ({rootJoint.kind}) {root.Name} → {ROOT_POSE} · ชื่อ Pose = "{ROOT_POSE}"`)

	-- ชื่อข้อต่อทั้งหมดบนทางจากตัวรากถึงเท้า (เฉพาะพวกนี้ที่มีผลต่อความสูงเท้า)
	local pathNames = {}
	for _, foot in feet do
		local node = foot
		while joints[node] do
			pathNames[node.Name] = true
			node = joints[node].parent
		end
	end

	-- ===== FK: ตำแหน่งโลกของ node ณ ท่าหนึ่ง (poseAt(name) → CFrame) =====
	-- เริ่มจาก HumanoidRootPart.CFrame ปัจจุบัน (โหมดแก้งาน = ท่าตั้งต้น ตัวรากไม่ถูกท่าขยับ)
	local rootWorld = root.CFrame
	local function worldOf(node, poseAt, memo)
		if node == root then
			return rootWorld
		end
		if memo[node] then
			return memo[node]
		end
		local joint = joints[node]
		local cf = worldOf(joint.parent, poseAt, memo) * joint.frame0 * poseAt(node.Name) * joint.frame1Inv
		memo[node] = cf
		return cf
	end
	-- ความสูงก้นเท้าต่ำสุด: ชิ้นส่วน = Y ต่ำสุดของมุมกล่องทั้ง 8 · Bone = ตำแหน่งจุด Bone (เป็นข้อเท้า ไม่ใช่พื้นรองเท้า
	-- แต่เทียบกับพื้นอ้างอิงที่วัดแบบเดียวกัน จึงหักล้างกัน)
	local function lowestFoot(poseAt)
		local memo, lowest = {}, math.huge
		for _, foot in feet do
			local cf = worldOf(foot, poseAt, memo)
			if foot:IsA("BasePart") then
				local half = foot.Size / 2
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							lowest = math.min(lowest, (cf * Vector3.new(half.X * x, half.Y * y, half.Z * z)).Y)
						end
					end
				end
			else
				lowest = math.min(lowest, cf.Position.Y)
			end
		end
		return lowest
	end
	-- แปลง "เลื่อนขึ้น/ลงในโลก" เป็นค่าที่บวกใน pose ของข้อต่อราก (ห้ามเดาว่า +Y ของ pose = ขึ้น — ตัวรากกระต่ายอาจหมุนอยู่)
	-- ที่มา: world(ลูก) = W * F0 * T * F1inv โดย W = world(ตัวราก), F0 = frame0
	--   ถ้า T' = T + d (บวกตำแหน่ง d ในพื้นที่แม่ของ T) = CFrame.new(d) * T
	--   world' = (W*F0) * CFrame.new(d) * T * F1inv = CFrame.new(R * d) * world  โดย R = (W*F0).Rotation
	--   → ทั้งตัวใต้ข้อต่อรากเลื่อนในโลกเท่ากับ R * d · อยากเลื่อน (0, delta, 0) → d = R:Inverse() * (0, delta, 0)
	--   ตัวราก (HumanoidRootPart) ไม่มีข้อต่อแม่ W จึงคงที่ทุกเฟรม → R คงที่
	local rootRotation = (rootWorld * rootJoint.frame0).Rotation
	local function localDelta(delta)
		return rootRotation:Inverse() * Vector3.new(0, delta, 0)
	end

	-- ===== โหลดท่า + ทำสำเนา =====
	local source, sourceLabel = loadClip(model)
	if not source then
		return
	end
	local clip = source:Clone()
	if not clip then
		stop("ทำสำเนาท่าไม่ได้ (Archivable = false?) — ใช้ Animation Editor Save เป็นท่าใหม่แล้วใส่ชื่อใน SOURCE_NAME")
		return
	end
	good(`โหลดท่าจาก {sourceLabel} → {clip.ClassName} (ทำงานกับสำเนา ท่าเดิมไม่ถูกแตะ)`)

	-- ===== เตรียม "เฟรม" ที่จะวัด/แก้ + ตัวอ่านท่าของแต่ละแบบ =====
	local isSequence = clip:IsA("KeyframeSequence")
	local isCurve = clip:IsA("CurveAnimation")
	local times, makeSampler, applyAll
	if isSequence then
		local keyframes = keyframesOf(clip)
		times = {}
		for _, keyframe in keyframes do
			table.insert(times, keyframe.Time)
		end
		makeSampler = function()
			local tracks = sequenceTracks(keyframes)
			return function(t)
				return function(name) return sampleTrack(tracks[name], t) end
			end, tracks
		end
		-- ใส่ค่าที่แก้ลง Pose ของข้อต่อรากในทุก Keyframe (ไม่มี Pose = สร้างใหม่ใต้ Pose ของตัวราก)
		applyAll = function(results, tracks)
			local created = 0
			local rootTrack = tracks[ROOT_POSE]
			for index, keyframe in keyframes do
				local row = results[index]
				local pose = nil
				for _, item in keyframe:GetDescendants() do
					if item:IsA("Pose") and item.Name == ROOT_POSE then
						pose = item
						break
					end
				end
				if not pose then
					-- สร้างทุก Keyframe ที่ขาด แม้ไม่ต้องเลื่อน: ไม่งั้นค่าระหว่างคีย์จะถูกประมาณจากคีย์ข้าง ๆ ที่เพิ่งแก้ → เท้าขยับผิด
					-- Pose แม่ (ชื่อ HumanoidRootPart) ต้องมีตามลำดับชั้น
					local parentPose = nil
					for _, item in keyframe:GetPoses() do
						if item:IsA("Pose") and item.Name == root.Name then
							parentPose = item
							break
						end
					end
					if not parentPose then
						parentPose = Instance.new("Pose")
						parentPose.Name = root.Name
						parentPose.CFrame = CFrame.identity
						keyframe:AddPose(parentPose) -- [Verified] Keyframe:AddPose
					end
					pose = Instance.new("Pose")
					pose.Name = ROOT_POSE
					-- คัดลอกการเปลี่ยนท่า (Easing) จากคีย์ข้างเคียงของข้อต่อราก
					if rootTrack and #rootTrack > 0 then
						local neighbor = rootTrack[1]
						for _, key in rootTrack do
							if key.time <= keyframe.Time then neighbor = key end
						end
						pose.EasingStyle = neighbor.pose.EasingStyle
						pose.EasingDirection = neighbor.pose.EasingDirection
					end
					parentPose:AddSubPose(pose) -- [Verified] Pose:AddSubPose
					created += 1
				end
				-- row.base = ค่าเดิม ณ เวลานี้ (คีย์จริงหรือค่าที่ประมาณจากคีย์ข้างเคียง) + ค่าเลื่อน
				pose.CFrame = row.base + localDelta(row.delta)
				if pose.Weight == 0 then
					pose.Weight = 1 -- เคยเป็นช่องว่างโครงสร้าง → ตอนนี้เป็นคีย์จริงแล้ว [Unverified ความหมายของ Weight]
				end
			end
			return created
		end
	elseif isCurve then
		local channels = curveChannels(clip)
		times = curveTimes(channels, pathNames)
		if #times == 0 then
			times = { 0 }
		end
		makeSampler = function()
			local fresh = curveChannels(clip)
			return function(t)
				return function(name) return sampleChannel(fresh[name], t) end
			end, fresh
		end
		-- เขียนเส้น Position ของข้อต่อรากใหม่: มีคีย์ทุกเวลาที่วัด = ค่าเดิม + ค่าเลื่อน (แบบ Linear)
		-- [Verified] FloatCurve:SetKeys ล้างคีย์เก่าแล้วใส่ใหม่ · FloatCurveKey.new(time, value, interpolation)
		applyAll = function(results, fresh)
			local channel = fresh[ROOT_POSE]
			local folder = channel and channel.folder
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = ROOT_POSE
				local parentFolder = nil
				for _, item in clip:GetDescendants() do
					if item:IsA("Folder") and item.Name == root.Name then
						parentFolder = item
						break
					end
				end
				if not parentFolder then
					parentFolder = Instance.new("Folder")
					parentFolder.Name = root.Name
					parentFolder.Parent = clip
				end
				folder.Parent = parentFolder
			end
			local position = channel and channel.position
			local old = {}
			for index, t in times do
				old[index] = samplePosition(position, t)
			end
			if not position then
				position = Instance.new("Vector3Curve")
				position.Name = "Position"
				position.Parent = folder
			end
			local axes = { { position:X(), "X" }, { position:Y(), "Y" }, { position:Z(), "Z" } }
			for _, axis in axes do
				local keys = {}
				for index, t in times do
					local value = old[index] + localDelta(results[index].delta)
					table.insert(keys, FloatCurveKey.new(t, value[axis[2]], Enum.KeyInterpolationMode.Linear))
				end
				axis[1]:SetKeys(keys)
			end
			return 0
		end
	else
		stop(`ท่าเป็นชนิด {clip.ClassName} ที่สคริปต์ไม่รู้จัก`)
		clip:Destroy()
		return
	end

	local length = times[#times] or 0
	info(`ท่ามี {#times} {if isSequence then "Keyframe" else "จุดเวลา (CurveAnimation)"} · ยาว {string.format("%.2f", length)} วินาที`)
	if #times == 0 then
		stop("ท่านี้ไม่มี Keyframe เลย (ท่าว่าง เช่นไฟล์ Automatic Save) — เลือกท่าอื่น")
		clip:Destroy()
		return
	end

	-- ===== ขั้น 4: วัดความสูงเท้าทุกเฟรม (ท่าเดิม) =====
	local sampler, data = makeSampler()
	local results = {}
	for index, t in times do
		local poseAt = sampler(t)
		results[index] = { time = t, low = lowestFoot(poseAt), base = poseAt(ROOT_POSE) }
	end
	local referenceY = results[1].low
	if REFERENCE == "lowest" then
		for _, row in results do
			referenceY = math.min(referenceY, row.low)
		end
	elseif REFERENCE ~= "first" then
		stop(`REFERENCE ต้องเป็น "first" หรือ "lowest" (ตอนนี้ = "{REFERENCE}")`)
		clip:Destroy()
		return
	end
	if MODE ~= "both" and MODE ~= "lowerOnly" then
		stop(`MODE ต้องเป็น "both" หรือ "lowerOnly" (ตอนนี้ = "{MODE}")`)
		clip:Destroy()
		return
	end
	local maxFloat, maxSink, fixedCount = 0, 0, 0
	for _, row in results do
		row.float = row.low - referenceY -- + = ลอย · - = จม
		maxFloat = math.max(maxFloat, row.float)
		maxSink = math.min(maxSink, row.float)
		local delta = -row.float
		if math.abs(delta) <= TOLERANCE or (MODE == "lowerOnly" and delta > 0) then
			delta = 0
		end
		row.delta = delta
		if delta ~= 0 then
			fixedCount += 1
		end
	end

	-- ===== ขั้น 5: ใส่ค่าที่แก้ลงสำเนา แล้ววัดซ้ำเพื่อยืนยัน =====
	local okApply, createdOrError = pcall(applyAll, results, data)
	if not okApply then
		stop("ใส่ค่าที่แก้ลงท่าไม่สำเร็จ: " .. tostring(createdOrError))
		if isCurve then
			warn("   ท่านี้เป็น CurveAnimation — ทางเลือก: Animation Editor → ⋯ → Import → From Roblox (เลข ID)"
				.. " → Save เป็นชื่อใหม่ โดยไม่เปิด Curve Editor (จะได้ KeyframeSequence) → ใส่ชื่อนั้นใน SOURCE_NAME แล้วรันใหม่")
		end
		clip:Destroy()
		return
	end
	local afterSampler = makeSampler()
	local maxAfter, minAfter = -math.huge, math.huge
	for _, row in results do
		row.after = lowestFoot(afterSampler(row.time)) - referenceY
		maxAfter = math.max(maxAfter, row.after)
		minAfter = math.min(minAfter, row.after)
	end

	-- ===== รายงาน =====
	print(`พื้นอ้างอิง ({REFERENCE}) = Y {string.format("%.3f", referenceY)} · โหมด {MODE} · (+ = ลอย, - = จม, หน่วย studs)`)
	print(string.format("%8s | %10s | %10s | %10s", "เวลา(s)", "ลอยก่อน", "เลื่อน", "ลอยหลัง"))
	local step = math.max(1, math.ceil(#results / MAX_ROWS))
	for index, row in results do
		if index % step == 1 or step == 1 or index == #results then
			print(string.format("%8.3f | %10.3f | %10.3f | %10.3f", row.time, row.float, row.delta, row.after))
		end
	end
	if step > 1 then
		info(`พิมพ์ทุก ๆ {step} เฟรม (ท่ายาว) · 5 เฟรมที่ลอยมากสุด:`)
		local sorted = table.clone(results)
		table.sort(sorted, function(a, b) return a.float > b.float end)
		for i = 1, math.min(5, #sorted) do
			local row = sorted[i]
			print(string.format("%8.3f | %10.3f | %10.3f | %10.3f", row.time, row.float, row.delta, row.after))
		end
	end
	print(string.format("สรุป: ก่อนแก้ ลอยสูงสุด %.3f · จมสุด %.3f  →  หลังแก้ ลอยสูงสุด %.3f · จมสุด %.3f · แก้ %d/%d เฟรม",
		maxFloat, maxSink, maxAfter, minAfter, fixedCount, #results))
	local limitAfter = if MODE == "both" then math.max(math.abs(maxAfter), math.abs(minAfter)) else math.max(maxAfter, 0)
	if limitAfter <= TOLERANCE * 2 then
		good("ตรวจซ้ำแล้ว: เท้าแตะพื้นอ้างอิงทุกเฟรม (คลาดไม่เกิน " .. TOLERANCE * 2 .. " studs)")
	else
		warn("⚠️ ตรวจซ้ำแล้วยังคลาดเกินคาด — ดูตารางด้านบน (อาจเกิดจาก Keyframe ห่างกันมาก หรือข้อต่อชื่อซ้ำ)")
	end
	if isSequence and typeof(createdOrError) == "number" and createdOrError > 0 then
		info(`สร้าง Pose "{ROOT_POSE}" ใหม่ใน {createdOrError} Keyframe ที่เดิมไม่มี`)
	end
	if isCurve then
		info("CurveAnimation: เส้น Position ของข้อต่อรากถูกเขียนใหม่เป็นคีย์แบบ Linear ทุกจุดเวลาที่วัด (ข้อต่ออื่นไม่เปลี่ยน)")
	end

	-- ===== DRY_RUN: จบตรงนี้ ไม่บันทึกอะไร =====
	if DRY_RUN then
		clip:Destroy()
		print("🧪 DRY_RUN = true → ยังไม่ได้บันทึกอะไร · ถ้าตัวเลขดูดี ตั้ง DRY_RUN = false แล้วรันทั้งไฟล์อีกครั้ง")
		return
	end

	-- ===== บันทึก: ใส่สำเนาที่แก้แล้วใน RBX_ANIMSAVES ของโมเดล (โผล่ในรายการ Load ของ Animation Editor) =====
	local _, recording = pcall(function()
		return ChangeHistoryService:TryBeginRecording("Fix foot float")
	end)
	local folder = saveFolders(model)[1]
	if not folder or folder:IsDescendantOf(model) then
		-- ยังไม่เคย Save ท่าของโมเดลนี้ → สร้างโฟลเดอร์ใน ServerStorage (ไม่แตะตัวโมเดล)
		-- [Unverified] Animation Editor อ่านโฟลเดอร์ RBX_ANIMSAVES > <ชื่อโมเดล> แม้โมเดลยังไม่มี ObjectValue AnimSaves
		local store = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
		if not store then
			store = Instance.new("Model") -- Animation Editor สร้างเป็น Model [Unverified] (ชนิดไม่มีผลกับการอ่าน)
			store.Name = "RBX_ANIMSAVES"
			store.Parent = ServerStorage
		end
		folder = store:FindFirstChild(model.Name)
		if not folder then
			folder = Instance.new("ObjectValue") -- ใช้แบบเดียวกับที่ Editor สร้าง [Unverified] · Value ชี้โมเดล
			folder.Name = model.Name
			folder.Value = model
			folder.Parent = store
		end
	end
	local name, n = OUTPUT_NAME, 1
	while folder:FindFirstChild(name) do -- มีชื่อนี้แล้ว → ไม่ทับ ตั้งชื่อ _2, _3, …
		n += 1
		name = `{OUTPUT_NAME}_{n}`
	end
	clip.Name = name
	clip.Parent = folder
	if recording then
		pcall(function()
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end)
	end
	good(`บันทึกท่าที่แก้แล้ว: {clip:GetFullName()}`)

	-- เลขทดสอบชั่วคราว (ใช้ได้ใน Studio เท่านั้น ใส่ในเกมจริงไม่ได้) [Verified: RegisterAnimationClip / RegisterKeyframeSequence]
	local okId, previewId = pcall(function()
		return game:GetService("AnimationClipProvider"):RegisterAnimationClip(clip)
	end)
	if not okId and isSequence then
		okId, previewId = pcall(function()
			return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(clip)
		end)
	end
	if okId then
		info("เลขพรีวิวชั่วคราว (Studio เท่านั้น): " .. tostring(previewId))
	else
		warn("⚠️ สร้างเลขพรีวิวไม่ได้: " .. tostring(previewId) .. " (ไม่เป็นไร ดูใน Animation Editor แทน)")
	end

	print("ขั้นต่อไป:")
	print(`  1. Avatar → Animation Editor → คลิกโมเดล {model.Name} → ⋯ → Load → เลือก "{name}"`)
	print("  2. กดเล่นดู: เท้าต้องแตะพื้นตอนย่อ ไม่ลอย ไม่จม (ไม่ดี → กด Ctrl + Z หรือลบท่านี้ แล้วลอง REFERENCE/MODE อื่น)")
	print("  3. ⋯ → Publish to Roblox (ทับเลขเดิม หรือสร้างเลขใหม่) — เจ้าของเดียวกับเกม")
	print(`  4. ได้เลขใหม่ → ใส่แทน {ANIM_ID} ที่ src/shared/Config/Combat.luau (แถว Boss_rabbit → Animations.Idle)`)
	print("  5. ก่อนกด Play: สำรองแล้วลบ ServerStorage > RBX_ANIMSAVES (ไม่งั้นเกมใน Studio อาจหยิบท่าที่ Save ไว้แทนเลข ID) → Ctrl + S")
end

-- รันตัวหลักใน pcall: ถ้าพังกลางทาง จะบอกเป็นภาษาไทยแทนข้อความแดงยาว ๆ
local ok, err = pcall(main)
if not ok then
	warn("❌ สคริปต์หยุดเพราะเกิดข้อผิดพลาด (ไม่มีอะไรถูกบันทึก ถ้ายังไม่ถึงขั้นบันทึก): " .. tostring(err))
	warn("   ตรวจว่า: อยู่โหมดแก้งาน (กด Stop แล้ว) · วางทั้งไฟล์ครบ · ชื่อโมเดล/ท่าในส่วนตั้งค่าถูก")
end
