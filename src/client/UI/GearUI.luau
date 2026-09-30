-- หน้าอุปกรณ์ป้อม + ป๊อปอัปของดรอปจากบอส (เจ้าของ: Client_UI_Scripter · โครงหน้าจอ: UX_Architect)
-- สเปก: design/equipment.md หัวข้อ 11 (UI) + 14 (สัญญากับ Client) · แทนแผงชั่วคราว "Gear" ที่เคยอยู่ใน UI/HudUI
-- ทุกสถานะอ่านจาก Attribute ที่ Server ตั้ง: Gear (JSON) · GearSlots · GearBonus (JSON) · Coins · Element + BossState.Active
-- Client แค่ "ขอ" ผ่าน Controllers/GearController · ไม่ตัดสินผลเอง · ปุ่มเทา = แค่บอกใบ้ (Server ตรวจซ้ำทุกครั้ง และปฏิเสธแบบเงียบ)
-- ตัวเลขที่โชว์ (ค่าหลัก/โบนัสธาตุ/ราคา/โอกาสดรอป) อ่านจาก Config/Equipment ผ่าน Util/GearMath → ปรับค่าไม่ต้องแก้ไฟล์นี้
--
-- โครงหน้าจอ (แผง "Gear" · เปิดจากปุ่ม HUD "🛠 อุปกรณ์" ใน HudUI · ปุ่มลัด G / RB (Gamepad)):
--   ┌ หัวแผง "🛠 อุปกรณ์ป้อม" + ✕ (Components.panel)
--   │ 1) แถวสถานะ: กระเป๋า n/150 · บอสอยู่ = ⛔ ใส่/ถอดไม่ได้
--   │ 2) การ์ด 4 ช่อง (จอกว้าง 4 คอลัมน์ · จอแคบ 2×2): ชิ้นที่ใส่ (ขอบสีระดับ + ไอคอนธาตุ) / ว่าง / 🔒 + ปุ่มปลดล็อก 💰
--   │ 3) สรุปโบนัสรวม (จาก GearBonus) + ตัวบอกชุดธาตุ n/4
--   │ 4) แท็บกรองช่อง: ทั้งหมด / ลำกล้อง / กลไก / แกน / เกราะ
--   │ 5) กริดกระเป๋า: การ์ดชิ้น (ชื่อ · ระดับ · ×จำนวน · ค่าหลัก · ป้าย "เข้าธาตุ" / "ใส่อยู่" / "ใหม่") เรียง ระดับสูง → ธาตุตรง
--   │ 6) ปุ่ม "แยกทั้งหมดระดับธรรมดา" (แตะยืนยัน 2 ครั้ง) · ปุ่ม "ℹ️ โอกาสดรอป" (ตาราง + pity)
--   └ แผ่นรายละเอียด (เลื่อนทับจากล่าง เมื่อแตะชิ้น): ค่าหลัก/ค่ารอง · เทียบกับชิ้นที่ใส่ · ใส่/ถอด · รวม 3→1 · ย่อย (เลือกจำนวน)
--   ป๊อปอัปดรอป (กลางบน ใต้แถบบอส): รายการของที่ได้ + ป้ายใหม่/กระเป๋าเต็ม · ปิดเองใน DROP_SHOW_SECONDS · ไม่บังการเล่น
--   ทุกปุ่มสูง ≥ 44 px (Theme.ButtonHeight) · ปุ่มห่างกัน ≥ 8 px · Gamepad: โฟกัสปุ่มแรกเมื่อเปิดแผง/แผ่นรายละเอียด
--
-- อยากปรับ:
--   ขนาดแผง → PANEL_MAX_SIZE · ความสูงการ์ด → SLOT_CARD_HEIGHT / ITEM_CARD_HEIGHT / ITEM_MIN_WIDTH · ปุ่มลัด → Enum.KeyCode ใน Init
--   ข้อความชื่อค่าสถานะ → STAT_TEXT · อีโมจิระดับ → RARITY_EMOJI · เวลาป๊อปอัป → DROP_SHOW_SECONDS · เวลายืนยัน → CONFIRM_SECONDS
--   หน้าตาการ์ด → slotCard / itemCard · แผ่นรายละเอียด → renderSheet · ป๊อปอัป → showDrops
-- ⚠️ ห้าม: ตั้ง Attribute เอง / ถือว่าคำขอสำเร็จเอง → รอ Attribute "Gear" เปลี่ยนแล้วค่อยวาดใหม่เสมอ
--
-- 📖 อ่านตามลำดับนี้:
--   1) GearUI.Init (ท้ายไฟล์) สร้างแผง + แผ่นรายละเอียด + ป๊อปอัป · ลงทะเบียน Panels "Gear" · ผูกปุ่มลัด G/RB
--   2) GearUI.Start ฟัง Attribute Gear / GearSlots / GearBonus / Coins / Element + BossState.Active → render(false)
--      + ฟัง GearDrops (GearController.onDrops) → showDrops
--   3) readState แปลง Attribute เป็นตาราง State (decodeGear รองรับ Items ที่เป็น [] หรือ {})
--   4) render: แผงปิดอยู่ = จำไว้ว่าต้องวาด (dirty) · เปิดอยู่ = เทียบ signature → เปลี่ยนจริงค่อยล้างแล้ววาดใหม่
--   5) ผู้เล่นกด → Controllers/GearController → Server (Network/GearHandler) → Attribute ใหม่ → กลับไปข้อ 2

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Elements = require(ReplicatedStorage.Shared.Config.Elements)
local Equipment = require(ReplicatedStorage.Shared.Config.Equipment)
local ElementMath = require(ReplicatedStorage.Shared.Util.ElementMath)
local GearMath = require(ReplicatedStorage.Shared.Util.GearMath)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local GearController = require(script.Parent.Parent.Controllers.GearController)

local player = Players.LocalPlayer

-- ===== ค่าคงที่ =====
-- ✏️ แก้ตรงนี้ถ้าอยาก: ขนาดแผง · ความสูงการ์ด · เวลายืนยัน/ป๊อปอัป
local PANEL_NAME = "Gear" -- ⚠️ ต้องตรงกับ Panels.toggle("Gear") ในปุ่ม HUD ของ UI/HudUI
local PANEL_MAX_SIZE = Vector2.new(560, 520) -- แผงนี้เนื้อหาเยอะ → ใหญ่กว่าแผงมาตรฐาน (480 × 440)
local SLOT_CARD_HEIGHT = 112
local ITEM_CARD_HEIGHT = 118
local ITEM_MIN_WIDTH = 104 -- ความกว้างการ์ดชิ้นขั้นต่ำ (คำนวณจำนวนคอลัมน์ของกริดกระเป๋า)
local WIDE_SLOTS_WIDTH = 420 -- เนื้อหากว้างเท่านี้ขึ้นไป → การ์ดช่อง 4 คอลัมน์ (แคบกว่า = 2×2)
local GAP = 8 -- ระยะห่างระหว่างปุ่ม/การ์ด (≥ 8 px ตามสเปก)
local CONFIRM_SECONDS = 3 -- เวลาที่ปุ่ม "แตะอีกครั้งเพื่อยืนยัน" รอการกดครั้งที่สอง
local PENDING_SECONDS = 2 -- ส่งคำขอแล้ว Server ไม่ตอบ (ปฏิเสธเงียบ) → คืนข้อความปุ่มหลังเวลานี้
local DROP_SHOW_SECONDS = 8 -- ป๊อปอัปดรอปอยู่บนจอนานเท่านี้ (+ เวลาเด้งทีละแถว)
local DROP_MAX_ROWS = 6 -- กันข้อมูลแปลก: แสดงไม่เกินเท่านี้แถว (Server ส่ง 1–4)
local CONFIRM_FROM_RARITY = "Epic" -- รวม/ย่อยชิ้นระดับนี้ขึ้นไป ต้องแตะยืนยัน 2 ครั้ง
local SENDING_TEXT = "กำลังส่ง…"
local ARMED_TEXT = "⚠️ แตะอีกครั้งเพื่อยืนยัน"

-- ชื่อค่าสถานะบน UI + เครื่องหมาย (SkillCooldown / StunReduce = "ลดลง")
local STAT_TEXT: { [string]: { name: string, sign: string } } = {
	Damage = { name = "ดาเมจ", sign = "+" },
	FireRate = { name = "อัตรายิง", sign = "+" },
	BossDamage = { name = "ดาเมจบอส", sign = "+" },
	SkillCooldown = { name = "คูลดาวน์สกิล", sign = "−" },
	SkillDamage = { name = "ดาเมจสกิล", sign = "+" },
	TurretHp = { name = "เลือดป้อม", sign = "+" },
	StunReduce = { name = "เวลาช็อต", sign = "−" },
}
local RARITY_EMOJI: { [string]: string } = { Common = "⚪", Rare = "🔵", Epic = "🟣", Legendary = "🟡" }
local NEUTRAL_ICON = "🔩" -- ไอคอนชิ้นกลาง (ไม่มีธาตุ)
local GOOD_COLOR = Theme.Colors.Accent
local BAD_COLOR = Theme.Colors.Danger

-- ===== ชนิดข้อมูล =====
-- State = ทุกอย่างที่หน้าจอใช้ (อ่านจาก Attribute ครั้งเดียวต่อการวาด)
type State = {
	gear: GearMath.Gear?, -- nil = ข้อมูลยังโหลดไม่เสร็จ
	gearRaw: string,
	bonusRaw: string,
	bonus: GearMath.Bonus,
	element: string, -- "" = ยังไม่เลือกธาตุ
	coins: number,
	bossActive: boolean,
}
-- ข้อมูลแสดงผลของชิ้น 1 id
type ItemInfo = {
	key: string,
	slot: string,
	variant: string,
	rarity: string,
	name: string,
	icon: string, -- ไอคอนธาตุ (ชิ้นกลาง = NEUTRAL_ICON)
	elementName: string?, -- ชิ้นกลาง = nil
	rarityColor: Color3,
}

-- ===== ตัวแปรสถานะของหน้าจอ =====
local frame: Frame
local content: ScrollingFrame
local closeButton: TextButton
local sheet: Frame
local sheetTitle: TextLabel
local sheetStroke: UIStroke
local sheetContent: ScrollingFrame
local sheetClose: TextButton
local dropGui: ScreenGui
local bossState: Instance? = nil

local slotLayout: UIGridLayout? = nil
local itemLayout: UIGridLayout? = nil
local tabsRow: Frame? = nil

local filter = "All" -- "All" หรือชื่อช่อง
local selectedKey: string? = nil -- ชิ้นที่เปิดแผ่นรายละเอียดอยู่
local salvageCount = 1
local showOdds = false
local newKeys: { [string]: boolean } = {} -- id ที่เพิ่งได้จากบอสครั้งแรก (โชว์ป้าย "ใหม่" จนกว่าจะเปิดดู) · แสดงผลเท่านั้น
local dirty = true
local lastSignature = ""
local firstFocus: GuiObject? = nil
local sheetFocus: GuiObject? = nil
local armedId: string? = nil
local armedButton: TextButton? = nil
local armedIdle = ""
local armedToken = 0
local dropToken = 0
local returnFocus: string? = nil -- ปิดแผ่นรายละเอียดแล้ว Gamepad กลับไปเลือกการ์ดชื่อนี้

-- ===== อ่าน Attribute =====
-- แปลง Attribute "Gear" (JSON) → ตาราง Gear · ยังไม่มี/อ่านไม่ได้ = nil (โชว์ "กำลังโหลด")
-- ⚠️ Items ว่างอาจมาเป็น [] (array) → วนแล้วเก็บเฉพาะ key ที่เป็น id จริง + จำนวนเป็นตัวเลข ≥ 1 → [] กับ {} ได้ผลเดียวกัน
local function decodeGear(raw: any): GearMath.Gear?
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local items: { [string]: number } = {}
	if type(data.Items) == "table" then
		for key, count in data.Items do
			if GearMath.isKey(key) and type(count) == "number" and count == count and count >= 1 then
				items[key] = math.floor(count)
			end
		end
	end
	local equipped: { [string]: string } = {}
	local rawEquipped = if type(data.Equipped) == "table" then data.Equipped else {}
	for _, slot in Equipment.SlotOrder do
		local key = rawEquipped[slot]
		equipped[slot] = if GearMath.isKey(key) then key else ""
	end
	-- GearSlots มาพร้อม Gear · ใช้ตัวที่ใหม่กว่าไม่ได้ (ยิงคนละครั้ง) → ใช้ค่าใน JSON เป็นหลัก สำรองด้วย GearSlots
	local slotsSource = if type(data.Slots) == "number" then data.Slots else player:GetAttribute("GearSlots")
	return {
		Items = items,
		Equipped = equipped,
		Slots = GearMath.clampSlots(slotsSource),
		Pity = if type(data.Pity) == "number" and data.Pity == data.Pity then data.Pity else 0,
	}
end

-- แปลง Attribute "GearBonus" (JSON) → Bonus · ไม่มี = คำนวณเองจาก Gear (แสดงผลเท่านั้น)
local function decodeBonus(raw: any, gear: GearMath.Gear?, element: string): GearMath.Bonus
	if type(raw) == "string" then
		local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(data) == "table" then
			local bonus = GearMath.emptyBonus()
			for _, stat in GearMath.BONUS_STATS do
				local value = data[stat]
				if type(value) == "number" and value == value then
					(bonus :: any)[stat] = value
				end
			end
			return bonus
		end
	end
	return GearMath.bonus(gear, element)
end

local function readState(): State
	local gearRaw = player:GetAttribute("Gear")
	local bonusRaw = player:GetAttribute("GearBonus")
	local element = player:GetAttribute("Element")
	local coins = player:GetAttribute("Coins")
	local elementId = if ElementMath.isElement(element) then element else ""
	local gear = decodeGear(gearRaw)
	return {
		gear = gear,
		gearRaw = if type(gearRaw) == "string" then gearRaw else "",
		bonusRaw = if type(bonusRaw) == "string" then bonusRaw else "",
		bonus = decodeBonus(bonusRaw, gear, elementId),
		element = elementId,
		coins = if type(coins) == "number" and coins == coins then coins else 0,
		bossActive = bossState ~= nil and bossState:GetAttribute("Active") == true,
	}
end

-- ===== ตัวช่วยแสดงผล =====
-- สัดส่วน → "22%" / "4.5%"
local function pct(value: number): string
	return string.format("%g%%", math.floor(value * 1000 + 0.5) / 10)
end

-- "ดาเมจ +22%" / "คูลดาวน์สกิล −15%"
local function statText(stat: string, value: number): string
	local def = STAT_TEXT[stat]
	if not def then
		return `{stat} {pct(value)}`
	end
	return `{def.name} {def.sign}{pct(value)}`
end

-- ย่อตัวเลขเงิน: 15000 → "15K"
local function shortNumber(value: number): string
	if value >= 1e6 then
		return string.format("%gM", math.floor(value / 1e5) / 10)
	elseif value >= 1e4 then
		return string.format("%gK", math.floor(value / 1e2) / 10)
	end
	return tostring(math.floor(value))
end

-- สีสำหรับ RichText: <font color="#rrggbb">
local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

local function colored(text: string, color: Color3): string
	return `<font color="{hex(color)}">{text}</font>`
end

-- ข้อมูลแสดงผลของ id · id ไม่รู้จัก = nil
local function infoOf(key: string): ItemInfo?
	local slot, variant, rarity = GearMath.parseKey(key)
	if not slot or not variant or not rarity then
		return nil
	end
	local elementDef = Elements.Elements[variant]
	local rarityDef = Equipment.Rarities[rarity]
	return {
		key = key,
		slot = slot,
		variant = variant,
		rarity = rarity,
		name = Equipment.Names[`{slot}_{variant}`] or key,
		icon = if elementDef then elementDef.Icon or "" else NEUTRAL_ICON,
		elementName = if elementDef then elementDef.Name else nil,
		rarityColor = if rarityDef then rarityDef.Color else Theme.Colors.TextMuted,
	}
end

-- ต้องแตะยืนยัน 2 ครั้งไหม (ระดับ ≥ CONFIRM_FROM_RARITY)
local function needsConfirm(rarity: string): boolean
	return (GearMath.rarityIndex(rarity) or 0) >= (GearMath.rarityIndex(CONFIRM_FROM_RARITY) or math.huge)
end

-- ชิ้นในช่องนี้ "เข้าธาตุ" ป้อมไหม
local function matches(info: ItemInfo, element: string): boolean
	return element ~= "" and info.variant == element
end

-- ป้ายข้อความหลายบรรทัด (ตัดคำ + สูงตามข้อความ) · rich = ใช้แท็กสี
local function wrapped(parent: Instance, text: string, textSize: number, color: Color3, order: number, rich: boolean?): TextLabel
	local label = Components.label(parent, text, {
		size = UDim2.new(1, -10, 0, 0),
		textSize = textSize,
		color = color,
		order = order,
	})
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
	label.RichText = rich == true
	return label
end

-- ป้ายเล็กในการ์ด (ตำแหน่ง/ขนาดพิกเซลในแนวตั้ง · กว้างเต็มการ์ด)
local function cardLine(parent: Instance, text: string, y: number, height: number, textSize: number, color: Color3, bold: boolean?): TextLabel
	local label = Components.label(parent, text, {
		size = UDim2.new(1, -12, 0, height),
		position = UDim2.fromOffset(6, y),
		textSize = textSize,
		color = color,
		bold = bold,
	})
	label.RichText = true
	return label
end

local function addStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

-- ลบลูกทั้งหมดยกเว้น layout
local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

-- ===== ปุ่มกด (ปกติ / เทา / ยืนยัน 2 ครั้ง) =====
local render: (force: boolean?) -> ()

-- ล้างสถานะ "รอยืนยัน" (เรียกทุกครั้งที่วาดใหม่)
local function disarm()
	armedToken += 1
	armedId = nil
	armedButton = nil
end

-- ปุ่มกว้างเต็มแถว · enabled = false → ตัวหนังสือจาง กดแล้วไม่ส่ง (ยังเลือกด้วย Gamepad ได้เพื่ออ่านเหตุผล)
-- confirmId ≠ nil → ต้องแตะ 2 ครั้ง (ครั้งแรกเปลี่ยนเป็น ARMED_TEXT · ไม่กดซ้ำใน CONFIRM_SECONDS = กลับข้อความเดิม)
-- send คืน false = ไม่ได้ส่ง (เช่น กดรัว) → ไม่ขึ้น "กำลังส่ง…"
local function actionButton(
	parent: Instance,
	text: string,
	order: number,
	enabled: boolean,
	primary: boolean,
	confirmId: string?,
	send: () -> boolean
): TextButton
	local button = Components.button(parent, text, {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		order = order,
		textSize = 15,
		color = if enabled and primary then Theme.Colors.Accent else Theme.Colors.Surface,
		hoverColor = if enabled and primary then Theme.Colors.AccentHover else Theme.Colors.SurfaceHover,
	})
	button.Name = `Action{order}` -- ชื่อคงที่ → วาดใหม่แล้ว Gamepad กลับมาเลือกปุ่มเดิมได้
	button.TextWrapped = true
	if not enabled then
		button.TextTransparency = 0.5
		return button
	end
	button.Activated:Connect(function()
		if button.Text == SENDING_TEXT then
			return
		end
		if confirmId and armedId ~= confirmId then
			-- แตะครั้งแรก: ปุ่มอื่นที่รอยืนยันอยู่กลับเป็นข้อความเดิม
			if armedButton and armedButton ~= button and armedButton.Parent then
				armedButton.Text = armedIdle
			end
			armedToken += 1
			local token = armedToken
			armedId = confirmId
			armedButton = button
			armedIdle = text
			button.Text = ARMED_TEXT
			task.delay(CONFIRM_SECONDS, function()
				if armedToken == token and armedId == confirmId then
					armedId = nil
					armedButton = nil
					if button.Parent then
						button.Text = text
					end
				end
			end)
			return
		end
		disarm()
		if send() then
			button.Text = SENDING_TEXT
			-- Server ปฏิเสธเงียบ (Attribute ไม่เปลี่ยน = ไม่วาดใหม่) → คืนข้อความให้กดใหม่ได้
			task.delay(PENDING_SECONDS, function()
				if button.Parent and button.Text == SENDING_TEXT then
					button.Text = text
				end
			end)
		end
	end)
	return button
end

-- ===== แผ่นรายละเอียด (เลื่อนทับจากล่าง) =====
local function openSheet(key: string)
	selectedKey = key
	salvageCount = 1
	newKeys[key] = nil
	render(true)
end

local function closeSheet()
	returnFocus = if selectedKey then `Item_{selectedKey}` else nil
	selectedKey = nil
	render(true)
end

-- เทียบโบนัส "ถ้าใส่ชิ้นนี้" กับตอนนี้ (ก๊อป gear แล้วแก้ Equipped · คำนวณด้วย GearMath.bonus เพื่อแสดงเท่านั้น)
local function compareText(state: State, info: ItemInfo): string
	local gear = state.gear :: GearMath.Gear
	local equipped = table.clone(gear.Equipped)
	equipped[info.slot] = info.key
	local before = GearMath.bonus(gear, state.element)
	local after = GearMath.bonus({ Items = gear.Items, Equipped = equipped, Slots = gear.Slots, Pity = gear.Pity }, state.element)
	local parts = {}
	for _, stat in GearMath.BONUS_STATS do
		local diff = (after :: any)[stat] - (before :: any)[stat]
		if math.abs(diff) >= 0.0005 then
			local name = STAT_TEXT[stat] and STAT_TEXT[stat].name or stat
			-- ทุกค่า "มากขึ้น = ดีขึ้น" (คูลดาวน์/ช็อตเป็น "ลดลงกี่ %") → ▲ เขียว / ▼ แดง
			if diff > 0 then
				table.insert(parts, colored(`{name} ▲{pct(diff)}`, GOOD_COLOR))
			else
				table.insert(parts, colored(`{name} ▼{pct(-diff)}`, BAD_COLOR))
			end
		end
	end
	if #parts == 0 then
		return "ค่าเท่าเดิม"
	end
	return table.concat(parts, " · ")
end

local refreshSheet: () -> ()

-- วาดแผ่นรายละเอียดของ selectedKey · ไม่มีชิ้นแล้ว (ย่อย/รวมหมด) = ปิด
local function renderSheet(state: State)
	sheetFocus = nil
	local gear = state.gear
	local info = if selectedKey then infoOf(selectedKey) else nil
	local count = if gear and info then gear.Items[info.key] or 0 else 0
	if not gear or not info or count < 1 then
		selectedKey = nil
		sheet.Visible = false
		return
	end
	clear(sheetContent)
	sheet.Visible = true
	sheetStroke.Color = info.rarityColor
	sheetTitle.Text = `{info.icon} {info.name}`
	sheetTitle.TextColor3 = info.rarityColor

	local slotDef = Equipment.Slots[info.slot]
	local rarityDef = Equipment.Rarities[info.rarity]
	local equipped = GearMath.isEquipped(gear, info.key)
	local free = GearMath.freeCount(gear, info.key)
	local slotOpen = GearMath.isSlotOpen(info.slot, gear.Slots)
	local kind = if info.elementName then `ธาตุ{info.elementName}` else "ชิ้นกลาง (ไม่มีธาตุ)"

	-- ===== ข้อมูลชิ้น =====
	wrapped(
		sheetContent,
		`{RARITY_EMOJI[info.rarity] or ""} {colored(rarityDef.Name, info.rarityColor)} · {slotDef.Icon} {slotDef.Name} · {info.icon} {kind}`,
		14,
		Theme.Colors.Text,
		1,
		true
	)
	wrapped(sheetContent, `มี ×{count} · ใส่อยู่ {if equipped then 1 else 0} · ใช้ย่อย/รวมได้ {free}`, 13, Theme.Colors.TextMuted, 2)
	local mainStat, mainValue = GearMath.mainStat(info.slot, info.variant, info.rarity)
	wrapped(sheetContent, `ค่าหลัก: {statText(mainStat, mainValue)}`, 15, Theme.Colors.Text, 3)
	local match = Equipment.MatchBonus[info.variant]
	if not match then
		wrapped(sheetContent, "ชิ้นกลาง: ค่าหลักสูงกว่า แต่ไม่มีโบนัสธาตุตรง (ปลอดภัยเวลาเปลี่ยนธาตุ)", 13, Theme.Colors.TextMuted, 4)
	elseif matches(info, state.element) then
		wrapped(sheetContent, `✓ โบนัสธาตุตรง: {statText(match.Stat, match[info.rarity] or 0)}`, 14, GOOD_COLOR, 4)
	else
		-- ค่ารองเป็นสีเทาเมื่อธาตุไม่ตรง (สเปก 11.5)
		wrapped(
			sheetContent,
			`โบนัสธาตุตรง: {statText(match.Stat, match[info.rarity] or 0)} (ธาตุไม่ตรง · ต้องใช้ป้อมธาตุ{info.elementName})`,
			13,
			Theme.Colors.TextMuted,
			4
		)
	end
	if not slotOpen then
		wrapped(sheetContent, `🔒 ช่อง{slotDef.Name}ยังล็อก — ปลดล็อกช่องก่อนถึงจะใส่ได้`, 13, Theme.Colors.Coin, 5)
	elseif not equipped then
		local current = infoOf(gear.Equipped[info.slot])
		local header = if current then `เทียบกับ {current.name} ที่ใส่อยู่:` else "ถ้าใส่ชิ้นนี้ (ช่องว่าง):"
		wrapped(sheetContent, `{header} {compareText(state, info)}`, 13, Theme.Colors.Text, 5, true)
	end

	-- ===== ปุ่ม 1: ใส่ / ถอด =====
	local equipButton: TextButton
	if equipped then
		local ok = not state.bossActive
		equipButton = actionButton(sheetContent, if ok then "ถอดออก" else "⛔ ถอดได้หลังบอสจากไป", 10, ok, false, nil, function()
			return GearController.unequip(info.slot)
		end)
	elseif not slotOpen then
		equipButton = actionButton(sheetContent, "🔒 ช่องยังล็อก", 10, false, false, nil, function()
			return false
		end)
	elseif state.bossActive then
		equipButton = actionButton(sheetContent, "⛔ เปลี่ยนอุปกรณ์หลังบอสจากไป", 10, false, false, nil, function()
			return false
		end)
	else
		local current = infoOf(gear.Equipped[info.slot])
		local text = if current then `ใส่แทน {current.name}` else "ใส่"
		equipButton = actionButton(sheetContent, text, 10, true, true, nil, function()
			return GearController.equip(info.key)
		end)
	end
	sheetFocus = equipButton

	-- ===== ปุ่ม 2: รวม 3 → 1 =====
	local nextRarity = GearMath.nextRarity(info.rarity)
	local cost = GearMath.mergeCost(info.rarity)
	if not nextRarity or not cost then
		actionButton(sheetContent, "ระดับสูงสุดแล้ว (รวมต่อไม่ได้)", 20, false, false, nil, function()
			return false
		end)
	else
		local nextName = Equipment.Rarities[nextRarity].Name
		local resultKey = GearMath.keyOf(info.slot, info.variant, nextRarity)
		local base = `🔨 รวม 3→1 {nextName} · 💰{shortNumber(cost)}`
		local text, ok
		if (gear.Items[resultKey] or 0) >= Equipment.StackCap then
			text, ok = `กอง{nextName}เต็ม ({Equipment.StackCap}) รวมไม่ได้`, false
		elseif free < 3 then
			text, ok = `{base} (มีว่าง {free}/3)`, false
		elseif state.coins < cost then
			text, ok = `{base} (เงินไม่พอ)`, false
		else
			text, ok = base, true
		end
		actionButton(sheetContent, text, 20, ok, true, if needsConfirm(info.rarity) then `merge:{info.key}` else nil, function()
			return GearController.merge(info.key)
		end)
	end

	-- ===== ปุ่ม 3: ย่อย (เลือกจำนวน − n + สูงสุด) =====
	local value = GearMath.salvageValue(info.rarity)
	if free < 1 then
		actionButton(sheetContent, "♻ ย่อยไม่ได้ (ชิ้นที่ใส่อยู่)", 30, false, false, nil, function()
			return false
		end)
		return
	end
	salvageCount = math.clamp(salvageCount, 1, math.min(free, Equipment.StackCap))
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -10, 0, Theme.ButtonHeight)
	row.LayoutOrder = 30
	row.Parent = sheetContent
	Components.list(row, GAP, Enum.FillDirection.Horizontal)
	local function step(delta: number)
		salvageCount = math.clamp(salvageCount + delta, 1, math.min(free, Equipment.StackCap))
		refreshSheet()
	end
	local stepSize = UDim2.new(0.25, -GAP * 3 / 4, 1, 0)
	Components.button(row, "−", { size = stepSize, order = 1 }, function()
		step(-1)
	end).Name = "SalvageMinus"
	local countLabel = Components.label(row, `×{salvageCount}`, {
		size = stepSize,
		bold = true,
		alignX = Enum.TextXAlignment.Center,
		order = 2,
	})
	countLabel.TextTruncate = Enum.TextTruncate.None
	Components.button(row, "+", { size = stepSize, order = 3 }, function()
		step(1)
	end).Name = "SalvagePlus"
	Components.button(row, "สูงสุด", { size = stepSize, order = 4, textSize = 14 }, function()
		salvageCount = math.min(free, Equipment.StackCap)
		refreshSheet()
	end).Name = "SalvageMax"
	local amount = salvageCount
	actionButton(
		sheetContent,
		`♻ ย่อย {amount} ชิ้น → +{shortNumber(amount * value)}💰`,
		31,
		true,
		false,
		if needsConfirm(info.rarity) then `salvage:{info.key}:{amount}` else nil,
		function()
			return GearController.salvage(info.key, amount)
		end
	)
end

-- วาดแค่แผ่นรายละเอียด (ปุ่ม − / + / สูงสุด ของจำนวนย่อย) · ไม่ต้องสร้างกริดกระเป๋าใหม่ทั้งแผง
refreshSheet = function()
	local selected = GuiService.SelectedObject
	local selectedName = if selected and selected:IsDescendantOf(sheet) then selected.Name else nil
	disarm()
	renderSheet(readState())
	if selectedName and UserInputService.GamepadEnabled and sheet.Visible then
		local found = sheetContent:FindFirstChild(selectedName, true)
		GuiService.SelectedObject = if found and found:IsA("GuiObject") then found else sheetFocus
	end
end

-- ===== ส่วนต่างๆ ของแผงหลัก =====
-- การ์ดช่อง 1 ช่อง: ใส่อยู่ (แตะ = รายละเอียด) · ว่าง (แตะ = กรองกระเป๋าช่องนี้) · ล็อก (+ ปุ่มปลดล็อก ถ้าเป็นช่องถัดไป)
local function slotCard(parent: Instance, state: State, slot: string, index: number): GuiObject
	local gear = state.gear :: GearMath.Gear
	local slotDef = Equipment.Slots[slot]
	local header = `{slotDef.Icon} {slotDef.Name}`

	if index > gear.Slots then
		-- ===== ช่องล็อก =====
		local box = Instance.new("Frame")
		box.Name = `Slot_{slot}`
		box.BackgroundColor3 = Theme.Colors.Surface
		box.BackgroundTransparency = 0.4
		box.LayoutOrder = index
		box.Parent = parent
		Components.corner(box)
		addStroke(box, Theme.Colors.SurfaceHover, 1)
		cardLine(box, header, 4, 18, 13, Theme.Colors.TextMuted)
		local price = Equipment.SlotPrices[index] or 0
		if index == gear.Slots + 1 then
			local ok = state.coins >= price
			cardLine(box, if ok then "🔒 ล็อก" else "🔒 เงินไม่พอ", 24, 18, 13, Theme.Colors.TextMuted)
			local button = actionButton(box, `ปลดล็อก 💰{shortNumber(price)}`, 1, ok, true, `unlock:{index}`, function()
				return GearController.unlockSlot()
			end)
			button.Size = UDim2.new(1, -12, 0, Theme.ButtonHeight)
			button.AnchorPoint = Vector2.new(0.5, 1)
			button.Position = UDim2.new(0.5, 0, 1, -6)
			button.TextSize = 13
			button.Name = `Unlock_{slot}`
			return button
		end
		cardLine(box, `🔒 💰{shortNumber(price)}`, 24, 18, 13, Theme.Colors.TextMuted)
		local hint = cardLine(box, `ปลดช่อง{Equipment.Slots[Equipment.SlotOrder[index - 1]].Name}ก่อน`, 46, 34, 12, Theme.Colors.TextMuted)
		hint.TextWrapped = true
		return box
	end

	local info = infoOf(gear.Equipped[slot])
	local button = Components.button(parent, "", { order = index }, function()
		if info then
			openSheet(info.key)
		else
			filter = slot
			render(true)
			-- เลื่อนลงไปที่แท็บกรอง ให้เห็นชิ้นของช่องนี้ทันที
			task.defer(function()
				if tabsRow and tabsRow.Parent then
					local y = tabsRow.AbsolutePosition.Y - content.AbsolutePosition.Y + content.CanvasPosition.Y
					content.CanvasPosition = Vector2.new(0, math.max(0, y))
				end
			end)
		end
	end)
	button.Name = `Slot_{slot}`
	cardLine(button, header, 4, 18, 13, Theme.Colors.TextMuted)
	if info then
		addStroke(button, info.rarityColor, 2)
		local rarityDef = Equipment.Rarities[info.rarity]
		cardLine(button, info.name, 24, 20, 15, info.rarityColor, true)
		local tag = if matches(info, state.element) then " " .. colored("✓ธาตุ", GOOD_COLOR) else ""
		cardLine(button, `{info.icon} {rarityDef.Name}{tag}`, 46, 18, 13, Theme.Colors.Text)
		local stat, value = GearMath.mainStat(info.slot, info.variant, info.rarity)
		local statLine = cardLine(button, statText(stat, value), 66, 36, 12, Theme.Colors.TextMuted)
		statLine.TextWrapped = true
	else
		addStroke(button, Theme.Colors.SurfaceHover, 1)
		cardLine(button, "ว่าง", 24, 20, 15, Theme.Colors.TextMuted, true)
		local hint = cardLine(button, "แตะเพื่อดูชิ้นที่ใส่ได้", 46, 36, 12, Theme.Colors.TextMuted)
		hint.TextWrapped = true
	end
	return button
end

-- การ์ดชิ้นในกระเป๋า: ไอคอนธาตุ+ช่อง · ×จำนวน · ชื่อ · ระดับ · ค่าหลัก · ป้าย (เข้าธาตุ / ใส่อยู่ / ใหม่)
local function itemCard(parent: Instance, state: State, info: ItemInfo, count: number, order: number): TextButton
	local gear = state.gear :: GearMath.Gear
	local button = Components.button(parent, "", { order = order }, function()
		openSheet(info.key)
	end)
	button.Name = `Item_{info.key}`
	addStroke(button, info.rarityColor, 2)
	local slotDef = Equipment.Slots[info.slot]
	cardLine(button, `{info.icon}{slotDef.Icon}`, 4, 20, 16, Theme.Colors.Text)
	local countLabel = cardLine(button, `×{count}`, 4, 20, 15, Theme.Colors.Text, true)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	local nameLabel = cardLine(button, info.name, 26, 34, 13, Theme.Colors.Text, true)
	nameLabel.TextWrapped = true
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	cardLine(button, `{RARITY_EMOJI[info.rarity] or ""} {Equipment.Rarities[info.rarity].Name}`, 60, 16, 12, info.rarityColor)
	local stat, value = GearMath.mainStat(info.slot, info.variant, info.rarity)
	cardLine(button, statText(stat, value), 77, 16, 12, Theme.Colors.TextMuted)
	local badges = {}
	if newKeys[info.key] then
		table.insert(badges, colored("🆕ใหม่", Theme.Colors.Coin))
	end
	if matches(info, state.element) then
		table.insert(badges, colored("✓เข้าธาตุ", GOOD_COLOR))
	end
	if GearMath.isEquipped(gear, info.key) then
		table.insert(badges, colored("ใส่อยู่", Theme.Colors.Text))
	end
	if #badges > 0 then
		local line = cardLine(button, table.concat(badges, " "), 95, 18, 12, Theme.Colors.Text, true)
		line.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return button
end

-- ปรับจำนวนคอลัมน์ตามความกว้างเนื้อหา (เรียกเมื่อขนาดจอเปลี่ยน · แค่ตั้ง CellSize ไม่สร้างของใหม่)
local function updateColumns()
	local width = content.AbsoluteSize.X - 10
	if slotLayout and slotLayout.Parent then
		local cols = if width >= WIDE_SLOTS_WIDTH then 4 else 2
		slotLayout.CellSize = UDim2.new(1 / cols, -GAP * (cols - 1) / cols, 0, SLOT_CARD_HEIGHT)
	end
	if itemLayout and itemLayout.Parent then
		local cols = math.max(2, math.floor((width + GAP) / (ITEM_MIN_WIDTH + GAP)))
		itemLayout.CellSize = UDim2.new(1 / cols, -GAP * (cols - 1) / cols, 0, ITEM_CARD_HEIGHT)
	end
end

-- กล่องกริด (สูงตามเนื้อหา) · คืน (กล่อง, layout)
local function grid(parent: Instance, order: number): (Frame, UIGridLayout)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -10, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.LayoutOrder = order
	box.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = box
	return box, layout
end

-- โบนัสรวม (จาก GearBonus ที่ Server ใช้จริง) + ตัวบอกชุดธาตุ
local function buildBonus(state: State, order: number)
	local gear = state.gear :: GearMath.Gear
	local parts = {}
	for _, stat in GearMath.BONUS_STATS do
		local value = (state.bonus :: any)[stat]
		if value >= 0.0005 then
			table.insert(parts, statText(stat, value))
		end
	end
	local text = if #parts > 0 then table.concat(parts, " · ") else "ยังไม่มีโบนัส — ใส่อุปกรณ์ในช่องด้านบน"
	wrapped(content, "📊 โบนัสรวมที่ใช้จริง", 15, Theme.Colors.Text, order)
	wrapped(content, text, 14, if #parts > 0 then Theme.Colors.Coin else Theme.Colors.TextMuted, order + 1)

	-- ชุดธาตุ: ชิ้นธาตุตรงครบทุกช่อง (ช่องต้องเปิดครบ) → FullSetBonus
	local total = #Equipment.SlotOrder
	local bonusText = statText(Equipment.FullSetBonus.Stat, Equipment.FullSetBonus.Value)
	local elementDef = ElementMath.defOf(state.element)
	if not elementDef then
		wrapped(content, "🧩 เลือกธาตุป้อมก่อน เพื่อเปิดโบนัสธาตุตรง + โบนัสชุดธาตุ", 13, Theme.Colors.TextMuted, order + 2)
		return
	end
	local matched = 0
	for index, slot in Equipment.SlotOrder do
		local info = infoOf(gear.Equipped[slot])
		if index <= gear.Slots and info and matches(info, state.element) then
			matched += 1
		end
	end
	if matched >= total then
		wrapped(content, `✨ ชุดธาตุ{elementDef.Name}ครบ {total}/{total} · {bonusText}`, 14, GOOD_COLOR, order + 2)
	else
		wrapped(
			content,
			`🧩 ชุดธาตุ{elementDef.Name} {matched}/{total} ช่อง · ครบ = {bonusText}`,
			13,
			Theme.Colors.TextMuted,
			order + 2
		)
	end
end

-- แท็บกรองช่อง (ทั้งหมด + 4 ช่อง)
local function buildTabs(order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -10, 0, Theme.ButtonHeight)
	row.LayoutOrder = order
	row.Parent = content
	Components.list(row, GAP, Enum.FillDirection.Horizontal)
	tabsRow = row
	local tabs = { "All" }
	for _, slot in Equipment.SlotOrder do
		table.insert(tabs, slot)
	end
	local count = #tabs
	for index, id in tabs do
		local text = if id == "All" then "ทั้งหมด" else `{Equipment.Slots[id].Icon}{Equipment.Slots[id].Name}`
		local active = filter == id
		local button = Components.button(row, text, {
			size = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0),
			order = index,
			textSize = 12,
			color = if active then Theme.Colors.Accent else Theme.Colors.Surface,
			hoverColor = if active then Theme.Colors.AccentHover else Theme.Colors.SurfaceHover,
		}, function()
			filter = id
			render(true)
		end)
		button.Name = `Tab_{id}`
		button.TextWrapped = true
	end
end

-- รายการชิ้นตามตัวกรอง · เรียง: ระดับสูงก่อน → ธาตุตรงก่อน → ลำดับช่อง → ลำดับแบบ
local function sortedItems(state: State): { { info: ItemInfo, count: number } }
	local gear = state.gear :: GearMath.Gear
	local list = {}
	for key, count in gear.Items do
		local info = infoOf(key)
		if info and (filter == "All" or info.slot == filter) then
			table.insert(list, { info = info, count = count })
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = GearMath.rarityIndex(a.info.rarity) or 0, GearMath.rarityIndex(b.info.rarity) or 0
		if ra ~= rb then
			return ra > rb
		end
		local ma, mb = matches(a.info, state.element), matches(b.info, state.element)
		if ma ~= mb then
			return ma
		end
		local sa, sb = GearMath.slotIndex(a.info.slot) or 0, GearMath.slotIndex(b.info.slot) or 0
		if sa ~= sb then
			return sa < sb
		end
		return (table.find(Equipment.Variants, a.info.variant) or 0) < (table.find(Equipment.Variants, b.info.variant) or 0)
	end)
	return list
end

-- ตารางโอกาสดรอป (สเปก 4.2 · โปร่งใส) + pity
local function buildOdds(state: State, order: number)
	local gear = state.gear :: GearMath.Gear
	local steps = Equipment.Drops.ShareRolls
	local tables = {
		{ id = "A", label = `ดาเมจ < {pct(steps[1])}` },
		{ id = "B", label = `ดาเมจ {pct(steps[1])}–{pct(steps[2])}` },
		{ id = "C", label = `ดาเมจ ≥ {pct(steps[2])}` },
		{ id = "Top", label = "โบนัสอันดับ 1" },
	}
	local lines = {}
	for _, entry in tables do
		local parts = {}
		for _, row in GearMath.odds(entry.id) do
			if row.Chance > 0 then
				table.insert(parts, `{RARITY_EMOJI[row.Rarity] or ""}{pct(row.Chance)}`)
			end
		end
		table.insert(lines, `• {entry.label}: {table.concat(parts, " ")}`)
	end
	local drops = Equipment.Drops
	local pityName = Equipment.Rarities[drops.PityRarity].Name
	table.insert(lines, `• สุ่ม {drops.PityRolls} ครั้งติดไม่ได้{pityName}ขึ้นไป → ครั้งถัดไปได้{pityName}แน่นอน (ตอนนี้ {gear.Pity}/{drops.PityRolls})`)
	table.insert(lines, `• ได้ของต่อบอส: ตีได้ 1 ชิ้น · ดาเมจถึงเกณฑ์/ติดท็อป 3 ได้เพิ่ม · สูงสุด {drops.MaxRolls} ชิ้น`)
	wrapped(content, table.concat(lines, "\n"), 13, Theme.Colors.TextMuted, order)
end

-- ===== วาดแผงทั้งหมด =====
-- force = true → วาดใหม่เสมอ (ผู้เล่นกดแท็บ/เลือกชิ้น) · false → วาดเฉพาะเมื่อข้อมูลที่มีผลกับจอเปลี่ยน
-- แผงปิดอยู่ = ไม่วาด แค่จำว่า dirty (วาดตอนเปิด) → ไม่เสียแรงตอนเงินขึ้นทุกวินาทีระหว่างเล่น
render = function(force: boolean?)
	if not frame or not frame.Visible then
		dirty = true
		return
	end
	local state = readState()
	local gear = state.gear
	-- เงินเปลี่ยนบ่อยมาก → เก็บแค่ "พอ/ไม่พอ" ของปุ่มที่ใช้เงิน ไม่ใช่ตัวเลข
	local unlockPrice = if gear then GearMath.nextSlotPrice(gear.Slots) else nil
	local selectedInfo = if selectedKey then infoOf(selectedKey) else nil
	local mergePrice = if selectedInfo then GearMath.mergeCost(selectedInfo.rarity) else nil
	local signature = table.concat({
		state.gearRaw,
		state.bonusRaw,
		tostring(player:GetAttribute("GearSlots")),
		state.element,
		tostring(state.bossActive),
		tostring(unlockPrice ~= nil and state.coins >= unlockPrice),
		tostring(mergePrice ~= nil and state.coins >= mergePrice),
	}, "|")
	if not force and not dirty and signature == lastSignature then
		return
	end
	lastSignature = signature
	dirty = false
	disarm()

	-- จำชิ้นที่ Gamepad เลือกอยู่ (ชื่อ) → วาดใหม่แล้วเลือกชิ้นชื่อเดิม
	local selected = GuiService.SelectedObject
	local selectedName = if selected and selected:IsDescendantOf(frame) then selected.Name else nil
	local selectedInSheet = selected ~= nil and selected:IsDescendantOf(sheet)
	local canvas = content.CanvasPosition

	clear(content)
	slotLayout, itemLayout, tabsRow = nil, nil, nil
	firstFocus = nil

	if not gear then
		wrapped(content, "กำลังโหลดข้อมูลอุปกรณ์…", 15, Theme.Colors.TextMuted, 1)
		sheet.Visible = false
		return
	end

	-- 1) แถวสถานะ
	local total = GearMath.countAll(gear.Items)
	local status = `🎒 กระเป๋า {total}/{Equipment.InventoryCap}`
	if total >= Equipment.InventoryCap then
		status ..= " · เต็ม! ของใหม่จะถูกย่อยเป็นเหรียญ"
	end
	wrapped(content, status, 14, if total >= Equipment.InventoryCap then Theme.Colors.Coin else Theme.Colors.TextMuted, 1)
	if state.bossActive then
		wrapped(content, "⛔ บอสอยู่ — เปลี่ยนอุปกรณ์หลังบอสจากไป (ย่อย/รวม/ปลดช่องทำได้)", 14, BAD_COLOR, 2)
	end

	-- 2) การ์ด 4 ช่อง
	local slotBox, layout = grid(content, 10)
	slotLayout = layout
	for index, slot in Equipment.SlotOrder do
		local card = slotCard(slotBox, state, slot, index)
		if firstFocus == nil and card:IsA("GuiButton") then
			firstFocus = card
		end
	end

	-- 3) โบนัสรวม + ชุดธาตุ
	buildBonus(state, 20)

	-- 4) แท็บกรอง
	buildTabs(30)

	-- 5) กริดกระเป๋า
	local list = sortedItems(state)
	if #list == 0 then
		local empty = if total == 0
			then "ยังไม่มีอุปกรณ์ — ตีบอสให้โดนเพื่อรับอุปกรณ์ (ตีมาก/ติดท็อป = ได้หลายชิ้น)"
			else "ไม่มีชิ้นของช่องนี้"
		wrapped(content, empty, 14, Theme.Colors.TextMuted, 40)
	else
		local itemBox, grid2 = grid(content, 40)
		itemLayout = grid2
		for index, entry in list do
			itemCard(itemBox, state, entry.info, entry.count, index)
		end
	end

	-- 6) ย่อยทั้งหมดระดับ Common (ข้ามชิ้นที่ใส่อยู่ · ยืนยัน 2 ครั้งเสมอ)
	local bulkRarity = Equipment.RarityOrder[1]
	local bulkCount = 0
	for key in gear.Items do
		local _, _, rarity = GearMath.parseKey(key)
		if rarity == bulkRarity then
			bulkCount += GearMath.freeCount(gear, key)
		end
	end
	local bulkName = Equipment.Rarities[bulkRarity].Name
	local bulkText = if bulkCount > 0
		then `♻ แยกทั้งหมดระดับ{bulkName} ({bulkCount} ชิ้น → +{shortNumber(bulkCount * GearMath.salvageValue(bulkRarity))}💰)`
		else `♻ ไม่มีชิ้นระดับ{bulkName}ให้แยก`
	actionButton(content, bulkText, 50, bulkCount > 0, false, `bulk:{bulkRarity}`, function()
		return GearController.salvageRarity(bulkRarity)
	end)

	-- 7) โอกาสดรอป (เปิด/ปิด)
	Components.button(content, if showOdds then "ℹ️ ซ่อนโอกาสดรอป" else "ℹ️ โอกาสดรอป", {
		size = UDim2.new(1, -10, 0, Theme.ButtonHeight),
		order = 60,
		textSize = 15,
	}, function()
		showOdds = not showOdds
		render(true)
	end).Name = "Odds"
	if showOdds then
		buildOdds(state, 61)
	end

	updateColumns()
	content.CanvasPosition = canvas
	-- ขนาด canvas อัปเดตเฟรมถัดไป (AutomaticCanvasSize) → ตั้งตำแหน่งเลื่อนซ้ำอีกรอบ ไม่ให้เด้งกลับขึ้นบนสุด
	task.defer(function()
		if content.Parent then
			content.CanvasPosition = canvas
		end
	end)
	renderSheet(state)

	-- Gamepad: ของเดิมถูกลบไปแล้ว → เลือกชิ้นชื่อเดิม / ปุ่มแรกของแผ่นรายละเอียด / ปุ่มแรกของแผง
	if UserInputService.GamepadEnabled and Panels.current() == PANEL_NAME then
		local target: GuiObject? = nil
		if sheet.Visible then
			target = if selectedInSheet then nil else sheetFocus
			if selectedInSheet and selectedName then
				local found = sheetContent:FindFirstChild(selectedName, true)
				target = if found and found:IsA("GuiObject") then found else sheetFocus
			end
		else
			local wanted = returnFocus or selectedName
			local found = if wanted then content:FindFirstChild(wanted, true) else nil
			target = if found and found:IsA("GuiObject") then found else nil
		end
		GuiService.SelectedObject = target or firstFocus or closeButton
	end
	returnFocus = nil
end

-- ===== ป๊อปอัปของดรอปจากบอส =====
-- แสดงรายการของที่ได้ (Server → Client · แสดงผลเท่านั้น) · ตรวจรูปแบบก่อนใช้ · ปิดเองไม่ต้องกด
local function showDrops(list: any)
	if type(list) ~= "table" then
		return
	end
	local entries = {}
	for _, entry in list do
		if type(entry) == "table" and GearMath.isKey(entry.Key) then
			local salvaged = if type(entry.Salvaged) == "number" and entry.Salvaged == entry.Salvaged and entry.Salvaged > 0
				then entry.Salvaged
				else nil
			table.insert(entries, { key = entry.Key :: string, new = entry.New == true, salvaged = salvaged, top = entry.Top == true })
			if #entries >= DROP_MAX_ROWS then
				break
			end
		end
	end
	if #entries == 0 then
		return
	end
	for _, entry in entries do
		if entry.new and not entry.salvaged then
			newKeys[entry.key] = true
		end
	end
	render(true)

	dropToken += 1
	local token = dropToken
	local old = dropGui:FindFirstChild("Drops")
	if old then
		old:Destroy()
	end

	-- ✏️ ตำแหน่ง/ขนาด: กลางบน ใต้แถบบอสของ CombatUI (แถบนั้นสูงจากขอบบน 12 + 64 px) · กว้าง 70% ไม่เกิน 320 px
	-- Frame ไม่ Active → แตะนอกปุ่มทะลุไปเกม (ไม่บังการหมุนกล้อง/เล่น) [Unverified: พฤติกรรมแตะทะลุ Frame บนมือถือ]
	local box = Instance.new("Frame")
	box.Name = "Drops"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 84)
	box.Size = UDim2.new(0.7, 0, 0, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = Theme.Colors.Background
	box.BackgroundTransparency = 0.15
	box.Active = false
	box.Parent = dropGui
	Components.corner(box)
	Components.padding(box, 8)
	addStroke(box, Theme.Colors.Coin, 1)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, math.huge)
	limit.Parent = box
	Components.list(box, 6)

	local title = Components.label(box, "🛠 ได้อุปกรณ์จากบอส!", { size = UDim2.new(1, 0, 0, 22), bold = true, textSize = 16, color = Theme.Colors.Coin, order = 0 })
	title.TextXAlignment = Enum.TextXAlignment.Center

	for index, entry in entries do
		local info = infoOf(entry.key)
		if not info then
			continue
		end
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.Colors.Surface
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = index
		row.Parent = box
		Components.corner(row, UDim.new(0, 8))
		Components.padding(row, 6)
		local stroke = addStroke(row, info.rarityColor, 2)
		local extra = {}
		if entry.top then
			table.insert(extra, colored("🏆ท็อป", Theme.Colors.Coin))
		end
		if entry.new and not entry.salvaged then
			table.insert(extra, colored("🆕ใหม่", Theme.Colors.Coin))
		end
		local text = `{info.icon}{Equipment.Slots[info.slot].Icon} <b>{info.name}</b> {colored(Equipment.Rarities[info.rarity].Name, info.rarityColor)}`
		if #extra > 0 then
			text ..= " " .. table.concat(extra, " ")
		end
		if entry.salvaged then
			text ..= "\n" .. colored(`กระเป๋าเต็ม → ได้ {entry.salvaged}💰 แทน`, Theme.Colors.TextMuted)
		end
		local label = Components.label(row, text, { size = UDim2.new(1, 0, 0, 0), textSize = 14 })
		label.RichText = true
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None

		-- เด้งเข้าทีละแถว (0.2 วิ) · Legendary = ขอบกะพริบ
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = row
		row.Visible = false
		task.delay((index - 1) * 0.2, function()
			if dropToken ~= token or not row.Parent then
				return
			end
			row.Visible = true
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			if info.rarity == "Legendary" then
				TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 4 }):Play()
			end
		end)
	end

	-- ปุ่มเปิดหน้าอุปกรณ์ (ไม่ให้ Gamepad เลือกเอง กันแย่งโฟกัสตอนเล่น)
	local open = Components.button(box, "ดูอุปกรณ์", {
		size = UDim2.new(1, 0, 0, Theme.ButtonHeight),
		order = 100,
		textSize = 15,
	}, function()
		Panels.open(PANEL_NAME)
		box:Destroy()
	end)
	open.Selectable = false

	-- ปิดเองหลัง DROP_SHOW_SECONDS (ป๊อปอัปใหม่มาก่อน = token เปลี่ยน → ไม่ปิดของใหม่)
	task.delay(DROP_SHOW_SECONDS + #entries * 0.2, function()
		if dropToken == token and box.Parent then
			box:Destroy()
		end
	end)
end

-- เปิด/ปิดแผง (ปุ่มลัด G / RB) · ปุ่ม HUD ใน HudUI เรียก Panels.toggle("Gear") เองโดยตรง
local function toggle()
	Panels.toggle(PANEL_NAME)
end

local GearUI = {}

-- สร้างแผง + แผ่นรายละเอียด + ที่วางป๊อปอัป + ปุ่มลัด
function GearUI.Init()
	-- ===== แผงอุปกรณ์ (กรอบมาตรฐานจาก Components.panel · ขยายขนาดสูงสุดเป็น PANEL_MAX_SIZE) =====
	local gui = Components.screen("GearGui", 10)
	frame, content, closeButton = Components.panel(gui, "🛠 อุปกรณ์ป้อม", Panels.close)
	local limit = frame:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = PANEL_MAX_SIZE
	end
	Panels.register(PANEL_NAME, frame, closeButton)

	-- ===== แผ่นรายละเอียด: ทับครึ่งล่างของแผง (ZIndex สูงกว่าเนื้อหา) =====
	-- ✏️ ความสูง = Size Y 0.78 ของแผง · SelectionGroup = Gamepad เลื่อนโฟกัสอยู่ในแผ่นนี้จนกว่าจะปิด
	sheet = Instance.new("Frame")
	sheet.Name = "Detail"
	sheet.AnchorPoint = Vector2.new(0.5, 1)
	sheet.Position = UDim2.fromScale(0.5, 1)
	sheet.Size = UDim2.fromScale(1, 0.78)
	sheet.BackgroundColor3 = Theme.Colors.Background
	sheet.Active = true -- กันแตะทะลุไปโดนการ์ดข้างใต้
	sheet.ZIndex = 5
	sheet.Visible = false
	sheet.SelectionGroup = true
	sheet.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	sheet.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	sheet.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	sheet.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	sheet.Parent = frame
	Components.corner(sheet)
	Components.padding(sheet, 8)
	sheetStroke = addStroke(sheet, Theme.Colors.SurfaceHover, 2)
	sheetTitle = Components.label(sheet, "", {
		size = UDim2.new(1, -(Theme.ButtonHeight + GAP), 0, Theme.ButtonHeight),
		bold = true,
		textSize = 18,
	})
	sheetClose = Components.button(sheet, "✕", {
		size = UDim2.fromOffset(Theme.ButtonHeight, Theme.ButtonHeight),
		position = UDim2.fromScale(1, 0),
		anchor = Vector2.new(1, 0),
		hoverColor = Theme.Colors.Danger,
	}, closeSheet)
	sheetClose.Name = "CloseDetail"
	sheetContent = Instance.new("ScrollingFrame")
	sheetContent.Name = "DetailContent"
	sheetContent.BackgroundTransparency = 1
	sheetContent.BorderSizePixel = 0
	sheetContent.Position = UDim2.fromOffset(0, Theme.ButtonHeight + GAP)
	sheetContent.Size = UDim2.new(1, 0, 1, -(Theme.ButtonHeight + GAP))
	sheetContent.CanvasSize = UDim2.new()
	sheetContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sheetContent.ScrollBarThickness = 6
	sheetContent.ScrollingDirection = Enum.ScrollingDirection.Y
	sheetContent.Parent = sheet
	Components.list(sheetContent, GAP)

	-- ===== ที่วางป๊อปอัปดรอป (ต่ำกว่าแผงต่างๆ · สูงกว่า HUD) =====
	dropGui = Components.screen("GearDropGui", 6)

	-- เปิดแผง → วาดถ้ามีอะไรเปลี่ยนตอนปิด + โฟกัส Gamepad · ปิดแผง → ปิดแผ่นรายละเอียด
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			render(true)
			-- defer: Panels.open ตั้งโฟกัสเป็นปุ่ม ✕ หลังเปิด → รอให้เสร็จก่อนค่อยย้ายไปปุ่มแรกของแผง
			task.defer(function()
				if UserInputService.GamepadEnabled and frame.Visible then
					GuiService.SelectedObject = (if sheet.Visible then sheetFocus else nil) or firstFocus or closeButton
				end
			end)
		else
			selectedKey = nil
			sheet.Visible = false
			disarm()
		end
	end)
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateColumns)

	-- ===== ปุ่มลัด G (คีย์บอร์ด) / RB (Gamepad) · มือถือกดปุ่ม "🛠 อุปกรณ์" ใน HUD =====
	-- ✏️ เปลี่ยนปุ่มลัด: Enum.KeyCode.G / ButtonR1 (ปุ่มที่ใช้แล้ว: Q/X สกิล · U/Y อัป · C/LB ธาตุ · M/Select ตั้งค่า)
	ContextActionService:BindAction("TurretGearPanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonR1)
end

-- เริ่มฟัง Attribute จาก Server (ทางเดียวที่ UI รู้ผลคำขอ) + ของดรอปจากบอส
function GearUI.Start()
	local function onChanged()
		render(false)
	end
	for _, name in { "Gear", "GearSlots", "GearBonus", "Coins", "Element" } do
		player:GetAttributeChangedSignal(name):Connect(onChanged)
	end
	GearController.onDrops(showDrops)

	-- BossState (Server สร้าง) · บอสมา/ไป → ปุ่มใส่/ถอดเปิด/ปิด
	local state = ReplicatedStorage:WaitForChild("BossState")
	bossState = state
	state:GetAttributeChangedSignal("Active"):Connect(onChanged)
	onChanged()
end

return GearUI
