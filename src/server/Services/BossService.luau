-- ⚠️ ล็อก: วิธีวาง/ยึด/เล่นท่าของบอสที่ใช้ได้จดไว้ที่ docs/boss-slambot-known-good.md — ห้ามแก้ให้เพี้ยน ยกเว้นเพิ่มท่า
-- บอสอีเวนต์: เกิดตามเวลา ทั้งเซิร์ฟช่วยกันตี แบ่งรางวัล "ขั้นต่ำ + ตามดาเมจ" (เจ้าของ: Gameplay_Scripter)
-- ชนะ = เงิน + อุปกรณ์ป้อม (อันดับต้นได้โบนัส · GearService.grantBossDrops) · หนี = เงินลดลง ไม่มีของ
-- สถานะส่งให้ Client ผ่าน Attribute ของ ReplicatedStorage.BossState (อ่านอย่างเดียว ใช้แสดงผล):
--   Active: boolean · TotalDamage: ดาเมจรวมทั้งเซิร์ฟ · EndsAt / NextAt: เวลา workspace:GetServerTimeNow()
--   บอสไม่มีเลือด อยู่ Combat.Boss.Duration แล้วจากไป → แจกเงิน + อุปกรณ์ตามดาเมจ (ยืนยัน 2026-09-27 · ตั๋ว→อุปกรณ์ 2026-09-30)
--   Top: JSON [{ n = ชื่อ, d = ดาเมจ }] 5 อันดับ · Result: ข้อความผลรอบล่าสุด
-- ดาเมจของตัวเองส่งผ่าน Player Attribute "BossDamage"
--
-- หน้าตา/ท่าทาง (ยืนยัน 2026-09-26):
--   • บอสหลายตัวสลับกันตาม Combat.Boss.Rotation (กระต่าย → โรบอท → วน) · Animate = false = ยืนเฉย ไม่มีท่า
--   • โมเดลจริงวางเองใน Studio ที่ ServerStorage > Bosses > <ชื่อใน Rotation> (ริก R15 มี Humanoid)
--     ตอนนี้ชื่อ boss_slambot (Import จาก boss_slambot.fbx) · วางไว้ใน Workspace ก็ได้ → ตอนเซิร์ฟเริ่มจะย้ายไปเก็บให้
--     ชื่อยืดหยุ่น (boss_slambot / Slambot / Slam-Bot) · ชิ้นส่วนซ้อนอยู่ในโมเดลย่อยก็หาเจอ
--     ชิ้นที่ไม่ได้ต่อกับ HumanoidRootPart จะถูกซ่อมข้อต่อให้ (กันร่วงทะลุแมพ) · ตัวรากถูกซ่อน
--     ไม่มีโมเดล → ใช้ลูกบอลสำรอง · clone แล้วลบสคริปต์ที่ติดมากับโมเดล (กันสคริปต์แฝง)
--   • เปิดตัว: ท่า Walk เดินจากขอบแอ่งเข้ากลาง → ยืน Idle วน · ทุก SlamInterval วินาทีเล่นท่า Slam
--   • จังหวะกระแทก: เอฟเฟกต์พื้นแตก + ยิงสัญญาณ BossService.Slammed (TurretService ลดเลือดป้อม)
--   • เล่นอนิเมชันที่ Server ผ่าน Animator → ผู้เล่นทุกคนเห็นท่าเดียวกัน
--
-- ===== อยากปรับอะไร → ไปแก้ที่ไหน (ไม่ต้องแก้ไฟล์นี้) =====
--   • บอสมาเมื่อไหร่ / อยู่นานแค่ไหน → Combat.Boss.FirstDelay / Interval / Duration (src/shared/Config/Combat.luau)
--   • ลำดับบอส / เพิ่มบอสตัวใหม่ → Combat.Boss.Rotation (เพิ่มแถว + วางโมเดลชื่อตรงกันใน Studio)
--   • เลขท่า Idle/Walk/Slam → Combat.Boss.Animations หรือ Animations ในแถว Rotation ของบอสตัวนั้น
--   • บอสจมพื้น/ลอย → Combat.Boss.GroundOffset
--   • ทุบบ่อย/แรงแค่ไหน → Combat.Boss.SlamInterval / SlamDamage / SlamHitDelay
--   • เดินเปิดตัว → Combat.Boss.EntranceSeconds / EntranceFrom (ผังเดิม) · Map.Layout.EntranceFrom (ผังจาก Tag)
--   • เงิน/ของที่แจกตอนจบ → Economy.Boss.BaseReward / DamageRewardPool (Config/Economy.luau) · Equipment.Drops (Config/Equipment.luau)
--
-- คุยกับไฟล์ไหนบ้าง:
--   • LayoutService — จุดบอส/จุดป้อม/ความสูงพื้นจากแมพ (Tag BossSpawn)
--   • Wallet — ให้เงิน · GearService — ให้อุปกรณ์ป้อม (แทนตั๋วกาชาเดิม)
--   • TurretService / TurretClassService — เรียก getTarget (จุดเล็ง), isActive, damage (นับดาเมจ) และฟัง Slammed (ลดเลือดป้อม)
--   • MonsterService — เช็ก isActive (ตอนมีบอส มอนหยุดออก)
--   • ฝั่ง Client อ่าน ReplicatedStorage.BossState + Player Attribute "BossDamage" ไปแสดง UI
--
-- ⚠️ ห้ามแก้ (ล็อก): ส่วนหาโมเดล/ข้อต่อ/วางตัว/อนิเมชัน (findTemplate, connectedToRoot, poseLinks, jointPivot,
--   repairJoints, makeModel, studioSequences, loadTracks และการเดินใน runBehaviour)
--   → อ่าน docs/boss-slambot-known-good.md ก่อนเสมอ · ห้าม CFrame.lookAt · ห้าม GetBoundingBox · ห้ามยึด HumanoidRootPart อันแรกที่เจอ
--   → เพิ่มท่าใหม่ = ใส่เลข ID ใน Config อย่างเดียว ไม่ต้องแตะไฟล์นี้

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local LayoutService = require(script.Parent.LayoutService)
local GearService = require(script.Parent.GearService)
local Wallet = require(script.Parent.Wallet)

-- ===== ค่าคงที่ (ปรับได้ปลอดภัย) =====
-- PUBLISH_INTERVAL = ทุกกี่วินาทีส่งดาเมจ/อันดับให้ Client และเช็กว่าหมดเวลาบอสหรือยัง
--   ลดลง = ตัวเลขบน UI อัปเดตไวขึ้น (ส่งข้อมูลถี่ขึ้น) · เพิ่มขึ้น = ประหยัดกว่าแต่ตัวเลขกระตุก
-- TOP_COUNT = จำนวนอันดับที่ส่งไปโชว์ในตาราง Top · เพิ่มได้ แต่ UI ฝั่ง Client อาจโชว์ไม่ครบ
local PUBLISH_INTERVAL = 0.2
local TOP_COUNT = 5

-- ===== ชนิดข้อมูล =====
-- Entry = ดาเมจของผู้เล่น 1 คน · Boss = ข้อมูลบอสตัวที่อยู่ในแมพตอนนี้
type Entry = { userId: number, name: string, damage: number }
type Boss = {
	body: Instance, -- ของที่ลบทิ้งตอนบอสจบ (Model หรือลูกบอล)
	part: BasePart, -- จุดที่ป้อมเล็ง
	root: BasePart?, -- HumanoidRootPart (มีเฉพาะโมเดลจริง ใช้ขยับตอนเปิดตัว)
	tracks: { [string]: AnimationTrack },
	total: number, -- ดาเมจรวมทั้งเซิร์ฟ (บอสไม่มีเลือด)
	endsAt: number,
	damageBy: { [number]: Entry }, -- key = UserId (คนที่ออกไปแล้วยังอยู่ในตาราง แต่ไม่ได้รางวัล)
}

-- ===== สถานะระหว่างเกม (ระบบใช้เอง ห้ามแก้) =====
-- state = โฟลเดอร์ BossState · boss = บอสตัวปัจจุบัน (nil = ไม่มีบอส) · dirty = มีดาเมจใหม่รอส่งให้ Client
-- slammedEvent = สัญญาณ "บอสทุบพื้น" ที่ส่งออกไปให้ TurretService
local state: Folder
local boss: Boss? = nil
local dirty = false
local nextBoss = 1 -- ลำดับใน Combat.Boss.Rotation ของบอสตัวถัดไป
local slammedEvent = Instance.new("BindableEvent")

-- ===== ตำแหน่งและพื้น (ผังจากแมพ Tag หรือผังแอ่งเดิม) =====
-- มุมทั้ง 8 ของกล่อง (ใช้หาจุดต่ำสุดของชิ้นส่วน)
local CORNERS = {}
for _, x in { -1, 1 } do
	for _, y in { -1, 1 } do
		for _, z in { -1, 1 } do
			table.insert(CORNERS, Vector3.new(x, y, z))
		end
	end
end

-- ความสูงผิวพื้นที่รัศมี r จากกลางแมพ (แอ่งลึกเป็นขั้น)
local function floorAt(r: number): number
	local depth = 0
	for _, step in Map.Pit.Steps do
		if r < step.Outer then
			depth = math.max(depth, step.Depth)
		end
	end
	return Map.GroundY - depth
end

-- ความลึกของพื้นกลางแอ่ง (ขั้นในสุด)
local function pitFloorY(): number
	local deepest = 0
	for _, step in Map.Pit.Steps do
		deepest = math.max(deepest, step.Depth)
	end
	return Map.GroundY - deepest
end

-- จุดบอส: ผังจากแมพ (Tag BossSpawn) หรือกลางแมพเดิม (0, 0) · ยืนยัน 2026-09-27
local function bossCenter(): Vector3
	if LayoutService.hasLayout() then
		return LayoutService.bossCenter()
	end
	return Vector3.new(0, pitFloorY(), 0)
end

-- ความสูงพื้นใต้ตำแหน่ง: ผังจากแมพ = ยิงลำแสงหาพื้นจริง · ผังเดิม = ขั้นแอ่งรอบกลางแมพ
local function groundUnder(position: Vector3, ignore: { Instance }?): number
	if LayoutService.hasLayout() then
		return LayoutService.floorAt(position, ignore)
	end
	return floorAt(Vector3.new(position.X, 0, position.Z).Magnitude)
end

-- จุดเริ่มเดินเปิดตัว: ผังจากแมพ = ด้านหลังจุดบอส (ฝั่งตรงข้ามป้อม) · ผังเดิม = ทางทิศเหนือ
local function entranceStart(): Vector3
	if not LayoutService.hasLayout() then
		return Vector3.new(0, 0, -Combat.Boss.EntranceFrom)
	end
	local center = LayoutService.bossCenter()
	local sum = Vector3.zero
	for _, slot in LayoutService.slots() do
		local turret = LayoutService.turretTop(slot)
		local toward = Vector3.new(turret.X - center.X, 0, turret.Z - center.Z)
		if toward.Magnitude > 0.1 then
			sum += toward.Unit
		end
	end
	local back = if sum.Magnitude > 0.1 then -sum.Unit else Vector3.new(0, 0, -1)
	return Vector3.new(center.X, 0, center.Z) + back * Map.Layout.EntranceFrom
end

-- ระยะที่คลื่นทุบพื้นต้องแผ่ไปถึง (ป้อมที่ไกลที่สุด)
-- คืนระยะ (studs) ที่ใช้เป็นขนาดวงคลื่น: ไกลกว่าป้อมที่ไกลสุดเล็กน้อย
local function slamReach(center: Vector3): number
	if not LayoutService.hasLayout() then
		return Map.Base.TurretDistance * 2
	end
	local farthest = 20
	for _, slot in LayoutService.slots() do
		local turret = LayoutService.turretTop(slot)
		farthest = math.max(farthest, Vector3.new(turret.X - center.X, 0, turret.Z - center.Z).Magnitude)
	end
	return farthest * 2 + 10
end

-- เวลาของ Server ที่ Client เห็นตรงกัน (ใช้กับ EndsAt / NextAt)
local function now(): number
	return workspace:GetServerTimeNow()
end

-- ===== บอสสำรอง + ป้ายชื่อ =====
-- ติดป้าย "👹 BOSS" ลอยเหนือชิ้น parent สูง height studs (AlwaysOnTop = มองเห็นทะลุของบัง)
local function addLabel(parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = "👹 BOSS"
	label.Parent = gui
end

-- บอสสำรอง: ลูกบอลลอยกลางแมพ (ใช้เมื่อยังไม่ได้วางโมเดลใน ServerStorage)
local function makeBall(): (Instance, BasePart)
	local part = Instance.new("Part")
	part.Name = "Boss"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(14, 14, 14)
	part.Color = Color3.fromRGB(130, 60, 200)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(bossCenter() + Vector3.new(0, Combat.Boss.Height, 0))
	addLabel(part, 10)
	part.Parent = workspace
	return part, part
end

-- ===== ท่าทาง (อนิเมชัน) — ล็อก: แก้ได้แค่เพิ่มเลขท่าใน Config =====
-- ชื่อท่าที่ระบบรู้จัก · Slam เล่นครั้งเดียว ท่าอื่นเล่นวน (ดู loadTracks)
local ANIMATION_NAMES = { "Idle", "Walk", "Slam" }

-- หา ID ของท่า: เลขใน Config (ถ้าไม่ใช่ 0) ก่อน → ไม่งั้นใช้ Animation ชื่อเดียวกันในโฟลเดอร์ Animations ของโมเดล
-- (ใส่ AnimationId ในหน้าต่าง Properties ของ Studio ได้เลย) · คืน nil = ยังไม่มีท่านี้
-- animations = ตารางท่าของบอสตัวนั้น (Rotation[i].Animations หรือ Combat.Boss.Animations ของโรบอท)
local function animationIdFor(name: string, folder: Instance?, animations: { [string]: number }): string?
	local fromConfig = animations[name]
	if type(fromConfig) == "number" and fromConfig > 0 then
		-- %d กันเลขยาวถูกแปลงเป็นรูป 9.3e+13
		return `rbxassetid://{string.format("%d", fromConfig)}`
	end
	local item = folder and folder:FindFirstChild(name)
	if item and item:IsA("Animation") and item.AnimationId ~= "" then
		local id = item.AnimationId
		-- พิมพ์แค่ตัวเลข → เติม rbxassetid:// ให้
		return if string.match(id, "^%d+$") then `rbxassetid://{id}` else id
	end
	return nil
end

-- ท่าที่กด Save ไว้ใน Animation Editor (KeyframeSequence) ของโมเดลต้นแบบ
-- Studio เก็บไว้ใต้โมเดลโดยตรง, ใน <โมเดล>.AnimSaves หรือ ServerStorage.RBX_ANIMSAVES.<ชื่อโมเดล> `[Inferred]`
-- ไม่ต้องตั้งชื่อ: ชื่อที่มี idle/walk/slam = ใช้เป็นท่านั้น · ไม่งั้นท่าที่ยาวที่สุดเป็น Idle (เช่น "Imported Animation Clip")
local function studioSequences(template: Model): { [string]: KeyframeSequence }
	local found: { KeyframeSequence } = {}
	local places: { Instance? } = { template }
	local store = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	if store then
		table.insert(places, store:FindFirstChild(template.Name))
	end
	for _, place in places do
		if place then
			for _, item in place:GetDescendants() do
				if item:IsA("KeyframeSequence") and not table.find(found, item) then
					table.insert(found, item)
				end
			end
		end
	end
	local result = {}
	for _, sequence in found do
		local lower = string.lower(sequence.Name)
		for _, name in ANIMATION_NAMES do
			if not result[name] and string.find(lower, string.lower(name), 1, true) then
				result[name] = sequence
			end
		end
	end
	if not result.Idle then
		-- ไม่มีท่าชื่อ Idle → ใช้ท่าที่ยาวที่สุด (เช่นท่าเต้น "Imported Animation Clip")
		-- "Automatic Save" = ไฟล์เซฟอัตโนมัติของ Animation Editor มักว่าง/ไม่ใช่ท่าจริง → ใช้เป็นตัวเลือกสุดท้าย
		local best, bestScore = nil, -math.huge
		for _, sequence in found do
			local lower = string.lower(sequence.Name)
			if not string.find(lower, "walk", 1, true) and not string.find(lower, "slam", 1, true) then
				local length = 0
				for _, keyframe in sequence:GetKeyframes() do
					length = math.max(length, (keyframe :: Keyframe).Time)
				end
				local score = length - (if string.find(lower, "automatic", 1, true) then 1e6 else 0)
				if score > bestScore then
					best, bestScore = sequence, score
				end
			end
		end
		result.Idle = best
	end
	return result
end

-- โหลดท่า · คืนตาราง ชื่อท่า → AnimationTrack
-- ใน Studio: ใช้ท่าที่ Save ไว้ใน Animation Editor ก่อน (เห็นท่าล่าสุดทันที ไม่ต้อง Publish ไม่ติดเรื่องเจ้าของ)
-- เกมจริง: ใช้เลข ID ที่ Publish แล้ว (Config หรือโฟลเดอร์ Animations ในโมเดล)
-- คืน {} ถ้าไม่มีท่าเลย (บอสยืนนิ่ง) · ถ้าท่าโหลดไม่ขึ้น จะ warn บอกเหตุผลใน Output หลัง 3 วิ
local function loadTracks(
	model: Model,
	sequences: { [string]: KeyframeSequence },
	animations: { [string]: number }
): { [string]: AnimationTrack }
	local tracks = {}
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	local controller: Instance? = humanoid or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	local folder = model:FindFirstChild("Animations")
	local inStudio = RunService:IsStudio()
	for _, name in ANIMATION_NAMES do
		local id = animationIdFor(name, folder, animations)
		local publishedId = id
		local source = "ID ที่ Publish"
		local sequence = sequences[name]
		if inStudio and sequence then
			local ok, tempId = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
			end)
			if ok then
				id = tempId
				source = `ท่าที่ Save ใน Studio "{sequence.Name}"`
			end
		end
		if id then
			local animation = Instance.new("Animation")
			animation.Name = name
			animation.AnimationId = id
			local ok, result = pcall(function()
				return (animator :: Animator):LoadAnimation(animation)
			end)
			if ok then
				result.Looped = name ~= "Slam"
				result.Priority = if name == "Slam" then Enum.AnimationPriority.Action else Enum.AnimationPriority.Idle
				tracks[name] = result
				print(`[BossService] ท่า {name} ใช้{source}`)
				-- LoadAnimation ไม่ error ถ้าโหลดไม่ขึ้น → เช็กความยาวท่าภายหลัง
				task.delay(3, function()
					if result.Length == 0 and publishedId and id ~= publishedId and tracks[name] == result then
						-- ท่าที่ Save ใน Studio เล่นไม่ขึ้น → เปลี่ยนไปใช้ ID ที่ Publish แทน
						local fallback = Instance.new("Animation")
						fallback.AnimationId = publishedId
						local loaded, track = pcall(function()
							return (animator :: Animator):LoadAnimation(fallback)
						end)
						if loaded then
							track.Looped = result.Looped
							track.Priority = result.Priority
							tracks[name] = track
							if result.IsPlaying then
								result:Stop(0)
								track:Play(0.2)
							end
							warn(`[BossService] ท่า {name} จาก Studio เล่นไม่ขึ้น → เปลี่ยนไปใช้ ID ที่ Publish ({publishedId})`)
							task.delay(3, function()
								if track.Length == 0 then
									warn(
										`[BossService] ท่า {name} โหลดไม่ขึ้นทั้งสองแบบ — ID {publishedId} อาจ Publish ด้วยบัญชี/Group ที่ไม่ใช่เจ้าของเกม`
									)
								end
							end)
						end
					elseif result.Length == 0 then
						warn(
							`[BossService] ท่า {name} โหลดไม่ขึ้น ({id}) — มักเป็นเพราะ Publish ด้วยบัญชี/Group ที่ไม่ใช่เจ้าของเกม`
								.. " หรือยังไม่ได้ Save ท่าใน Animation Editor"
						)
					end
				end)
			else
				warn(`[BossService] โหลดท่า {name} ({id}) ไม่สำเร็จ: {result}`)
			end
		end
	end
	if next(tracks) == nil then
		warn(
			`[BossService] บอส {model.Name} ยังไม่มีท่า — ใส่ AnimationId ที่ ServerStorage > Bosses > {model.Name} > Animations`
				.. " หรือใส่เลขใน Config/Combat.luau (Boss.Animations)"
		)
	end
	return tracks
end

-- ===== หาโมเดลบอส — ล็อก ห้ามแก้ =====
-- ชื่อแบบยืดหยุ่น: ตัวเล็กหมด ตัดช่องว่าง/ขีด/_ และคำว่า boss → "Slambot", "Slam-Bot", "boss_slambot" = "slambot"
local function normalizeName(name: string): string
	local simple = string.gsub(string.lower(name), "[^%w]", "")
	return (string.gsub(simple, "boss", ""))
end

-- ใช่โมเดลบอสชื่อ name ไหม: เป็น Model + ชื่อตรงแบบยืดหยุ่น + มี HumanoidRootPart อยู่ข้างใน (ชั้นไหนก็ได้)
local function isBossModel(item: Instance, name: string): boolean
	return item:IsA("Model")
		and normalizeName(item.Name) == normalizeName(name)
		and item:FindFirstChild("HumanoidRootPart", true) ~= nil -- FBX อาจซ้อนชิ้นส่วนไว้ในโมเดลย่อย
end

-- หาโมเดลต้นแบบ: ServerStorage > Bosses ก่อน แล้วค่อยใน Workspace (ผู้ใช้อาจวางไว้ในแมพ)
local function findTemplate(name: string): Model?
	local folder = ServerStorage:FindFirstChild("Bosses")
	if folder then
		for _, item in folder:GetChildren() do
			if isBossModel(item, name) then
				return item :: Model
			end
		end
	end
	for _, item in workspace:GetDescendants() do
		if isBossModel(item, name) then
			return item :: Model
		end
	end
	return nil
end

-- ===== ข้อต่อ/ริก — ล็อก ห้ามแก้ (อ่าน docs/boss-slambot-known-good.md) =====
-- ข้อต่อมาตรฐาน R15: ชิ้นลูก → (ชิ้นแม่, ชื่อข้อต่อ)
local R15_JOINTS = {
	LowerTorso = { "HumanoidRootPart", "Root" },
	UpperTorso = { "LowerTorso", "Waist" },
	Head = { "UpperTorso", "Neck" },
	LeftUpperArm = { "UpperTorso", "LeftShoulder" },
	LeftLowerArm = { "LeftUpperArm", "LeftElbow" },
	LeftHand = { "LeftLowerArm", "LeftWrist" },
	RightUpperArm = { "UpperTorso", "RightShoulder" },
	RightLowerArm = { "RightUpperArm", "RightElbow" },
	RightHand = { "RightLowerArm", "RightWrist" },
	LeftUpperLeg = { "LowerTorso", "LeftHip" },
	LeftLowerLeg = { "LeftUpperLeg", "LeftKnee" },
	LeftFoot = { "LeftLowerLeg", "LeftAnkle" },
	RightUpperLeg = { "LowerTorso", "RightHip" },
	RightLowerLeg = { "RightUpperLeg", "RightKnee" },
	RightFoot = { "RightLowerLeg", "RightAnkle" },
}
-- ลำดับซ่อม: จากลำตัวออกไปปลายแขนขา (ชิ้นแม่ต้องต่อกับ root ก่อน)
local R15_ORDER = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- ชิ้นที่ต่อถึง root ผ่านข้อต่อ (Motor6D / Weld / WeldConstraint) — คำนวณเองไม่ต้องพึ่งฟิสิกส์
-- คืนตาราง { [ชิ้น] = true } ของทุกชิ้นที่ต่อถึง root (รวม root เอง) · ใช้ทั้งซ่อมข้อต่อและเลือกตัวรากจริง
local function connectedToRoot(model: Model, root: BasePart): { [BasePart]: boolean }
	local links: { [BasePart]: { BasePart } } = {}
	local function link(a: any, b: any)
		if typeof(a) == "Instance" and typeof(b) == "Instance" and a:IsA("BasePart") and b:IsA("BasePart") then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("JointInstance") then
			link(item.Part0, item.Part1)
		elseif item:IsA("WeldConstraint") then
			link(item.Part0, item.Part1)
		elseif item:IsA("Constraint") then
			-- ริกแบบใหม่ของ Roblox (AnimationConstraint) และ constraint อื่นต่อชิ้นผ่าน Attachment
			local a0, a1 = item.Attachment0, item.Attachment1
			if a0 and a1 then
				link(a0.Parent, a1.Parent)
			end
		end
	end
	local seen = { [root] = true }
	local queue = { root }
	while #queue > 0 do
		local part = table.remove(queue) :: BasePart
		for _, other in links[part] or {} do
			if not seen[other] then
				seen[other] = true
				table.insert(queue, other)
			end
		end
	end
	return seen
end

-- ซ่อมริกที่ชิ้นส่วนไม่ได้ต่อกับ root (FBX บางไฟล์ไม่มีข้อต่อ → ตัวร่วงทะลุแมพ เหลือ root ค้าง)
-- ชิ้น R15 → สร้าง Motor6D ตามมาตรฐาน (ท่าจาก Animation Editor ขยับได้) · ชิ้นอื่น → เชื่อมติดชิ้นที่ใกล้ที่สุด
-- คู่ข้อต่อ (ชิ้นแม่, ชิ้นลูก) จากโครงของท่า: Pose ซ้อนกันตามข้อต่อที่ท่าคาดไว้
-- ท่าเล่นได้ก็ต่อเมื่อข้อต่อในตัวต่อ "แม่ → ลูก" ตรงกับท่า `[Inferred]` (ท่านี้ขาต่อกับตัวราก ไม่ใช่ LowerTorso แบบ R15)
-- poseLinks: อ่านท่าเฟรมแรก คืนรายการคู่ { ชื่อชิ้นแม่, ชื่อชิ้นลูก } · ไม่มีท่า = ตารางว่าง
local function poseLinks(sequence: KeyframeSequence?, rootName: string): { { string } }
	local links = {}
	if not sequence then
		return links
	end
	local keyframe = sequence:GetKeyframes()[1]
	if not keyframe then
		return links
	end
	local function walk(pose: Instance, parentName: string)
		for _, sub in (pose :: Pose):GetSubPoses() do
			table.insert(links, { parentName, sub.Name })
			walk(sub, sub.Name)
		end
	end
	for _, top in (keyframe :: Keyframe):GetPoses() do
		-- Pose บนสุดคือตัวราก (ชื่ออาจไม่ตรงกับชิ้นในโมเดล)
		walk(top, rootName)
	end
	return links
end

-- จุดหมุนข้อต่อ: กระดูกชื่อเดียวกันถ้ามี · ไม่งั้นขอบของชิ้นลูกฝั่งที่หันเข้าหาชิ้นแม่ (ไหล่ สะโพก เข่า)
local function jointPivot(model: Model, parent: BasePart, child: BasePart, root: BasePart): Vector3
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") and item.Name == child.Name then
			return item.WorldPosition
		end
	end
	if parent == root then
		return child.Position
	end
	local toward = parent.Position - child.Position
	if toward.Magnitude < 0.01 then
		return child.Position
	end
	local unit = toward.Unit
	local half = child.Size / 2
	local cf = child.CFrame
	local reach = math.abs(cf.RightVector:Dot(unit)) * half.X
		+ math.abs(cf.UpVector:Dot(unit)) * half.Y
		+ math.abs(cf.LookVector:Dot(unit)) * half.Z
	return child.Position + unit * reach
end

-- animate = false (บอสไม่มีท่า เช่นกระต่าย) → ไม่สร้าง Motor6D แค่เชื่อมชิ้นที่หลุดให้ติดกัน
-- repairJoints: ซ่อมข้อต่อตามคำอธิบายเหนือ poseLinks · คืนจำนวนจุดที่ซ่อม (ใช้พิมพ์ลง Output)
local function repairJoints(model: Model, root: BasePart, sequence: KeyframeSequence?, animate: boolean): number
	local repaired = 0
	local connected = connectedToRoot(model, root)
	-- ริกแบบกระดูก (Bone จาก FBX): ท่าขยับที่กระดูก ไม่ใช่ที่ชิ้นส่วน → แค่เชื่อมทุกชิ้นให้ติดกัน ห้ามสร้าง Motor6D (ท่าจะซ้อนกันสองชั้น)
	local usesBones = model:FindFirstChildWhichIsA("Bone", true) ~= nil
	-- ลำดับข้อต่อ: ตามโครงของท่าถ้ามี (เล่นท่าได้แน่) · ไม่มีท่า → มาตรฐาน R15
	local links = poseLinks(sequence, root.Name)
	if #links == 0 then
		for _, childName in R15_ORDER do
			table.insert(links, { R15_JOINTS[childName][1], childName })
		end
	end
	-- ปิดการสร้างข้อต่อได้จาก Config (ทดสอบว่าข้อต่อที่เราสร้างทำให้ตัวล้มไหม) → เหลือแค่เชื่อมชิ้นที่หลุดให้ติดกัน
	local createMotors = animate and not usesBones and Combat.Boss.RepairJoints ~= false
	for _, pair in (if createMotors then links else {}) do
		local parent = if pair[1] == root.Name then root else model:FindFirstChild(pair[1], true)
		local child = model:FindFirstChild(pair[2], true)
		if child and child:IsA("BasePart") and child ~= root and not connected[child] and parent and parent:IsA("BasePart") and connected[parent] then
			local pivot = jointPivot(model, parent, child, root)
			local joint = Instance.new("Motor6D")
			local info = R15_JOINTS[child.Name]
			joint.Name = if info then info[2] else child.Name
			joint.Part0 = parent :: BasePart
			joint.Part1 = child
			joint.C0 = (parent :: BasePart).CFrame:Inverse() * CFrame.new(pivot)
			joint.C1 = child.CFrame:Inverse() * CFrame.new(pivot)
			joint.Parent = child
			connected[child] = true
			repaired += 1
		end
	end
	local anchors = {}
	for part in connected do
		table.insert(anchors, part)
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and not connected[item] then
			local nearest, best = root, math.huge
			for _, anchor in anchors do
				local distance = (anchor.Position - item.Position).Magnitude
				if distance < best then
					nearest, best = anchor, distance
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = nearest
			weld.Part1 = item
			weld.Parent = item
			item.Massless = true -- ชิ้นช่วยที่ติดมา (เช่น HumanoidRootPart อันที่สอง) ไม่ให้มีน้ำหนักถ่วงตัวบอส
			repaired += 1
		end
	end
	return repaired
end

-- ===== สร้างตัวบอสและวางตัว — ล็อก ห้ามแก้ =====
-- บอสจริงจากโมเดลต้นแบบ (findTemplate) · คืน nil ถ้าไม่มีโมเดล
-- คืน (โมเดล, ชิ้นที่ป้อมเล็ง, ตัวราก, ท่าที่ Save ใน Studio) · เรียกจาก spawnBoss
local function makeModel(
	name: string,
	animate: boolean,
	animations: { [string]: number }
): (Model?, BasePart?, BasePart?, { [string]: KeyframeSequence })
	local template = findTemplate(name)
	if not template then
		warn(
			`[BossService] ไม่เจอโมเดลบอสชื่อ "{name}" (ต้องมี HumanoidRootPart) ใน ServerStorage > Bosses หรือ Workspace`
		)
		return nil, nil, nil, {}
	end

	local sequences = if animate then studioSequences(template) else {}
	local model = template:Clone()
	-- AnimSaves = ท่าร่างที่ Animation Editor เก็บไว้ในโมเดล ไม่ต้องใช้ตอนเล่นจริง
	local drafts = model:FindFirstChild("AnimSaves")
	if drafts then
		drafts:Destroy()
	end
	for _, item in model:GetDescendants() do
		if item:IsA("KeyframeSequence") then
			item:Destroy() -- ท่าร่างที่ Save ไว้ใต้โมเดลโดยตรง (ใช้ผ่าน studioSequences ของตัวต้นแบบแล้ว)
		end
	end
	local candidates: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") then
			item:Destroy() -- โมเดลจากภายนอกห้ามพาสคริปต์เข้ามา
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.Anchored = false
			if item.Name == "HumanoidRootPart" then
				table.insert(candidates, item)
				-- ทุกชิ้นชื่อนี้เป็นกล่องช่วย ไม่ต้องเห็น (FBX มี HumanoidRootPart ติดมา 2 อัน = บล็อกสีเข้มในตัวบอส)
				item.Transparency = 1
				item.CanQuery = false
			end
		end
	end
	-- ตัวรากจริง = HumanoidRootPart ที่ต่อกับชิ้นอื่นมากที่สุด (ข้อต่อ AnimationConstraint ต่อกับอันนี้)
	-- ถ้ายึดผิดอัน ตัวจริงจะไม่ถูกยึด → บอสล้ม/ร่วง (บั๊ก 2026-09-27)
	local root: BasePart? = nil
	local bestLinks = -1
	for _, candidate in candidates do
		local linked = 0
		for _ in connectedToRoot(model, candidate) do
			linked += 1
		end
		if linked > bestLinks then
			root, bestLinks = candidate, linked
		end
	end
	root = root or model.PrimaryPart
	if not root then
		warn(`[BossService] โมเดล {model.Name} ไม่มี HumanoidRootPart — ใช้ลูกบอลแทน`)
		model:Destroy()
		return nil, nil, nil, {}
	end
	-- ยึดแค่ตัวราก ชิ้นอื่นขยับตามข้อต่อตามท่า
	root.Anchored = true
	if #candidates > 1 then
		print(`[BossService] เจอ HumanoidRootPart {#candidates} อัน → ใช้ {root:GetFullName()} (ต่อกับ {bestLinks - 1} ชิ้น) เป็นตัวราก`)
	end
	model.PrimaryPart = root
-- ตั้งแต่ตรงนี้ถึง print "ชิ้นส่วน … ข้อต่อเดิม" = พิมพ์ข้อมูลริกลง Output ไว้ดูตอนแก้ปัญหา (ไม่ได้เปลี่ยนตัวบอส)
	local counts = { Motor6D = 0, AnimationConstraint = 0, Bone = 0 }
	for _, item in model:GetDescendants() do
		if counts[item.ClassName] then
			counts[item.ClassName] += 1
		end
	end
	local humanoid0 = model:FindFirstChildWhichIsA("Humanoid", true)
	print(
		`[BossService] ริกของ {model.Name}: Motor6D {counts.Motor6D} · AnimationConstraint {counts.AnimationConstraint} · Bone {counts.Bone}`
			.. ` · Humanoid {if humanoid0 then humanoid0:GetFullName() else "ไม่มี"}`
	)
	-- โครงข้อต่อเอาจากท่า Idle: ท่าที่ Save ใน Studio หรือท่าที่ Publish (โหลดจาก Roblox)
	local shape: KeyframeSequence? = sequences.Idle or sequences.Walk or sequences.Slam
	local idleId = animations.Idle
	if animate and not shape and type(idleId) == "number" and idleId > 0 then
		local ok, result = pcall(function()
			return KeyframeSequenceProvider:GetKeyframeSequenceAsync(`rbxassetid://{string.format("%d", idleId)}`)
		end)
		if ok and result and result:IsA("KeyframeSequence") then
			shape = result
		end
	end
	if shape then
		local shown = {}
		for index, pair in poseLinks(shape, root.Name) do
			if index <= 6 then
				table.insert(shown, `{pair[1]}→{pair[2]}`)
			end
		end
		print(`[BossService] โครงข้อต่อตามท่า "{shape.Name}": {table.concat(shown, ", ")} …`)
	end
	local roots, parts = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
			if item.Name == "HumanoidRootPart" then
				roots += 1
			end
		end
	end
	local joints = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and #joints < 20 then
			local p0, p1 = item.Part0, item.Part1
			table.insert(joints, `{if p0 then p0.Name else "?"}→{if p1 then p1.Name else "?"}`)
		end
	end
	print(
		`[BossService] ชิ้นส่วน {parts} ชิ้น · HumanoidRootPart {roots} อัน · ข้อต่อเดิม: {if #joints > 0 then table.concat(joints, ", ") else "ไม่มี"}`
	)
	local repaired = repairJoints(model, root, shape, animate)
	if repaired > 0 then
		local kind = if model:FindFirstChildWhichIsA("Bone", true) then "ริกกระดูก (Bone): เชื่อมชิ้นให้ติดกัน ท่าขยับที่กระดูก" else "ริก Motor6D"
		print(`[BossService] ซ่อมข้อต่อในตัวบอส {repaired} จุด · {kind} (ชิ้นที่ไม่ได้ต่อกับ HumanoidRootPart จะร่วงทะลุแมพ)`)
	end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false -- ริกจากภายนอกอาจไม่มีข้อต่อคอ → ไม่ให้ Humanoid ถือว่าตาย
		-- บอสไม่ต้องเดิน/ล้ม/ตายแบบตัวละคร → ปิดระบบสถานะของ Humanoid (กันล้มหรือนอนราบเอง)
		humanoid.EvaluateStateMachine = false
		humanoid.PlatformStand = true
		for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Dead } do
			humanoid:SetStateEnabled(state, false)
		end
	end

	-- วางให้เท้าแตะพื้นที่ขอบแอ่ง: หันหน้าเข้ากลางก่อน แล้ววัดจุดต่ำสุดของตัวจริงในโลก
	-- (ไม่ใช้ GetBoundingBox เพราะกล่องหมุนตามตัวราก ถ้าโมเดลจาก Blender หมุนแกนมา ความสูงจะผิด → จม/ลอย)
	-- เก็บการหมุนเดิมของตัวราก: FBX จาก Blender หมุนแกนมา 90° ถ้าบังคับให้ตัวรากตั้งตรง (CFrame.lookAt) บอสจะนอนราบ (บั๊ก 2026-09-27)
	-- ทิศหน้าบอส = ทิศที่วางโมเดลไว้ใน Studio (อยากให้หันทางอื่น → หมุนโมเดลใน Studio แล้ว Ctrl+S)
	local startXZ = entranceStart()
	local rest = model:GetPivot().Rotation
	model:PivotTo(CFrame.new(startXZ) * rest)
	local lowest, highest = math.huge, -math.huge
	for _, item in model:GetDescendants() do
		-- ข้ามชิ้นล่องหน (HumanoidRootPart / ชิ้นช่วย) ที่อาจยื่นเลยเท้า
		if item:IsA("BasePart") and item.Transparency < 1 then
			local half = item.Size / 2
			for _, corner in CORNERS do
				local y = (item.CFrame * (half * corner)).Y
				lowest = math.min(lowest, y)
				highest = math.max(highest, y)
			end
		end
	end
	if lowest == math.huge then
		lowest, highest = root.Position.Y, root.Position.Y
	end
	local rootToBottom = model:GetPivot().Y - lowest + Combat.Boss.GroundOffset
	local floor = groundUnder(startXZ)
	model:SetAttribute("RootToBottom", rootToBottom)
	model:PivotTo(model:GetPivot() + Vector3.new(0, floor + rootToBottom - model:GetPivot().Y, 0))
	print(
		`[BossService] วาง {model.Name}: ตัวสูง {math.floor(highest - lowest + 0.5)} studs · เท้าห่างจุดหมุน {string.format("%.1f", rootToBottom)} · พื้นขอบแอ่ง Y={floor}`
			.. ` (ยังจม/ลอย → ปรับ Boss.GroundOffset ใน Config/Combat.luau)`
	)
	local height = highest - lowest

-- ป้อมเล็งที่ UpperTorso (กลางตัว) ถ้ามี · ไม่มี → เล็งตัวราก
	local aim = model:FindFirstChild("UpperTorso", true)
	local target = if aim and aim:IsA("BasePart") then aim else root
	addLabel(target, height * 0.6)
	model.Parent = workspace
	return model, target, root, sequences
end

-- ===== ท่าทุบพื้น (Slam) =====
-- เอฟเฟกต์ทุบพื้น: วงคลื่นกระแทก + ก้อนบล็อกกระเด็น (ลบเองอัตโนมัติ)
local function slamEffect(center: Vector3)
	local y = groundUnder(center, if boss then { boss.body } else nil)
	local ring = Instance.new("Part")
	ring.Name = "SlamWave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 196, 92)
	ring.Size = Vector3.new(0.6, 8, 8)
	ring.CFrame = CFrame.new(center.X, y + 0.4, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	local reach = slamReach(center)
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.6, reach, reach),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)

	local rng = Random.new()
	for _ = 1, 12 do
		local chunk = Instance.new("Part")
		chunk.Name = "SlamDebris"
		chunk.Size = Vector3.one * rng:NextNumber(1.5, 3)
		chunk.Color = Color3.fromRGB(255, 214, 110):Lerp(Color3.fromRGB(200, 116, 42), rng:NextNumber())
		chunk.Material = Enum.Material.Plastic
		chunk.CanCollide = false
		chunk.CanTouch = false
		chunk.CanQuery = false
		local angle = rng:NextNumber(0, 2 * math.pi)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
		chunk.CFrame = CFrame.new(Vector3.new(center.X, y + 1, center.Z) + offset * rng:NextNumber(4, 10))
		chunk.AssemblyLinearVelocity = offset * rng:NextNumber(20, 45) + Vector3.new(0, rng:NextNumber(30, 55), 0)
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1.5)
	end
end

-- onHit ทำงานครั้งเดียวต่อการทุบ (ตัวแปร hit กันซ้ำ เพราะทั้ง Marker และตัวจับเวลาอาจเรียกทั้งคู่)
-- จังหวะกระแทกของท่า Slam ครั้งเดียว (ลบเอฟเฟกต์เองถ้าบอสจบกลางท่า)
local function slam(current: Boss)
	local track = current.tracks.Slam
	local hit = false
	local function onHit()
		if hit or boss ~= current then
			return
		end
		hit = true
		slamEffect(current.part.Position)
		slammedEvent:Fire(Combat.Boss.SlamDamage)
	end
	if track then
		local connection = track:GetMarkerReachedSignal("Hit"):Connect(onHit)
		track:Play()
		task.delay(track.Length > 0 and track.Length or 3, function()
			connection:Disconnect()
		end)
	end
	-- ไม่มี Marker "Hit" (หรือไม่มีท่า) → ใช้เวลาใน Config แทน
	task.delay(Combat.Boss.SlamHitDelay, onHit)
end

-- ===== เท้าติดพื้นตลอดท่า (PlantFeet) — เปิดเฉพาะบอสที่ใส่ PlantFeet = true ในแถว Rotation =====
-- ปัญหา: ท่า Motion Capture งอเข่าแต่สะโพกไม่ลดตาม → ขาพับขึ้น เท้าลอยจากพื้น (บั๊ก 2026-09-29 กระต่ายทุบพื้น)
-- แก้: ทุกเฟรมวัดจุดต่ำสุดของชิ้นที่มองเห็น แล้วเลื่อนทั้งตัวขึ้น/ลงให้จุดนั้นแตะพื้นพอดี (ตัวรากยังยึดอยู่ → ไม่ร่วงแมพ)
-- ข้ามเฟรมที่บอสกำลังเดินเปิดตัว (ตำแหน่งแนวนอนเปลี่ยน) ให้โค้ดเดินที่ล็อกไว้คุมเอง · ไม่แตะการหมุน ไม่แตะข้อต่อ
-- ตำแหน่งชิ้นส่วนฝั่ง Server ตามท่าที่เล่นอยู่ [Inferred] · ท่าที่ลอยในหน้า Animation Editor ยังต้องแก้ในท่าเอง (โค้ดไม่ทำงานในหน้าแก้ท่า)
local MAX_PLANT_STEP = 4 -- studs ต่อเฟรม (กันกระชากถ้าวัดพลาด เช่น ชิ้นหลุดกระเด็น)

local function plantFeet(current: Boss, model: Model)
	local lastXZ: Vector3? = nil
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if boss ~= current or model.Parent == nil then
			connection:Disconnect()
			return
		end
		local pivot = model:GetPivot()
		local xz = Vector3.new(pivot.X, 0, pivot.Z)
		local walking = lastXZ ~= nil and (xz - lastXZ).Magnitude > 0.01
		lastXZ = xz
		if walking then
			return
		end
		local lowest = math.huge
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item.Transparency < 1 then
				local half = item.Size / 2
				for _, corner in CORNERS do
					lowest = math.min(lowest, (item.CFrame * (half * corner)).Y)
				end
			end
		end
		if lowest == math.huge then
			return
		end
		local target = groundUnder(pivot.Position, { model }) + Combat.Boss.GroundOffset
		local delta = math.clamp(target - lowest, -MAX_PLANT_STEP, MAX_PLANT_STEP)
		if math.abs(delta) > 0.02 then
			model:PivotTo(pivot + Vector3.new(0, delta, 0)) -- เลื่อนแค่แนวตั้ง คงการหมุนเดิม
		end
	end)
end

-- ===== พฤติกรรมบอส (เดินเปิดตัว → ยืน → ทุบวน) =====
-- เรียกผ่าน task.spawn ตอนบอสเกิด · ทุกลูปเช็ก boss == current → บอสจบเมื่อไหร่ ลูปหยุดเอง
-- เปิดตัว (เดินเข้ากลาง) → Idle → วนทุบทุก SlamInterval จนบอสจบ
local function runBehaviour(current: Boss)
	local tracks = current.tracks
	local root = current.root
	-- ท่ายืน/เต้นเล่นวนตั้งแต่เกิด · มีท่าเดินค่อยใช้ท่าเดินช่วงเปิดตัว
	local function playIdle()
		local idle = current.tracks.Idle
		if idle and not idle.IsPlaying then
			idle.Looped = true
			idle:Play(0.3)
			task.delay(1, function()
				print(`[BossService] ท่า Idle กำลังเล่น={idle.IsPlaying} ยาว {string.format("%.1f", idle.Length)} วิ`)
			end)
		end
	end
	if not tracks.Walk then
		playIdle()
	end
	if root then
		if tracks.Walk then
			tracks.Walk:Play()
		end
		-- การเดินเปิดตัว (ล็อก): ต้องใช้ CFrame.new(ตำแหน่ง) * rest เสมอ ห้ามเปลี่ยนเป็น CFrame.lookAt → บอสนอนราบ
		-- lift = ระยะจุดหมุนถึงเท้าที่วัดไว้ใน makeModel · t = ความคืบหน้า 0 → 1 ตลอด EntranceSeconds วินาที
		local model = current.body :: Model
		local rest = model:GetPivot().Rotation
		local lift = model:GetAttribute("RootToBottom") or 0
		local from = model:GetPivot().Position
		local centerPoint = bossCenter()
		local to = Vector3.new(centerPoint.X, from.Y, centerPoint.Z)
		local started = os.clock()
		while boss == current do
			local t = math.min((os.clock() - started) / Combat.Boss.EntranceSeconds, 1)
			local flat = from:Lerp(to, t)
			-- เดินลงขั้นบันไดของแอ่ง: ปรับความสูงตามพื้นใต้เท้า
			local position = Vector3.new(flat.X, groundUnder(flat, { model }) + lift, flat.Z)
			model:PivotTo(CFrame.new(position) * rest) -- คงการหมุนเดิม ไม่ให้บอสนอน
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if tracks.Walk then
			tracks.Walk:Stop(0.3)
		end
	end
	if boss ~= current then
		return
	end
	playIdle()
	while boss == current do
		task.wait(Combat.Boss.SlamInterval)
		if boss ~= current then
			break
		end
		slam(current)
	end
end

-- ===== อันดับดาเมจ + ส่งสถานะให้ Client =====
-- เรียงผู้เล่นตามดาเมจ มาก → น้อย (คืนรายการ Entry)
local function sortedEntries(current: Boss): { Entry }
	local list = {}
	for _, entry in current.damageBy do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.damage > b.damage
	end)
	return list
end

-- ส่งดาเมจรวม, Top (JSON) และดาเมจของแต่ละคน (Player Attribute BossDamage) ให้ Client · เรียกจาก Start เมื่อ dirty
local function publish(current: Boss)
	state:SetAttribute("TotalDamage", math.floor(current.total))
	local top = {}
	for index, entry in sortedEntries(current) do
		if index > TOP_COUNT then
			break
		end
		table.insert(top, { n = entry.name, d = math.floor(entry.damage) })
	end
	state:SetAttribute("Top", HttpService:JSONEncode(top))
	for userId, entry in current.damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("BossDamage", math.floor(entry.damage))
		end
	end
end

-- ===== เกิดบอส / จบรอบ =====
-- เกิดบอสตัวถัดไปใน Rotation แล้วเริ่มพฤติกรรม + รีเซ็ตค่าใน BossState · เรียกจาก Start เมื่อถึงเวลา NextAt
local function spawnBoss()
	local body: Instance, part: BasePart
	local tracks = {}
	-- เลือกบอสตัวถัดไปใน Rotation · หาโมเดลไม่เจอ → ลองตัวถัดไป · ไม่เจอเลย → ลูกบอลสำรอง
	local rotation = Combat.Boss.Rotation
	local model, target, root, sequences = nil, nil, nil, {}
	local chosen = nil -- แถว Rotation ของบอสที่เกิดจริงรอบนี้
	for _ = 1, #rotation do
		local entry = rotation[nextBoss]
		-- เลื่อนลำดับไปตัวถัดไป วนกลับตัวแรกเมื่อสุดรายการ
		nextBoss = nextBoss % #rotation + 1
		-- ท่าของบอสตัวนี้: ใส่ไว้ในแถว Rotation ก็ได้ · ไม่ใส่ = ใช้ Combat.Boss.Animations (ท่าโรบอท)
		local animations = entry.Animations or Combat.Boss.Animations
		model, target, root, sequences = makeModel(entry.Model, entry.Animate, animations)
		if model and target then
			chosen = entry
			print(`[BossService] บอสรอบนี้: {entry.Model} ({if entry.Animate then "มีท่า" else "ยืนเฉย ไม่มีท่า"})`)
			if entry.Animate then
				tracks = loadTracks(model, sequences, animations)
			end
			break
		end
	end
	if model and target then
		body, part = model, target
	else
		warn("[BossService] ไม่เจอโมเดลบอสใน Rotation เลย — ใช้ลูกบอลแทน")
		body, part = makeBall()
	end
	local current: Boss = {
		body = body,
		part = part,
		root = root,
		tracks = tracks,
		total = 0,
		endsAt = now() + Combat.Boss.Duration,
		damageBy = {},
	}
	boss = current
	if chosen and chosen.PlantFeet and model then
		plantFeet(current, model)
	end
	task.spawn(runBehaviour, current)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BossDamage", 0)
	end
	state:SetAttribute("TotalDamage", 0)
	state:SetAttribute("EndsAt", boss.endsAt)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state:SetAttribute("Active", true)
end

-- ครบเวลา: บอสจากไป → แจกเงิน (ขั้นต่ำ + ตามสัดส่วนดาเมจ) + อุปกรณ์ป้อม (ทุกคนที่ตี + โบนัสตาม share/อันดับต้น)
local function finish(current: Boss)
	boss = nil
	current.body:Destroy()
	publish(current)

	local ranking = sortedEntries(current)
	local total = 0
	for _, entry in ranking do
		total += entry.damage
	end
	-- เงินที่ได้ = BaseReward + DamageRewardPool × (ดาเมจตัวเอง ÷ ดาเมจรวม) · คนที่ออกจากเกมไปแล้วไม่ได้รางวัล
	for rank, entry in ranking do
		local player = Players:GetPlayerByUserId(entry.userId)
		if player and total > 0 and entry.damage > 0 then
			Wallet.earn(player, Economy.Boss.BaseReward + Economy.Boss.DamageRewardPool * entry.damage / total)
			-- ✏️ แก้เฉพาะรางวัล (เจ้าของเกมสั่งถอดกาชา 2026-09-30): ตั๋วกาชา → อุปกรณ์ป้อม · ส่วนโมเดล/ท่าบอสที่ล็อกไม่ได้แตะ
			-- pcall: ถ้าแจกของคนหนึ่งพลาด คนถัดไปยังได้รางวัลตามปกติ
			local ok, err = pcall(GearService.grantBossDrops, player, rank, entry.damage / total)
			if not ok then
				warn(`[BossService] แจกอุปกรณ์ไม่สำเร็จ {player.Name}: {err}`)
			end
		end
	end

	if total > 0 then
		state:SetAttribute(
			"Result",
			`⏰ บอสจากไปแล้ว! 🏆 {ranking[1].name} · ได้เงิน + 🛠️ อุปกรณ์ตามดาเมจ`
		)
	else
		state:SetAttribute("Result", "⏰ บอสจากไปแล้ว… ไม่มีใครทำดาเมจ")
	end
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.Interval)
end

-- ===== API ให้ไฟล์อื่นเรียก =====
local BossService = {}

-- ยิงเมื่อบอสทุบพื้นถึงจังหวะกระแทก: (ดาเมจต่อป้อม)
BossService.Slammed = slammedEvent.Event

-- มีบอสอยู่ในแมพตอนนี้หรือไม่ (ตั้งแต่เกิดจนตาย/หนี)
function BossService.isActive(): boolean
	return boss ~= nil
end

-- บอสที่ตีได้ตอนนี้ (nil ถ้าไม่มี)
function BossService.getTarget(): Vector3?
	if boss then
		return boss.part.Position
	end
	return nil
end

-- นับดาเมจที่ player ทำใส่บอส · เรียกจาก TurretClassService.damageBoss (ตอนป้อมยิงโดน)
-- amount ~= amount = เช็กค่า NaN (ตัวเลขเสีย) ไม่ให้เข้ามาปนยอดรวม
function BossService.damage(player: Player, amount: number)
	local current = boss
	if not current or amount <= 0 or amount ~= amount then
		return
	end
	-- บอสไม่มีเลือด: นับดาเมจทุกนัดจนหมดเวลา
	local applied = amount
	current.total += applied
	local entry = current.damageBy[player.UserId]
	if not entry then
		entry = { userId = player.UserId, name = player.DisplayName, damage = 0 }
		current.damageBy[player.UserId] = entry
	end
	entry.damage += applied
	dirty = true
end

-- เรียกครั้งเดียวตอนเซิร์ฟเริ่ม: ย้ายโมเดลบอสไปเก็บ + สร้างโฟลเดอร์ BossState ให้ Client อ่าน
function BossService.Init()
	-- โมเดลบอสที่วางไว้ในแมพ → ย้ายเก็บ ServerStorage > Bosses ให้โผล่เฉพาะตอนบอสมา (ไม่ร่วงทะลุแมพก่อนเวลา)
	for _, entry in Combat.Boss.Rotation do
		local template = findTemplate(entry.Model)
		if template and not template:IsDescendantOf(ServerStorage) then
			local folder = ServerStorage:FindFirstChild("Bosses")
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = "Bosses"
				folder.Parent = ServerStorage
			end
			template.Parent = folder
			print(`[BossService] ย้าย {template.Name} จาก Workspace ไปรอใน ServerStorage > Bosses (จะโผล่ตอนบอสมา)`)
		end
	end

	state = Instance.new("Folder")
	state.Name = "BossState"
	state:SetAttribute("Active", false)
	state:SetAttribute("NextAt", now() + Combat.Boss.FirstDelay)
	state:SetAttribute("Top", "[]")
	state:SetAttribute("Result", "")
	state.Parent = ReplicatedStorage
end

-- ลูปหลักทุก PUBLISH_INTERVAL วิ: ครบเวลา → finish · มีดาเมจใหม่ → publish
-- ไม่มีบอสและถึง NextAt → spawnBoss (ถ้ายังไม่มีผู้เล่นในเซิร์ฟ → เลื่อนไปอีก 5 วิ)
function BossService.Start()
	while true do
		task.wait(PUBLISH_INTERVAL)
		local current = boss
		if current then
			if now() >= current.endsAt then
				finish(current)
			elseif dirty then
				dirty = false
				publish(current)
			end
		elseif now() >= state:GetAttribute("NextAt") then
			if #Players:GetPlayers() > 0 then
				spawnBoss()
			else
				state:SetAttribute("NextAt", now() + 5)
			end
		end
	end
end

return BossService
