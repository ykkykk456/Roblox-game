-- แผงกาชาสกิล: ตั๋ว · ปุ่มสุ่ม · โอกาสได้แต่ละสกิล · คลังสกิล (ใช้/อัปขั้น) (เจ้าของ: Client_UI_Scripter)
-- เปิดจากปุ่มเมนู "กาชา" ใน HudUI (Panels "Gacha") · ทุกค่าแสดงจาก Attribute ที่ Server ตั้ง
-- ปุ่ม "ใช้/อัป" ที่เป็นสีจางคือบอกใบ้ว่ายังทำไม่ได้ — Server เป็นคนตัดสินจริงเสมอ
--
-- อยากปรับ:
--   ชื่อ/คำอธิบาย/โอกาสสกิล → shared/Config/Skills.luau · ขนาดการสุ่ม (1, 10) → Config/Economy.Gacha.RollSizes
--   ขนาด/ตำแหน่ง/สีของแต่ละชิ้น → ดูหมวดใน buildRow (การ์ดสกิล) และ GachaUI.Init (ส่วนบนของแผง)
--   ข้อความที่แสดงผลของสกิล → effectText
-- ⚠️ Client แค่ส่งคำขอผ่าน Controllers/SkillController · ไม่สุ่มเอง ไม่ให้ตั๋ว/สกิลเอง

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Skills = require(ReplicatedStorage.Shared.Config.Skills)
local SkillMath = require(ReplicatedStorage.Shared.Util.SkillMath)
local Components = require(script.Parent.Components)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Theme)
local SkillController = require(script.Parent.Parent.Controllers.SkillController)

local player = Players.LocalPlayer

-- ชิ้น UI ของการ์ดสกิล 1 ใบ ที่ต้องอัปเดตภายหลัง
type Row = { level: TextLabel, detail: TextLabel, equip: TextButton, upgrade: TextButton }

-- ป้าย/ปุ่มที่ render() ต้องอัปเดต (สร้างใน Init)
local ticketLabel: TextLabel
local resultLabel: TextLabel
local rollButtons: { [number]: TextButton } = {}
local rows: { [string]: Row } = {}

-- ===== อ่านข้อมูลที่ Server ส่งมา (Attribute) =====
-- สกิลที่มี: อ่าน Attribute "Skills" (ข้อความ JSON) → { [id] = { Level, Copies } } · อ่านไม่ได้ → {}
local function ownedSkills(): { [string]: any }
	local raw = player:GetAttribute("Skills")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(decoded) == "table" then decoded else {}
end

-- จำนวนตั๋วกาชา จาก Attribute "GachaTickets" (ไม่มี = 0)
local function tickets(): number
	local value = player:GetAttribute("GachaTickets")
	return if type(value) == "number" then value else 0
end

-- ===== ข้อความ + วาดหน้าจอ =====
-- สร้างข้อความอธิบายผลสกิลที่เลเวลนี้ เช่น "ยิงเร็ว ×3.00 · 5 วิ · คูลดาวน์ 30 วิ"
local function effectText(def: any, level: number): string
	local parts = {}
	if def.FireRate then
		table.insert(
			parts,
			`ยิงเร็ว ×{string.format("%.2f", SkillMath.multiplier(def.FireRate, level))}`
		)
	end
	if def.Damage then
		table.insert(parts, `ดาเมจ ×{string.format("%.2f", SkillMath.multiplier(def.Damage, level))}`)
	end
	if def.BossDamage then
		table.insert(parts, `ใส่บอส ×{string.format("%.2f", SkillMath.multiplier(def.BossDamage, level))}`)
	end
	if def.Burst then
		table.insert(parts, `นัดใหญ่ ×{math.floor(SkillMath.burst(def.Burst, level))}`)
	end
	local timing = if def.Duration > 0 then `{def.Duration} วิ · ` else ""
	return `{table.concat(parts, " · ")} · {timing}คูลดาวน์ {def.Cooldown} วิ`
end

-- อัปเดตทั้งแผงตามข้อมูลล่าสุด: ตั๋ว · ปุ่มสุ่ม (จาง = ตั๋วไม่พอ) · การ์ดสกิลทุกใบ
-- เรียกเมื่อ Attribute Skills / EquippedSkill / GachaTickets เปลี่ยน
local function render()
	local have = tickets()
	ticketLabel.Text = `🎟 ตั๋วกาชา: {have}`
	for count, button in rollButtons do
		button.TextTransparency = if have >= count then 0 else 0.5
	end

	local owned = ownedSkills()
	local equipped = player:GetAttribute("EquippedSkill")
	for id, row in rows do
		local entry = owned[id]
		local def = Skills.List[id]
		if type(entry) ~= "table" then
			row.level.Text = "🔒 ยังไม่มี"
			row.detail.Text = def.Description
			row.equip.Visible = false
			row.upgrade.Visible = false
			continue
		end
		local level = SkillMath.clampLevel(entry.Level)
		local copies = if type(entry.Copies) == "number" then entry.Copies else 0
		local need = SkillMath.copiesToUpgrade(level)
		row.level.Text = `Lv.{level}/{Skills.MaxLevel}`
		row.detail.Text = effectText(def, level)

		row.equip.Visible = true
		row.equip.Text = if equipped == id then "✔ ใช้อยู่" else "ใช้"
		row.equip.TextTransparency = if equipped == id then 0.5 else 0

		row.upgrade.Visible = true
		if need then
			row.upgrade.Text = `อัป ({copies}/{need})`
			row.upgrade.TextTransparency = if copies >= need then 0 else 0.5
		else
			row.upgrade.Text = "สูงสุด"
			row.upgrade.TextTransparency = 0.5
		end
	end
end

-- แสดงผลสุ่มล่าสุดใต้ปุ่มสุ่ม (results มาจาก Server ผ่าน SkillController.Result)
local function showResults(results: { any })
	local names = {}
	for _, result in results do
		local def = if type(result) == "table" then Skills.List[result.id] else nil
		if def then
			local tag = if result.new then " (ใหม่!)" else ""
			table.insert(names, `{SkillMath.rarity(result.id).Name}: {def.Name}{tag}`)
		end
	end
	resultLabel.Text = if #names > 0 then `ได้รับ → {table.concat(names, " · ")}` else ""
end

-- ===== การ์ดสกิล 1 ใบ =====
-- สร้างการ์ดของสกิล id ใน content (order = ลำดับในรายการ) แล้วเก็บไว้ใน rows ให้ render() อัปเดต
local function buildRow(content: Instance, id: string, order: number)
	local def = Skills.List[id]
	local rarity = SkillMath.rarity(id)

	-- กรอบการ์ด: สูง 92 พิกเซล · ขอบสีตามความหายาก (rarity.Color) หนา 2
	local card = Instance.new("Frame")
	card.Name = id
	card.BackgroundColor3 = Theme.Colors.Surface
	card.Size = UDim2.new(1, -10, 0, 92)
	card.LayoutOrder = order
	card.Parent = content
	Components.corner(card)
	Components.padding(card, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 2
	stroke.Parent = card

	-- แถวบน: ชื่อสกิล (ซ้าย 65%) · เลเวล (ขวา 35%) · แถวสอง: รายละเอียดผลสกิล (y = 24)
	Components.label(card, `{def.Name}  [{rarity.Name}]`, {
		size = UDim2.new(0.65, 0, 0, 22),
		bold = true,
		color = rarity.Color,
	})
	local level = Components.label(card, "", {
		size = UDim2.new(0.35, 0, 0, 22),
		position = UDim2.fromScale(0.65, 0),
		alignX = Enum.TextXAlignment.Right,
		textSize = 16,
	})
	local detail = Components.label(card, "", {
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 24),
		textSize = 13,
		color = Theme.Colors.TextMuted,
	})

	-- แถวปุ่ม (y = 46 · ชิดขวา): ปุ่ม "ใช้" + ปุ่ม "อัป" (สีเขียว) กว้างปุ่มละ 110 พิกเซล
	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.Position = UDim2.fromOffset(0, 46)
	buttons.Size = UDim2.new(1, 0, 0, 30)
	buttons.Parent = card
	local layout = Components.list(buttons, 8, Enum.FillDirection.Horizontal)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local equip = Components.button(
		buttons,
		"",
		{ size = UDim2.fromOffset(110, 30), textSize = 14, order = 1 },
		function()
			SkillController.equip(id)
		end
	)
	local upgrade = Components.button(buttons, "", {
		size = UDim2.fromOffset(110, 30),
		textSize = 14,
		order = 2,
		color = Theme.Colors.Accent,
		hoverColor = Theme.Colors.AccentHover,
	}, function()
		SkillController.upgrade(id)
	end)

	rows[id] = { level = level, detail = detail, equip = equip, upgrade = upgrade }
end

local GachaUI = {}

-- สร้างแผงกาชาตอนเริ่มเกม (ซ่อนไว้จนกดปุ่ม "กาชา")
-- ลำดับจากบนลงล่างในแผงกำหนดด้วย order (1 ตั๋ว → 2 ปุ่มสุ่ม → 3 ผลสุ่ม → 4 โอกาส → 5 หัวข้อ → 11+ การ์ด)
function GachaUI.Init()
	local gui = Components.screen("GachaGui", 10)
	local frame, content, closeButton = Components.panel(gui, "🎰 กาชาสกิลป้อม", Panels.close)

	-- ===== ป้ายจำนวนตั๋ว =====
	ticketLabel = Components.label(
		content,
		"",
		{ size = UDim2.new(1, -10, 0, 28), bold = true, color = Theme.Colors.Coin, order = 1 }
	)

	-- ===== ปุ่มสุ่ม (1 ปุ่มต่อค่าใน RollSizes · แบ่งความกว้างเท่ากัน) =====
	local rollRow = Instance.new("Frame")
	rollRow.BackgroundTransparency = 1
	rollRow.Size = UDim2.new(1, -10, 0, Theme.ButtonHeight)
	rollRow.LayoutOrder = 2
	rollRow.Parent = content
	Components.list(rollRow, 8, Enum.FillDirection.Horizontal)
	local sizes = Economy.Gacha.RollSizes
	for index, count in sizes do
		rollButtons[count] = Components.button(rollRow, `สุ่ม {count} ครั้ง (🎟 {count})`, {
			size = UDim2.new(1 / #sizes, -8, 1, 0),
			color = Theme.Colors.Accent,
			hoverColor = Theme.Colors.AccentHover,
			order = index,
		}, function()
			SkillController.roll(count)
		end)
	end

	-- ===== ข้อความผลสุ่มล่าสุด (สูงขยายตามข้อความ) =====
	resultLabel = Components.label(content, "", {
		size = UDim2.new(1, -10, 0, 0),
		bold = true,
		textSize = 15,
		color = Theme.Colors.Coin,
		order = 3,
	})
	resultLabel.AutomaticSize = Enum.AutomaticSize.Y
	resultLabel.TextWrapped = true
	resultLabel.TextTruncate = Enum.TextTruncate.None

	-- ===== โอกาสได้ (แสดงให้ผู้เล่นเห็นเสมอ) =====
	local oddsLines = {}
	local odds = SkillMath.odds()
	for _, id in Skills.Order do
		table.insert(oddsLines, `{Skills.List[id].Name} {string.format("%.1f", odds[id] * 100)}%`)
	end
	local oddsLabel = Components.label(content, `โอกาสได้: {table.concat(oddsLines, " · ")}`, {
		size = UDim2.new(1, -10, 0, 0),
		textSize = 13,
		color = Theme.Colors.TextMuted,
		order = 4,
	})
	oddsLabel.AutomaticSize = Enum.AutomaticSize.Y
	oddsLabel.TextWrapped = true
	oddsLabel.TextTruncate = Enum.TextTruncate.None

	-- ===== หัวข้อ + การ์ดสกิลทุกใบ (ลำดับตาม Skills.Order) =====
	Components.label(
		content,
		"สกิลของฉัน (ได้ซ้ำ = วัตถุดิบอัปขั้น)",
		{
			size = UDim2.new(1, -10, 0, 26),
			bold = true,
			order = 5,
		}
	)
	for index, id in Skills.Order do
		buildRow(content, id, 10 + index)
	end

	Panels.register("Gacha", frame, closeButton)
end

-- เริ่มฟังการเปลี่ยนแปลงจาก Server แล้ววาดหน้าจอครั้งแรก
function GachaUI.Start()
	for _, name in { "Skills", "EquippedSkill", "GachaTickets" } do
		player:GetAttributeChangedSignal(name):Connect(render)
	end
	SkillController.Result:Connect(showResults)
	render()
end

return GachaUI
