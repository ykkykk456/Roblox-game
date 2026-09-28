-- หน้าเลือกคลาสป้อม + สายธาตุ (เจ้าของ: Client_UI_Scripter · โครงหน้าจอ: UX_Architect) · สเปก: design/turret-classes.md
-- ทุกสถานะอ่านจาก Player Attribute ที่ Server ตั้ง (TurretClass / TurretBranch / TurretLevel) — Client แค่ขอ ไม่ตัดสินเอง
-- ข้อความ/สี/ตัวคูณที่แสดงอ่านจาก Config/Skill_class_default (ตัวคูณเทียบป้อมพื้นฐาน · ไม่ใช่ดาเมจจริง)
--
-- โครงหน้าจอ:
--   ปุ่ม HUD (กลางล่าง เหนือแผงป้อมของ CombatUI) → เปิด/ปิดแผง "Class" · คีย์ลัด C / LB (Gamepad)
--   แผง 3 มุมมอง (ใช้ Panels: เปิดได้ทีละแผง)
--     Class  = การ์ด 4 คลาส (เลือก/เปลี่ยนได้ฟรีจนกว่าจะมีสาย) · เด้งเองครั้งแรกเมื่อ TurretClass == ""
--     Branch = การ์ดสายธาตุของคลาสตัวเอง (กดยืนยัน 2 ครั้ง เพราะเลือกแล้วล็อก) · เด้งเองครั้งแรกเมื่อเลเวลถึง
--     Info   = หลังเลือกสายแล้ว: ดูข้อมูลคลาส/สายอย่างเดียว
--   การ์ดเรียงแนวตั้งในแผงที่เลื่อนได้ → ใช้ได้บนจอมือถือแคบ · ทุกปุ่มสูง ≥ 44 px (Theme.ButtonHeight)

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClassConfig = require(ReplicatedStorage.Shared.Config.Skill_class_default)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local ClassController = require(script.Parent.Parent.Controllers.ClassController)

local player = Players.LocalPlayer

local PANEL_NAME = "Class"
local CONFIRM_SECONDS = 3 -- เวลาที่ปุ่ม "ยืนยัน?" รอการกดครั้งที่สอง
local REFRESH_INTERVAL = 0.5
local ACTION_WIDTH = 96
local DAMAGE_COLOR = Color3.fromRGB(235, 96, 80)
local RATE_COLOR = Color3.fromRGB(255, 204, 64)
local WHITE = Color3.new(1, 1, 1)

type View = "Class" | "Branch" | "Info"
type State = {
	known: boolean, -- Server ส่ง TurretClass มาแล้ว (ข้อมูลผู้เล่นโหลดเสร็จ)
	class: string, -- "" = ยังไม่เลือก (หรือ id ที่ไม่มีใน Config)
	branch: string, -- id สายจาก Attribute (อาจไม่มีใน Config)
	locked: boolean, -- มีสายแล้ว = เปลี่ยนคลาส/สายไม่ได้
	level: number,
}
type Action = { text: string, primary: boolean?, dim: boolean?, onClick: (() -> ())? }
type Scale = { damage: number, rate: number }

local frame: Frame
local content: ScrollingFrame
local closeButton: TextButton
local hudButton: TextButton
local hudStroke: UIStroke

local view: View = "Class"
local lastSignature = ""
local firstFocus: GuiObject? = nil
local promptedClass = false
local promptedBranch = false
local awaitingClass = false -- ส่งคำขอเปลี่ยนคลาสแล้ว → ปิดแผงเมื่อ Server ตั้งค่าใหม่ ให้เห็นป้อมเปลี่ยนร่าง
local confirmId: string? = nil
local confirmToken = 0

local function readState(): State
	local class = player:GetAttribute("TurretClass")
	local branch = player:GetAttribute("TurretBranch")
	local level = player:GetAttribute("TurretLevel")
	local classId = if type(class) == "string" and ClassConfig.Classes[class] then class else ""
	-- ล็อกเฉพาะสายที่ถูกต้องของคลาสตัวเอง (ตรงกับ ClassMath.canChooseClass ฝั่ง Server)
	local branchDef = if type(branch) == "string" then ClassConfig.Branches[branch] else nil
	local validBranch = branchDef ~= nil and branchDef.Class == classId
	return {
		known = type(class) == "string",
		class = classId,
		branch = if validBranch then branch else "",
		locked = validBranch,
		level = if type(level) == "number" and level == level then level else 0,
	}
end

-- บอกใบ้เท่านั้น · Server ตรวจเลเวล/สิทธิ์จริงเสมอ
local function canChooseBranch(state: State): boolean
	return state.class ~= "" and not state.locked and state.level >= ClassConfig.BranchLevel
end

local function defaultView(state: State): View
	if state.locked then
		return "Info"
	elseif canChooseBranch(state) then
		return "Branch"
	end
	return "Class"
end

local function resolveView(state: State, wanted: View): View
	if state.locked then
		return "Info"
	elseif wanted == "Branch" and not canChooseBranch(state) then
		return "Class"
	elseif wanted == "Info" then
		return defaultView(state)
	end
	return wanted
end

-- แถว FireColors ที่ใช้ตอนนี้ = แถวสุดท้ายที่ Level ≤ เลเวลป้อม (ตามสเปก) · ต่ำกว่าแถวแรก = nil
local function fireIndex(level: number): number?
	local found = nil
	for index, row in ClassConfig.FireColors do
		if row.Level <= level then
			found = index
		end
	end
	return found
end

local function tint(color: Color3): Color3
	-- สีคลาสบางสีมืด (นักฆ่า) → ผสมขาวให้อ่านออกบนพื้นมืด
	return color:Lerp(WHITE, 0.35)
end

local function formatMultiplier(value: number): string
	return string.format("%g", math.floor(value * 100 + 0.5) / 100)
end

local function keyHint(): string
	if UserInputService.GamepadEnabled then
		return " [LB]"
	elseif UserInputService.KeyboardEnabled then
		return " [C]"
	end
	return ""
end

local function wrapped(parent: Instance, text: string, textSize: number, color: Color3, order: number): TextLabel
	local label = Components.label(parent, text, {
		size = UDim2.new(1, -10, 0, 0),
		textSize = textSize,
		color = color,
		order = order,
	})
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	return label
end

local function scaleOf(defs: { any }): Scale
	local scale = { damage = 0.001, rate = 0.001 }
	for _, def in defs do
		scale.damage = math.max(scale.damage, def.Damage)
		scale.rate = math.max(scale.rate, def.FireRate)
	end
	return scale
end

-- แถบสถิติแบบง่าย: ความยาว = ค่า ÷ ค่าสูงสุดในกลุ่มที่แสดงอยู่
local function statBar(parent: Instance, icon: string, value: number, maxValue: number, color: Color3, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 16)
	row.LayoutOrder = order
	row.Parent = parent

	Components.label(row, `{icon} ×{formatMultiplier(value)}`, {
		size = UDim2.new(0, 64, 1, 0),
		textSize = 13,
		color = Theme.Colors.TextMuted,
	})

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, 68, 0.5, 0)
	back.Size = UDim2.new(1, -68, 0, 8)
	back.BackgroundColor3 = Theme.Colors.Background
	back.BorderSizePixel = 0
	back.Parent = row
	Components.corner(back, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(value / maxValue, 0.06, 1), 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	Components.corner(fill, UDim.new(1, 0))
end

-- การ์ดคลาส/สาย: ชื่อ + สี · คำอธิบาย · ⚔ ดาเมจ / ⚡ อัตรายิง · ปุ่มด้านขวา (ถ้ามี action)
local function card(parent: Instance, def: any, order: number, scale: Scale, action: Action?): TextButton?
	local accent = tint(def.Color)

	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.Colors.Surface
	box.Size = UDim2.new(1, -10, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.LayoutOrder = order
	box.Parent = parent
	Components.corner(box)
	Components.padding(box, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Parent = box

	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	info.Size = UDim2.new(1, if action then -(ACTION_WIDTH + 8) else 0, 0, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.Parent = box
	Components.list(info, 4)

	local nameRow = Instance.new("Frame")
	nameRow.BackgroundTransparency = 1
	nameRow.Size = UDim2.new(1, 0, 0, 22)
	nameRow.LayoutOrder = 1
	nameRow.Parent = info
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.Position = UDim2.fromScale(0, 0.5)
	swatch.Size = UDim2.fromOffset(14, 14)
	swatch.BackgroundColor3 = def.Color
	swatch.Parent = nameRow
	Components.corner(swatch, UDim.new(1, 0))
	local swatchStroke = Instance.new("UIStroke")
	swatchStroke.Color = Theme.Colors.TextMuted
	swatchStroke.Parent = swatch
	Components.label(nameRow, def.Name, {
		size = UDim2.new(1, -20, 1, 0),
		position = UDim2.fromOffset(20, 0),
		bold = true,
		textSize = 17,
		color = accent,
	})

	local description = Components.label(info, def.Description, {
		size = UDim2.new(1, 0, 0, 0),
		textSize = 14,
		color = Theme.Colors.TextMuted,
		order = 2,
	})
	description.AutomaticSize = Enum.AutomaticSize.Y
	description.TextWrapped = true
	description.TextTruncate = Enum.TextTruncate.None

	statBar(info, "⚔", def.Damage, scale.damage, DAMAGE_COLOR, 3)
	statBar(info, "⚡", def.FireRate, scale.rate, RATE_COLOR, 4)

	if not action then
		return nil
	end
	local button = Components.button(box, action.text, {
		size = UDim2.fromOffset(ACTION_WIDTH, Theme.ButtonHeight),
		position = UDim2.fromScale(1, 0.5),
		anchor = Vector2.new(1, 0.5),
		color = if action.primary then Theme.Colors.Accent else Theme.Colors.SurfaceHover,
		hoverColor = if action.primary then Theme.Colors.AccentHover else Theme.Colors.SurfaceHover,
		textSize = 16,
	}, action.onClick)
	if action.dim then
		button.TextTransparency = 0.5
	end
	return button
end

-- แถบสีบอลไฟของสายไฟ (ปืนใหญ่) · ไฮไลต์สีที่ใช้อยู่ถ้ารู้เลเวล
local function fireStrip(parent: Instance, order: number, currentLevel: number?)
	wrapped(parent, "🔥 สีบอลไฟเปลี่ยนตามเลเวลป้อม", 14, Theme.Colors.Coin, order)

	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -10, 0, 56)
	strip.LayoutOrder = order + 1
	strip.Parent = parent
	local layout = Components.list(strip, 4, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local count = #ClassConfig.FireColors
	local current = if currentLevel then fireIndex(currentLevel) else nil
	for index, row in ClassConfig.FireColors do
		local item = Instance.new("Frame")
		item.BackgroundColor3 = Theme.Colors.Surface
		item.Size = UDim2.new(1 / count, -4, 1, 0)
		item.LayoutOrder = index
		item.Parent = strip
		Components.corner(item, UDim.new(0, 8))
		if index == current then
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Theme.Colors.Coin
			stroke.Thickness = 2
			stroke.Parent = item
		end

		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0)
		dot.Position = UDim2.new(0.5, 0, 0, 4)
		dot.Size = UDim2.fromOffset(18, 18)
		dot.BackgroundColor3 = row.Color
		dot.Parent = item
		Components.corner(dot, UDim.new(1, 0))

		Components.label(item, `Lv.{row.Level}`, {
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.fromOffset(0, 24),
			textSize = 12,
			bold = index == current,
			alignX = Enum.TextXAlignment.Center,
		})
		Components.label(item, row.Name, {
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.fromOffset(0, 38),
			textSize = 12,
			color = Theme.Colors.TextMuted,
			alignX = Enum.TextXAlignment.Center,
		})
	end
end

local function navButton(text: string, order: number, onClick: () -> ()): TextButton
	return Components.button(content, text, {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		textSize = 16,
		order = order,
	}, onClick)
end

local render: (force: boolean?) -> ()

local function buildClassView(state: State)
	local current = ClassConfig.Classes[state.class]
	local header = if current
		then `คลาสตอนนี้: {current.Name} · เปลี่ยนได้ฟรีจนกว่าจะเลือกสายธาตุ (ป้อม Lv.{ClassConfig.BranchLevel})`
		else `เลือกคลาสป้อมของคุณ · เปลี่ยนได้ฟรีจนกว่าจะเลือกสายธาตุที่ป้อม Lv.{ClassConfig.BranchLevel}`
	wrapped(content, header, 15, Theme.Colors.Text, 1)

	if canChooseBranch(state) then
		firstFocus = navButton("✨ ไปเลือกสายธาตุ", 2, function()
			view = "Branch"
			render(true)
		end)
	end

	local defs = {}
	for _, id in ClassConfig.ClassOrder do
		table.insert(defs, ClassConfig.Classes[id])
	end
	local scale = scaleOf(defs)

	for index, id in ClassConfig.ClassOrder do
		local def = ClassConfig.Classes[id]
		local action: Action = if id == state.class
			then { text = "✔ ใช้อยู่", dim = true }
			else {
				text = "เลือก",
				primary = true,
				onClick = function()
					awaitingClass = true
					ClassController.requestClass(id)
				end,
			}
		local button = card(content, def, 10 + index, scale, action)
		if firstFocus == nil and id ~= state.class then
			firstFocus = button
		end
	end
end

local function buildBranchView(state: State)
	local classDef = ClassConfig.Classes[state.class]
	wrapped(
		content,
		`✨ ป้อมถึง Lv.{ClassConfig.BranchLevel} แล้ว! เลือกสายธาตุของ{classDef.Name} ได้ 1 สาย`,
		15,
		Theme.Colors.Text,
		1
	)
	wrapped(content, "เลือกแล้วเปลี่ยนไม่ได้ · กดปุ่มซ้ำอีกครั้งเพื่อยืนยัน", 13, Theme.Colors.TextMuted, 2)

	local defs = {}
	for _, def in ClassConfig.Branches do
		table.insert(defs, def)
	end
	local scale = scaleOf(defs) -- เทียบทุกสายในเกม ให้แถบของแต่ละคลาสเปรียบเทียบกันได้

	local confirmButton: TextButton? = nil
	for index, id in classDef.Branches do
		local def = ClassConfig.Branches[id]
		if not def then
			continue
		end
		local button: TextButton
		local function resetLater(token: number)
			task.delay(CONFIRM_SECONDS, function()
				if confirmToken == token and button.Parent then
					confirmId = nil
					button.Text = "เลือก"
				end
			end)
		end
		button = card(content, def, 10 + index * 2, scale, {
			text = "เลือก",
			primary = true,
			onClick = function()
				confirmToken += 1
				if confirmId == id then
					-- กดครั้งที่สอง = ส่งคำขอ · ผลจริงมาทาง Attribute TurretBranch
					confirmId = nil
					button.Text = "กำลังส่ง…"
					ClassController.requestBranch(id)
				else
					if confirmButton and confirmButton ~= button and confirmButton.Parent then
						confirmButton.Text = "เลือก"
					end
					confirmId = id
					confirmButton = button
					button.Text = "ยืนยัน?"
				end
				resetLater(confirmToken)
			end,
		}) :: TextButton
		if firstFocus == nil then
			firstFocus = button
		end
		if id == "Fire" or def.Effect and def.Effect.Kind == "FireColor" then
			fireStrip(content, 11 + index * 2, nil)
		end
	end

	navButton("🔁 เปลี่ยนคลาส", 90, function()
		view = "Class"
		render(true)
	end)
end

local function buildInfoView(state: State)
	wrapped(content, "🔒 เลือกสายธาตุแล้ว · ป้อมของคุณตอนนี้", 15, Theme.Colors.Text, 1)

	local classDef = ClassConfig.Classes[state.class]
	if classDef then
		local classes = {}
		for _, id in ClassConfig.ClassOrder do
			table.insert(classes, ClassConfig.Classes[id])
		end
		card(content, classDef, 2, scaleOf(classes), nil)
	end

	local branchDef = ClassConfig.Branches[state.branch]
	if branchDef then
		local all = {}
		for _, def in ClassConfig.Branches do
			table.insert(all, def)
		end
		card(content, branchDef, 3, scaleOf(all), nil)
		if branchDef.Effect and branchDef.Effect.Kind == "FireColor" then
			fireStrip(content, 4, state.level)
		end
	else
		wrapped(content, `สายธาตุ: {state.branch}`, 15, Theme.Colors.TextMuted, 3)
	end
end

render = function(force: boolean?)
	local state = readState()
	view = resolveView(state, view)
	local fire = if view == "Info" then fireIndex(state.level) or 0 else 0
	local signature =
		`{view}|{state.class}|{state.branch}|{tostring(canChooseBranch(state))}|{fire}|{tostring(state.known)}`
	if not force and signature == lastSignature then
		return
	end
	lastSignature = signature
	confirmId = nil
	confirmToken += 1

	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	firstFocus = nil

	if not state.known then
		wrapped(content, "กำลังโหลดข้อมูลป้อม…", 15, Theme.Colors.TextMuted, 1)
	elseif view == "Info" then
		buildInfoView(state)
	elseif view == "Branch" then
		buildBranchView(state)
	else
		buildClassView(state)
	end
	content.CanvasPosition = Vector2.zero

	-- Gamepad: ของเดิมที่เลือกไว้ถูกลบไปแล้ว → ย้ายโฟกัสไปปุ่มแรกของมุมมองใหม่
	if Panels.current() == PANEL_NAME and UserInputService.GamepadEnabled then
		local selected = GuiService.SelectedObject
		if selected == nil or not selected:IsDescendantOf(frame) then
			GuiService.SelectedObject = firstFocus or closeButton
		end
	end
end

local function renderHud()
	local state = readState()
	hudButton.Visible = state.known
	if not state.known then
		return
	end
	local classDef = ClassConfig.Classes[state.class]
	local needsAction = state.class == "" or canChooseBranch(state)
	local text
	if not classDef then
		text = "🏰 เลือกคลาส!"
	elseif canChooseBranch(state) then
		text = `✨ เลือกสายธาตุ! ({classDef.Name})`
	elseif state.locked then
		local branchDef = ClassConfig.Branches[state.branch]
		text = `🏰 {classDef.Name} · {if branchDef then branchDef.Name else state.branch}`
	else
		text = `🏰 คลาส: {classDef.Name}`
	end
	hudButton.Text = text .. keyHint()
	hudButton.BackgroundColor3 = if needsAction then Theme.Colors.Accent else Theme.Colors.Background
	hudButton.BackgroundTransparency = if needsAction then 0 else 0.2
	hudStroke.Color = if classDef then tint(classDef.Color) else Theme.Colors.SurfaceHover
end

local function openView(wanted: View)
	view = wanted
	render(true)
	Panels.open(PANEL_NAME)
	if UserInputService.GamepadEnabled and firstFocus then
		GuiService.SelectedObject = firstFocus
	end
end

local function toggle()
	local state = readState()
	if not state.known then
		return
	end
	if Panels.current() == PANEL_NAME then
		Panels.close()
	else
		openView(defaultView(state))
	end
end

-- เด้งแผงให้เองครั้งเดียวต่อรอบเล่น · ไม่แย่งแผงอื่นที่ผู้เล่นเปิดอยู่ (รอจนปิดก่อน)
local function checkPrompts()
	local state = readState()
	if not state.known then
		return
	end
	local current = Panels.current()
	if state.class == "" then
		if not promptedClass and current == nil then
			promptedClass = true
			openView("Class")
		end
	elseif canChooseBranch(state) and not promptedBranch then
		if current == nil or current == PANEL_NAME then
			promptedBranch = true
			openView("Branch")
		end
	end
end

local function onStateChanged()
	renderHud()
	if Panels.current() == PANEL_NAME then
		render(false)
	end
	checkPrompts()
end

local ClassUI = {}

function ClassUI.Init()
	-- ปุ่ม HUD: กลางล่าง เหนือแผงป้อมของ CombatUI (แผงนั้นสูงจากขอบล่าง 48 + 94 px)
	-- ซ้ายบน = เหรียญ/ตารางดาเมจ · ขวากลาง = เมนู HudUI · ขวาล่าง = ปุ่มกระโดดมือถือ → กลางล่างว่าง
	local hudGui = Components.screen("ClassHudGui", 4)
	hudButton = Components.button(hudGui, "", {
		size = UDim2.new(0.9, 0, 0, Theme.ButtonHeight),
		position = UDim2.new(0.5, 0, 1, -150),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Colors.Background,
		textSize = 16,
		noHover = true,
	}, toggle)
	hudButton.Name = "ClassButton"
	hudButton.TextTruncate = Enum.TextTruncate.AtEnd
	hudButton.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(300, Theme.ButtonHeight)
	limit.Parent = hudButton
	hudStroke = Instance.new("UIStroke")
	hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hudStroke.Thickness = 2
	hudStroke.Color = Theme.Colors.SurfaceHover
	hudStroke.Parent = hudButton

	local gui = Components.screen("ClassGui", 10)
	frame, content, closeButton = Components.panel(gui, "🏰 คลาสป้อม", Panels.close)
	Panels.register(PANEL_NAME, frame, closeButton)

	ContextActionService:BindAction("TurretClassPanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)
end

function ClassUI.Start()
	player:GetAttributeChangedSignal("TurretClass"):Connect(function()
		if awaitingClass and Panels.current() == PANEL_NAME and view == "Class" then
			Panels.close() -- เลือกคลาสสำเร็จ → ปิดให้เห็นป้อมเปลี่ยนร่าง
		end
		awaitingClass = false
		onStateChanged()
	end)
	player:GetAttributeChangedSignal("TurretBranch"):Connect(function()
		if readState().locked then
			view = "Info"
		end
		onStateChanged()
	end)
	player:GetAttributeChangedSignal("TurretLevel"):Connect(onStateChanged)
	onStateChanged()

	-- สำรอง: ลองเด้งซ้ำเมื่อแผงอื่นปิดแล้ว (เผื่อตอนถึงเลเวลผู้เล่นเปิดกาชาอยู่)
	while true do
		task.wait(REFRESH_INTERVAL)
		renderHud()
		checkPrompts()
	end
end

return ClassUI
