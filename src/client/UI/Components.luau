-- ชิ้นส่วน UI ที่ใช้ซ้ำ (ปุ่ม แผง สไลเดอร์ สวิตช์) — ทุกชิ้นรองรับ เมาส์ / สัมผัส / Gamepad
-- โมดูล helper: ไม่มี Init/Start (loader require แล้วข้ามไป)
-- ใครใช้: UI ทุกไฟล์ (HudUI, SettingsUI, ElementUI, CombatUI)
-- ⚠️ แก้ไฟล์นี้ = ทุกหน้าจอเปลี่ยนตาม · อยากแก้แค่หน้าเดียว → ส่ง options (size/position/color) จากไฟล์หน้านั้นแทน
-- สี/ฟอนต์/ความสูงปุ่ม → UI/Theme.luau

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local Components = {}

-- ===== ตัวช่วยพื้นฐาน =====
-- เปลี่ยนค่าของชิ้นแบบนุ่มนวล (ความเร็ว = Theme.TweenTime)
local function tween(instance: Instance, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(Theme.TweenTime, Enum.EasingStyle.Quad), goal):Play()
end

-- ทำให้มุมของ parent โค้งมน (ไม่ใส่ radius = Theme.Corner)
function Components.corner(parent: Instance, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = parent
end

-- เว้นขอบด้านในของ parent ทุกด้านเท่ากัน pixels พิกเซล
function Components.padding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

-- เรียงลูกของ parent ต่อกันอัตโนมัติ (ค่าเริ่มแนวตั้ง) ห่างกัน spacing พิกเซล · เรียงตาม LayoutOrder
function Components.list(parent: Instance, spacing: number, direction: Enum.FillDirection?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, spacing)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

-- ScreenGui ใหม่ใน PlayerGui · เว้นพื้นที่ปุ่มระบบของ Roblox และ notch มือถือให้อัตโนมัติ
function Components.screen(name: string, displayOrder: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder = displayOrder or 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- ===== ป้ายข้อความ =====
-- ตัวเลือกของ label (ไม่ใส่ = ค่าเริ่มต้น): size/position = ขนาด/ตำแหน่ง · bold = ตัวหนา
-- textSize = ขนาดตัวอักษร · color = สีตัวอักษร · alignX = ชิดซ้าย/กลาง/ขวา · order = ลำดับในรายการ
type LabelOptions = {
	size: UDim2?,
	position: UDim2?,
	bold: boolean?,
	textSize: number?,
	color: Color3?,
	alignX: Enum.TextXAlignment?,
	order: number?,
}

-- สร้างป้ายข้อความโปร่งใสใน parent · ค่าเริ่ม: กว้างเต็ม สูง Theme.ButtonHeight ชิดซ้าย
function Components.label(parent: Instance, text: string, options: LabelOptions?): TextLabel
	local opts: LabelOptions = options or {}
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = opts.size or UDim2.new(1, 0, 0, Theme.ButtonHeight)
	label.Position = opts.position or UDim2.new()
	label.Font = if opts.bold then Theme.FontBold else Theme.Font
	label.TextSize = opts.textSize or Theme.TextSize
	label.TextColor3 = opts.color or Theme.Colors.Text
	label.TextXAlignment = opts.alignX or Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.LayoutOrder = opts.order or 0
	label.Text = text
	label.Parent = parent
	return label
end

-- ===== ปุ่ม =====
-- ตัวเลือกของปุ่ม: anchor = จุดยึด · color = สีพื้น · hoverColor = สีตอนชี้/เลือก (อื่นๆ เหมือน LabelOptions)
type ButtonOptions = {
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	hoverColor: Color3?,
	textSize: number?,
	order: number?,
	noHover: boolean?, -- ปิดการเปลี่ยนสีอัตโนมัติ (ปุ่มที่คุมสีเอง เช่น สวิตช์)
}

-- สร้างปุ่มใน parent · กดแล้วเรียก onClick · เปลี่ยนสีเมื่อเมาส์ชี้หรือ Gamepad เลือก
-- ค่าเริ่ม: กว้างเต็ม สูง Theme.ButtonHeight สี Theme.Colors.Surface
function Components.button(parent: Instance, text: string, options: ButtonOptions?, onClick: (() -> ())?): TextButton
	local opts: ButtonOptions = options or {}
	local baseColor = opts.color or Theme.Colors.Surface
	local hoverColor = opts.hoverColor or Theme.Colors.SurfaceHover

	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Size = opts.size or UDim2.new(1, 0, 0, Theme.ButtonHeight)
	button.Position = opts.position or UDim2.new()
	button.AnchorPoint = opts.anchor or Vector2.zero
	button.BackgroundColor3 = baseColor
	button.Font = Theme.FontBold
	button.TextSize = opts.textSize or Theme.TextSize
	button.TextColor3 = Theme.Colors.Text
	button.LayoutOrder = opts.order or 0
	button.Text = text
	button.Parent = parent
	Components.corner(button)

	-- เปลี่ยนสีปุ่มเป็นสี hover (on = true) หรือกลับสีเดิม
	local function highlight(on: boolean)
		if opts.noHover then
			return
		end
		tween(button, { BackgroundColor3 = if on then hoverColor else baseColor })
	end
	button.MouseEnter:Connect(function()
		highlight(true)
	end)
	button.MouseLeave:Connect(function()
		highlight(false)
	end)
	button.SelectionGained:Connect(function()
		highlight(true)
	end)
	button.SelectionLost:Connect(function()
		highlight(false)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

-- ===== แผงหน้าต่าง =====
-- แผงหน้าต่างกลางจอ: คืน (frame, content, closeButton) · content เรียงของแนวตั้งและเลื่อนได้เมื่อยาวเกินจอ
function Components.panel(parent: Instance, title: string, onClose: () -> ()): (Frame, ScrollingFrame, TextButton)
	-- กรอบแผง: กลางจอ · กว้าง 90% สูง 80% ของจอ (แก้ Position/Size ตรงนี้ = ทุกแผงเปลี่ยน)
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.9, 0.8)
	frame.BackgroundColor3 = Theme.Colors.Background
	frame.BackgroundTransparency = Theme.PanelTransparency
	frame.Visible = false
	frame.Parent = parent
	Components.corner(frame)
	Components.padding(frame, Theme.Padding)

	-- ขนาดแผงใหญ่สุด 480 × 440 พิกเซล (จอใหญ่จะไม่ขยายเกินนี้)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 440)
	limit.Parent = frame

	-- เส้นขอบแผง (หนา 1 พิกเซล)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.SurfaceHover
	stroke.Thickness = 1
	stroke.Parent = frame

	-- หัวข้อแผง (ซ้ายบน)
	Components.label(frame, title, {
		size = UDim2.new(1, -Theme.ButtonHeight - 8, 0, Theme.ButtonHeight),
		bold = true,
		textSize = Theme.TitleSize,
	})

	-- ปุ่มปิด ✕ (มุมขวาบน · ชี้แล้วเป็นสีแดง)
	local closeButton = Components.button(frame, "✕", {
		size = UDim2.fromOffset(Theme.ButtonHeight, Theme.ButtonHeight),
		position = UDim2.fromScale(1, 0),
		anchor = Vector2.new(1, 0),
		hoverColor = Theme.Colors.Danger,
	}, onClose)
	closeButton.Name = "Close"

	-- พื้นที่เนื้อหาใต้หัวข้อ (เลื่อนขึ้นลงได้ · ของข้างในห่างกัน 8 พิกเซล)
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromOffset(0, Theme.ButtonHeight + Theme.Padding)
	content.Size = UDim2.new(1, 0, 1, -(Theme.ButtonHeight + Theme.Padding))
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarThickness = 6
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = frame
	Components.list(content, 8)

	return frame, content, closeButton
end

-- ===== ตัวควบคุมในหน้าตั้งค่า (สวิตช์ + สไลเดอร์) =====
-- แถวหนึ่งบรรทัด: ชื่อด้านซ้าย 40% · ตัวควบคุมด้านขวา 60% (คืน frame ฝั่งขวา)
local function row(parent: Instance, labelText: string, order: number?): Frame
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, -10, 0, Theme.ButtonHeight)
	container.LayoutOrder = order or 0
	container.Parent = parent

	Components.label(container, labelText, { size = UDim2.new(0.4, -8, 1, 0), color = Theme.Colors.TextMuted })

	local right = Instance.new("Frame")
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.fromScale(0.6, 1)
	right.Parent = container
	return right
end

-- สวิตช์เปิด/ปิด · คืนฟังก์ชัน set(value) สำหรับอัปเดตจากภายนอก
function Components.toggle(parent: Instance, labelText: string, value: boolean, onChanged: (boolean) -> (), order: number?): (boolean) -> ()
	local right = row(parent, labelText, order)
	local current = value
	local button: TextButton

	-- วาดสวิตช์ตามค่า: เปิด = สี Accent · ปิด = สี Surface
	local function render()
		button.Text = if current then "เปิด" else "ปิด"
		button.BackgroundColor3 = if current then Theme.Colors.Accent else Theme.Colors.Surface
	end

	button = Components.button(right, "", { size = UDim2.new(0, 110, 1, 0), noHover = true }, function()
		current = not current
		render()
		onChanged(current)
	end)
	render()

	return function(newValue: boolean)
		current = newValue
		render()
	end
end

-- สไลเดอร์ตัวเลข: ลากได้ (เมาส์/สัมผัส) และมีปุ่ม − / + สำหรับ Gamepad · คืนฟังก์ชัน set(value)
function Components.slider(
	parent: Instance,
	labelText: string,
	range: { min: number, max: number, step: number },
	value: number,
	onChanged: (number) -> (),
	order: number?
): (number) -> ()
	local right = row(parent, labelText, order)
	local current = value
	local stepWidth = Theme.ButtonHeight

	-- แถบเลื่อน (อยู่ระหว่างปุ่ม − กับ + · สูง 10 พิกเซล)
	local bar = Instance.new("TextButton")
	bar.Name = "Bar"
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.Selectable = false
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, stepWidth + 6, 0.5, 0)
	bar.Size = UDim2.new(1, -(stepWidth * 2 + 18) - 44, 0, 10)
	bar.BackgroundColor3 = Theme.Colors.Surface
	bar.Parent = right
	Components.corner(bar, UDim.new(1, 0))

	-- ส่วนที่เติมสีในแถบ (ยาวตามค่าปัจจุบัน)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Theme.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Components.corner(fill, UDim.new(1, 0))

	-- ตัวเลขค่าปัจจุบัน (ขวาสุด กว้าง 44 พิกเซล)
	local valueLabel = Components.label(right, "", {
		size = UDim2.new(0, 44, 1, 0),
		position = UDim2.new(1, -44, 0, 0),
		alignX = Enum.TextXAlignment.Right,
	})

	-- วาดแถบเติมสี + ตัวเลขตามค่าปัจจุบัน
	local function render()
		local alpha = (current - range.min) / (range.max - range.min)
		fill.Size = UDim2.fromScale(alpha, 1)
		valueLabel.Text = tostring(current)
	end

	-- ตั้งค่าใหม่ (ปัดให้ลง step และไม่เกิน min–max) · notify = true → แจ้ง onChanged
	local function setValue(newValue: number, notify: boolean)
		local snapped = range.min + math.floor((newValue - range.min) / range.step + 0.5) * range.step
		snapped = math.clamp(snapped, range.min, range.max)
		if snapped == current then
			return
		end
		current = snapped
		render()
		if notify then
			onChanged(current)
		end
	end

	-- ปุ่ม − (ซ้าย) / + (ขวา) ลด-เพิ่มทีละ step
	Components.button(right, "−", {
		size = UDim2.new(0, stepWidth, 1, 0),
	}, function()
		setValue(current - range.step, true)
	end)
	Components.button(right, "+", {
		size = UDim2.new(0, stepWidth, 1, 0),
		position = UDim2.new(1, -(stepWidth + 44 + 6), 0, 0),
	}, function()
		setValue(current + range.step, true)
	end)

	-- ลากแถบด้วยเมาส์/นิ้ว: แปลงตำแหน่ง x บนจอเป็นค่า
	local dragging = false
	local function updateFromX(x: number)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		setValue(range.min + alpha * (range.max - range.min), true)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	render()
	return function(newValue: number)
		setValue(newValue, false)
		render()
	end
end

return Components
