-- HUD การต่อสู้: แถบบอส (บนกลาง) · ตารางดาเมจ (ซ้าย ใต้เหรียญ) · แผงป้อม (ล่างกลาง) (เจ้าของ: Client_UI_Scripter)
-- ทุกค่าแสดงจาก Attribute ที่ Server ตั้ง (ReplicatedStorage.BossState + Player Attributes) — Client ไม่เป็นเจ้าของค่า
-- ปุ่มบนจอใช้ได้ทั้งสัมผัส/เมาส์/Gamepad · ปุ่มลัดอยู่ใน TurretController
--
-- อยากปรับ:
--   ย้าย/ขยายแถบบอส → หมวด "แถบบอส" ใน CombatUI.Init (bossFrame.Position / Size)
--   ย้ายตารางดาเมจ → หมวด "ตารางดาเมจ" (board.Position / Size) · จำนวนแถว = for index = 1, 5
--   ย้ายแผงป้อม/ปุ่มอัป/ปุ่มสกิล → หมวด "แผงป้อม" (panel.Position / Size)
--   ข้อความที่แสดง → renderBoss / renderBoard / renderTurret · สี → UI/Theme.luau
--   ปุ่มลัด U/Y (อัป) และ Q/X (สกิล) ที่โชว์บนปุ่ม → keyHint(...) ใน renderTurret (ปุ่มจริงผูกใน TurretController)
-- ⚠️ ตัวเลขดาเมจ/ราคาบนจอเป็นแค่การแสดงผล · ดาเมจจริงและการหักเงินทำที่ Server เท่านั้น

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Map = require(ReplicatedStorage.Shared.Config.Map)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local ClassMath = require(ReplicatedStorage.Shared.Util.ClassMath)
local TurretMath = require(ReplicatedStorage.Shared.Util.TurretMath)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local TurretController = require(script.Parent.Parent.Controllers.TurretController)

local player = Players.LocalPlayer

-- วินาทีต่อรอบอัปเดตนาฬิกานับถอยหลัง (ลด = ลื่นขึ้นแต่ทำงานถี่ขึ้น)
local REFRESH_INTERVAL = 0.2
local RESULT_SHOW_TIME = 8 -- วินาทีที่แสดงผลรอบล่าสุดหลังบอสจบ

-- ชิ้น UI ที่ฟังก์ชัน render ต้องอัปเดต (สร้างใน Init) · bossState = ข้อมูลบอสจาก Server
local bossState: Instance
local bossTitle: TextLabel
local bossFill: Frame
local bossHpText: TextLabel
local bossBarBack: Frame
local board: Frame
local boardRows: { TextLabel } = {}
local boardSelf: TextLabel
local turretInfo: TextLabel
local upgradeButton: TextButton
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

-- ข้อความบอกปุ่มลัดตามอุปกรณ์ เช่น " [U]" (คีย์บอร์ด) / " [Y]" (Gamepad) / "" (มือถือ)
local function keyHint(keyboard: string, gamepad: string): string
	if UserInputService.GamepadEnabled then
		return ` [{gamepad}]`
	elseif UserInputService.KeyboardEnabled then
		return ` [{keyboard}]`
	end
	return ""
end

-- อ่าน Attribute ที่เป็นตัวเลข · ไม่มี/ไม่ใช่ตัวเลข → fallback
local function numberAttr(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

-- ===== วาดข้อมูลบนจอ =====
-- แถบบอส: บอสอยู่ = เวลาที่เหลือ + ดาเมจรวม · ไม่อยู่ = เตือนก่อนมา / ผลรอบล่าสุด / นับถอยหลังบอสถัดไป
local function renderBoss()
	local serverNow = workspace:GetServerTimeNow()
	if bossState:GetAttribute("Active") == true then
		-- บอสไม่มีเลือด: แถบ = เวลาที่เหลือ · ตัวเลข = ดาเมจรวมทั้งเซิร์ฟ
		local left = numberAttr(bossState, "EndsAt", 0) - serverNow
		bossTitle.Text = `👹 บอสมาแล้ว! เหลือเวลา {clock(left)}`
		bossFill.Size = UDim2.fromScale(math.clamp(left / math.max(Combat.Boss.Duration, 1), 0, 1), 1)
		bossHpText.Text = `ดาเมจรวม {shortNumber(numberAttr(bossState, "TotalDamage", 0))}`
		bossBarBack.Visible = true
		return
	end
	bossBarBack.Visible = false
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

-- แผงป้อม: เลเวล/ดาเมจ/อัตรายิง · ปุ่มอัป (ราคา · จาง = เงินไม่พอ) · ปุ่มสกิล (ทำงาน/รอคูลดาวน์/พร้อม)
local function renderTurret()
	local level = TurretMath.clampLevel(player:GetAttribute("TurretLevel"))
	local boost = numberAttr(player, "FriendBoost", 0)
	local boostText = if boost > 0 then ` · 👥 +{math.floor(boost * 100 + 0.5)}%` else ""
	-- รวมตัวคูณคลาส/สายธาตุ (ClassMath) เพื่อแสดงผลเท่านั้น · ดาเมจจริงคำนวณที่ Server
	local stats = ClassMath.stats(player:GetAttribute("TurretClass"), player:GetAttribute("TurretBranch"), level)
	local rateText = string.format("%.1f", TurretMath.fireRate(level) * stats.FireRate)
	local damageText = shortNumber(TurretMath.damage(level) * stats.Damage)
	turretInfo.Text =
		`🔫 ป้อม Lv.{level} · ดาเมจ {damageText} · ยิง {rateText}/วิ{boostText}`

	if level >= Combat.Turret.MaxLevel then
		upgradeButton.Text = "⬆ เลเวลสูงสุด"
		upgradeButton.TextTransparency = 0.5
	else
		local cost = TurretMath.upgradeCost(level)
		local coins = numberAttr(player, "Coins", 0)
		upgradeButton.Text = `⬆ อัป 💰{shortNumber(cost)}{keyHint("U", "Y")}`
		-- แค่บอกใบ้ว่าเงินไม่พอ · Server เป็นคนตัดสินจริง
		upgradeButton.TextTransparency = if coins >= cost then 0 else 0.5
	end

	local equipped = Skills.List[player:GetAttribute("EquippedSkill") or ""]
	local skillName = if equipped then equipped.Name else "-"
	local serverNow = workspace:GetServerTimeNow()
	local activeLeft = numberAttr(player, "SkillActiveUntil", 0) - serverNow
	local readyLeft = numberAttr(player, "SkillReadyAt", 0) - serverNow
	if activeLeft > 0 then
		skillButton.Text = `⚡ {skillName} {math.ceil(activeLeft)} วิ`
		skillButton.TextTransparency = 0
	elseif readyLeft > 0 then
		skillButton.Text = `⚡ รอ {math.ceil(readyLeft)} วิ`
		skillButton.TextTransparency = 0.5
	else
		skillButton.Text = `⚡ {skillName}{keyHint("Q", "X")}`
		skillButton.TextTransparency = 0
	end
end

local CombatUI = {}

-- สร้าง HUD การต่อสู้ทั้งหมดตอนเริ่มเกม
function CombatUI.Init()
	local gui = Components.screen("CombatGui", 4)

	-- ===== แถบบอส (บนกลาง) =====
	-- ตำแหน่ง = bossFrame.Position (ห่างขอบบน 12) · กว้าง 50% ของจอ สูง 64 · กว้างสุด 460 (UISizeConstraint)
	-- ข้างในมี: bossTitle (ข้อความบน) · bossBarBack (พื้นแถบ) · bossFill (แถบสีแดงหดตามเวลา) · bossHpText (ตัวเลขบนแถบ)
	local bossFrame = Instance.new("Frame")
	bossFrame.Name = "Boss"
	bossFrame.AnchorPoint = Vector2.new(0.5, 0)
	bossFrame.Position = UDim2.new(0.5, 0, 0, 12)
	bossFrame.Size = UDim2.new(0.5, 0, 0, 64)
	bossFrame.BackgroundTransparency = 1
	bossFrame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 64)
	limit.Parent = bossFrame

	bossTitle = Components.label(bossFrame, "", {
		size = UDim2.new(1, 0, 0, 28),
		bold = true,
		alignX = Enum.TextXAlignment.Center,
	})
	bossTitle.TextStrokeTransparency = 0.5

	bossBarBack = Instance.new("Frame")
	bossBarBack.Position = UDim2.fromOffset(0, 32)
	bossBarBack.Size = UDim2.new(1, 0, 0, 24)
	bossBarBack.BackgroundColor3 = Theme.Colors.Background
	bossBarBack.BackgroundTransparency = 0.2
	bossBarBack.Visible = false
	bossBarBack.Parent = bossFrame
	Components.corner(bossBarBack, UDim.new(0, 8))

	bossFill = Instance.new("Frame")
	bossFill.Size = UDim2.fromScale(1, 1)
	bossFill.BackgroundColor3 = Theme.Colors.Danger
	bossFill.Parent = bossBarBack
	Components.corner(bossFill, UDim.new(0, 8))

	bossHpText = Components.label(bossBarBack, "", {
		size = UDim2.fromScale(1, 1),
		bold = true,
		textSize = 14,
		alignX = Enum.TextXAlignment.Center,
	})

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

	-- ===== แผงป้อม (ล่างกลาง เหนือแถวคำแนะนำปุ่มลัดของ HudUI) =====
	-- ตำแหน่ง = panel.Position (ห่างขอบล่าง 48) · กว้าง 90% ของจอ แต่ไม่เกิน 420 (panelLimit)
	-- แถวบน = turretInfo (ข้อมูลป้อม) · แถวล่าง = ปุ่มอัป (ซ้าย สีเขียว) + ปุ่มสกิล (ขวา) กว้างครึ่งละปุ่ม
	local panel = Instance.new("Frame")
	panel.Name = "Turret"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -48)
	panel.Size = UDim2.new(0.9, 0, 0, 28 + 6 + Theme.ButtonHeight + 16)
	panel.BackgroundColor3 = Theme.Colors.Background
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui
	local panelLimit = Instance.new("UISizeConstraint")
	panelLimit.MaxSize = Vector2.new(420, math.huge)
	panelLimit.Parent = panel
	Components.corner(panel)
	Components.padding(panel, 8)

	turretInfo = Components.label(panel, "", {
		size = UDim2.new(1, 0, 0, 28),
		textSize = 15,
		alignX = Enum.TextXAlignment.Center,
	})

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Position = UDim2.fromOffset(0, 34)
	buttons.Size = UDim2.new(1, 0, 0, Theme.ButtonHeight)
	buttons.Parent = panel
	local layout = Components.list(buttons, 8, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	upgradeButton = Components.button(buttons, "", {
		size = UDim2.new(0.5, -4, 1, 0),
		color = Theme.Colors.Accent,
		hoverColor = Theme.Colors.AccentHover,
		textSize = 16,
		order = 1,
	}, TurretController.requestUpgrade)
	skillButton = Components.button(
		buttons,
		"",
		{ size = UDim2.new(0.5, -4, 1, 0), textSize = 16, order = 2 },
		TurretController.requestSkill
	)
end

-- เริ่มทำงาน: รอข้อมูลบอสจาก Server · ฟัง Attribute ที่เปลี่ยน · วนอัปเดตนาฬิกาทุก REFRESH_INTERVAL วินาที
function CombatUI.Start()
	bossState = ReplicatedStorage:WaitForChild("BossState")

	bossState:GetAttributeChangedSignal("Result"):Connect(function()
		lastResultAt = os.clock()
	end)
	bossState:GetAttributeChangedSignal("Top"):Connect(renderBoard)
	player:GetAttributeChangedSignal("BossDamage"):Connect(renderBoard)
	for _, name in { "TurretLevel", "Coins", "FriendBoost", "EquippedSkill", "TurretClass", "TurretBranch" } do
		player:GetAttributeChangedSignal(name):Connect(renderTurret)
	end
	renderBoard()

	-- นาฬิกานับถอยหลัง (บอส/สกิล) อัปเดตเป็นรอบ
	while true do
		renderBoss()
		renderTurret()
		task.wait(REFRESH_INTERVAL)
	end
end

return CombatUI
