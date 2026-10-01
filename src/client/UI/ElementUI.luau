-- หน้าเลือกธาตุป้อม (เจ้าของ: Client_UI_Scripter · โครงหน้าจอ: UX_Architect) · สเปก: design/element-skills.md
-- แทน ClassUI เดิม · ทุกสถานะอ่านจาก Attribute ที่ Server ตั้ง (Element / TurretLevel / Coins + BossState.Active)
-- Client แค่ขอ ไม่ตัดสินเอง · ข้อความ/สี/ตัวคูณ/สกิลที่แสดงอ่านจาก Config/Elements (ตัวคูณเทียบป้อมพื้นฐาน · ไม่ใช่ดาเมจจริง)
-- ตอนนี้มีแค่ธาตุพื้นฐาน 4 ธาตุ · วิวัฒนาการ (Lv.20) = แผน ยังไม่ทำ
--
-- โครงหน้าจอ:
--   ปุ่ม HUD (กลางล่าง เหนือแผงป้อมของ CombatUI) → เปิด/ปิดแผง "Element" · คีย์ลัด C / LB (Gamepad)
--   แผง 2 มุมมอง (ใช้ Panels: เปิดได้ทีละแผง)
--     Element = การ์ด 4 ธาตุ · เลือกครั้งแรกฟรี (กดครั้งเดียว · เด้งเองตอนเข้าเกมถ้ายังไม่เลือก)
--               เปลี่ยนภายหลัง = 💰 + กดยืนยัน 2 ครั้ง · บอสอยู่/เงินไม่พอ = ปุ่มจาง กดไม่ได้
--     Info    = ดูธาตุตอนนี้ + ขั้นหน้าตาป้อม (อัปทุก 10 เลเวล) + ปุ่มไปเปลี่ยนธาตุ
--   การ์ดเรียงแนวตั้งในแผงที่เลื่อนได้ → ใช้ได้บนจอมือถือแคบ · ทุกปุ่มสูง ≥ 44 px (Theme.ButtonHeight)
--
-- อยากปรับ:
--   ชื่อ/คำอธิบาย/สี/ตัวคูณ/สกิล/Passive/ราคาเปลี่ยนธาตุ → shared/Config/Elements.luau (ไม่ต้องแก้ไฟล์นี้)
--   ย้าย/ขยายปุ่ม HUD → ElementUI.Init (hudButton) · หน้าตาการ์ด → card() · แถบสถิติ → statBar() · แถบสีไฟ → fireStrip()
--   ข้อความแต่ละมุมมอง → buildElementView / buildInfoView · ปุ่มลัด → Enum.KeyCode ใน Init (+ keyHint)
-- ⚠️ ปุ่ม "เลือก" แค่ส่งคำขอผ่าน Controllers/ElementController · Server ตรวจเงิน/บอสเองแล้วตั้ง Attribute กลับมา
--
-- 📖 อ่านตามลำดับนี้:
--   1) ElementUI.Init (ท้ายไฟล์) สร้างปุ่ม HUD + แผง (UI/Components + ลงทะเบียน UI/Panels) + ผูกปุ่มลัด C/LB → toggle
--   2) ElementUI.Start ฟัง Attribute Element / TurretLevel / Coins + BossState → onStateChanged
--      + วนลูปทุก REFRESH_INTERVAL วิ: renderHud + checkPrompts (เด้งแผงให้เองครั้งแรก)
--   3) readState อ่าน Attribute เป็นตาราง State · defaultView/resolveView เลือกมุมมอง
--   4) render ล้างแผงแล้วสร้างมุมมองใหม่ (ทุกมุมมองใช้ card() → statBar())
--   5) ผู้เล่นกด → Controllers/ElementController → Server (Network/ElementHandler) → ตั้ง Attribute ใหม่ → กลับไปข้อ 2

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local ElementController = require(script.Parent.Parent.Controllers.ElementController)

local player = Players.LocalPlayer

-- ===== ค่าคงที่ =====
-- ✏️ แก้ตรงนี้ถ้าอยาก: เปลี่ยนเวลารอยืนยัน · ความกว้างปุ่มในการ์ด · สีแถบสถิติ
local PANEL_NAME = "Element"
local CONFIRM_SECONDS = 3 -- เวลาที่ปุ่ม "ยืนยัน?" รอการกดครั้งที่สอง
local REFRESH_INTERVAL = 0.5 -- วินาทีต่อรอบเช็กเด้งแผง/อัปเดตปุ่ม HUD
local ACTION_WIDTH = 104 -- ความกว้างปุ่มด้านขวาของการ์ด (พิกเซล)
local DAMAGE_COLOR = Color3.fromRGB(235, 96, 80)
local RATE_COLOR = Color3.fromRGB(255, 204, 64)
local WHITE = Color3.new(1, 1, 1)

-- มุมมองของแผง · State = สถานะป้อมที่อ่านจาก Attribute
type View = "Element" | "Info"
type State = {
	known: boolean, -- Server ส่ง Element มาแล้ว (ข้อมูลผู้เล่นโหลดเสร็จ)
	element: string, -- "" = ยังไม่เลือก
	level: number,
	coins: number,
	bossActive: boolean,
}
-- ปุ่มบนการ์ด: text = ข้อความ · primary = สีเขียว · dim = ตัวหนังสือจาง · onClick = กดแล้วทำอะไร (nil = กดไม่ได้)
type Action = { text: string, primary: boolean?, dim: boolean?, onClick: (() -> ())? }
type Scale = { damage: number, rate: number }

-- ===== ตัวแปรสถานะของหน้าจอ =====
local frame: Frame
local content: ScrollingFrame
local closeButton: TextButton
local hudButton: TextButton
local hudStroke: UIStroke
local bossState: Instance? = nil

local view: View = "Element"
local lastSignature = ""
local firstFocus: GuiObject? = nil
local promptedElement = false
local awaitingElement = false -- ส่งคำขอเลือกธาตุแล้ว → ปิดแผงเมื่อ Server ตั้งค่าใหม่ ให้เห็นป้อมเปลี่ยนร่าง
local confirmId: string? = nil
local confirmToken = 0
local confirmButton: TextButton? = nil

-- ===== อ่านสถานะ + เลือกมุมมอง =====
local function readState(): State
	local element = player:GetAttribute("Element")
	local level = player:GetAttribute("TurretLevel")
	local coins = player:GetAttribute("Coins")
	return {
		known = type(element) == "string",
		element = if ElementMath.isElement(element) then element else "",
		level = if type(level) == "number" and level == level then level else 0,
		coins = if type(coins) == "number" then coins else 0,
		bossActive = bossState ~= nil and bossState:GetAttribute("Active") == true,
	}
end

-- มุมมองเมื่อกดปุ่ม: ยังไม่มีธาตุ → Element · มีแล้ว → Info
local function defaultView(state: State): View
	return if state.element == "" then "Element" else "Info"
end

-- ยังไม่มีธาตุ → บังคับหน้า Element เสมอ
local function resolveView(state: State, wanted: View): View
	return if state.element == "" then "Element" else wanted
end

-- ===== ตัวช่วยแสดงผล =====
local function tint(color: Color3): Color3
	return color:Lerp(WHITE, 0.35)
end

local function formatMultiplier(value: number): string
	return string.format("%g", math.floor(value * 100 + 0.5) / 100)
end

-- ย่อตัวเลขเงิน: 5000 → "5K"
local function shortNumber(value: number): string
	if value >= 1e6 then
		return string.format("%gM", math.floor(value / 1e5) / 10)
	elseif value >= 1e3 then
		return string.format("%gK", math.floor(value / 1e2) / 10)
	end
	return tostring(math.floor(value))
end

-- ข้อความบอกปุ่มลัดบนปุ่ม HUD: " [LB]" / " [C]" / "" (มือถือ)
local function keyHint(): string
	-- ✏️ แก้ตรงนี้ถ้าเปลี่ยนปุ่มลัดใน ElementUI.Init
	if UserInputService.GamepadEnabled then
		return " [LB]"
	elseif UserInputService.KeyboardEnabled then
		return " [C]"
	end
	return ""
end

-- ป้ายข้อความหลายบรรทัด (ตัดคำ + สูงขยายตามข้อความ)
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

-- ทุกธาตุในเกม (ใช้เทียบความยาวแถบ) ตามลำดับ Order
local function allDefs(): { any }
	local defs = {}
	for _, id in Elements.Order do
		table.insert(defs, Elements.Elements[id])
	end
	return defs
end

-- ค่า Damage/FireRate สูงสุดในกลุ่ม (ให้แถบของค่าสูงสุดยาวเต็ม)
local function scaleOf(defs: { any }): Scale
	local scale = { damage = 0.001, rate = 0.001 }
	for _, def in defs do
		scale.damage = math.max(scale.damage, def.Damage)
		scale.rate = math.max(scale.rate, def.FireRate)
	end
	return scale
end

-- แถบสถิติแบบง่าย: ความยาว = ค่า ÷ ค่าสูงสุดในกลุ่ม
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

-- ข้อความเล็กในการ์ด (Passive / สกิล) ตัดคำ + สูงตามเนื้อหา
local function smallText(parent: Instance, text: string, color: Color3, order: number)
	local label = Components.label(parent, text, {
		size = UDim2.new(1, 0, 0, 0),
		textSize = 13,
		color = color,
		order = order,
	})
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

-- การ์ดธาตุ: ชื่อ + สี · คำอธิบาย · ⚔ / ⚡ · ✨ Passive · 🎯 สกิล · ปุ่มด้านขวา (ถ้ามี action)
local function card(parent: Instance, def: any, order: number, scale: Scale, action: Action?): TextButton?
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหน้าตาการ์ด: ขนาดตัวอักษร · ความหนาขอบ (2) · ระยะขอบใน (8)
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

	Components.label(info, `{def.Icon or ""} ธาตุ{def.Name}`, {
		size = UDim2.new(1, 0, 0, 22),
		bold = true,
		textSize = 17,
		color = accent,
		order = 1,
	})
	smallText(info, def.Description or "", Theme.Colors.TextMuted, 2)
	statBar(info, "⚔", def.Damage, scale.damage, DAMAGE_COLOR, 3)
	statBar(info, "⚡", def.FireRate, scale.rate, RATE_COLOR, 4)
	if def.Passive then
		smallText(info, `✨ {def.Passive.Name or "ติดตัว"}: {def.Passive.Text or ""}`, Theme.Colors.Text, 5)
	end
	if def.Skill then
		local skill = def.Skill
		smallText(info, `🎯 สกิล {skill.Name} ({skill.Cooldown} วิ): {skill.Description or ""}`, Theme.Colors.Coin, 6)
	end

	if not action then
		return nil
	end
	local button = Components.button(box, action.text, {
		size = UDim2.fromOffset(ACTION_WIDTH, Theme.ButtonHeight),
		position = UDim2.fromScale(1, 0.5),
		anchor = Vector2.new(1, 0.5),
		color = if action.primary then Theme.Colors.Accent else Theme.Colors.SurfaceHover,
		hoverColor = if action.primary then Theme.Colors.AccentHover else Theme.Colors.SurfaceHover,
		textSize = 15,
	}, action.onClick)
	if action.dim then
		button.TextTransparency = 0.5
	end
	return button
end

-- แถบสีบอลไฟตามเลเวล (ธาตุไฟ) · ไฮไลต์สีที่ใช้อยู่ถ้ารู้เลเวล
local function fireStrip(parent: Instance, order: number, currentLevel: number?)
	wrapped(parent, "🔥 สีบอลไฟเปลี่ยนตามเลเวลป้อม", 14, Theme.Colors.Coin, order)
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -10, 0, 56)
	strip.LayoutOrder = order + 1
	strip.Parent = parent
	local layout = Components.list(strip, 4, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local count = #Elements.FireColors
	local current = if currentLevel and currentLevel >= Elements.FireColors[1].Level
		then ElementMath.fireTier(currentLevel)
		else nil
	for index, row in Elements.FireColors do
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

-- ปุ่มกว้างเต็มแผง สำหรับสลับมุมมอง
local function navButton(text: string, order: number, onClick: () -> ()): TextButton
	return Components.button(content, text, {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		textSize = 16,
		order = order,
	}, onClick)
end

-- ปุ่ม 2 จังหวะ (idleText → "ยืนยัน?" → ส่ง) ใช้กับการเปลี่ยนธาตุที่เสียเงิน
-- คืน (onClick, bind) · ต้องเรียก bind(ปุ่ม) หลังสร้างการ์ด ให้ onClick รู้ว่าปุ่มไหน
local function twoStep(id: string, idleText: string, send: () -> ()): (() -> (), (TextButton) -> ())
	local button: TextButton? = nil
	local function resetLater(token: number)
		task.delay(CONFIRM_SECONDS, function()
			if confirmToken == token and button and button.Parent then
				confirmId = nil
				button.Text = idleText
			end
		end)
	end
	local function onClick()
		if not button then
			return
		end
		-- ระบบ token: กดใหม่/วาดใหม่ = token เปลี่ยน → ตัวจับเวลาเก่าไม่ทำอะไร
		confirmToken += 1
		if confirmId == id then
			confirmId = nil
			button.Text = "กำลังส่ง…"
			send()
		else
			if confirmButton and confirmButton ~= button and confirmButton.Parent then
				confirmButton.Text = idleText
			end
			confirmId = id
			confirmButton = button
			button.Text = "ยืนยัน?"
		end
		resetLater(confirmToken)
	end
	return onClick, function(b: TextButton)
		button = b
	end
end

local render: (force: boolean?) -> ()

-- ===== 2 มุมมองของแผง =====
-- มุมมอง Element: การ์ด 4 ธาตุ · ครั้งแรกฟรีกดทีเดียว · เปลี่ยน = 💰 + ยืนยัน · บอสอยู่/เงินไม่พอ = ปุ่มจาง
local function buildElementView(state: State)
	local cost = Elements.ChangeElementCost
	local first = state.element == ""
	-- ✏️ แก้ข้อความหัวแผงได้ที่นี่
	local header = if first
		then "เลือกธาตุป้อมของคุณ (ครั้งแรกฟรี) · ป้อมเปลี่ยนหน้าตา + วิธียิง + สกิลทันที"
		else `เปลี่ยนธาตุ = 💰{shortNumber(cost)} · เลเวลป้อมคงเดิม · สกิลต้องรอคูลดาวน์ใหม่`
	wrapped(content, header, 15, Theme.Colors.Text, 1)
	if not first and state.bossActive then
		wrapped(content, "⛔ บอสอยู่ — เปลี่ยนธาตุไม่ได้จนกว่าบอสจะไป", 14, Theme.Colors.Danger, 2)
	end
	if not first then
		firstFocus = navButton("⬅ กลับ", 3, function()
			view = "Info"
			render(true)
		end)
	end

	local scale = scaleOf(allDefs())
	for index, id in Elements.Order do
		local def = Elements.Elements[id]
		local button: TextButton?
		if id == state.element then
			button = card(content, def, 10 + index, scale, { text = "✔ ใช้อยู่", dim = true })
		elseif first then
			-- ครั้งแรก: กดครั้งเดียวส่งเลย (ฟรี) · ผลจริงมาทาง Attribute Element
			button = card(content, def, 10 + index, scale, {
				text = "เลือก",
				primary = true,
				onClick = function()
					awaitingElement = true
					ElementController.requestElement(id)
				end,
			})
		elseif state.bossActive or state.coins < cost then
			-- แค่บอกใบ้ (กดไม่ได้) · Server ตรวจเงิน/บอสจริงอีกรอบ
			button = card(content, def, 10 + index, scale, { text = `💰{shortNumber(cost)}`, dim = true })
		else
			local idle = `💰{shortNumber(cost)}`
			local onClick, bind = twoStep(id, idle, function()
				awaitingElement = true
				ElementController.requestElement(id)
			end)
			button = card(content, def, 10 + index, scale, { text = idle, primary = true, onClick = onClick })
			if button then
				bind(button)
			end
		end
		if firstFocus == nil and button and id ~= state.element then
			firstFocus = button
		end
	end
end

-- มุมมอง Info: การ์ดธาตุที่ใช้อยู่ + ขั้นหน้าตาป้อม + ปุ่มไปเปลี่ยนธาตุ
local function buildInfoView(state: State)
	local def = ElementMath.defOf(state.element)
	if not def then
		return
	end
	-- ขั้นหน้าตา: อัปทุก 10 เลเวล (Elements.LookTiers) · บอกเลเวลขั้นถัดไป
	local tier, tierLevel = ElementMath.lookTier(state.level)
	local nextLevel = Elements.LookTiers[tier + 1]
	local tierText = if nextLevel
		then `🏰 หน้าตาป้อมขั้น {tier}/{#Elements.LookTiers} (Lv.{tierLevel}) · ขั้นถัดไป Lv.{nextLevel}`
		else `🏰 หน้าตาป้อมขั้นสูงสุด {tier}/{#Elements.LookTiers} (Lv.{tierLevel})`
	wrapped(content, "ป้อมของคุณตอนนี้", 15, Theme.Colors.Text, 1)
	wrapped(content, tierText, 14, Theme.Colors.Coin, 2)
	card(content, def, 3, scaleOf(allDefs()), nil)
	if def.UseFireColors then
		fireStrip(content, 4, state.level)
	end
	firstFocus = navButton(`🔁 เปลี่ยนธาตุ (💰{shortNumber(Elements.ChangeElementCost)})`, 90, function()
		view = "Element"
		render(true)
	end)
end

-- ===== วาดแผง + ปุ่ม HUD =====
-- ล้างเนื้อหาในแผงแล้วสร้างมุมมองใหม่ · force = true → วาดใหม่เสมอ · false → วาดเฉพาะเมื่อสถานะที่มีผลกับจอเปลี่ยน
render = function(force: boolean?)
	local state = readState()
	view = resolveView(state, view)
	local tier = ElementMath.lookTier(state.level)
	local fire = if view == "Info" then ElementMath.fireTier(state.level) else 0
	local signature = table.concat({
		view,
		state.element,
		tostring(tier),
		tostring(fire),
		tostring(state.known),
		tostring(state.bossActive),
		tostring(state.coins >= Elements.ChangeElementCost),
	}, "|")
	if not force and signature == lastSignature then
		return
	end
	lastSignature = signature
	confirmId = nil
	confirmToken += 1
	confirmButton = nil
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
	else
		buildElementView(state)
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

-- ปุ่ม HUD: ข้อความตามสถานะ · สีเขียวเมื่อยังไม่ได้เลือกธาตุ · ซ่อนจนข้อมูลโหลดเสร็จ
local function renderHud()
	local state = readState()
	hudButton.Visible = state.known
	if not state.known then
		return
	end
	-- ✏️ แก้ข้อความบนปุ่ม HUD ได้ที่นี่
	local def = ElementMath.defOf(state.element)
	local text = if def then `{def.Icon or ""} ธาตุ{def.Name}` else "🔮 เลือกธาตุป้อม!"
	local needsAction = def == nil
	hudButton.Text = text .. keyHint()
	hudButton.BackgroundColor3 = if needsAction then Theme.Colors.Accent else Theme.Colors.Background
	hudButton.BackgroundTransparency = if needsAction then 0 else 0.2
	hudStroke.Color = if def then tint(def.Color) else Theme.Colors.SurfaceHover
end

-- ===== เปิด/ปิดแผง =====
local function openView(wanted: View)
	view = wanted
	render(true)
	Panels.open(PANEL_NAME)
	if UserInputService.GamepadEnabled and firstFocus then
		GuiService.SelectedObject = firstFocus
	end
end

-- เปิด-ปิดแผง (ปุ่ม HUD / ปุ่มลัด C / LB)
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

-- ยังไม่มีธาตุ → เด้งหน้าเลือกธาตุให้เองครั้งเดียวต่อรอบเล่น (ไม่แย่งแผงอื่นที่ผู้เล่นเปิดอยู่)
local function checkPrompts()
	local state = readState()
	if state.known and state.element == "" and not promptedElement and Panels.current() == nil then
		promptedElement = true
		openView("Element")
	end
end

-- เรียกเมื่อสถานะเปลี่ยน: อัปเดตปุ่ม HUD + แผง (ถ้าเปิดอยู่) + เช็กเด้งแผง
local function onStateChanged()
	renderHud()
	if Panels.current() == PANEL_NAME then
		render(false)
	end
	checkPrompts()
end

local ElementUI = {}

-- เปิดหน้าเลือกธาตุจากภายนอก (UI/TutorialUI ขั้น 1 ใช้บังคับเปิด) · ข้อมูลยังไม่โหลด = ไม่เปิด
-- ใช้ openView เพื่อวาดเนื้อหาใหม่ก่อนเปิด (Panels.open ตรง ๆ อาจได้แผงว่าง/ค้างมุมมองเก่า)
function ElementUI.openPicker()
	if not readState().known then
		return
	end
	promptedElement = true
	openView("Element")
end

-- สร้างปุ่ม HUD + แผง + ผูกปุ่มลัดตอนเริ่มเกม
function ElementUI.Init()
	-- ===== ปุ่ม HUD: ชิดซ้าย กลางจอแนวตั้ง (ใต้ตารางดาเมจบอส) ตามจุดที่เจ้าของเกมวาดไว้ 2026-10-01 =====
	-- ✏️ ย้าย/ขยาย: position UDim2.new(0, 12, 0.5, 0) (ห่างขอบซ้าย 12 px · กลางจอแนวตั้ง) · กว้าง 160 px
	local hudGui = Components.screen("ElementHudGui", 4)
	hudButton = Components.button(hudGui, "", {
		size = UDim2.new(0, 160, 0, Theme.ButtonHeight),
		position = UDim2.new(0, 12, 0.5, 0),
		anchor = Vector2.new(0, 0.5),
		color = Theme.Colors.Background,
		textSize = 16,
		noHover = true,
	}, toggle)
	hudButton.Name = "ElementButton"
	hudButton.TextTruncate = Enum.TextTruncate.AtEnd
	hudButton.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(160, Theme.ButtonHeight)
	limit.Parent = hudButton
	hudStroke = Instance.new("UIStroke")
	hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hudStroke.Thickness = 2
	hudStroke.Color = Theme.Colors.SurfaceHover
	hudStroke.Parent = hudButton

	-- ===== แผงธาตุ (ขนาด/ตำแหน่งแผงกำหนดใน Components.panel) =====
	local gui = Components.screen("ElementGui", 10)
	frame, content, closeButton = Components.panel(gui, "🔮 ธาตุป้อม", Panels.close)
	Panels.register(PANEL_NAME, frame, closeButton)

	-- ===== ปุ่มลัด C (คีย์บอร์ด) / LB (Gamepad) · มือถือกดปุ่ม HUD =====
	ContextActionService:BindAction("TurretElementPanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)
end

-- เริ่มฟัง Attribute จาก Server (ทางเดียวที่ UI รู้ผลการเลือก)
function ElementUI.Start()
	-- ธาตุเปลี่ยนหลังเรากด (awaitingElement) → ปิดแผงให้เห็นป้อมเปลี่ยนร่าง
	player:GetAttributeChangedSignal("Element"):Connect(function()
		if awaitingElement and Panels.current() == PANEL_NAME and view == "Element" then
			Panels.close()
		end
		awaitingElement = false
		onStateChanged()
	end)
	player:GetAttributeChangedSignal("TurretLevel"):Connect(onStateChanged)
	player:GetAttributeChangedSignal("Coins"):Connect(onStateChanged)
	onStateChanged()

	-- BossState (Server สร้าง) · บอสมา/ไป → ปุ่มเปลี่ยนธาตุเปิด/ปิด
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("BossState")
		bossState = state
		state:GetAttributeChangedSignal("Active"):Connect(onStateChanged)
		onStateChanged()
	end)

	-- สำรอง: ลองเด้งซ้ำเมื่อแผงอื่นปิดแล้ว
	while true do
		task.wait(REFRESH_INTERVAL)
		renderHud()
		checkPrompts()
	end
end

return ElementUI
