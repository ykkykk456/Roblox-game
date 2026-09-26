-- ทะเบียนชื่อ CollectionService tag ที่ใช้เชื่อม "ชิ้นในแมพ" กับโค้ด (เจ้าของ: World_Builder)
-- เพิ่ม tag ใหม่ที่นี่ก่อน แล้วค่อยไปติด tag ให้ชิ้นส่วนใน Studio (Tag Editor ในแท็บ Properties > Tags)
-- โค้ดอ้างอิงผ่าน Tags.X เสมอ ห้ามพิมพ์ชื่อ tag เป็นข้อความตรงๆ
-- ชิ้นในฐานมี Attribute "BaseSlot" (number) บอกว่าเป็นของฐานไหน

return table.freeze({
	-- สร้างโดย MapService (ยังไม่มีระบบอ่าน · รอ /roblox-feature)
	LootZone = "LootZone", -- บล็อกในแอ่งกลางแมพ = ที่เก็บของ (MapService ติดให้บล็อก Pit_* ของ MapGround)
	MonsterYard = "MonsterYard", -- สวนหลังบ้านที่มอนเกิด
	SellPad = "SellPad", -- แผ่นขายของ
	AmmoCrate = "AmmoCrate", -- ลังเติมกระสุนพิเศษ
	UpgradeBoard = "UpgradeBoard", -- ป้ายอัปเกรดตัวเอง
	SummonAltar = "SummonAltar", -- จุดส่งของเรียกบอสพิเศษ

	-- ติดมือใน Studio (BossAnimationService อ่าน)
	Boss = "Boss", -- Model บอส · ต้องมี Attribute BossId ตรงกับชื่อใน Config/BossAnimations.luau
})
