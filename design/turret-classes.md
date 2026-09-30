# Feature Spec — คลาสป้อมเริ่มต้น + สายธาตุ (2026-09-28)

> ⛔ **เลิกใช้แล้ว (2026-09-30)** — ถูกแทนด้วย `design/element-skills.md` (ธาตุป้อม 🔥💧🪨🌪️)
> โค้ดเดิม (`Skill_class_default.luau`, `ClassMath`, `TurretClassService`, `TurretClassHandler`, `ClassUI`, `ClassController`,
> Remote `ChooseTurretClass` / `ChooseTurretBranch`) ถูกลบแล้ว · ข้อมูลผู้เล่น `TurretClass`/`TurretBranch` ถูก migrate (PlayerData v5 → v6)
> เป็น `Element = ""` (ผู้เล่นเลือกธาตุใหม่ฟรี) · เก็บไฟล์นี้ไว้อ้างอิงไอเดียเก่าเท่านั้น

ค่าทั้งหมด: `src/shared/Config/Skill_class_default.luau` (แยกจากสกิลกาชา `Config/Skills.luau` — ทั้งสองระบบทำงานซ้อนกัน)
สถานะ: [Proposed] prototype · ยังไม่ได้ทดสอบใน Studio · รอเอกสารระบบธาตุฉบับเต็มจากผู้ใช้

## กฎของระบบ (Systems_Designer)
1. ป้อมเป็นป้อมปืน ไม่ใช่คน · ผู้เล่น 1 คน = ป้อม 1 ตัว วางที่แท่น Tag `TurretN` เหมือนเดิม (LayoutService)
2. คลาสเริ่มต้น 4 คลาส: นักเวท `Mage` · นักธนู `Archer` · นักฆ่า `Assassin` · ปืนใหญ่ `Cannon` · แต่ละคลาสมีหน้าตาป้อมต่างกัน (สร้างด้วยโค้ด)
3. ผู้เล่นใหม่/ข้อมูลเก่า: `TurretClass = ""` → ป้อมยิงแบบ `Unchosen` และ UI เด้งให้เลือกคลาส
4. เปลี่ยนคลาสได้ฟรีตราบใดที่ยังไม่เลือกสายธาตุ [Proposed] · เลือกสายแล้ว = ล็อก (ระบบรีเซ็ตทำทีหลัง)
5. `TurretLevel ≥ BranchLevel` และยังไม่มีสาย → เลือกสายธาตุได้ 1 สายจาก `Classes[c].Branches`
   - นักเวท: สายฟ้า (ดาเมจต่อเนื่อง) / นักแปรธาตุ (ลำแสงรุ้ง แรงใส่บอส)
   - นักธนู: ลม (ชาร์จแล้วรัว 5 ดอก) / Gatling (ป้อมเปลี่ยนร่างเป็นปืนกลหมุน)
   - นักฆ่า: พิษ (ลดเกราะบอส ทุกป้อมตีบอสแรงขึ้น) / มืด (หลุมดำที่ตัวบอส ดาเมจต่อเนื่องในรัศมี)
   - ปืนใหญ่: ไฟ สายเดียว · การเติบโต = สีบอลไฟตาม `FireColors`
6. ดาเมจ/อัตรายิง = สูตรป้อมเดิม (TurretMath) × ตัวคูณคลาส/สาย × สกิลกาชา × Friend boost · Server คำนวณทั้งหมด
7. บอสไม่มีเลือด: ดาเมจนับเข้า `BossService.damage` เหมือนเดิม (รางวัลตามดาเมจ) · ลดเกราะ = คูณดาเมจที่บอสได้รับจากทุกผู้เล่น
8. ป้อมช็อต (โดนทุบ) = หยุดยิงและหยุดชาร์จ · DoT/หลุมดำที่ปล่อยไปแล้วทำงานต่อจนหมดเวลา · บอสจากไป = ล้าง effect ที่ติดบอส

## ข้อมูล (DataStore_Backend)
PlayerData v4 → v5: `TurretClass = ""`, `TurretBranch = ""` · migration [4] · mirror เป็น Player Attribute ผ่าน StatsService

## Remote (Networking_Specialist)
| ชื่อ | ทิศ | argument | ตรวจ |
|---|---|---|---|
| `ChooseTurretClass` | C→S | `classId: string` | Guard rate 3/1s · มีใน `Classes` · ยังไม่มีสาย |
| `ChooseTurretBranch` | C→S | `branchId: string` | Guard rate 3/1s · มีใน `Branches` · เป็นของคลาสตัวเอง · เลเวลถึง · ยังไม่มีสาย |
| `TurretFx` | S→C | `{ {Kind, From, To, Color, Radius?, Duration?} }` | เอฟเฟกต์ล้วน (แทน `TurretFired` เดิม) |

`Kind` = ค่า `Fx` ใน Config: `Tracer Bolt Arrow Dagger Shell Lightning Beam Wind Gatling Poison BlackHole Fireball` (Kind ที่ไม่รู้จัก → วาดเป็น Tracer)
`BlackHole` ส่ง `To` = จุดหลุม, `Radius`, `Duration` · อื่นๆ ส่งเส้นทาง From→To

## ไฟล์ (Architecture_Lead)
- shared: `Config/Skill_class_default.luau` · `Util/ClassMath.luau` (ฟังก์ชันบริสุทธิ์: สถิติรวม, สีไฟ, ตรวจสิทธิ์เลือก)
- server: `Services/TurretClassService.luau` (เลือกคลาส/สาย + effect ต่อเนื่อง: DoT, ลดเกราะ, หลุมดำ, ชาร์จลม) · `Services/TurretLook.luau` (สร้างหน้าตาป้อมตามคลาส/สาย) · `Network/TurretClassHandler.luau` · แก้ `TurretService`, `PlayerData`, `StatsService`, `Remotes`
- client: `Controllers/ClassController.luau` · `UI/ClassUI.luau` · แก้ `TurretController` (วาด TurretFx)

## เกณฑ์ตรวจรับ
- [ ] เข้าเกมครั้งแรก เห็นหน้าเลือก 4 คลาส · เลือกแล้วหน้าตาป้อมที่แท่น TurretN เปลี่ยนทันที
- [ ] แต่ละคลาสหน้าตาต่างกันชัดเจน · Gatling เปลี่ยนร่างเป็นปืนกลหมุน
- [ ] เลเวล < 10 ส่งเลือกสาย → Server ปฏิเสธ · เลเวล ≥ 10 เลือกได้เฉพาะสายของคลาสตัวเอง ครั้งเดียว
- [ ] ส่ง classId/branchId มั่ว หรือรัวเกิน rate → ไม่มีผล ไม่ error
- [ ] สายฟ้า: เป้าโดนดาเมจต่อเนื่อง 3 วิ · หลุมดำ: ดาเมจทุกเป้าในรัศมี 4 วิ · พิษ: ดาเมจบอสจากผู้เล่นอื่นเพิ่ม 25% ระหว่างติดพิษ
- [ ] ลม: ชาร์จ ~2.5 วิ แล้วยิงรัว 5 ดอก · ปืนใหญ่/ไฟ: ยิงช้าแต่แรงสุด · สีบอลไฟเปลี่ยนที่เลเวล 20/30/40/50
- [ ] ออกเกมแล้วเข้าใหม่ คลาส/สายยังอยู่ · โหลดข้อมูลไม่สำเร็จ = ไม่บันทึกทับ
- [ ] สกิลกาชา (Q) ยังทำงานเหมือนเดิมบนทุกคลาส
