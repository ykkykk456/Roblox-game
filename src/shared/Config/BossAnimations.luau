-- AnimationId ของบอสแต่ละตัว (เจ้าของ: Animator / World_Builder)
-- วิธีใช้: Publish ท่าใน Animation Editor → คัดลอกเลข ID มาวางแทน 0 → บอสใน Studio ตั้ง Attribute BossId ให้ตรงกับชื่อแถว
-- บอสตัวใหม่ = เพิ่มแถวใหม่ · ท่าใหม่ = เพิ่มชื่อท่าในแถว แล้วสั่ง BossAnimationService.PlayAction(model, "ชื่อท่า")
-- ID ที่ยังเป็น 0 จะถูกข้าม (warn ครั้งเดียว) ไม่ทำให้เกมพัง
--
-- Loop และ Priority ตั้งใน Animation Editor ก่อน Publish:
--   Idle, Walk = Looped · Idle → Priority Idle · Walk → Movement · Attack/Hit/Death → Action
-- ท่าต้อง Publish ภายใต้เจ้าของเดียวกับเกม (User หรือ Group เดียวกัน) ไม่งั้นเล่นไม่ได้ [Verified]

return table.freeze({
	Boss1 = table.freeze({
		Idle = "rbxassetid://0",
		Walk = "rbxassetid://0",
		Attack = "rbxassetid://0",
		Hit = "rbxassetid://0",
		Death = "rbxassetid://0",
	}),
})
