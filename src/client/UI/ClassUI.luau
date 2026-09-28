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
--
-- อยากปรับ:
--   ชื่อ/คำอธิบาย/สี/ตัวคูณของคลาส-สาย → shared/Config/Skill_class_default.luau (ไม่ต้องแก้ไฟล์นี้)
--   ย้าย/ขยายปุ่ม HUD → ClassUI.Init (hudButton: position / size · กว้างสุด 300 ที่ limit)
--   หน้าตาการ์ด → card() · แถบสถิติ → statBar() · แถบสีบอลไฟ → fireStrip()
--   ข้อความบนแต่ละมุมมอง → buildClassView / buildBranchView / buildInfoView
--   ปุ่มลัด C / LB → Enum.KeyCode ใน ClassUI.Init (ข้อความบอกปุ่ม → keyHint)
-- ⚠️ ปุ่ม "เลือก" แค่ส่งคำขอผ่าน Controllers/ClassController · Server ตรวจสิทธิ์/เลเวลเองแล้วตั้ง Attribute กลับมา
--
-- 📖 อ่านตามลำดับนี้:
--   1) ClassUI.Init (ท้ายไฟล์) สร้างปุ่ม HUD + แผง "Class" (ผ่าน UI/Components, ลงทะเบียนกับ UI/Panels) + ผูกปุ่มลัด C/LB → toggle
--   2) ClassUI.Start ฟัง Attribute TurretClass / TurretBranch / TurretLevel → onStateChanged
--      + วนลูปทุก REFRESH_INTERVAL วินาที: renderHud + checkPrompts (เด้งแผงให้เองครั้งแรก)
--   3) readState อ่าน Attribute ทั้งหมดเป็นตาราง State · resolveView/defaultView เลือกมุมมอง
--   4) render ล้างแผงแล้วสร้างมุมมองใหม่: buildClassView (การ์ดคลาส) / buildBranchView (การ์ดสาย) / buildInfoView (ดูอย่างเดียว)
--      ทุกมุมมองใช้ตัวช่วย card() → statBar() · สายไฟใช้ fireStrip() เพิ่ม
--   5) ผู้เล่นกด "เลือก" → Controllers/ClassController.requestClass / requestBranch → Server (Network/TurretClassHandler)
--   6) Server ตรวจแล้วตั้ง Attribute ใหม่ → กลับไปขั้น 2 (onStateChanged) → render ใหม่ให้เห็นผล
-- 💡 ศัพท์ UI ที่ใช้บ่อยในไฟล์นี้:
--   UDim2.new(scaleX, offsetX, scaleY, offsetY) = ขนาด/ตำแหน่ง: scale = สัดส่วนของกรอบแม่ (1 = เต็ม) · offset = พิกเซล
--     เช่น UDim2.new(1, -10, 0, 16) = กว้างเต็มแม่ลบ 10 px · สูง 16 px
--   UDim2.fromScale(x, y) = ใช้แต่สัดส่วน · UDim2.fromOffset(x, y) = ใช้แต่พิกเซล
--   AnchorPoint = จุดยึดของตัวเอง (0,0 = มุมซ้ายบน · 0.5,0.5 = กึ่งกลาง · 1,0.5 = ขอบขวากลาง) ใช้คู่กับ Position
--   Instance.new("Frame") = สร้างกล่อง UI ใหม่ · .Parent = ใส่เข้าไปในกล่องแม่ (ตั้งแล้วถึงจะแสดง)
--   LayoutOrder = ลำดับเรียงเมื่ออยู่ใน UIListLayout (น้อย = บน) · AutomaticSize = สูงขยายตามเนื้อหาเอง

-- GuiService = ใช้ย้ายโฟกัสปุ่มของ Gamepad · UserInputService = รู้ว่าผู้เล่นใช้คีย์บอร์ด/จอย/มือถือ
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- script.Parent = โฟลเดอร์ที่ไฟล์นี้อยู่ (UI/) · script.Parent.Parent = client/ → เข้าไป Controllers ได้
local ClassConfig = require(ReplicatedStorage.Shared.Config.Skill_class_default)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local ClassController = require(script.Parent.Parent.Controllers.ClassController)

-- LocalPlayer = ผู้เล่นที่ใช้เครื่องนี้อยู่ (มีเฉพาะฝั่ง Client)
local player = Players.LocalPlayer

-- ===== ค่าคงที่ =====
-- ✏️ แก้ตรงนี้ถ้าอยาก: เปลี่ยนเวลารอยืนยัน (CONFIRM_SECONDS) · ความกว้างปุ่มในการ์ด (ACTION_WIDTH) · สีแถบสถิติ
-- ชื่อแผงใน Panels
local PANEL_NAME = "Class"
local CONFIRM_SECONDS = 3 -- เวลาที่ปุ่ม "ยืนยัน?" รอการกดครั้งที่สอง
-- วินาทีต่อรอบเช็กเด้งแผง/อัปเดตปุ่ม HUD
local REFRESH_INTERVAL = 0.5
-- ความกว้างปุ่มด้านขวาของการ์ด (พิกเซล)
local ACTION_WIDTH = 96
-- สีแถบ ⚔ ดาเมจ / ⚡ อัตรายิง ในการ์ด
local DAMAGE_COLOR = Color3.fromRGB(235, 96, 80)
local RATE_COLOR = Color3.fromRGB(255, 204, 64)
local WHITE = Color3.new(1, 1, 1)

-- มุมมองของแผง (ดูคำอธิบายด้านบน) · State = สถานะป้อมที่อ่านจาก Attribute
-- `"Class" | "Branch" | "Info"` = ชนิดที่รับได้แค่ 3 คำนี้ (พิมพ์ผิดตัวตรวจโค้ดจะเตือน · ไม่มีผลตอนรัน)
type View = "Class" | "Branch" | "Info"
type State = {
	known: boolean, -- Server ส่ง TurretClass มาแล้ว (ข้อมูลผู้เล่นโหลดเสร็จ)
	class: string, -- "" = ยังไม่เลือก (หรือ id ที่ไม่มีใน Config)
	branch: string, -- id สายจาก Attribute (อาจไม่มีใน Config)
	locked: boolean, -- มีสายแล้ว = เปลี่ยนคลาส/สายไม่ได้
	level: number,
}
-- ปุ่มบนการ์ด: text = ข้อความ · primary = สีเขียว · dim = ตัวหนังสือจาง · onClick = กดแล้วทำอะไร
type Action = { text: string, primary: boolean?, dim: boolean?, onClick: (() -> ())? }
-- ค่าสูงสุดของกลุ่มที่แสดง (ใช้คำนวณความยาวแถบสถิติ)
type Scale = { damage: number, rate: number }

-- ===== ตัวแปรสถานะของหน้าจอ =====
-- ชิ้น UI หลัก (สร้างใน Init)
-- ประกาศไว้ก่อนแต่ยังว่าง → Init ใส่ค่าให้ · ฟังก์ชันอื่นในไฟล์ใช้ตัวแปรเดียวกันนี้
local frame: Frame
local content: ScrollingFrame
local closeButton: TextButton
local hudButton: TextButton
local hudStroke: UIStroke

-- มุมมองที่แสดงอยู่ · lastSignature = กันวาดซ้ำเมื่อไม่มีอะไรเปลี่ยน · firstFocus = ปุ่มแรกสำหรับ Gamepad
-- prompted* = เด้งแผงให้เองไปแล้วหรือยัง · confirm* = สถานะปุ่ม "ยืนยัน?" ของการเลือกสาย
local view: View = "Class"
local lastSignature = ""
local firstFocus: GuiObject? = nil
local promptedClass = false
local promptedBranch = false
local awaitingClass = false -- ส่งคำขอเปลี่ยนคลาสแล้ว → ปิดแผงเมื่อ Server ตั้งค่าใหม่ ให้เห็นป้อมเปลี่ยนร่าง
local confirmId: string? = nil
local confirmToken = 0

-- ===== อ่านสถานะ + เลือกมุมมอง =====
-- อ่านสถานะป้อมจาก Attribute ที่ Server ตั้ง (ค่าเสีย/ไม่มีใน Config → ถือว่ายังไม่เลือก)
local function readState(): State
	-- GetAttribute("ชื่อ") = อ่านค่าที่ Server แปะไว้บนตัวผู้เล่น · ยังไม่ถูกตั้ง = nil
	local class = player:GetAttribute("TurretClass")
	local branch = player:GetAttribute("TurretBranch")
	local level = player:GetAttribute("TurretLevel")
	-- `if เงื่อนไข then A else B` = เลือกค่าในบรรทัดเดียว · คลาสที่ไม่มีใน Config → ถือว่า "" (ยังไม่เลือก)
	local classId = if type(class) == "string" and ClassConfig.Classes[class] then class else ""
	-- ล็อกเฉพาะสายที่ถูกต้องของคลาสตัวเอง (ตรงกับ ClassMath.canChooseClass ฝั่ง Server)
	local branchDef = if type(branch) == "string" then ClassConfig.Branches[branch] else nil
	local validBranch = branchDef ~= nil and branchDef.Class == classId
	-- known: Attribute TurretClass ถูกตั้งแล้ว (แม้เป็น "") = ข้อมูลผู้เล่นโหลดเสร็จ
	-- `level == level` = กรอง NaN (ค่าเสียที่ไม่เท่ากับตัวเอง)
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
	-- ⚠️ ระวัง: ใช้แค่ตัดสินว่าจะ "โชว์" ปุ่มเลือกสายไหม · ต่อให้ Client โกงให้ true ได้ Server ก็ยังปฏิเสธ
	return state.class ~= "" and not state.locked and state.level >= ClassConfig.BranchLevel
end

-- มุมมองที่ควรเปิดเมื่อกดปุ่ม: มีสายแล้ว → Info · เลือกสายได้ → Branch · อื่นๆ → Class
local function defaultView(state: State): View
	if state.locked then
		return "Info"
	elseif canChooseBranch(state) then
		return "Branch"
	end
	return "Class"
end

-- ปรับมุมมองที่อยากเปิด (wanted) ให้ถูกกับสถานะจริง เช่น ยังเลือกสายไม่ได้ → กลับไป Class
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
	-- วนทุกแถว (เรียง Level น้อย → มาก) จำแถวล่าสุดที่ผ่านเงื่อนไข → ได้แถวสุดท้ายที่ Level ≤ เลเวลป้อม
	-- `for index, row in ตาราง do` = วนทีละช่อง ได้ลำดับ (index) กับค่า (row)
	local found = nil
	for index, row in ClassConfig.FireColors do
		if row.Level <= level then
			found = index
		end
	end
	return found
end

-- ===== ตัวช่วยแสดงผล =====
-- ทำสีให้สว่างขึ้น 35% (ใช้กับชื่อ/ขอบการ์ด)
local function tint(color: Color3): Color3
	-- สีคลาสบางสีมืด (นักฆ่า) → ผสมขาวให้อ่านออกบนพื้นมืด
	return color:Lerp(WHITE, 0.35)
end

-- แสดงตัวคูณแบบสั้น ปัด 2 ตำแหน่ง เช่น 1.2 → "1.2" · 3.50 → "3.5"
local function formatMultiplier(value: number): string
	-- ×100 → ปัดเศษ (floor(x + 0.5)) → ÷100 = ปัด 2 ตำแหน่ง · "%g" = แสดงตัวเลขแบบตัดศูนย์ท้ายทิ้ง
	return string.format("%g", math.floor(value * 100 + 0.5) / 100)
end

-- ข้อความบอกปุ่มลัดบนปุ่ม HUD: " [LB]" (Gamepad) / " [C]" (คีย์บอร์ด) / "" (มือถือ)
local function keyHint(): string
	-- ✏️ แก้ตรงนี้ถ้าเปลี่ยนปุ่มลัดใน ClassUI.Init (ข้อความบนปุ่มต้องตรงกัน)
	if UserInputService.GamepadEnabled then
		return " [LB]"
	elseif UserInputService.KeyboardEnabled then
		return " [C]"
	end
	return ""
end

-- ป้ายข้อความหลายบรรทัด (ตัดคำ + สูงขยายตามข้อความ) ใน parent · order = ลำดับบนจอ
local function wrapped(parent: Instance, text: string, textSize: number, color: Color3, order: number): TextLabel
	-- สูงเริ่มที่ 0 แล้วให้ AutomaticSize.Y ขยายตามจำนวนบรรทัด · TextWrapped = ตัดขึ้นบรรทัดใหม่เมื่อยาวเกินกว้าง
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

-- หาค่า Damage/FireRate สูงสุดใน defs (ให้แถบของค่าสูงสุดยาวเต็ม)
local function scaleOf(defs: { any }): Scale
	-- เริ่มที่ 0.001 (ไม่ใช่ 0) กันหารด้วยศูนย์ใน statBar ถ้า defs ว่าง
	local scale = { damage = 0.001, rate = 0.001 }
	for _, def in defs do
		scale.damage = math.max(scale.damage, def.Damage)
		scale.rate = math.max(scale.rate, def.FireRate)
	end
	return scale
end

-- แถบสถิติแบบง่าย: ความยาว = ค่า ÷ ค่าสูงสุดในกลุ่มที่แสดงอยู่
local function statBar(parent: Instance, icon: string, value: number, maxValue: number, color: Color3, order: number)
	-- แถวสูง 16 พิกเซล: ป้ายตัวเลข (ซ้าย กว้าง 64) + แถบ (ต่อจากป้าย สูง 8)
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

	-- back = รางแถบสีเข้ม · AnchorPoint (0, 0.5) + Position Y 0.5 = วางกึ่งกลางแนวตั้งของแถว
	-- เริ่มที่ x = 68 px (หลบป้ายตัวเลขกว้าง 64) · กว้าง = เต็มแถวลบ 68 px
	-- ✏️ ความหนาแถบ = 8 · ความสูงแถว = 16 (ด้านบน)
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, 68, 0.5, 0)
	back.Size = UDim2.new(1, -68, 0, 8)
	back.BackgroundColor3 = Theme.Colors.Background
	back.BorderSizePixel = 0
	back.Parent = row
	Components.corner(back, UDim.new(1, 0))

	-- fill = ส่วนที่เติมสี · กว้างเป็นสัดส่วน ค่า ÷ ค่าสูงสุด (อย่างน้อย 6% ให้ยังเห็น) · UDim.new(1, 0) ที่ corner = มุมโค้งสุด
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(value / maxValue, 0.06, 1), 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	Components.corner(fill, UDim.new(1, 0))
end

-- การ์ดคลาส/สาย: ชื่อ + สี · คำอธิบาย · ⚔ ดาเมจ / ⚡ อัตรายิง · ปุ่มด้านขวา (ถ้ามี action)
local function card(parent: Instance, def: any, order: number, scale: Scale, action: Action?): TextButton?
	-- def = ก้อนข้อมูลของคลาสหรือสายจาก Config (มี Name/Description/Color/Damage/FireRate)
	-- action = nil → การ์ดดูอย่างเดียว (มุมมอง Info) · มี → มีปุ่มด้านขวา
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหน้าตาการ์ด: ขนาดตัวอักษร (17/14/16) · ความหนาขอบ (2) · ระยะขอบใน (padding 8)
	local accent = tint(def.Color)

	-- กรอบการ์ด: สูงขยายตามเนื้อหา · ขอบสีคลาส/สาย หนา 2
	local box = Instance.new("Frame")
	box.BackgroundColor3 = Theme.Colors.Surface
	box.Size = UDim2.new(1, -10, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.LayoutOrder = order
	box.Parent = parent
	Components.corner(box)
	Components.padding(box, 8)
	-- UIStroke = เส้นขอบรอบกล่อง (ใส่เป็นลูกของกล่อง)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Parent = box

	-- ฝั่งซ้าย (ข้อมูล) เรียงลงล่าง: ชื่อ → คำอธิบาย → แถบ ⚔ → แถบ ⚡ · เว้นขวาไว้ให้ปุ่ม
	local info = Instance.new("Frame")
	info.BackgroundTransparency = 1
	-- กว้างเต็มการ์ด แต่ถ้ามีปุ่ม → ลบความกว้างปุ่ม + ช่องว่าง 8 px · Components.list = เรียงลูกลงล่างห่าง 4 px
	info.Size = UDim2.new(1, if action then -(ACTION_WIDTH + 8) else 0, 0, 0)
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.Parent = box
	Components.list(info, 4)

	-- แถวชื่อ: จุดสี (14×14) + ชื่อ (ตัวหนา ขนาด 17)
	local nameRow = Instance.new("Frame")
	nameRow.BackgroundTransparency = 1
	nameRow.Size = UDim2.new(1, 0, 0, 22)
	nameRow.LayoutOrder = 1
	nameRow.Parent = info
	-- swatch = จุดสีกลม (มุมโค้ง UDim.new(1, 0) = วงกลม) ชิดซ้าย กลางแนวตั้ง · ชื่อเริ่มที่ x = 20 px หลบจุดสี
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

	-- แถบ ⚔ = ตัวคูณดาเมจ · ⚡ = ตัวคูณอัตรายิง (เทียบกับค่าสูงสุดในกลุ่มใน scale)
	statBar(info, "⚔", def.Damage, scale.damage, DAMAGE_COLOR, 3)
	statBar(info, "⚡", def.FireRate, scale.rate, RATE_COLOR, 4)

	if not action then
		return nil
	end
	-- ปุ่มด้านขวา กลางแนวตั้ง (กว้าง ACTION_WIDTH)
	-- position (1, 0.5) + anchor (1, 0.5) = เอาขอบขวากลางของปุ่ม ไปแปะที่ขอบขวากลางของการ์ด
	-- action.onClick = ฟังก์ชันที่มุมมองส่งมา (เช่น ส่งคำขอเลือกคลาส) · Components.button ผูกให้ตอนกด
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

	-- แถบสูง 56 พิกเซล แบ่งช่องเท่ากันตามจำนวนแถวใน FireColors · ช่องที่ใช้อยู่มีขอบสีทอง
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -10, 0, 56)
	strip.LayoutOrder = order + 1
	strip.Parent = parent
	local layout = Components.list(strip, 4, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- แต่ละช่องกว้าง 1/count ของแถบ (ลบ 4 px เป็นช่องไฟ) · current = ช่องที่ต้องไฮไลต์ (nil = ไม่ไฮไลต์)
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนความสูงแถบ (56 ด้านบน) · ขนาดจุดสี (18) · ตำแหน่งข้อความ (24 / 38 px จากบน)
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

-- ปุ่มกว้างเต็มแผง สำหรับสลับมุมมอง (เช่น "ไปเลือกสายธาตุ" / "เปลี่ยนคลาส")
local function navButton(text: string, order: number, onClick: () -> ()): TextButton
	return Components.button(content, text, {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		textSize = 16,
		order = order,
	}, onClick)
end

-- ประกาศไว้ก่อน (ตัวจริงอยู่ด้านล่าง) เพราะปุ่มในมุมมองต้องเรียก render
-- (Luau ต้องประกาศชื่อก่อนใช้ · ตรงนี้บอกแค่ชนิด "ฟังก์ชันที่รับ force" ค่าจริงใส่ทีหลังที่ `render = function`)
local render: (force: boolean?) -> ()

-- ===== 3 มุมมองของแผง =====
-- มุมมอง Class: หัวข้อ + (ปุ่มไปเลือกสาย ถ้าได้) + การ์ดทุกคลาสพร้อมปุ่ม "เลือก"

local function buildClassView(state: State)
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนข้อความหัวแผง (มีคลาสแล้ว / ยังไม่มี) · {ค่า} ใน `...` = แทรกค่าลงข้อความ
	local current = ClassConfig.Classes[state.class]
	local header = if current
		then `คลาสตอนนี้: {current.Name} · เปลี่ยนได้ฟรีจนกว่าจะเลือกสายธาตุ (ป้อม Lv.{ClassConfig.BranchLevel})`
		else `เลือกคลาสป้อมของคุณ · เปลี่ยนได้ฟรีจนกว่าจะเลือกสายธาตุที่ป้อม Lv.{ClassConfig.BranchLevel}`
	wrapped(content, header, 15, Theme.Colors.Text, 1)

	-- ถึงเลเวลแล้ว → ปุ่มลัดไปหน้าเลือกสาย (กดแล้วเปลี่ยน view แล้ววาดใหม่)
	if canChooseBranch(state) then
		firstFocus = navButton("✨ ไปเลือกสายธาตุ", 2, function()
			view = "Branch"
			render(true)
		end)
	end

	-- รวบรวมทุกคลาสเพื่อหาค่าสูงสุด (แถบยาวเทียบกันได้) · table.insert(ตาราง, ค่า) = ต่อท้ายตาราง
	local defs = {}
	for _, id in ClassConfig.ClassOrder do
		table.insert(defs, ClassConfig.Classes[id])
	end
	local scale = scaleOf(defs)

	-- การ์ดละ 1 คลาสตามลำดับ ClassOrder · คลาสที่ใช้อยู่ = ปุ่มจาง "ใช้อยู่" (กดไม่ได้เพราะไม่มี onClick)
	-- `: Action` หลังชื่อตัวแปร = type hint บอกว่าตารางนี้คือ Action
	for index, id in ClassConfig.ClassOrder do
		local def = ClassConfig.Classes[id]
		local action: Action = if id == state.class
			then { text = "✔ ใช้อยู่", dim = true }
			else {
				text = "เลือก",
				primary = true,
				onClick = function()
					-- ⚠️ ระวัง: แค่ส่งคำขอ ไม่เปลี่ยน state เอง · awaitingClass = จำไว้ว่ารอคำตอบ (ใช้ปิดแผงใน Start)
					awaitingClass = true
					ClassController.requestClass(id)
				end,
			}
		-- LayoutOrder 10+ ให้การ์ดอยู่ใต้หัวข้อ (1) และปุ่มนำทาง (2) · จำปุ่มแรกที่กดได้ไว้ให้ Gamepad โฟกัส
		local button = card(content, def, 10 + index, scale, action)
		if firstFocus == nil and id ~= state.class then
			firstFocus = button
		end
	end
end

-- มุมมอง Branch: การ์ดสายของคลาสตัวเอง · กด "เลือก" 1 ครั้ง = "ยืนยัน?" · กดซ้ำภายใน CONFIRM_SECONDS = ส่งคำขอ
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

	-- confirmButton = ปุ่มที่ขึ้น "ยืนยัน?" อยู่ตอนนี้ (มีได้ทีละปุ่ม)
	local confirmButton: TextButton? = nil
	-- วนเฉพาะสายของคลาสตัวเอง (Classes.<คลาส>.Branches) · `continue` = ข้ามรอบนี้ไปรอบถัดไป (ชื่อสายไม่มีใน Config)
	for index, id in classDef.Branches do
		local def = ClassConfig.Branches[id]
		if not def then
			continue
		end
		local button: TextButton
		-- ไม่กดยืนยันภายในเวลา → คืนปุ่มเป็น "เลือก"
		-- ระบบ token: ทุกการกด confirmToken +1 · พอครบเวลา ถ้า token ยังเท่าเดิม = ไม่มีใครกดอะไรเพิ่ม → รีเซ็ตได้
		-- ถ้าเลขเปลี่ยนแล้ว (กดใหม่/วาดใหม่) → ตัวจับเวลาเก่านี้ไม่ทำอะไร
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
				-- กดครั้งแรก = เปลี่ยนเป็น "ยืนยัน?" (และคืนปุ่มอื่นที่ค้าง "ยืนยัน?" เป็น "เลือก")
				-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนข้อความปุ่ม "เลือก" / "ยืนยัน?" / "กำลังส่ง…"
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
		-- `:: TextButton` = บอกตัวตรวจโค้ดว่าไม่ใช่ nil แน่นอน (เพราะส่ง action ไป) · ไม่มีผลตอนรัน
		}) :: TextButton
		if firstFocus == nil then
			firstFocus = button
		end
		-- สายไฟ → แสดงแถบสีบอลไฟต่อใต้การ์ด (order = การ์ด + 1) · ส่ง nil = ยังไม่ไฮไลต์ช่องไหน
		if id == "Fire" or def.Effect and def.Effect.Kind == "FireColor" then
			fireStrip(content, 11 + index * 2, nil)
		end
	end

	navButton("🔁 เปลี่ยนคลาส", 90, function()
		view = "Class"
		render(true)
	end)
end

-- มุมมอง Info: แสดงการ์ดคลาส + สายที่เลือกแล้ว (ไม่มีปุ่ม)
local function buildInfoView(state: State)
	wrapped(content, "🔒 เลือกสายธาตุแล้ว · ป้อมของคุณตอนนี้", 15, Theme.Colors.Text, 1)

	-- การ์ดไม่มีปุ่ม (action = nil) · ถ้า id ใน Attribute ไม่มีใน Config → ข้าม/แสดงแค่ชื่อ id ไม่ให้ error
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

-- ===== วาดแผง + ปุ่ม HUD =====
-- ล้างเนื้อหาในแผงแล้วสร้างมุมมองใหม่ · force = true → วาดใหม่เสมอ · false → วาดเฉพาะเมื่อสถานะเปลี่ยน
render = function(force: boolean?)
	-- ขั้น 1: อ่านสถานะล่าสุด + ปรับมุมมองให้ถูกกับสถานะ
	local state = readState()
	view = resolveView(state, view)
	-- ขั้น 2: signature = ข้อความสรุปทุกอย่างที่มีผลต่อหน้าจอ · เหมือนครั้งก่อน = ไม่ต้องวาดใหม่ (ประหยัด)
	-- fire = ช่องสีไฟที่ไฮไลต์ (เฉพาะมุมมอง Info) · ใส่ชื่อ fire เป็นตัวแปรท้องถิ่น ไม่เกี่ยวกับ fire() ไฟล์อื่น
	local fire = if view == "Info" then fireIndex(state.level) or 0 else 0
	local signature =
		`{view}|{state.class}|{state.branch}|{tostring(canChooseBranch(state))}|{fire}|{tostring(state.known)}`
	if not force and signature == lastSignature then
		return
	end
	-- ขั้น 3: รีเซ็ตสถานะปุ่มยืนยัน (+1 token = ยกเลิกตัวจับเวลาเก่าทั้งหมด)
	lastSignature = signature
	confirmId = nil
	confirmToken += 1

	-- ขั้น 4: ลบของเก่าในแผงทั้งหมด ยกเว้น UIListLayout (ตัวจัดเรียงที่ต้องอยู่ถาวร)
	-- GetChildren() = รายการลูกทั้งหมด · IsA("ชนิด") = เช็กชนิด · Destroy() = ลบทิ้ง
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	firstFocus = nil

	-- ขั้น 5: สร้างมุมมองตาม view · ยังโหลดข้อมูลไม่เสร็จ → ข้อความรอ · CanvasPosition = zero เลื่อนกลับบนสุด
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

-- อัปเดตปุ่ม HUD: ข้อความตามสถานะ · สีเขียวเมื่อมีสิ่งที่ต้องเลือก · ซ่อนจนข้อมูลโหลดเสร็จ
local function renderHud()
	local state = readState()
	hudButton.Visible = state.known
	if not state.known then
		return
	end
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนข้อความบนปุ่ม HUD ในแต่ละสถานะ (ยังไม่เลือก / เลือกสายได้ / ล็อกแล้ว / มีคลาส)
	-- needsAction = มีสิ่งที่ผู้เล่นควรกด → ปุ่มสีเขียวทึบ ดึงสายตา
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
	-- `..` = ต่อข้อความ · ต่อท้ายด้วยคำบอกปุ่มลัด เช่น " [C]"
	hudButton.Text = text .. keyHint()
	hudButton.BackgroundColor3 = if needsAction then Theme.Colors.Accent else Theme.Colors.Background
	hudButton.BackgroundTransparency = if needsAction then 0 else 0.2
	hudStroke.Color = if classDef then tint(classDef.Color) else Theme.Colors.SurfaceHover
end

-- ===== เปิด/ปิดแผง =====
-- เปิดแผงที่มุมมอง wanted
local function openView(wanted: View)
	-- วาดก่อนเปิด (force = true) ให้เนื้อหาพร้อมตอนแผงเด้งขึ้น · Panels.open ปิดแผงอื่นให้เอง
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

-- เด้งแผงให้เองครั้งเดียวต่อรอบเล่น · ไม่แย่งแผงอื่นที่ผู้เล่นเปิดอยู่ (รอจนปิดก่อน)
local function checkPrompts()
	local state = readState()
	if not state.known then
		return
	end
	-- current = ชื่อแผงที่เปิดอยู่ (nil = ไม่มี)
	-- ยังไม่มีคลาส → เด้งหน้าคลาส เฉพาะตอนไม่มีแผงอื่นเปิด · promptedClass = true กันเด้งซ้ำ
	-- เลือกสายได้ → เด้งหน้าสาย (ถ้าไม่มีแผงเปิด หรือแผงคลาสเปิดอยู่แล้ว)
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

-- เรียกเมื่อ Attribute ป้อมเปลี่ยน: อัปเดตปุ่ม HUD + แผง (ถ้าเปิดอยู่) + เช็กเด้งแผง
local function onStateChanged()
	renderHud()
	if Panels.current() == PANEL_NAME then
		render(false)
	end
	checkPrompts()
end

local ClassUI = {}

-- สร้างปุ่ม HUD + แผงคลาส + ผูกปุ่มลัดตอนเริ่มเกม
function ClassUI.Init()
	-- ===== ปุ่ม HUD (ตำแหน่ง = position · ขนาด = size · ขอบสี = hudStroke) =====
	-- ปุ่ม HUD: กลางล่าง เหนือแผงป้อมของ CombatUI (แผงนั้นสูงจากขอบล่าง 48 + 94 px)
	-- ซ้ายบน = เหรียญ/ตารางดาเมจ · ขวากลาง = เมนู HudUI · ขวาล่าง = ปุ่มกระโดดมือถือ → กลางล่างว่าง
	-- Components.screen(ชื่อ, ลำดับชั้น) = ScreenGui ใหม่ใน PlayerGui (เลขมาก = ทับอยู่ด้านบน)
	-- ✏️ แก้ตรงนี้ถ้าอยากย้าย/ขยายปุ่ม HUD:
	--   size UDim2.new(0.9, 0, 0, สูง) = กว้าง 90% ของจอ (แต่ถูกจำกัดที่ 300 px โดย limit ด้านล่าง)
	--   position UDim2.new(0.5, 0, 1, -150) = กึ่งกลางแนวนอน · ขอบล่างของจอขยับขึ้น 150 px
	--   anchor (0.5, 1) = ยึดที่ "กลางล่าง" ของปุ่ม → ตัวเลข position คือตำแหน่งของขอบล่างปุ่ม
	--   ตัวเลข -150 มาจากแผงป้อมของ CombatUI (48 + 94 px) + ช่องว่าง · ขยับแล้วเช็กว่าไม่ทับกัน
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
	-- UISizeConstraint = จำกัดขนาดสูงสุด/ต่ำสุดของกล่องแม่ (จอกว้าง → ปุ่มไม่ยืดยาวเกิน 300 px)
	-- ซ่อนปุ่มไว้ก่อน (Visible = false) จน renderHud เห็นว่าข้อมูลโหลดเสร็จ
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(300, Theme.ButtonHeight)
	limit.Parent = hudButton
	hudStroke = Instance.new("UIStroke")
	hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hudStroke.Thickness = 2
	hudStroke.Color = Theme.Colors.SurfaceHover
	hudStroke.Parent = hudButton

	-- ===== แผงคลาส (ขนาด/ตำแหน่งแผงกำหนดใน Components.panel) =====
	local gui = Components.screen("ClassGui", 10)
	-- Components.panel คืน 3 ค่าพร้อมกัน: กรอบแผง · พื้นที่เลื่อนได้ (ใส่การ์ด) · ปุ่มปิด
	-- Panels.register = ลงทะเบียนให้ระบบแผงกลางรู้จัก (เปิดทีละแผง · ปุ่มปิดเป็นโฟกัสแรกของ Gamepad)
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนหัวข้อแผง "🏰 คลาสป้อม"
	frame, content, closeButton = Components.panel(gui, "🏰 คลาสป้อม", Panels.close)
	Panels.register(PANEL_NAME, frame, closeButton)

	-- ===== ปุ่มลัด C (คีย์บอร์ด) / LB (Gamepad) =====
	-- ContextActionService:BindAction(ชื่อ, ฟังก์ชัน, สร้างปุ่มมือถือไหม, ปุ่ม...) · ทำงานเฉพาะตอนกดลง (Begin)
	-- Sink = กินปุ่มไว้ไม่ส่งต่อ · false = ไม่สร้างปุ่มมือถือ (มือถือกดปุ่ม HUD แทน)
	-- ✏️ แก้ตรงนี้ถ้าอยากเปลี่ยนปุ่มลัด: Enum.KeyCode.C / ButtonL1 (แล้วแก้ keyHint ให้ตรง)
	ContextActionService:BindAction("TurretClassPanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)
end

-- เริ่มฟัง Attribute TurretClass / TurretBranch / TurretLevel จาก Server
function ClassUI.Start()
	-- GetAttributeChangedSignal("ชื่อ"):Connect(ฟังก์ชัน) = "ทุกครั้งที่ Server เปลี่ยน Attribute นี้ ให้เรียกฟังก์ชัน"
	-- นี่คือทางเดียวที่ UI รู้ผลการเลือก (Server ตอบกลับทาง Attribute ไม่ใช่ทาง Remote)
	-- คลาสเปลี่ยนหลังเรากด "เลือก" (awaitingClass) → ปิดแผงให้เห็นป้อมเปลี่ยนร่าง
	player:GetAttributeChangedSignal("TurretClass"):Connect(function()
		if awaitingClass and Panels.current() == PANEL_NAME and view == "Class" then
			Panels.close() -- เลือกคลาสสำเร็จ → ปิดให้เห็นป้อมเปลี่ยนร่าง
		end
		awaitingClass = false
		onStateChanged()
	end)
	-- สายเปลี่ยน (Server ยอมรับการเลือกสาย) → สลับไปมุมมอง Info
	player:GetAttributeChangedSignal("TurretBranch"):Connect(function()
		if readState().locked then
			view = "Info"
		end
		onStateChanged()
	end)
	-- เลเวลเปลี่ยน → อาจถึง BranchLevel แล้ว (ปุ่ม HUD/แผงเด้ง) · เรียก onStateChanged() ทันทีอีก 1 ครั้งสำหรับค่าปัจจุบัน
	player:GetAttributeChangedSignal("TurretLevel"):Connect(onStateChanged)
	onStateChanged()

	-- สำรอง: ลองเด้งซ้ำเมื่อแผงอื่นปิดแล้ว (เผื่อตอนถึงเลเวลผู้เล่นเปิดกาชาอยู่)
	-- วนไม่รู้จบได้เพราะ Start ถูกรันใน task.spawn แยก (ไม่บล็อกไฟล์อื่น) · task.wait = หยุดรอแล้วค่อยวนต่อ
	while true do
		task.wait(REFRESH_INTERVAL)
		renderHud()
		checkPrompts()
	end
end

return ClassUI
