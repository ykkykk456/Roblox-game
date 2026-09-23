-- ธีมของ UI ทั้งเกม (เจ้าของ: Visual_Director) — เปลี่ยนสี/ฟอนต์ที่นี่ที่เดียว
-- [Proposed] ค่าชุดแรกสำหรับ prototype: โทนมืด + เขียวให้เข้ากับพื้นหญ้า

return table.freeze({
	Colors = table.freeze({
		Background = Color3.fromRGB(22, 24, 30),
		Surface = Color3.fromRGB(38, 42, 52),
		SurfaceHover = Color3.fromRGB(54, 59, 72),
		Accent = Color3.fromRGB(96, 186, 84),
		AccentHover = Color3.fromRGB(116, 206, 104),
		Text = Color3.fromRGB(242, 244, 248),
		TextMuted = Color3.fromRGB(160, 166, 182),
		Danger = Color3.fromRGB(214, 84, 84),
		Coin = Color3.fromRGB(255, 204, 64),
	}),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	TextSize = 18,
	TitleSize = 24,
	Corner = UDim.new(0, 12),
	Padding = 12,
	ButtonHeight = 44, -- ความสูงขั้นต่ำให้กดบนมือถือได้สบาย
	PanelTransparency = 0.05,
	TweenTime = 0.15,
})
