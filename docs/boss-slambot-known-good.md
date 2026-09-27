# บอส Slambot — วิธีที่ใช้ได้แล้ว (ห้ามเปลี่ยน)

> คำสั่งเจ้าของเกม (2026-09-27): อันไหนได้แล้วให้จดไว้ จะได้ไม่ต้องหาวิธีแก้อื่น
> **ถ้าบอสออกมาได้แล้ว ห้ามแก้อะไรให้เพี้ยนไปจากเดิม ยกเว้นตอนเพิ่มท่าทาง**
> ไฟล์ที่ล็อก: `src/server/Services/BossService.luau` (ส่วนโมเดล/ข้อต่อ/วางตัว/อนิเมชัน) · `Combat.Boss` ใน `src/shared/Config/Combat.luau`
> สถานะ: commit ล่าสุดของชุดนี้ = "keep the root's own rotation" · รอผู้ใช้ยืนยันว่ายืนตรง+เต้นได้ (ถ้ายืนยันแล้ว ถือว่าล็อก)

## ขั้นตอนฝั่งผู้ใช้ที่ใช้ได้ (ยืนยัน 2026-09-27)
1. Import `boss_slambot.fbx` (Blender) → โมเดลชื่อ `boss_slambot` วางใน Workspace ได้ (เกมย้ายไป `ServerStorage/Bosses` เองตอนเริ่ม)
2. ทำท่าด้วย Motion Capture ใน Animation Editor → **Publish** (เจ้าของเดียวกับเกม) → ส่งเลข ID → ใส่ `Combat.Boss.Animations`
3. **สำรองแล้วลบ** `ServerStorage/RBX_ANIMSAVES` และ KeyframeSequence ใต้โมเดล → Ctrl+S → Play
   (ถ้าไม่ลบ ตอนเทสใน Studio จะไปหยิบไฟล์ "Automatic Save" ที่ว่าง)

## ข้อเท็จจริงของโมเดลนี้ (จาก Output ของผู้ใช้)
- ริกเป็น **AnimationConstraint 15 อัน** · Motor6D 0 · Bone 0 · มี Humanoid ที่ `boss_slambot.Humanoid`
- มี **HumanoidRootPart 2 อัน** (อันหนึ่งเป็นกล่องจาก FBX = บล็อกสีเข้ม)
- ตัวรากจริง (ที่ AnimationConstraint ต่ออยู่) **หมุนแกนมา 90°** เพราะ Blender ใช้ Z ขึ้น
- ท่า Idle = `84868529983536` (ท่าเต้น 30 วิ) โครงท่ามาตรฐาน R15 (HRP→LowerTorso→UpperTorso…)

## สิ่งที่โค้ดต้องทำ (ห้ามถอด)
| ทำอะไร | ทำไม (ถ้าถอดจะเกิดอะไร) |
|---|---|
| หาโมเดลแบบชื่อยืดหยุ่น + ค้นชิ้นส่วนทุกชั้น | ไม่งั้นหาไม่เจอ → ลูกบอลม่วง |
| ย้ายโมเดลจาก Workspace ไป ServerStorage ตอนเริ่ม | ไม่งั้นบอสโผล่ก่อนเวลา/ร่วงทะลุแมพ |
| นับ AnimationConstraint (ผ่าน Attachment) เป็นข้อต่อ | ไม่งั้นระบบสร้าง Motor6D ซ้อน → ท่าไม่ขยับ |
| เลือก HumanoidRootPart **ที่ต่อกับชิ้นอื่นมากที่สุด** เป็นตัวรากแล้วยึด (Anchored) | ยึดผิดอัน → ตัวจริงไม่ถูกยึด → **ล้ม** |
| ซ่อน HumanoidRootPart ทุกอัน · ชิ้นที่หลุดเชื่อมติด + Massless | ไม่งั้นเห็นบล็อกสีเข้ม/ถ่วงตัวเอียง |
| วางตัวและเดินด้วย `CFrame.new(ตำแหน่ง) * การหมุนเดิม` **ห้ามใช้ CFrame.lookAt** | lookAt บังคับตัวรากตั้งตรง → **บอสนอนราบ** |
| วัดเท้าจากมุมชิ้นที่มองเห็นในโลกจริง (ไม่ใช้ GetBoundingBox) + `GroundOffset` | ไม่งั้นจม/ลอย |
| ปิดสถานะ Humanoid (EvaluateStateMachine=false, PlatformStand, ปิด FallingDown/Ragdoll/Dead) | Humanoid อาจทำให้ล้ม/ตายเอง |
| เล่น Idle วนตั้งแต่เกิด (Looped) · ท่าที่ Save ใน Studio ใช้ก่อน ไม่งั้นใช้ ID · Length 0 → สลับไป ID | ไม่งั้นไม่เต้น/หยิบท่าว่าง |

## วิธีที่ลองแล้ว "ไม่ได้" (อย่ากลับไปใช้)
- สร้าง Motor6D แบบ R15 มาตรฐานทับริก AnimationConstraint → ท่าเล่นแต่ตัวไม่ขยับ
- ยึด HumanoidRootPart อันแรก/อันสุดท้ายที่เจอ → ยืนได้แป๊บเดียวแล้วล้ม
- `CFrame.lookAt` ตอนวางบอส → นอนราบ
- `GetBoundingBox` หาความสูงเท้า → จม/ลอย

## ตอนเพิ่มท่า (อนุญาตให้แก้)
- เพิ่มแค่เลข ID ใน `Combat.Boss.Animations` (Walk / Slam) · ท่า Slam ใส่ Marker `Hit`
- ห้ามแตะส่วนหา/ยึดตัวราก/วางตัว/ข้อต่อ ถ้าไม่จำเป็นกับท่าใหม่

## บอสหลายตัว (Rotation) — เพิ่ม 2026-09-27
- `Combat.Boss.Rotation` = ลำดับบอสที่สลับกันเกิด วนซ้ำ: `Boss_rabbit` (Animate = false) → `boss_slambot` (Animate = true)
- ทุกตัวใช้ขั้นตอนเดียวกับโรบอท: หาโมเดลชื่อยืดหยุ่น · ย้ายจาก Workspace ไป ServerStorage/Bosses ตอนเริ่ม · เลือก HumanoidRootPart ที่ต่อมากสุดแล้วยึด · คงการหมุนเดิม · วัดเท้า · ปิดสถานะ Humanoid
- `Animate = false` → ไม่โหลดท่า ไม่สร้าง Motor6D (เชื่อมชิ้นที่หลุดอย่างเดียว) → ยืนเฉย
- โรบอทยังทำงานแบบเดิมทุกขั้น (ล็อก)
- เพิ่มบอสตัวใหม่ = เพิ่มแถวใน Rotation + วางโมเดลชื่อตรงใน Studio
- บอสแต่ละตัวมีท่าของตัวเองได้: ใส่ `Animations = { Idle, Walk, Slam }` ในแถว Rotation · ไม่ใส่ = ใช้ `Combat.Boss.Animations` (ท่าโรบอท)
- กระต่าย (2026-09-27): `Animate = true` · Idle = `99370436873239` (Motion Capture) · ใช้ขั้นตอนเดียวกับโรบอททุกขั้น
