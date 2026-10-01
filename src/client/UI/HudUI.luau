-- HUD หลัก: เหรียญ (มุมซ้ายบน) · เมนู (ขวากลาง) · FPS (ซ้ายล่าง) · คำแนะนำปุ่มลัด (กลางล่าง)
-- เหรียญแสดงจาก Attribute "Coins" ที่ Server ตั้งให้ (StatsService) — Client แค่แสดง ไม่เป็นเจ้าของค่า
-- อยากย้าย/ขยายของบนจอ → แก้ Position / Size ในหมวดของชิ้นนั้นด้านล่าง
--   UDim2.fromOffset(x, y) = พิกเซล · UDim2.new(สัดส่วนX, พิกเซลX, สัดส่วนY, พิกเซลY) (สัดส่วน 1 = สุดจอ)
--   AnchorPoint = จุดยึดของชิ้น (0,0 = มุมซ้ายบน · 1,0.5 = ขวากลาง)
-- อยากเพิ่มปุ่มเมนู → เพิ่ม Components.button ในหมวดเมนู + ขยาย menu.Size
-- สี/ฟอนต์ → UI/Theme.luau

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local TurretPanelUI = require(script.Parent.TurretPanelUI)
local Settings = require(script.Parent.Parent.Controllers.SettingsController)

local player = Players.LocalPlayer

-- ป้ายที่ต้องใช้ต่อใน Start()
local fpsLabel: TextLabel
local hintLabel: TextLabel?

-- แผงที่ยังไม่มีระบบจริง: แสดงข้อความ "กำลังพัฒนา"
local function placeholderPanel(gui: ScreenGui, name: string, title: string, message: string)
	local frame, content, closeButton = Components.panel(gui, title, Panels.close)
	local label = Components.label(content, message, {
		size = UDim2.new(1, -10, 0, 80),
		color = Theme.Colors.TextMuted,
		alignX = Enum.TextXAlignment.Center,
	})
	label.TextWrapped = true
	Panels.register(name, frame, closeButton)
end

local HudUI = {}

-- สร้าง HUD ทั้งหมดตอนเริ่มเกม
function HudUI.Init()
	local gui = Components.screen("HudGui", 5)

	-- ===== ป้ายเหรียญ (มุมซ้ายบน) =====
	-- ตำแหน่ง = badge.Position · ขนาด = badge.Size · สีตัวเลข = Theme.Colors.Coin
	local badge = Instance.new("Frame")
	badge.Name = "Coins"
	badge.Position = UDim2.fromOffset(12, 12)
	badge.Size = UDim2.fromOffset(160, Theme.ButtonHeight)
	badge.BackgroundColor3 = Theme.Colors.Background
	badge.BackgroundTransparency = 0.2
	badge.Parent = gui
	Components.corner(badge)
	Components.padding(badge, 8)
	local coinLabel = Components.label(badge, "", {
		size = UDim2.fromScale(1, 1),
		bold = true,
		color = Theme.Colors.Coin,
	})
	-- อัปเดตตัวเลขเมื่อ Server เปลี่ยน Attribute "Coins"
	local function renderCoins()
		local coins = player:GetAttribute("Coins")
		coinLabel.Text = if typeof(coins) == "number" then `💰 {coins}` else "💰 …"
	end
	player:GetAttributeChangedSignal("Coins"):Connect(renderCoins)
	renderCoins()

	-- ===== ปุ่มเมนู (ขวากลาง) =====
	-- ตำแหน่ง = menu.Position · ขนาดกล่อง = menu.Size (สูงพอสำหรับ 4 ปุ่ม) · ระยะห่างปุ่ม = Components.list(menu, 8)
	-- order = ลำดับปุ่มจากบนลงล่าง
	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.AnchorPoint = Vector2.new(1, 0.5)
	menu.Position = UDim2.new(1, -12, 0.5, 0)
	menu.Size = UDim2.fromOffset(170, Theme.ButtonHeight * 4 + 24)
	menu.Parent = gui
	Components.list(menu, 8)
	local settingsButton = Components.button(menu, "⚙  ตั้งค่า", { order = 1 }, function()
		Panels.toggle("Settings")
	end)
	local shopButton = Components.button(menu, "🛒  ร้านค้า", { order = 2 }, function()
		Panels.toggle("Shop")
	end)
	local bagButton = Components.button(menu, "🎒  กระเป๋า", { order = 3 }, function()
		Panels.toggle("Bag")
	end)
	-- ✏️ ปุ่มแผงป้อม (อุปกรณ์ + อัปเกรด) = ทางสำรอง · ทางหลักคือคลิก/แตะป้อมในโลก (UI/TurretTapUI)
	--   แผงสร้างใน UI/TurretPanelUI (ปุ่มลัด G / RB อยู่ในไฟล์นั้น)
	local gearButton = Components.button(menu, "🛠  ป้อม", { order = 4 }, TurretPanelUI.toggle)

	-- ตั้งชื่อปุ่ม (UI/TutorialUI หาปุ่มด้วยชื่อนี้เพื่อหรี่ปุ่มที่ไม่เกี่ยวระหว่างฝึก)
	settingsButton.Name = "Settings"
	shopButton.Name = "Shop"
	bagButton.Name = "Bag"
	gearButton.Name = "Gear"

	-- แผงชั่วคราวของปุ่มที่ยังไม่มีระบบ
	placeholderPanel(gui, "Shop", "ร้านค้า", "ร้านค้ากำลังพัฒนา\nจะเปิดเมื่อมีระบบเงินและไอเทม")
	placeholderPanel(gui, "Bag", "กระเป๋า", "กระเป๋ากำลังพัฒนา\nจะแสดงไอเทมที่คุณมี")

	-- ===== ตัวนับ FPS (ซ้ายล่าง · แสดงเมื่อเปิดในตั้งค่า) =====
	-- ตำแหน่ง/ขนาด = position / size ด้านล่าง
	fpsLabel = Components.label(gui, "FPS: -", {
		size = UDim2.fromOffset(120, 28),
		position = UDim2.new(0, 12, 1, -12),
		color = Theme.Colors.TextMuted,
		textSize = 14,
	})
	fpsLabel.AnchorPoint = Vector2.new(0, 1)
	fpsLabel.Visible = Settings.get("ShowFps")
	Settings.Changed:Connect(function(key: string, value: any)
		if key == "ShowFps" then
			fpsLabel.Visible = value
		end
	end)

	-- ===== คำแนะนำปุ่มลัด (กลางล่าง · ไม่แสดงบนจอสัมผัสอย่างเดียว) =====
	local hint = if UserInputService.GamepadEnabled
		then "กด Select เพื่อเปิดตั้งค่า"
		elseif UserInputService.KeyboardEnabled then "กด M เพื่อเปิดตั้งค่า"
		else nil
	if hint then
		local label = Components.label(gui, hint, {
			size = UDim2.fromOffset(300, 28),
			position = UDim2.new(0.5, 0, 1, -12),
			color = Theme.Colors.TextMuted,
			textSize = 14,
			alignX = Enum.TextXAlignment.Center,
		})
		label.AnchorPoint = Vector2.new(0.5, 1)
		hintLabel = label
	end
end

-- เริ่มทำงาน: ค่อยๆ ซ่อนคำแนะนำหลัง 6 วินาที + นับ FPS ทุก 1 วินาที
function HudUI.Start()
	if hintLabel then
		task.delay(6, function()
			TweenService:Create(hintLabel :: TextLabel, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		end)
	end

	local frames = 0
	local elapsed = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		frames += 1
		elapsed += deltaTime
		if elapsed >= 1 then
			if fpsLabel.Visible then
				fpsLabel.Text = `FPS: {math.floor(frames / elapsed + 0.5)}`
			end
			frames = 0
			elapsed = 0
		end
	end)
end

return HudUI
