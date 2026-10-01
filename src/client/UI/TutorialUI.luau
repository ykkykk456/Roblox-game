-- หน้าจอฝึกสอนตอนเข้าเกม 5 ขั้น (เจ้าของ: Client_UI_Scripter · โครงหน้าจอ: UX_Architect) · สเปก: design/tutorial.md
-- แสดงผลอย่างเดียว: ขั้นปัจจุบันอ่านจาก Attribute TutorialStep / TutorialDone ที่ Server ตั้ง · Client เลื่อนขั้นเองไม่ได้
-- ส่งคำขอได้ทางเดียว = ปุ่ม "เข้าใจแล้ว!" ขั้น 5 → Controllers/TutorialController (Remote TutorialAck)
-- ข้อความแต่ละขั้น/ตัวเลข → src/shared/Config/Tutorial.luau (Steps[n].Text · MinReadSeconds · RewardCoins)
--
-- สิ่งที่ผู้เล่นเห็นต่อขั้น:
--   ป้ายบนจอ (ใต้แถบบอส) = "ขั้น n/5" + แถบความคืบหน้า + ข้อความขั้น + คำใบ้ปุ่มตามอุปกรณ์ · เปลี่ยนขั้น = เด้ง + กระพริบ
--   1 ChooseElement = บังคับเปิดหน้าเลือกธาตุ (UI/ElementUI) ค้างไว้ · ปิดเอง = เปิดกลับให้ จนกว่า Element ≠ ""
--   2 WatchTurret   = ลูกศร 3D เด้งเหนือป้อมตัวเอง (workspace.Turrets · Attribute OwnerUserId) + ลำแสงจากตัวละคร
--   3 UseSkill      = ปุ่มสกิล (UI/CombatUI) กระพริบ/ขยาย + ป้าย "Q / ปุ่มสกิล"
--   4 Upgrade       = ลูกศร 3D "คลิกป้อม" เหนือป้อมตัวเอง (ไม่มีปุ่มลัดอัปแล้ว) · เปิดแผงป้อม (UI/TurretPanelUI) แล้ว
--                     ปุ่ม "อัปเกรด" ในแผงกระพริบ/ขยาย + แผงเลื่อนให้เห็นปุ่มเอง (focusUpgrade)
--   5 MeetBoss      = ลูกศร 3D + ลำแสงชี้จุดเกิดบอส (Tag BossSpawn · ไม่เจอ = จุดกลางโลก) + ปุ่ม "เข้าใจแล้ว!" (กดได้หลัง MinReadSeconds)
--   จบ (TutorialDone เปลี่ยนเป็น true ระหว่างเล่น) = ป้ายฉลอง "พร้อมลุย! 🎉" + เหรียญโบนัส (แค่แสดง · Server แจกจริง)
--   ปุ่มที่ไม่เกี่ยวกับขั้นปัจจุบัน = หรี่ด้วยแผ่นทึบ (แค่หน้าตา · Server ปฏิเสธคำขอเองอยู่แล้ว)
--   เข้าเกมมาแล้ว TutorialDone = true → ไม่แสดงอะไรเลย
--
-- อยากปรับ:
--   ตำแหน่ง/ขนาดป้าย → TutorialUI.Init (banner.Position / BANNER_MAX_WIDTH) · ขนาดตัวหนังสือ → STEP_TEXT_SIZE
--   คำใบ้ปุ่มแต่ละขั้น → hintFor() · สีลูกศร/ไฮไลต์ → HIGHLIGHT_COLOR · ความสูงลูกศร → ARROW_HEIGHT
-- ⚠️ ทุกอย่างในไฟล์นี้เป็นของ Client เท่านั้น (ลูกศร/ลำแสงอยู่ในโฟลเดอร์ local) · ล้างหมดทุกครั้งที่ขั้นเปลี่ยน (clearStep)
--
-- 📖 อ่านตามลำดับนี้:
--   1) TutorialUI.Init สร้างป้าย + ป้ายฉลอง + โฟลเดอร์เอฟเฟกต์
--   2) TutorialUI.Start ฟัง Attribute TutorialStep / TutorialDone → render()
--   3) render → clearStep (ล้างของขั้นเก่า) → showStep(n) → ฟังก์ชันของขั้นนั้น (step1..step5)
--   4) ของที่สร้างต่อขั้นต้องผ่าน track() เสมอ เพื่อให้ clearStep ล้างได้

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Tags = require(ReplicatedStorage.Shared.Config.Tags)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local CombatUI = require(script.Parent.CombatUI)
local Components = require(script.Parent.Components)
local ElementUI = require(script.Parent.ElementUI)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local TurretPanelUI = require(script.Parent.TurretPanelUI)
local TutorialController = require(script.Parent.Parent.Controllers.TutorialController)

local player = Players.LocalPlayer

-- ===== ค่าที่ปรับได้ (หน้าตาเท่านั้น · ตัวเลขเกมอยู่ Config/Tutorial) =====
local TOTAL_STEPS = #Tutorial.Steps
local PICKER_PANEL = "Element" -- ⚠️ ต้องตรงกับ PANEL_NAME ใน UI/ElementUI
local PICKER_CHECK = 0.25 -- วินาที: ขั้น 1 เช็กว่าหน้าเลือกธาตุถูกปิดไหม (ถี่ = เปิดกลับเร็ว)
local TARGET_RETRY = 1 -- วินาที: ยังหาป้อม/จุดบอสไม่เจอ (ยังโหลดไม่มา) → ลองใหม่ทุกเท่านี้
local ACK_RETRY = 3 -- วินาที: กด "เข้าใจแล้ว!" แล้ว Server ยังไม่เลื่อนขั้น → ปุ่มกดได้อีกครั้ง
local CELEBRATE_SECONDS = 3.5 -- วินาทีที่ป้ายฉลองค้างก่อนจางหาย
local BANNER_MAX_WIDTH = 560 -- ป้ายกว้างสุด (พิกเซล) บนจอใหญ่
local BANNER_TOP = 10 -- ป้ายห่างใต้แถบปุ่มระบบ Roblox 10 px (แถบบอสย้ายขึ้นไปอยู่ในแถวปุ่มระบบแล้ว)
local STEP_TEXT_SIZE = 22
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 214, 64) -- สีลูกศร/ขอบปุ่มที่ต้องกด
local BEAM_COLOR = Color3.fromRGB(255, 230, 120)
local ARROW_HEIGHT = 3 -- studs เหนือเป้าที่ลูกศรลอย (เด้งขึ้นอีก ARROW_BOUNCE)
local ARROW_BOUNCE = 1.6
local DIM_TRANSPARENCY = 0.45 -- ความทึบแผ่นหรี่ปุ่ม (0 = ดำสนิท · 1 = ไม่หรี่)

-- ===== ชิ้น UI (สร้างใน Init) =====
local banner: Frame
local bannerScale: UIScale
local progressLabel: TextLabel
local progressFill: Frame
local stepLabel: TextLabel
local hintLabel: TextLabel
local ackButton: TextButton
local celebrateLabel: TextLabel
local celebrateScale: UIScale
local effectsFolder: Folder

-- ===== สถานะ =====
local currentStep = 0 -- ขั้นที่แสดงอยู่ (0 = ไม่แสดง)
local stepToken = 0 -- เพิ่มทุกครั้งที่ล้างขั้น → thread ของขั้นเก่ารู้ตัวแล้วหยุด
local seenTutorial = false -- รอบเล่นนี้เคยแสดงขั้นใด ๆ (ใช้ตัดสินว่าจะฉลองไหม · เข้าเกมมาจบแล้ว = ไม่ฉลอง)
local stepTrash: { any } = {} -- ของที่ต้องล้างเมื่อขั้นเปลี่ยน (Instance / Connection / ฟังก์ชัน)

-- ===== ตัวช่วยล้างของ =====
-- เก็บของไว้ล้างตอนเปลี่ยนขั้น · คืนของเดิมให้ใช้ต่อ
local function track<T>(item: T): T
	table.insert(stepTrash, item)
	return item
end

-- ล้างของขั้นปัจจุบันทั้งหมด (ลูกศร ลำแสง ไฮไลต์ แผ่นหรี่ การฟังสัญญาณ)
local function clearStep()
	stepToken += 1
	for index = #stepTrash, 1, -1 do
		local item = stepTrash[index]
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif typeof(item) == "Instance" then
			if item:IsA("Tween") then
				item:Cancel()
			end
			item:Destroy()
		elseif type(item) == "function" then
			pcall(item)
		end
	end
	table.clear(stepTrash)
	ackButton.Visible = false
	if GuiService.SelectedObject == ackButton then
		GuiService.SelectedObject = nil
	end
end

-- เล่น tween แบบวนไปกลับไม่รู้จบ (หยุดเมื่อขั้นเปลี่ยน)
local function loopTween(instance: Instance, seconds: number, goal: { [string]: any })
	local tween = track(
		TweenService:Create(
			instance,
			TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			goal
		)
	)
	tween:Play()
end

-- ===== คำใบ้ปุ่มตามอุปกรณ์ =====
-- คืนข้อความตามอุปกรณ์ที่ใช้อยู่ (Gamepad / คีย์บอร์ด / จอสัมผัส) — แบบเดียวกับ keyHint ของ CombatUI
local function byDevice(keyboard: string, gamepad: string, touch: string): string
	if UserInputService.GamepadEnabled then
		return gamepad
	elseif UserInputService.KeyboardEnabled then
		return keyboard
	end
	return touch
end

-- ✏️ คำใบ้บรรทัดล่างของป้าย + ป้ายเล็กบนปุ่ม (ปุ่มลัดจริงผูกใน TurretController / TurretPanelUI)
local function hintFor(step: number): string
	if step == 1 then
		return "👇 เลือก 1 ธาตุจากการ์ดด้านล่าง"
	elseif step == 2 then
		return "👀 ลูกศรเหลือง = ป้อมของคุณ"
	elseif step == 3 then
		return byDevice("Q / ปุ่มสกิล", "X / ปุ่มสกิล", "แตะปุ่มสกิล ⚡")
	elseif step == 4 then
		return byDevice("🖱 คลิกป้อม (ลูกศรเหลือง) → ⬆ อัปเกรด", "RB เปิดแผงป้อม → ⬆ อัปเกรด", "👆 แตะป้อม (ลูกศรเหลือง) → ⬆ อัปเกรด")
	elseif step == 5 then
		return byDevice("🛠 คลิกที่ป้อมเพื่อใส่อุปกรณ์", "🛠 กด RB ดูอุปกรณ์", "🛠 แตะที่ป้อมเพื่อใส่อุปกรณ์")
	end
	return ""
end

-- ===== หาเป้าบนจอ (ปุ่มของไฟล์อื่น) =====
-- ปุ่มเมนูของ HudUI ตามชื่อ (Settings / Shop / Bag / Gear)
local function menuButton(name: string): GuiObject?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("HudGui")
	local menu = hud and hud:FindFirstChild("Menu")
	local button = menu and menu:FindFirstChild(name)
	return if button and button:IsA("GuiObject") then button else nil
end

-- ปุ่ม HUD เปิดแผงธาตุของ ElementUI
local function elementHudButton(): GuiObject?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("ElementHudGui")
	local button = hud and hud:FindFirstChild("ElementButton")
	return if button and button:IsA("GuiObject") then button else nil
end

-- ===== เอฟเฟกต์บนปุ่ม =====
-- หรี่ปุ่ม = แผ่นสีดำโปร่งแสงทับบนปุ่ม (ไม่แตะสี/ข้อความที่ไฟล์เจ้าของวาดเอง)
local function dim(button: GuiObject?)
	if not button then
		return
	end
	local shade = Instance.new("Frame")
	shade.Name = "TutorialDim"
	shade.Active = false
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = DIM_TRANSPARENCY
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = button.ZIndex + 2
	Components.corner(shade)
	shade.Parent = button
	track(shade)
end

-- ไฮไลต์ปุ่มที่ต้องกด: ขอบเหลืองหนา-บาง + ปุ่มขยาย-หด + ป้าย "👇 tag" เด้งอยู่เหนือปุ่ม
local function pulse(button: GuiObject?, tag: string)
	if not button then
		return
	end
	local stroke = track(Instance.new("UIStroke"))
	stroke.Name = "TutorialPulse"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Thickness = 2
	stroke.Parent = button
	loopTween(stroke, 0.45, { Thickness = 5 })

	local scale = track(Instance.new("UIScale"))
	scale.Name = "TutorialPulse"
	scale.Parent = button
	loopTween(scale, 0.45, { Scale = 1.08 })

	local label = track(Instance.new("TextLabel"))
	label.Name = "TutorialTag"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -6)
	label.Size = UDim2.fromOffset(0, 30)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundColor3 = HIGHLIGHT_COLOR
	label.Font = Theme.FontBold
	label.TextSize = 18
	label.TextColor3 = Theme.Colors.Background
	label.Text = `👇 {tag}`
	label.ZIndex = button.ZIndex + 3
	Components.corner(label, UDim.new(0, 8))
	Components.padding(label, 6)
	label.Parent = button
	loopTween(label, 0.35, { Position = UDim2.new(0.5, 0, 0, -14) })
end

-- ===== ลูกศร 3D + ลำแสง =====
-- สร้างลูกศรเด้งลอยเหนือจุดที่ getTarget() คืน (nil = ยังไม่เจอ → ซ่อน) · withBeam = ลากลำแสงจากตัวละครไปหา
-- คืนฟังก์ชัน refresh() ให้เรียกเมื่อเป้าอาจย้าย (สัญญาณจากโลก)
local function worldArrow(getTarget: () -> Vector3?, caption: string, extraHeight: number, withBeam: boolean): () -> ()
	-- ชิ้นยึดล่องหน (Anchored · ไม่ชน · ไม่โดน Raycast) อยู่ในโฟลเดอร์ local ของเครื่องนี้เท่านั้น
	local anchor = track(Instance.new("Part"))
	anchor.Name = "TutorialTarget"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = effectsFolder
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = anchor

	-- ลูกศร = BillboardGui ขนาดคงที่บนจอ · มองเห็นทะลุกำแพง (AlwaysOnTop)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Arrow"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(140, 120)
	billboard.StudsOffset = Vector3.new(0, ARROW_HEIGHT + extraHeight, 0)
	billboard.Enabled = false
	billboard.Parent = anchor

	local captionLabel = Instance.new("TextLabel")
	captionLabel.BackgroundTransparency = 1
	captionLabel.Size = UDim2.new(1, 0, 0, 30)
	captionLabel.Font = Theme.FontBold
	captionLabel.TextSize = 20
	captionLabel.TextColor3 = HIGHLIGHT_COLOR
	captionLabel.TextStrokeTransparency = 0.2
	captionLabel.Text = caption
	captionLabel.Parent = billboard

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Position = UDim2.fromOffset(0, 30)
	arrowLabel.Size = UDim2.new(1, 0, 1, -30)
	arrowLabel.Font = Theme.FontBold
	arrowLabel.TextScaled = true
	arrowLabel.TextColor3 = HIGHLIGHT_COLOR
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.Text = "▼"
	arrowLabel.Parent = billboard

	loopTween(billboard, 0.5, { StudsOffset = Vector3.new(0, ARROW_HEIGHT + extraHeight + ARROW_BOUNCE, 0) })

	-- ลำแสงจากตัวละครไปหาเป้า (สร้างใหม่ทุกครั้งที่เกิดใหม่)
	if withBeam then
		local beam = Instance.new("Beam")
		beam.Attachment1 = targetAttachment
		beam.Color = ColorSequence.new(BEAM_COLOR)
		beam.Transparency = NumberSequence.new(0.35, 0.1)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Width0 = 0.5
		beam.Width1 = 1.2
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = anchor

		local characterAttachment: Attachment? = nil
		local function attachCharacter(character: Model?)
			if characterAttachment then
				characterAttachment:Destroy()
				characterAttachment = nil
			end
			beam.Attachment0 = nil
			local root = character and character:WaitForChild("HumanoidRootPart", 5)
			if not root or not anchor.Parent then
				return
			end
			local attachment = Instance.new("Attachment")
			attachment.Name = "TutorialBeam"
			attachment.Parent = root
			characterAttachment = attachment
			beam.Attachment0 = attachment
		end
		track(function()
			if characterAttachment then
				characterAttachment:Destroy()
			end
		end)
		track(player.CharacterAdded:Connect(attachCharacter))
		task.spawn(attachCharacter, player.Character)

		-- เปิดลำแสงเมื่อเจอเป้าแล้วเท่านั้น (ไม่งั้นจะชี้ไปจุด 0,0,0 ของชิ้นยึด)
		track(billboard:GetPropertyChangedSignal("Enabled"):Connect(function()
			beam.Enabled = billboard.Enabled
		end))
	end

	return function()
		local position = getTarget()
		if position then
			anchor.Position = position
		end
		billboard.Enabled = position ~= nil
	end
end

-- ลองหาเป้าซ้ำเป็นระยะจนเจอ (ของในโลกอาจยังโหลดมาไม่ถึง) · ถูกหยุดเมื่อขั้นเปลี่ยน
local function retryUntilFound(refresh: () -> (), found: () -> boolean)
	local token = stepToken
	task.spawn(function()
		while token == stepToken do
			refresh()
			if found() then
				return
			end
			task.wait(TARGET_RETRY)
		end
	end)
end

-- ===== หาตำแหน่งเป้าในโลก =====
-- จุดบนสุดกลางชิ้น (Model = กล่องรวม · BasePart = ตัวชิ้น)
local function topOf(instance: Instance): Vector3?
	if instance:IsA("Model") then
		local ok, cframe, size = pcall(instance.GetBoundingBox, instance)
		if ok and size.Magnitude > 0 then
			return cframe.Position + Vector3.new(0, size.Y / 2, 0)
		end
	elseif instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, instance.Size.Y / 2, 0)
	end
	return nil
end

-- ป้อมของเราเอง: workspace.Turrets → ตัวที่ Attribute OwnerUserId = UserId ของเรา (TurretService ตั้งให้)
local function ownTurret(): Instance?
	local folder = workspace:FindFirstChild("Turrets")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("OwnerUserId") == player.UserId then
			return child
		end
	end
	return nil
end

-- จุดเกิดบอส: ชิ้นแรกที่ติด Tag BossSpawn · ไม่เจอ = nil
local function bossSpawnPart(): Instance?
	for _, item in CollectionService:GetTagged(Tags.BossSpawn) do
		if item:IsDescendantOf(workspace) then
			return item
		end
	end
	return nil
end

-- ปุ่มที่ต้องหรี่นอกขั้นของมัน: สกิล (UI/CombatUI) · อัปเกรด (ในแผงป้อม UI/TurretPanelUI)
local function skillButton(): GuiObject?
	return CombatUI.getSkillButton()
end

local function upgradeButton(): GuiObject?
	return TurretPanelUI.getUpgradeButton()
end

-- ลูกศร + ลำแสงชี้ป้อมตัวเอง · ป้อมสร้างใหม่ (เปลี่ยนธาตุ/ขั้นหน้าตา) → ย้ายลูกศรตาม (ใช้ขั้น 2 และ 4)
local function arrowOnOwnTurret(caption: string)
	local refresh = worldArrow(function()
		local turret = ownTurret()
		return if turret then topOf(turret) else nil
	end, caption, 0, true)

	task.spawn(function()
		local token = stepToken
		local folder = workspace:WaitForChild("Turrets", 30)
		if not folder or token ~= stepToken then
			return
		end
		local function onChanged()
			task.defer(refresh) -- รอ Server ใส่ลูกในโมเดลครบก่อนค่อยวัดกล่อง
		end
		track(folder.ChildAdded:Connect(onChanged))
		track(folder.ChildRemoved:Connect(onChanged))
		retryUntilFound(refresh, function()
			return ownTurret() ~= nil
		end)
	end)
end

-- ===== ขั้นต่าง ๆ =====
-- ขั้น 1: บังคับเปิดหน้าเลือกธาตุค้างไว้ จนกว่า Server ตั้ง Element ≠ "" (ปิดเอง → เปิดกลับ)
local function step1()
	local token = stepToken
	task.spawn(function()
		while token == stepToken do
			-- Element = nil (ยังโหลดไม่เสร็จ) → รอ · ≠ "" (เลือกแล้ว รอ Server เลื่อนขั้น) → ไม่บังคับ
			if player:GetAttribute("Element") == "" and Panels.current() ~= PICKER_PANEL then
				ElementUI.openPicker()
			end
			task.wait(PICKER_CHECK)
		end
	end)
	dim(upgradeButton())
	dim(skillButton())
end

-- ขั้น 2: ลูกศร + ลำแสงชี้ป้อมตัวเอง
local function step2()
	arrowOnOwnTurret("ป้อมของคุณ")
	dim(upgradeButton())
	dim(skillButton())
end

-- ขั้น 3: ปุ่มสกิลกระพริบ · ปุ่มอัปหรี่
local function step3()
	pulse(skillButton(), byDevice("Q / ปุ่มสกิล", "X / ปุ่มสกิล", "แตะปุ่มสกิล"))
	dim(upgradeButton())
end

-- ขั้น 4: ลูกศรชี้ป้อม "คลิกป้อม" → ผู้เล่นเปิดแผงป้อม → ปุ่มอัปเกรดในแผงกระพริบ (ติดไว้ตั้งแต่ต้นขั้น · แผงปิดอยู่ก็มองไม่เห็นเอง)
-- แผงเปิด (ตอนไหนก็ได้ในขั้นนี้) → เลื่อนแผงให้เห็นปุ่มอัป (จอเล็กปุ่มอาจอยู่ใต้ขอบ) · ปุ่มสกิลหรี่
local function step4()
	arrowOnOwnTurret(byDevice("🖱 คลิกป้อม!", "RB เปิดแผงป้อม", "👆 แตะป้อม!"))
	pulse(upgradeButton(), "อัปเกรด")
	dim(skillButton())

	local panel = TurretPanelUI.getFrame()
	if panel then
		track(panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if panel.Visible then
				TurretPanelUI.focusUpgrade()
			end
		end))
		if panel.Visible then
			TurretPanelUI.focusUpgrade()
		end
	end
end

-- ขั้น 5: ลูกศร + ลำแสงชี้จุดเกิดบอส + ปุ่ม "เข้าใจแล้ว!" (กดได้หลัง MinReadSeconds)
local function step5()
	local refresh = worldArrow(function()
		local marker = bossSpawnPart()
		return if marker then topOf(marker) else Vector3.zero -- [Assumed] ไม่มี Tag = บอสเกิดกลางโลก (ผังวงกลมเดิม)
	end, "👹 จุดเกิดบอส", 6, true)
	refresh()
	-- ชิ้นติด Tag โหลดมาทีหลัง (Streaming) → ย้ายลูกศรไปจุดจริง
	track(CollectionService:GetInstanceAddedSignal(Tags.BossSpawn):Connect(function()
		task.defer(refresh)
	end))

	dim(upgradeButton())
	dim(skillButton())

	-- ปุ่มเข้าใจแล้ว: นับถอยหลังจากเวลาที่เครื่องนี้เห็นขั้น 5 (ช้ากว่าเวลาเริ่มขั้นที่ Server เสมอ → Server ไม่ปฏิเสธเพราะเร็วไป)
	local token = stepToken
	local readyAt = os.clock() + Tutorial.MinReadSeconds
	ackButton.Visible = true
	ackButton.AutoButtonColor = false
	task.spawn(function()
		while token == stepToken and os.clock() < readyAt do
			ackButton.Text = `เข้าใจแล้ว! ({math.ceil(readyAt - os.clock())})`
			ackButton.BackgroundColor3 = Theme.Colors.Surface
			ackButton.TextTransparency = 0.4
			task.wait(0.2)
		end
		if token ~= stepToken then
			return
		end
		ackButton.Text = "เข้าใจแล้ว! ✅"
		ackButton.BackgroundColor3 = Theme.Colors.Accent
		ackButton.TextTransparency = 0
		-- Gamepad: เลือกปุ่มให้เลย กด A ได้ทันที (ไม่แย่งถ้ากำลังเลือกของอื่นอยู่)
		if UserInputService.GamepadEnabled and GuiService.SelectedObject == nil then
			GuiService.SelectedObject = ackButton
		end
	end)

	local sentAt = -math.huge
	track(ackButton.Activated:Connect(function()
		local now = os.clock()
		if now < readyAt or now - sentAt < ACK_RETRY then
			return
		end
		sentAt = now
		ackButton.Text = "กำลังไป… ⏳"
		TutorialController.requestAck()
		-- Server ยังไม่เลื่อนขั้นภายใน ACK_RETRY วิ → ให้กดใหม่ได้
		task.delay(ACK_RETRY, function()
			if token == stepToken then
				ackButton.Text = "เข้าใจแล้ว! ✅"
			end
		end)
	end))
end

local STEP_RUNNERS: { [number]: () -> () } = { step1, step2, step3, step4, step5 }

-- ===== ป้าย =====
-- เด้ง + กระพริบสีตอนขั้นเปลี่ยน
local function bounceBanner()
	bannerScale.Scale = 1.15
	TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	banner.BackgroundColor3 = Theme.Colors.Accent
	TweenService:Create(banner, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundColor3 = Theme.Colors.Background })
		:Play()
end

-- แสดงขั้น step (ล้างของเก่าแล้ว) · ข้อความจาก Config Tutorial.Steps[step].Text
local function showStep(step: number)
	local def = Tutorial.Steps[step]
	progressLabel.Text = `ขั้น {step}/{TOTAL_STEPS}`
	TweenService:Create(progressFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(step / TOTAL_STEPS, 1),
	}):Play()
	stepLabel.Text = if def then def.Text else ""
	hintLabel.Text = hintFor(step)
	banner.Visible = true
	bounceBanner()

	-- ปุ่มเมนูที่ไม่เกี่ยว = หรี่ (ตั้งค่า ไม่หรี่ · ปุ่ม "🛠 ป้อม" ไม่หรี่ในขั้น 4 (ทางสำรองไปปุ่มอัป) และ 5 (ลองดูอุปกรณ์))
	dim(menuButton("Shop"))
	dim(menuButton("Bag"))
	if step ~= 4 and step ~= 5 then
		dim(menuButton("Gear"))
	end
	if step ~= 1 then
		dim(elementHudButton())
	end

	local runner = STEP_RUNNERS[step]
	if runner then
		local ok, err = pcall(runner)
		if not ok then
			warn(`[TutorialUI] ขั้น {step} ผิดพลาด: {err}`)
		end
	end
end

-- ป้ายฉลองจบการฝึก (แค่แสดง · เหรียญโบนัสจริง Server แจกเอง)
local function celebrate()
	celebrateLabel.Text = `พร้อมลุย! 🎉\n+{Tutorial.RewardCoins} 💰`
	celebrateLabel.TextTransparency = 0
	celebrateLabel.TextStrokeTransparency = 0.2
	celebrateLabel.Visible = true
	celebrateScale.Scale = 0.3
	TweenService:Create(celebrateScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(CELEBRATE_SECONDS, function()
		local fade = TweenService:Create(celebrateLabel, TweenInfo.new(0.6), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fade.Completed:Once(function()
			celebrateLabel.Visible = false
		end)
		fade:Play()
	end)
end

-- ขั้นที่ควรแสดงตอนนี้ (0 = ไม่แสดง: ปิดระบบ / จบแล้ว / ยังโหลดไม่เสร็จ / เลขขั้นผิด)
local function activeStep(): number
	if not Tutorial.Enabled or player:GetAttribute("TutorialDone") == true then
		return 0
	end
	local step = player:GetAttribute("TutorialStep")
	if type(step) ~= "number" then
		return 0
	end
	step = math.floor(step)
	if step < 1 or step > TOTAL_STEPS then
		return 0
	end
	return step
end

-- วาดตามสถานะล่าสุด · ขั้นเดิม = ไม่ทำอะไร (กันล้าง/สร้างซ้ำ)
local function render()
	local step = activeStep()
	if step == currentStep then
		return
	end
	currentStep = step
	clearStep()
	if step == 0 then
		banner.Visible = false
		return
	end
	seenTutorial = true
	showStep(step)
end

local TutorialUI = {}

-- สร้างป้ายขั้น + ป้ายฉลอง + โฟลเดอร์เอฟเฟกต์ 3D (ซ่อนไว้ก่อน)
function TutorialUI.Init()
	-- DisplayOrder 11 = อยู่เหนือแผงหน้าต่าง (10) เพื่อให้เห็นข้อความขั้น 1 ตอนหน้าเลือกธาตุเปิด
	local gui = Components.screen("TutorialGui", 11)

	-- ===== ป้ายขั้น (บนกลาง ใต้แถบบอส) =====
	-- ✏️ ตำแหน่ง = banner.Position · กว้าง 92% ของจอ ไม่เกิน BANNER_MAX_WIDTH · สูงขยายตามข้อความ
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Active = false
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, BANNER_TOP)
	banner.Size = UDim2.new(0.92, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.BackgroundColor3 = Theme.Colors.Background
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	banner.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(BANNER_MAX_WIDTH, math.huge)
	limit.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = HIGHLIGHT_COLOR
	stroke.Thickness = 2
	stroke.Parent = banner
	bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	Components.corner(banner)
	Components.padding(banner, 10)
	local layout = Components.list(banner, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- แถวบน: "ขั้น n/5" + แถบความคืบหน้า
	local progressRow = Instance.new("Frame")
	progressRow.BackgroundTransparency = 1
	progressRow.Size = UDim2.new(1, 0, 0, 22)
	progressRow.LayoutOrder = 1
	progressRow.Parent = banner
	progressLabel = Components.label(progressRow, "", {
		size = UDim2.new(0, 80, 1, 0),
		bold = true,
		textSize = 16,
		color = HIGHLIGHT_COLOR,
	})
	local progressBack = Instance.new("Frame")
	progressBack.AnchorPoint = Vector2.new(0, 0.5)
	progressBack.Position = UDim2.new(0, 88, 0.5, 0)
	progressBack.Size = UDim2.new(1, -88, 0, 10)
	progressBack.BackgroundColor3 = Theme.Colors.Surface
	progressBack.BorderSizePixel = 0
	progressBack.Parent = progressRow
	Components.corner(progressBack, UDim.new(1, 0))
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.Colors.Accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	Components.corner(progressFill, UDim.new(1, 0))

	-- ข้อความขั้น (ตัวใหญ่ ตัดบรรทัดได้)
	stepLabel = Components.label(banner, "", {
		size = UDim2.new(1, 0, 0, 0),
		bold = true,
		textSize = STEP_TEXT_SIZE,
		alignX = Enum.TextXAlignment.Center,
		order = 2,
	})
	stepLabel.AutomaticSize = Enum.AutomaticSize.Y
	stepLabel.TextWrapped = true
	stepLabel.TextTruncate = Enum.TextTruncate.None
	stepLabel.TextStrokeTransparency = 0.6

	-- คำใบ้ปุ่ม (ตามอุปกรณ์)
	hintLabel = Components.label(banner, "", {
		size = UDim2.new(1, 0, 0, 0),
		textSize = 16,
		color = HIGHLIGHT_COLOR,
		alignX = Enum.TextXAlignment.Center,
		order = 3,
	})
	hintLabel.AutomaticSize = Enum.AutomaticSize.Y
	hintLabel.TextWrapped = true
	hintLabel.TextTruncate = Enum.TextTruncate.None

	-- ปุ่ม "เข้าใจแล้ว!" (ขั้น 5 เท่านั้น · สูง ≥ 44 กดบนมือถือสบาย)
	ackButton = Components.button(banner, "เข้าใจแล้ว!", {
		size = UDim2.new(0.6, 0, 0, Theme.ButtonHeight),
		color = Theme.Colors.Accent,
		hoverColor = Theme.Colors.AccentHover,
		textSize = 20,
		order = 4,
	})
	ackButton.Name = "TutorialAck"
	ackButton.Visible = false

	-- ===== ป้ายฉลองจบ (กลางจอค่อนบน) =====
	celebrateLabel = Instance.new("TextLabel")
	celebrateLabel.Name = "Celebrate"
	celebrateLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	celebrateLabel.Position = UDim2.fromScale(0.5, 0.35)
	celebrateLabel.Size = UDim2.fromOffset(420, 130)
	celebrateLabel.BackgroundTransparency = 1
	celebrateLabel.Font = Theme.FontBold
	celebrateLabel.TextSize = 44
	celebrateLabel.TextColor3 = Theme.Colors.Coin
	celebrateLabel.TextStrokeTransparency = 0.2
	celebrateLabel.Visible = false
	celebrateLabel.Parent = gui
	celebrateScale = Instance.new("UIScale")
	celebrateScale.Parent = celebrateLabel

	-- ===== โฟลเดอร์ของ 3D ฝั่งเครื่องนี้ (ลูกศร/ลำแสง · ไม่ส่งไป Server/ผู้เล่นอื่น) =====
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "TutorialEffects"
	effectsFolder.Parent = workspace
end

-- เริ่มฟัง Attribute จาก Server (ทางเดียวที่รู้ว่าอยู่ขั้นไหน)
function TutorialUI.Start()
	if not Tutorial.Enabled then
		return
	end
	player:GetAttributeChangedSignal("TutorialStep"):Connect(render)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		-- ฉลองเฉพาะตอนจบระหว่างเล่นรอบนี้ (เข้าเกมมาจบแล้ว = ไม่แสดงอะไร)
		if player:GetAttribute("TutorialDone") == true and seenTutorial then
			seenTutorial = false
			celebrate()
		end
		render()
	end)
	render()
end

return TutorialUI
