-- ธีมของ UI ทั้งเกม (เจ้าของ: Visual_Director) — เปลี่ยนสี/ฟอนต์ที่นี่ที่เดียว
-- [Proposed] ค่าชุดแรกสำหรับ prototype: โทนมืด + เขียวให้เข้ากับพื้นหญ้า
-- ใครใช้: UI ทุกไฟล์ (Components, HudUI, SettingsUI, GachaUI, ClassUI, CombatUI)
-- สีเขียนเป็น Color3.fromRGB(แดง, เขียว, น้ำเงิน) แต่ละค่า 0–255

return table.freeze({
	-- ===== สี =====
	Colors = table.freeze({
		-- พื้นหลังแผง/ป้าย
		Background = Color3.fromRGB(22, 24, 30),
		-- พื้นปุ่ม/ช่อง · Hover = ตอนเอาเมาส์ชี้
		Surface = Color3.fromRGB(38, 42, 52),
		SurfaceHover = Color3.fromRGB(54, 59, 72),
		-- สีเน้น (ปุ่มหลัก/หัวข้อ)
		Accent = Color3.fromRGB(96, 186, 84),
		AccentHover = Color3.fromRGB(116, 206, 104),
		-- ตัวหนังสือหลัก · Muted = ตัวหนังสือรอง (จางกว่า)
		Text = Color3.fromRGB(242, 244, 248),
		TextMuted = Color3.fromRGB(160, 166, 182),
		-- ปุ่มอันตราย (เช่น คืนค่าเริ่มต้น) · Coin = สีตัวเลขเหรียญ
		Danger = Color3.fromRGB(214, 84, 84),
		Coin = Color3.fromRGB(255, 204, 64),
	}),
	-- ===== ตัวหนังสือ =====
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	-- ขนาดตัวหนังสือปกติ / หัวข้อแผง (พิกเซล)
	TextSize = 18,
	TitleSize = 24,
	-- ===== รูปทรง =====
	-- ความโค้งมุม (พิกเซล) · มากขึ้น = มุมมนขึ้น
	Corner = UDim.new(0, 12),
	-- ระยะขอบด้านในแผง (พิกเซล)
	Padding = 12,
	ButtonHeight = 44, -- ความสูงขั้นต่ำให้กดบนมือถือได้สบาย
	-- ความโปร่งใสแผง (0 = ทึบ, 1 = ใสหมด)
	PanelTransparency = 0.05,
	-- ความเร็วแอนิเมชันปุ่ม (วินาที)
	TweenTime = 0.15,
})
