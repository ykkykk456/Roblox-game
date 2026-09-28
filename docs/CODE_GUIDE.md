# คู่มือแก้โค้ดเอง — "อยากแก้ X → ไปไฟล์ไหน"

อ่านไฟล์นี้ก่อนแก้อะไรก็ตาม · ทุกไฟล์ใน `src/` มีคอมเมนต์ภาษาไทยอธิบายหัวไฟล์ / ฟังก์ชัน / ค่าที่ปรับได้แล้ว

## กติกา 5 ข้อก่อนแก้
1. **ตัวเลขเกม (ดาเมจ ราคา เวลา ขนาด) แก้ที่ `src/shared/Config/` ก่อนเสมอ** — ส่วนใหญ่ไม่ต้องแตะโค้ดเลย
2. แก้แล้ว **Save ไฟล์** → `rojo serve` จะส่งเข้า Studio เอง → กด Play ทดสอบ (หยุดเกมก่อน sync)
3. ไฟล์นอก `src/server` · `src/shared` · `src/client` **ไม่เข้าเกม**
4. **ห้ามแก้** โค้ดบอส Slambot ใน `BossService.luau` ให้เพี้ยน (ดู `docs/boss-slambot-known-good.md`) · ปรับตัวเลขบอสใน `Config/Combat.luau` ได้
5. แก้ `DEFAULT` ใน `PlayerData.luau` (ข้อมูลที่เซฟ) = ต้องเพิ่ม `VERSION` + migration ไม่งั้นเซฟผู้เล่นพัง → ให้ Claude ทำ

## อยากแก้... → ไปที่

| อยากแก้ | ไฟล์ | ค่า/จุด |
|---|---|---|
| ดาเมจ / อัตรายิง / ระยะยิงพื้นฐานของป้อม | `src/shared/Config/Combat.luau` | `Turret.BaseDamage` `DamagePerLevel` `BaseFireRate` `FireRatePerLevel` `Range` `MaxLevel` |
| เลือดป้อม / เวลาช็อต | `Config/Combat.luau` | `Turret.MaxHp` `StunSeconds` |
| **คลาสป้อม** (ตัวคูณดาเมจ/ยิงเร็ว, ชื่อ, คำอธิบาย, สี) | `src/shared/Config/Skill_class_default.luau` | `Classes.<คลาส>` |
| **สายธาตุ** (สายฟ้า ลม พิษ ฯลฯ) + ความสามารถพิเศษ | `Config/Skill_class_default.luau` | `Branches.<สาย>` + `Effect` |
| เลเวลที่ปลดล็อกสายธาตุ | `Config/Skill_class_default.luau` | `BranchLevel` |
| สีบอลไฟตามเลเวล (ปืนใหญ่) | `Config/Skill_class_default.luau` | `FireColors` |
| หน้าตาป้อมแต่ละคลาส (ชิ้นส่วน ขนาด สี) | `src/server/Services/TurretLook.luau` | ฟังก์ชันสร้างของแต่ละคลาส |
| เอฟเฟกต์กระสุน/ลำแสง/หลุมดำ (ที่เห็นบนจอ) | `src/client/Controllers/TurretController.luau` | ฟังก์ชันวาดตาม `Kind` |
| หน้าเลือกคลาส (ปุ่ม ตำแหน่ง ข้อความ) · ปุ่มลัด C | `src/client/UI/ClassUI.luau` | |
| สกิลกาชา (รายชื่อ ผล คูลดาวน์ โอกาสสุ่ม) | `src/shared/Config/Skills.luau` | `List` `Rarities` |
| ราคาอัปป้อม · เงินจากมอน · รางวัลบอส · ตั๋วกาชา | `src/shared/Config/Economy.luau` | `Turret` `MonsterReward` `Boss` `Gacha` |
| มอน (จำนวนต่อ wave, เลือด, ความเร็ว, เวลาพัก) | `Config/Combat.luau` | `Monster.*` |
| บอส (เวลาอยู่, ช่วงเวลามา, ลำดับสลับ, ท่า Animation ID, ทุบ) | `Config/Combat.luau` | `Boss.*` (`Rotation`, `Animations`, `Duration`, `SlamDamage`) |
| ตำแหน่งบอส / ป้อม / บ้าน | **ใน Studio** ติด Tag `BossSpawn` `Turret1..6` `House1..6` | ชื่อ Tag อยู่ `Config/Tags.luau` |
| เลนมอน / ระยะเกิด | `src/shared/Config/Map.luau` | `Layout.*` `Lane.*` |
| หน้าจอ HUD เงิน / แถบบอส / ปุ่มอัป-สกิล | `src/client/UI/HudUI.luau` · `CombatUI.luau` | |
| หน้ากาชา | `src/client/UI/GachaUI.luau` | |
| สี/ฟอนต์ UI ทั้งเกม | `src/client/UI/Theme.luau` | |

## ระบบทำงานยังไง (ภาพรวม)
```
ผู้เล่นกดปุ่ม (Client)  ──ส่ง "ขอ"──▶  Network/*Handler (ตรวจด้วย Guard)  ──▶  Services/* (คำนวณจริง)
                                                                                  │
หน้าจอ/เอฟเฟกต์ (Client)  ◀── Player Attribute / Remote ───────────────────────────┘
```
- **Server** (`src/server`) = ความจริงทั้งหมด: เงิน ดาเมจ เลเวล เซฟข้อมูล
- **Shared** (`src/shared`) = ค่าตั้ง + สูตรคำนวณ ที่ทั้งสองฝั่งอ่าน (ผู้เล่นอ่านได้ → ห้ามมีความลับ)
- **Client** (`src/client`) = ปุ่ม หน้าจอ เอฟเฟกต์ เท่านั้น — แก้ที่ Client ไม่ทำให้ได้เงิน/ดาเมจเพิ่ม

## ไฟล์ฝั่ง Server หลักๆ
| ไฟล์ | ทำอะไร |
|---|---|
| `Services/TurretService.luau` | ป้อม: สร้าง · เล็ง · ยิง · อัปเลเวล · ใช้สกิล · เลือดป้อม |
| `Services/TurretClassService.luau` | เลือกคลาส/สาย · ดาเมจต่อเนื่อง · ลดเกราะ · หลุมดำ |
| `Services/TurretLook.luau` | หน้าตาป้อมตามคลาส |
| `Services/BossService.luau` | บอส (🔒 ล็อก) |
| `Services/MonsterService.luau` | มอนเป็น wave ตามเลน |
| `Services/LayoutService.luau` | อ่านตำแหน่งจาก Tag ในแมพ |
| `Services/MapService.luau` | สร้าง/ล็อกแมพ · จุดเกิด |
| `Services/SkillService.luau` | กาชา · คลังสกิล · คูลดาวน์ |
| `Data/PlayerData.luau` | เซฟ/โหลดข้อมูลผู้เล่น (ระวัง!) |
| `Network/Guard.luau` | ด่านตรวจทุกคำขอจากผู้เล่น (กันโกง) |

## เพิ่มของใหม่
- **ไฟล์ใหม่**: วางใน `Services/` (Server) หรือ `Controllers/` / `UI/` (Client) ได้เลย ระบบโหลดให้อัตโนมัติ · ต้อง `return { Init = ..., Start = ... }`
- **ปุ่มใหม่ที่ส่งคำขอถึง Server**: ต้องเพิ่ม Remote ใน `src/shared/Remotes.luau` + รับผ่าน `Guard` ใน `src/server/Network/` → ให้ Claude ทำด้วย `/roblox-feature` ปลอดภัยกว่า

## ตรวจว่าแก้แค่คอมเมนต์
`python3 tools/check_comments_only.py` — ใช้หลังแก้คอมเมนต์ ถ้าเผลอแก้โค้ดจะบอกบรรทัดที่เปลี่ยน
