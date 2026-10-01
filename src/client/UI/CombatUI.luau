-- HUD การต่อสู้: แถบบอส (บนกลาง) · ตารางดาเมจ (ซ้าย ใต้เหรียญ) · แผงป้อม (ล่างกลาง) (เจ้าของ: Client_UI_Scripter)
-- ทุกค่าแสดงจาก Attribute ที่ Server ตั้ง (ReplicatedStorage.BossState + Player Attributes) — Client ไม่เป็นเจ้าของค่า
-- ปุ่มบนจอใช้ได้ทั้งสัมผัส/เมาส์/Gamepad · ปุ่มลัดอยู่ใน TurretController
--
-- อยากปรับ:
--   ย้าย/ขยายแถบบอส → BOSS_BAR_TOP / BOSS_BAR_HEIGHT ด้านบนไฟล์ · สีรุ้ง/ความเร็ววิ้ง → RAINBOW_* / SHINE_*
--   ย้ายตารางดาเมจ → หมวด "ตารางดาเมจ" (board.Position / Size) · จำนวนแถว = for index = 1, 5
--   ย้ายแผงป้อม/ปุ่มสกิล → หมวด "แผงป้อม" (panel.Position / Size)
--   ปุ่มอัปเกรดย้ายไปอยู่แผงป้อมที่เปิดด้วยการคลิกป้อม (UI/TurretPanelUI) · ไม่มีปุ่มลัดอัปแล้ว
--   ข้อความที่แสดง → renderBoss / renderBoard / renderTurret · สี → UI/Theme.luau
--   ปุ่มสกิล = กล่องสี่เหลี่ยม "Q" สีตามธาตุ → SKILL_KEY_TEXT / renderTurret / Init (ปุ่มลัดจริงผูกใน TurretController)
--   ชื่อสกิลบนปุ่ม = สกิลของธาตุ (Config/Elements · Skill.Name) · คูลดาวน์จาก Attribute SkillReadyAt/SkillActiveUntil (Server ตั้ง)
-- ⚠️ ตัวเลขดาเมจ/ราคาบนจอเป็นแค่การแสดงผล · ดาเมจจริงและการหักเงินทำที่ Server เท่านั้น

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local TurretController = require(script.Parent.Parent.Controllers.TurretController)

local player = Players.LocalPlayer

-- วินาทีต่อรอบอัปเดตนาฬิกานับถอยหลัง (ลด = ลื่นขึ้นแต่ทำงานถี่ขึ้น)
local REFRESH_INTERVAL = 0.2
local RESULT_SHOW_TIME = 8 -- วินาทีที่แสดงผลรอบล่าสุดหลังบอสจบ

-- ✏️ แถบบอสสีรุ้งวิบวับ (แสดงผลล้วน)
local BOSS_BAR_TOP = 10 -- ✏️ ระยะห่างจากขอบบน (พิกเซล · นับใต้ปุ่มระบบ Roblox ที่ ScreenInsets เว้นให้แล้ว)
local BOSS_BAR_HEIGHT = 26 -- ✏️ ความสูงแถบ (ถ้าเปลี่ยน ให้แก้ BANNER_TOP ใน TutorialUI ด้วย)
local RAINBOW_SPEED = 0.25 -- ✏️ ความเร็วสีรุ้งไหล (รอบต่อวินาที · มาก = ไหลเร็ว)
local RAINBOW_SATURATION = 0.75 -- ✏️ ความสดของสีรุ้ง (0 = ขาว · 1 = สดสุด)
local SHINE_PERIOD = 1.6 -- ✏️ วินาทีต่อการวิ้งแสงขาวพาดผ่านแถบ 1 ครั้ง
local SHINE_WIDTH = 0.25 -- ✏️ ความกว้างแสงวิ้ง (สัดส่วนของแถบ)

-- ชิ้น UI ที่ฟังก์ชัน render ต้องอัปเดต (สร้างใน Init) · bossState = ข้อมูลบอสจาก Server
local bossState: Instance
local bossTitle: TextLabel
local bossFill: Frame
local bossHpText: TextLabel
local bossBarBack: Frame
local bossGradient: UIGradient -- สีรุ้งบน bossFill (หมุนสีทุกเฟรม)
local bossShine: Frame -- แถบแสงขาววิ้งพาดผ่าน
local bossStroke: UIStroke -- ขอบแถบที่กะพริบเบาๆ
local board: Frame
local boardRows: { TextLabel } = {}
local boardSelf: TextLabel
local skillButton: TextButton
local lastResultAt = 0

-- ===== ตัวช่วยจัดรูปข้อความ =====
-- ย่อตัวเลขยาว: 1500 → "1.5K" · 2000000 → "2.0M"
local function shortNumber(value: number): string
	if value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

-- แปลงวินาทีเป็นนาฬิกา "นาที:วินาที" เช่น 125 → "2:05"
local function clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- อ่าน Attribute ที่เป็นตัวเลข · ไม่มี/ไม่ใช่ตัวเลข → fallback
local function numberAttr(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

-- ===== วาดข้อมูลบนจอ =====
-- แถบบอส: บอสอยู่ = แถบสีรุ้งหดตามเวลา + ดาเมจรวม (ไม่โชว์ตัวเลขเวลา) · ไม่อยู่ = เตือนก่อนมา / ผลรอบล่าสุด / นับถอยหลังบอสถัดไป
local function renderBoss()
	local serverNow = workspace:GetServerTimeNow()
	if bossState:GetAttribute("Active") == true then
		-- บอสไม่มีเลือด: ความยาวแถบ = เวลาที่เหลือ · ตัวเลขบนแถบ = ดาเมจรวมทั้งเซิร์ฟ
		local left = numberAttr(bossState, "EndsAt", 0) - serverNow
		bossTitle.Visible = false -- แถบอยู่ตำแหน่งเดียวกับข้อความ → ซ่อนข้อความตอนบอสอยู่
		bossFill.Size = UDim2.fromScale(math.clamp(left / math.max(Combat.Boss.Duration, 1), 0, 1), 1)
		bossHpText.Text = `👹 ดาเมจรวม {shortNumber(numberAttr(bossState, "TotalDamage", 0))}`
		bossBarBack.Visible = true
		return
	end
	bossBarBack.Visible = false
	bossTitle.Visible = true
	local result = bossState:GetAttribute("Result")
	local incoming = numberAttr(bossState, "NextAt", math.huge) - serverNow
	if incoming > 0 and incoming <= Map.Pit.WarnSeconds then
		bossTitle.Text = `⚠️ บอสกำลังมา! ออกจากแอ่งกลางแมพใน {math.ceil(incoming)} วิ`
	elseif type(result) == "string" and result ~= "" and os.clock() - lastResultAt < RESULT_SHOW_TIME then
		bossTitle.Text = result
	else
		bossTitle.Text =
			`⏳ บอสมาในอีก {clock(numberAttr(bossState, "NextAt", serverNow) - serverNow)}`
	end
end

-- แถบบอสสีรุ้งวิบวับ (เรียกทุกเฟรมจาก RenderStepped · ทำงานเฉพาะตอนแถบโชว์ จึงเบา)
-- สีรุ้ง = เลื่อน Hue ของ 7 จุดสีวนไปเรื่อยๆ (ต่อกันเนียนไม่มีรอยตัด) · แสงวิ้ง = เลื่อน bossShine ซ้าย→ขวา
local function animateBossBar()
	if not bossBarBack.Visible then
		return
	end
	local now = os.clock()
	local shift = (now * RAINBOW_SPEED) % 1
	local keypoints = table.create(7)
	for index = 0, 6 do
		local alpha = index / 6
		local hue = (alpha - shift) % 1
		keypoints[index + 1] = ColorSequenceKeypoint.new(alpha, Color3.fromHSV(hue, RAINBOW_SATURATION, 1))
	end
	bossGradient.Color = ColorSequence.new(keypoints)
	-- แสงวิ้งเริ่มนอกแถบซ้าย → ออกนอกแถบขวา
	local progress = (now % SHINE_PERIOD) / SHINE_PERIOD
	bossShine.Position = UDim2.fromScale(-SHINE_WIDTH + progress * (1 + SHINE_WIDTH * 2), 0)
	-- ขอบขาวกะพริบ (โปร่ง 0.3 ↔ 0.8)
	bossStroke.Transparency = 0.55 + 0.25 * math.sin(now * 6)
end

-- ตารางดาเมจ: อันดับ 1–5 จาก Attribute "Top" (JSON) + ดาเมจของเราเอง · ไม่มีข้อมูล = ซ่อนตาราง
local function renderBoard()
	local ok, top = pcall(HttpService.JSONDecode, HttpService, bossState:GetAttribute("Top") or "[]")
	if not ok or type(top) ~= "table" then
		top = {}
	end
	board.Visible = #top > 0
	for index, row in boardRows do
		local entry = top[index]
		if type(entry) == "table" and type(entry.n) == "string" and type(entry.d) == "number" then
			row.Text = `{index}. {entry.n} — {shortNumber(entry.d)}`
			row.Visible = true
		else
			row.Visible = false
		end
	end
	boardSelf.Text = `คุณ: {shortNumber(numberAttr(player, "BossDamage", 0))}`
end

-- ปุ่มสกิล (กล่องสี่เหลี่ยม "Q" สีตามธาตุ) · เวลาคูลดาวน์มาจาก Attribute ที่ Server ตั้ง (SkillReadyAt / SkillActiveUntil)
-- พร้อม = สีธาตุเต็ม · กำลังทำงาน = ขอบขาวหนา · รอคูลดาวน์ = ม่านมืดค่อยๆ ลดลงจากบนลงล่าง · ยังไม่เลือกธาตุ = สีเทา
-- ✏️ เปลี่ยนตัวอักษรบนปุ่ม → SKILL_KEY_TEXT · ความเข้มตอนรอ → skillShade.BackgroundTransparency ใน Init
local SKILL_KEY_TEXT = "Q"
local skillShade: Frame
local skillKey: TextLabel
local skillStroke: UIStroke
local skillCooldownTotal = 0 -- ความยาวคูลดาวน์รอบล่าสุด (วินาที) ไว้คำนวณสัดส่วนม่าน

local function renderTurret()
	local level = TurretMath.clampLevel(player:GetAttribute("TurretLevel"))
	local element = player:GetAttribute("Element")
	local stats = ElementMath.stats(element, level)
	local def = ElementMath.defOf(element)
	local serverNow = workspace:GetServerTimeNow()
	local activeLeft = numberAttr(player, "SkillActiveUntil", 0) - serverNow
	local readyLeft = numberAttr(player, "SkillReadyAt", 0) - serverNow

	if not stats.Skill or not def then
		skillButton.BackgroundColor3 = Color3.fromRGB(90, 90, 96)
		skillKey.TextTransparency = 0.5
		skillShade.Visible = false
		skillStroke.Color = Color3.fromRGB(60, 60, 66)
		return
	end
	skillButton.BackgroundColor3 = def.Color
	skillKey.TextTransparency = 0
	skillStroke.Color = if activeLeft > 0 then Color3.new(1, 1, 1) else def.Color:Lerp(Color3.new(0, 0, 0), 0.4)
	skillStroke.Thickness = if activeLeft > 0 then 4 else 2
	if readyLeft > 0 then
		skillCooldownTotal = math.max(skillCooldownTotal, readyLeft)
		skillShade.Visible = true
		skillShade.Size = UDim2.fromScale(1, math.clamp(readyLeft / skillCooldownTotal, 0, 1))
	else
		skillCooldownTotal = 0
		skillShade.Visible = false
	end
end

local CombatUI = {}

-- สร้าง HUD การต่อสู้ทั้งหมดตอนเริ่มเกม
function CombatUI.Init()
	local gui = Components.screen("CombatGui", 4)

	-- ===== แถบบอส (บนกลาง) =====
	-- ✏️ ตำแหน่ง = BOSS_BAR_TOP (ห่างขอบบน · ScreenInsets เว้นแถบปุ่มระบบ Roblox ให้แล้ว) · สูง = BOSS_BAR_HEIGHT
	--    กว้าง 50% ของจอ · กว้างสุด 460 (UISizeConstraint)
	-- ข้างในมี (ซ้อนตำแหน่งเดียวกัน โชว์ทีละอย่าง):
	--   bossTitle = ข้อความตอนไม่มีบอส (บอสมาในอีก… / เตือน / ผลรอบ)
	--   bossBarBack (พื้นแถบ) · bossFill (แถบสีรุ้งหดตามเวลา) · bossShine (แสงวิ้ง) · bossHpText (ดาเมจรวม) = ตอนบอสอยู่
	local bossFrame = Instance.new("Frame")
	bossFrame.Name = "Boss"
	bossFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossFrame.Position = UDim2.new(0.5, 0, 0, BOSS_BAR_TOP)
	bossFrame.Size = UDim2.new(0.5, 0, 0, BOSS_BAR_HEIGHT)
	bossFrame.BackgroundTransparency = 1
	bossFrame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, BOSS_BAR_HEIGHT)
	limit.Parent = bossFrame

	bossTitle = Components.label(bossFrame, "", {
		size = UDim2.fromScale(1, 1),
		bold = true,
		alignX = Enum.TextXAlignment.Center,
	})
	bossTitle.TextStrokeTransparency = 0.5

	bossBarBack = Instance.new("Frame")
	bossBarBack.Size = UDim2.fromScale(1, 1)
	bossBarBack.BackgroundColor3 = Theme.Colors.Background
	bossBarBack.BackgroundTransparency = 0.2
	bossBarBack.Visible = false
	bossBarBack.Parent = bossFrame
	Components.corner(bossBarBack, UDim.new(0, 8))
	-- ขอบขาวกะพริบเบาๆ (ความโปร่งใสเปลี่ยนใน animateBossBar)
	bossStroke = Instance.new("UIStroke")
	bossStroke.Color = Color3.new(1, 1, 1)
	bossStroke.Thickness = 2
	bossStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bossStroke.Parent = bossBarBack

	bossFill = Instance.new("Frame")
	bossFill.Size = UDim2.fromScale(1, 1)
	bossFill.BackgroundColor3 = Color3.new(1, 1, 1) -- ขาว เพื่อให้ UIGradient ด้านล่างแสดงสีรุ้งตรงสี
	bossFill.ClipsDescendants = true -- แสงวิ้งไม่ล้นออกนอกแถบ
	bossFill.Parent = bossBarBack
	Components.corner(bossFill, UDim.new(0, 8))
	bossGradient = Instance.new("UIGradient")
	bossGradient.Parent = bossFill

	-- แสงขาววิ้ง: แถบขาวโปร่งตรงกลาง จางที่ขอบ เลื่อนจากซ้ายไปขวาวนไป
	bossShine = Instance.new("Frame")
	bossShine.AnchorPoint = Vector2.new(0.5, 0)
	bossShine.Size = UDim2.fromScale(SHINE_WIDTH, 1)
	bossShine.BackgroundColor3 = Color3.new(1, 1, 1)
	bossShine.BorderSizePixel = 0
	bossShine.Parent = bossFill
	local shineFade = Instance.new("UIGradient")
	shineFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35), -- ✏️ ความสว่างแสงวิ้ง (0 = ขาวทึบ · 1 = มองไม่เห็น)
		NumberSequenceKeypoint.new(1, 1),
	})
	shineFade.Parent = bossShine

	bossHpText = Components.label(bossBarBack, "", {
		size = UDim2.fromScale(1, 1),
		bold = true,
		textSize = 15,
		alignX = Enum.TextXAlignment.Center,
	})
	bossHpText.ZIndex = 3 -- อยู่เหนือสีรุ้ง/แสงวิ้งเสมอ
	bossHpText.TextStrokeTransparency = 0.2 -- ขอบดำให้อ่านออกบนพื้นสีรุ้ง

	-- ===== ตารางดาเมจ (ซ้าย ใต้เหรียญ — ขวากลางเป็นเมนู และขวาล่างเป็นปุ่มกระโดดบนมือถือ) =====
	-- ตำแหน่ง = board.Position (ใต้ป้ายเหรียญของ HudUI) · กว้าง 210 · สูงขยายตามจำนวนแถว
	board = Instance.new("Frame")
	board.Name = "DamageBoard"
	board.Position = UDim2.fromOffset(12, 12 + Theme.ButtonHeight + 8)
	board.Size = UDim2.fromOffset(210, 0)
	board.AutomaticSize = Enum.AutomaticSize.Y
	board.BackgroundColor3 = Theme.Colors.Background
	board.BackgroundTransparency = 0.2
	board.Visible = false
	board.Parent = gui
	Components.corner(board)
	Components.padding(board, 8)
	Components.list(board, 2)
	Components.label(
		board,
		"🏆 ดาเมจบอส",
		{ size = UDim2.new(1, 0, 0, 22), bold = true, textSize = 16, order = 0 }
	)
	for index = 1, 5 do
		boardRows[index] = Components.label(board, "", { size = UDim2.new(1, 0, 0, 18), textSize = 14, order = index })
	end
	boardSelf = Components.label(board, "", {
		size = UDim2.new(1, 0, 0, 20),
		textSize = 14,
		bold = true,
		color = Theme.Colors.Coin,
		order = 10,
	})

	-- ===== ปุ่มสกิล: กล่องสี่เหลี่ยม "Q" ล่างกลาง (เจ้าของเกมสั่ง 2026-10-01: เหลือแค่ตัว Q + สีตามธาตุ) =====
	-- ✏️ ตำแหน่ง = UDim2.new(0.5, 0, 1, -48) (กลางจอ ห่างขอบล่าง 48) · ขนาด = SKILL_SIZE
	local SKILL_SIZE = 72
	skillButton = Components.button(gui, SKILL_KEY_TEXT, {
		size = UDim2.fromOffset(SKILL_SIZE, SKILL_SIZE),
		position = UDim2.new(0.5, 0, 1, -48),
		anchor = Vector2.new(0.5, 1),
		textSize = 34,
		noHover = true,
	}, TurretController.requestSkill)
	skillButton.Name = "SkillButton"
	skillButton.ClipsDescendants = true
	skillStroke = Instance.new("UIStroke")
	skillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	skillStroke.Thickness = 2
	skillStroke.Parent = skillButton
	-- ม่านคูลดาวน์ (สีดำโปร่ง) ทับบนปุ่ม แต่ใต้ตัวอักษร
	skillShade = Instance.new("Frame")
	skillShade.Name = "Cooldown"
	skillShade.BackgroundColor3 = Color3.new(0, 0, 0)
	skillShade.BackgroundTransparency = 0.45
	skillShade.BorderSizePixel = 0
	skillShade.AnchorPoint = Vector2.new(0, 1)
	skillShade.Position = UDim2.fromScale(0, 1)
	skillShade.Size = UDim2.fromScale(1, 0)
	skillShade.ZIndex = skillButton.ZIndex
	skillShade.Visible = false
	skillShade.Parent = skillButton
	-- ตัวอักษร Q เป็น Label แยก อยู่เหนือม่าน (ข้อความของปุ่มเองจะโดนม่านทับ)
	skillButton.Text = ""
	skillKey = Instance.new("TextLabel")
	skillKey.Name = "Key"
	skillKey.BackgroundTransparency = 1
	skillKey.Size = UDim2.fromScale(1, 1)
	skillKey.Font = Enum.Font.GothamBlack
	skillKey.TextSize = 34
	skillKey.TextColor3 = Color3.new(1, 1, 1)
	skillKey.TextStrokeTransparency = 0.3
	skillKey.Text = SKILL_KEY_TEXT
	skillKey.ZIndex = skillShade.ZIndex + 1
	skillKey.Parent = skillButton
end

-- ปุ่มสกิลของแผงป้อม (สร้างใน Init) · ใช้โดย UI/TutorialUI เพื่อทำไฮไลต์/หรี่ปุ่มระหว่างฝึก (ไม่แตะการทำงานของปุ่ม)
-- (ปุ่มอัปอยู่ UI/TurretPanelUI.getUpgradeButton)
function CombatUI.getSkillButton(): TextButton?
	return skillButton
end

-- เริ่มทำงาน: รอข้อมูลบอสจาก Server · ฟัง Attribute ที่เปลี่ยน · วนอัปเดตนาฬิกาทุก REFRESH_INTERVAL วินาที
function CombatUI.Start()
	bossState = ReplicatedStorage:WaitForChild("BossState")

	bossState:GetAttributeChangedSignal("Result"):Connect(function()
		lastResultAt = os.clock()
	end)
	bossState:GetAttributeChangedSignal("Top"):Connect(renderBoard)
	player:GetAttributeChangedSignal("BossDamage"):Connect(renderBoard)
	for _, name in { "TurretLevel", "Coins", "FriendBoost", "Element", "SkillReadyAt" } do
		player:GetAttributeChangedSignal(name):Connect(renderTurret)
	end
	renderBoard()
	RunService.RenderStepped:Connect(animateBossBar) -- แถบบอสสีรุ้งวิบวับ

	-- นาฬิกานับถอยหลัง (บอส/สกิล) อัปเดตเป็นรอบ
	while true do
		renderBoss()
		renderTurret()
		task.wait(REFRESH_INTERVAL)
	end
end

return CombatUI
