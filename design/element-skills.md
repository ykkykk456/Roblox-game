# Feature Spec — ธาตุป้อม + วิวัฒนาการ + สกิลธาตุ (2026-09-30)

สถานะ: **[Proposed]** · ตัวเลขทุกตัวเป็น `[Proposed]` (เจ้าของตัวเลข: `/roblox-economy`)

> ### ✅ สิ่งที่ทำแล้ว (2026-09-30 · ตามคำสั่งเจ้าของเกม)
> - **ทำแค่ธาตุพื้นฐาน 4 ธาตุ** (หัวข้อ 2): เลือกธาตุ · การยิงปกติ + ผลกระสุน · Passive · สกิลกด 1 อัน/ธาตุ (ปุ่ม Q / X / ปุ่มบนจอ)
> - **วิวัฒนาการ + ตื่นพลัง (หัวข้อ 3–4) = แผน — ยังไม่ทำ** · เจ้าของเกมปักวิวัฒนาการไว้ที่ **Lv.20** (ไม่ใช่ Lv.10 ตามร่างเดิม) → `Elements.EvolveLevel = 20` (ยังไม่ใช้ในโค้ด)
>   - โค้ด Server เตรียมรูปแบบสกิล Beam/Strikes/Zone/Buff + ผล ArmorBreak/Shock/BossSlamDelay/Revive/EveryNth ไว้แล้ว (ยังไม่ได้ทดสอบ · ยังไม่มีภาพฝั่ง Client)
> - **หน้าตาป้อมอัปทุก 10 เลเวล** (Lv.1/10/20/30/40/50 · `Elements.LookTiers`) — ใหญ่ขึ้น + ชิ้นเพิ่ม + แสงเรือง · แทน "ตื่นพลัง Lv.30" ในร่างเดิม
> - **ใช้โมเดลที่ปั้นเองได้**: `ServerStorage > TurretModels > <ธาตุ>_<เลเวลขั้น>` (วิธีทำ: หัวไฟล์ `src/server/Services/TurretLook.luau` + `docs/CODE_GUIDE.md`)
> - ข้อมูล: PlayerData v5 → v6 เพิ่ม `Element` (ยังไม่มี `Evolution` — เพิ่มตอนทำวิวัฒนาการ) · กาชายังไม่ถอด (อีกงาน) · `Gear` (v4) เตรียมไว้ให้ระบบอุปกรณ์ป้อม
> - เปลี่ยนธาตุ: 💰`ChangeElementCost` 5000 · ห้ามระหว่างบอส · คูลดาวน์สกิลเริ่มนับใหม่ · เลือกครั้งแรกฟรี + ใช้สกิลได้ทันที
> - Frost หน่วงทุบ (ถ้าทำในอนาคต): BossService ล็อกไว้ → โค้ดเตรียมแบบ "หน่วงผลการทุบกับป้อม" (ท่าบอสยังทุบตามเวลาเดิม) `[Proposed]`
แทนที่: `design/turret-classes.md` (คลาส Mage/Archer/Assassin/Cannon + สายธาตุ) และ **สกิลกาชา** (`Config/Skills.luau` — ลบทิ้ง)
ไฟล์ Config ที่จะสร้าง: `src/shared/Config/Elements.luau` (โครงอยู่ในหัวข้อ 5)

---

## 0. สรุปสั้นๆ สำหรับเจ้าของเกม
- ผู้เล่นใหม่เลือก **ธาตุพื้นฐาน 1 ใน 4**: 🔥 ไฟ · 💧 น้ำ · 🪨 ดิน · 🌪️ ลม → ป้อมปืนเปลี่ยนหน้าตา + วิธียิงทันที
- **Lv.10** เลือก **วิวัฒนาการ 1 ใน 2** ของธาตุตัวเอง (ล็อก) → ได้ร่างใหม่ + สกิลใหม่
- **Lv.30** **ตื่นพลัง (Awaken)** อัตโนมัติ — ร่างเดิมแต่ใหญ่/สว่างขึ้น สกิลแรงขึ้น (ไม่ต้องเลือก)
- ทุกธาตุมี **สกิลกด 1 อัน** (ปุ่มเดิม Q / จอย X / ปุ่มบนจอ) + **ความสามารถติดตัว (Passive) 1 อัน**
- รวม 12 แบบ: 4 พื้นฐาน + 8 วิวัฒนาการ

```
Fire  ──Lv.10──► Inferno (ปืนใหญ่ไฟนรก)   | Phoenix (นกเพลิง)
Water ──Lv.10──► Frost   (น้ำแข็ง)          | Prism   (ลำแสงรุ้ง)
Earth ──Lv.10──► Toxic   (ปฐพีพิษ)          | Gravity (หลุมดำ)
Wind  ──Lv.10──► Storm   (พายุสายฟ้า)       | Cyclone (ปืนกลพายุหมุน)
                        └──Lv.30──► Awaken (ทุกสาย อัตโนมัติ)
```

### ไอเดียเก่าของเจ้าของ → ไปอยู่ที่ไหน
| ไอเดียเดิม (turret-classes.md) | ตอนนี้อยู่ที่ |
|---|---|
| สายฟ้า ดาเมจต่อเนื่อง | **Storm** (Passive ช็อตต่อเนื่อง + สกิลฟ้าผ่า) |
| นักแปรธาตุ ลำแสงรุ้งใส่บอส | **Prism** (น้ำหักเหแสง = รุ้ง) |
| ลม ชาร์จแล้วรัว 5 ดอก | **Wind พื้นฐาน** (สกิล "ลมกรด 5 ดาบ") |
| Gatling ปืนกลหมุน | **Cyclone** (ลมหมุน = ลำกล้องหมุน) |
| พิษ ลดเกราะบอส | **Toxic** (ดิน+พิษ = หนองพิษ) |
| มืด หลุมดำ | **Gravity** (แรงโน้มถ่วงของดิน) |
| ไฟ บอลไฟเปลี่ยนสีตามเลเวล | **Fire / Inferno** (สีบอลไฟตามเลเวล ใช้ตาราง `FireColors` เดิม) |

---

## 1. คำศัพท์ + สูตรที่ใช้ทั้งเอกสาร
- **D** = ดาเมจต่อนัดของป้อมตามเลเวล (`TurretMath` เดิม: 10 + 5×(Lv−1)) × Friend boost · **ก่อน**คูณตัวคูณธาตุ
- **ดาเมจสกิล = ตัวเลข × D × (อัตรายิงตามเลเวล ÷ `BaseFireRate`)** `[Proposed]`
  - เหตุผล: อัตรายิงป้อมโตจาก 1 → 5.9 นัด/วิ ตั้งแต่ Lv.1 → 50 ถ้าไม่คูณ สกิลจะไร้ค่าตอนเลเวลสูง `[Inferred: จาก Combat.Turret]`
  - Config field `ScaleWithFireRate = true` (ปิดได้รายสกิล · สกิลแบบ "บัฟอัตรายิง" ตั้ง false เพราะโตเองอยู่แล้ว)
- **เป้าหมายของสกิล**: มีบอส → บอส · ไม่มีบอส → มอนตัวหน้าสุดใน **เลนตัวเอง** · ไม่มีเป้าในระยะ → กดไม่ได้ **ไม่เสียคูลดาวน์**
- **ช็อต (โดนทุบจน HP หมด)**: กดสกิลไม่ได้ · สกิลแบบ "ช่อง" (Beam, ชาร์จ, รัว) หยุดทันที · ของที่ปล่อยไปแล้ว (กระสุน/โซน/DoT) ทำงานต่อจนหมด (กฎเดิมข้อ 8) · คูลดาวน์เดินต่อ
- **บอสจากไป** = ล้างสถานะที่ติดบอสทั้งหมด (เกราะแตก, ช็อต, แช่แข็ง)

---

## 2. ธาตุพื้นฐาน 4 ธาตุ

### 2.1 การยิงปกติ + หน้าตา + Passive
| | 🔥 Fire ไฟ | 💧 Water น้ำ | 🪨 Earth ดิน | 🌪️ Wind ลม |
|---|---|---|---|---|
| ตัวตน | แรง ระเบิด เผาไหม้ | ต่อเนื่อง ฟื้นฟู ควบคุมเลน | หนัก ช้า ทนทาน | เร็ว คล่อง ทะลุ |
| กระสุน | ลูกไฟทรงกลม Ball Ø1.4 Neon ส้ม + หางไฟ (Trail) | หยดน้ำ Ball Ø0.8 Neon ฟ้า + Trail ยาว | ก้อนหินทรงกล่อง 1.6³ Slate น้ำตาล โค้งลง (arc) | ใบมีดลม Wedge บาง 0.2×1×2.5 Neon ขาวเขียวใส 0.3 |
| ความเร็ว | 90 studs/s (บินเห็น) | 140 studs/s | 70 studs/s + โค้ง 8 studs | 250 studs/s (เกือบทันที) |
| Damage × | 1.4 | 0.8 | 2.0 | 0.55 |
| FireRate × | 0.7 | 1.3 | 0.5 | 1.9 |
| DPS รวม (×) | 0.98 | 1.04 | 1.00 | 1.05 |
| ผลกับมอน | ระเบิดรัศมี 6 (โดนหลายตัว) | ช้าลง 20% 1.5 วิ | กระแทกถอย 4 studs | ทะลุได้ 2 ตัว |
| **Passive** | **เผาไหม้**: เป้าติดไฟ 0.1D/วิ 3 วิ (ยิงซ้ำ = รีเซ็ตเวลา ไม่ซ้อน) | **ชุ่มชื่น**: ป้อมฟื้น HP 2/วิ (ไม่ฟื้นตอนช็อต) | **ผิวหิน**: ดาเมจจากบอสทุบ −30% | **ตัวเบา**: เวลาช็อต −40% (6 → 3.6 วิ) |

### 2.2 หน้าตาป้อม (Parts ล้วน · สร้างด้วยโค้ดแบบ TurretLook เดิม)
| ธาตุ | ฐาน | ลำกล้อง | จุดเรืองแสง (Neon) |
|---|---|---|---|
| Fire | กล่องเตี้ยกว้าง Basalt/Slate ดำเทา | ลำกล้องครกสั้นอ้วน Cylinder Ø2.2 ยาว 3 สีเหล็กแดงเข้ม | แกนกลางลูกบาศก์ Neon ส้ม + ช่องระบายไฟ 4 ช่องข้างฐาน (Neon ส้ม/แดง) |
| Water | ฐานกลม Cylinder SmoothPlastic ขาวน้ำเงิน | ลำกล้องยาวเรียว Ø1 ยาว 5 Glass ฟ้าใส 0.4 | ลูกแก้วน้ำ Ball Ø2 Neon ฟ้าอ่อน ใส 0.3 ลอยเหนือฐาน หมุนช้า (Tween) |
| Earth | ก้อนหินกองซ้อน 3 ก้อน Slate น้ำตาล + มอสส์เขียว (Grass) | ลำกล้องหินเหลี่ยม 2×2×4 Rock | รอยแตกเส้นบาง Neon เหลืองอำพัน บนหิน |
| Wind | ฐานสามเหลี่ยมบาง (Wedge 3 ชิ้น) Metal ขาวเงิน | ลำกล้องคู่เรียวยาว Ø0.6 | ใบพัด 3 ใบ Neon เขียวมิ้นต์ หมุนรอบลำกล้องตลอด (Tween วน) |

### 2.3 สกิลกดของธาตุพื้นฐาน
| | 🔥 **ลูกไฟพัด** (Fire Volley) | 💧 **คลื่นยักษ์** (Tidal Wave) | 🪨 **หินถล่ม** (Boulder Crash) | 🌪️ **ลมกรด 5 ดาบ** (Gale Burst) |
|---|---|---|---|---|
| การยิง | ยิงลูกไฟ **5 ลูก เป็นพัด 30°** ทยอยใน 0.6 วิ (ห่างลูกละ 0.15 วิ) บิน 90 studs/s เข้าหาเป้า (พัดบีบเข้าหาเป้า ทุกลูกโดน) | กำแพงน้ำ 1 ก้อนเกิดหน้าป้อม **วิ่งตามเลนตัวเอง** ไปกลางแอ่ง 40 studs/s ชนมอนทุกตัวที่ผ่าน · ถึงปลายเลน = **ซัดบอส 1 ครั้ง** | หินยักษ์ 1 ก้อน **โยนโค้ง** (สูง 20 studs) ถึงเป้าใน 1.2 วิ · ตกแล้วเกิด **วงแรงกระแทกรัศมี 16** | **ชาร์จ 1.0 วิ** แล้วยิงใบลม **5 ดาบ ห่าง 0.12 วิ** ความเร็ว 250 studs/s ทะลุมอนทุกตัวในแนว |
| ดาเมจ | ลูกละ 2.0D (รวม 10D) + ติดเผาไหม้แรงขึ้น 0.3D/วิ 4 วิ | มอน 3D ต่อตัว · บอส 9D | บอส/เป้า 11D · มอนในวง 4D | ดาบละ 2.0D (รวม 10D) |
| สถานะ | เผาไหม้ (ไม่ซ้อน ใช้ค่าสูงสุด) | มอน: ถอย 12 studs + ช้า 40% 3 วิ · **ป้อมฟื้น HP 30** | มอน: ถอย 6 studs · **ป้อมได้เกราะหิน กันทุบ 1 ครั้ง** ภายใน 12 วิ | — |
| คูลดาวน์ | 25 วิ | 25 วิ | 30 วิ | 24 วิ |
| VFX | ลูกไฟ Neon ส้ม Ø2 + Trail แดง · ตกแล้วลูกบอล Neon ขยาย Ø2→8 จาง 0.3 วิ | Part 10×6×2 Neon ฟ้าใส 0.4 + โฟมขาวด้านบน (Part บาง Neon ขาว) · ถึงบอสแตกเป็นวง Cylinder แบน Ø20 จาง | หิน Slate 5×5×5 หมุนระหว่างบิน · วงแรงกระแทก Cylinder แบน Neon เหลืองอำพัน Ø0→32 ใน 0.4 วิ · เกราะหิน = กล่อง Slate โปร่ง 0.6 ครอบป้อม | ตอนชาร์จ: วงแหวน Neon เขียว 3 วงหมุนรอบลำกล้องเร็วขึ้นเรื่อยๆ · ใบลม Wedge Neon ขาวเขียว 0.3×2×4 + Trail |

---

## 3. วิวัฒนาการ (Evolution) — ⏸️ แผน — ยังไม่ทำ (ปักไว้ Lv.20 · ข้อความ Lv.10/Lv.30 ด้านล่างเป็นร่างเดิม)

### 3.1 กฎ
- **Lv.10**: UI เด้ง "ป้อมพร้อมวิวัฒนาการ!" ให้เลือก 1 ใน 2 · เลือกแล้ว **ล็อก** (เปลี่ยนได้โดยเปลี่ยนธาตุใหม่เท่านั้น ดูหัวข้อ 4)
  - ปิดหน้าต่างได้ · ปุ่ม "วิวัฒนาการ" ค้างบน HUD จนกว่าจะเลือก · ไม่เลือก = ยังเป็นธาตุพื้นฐานต่อไป
- **Lv.30 ตื่นพลัง (Awaken)** อัตโนมัติ: ดาเมจสกิล ×1.25 · ป้อมใหญ่ขึ้น 15% + วงแหวน Neon สีธาตุลอยรอบฐาน · สีกระสุนเข้มขึ้น
  - Fire/Inferno/Phoenix: สีบอลไฟยังเปลี่ยนตามเลเวลตามตาราง `FireColors` เดิม (10/20/30/40/50)
- วิวัฒนาการ **แทน** ค่าธาตุพื้นฐานทั้งชุด (Damage/FireRate/กระสุน/Passive/สกิล) — ไม่คูณซ้อน (เหมือน ClassMath เดิม)

### 3.2 ตารางวิวัฒนาการทั้ง 8
| id | ชื่อ | แนวคิด | กระสุนปกติ | Dmg× | Rate× | Passive | หน้าตา (เปลี่ยนจากพื้นฐาน) |
|---|---|---|---|---|---|---|---|
| `Inferno` | ปืนใหญ่ไฟนรก | ช้ามาก แรงสุด ระเบิดใหญ่ | ลูกไฟ Ø2.5 70 studs/s ระเบิดรัศมี 8 | 2.6 | 0.45 | เผาไหม้ 0.15D/วิ 4 วิ | ลำกล้องครกใหญ่ขึ้น Ø3.5 + ปล่องควัน 2 ปล่อง · ลาวา Neon ไหลตามร่องฐาน |
| `Phoenix` | นกเพลิง | คล่อง ติดตามเป้า ฟื้นคืนชีพ | ลูกไฟเล็กติดตามเป้า (homing) 110 studs/s | 1.3 | 0.9 | **คืนชีพ**: HP หมด → ฟื้น 50% ทันทีไม่ช็อต (1 ครั้ง/60 วิ) | ปีก Wedge Neon ส้ม-ทอง 2 ข้างกางจากลำกล้อง ขยับขึ้นลง (Tween) |
| `Frost` | น้ำแข็ง | ควบคุม + ช่วยทีมหน่วงบอส | เศษน้ำแข็ง Wedge 150 studs/s · มอนช้า 30% 2 วิ | 1.0 | 1.15 | **ผิวน้ำแข็ง**: ดาเมจทุบ −25% | ฐานเป็นผลึกน้ำแข็ง Glass ฟ้าอ่อน · ลำกล้องมีหนามน้ำแข็ง Wedge 4 อัน |
| `Prism` | ลำแสงรุ้ง | ยิงบอสต่อเนื่อง สายดาเมจบอส | ลำแสงสั้นทันที (hitscan) สีวนรุ้ง | 0.9 | 1.3 | **หักเห**: ทุกนัดที่ 6 แรง ×2 | ลูกแก้วกลายเป็นปริซึม (Wedge ใส) สะท้อนสีรุ้งวน (Tween สี) |
| `Toxic` | ปฐพีพิษ | ซัพพอร์ต ลดเกราะบอสให้ทั้งเซิร์ฟ | ขวดพิษ Ball เขียว โยนโค้ง 80 studs/s · ติดพิษ 0.2D/วิ 3 วิ | 1.2 | 1.0 | **กัดกร่อน**: บอสที่ติดพิษจากป้อมนี้ รับดาเมจจากทุกคน +5% | หินมีหนองพิษ Neon เขียวเดือดเป็นฟอง (Ball เล็กลอยขึ้นวนลูป) |
| `Gravity` | หลุมดำ | หนัก ดาเมจพื้นที่ต่อเนื่อง | ลูกทรงกลมดำ Ø2 (Neon ม่วงขอบ) 60 studs/s | 2.3 | 0.5 | ผิวหิน (ทุบ −30%) | หินลอยแยกชิ้นรอบลำกล้อง 4 ก้อน โคจรรอบ · แกน Neon ม่วงเข้ม |
| `Storm` | พายุสายฟ้า | ทันที ดาเมจต่อเนื่อง | สายฟ้าทันที (hitscan) · Part บางซิกแซก 3 ท่อน | 0.75 | 1.55 | **ช็อต**: เป้าโดนดาเมจต่อเนื่อง 0.15D/วิ 2 วิ (ไม่ซ้อน) | ใบพัดกลายเป็นขดลวด Tesla (Cylinder ซ้อน) + ประกาย Neon ฟ้าม่วงกะพริบ |
| `Cyclone` | ปืนกลพายุหมุน | ยิงรัวไม่หยุด | กระสุนเล็ก Ø0.3 300 studs/s | 0.35 | 3.4 | ตัวเบา+ (ช็อต −50%) | ลำกล้องเปลี่ยนเป็น 6 ลำกล้องหมุน (Gatling) หมุนตลอดเวลายิง |

---

## 4. สกิลกดของวิวัฒนาการ — ⏸️ แผน — ยังไม่ทำ

รูปแบบ: **การยิง** = สิ่งที่ Server ทำ (เวลา/จำนวน/ความเร็ว) · **VFX** = สิ่งที่ Client วาด (ผ่าน `TurretFx`)

**🔥 Inferno — "ดวงอาทิตย์ถล่ม" (Sunfall)** · คูลดาวน์ 30 วิ
- การยิง: **ชาร์จ 1.5 วิ** (ลูกไฟโตเหนือลำกล้อง) → ยิงลูกไฟยักษ์ 1 ลูก 60 studs/s ไปที่เป้า → ระเบิดรัศมี 14
- ดาเมจ: เป้าหลัก 18D · มอนในรัศมี 6D · ติดเผาไหม้ 0.6D/วิ 5 วิ
- VFX: Ball Neon สี `FireColors` ขยาย Ø2→8 ระหว่างชาร์จ + ParticleEmitter ประกาย · ระเบิด = Ball Neon Ø8→28 จาง 0.5 วิ + วงแหวนพื้น

**🔥 Phoenix — "นกเพลิงโฉบ" (Phoenix Dive)** · คูลดาวน์ 28 วิ
- การยิง: ปล่อยนกเพลิง 1 ตัว **บินตามเลนตัวเอง** 60 studs/s ไปหาบอส (ชนมอนทุกตัวที่ผ่าน) → ถึงบอสแล้ว **วนรอบบอส 3 วิ** ติก 4 ครั้ง/วิ
- ดาเมจ: มอนที่ผ่าน 5D · บอส 12 ติก × 1.33D = 16D · ติดเผาไหม้ 0.3D/วิ 3 วิ
- สถานะ: ระหว่างนกบิน ป้อมฟื้น HP 10/วิ (รวม ~30)
- VFX: ตัวนก = Wedge 2 ชิ้นเป็นปีก Neon ส้ม-ทอง กว้าง 8 + ลำตัว Ball Neon เหลือง Ø2 + Trail ไฟยาว · วนรอบบอสรัศมี 12

**💧 Frost — "หอกธารน้ำแข็ง" (Glacier Lances)** · คูลดาวน์ 28 วิ
- การยิง: หอกน้ำแข็ง **3 เล่ม ห่างกัน 0.3 วิ** 150 studs/s ไปที่เป้า · เล่มสุดท้าย **แช่แข็ง**
- ดาเมจ: เล่มละ 4.5D (รวม 13.5D)
- สถานะ: **บอส: เลื่อนการทุบครั้งถัดไปออก +3 วิ** (ช่วยทุกป้อมในเซิร์ฟ · ทั้งเซิร์ฟใช้ได้ 1 ครั้งทุก 20 วิ ครั้งที่ติดคูลดาวน์นี้ = ได้แค่ดาเมจ) · มอนในเลน: แช่แข็งหยุดเดิน 2 วิ
- VFX: หอก = Wedge ยาว 0.8×0.8×6 Glass/Neon ฟ้าขาว + Trail · บอสแช่แข็ง = กล่อง Glass ฟ้าใส 0.6 ครอบรอบเท้าบอส 3 วิ

**💧 Prism — "ลำแสงรุ้งแปรธาตุ" (Rainbow Beam)** · คูลดาวน์ 30 วิ
- การยิง: **ลำแสงต่อเนื่อง 2.5 วิ ติก 10 ครั้ง/วิ** ทันที (ไม่มีเวลาเดินทาง) ล็อกเป้าเดิม · ป้อมช็อต = ลำแสงหยุด
- ดาเมจ: ติกละ 0.7D (รวม 17.5D) · ใช้กับบอสได้ดีที่สุด (ไม่มีบอส = ยิงมอนตัวหน้าสุด ตายแล้วย้ายเป้า)
- VFX: Part ยาว From→To หนา 1.5 Neon เปลี่ยนสีวน 7 สีทุก 0.1 วิ + แกนในสีขาวหนา 0.5 · จุดโดน = Ball Neon ขาว Ø4 เต้น

**🪨 Toxic — "ขวดพิษกัดเกราะ" (Corrosion Flask)** · คูลดาวน์ 30 วิ
- การยิง: โยนขวดโค้ง ถึงเป้าใน 1.0 วิ → เกิด **บ่อพิษรัศมี 12 นาน 8 วิ** ที่ตัวเป้า
- ดาเมจ: กระแทก 3D + บ่อพิษ 0.5D/วิ ทุกเป้าในรัศมี (รวมกับบอส ~7D)
- สถานะ: **บอสเกราะแตก: ดาเมจที่บอสได้รับจากทุกผู้เล่น +20% นาน 8 วิ** (หลายคนใช้ = ไม่ซ้อน ใช้ค่าสูงสุด · Passive +5% ไม่บวกซ้อนกับสกิล) · **ผู้ใช้ได้เครดิต 50% ของดาเมจส่วนเพิ่ม** (นับเข้าตารางดาเมจ เพื่อให้สายซัพพอร์ตได้รางวัล)
- VFX: ขวด Ball Neon เขียว Ø1.5 หมุน · บ่อ = Cylinder แบน Neon เขียวใส 0.5 Ø24 + ฟอง Ball เล็กลอยขึ้น · บอสมีไฮไลต์เขียว (Highlight) ตลอดเวลาเกราะแตก

**🪨 Gravity — "หลุมดำ" (Black Hole)** · คูลดาวน์ 30 วิ
- การยิง: ยิงลูกดำ 60 studs/s → ถึงเป้าเกิด **หลุมดำรัศมี 16 นาน 4 วิ ติก 4 ครั้ง/วิ** · ต่อป้อมมีได้ 1 หลุม
- ดาเมจ: กระแทก 3D + ติกละ 0.8D ทุกเป้าในรัศมี (รวม ~15.8D ต่อเป้า)
- สถานะ: มอนในรัศมีถูกดูดเข้าหาศูนย์กลาง (ขยับตำแหน่ง 3 studs/ติก) + หยุดเดิน
- VFX: Ball Neon ดำ (Color 10,0,20) Ø6 + วงแหวน Cylinder แบน Neon ม่วง Ø32 หมุนเร็ว + หดเข้าวนซ้ำ · จบ = ยุบ Ø6→0 แล้วแฟลชม่วง

**🌪️ Storm — "พายุฟ้าคำราม" (Thunderstorm)** · คูลดาวน์ 28 วิ
- การยิง: **ฟ้าผ่า 6 ครั้ง ห่างกัน 0.5 วิ (3 วิ)** ทันที ลงที่เป้า · ทุกครั้ง **กระโดดต่อ** ไปมอนในเลนตัวเอง 2 ตัวที่ใกล้ที่สุด
- ดาเมจ: ครั้งละ 2.5D ที่เป้า (รวม 15D) · มอนที่โดนกระโดด 2D · ติดช็อต (Passive) ทุกครั้ง
- VFX: สายฟ้า = Part บาง 0.4 ซิกแซก 4 ท่อนจากฟ้า (สูง 60) ลงเป้า Neon ฟ้าม่วง อยู่ 0.12 วิ + แฟลช Ball Ø6 · เมฆเทา Part แบน 20×2×20 ลอยเหนือเป้าตลอด 3 วิ

**🌪️ Cyclone — "พายุกระสุน" (Minigun Frenzy)** · คูลดาวน์ 25 วิ
- การยิง: **อัตรายิง ×3 นาน 5 วิ** (ยิงปกติแต่ถี่ขึ้น) · ลำกล้องหมุนเร็วขึ้น
- ดาเมจ: บัฟ (ได้ประมาณ +2 × DPS ปกติ × 5 วิ ≈ 11.9D ที่ Lv.1) · `ScaleWithFireRate = false`
- สถานะ: ระหว่างบัฟ **ไม่ช็อต** (ถ้า HP หมดจะช็อตหลังบัฟจบ)
- VFX: ลำกล้องหมุน ×3 + ประกายปากกระบอก Ball Neon เหลือง Ø1 กะพริบ + วงลม Cylinder แบน Neon เขียวหมุนรอบป้อม

---

## 5. สมดุลโดยประมาณ (DPS ใส่บอส หน่วย D/วิ ที่ Lv.1) `[Proposed]` `[Inferred: คำนวณจาก Combat.luau]`
สมมติ: กดสกิลทุกครั้งที่คูลดาวน์หมด · บอสทุบทุก 10 วิ 40 ดาเมจ · HP 100 · ช็อต 6 วิ → ป้อมที่ไม่มีการป้องกันยิงได้ ~83% ของเวลา
"เวลายิงได้" ประเมินจาก Passive/สกิลป้องกัน (ประมาณ ไม่ใช่ค่าจริง ต้องทดสอบใน Studio)

| id | ยิงปกติ + Passive | สกิล (ดาเมจ ÷ คูลดาวน์) | รวม | เวลายิงได้ | **ผลจริง** | จุดเด่น |
|---|---|---|---|---|---|---|
| Fire | 0.98 + 0.10 | 11.2/25 = 0.45 | 1.53 | 83% | **1.27** | เคลียร์มอน |
| Water | 1.04 | 9/25 = 0.36 | 1.40 | 92% | **1.29** | ทนทาน+ควบคุมเลน |
| Earth | 1.00 | 11/30 = 0.37 | 1.37 | 95% | **1.30** | ทนทานสุด |
| Wind | 1.05 | 10/24 = 0.42 | 1.47 | 89% | **1.31** | เจาะแถวมอน |
| Inferno | 1.17 + 0.15 | 21/30 = 0.70 | 2.02 | 83% | **1.68** | ดาเมจระเบิดสูงสุด |
| Phoenix | 1.17 | 17/28 = 0.61 | 1.78 | 92% | **1.64** | ไม่ค่อยช็อต |
| Frost | 1.15 | 13.5/28 = 0.48 | 1.63 | 90% | **1.47** + หน่วงทุบทั้งเซิร์ฟ | ซัพพอร์ต |
| Prism | 1.17 + 0.20 | 17.5/30 = 0.58 | 1.95 | 83% | **1.62** | ยิงบอสล้วน |
| Toxic | 1.20 + 0.20 | 7/30 = 0.23 | 1.63 | 83% | **1.35** + เครดิตเกราะแตก (~+0.2–0.4 เมื่อเซิร์ฟเต็ม) | ซัพพอร์ต |
| Gravity | 1.15 | 15.8/30 = 0.53 | 1.68 | 95% | **1.60** | มอนเป็นกลุ่ม |
| Storm | 1.16 + 0.15 | 16.6/28 = 0.59 | 1.90 | 83% | **1.58** | ทันที ไม่พลาด |
| Cyclone | 1.19 | 11.9/25 = 0.48 | 1.67 | 91% | **1.52** | AFK ดี (บัฟไม่ต้องเล็ง) |

- เป้าหมาย: พื้นฐานห่างกันไม่เกิน ±5% · วิวัฒนาการ 1.45–1.70 (ซัพพอร์ตต่ำกว่าเล็กน้อยแต่ช่วยทีม) · Awaken ×1.25 เฉพาะส่วนสกิล
- AFK (ไม่กดสกิล): ทุกธาตุเหลือแค่ "ยิงปกติ + Passive" ≈ 1.0–1.4 → คนอยู่หน้าจอได้เปรียบ ~25–45% (ตรงเสาหลักข้อ 2)

---

## 6. ข้อมูล + กฎ (สำหรับ DataStore_Backend / Networking_Specialist)

### 6.1 id (ห้ามเปลี่ยนหลังเปิดเกม เพราะถูกบันทึกใน DataStore)
- ธาตุพื้นฐาน: `Fire` `Water` `Earth` `Wind`
- วิวัฒนาการ: `Inferno` `Phoenix` `Frost` `Prism` `Toxic` `Gravity` `Storm` `Cyclone`

### 6.2 สิ่งที่บันทึกต่อผู้เล่น — PlayerData v5 → v6
| field | ค่า | หมายเหตุ |
|---|---|---|
| `Element` | `""` หรือ id พื้นฐาน | `""` = ยังไม่เลือก → ยิงแบบ `Unchosen` + UI เด้งให้เลือก |
| `Evolution` | `""` หรือ id วิวัฒนาการ | ต้องเป็นของธาตุตัวเอง · Awaken ไม่ต้องบันทึก (คำนวณจาก `TurretLevel ≥ AwakenLevel`) |

- **Migration [5]**: `TurretClass`/`TurretBranch` → **รีเซ็ต** `Element = ""`, `Evolution = ""` (ผู้เล่นเลือกใหม่ฟรี) แล้วลบ field เก่า · คลาสเก่ากับธาตุใหม่เทียบกันไม่ตรง จึงไม่แมป `[Proposed]`
- ลบ `Skills`, `EquippedSkill` (สกิลกาชา) ใน migration เดียวกัน · `TurretLevel` และเงิน **ไม่แตะ**
- ผู้เล่นที่ Lv ≥ 10 อยู่แล้ว: เลือกธาตุแล้วจะเห็นปุ่มวิวัฒนาการทันที
- โหลดข้อมูลไม่สำเร็จ = ห้ามบันทึกทับ (กฎเดิม) · mirror เป็น Player Attribute `Element`, `Evolution` ผ่าน StatsService

### 6.3 กฎการเลือก/เปลี่ยน
1. เลือกธาตุครั้งแรก **ฟรี** · เลือกได้ทุกเวลา (หน้าเลือกเด้งตอนเข้าเกมถ้ายังไม่เลือก)
2. **เปลี่ยนธาตุ** = เสียเงิน `ChangeElementCost` (ค่าใน Config → `/roblox-economy`) · รีเซ็ต `Evolution = ""` · เลเวลป้อมคงเดิม · **ห้ามเปลี่ยนระหว่างบอสอยู่** (กันสลับหาของดีกลางไฟต์)
3. **วิวัฒนาการ**: `TurretLevel ≥ EvolveLevel (10)` + `Evolution == ""` + id อยู่ใน `Elements[Element].Evolutions` → ฟรี ครั้งเดียว ล็อก
4. สกิลใช้ Remote เดิม `UseTurretSkill` (ไม่มี argument) · Server ดู Element/Evolution เอง · คูลดาวน์เก็บที่ Server
5. เปลี่ยนธาตุ/วิวัฒนาการ = รีเซ็ตคูลดาวน์เป็นเต็ม (กันกดสกิลรัวด้วยการสลับ)

### 6.4 Remote (แทนของเดิม)
| ชื่อ | ทิศ | argument | ตรวจ (Guard) |
|---|---|---|---|
| `ChooseElement` | C→S | `elementId: string` | rate 3/1 วิ · อยู่ใน `Order` · ถ้ามีธาตุแล้ว = เปลี่ยน → เช็กเงิน + บอสไม่อยู่ |
| `ChooseEvolution` | C→S | `evolutionId: string` | rate 3/1 วิ · เป็นของธาตุตัวเอง · เลเวลถึง · ยังไม่มีวิวัฒนาการ |
| `UseTurretSkill` | C→S | — | เดิม · + ไม่ช็อต · คูลดาวน์หมด · มีเป้า |
| `TurretFx` | S→C | `{Kind, From, To, Color, Radius?, Duration?, Count?}` | เอฟเฟกต์ล้วน · Kind ไม่รู้จัก → Tracer |

ลบ: `ChooseTurretClass`, `ChooseTurretBranch`, `RollGacha`, `EquipSkill`, `UpgradeSkill`, `GachaResult`

---

## 7. โครง Config ที่เสนอ — `src/shared/Config/Elements.luau` `[Proposed]`
Pattern ใช้ **Kind 6 แบบ** เพื่อให้โค้ดน้อยที่สุด (ทุกสกิลสร้างจากนี้):
| Pattern.Kind | ความหมาย | field ที่ใช้ |
|---|---|---|
| `Volley` | ยิงกระสุนเป็นชุด (1 ลูกก็ได้) | Count, Spread(°), Interval, Speed หรือ TravelTime, Arc?, Charge?, Damage, Splash?, SplashDamage?, Pierce? |
| `LaneWave` | ของวิ่งตามเลนตัวเองไปหาบอส | Speed, Damage(มอน), EndDamage(บอส), EndTicks?, EndTickRate?, EndDuration? |
| `Beam` | ลำแสงทันทีต่อเนื่อง | Duration, TickRate, Damage(ต่อติก) |
| `Strikes` | โจมตีทันทีซ้ำๆ | Count, Interval, Damage, Chain?, ChainDamage? |
| `Zone` | โยนแล้วเกิดโซนที่เป้า | Speed/TravelTime, ImpactDamage, Radius, Duration, TickRate, Damage(ต่อติก), Pull? |
| `Buff` | บัฟป้อมตัวเอง | Duration, FireRate, StunImmune? |

```lua
return table.freeze({
	EvolveLevel = 10,           -- เลือกวิวัฒนาการได้
	AwakenLevel = 30,           -- ตื่นพลังอัตโนมัติ
	AwakenSkillDamage = 1.25,   -- ×ดาเมจสกิลหลังตื่นพลัง
	AwakenScale = 1.15,         -- ×ขนาดโมเดลป้อม
	ChangeElementCost = 5000,   -- เงินที่ใช้เปลี่ยนธาตุ (→ /roblox-economy)
	Order = { "Fire", "Water", "Earth", "Wind" },
	Unchosen = { Damage = 1, FireRate = 1, Fx = "Tracer", Color = Color3.fromRGB(255, 220, 90) },
	FireColors = { --[[ ย้ายมาจาก Skill_class_default เดิม ]] },

	Elements = {
		Fire = {
			Tier = "Basic", Name = "ไฟ", Description = "ลูกไฟระเบิด เผาไหม้",
			Color = Color3.fromRGB(255, 120, 40), Look = "Fire",
			Damage = 1.4, FireRate = 0.7,
			Shot = { Fx = "Fireball", Speed = 90, Size = 1.4, Splash = 6, MonsterSlow = nil, Pierce = 0, Knockback = 0, Homing = false },
			Passive = { Kind = "Burn", DotPerSecond = 0.1, Seconds = 3 },
			Evolutions = { "Inferno", "Phoenix" },
			Skill = {
				Name = "ลูกไฟพัด", Description = "ยิงลูกไฟ 5 ลูกเป็นพัด ติดไฟแรง",
				Cooldown = 25, ScaleWithFireRate = true, Fx = "Fireball",
				Pattern = { Kind = "Volley", Count = 5, Spread = 30, Interval = 0.15, Speed = 90, Damage = 2.0, Splash = 6, SplashDamage = 2.0 },
				Status = { Kind = "Burn", DotPerSecond = 0.3, Seconds = 4 },
			},
		},
		Water = {
			Tier = "Basic", Name = "น้ำ", Color = Color3.fromRGB(80, 170, 255), Look = "Water",
			Damage = 0.8, FireRate = 1.3,
			Shot = { Fx = "WaterBolt", Speed = 140, Size = 0.8, MonsterSlow = { Amount = 0.2, Seconds = 1.5 } },
			Passive = { Kind = "Regen", HpPerSecond = 2 },
			Evolutions = { "Frost", "Prism" },
			Skill = { Name = "คลื่นยักษ์", Cooldown = 25, ScaleWithFireRate = true, Fx = "Wave",
				Pattern = { Kind = "LaneWave", Speed = 40, Damage = 3, EndDamage = 9 },
				Status = { Kind = "Knockback", Studs = 12, Slow = 0.4, SlowSeconds = 3 },
				SelfHeal = 30 },
		},
		Earth = {
			Tier = "Basic", Name = "ดิน", Color = Color3.fromRGB(150, 110, 70), Look = "Earth",
			Damage = 2.0, FireRate = 0.5,
			Shot = { Fx = "Rock", Speed = 70, Arc = 8, Size = 1.6, Knockback = 4 },
			Passive = { Kind = "SlamReduce", Amount = 0.3 },
			Evolutions = { "Toxic", "Gravity" },
			Skill = { Name = "หินถล่ม", Cooldown = 30, ScaleWithFireRate = true, Fx = "Boulder",
				Pattern = { Kind = "Volley", Count = 1, TravelTime = 1.2, Arc = 20, Damage = 11, Splash = 16, SplashDamage = 4 },
				Status = { Kind = "Knockback", Studs = 6 },
				SelfShield = { Blocks = 1, Seconds = 12 } },
		},
		Wind = {
			Tier = "Basic", Name = "ลม", Color = Color3.fromRGB(170, 240, 210), Look = "Wind",
			Damage = 0.55, FireRate = 1.9,
			Shot = { Fx = "WindBlade", Speed = 250, Pierce = 2 },
			Passive = { Kind = "StunReduce", Amount = 0.4 },
			Evolutions = { "Storm", "Cyclone" },
			Skill = { Name = "ลมกรด 5 ดาบ", Cooldown = 24, ScaleWithFireRate = true, Fx = "WindBlade",
				Pattern = { Kind = "Volley", Charge = 1.0, Count = 5, Spread = 0, Interval = 0.12, Speed = 250, Damage = 2.0, Pierce = 99 } },
		},

		-- ===== วิวัฒนาการ (Tier = "Evolved", Base = ธาตุเจ้าของ) =====
		Inferno = { Tier = "Evolved", Base = "Fire", Name = "ปืนใหญ่ไฟนรก", Damage = 2.6, FireRate = 0.45,
			Shot = { Fx = "Fireball", Speed = 70, Size = 2.5, Splash = 8 }, UseFireColors = true,
			Passive = { Kind = "Burn", DotPerSecond = 0.15, Seconds = 4 },
			Skill = { Name = "ดวงอาทิตย์ถล่ม", Cooldown = 30, ScaleWithFireRate = true, Fx = "BigFireball",
				Pattern = { Kind = "Volley", Charge = 1.5, Count = 1, Speed = 60, Damage = 18, Splash = 14, SplashDamage = 6 },
				Status = { Kind = "Burn", DotPerSecond = 0.6, Seconds = 5 } } },
		Phoenix = { Tier = "Evolved", Base = "Fire", Name = "นกเพลิง", Damage = 1.3, FireRate = 0.9,
			Shot = { Fx = "Fireball", Speed = 110, Homing = true }, UseFireColors = true,
			Passive = { Kind = "Revive", HpFraction = 0.5, Cooldown = 60 },
			Skill = { Name = "นกเพลิงโฉบ", Cooldown = 28, ScaleWithFireRate = true, Fx = "Phoenix",
				Pattern = { Kind = "LaneWave", Speed = 60, Damage = 5, EndDamage = 1.33, EndTicks = 12, EndTickRate = 4 },
				Status = { Kind = "Burn", DotPerSecond = 0.3, Seconds = 3 }, SelfHealPerSecond = 10 } },
		Frost = { Tier = "Evolved", Base = "Water", Name = "น้ำแข็ง", Damage = 1.0, FireRate = 1.15,
			Shot = { Fx = "IceShard", Speed = 150, MonsterSlow = { Amount = 0.3, Seconds = 2 } },
			Passive = { Kind = "SlamReduce", Amount = 0.25 },
			Skill = { Name = "หอกธารน้ำแข็ง", Cooldown = 28, ScaleWithFireRate = true, Fx = "IceLance",
				Pattern = { Kind = "Volley", Count = 3, Spread = 0, Interval = 0.3, Speed = 150, Damage = 4.5 },
				Status = { Kind = "BossSlamDelay", Seconds = 3, ServerCooldown = 20, MonsterFreeze = 2 } } },
		Prism = { Tier = "Evolved", Base = "Water", Name = "ลำแสงรุ้ง", Damage = 0.9, FireRate = 1.3,
			Shot = { Fx = "RainbowRay", Speed = 0 }, -- 0 = ทันที
			Passive = { Kind = "EveryNth", N = 6, Multiplier = 2 },
			Skill = { Name = "ลำแสงรุ้งแปรธาตุ", Cooldown = 30, ScaleWithFireRate = true, Fx = "RainbowBeam",
				Pattern = { Kind = "Beam", Duration = 2.5, TickRate = 10, Damage = 0.7 } } },
		Toxic = { Tier = "Evolved", Base = "Earth", Name = "ปฐพีพิษ", Damage = 1.2, FireRate = 1.0,
			Shot = { Fx = "PoisonFlask", Speed = 80, Arc = 6, Dot = { DotPerSecond = 0.2, Seconds = 3 } },
			Passive = { Kind = "ArmorBreak", Amount = 0.05, Seconds = 3 },
			Skill = { Name = "ขวดพิษกัดเกราะ", Cooldown = 30, ScaleWithFireRate = true, Fx = "PoisonPool",
				Pattern = { Kind = "Zone", TravelTime = 1.0, ImpactDamage = 3, Radius = 12, Duration = 8, TickRate = 1, Damage = 0.5 },
				Status = { Kind = "ArmorBreak", Amount = 0.2, Seconds = 8, AssistCredit = 0.5 } } },
		Gravity = { Tier = "Evolved", Base = "Earth", Name = "หลุมดำ", Damage = 2.3, FireRate = 0.5,
			Shot = { Fx = "DarkOrb", Speed = 60, Size = 2 },
			Passive = { Kind = "SlamReduce", Amount = 0.3 },
			Skill = { Name = "หลุมดำ", Cooldown = 30, ScaleWithFireRate = true, Fx = "BlackHole",
				Pattern = { Kind = "Zone", Speed = 60, ImpactDamage = 3, Radius = 16, Duration = 4, TickRate = 4, Damage = 0.8, Pull = 3 } } },
		Storm = { Tier = "Evolved", Base = "Wind", Name = "พายุสายฟ้า", Damage = 0.75, FireRate = 1.55,
			Shot = { Fx = "Lightning", Speed = 0 },
			Passive = { Kind = "Shock", DotPerSecond = 0.15, Seconds = 2 },
			Skill = { Name = "พายุฟ้าคำราม", Cooldown = 28, ScaleWithFireRate = true, Fx = "Thunder",
				Pattern = { Kind = "Strikes", Count = 6, Interval = 0.5, Damage = 2.5, Chain = 2, ChainDamage = 2 } } },
		Cyclone = { Tier = "Evolved", Base = "Wind", Name = "ปืนกลพายุหมุน", Damage = 0.35, FireRate = 3.4,
			Shot = { Fx = "Gatling", Speed = 300, Size = 0.3 },
			Passive = { Kind = "StunReduce", Amount = 0.5 },
			Skill = { Name = "พายุกระสุน", Cooldown = 25, ScaleWithFireRate = false, Fx = "Frenzy",
				Pattern = { Kind = "Buff", Duration = 5, FireRate = 3, StunImmune = true } } },
	},
})
```
หมายเหตุ implement: ทุกตาราง `table.freeze` แบบไฟล์เดิม · `Look` = ชื่อฟังก์ชันสร้างโมเดลใน `TurretLook` (วิวัฒนาการใช้ id ตัวเอง) · Passive/Status.Kind ใหม่ทั้งหมด (Burn, Regen, SlamReduce, StunReduce, Revive, EveryNth, ArmorBreak, Shock, Knockback, BossSlamDelay) ต้องมีโค้ดรองรับที่ Server · Fx ใหม่ต้องมี drawer ใน `TurretController` (ไม่มี → Tracer)

---

## 8. เกณฑ์ตรวจรับ
- [ ] ผู้เล่นใหม่เห็นหน้าเลือก 4 ธาตุ · เลือกแล้วหน้าตาป้อมเปลี่ยนทันที และแยกธาตุออกด้วยตาเปล่า
- [ ] Lv < 10 ส่ง `ChooseEvolution` → ไม่มีผล · Lv ≥ 10 เลือกได้เฉพาะ 2 สายของธาตุตัวเอง ครั้งเดียว
- [ ] Lv.30 ป้อมตื่นพลังเอง (ใหญ่ขึ้น + วงแหวน) สกิลแรงขึ้น 25%
- [ ] กด Q/X/ปุ่มจอ: ทุกธาตุยิงตามรูปแบบในหัวข้อ 2.3/4 · ไม่มีเป้า = ไม่เสียคูลดาวน์ · ช็อตอยู่ = กดไม่ได้
- [ ] Toxic: ดาเมจบอสจากผู้เล่นคนอื่น +20% ระหว่างเกราะแตก (ไม่ซ้อน) · Frost: การทุบครั้งถัดไปช้าลง 3 วิ ไม่เกิน 1 ครั้ง/20 วิ
- [ ] เปลี่ยนธาตุระหว่างบอสอยู่ → ปฏิเสธ · เงินไม่พอ → ปฏิเสธ · เปลี่ยนสำเร็จ = วิวัฒนาการรีเซ็ต
- [ ] ข้อมูลเก่า v5 เข้าเกม → `Element = ""` เลือกใหม่ฟรี · เลเวล/เงินเท่าเดิม · สกิลกาชาหายไม่ error
- [ ] ส่ง id มั่ว/รัวเกิน rate → ไม่มีผล ไม่ error

---

## 9. คำถามถึงเจ้าของเกม
1. เลเวลวิวัฒนาการ **Lv.10** และตื่นพลัง **Lv.30** โอเคไหม? (หรืออยากให้ Lv.25 เป็นวิวัฒนาการขั้น 2 ที่ต้องเลือกอีกรอบ — จะเพิ่มเป็น 16 แบบ งานเยอะขึ้นมาก)
2. เปลี่ยนธาตุ: ให้เสีย **เงินในเกม** (เสนอ 5000) หรือใช้ **Robux** หรือห้ามเปลี่ยนเลย?
3. ข้อมูลเก่า (คลาส/สายเดิม) **รีเซ็ตให้เลือกใหม่ฟรี** ได้ไหม? (ตอนนี้ยังเป็น prototype จึงเสนอรีเซ็ต)
4. ลบกาชาสกิลแล้ว **ตั๋วกาชาที่บอสดรอป** จะใช้ทำอะไรแทน? (เช่น สุ่มอุปกรณ์แต่งปืน · หรือหยุดดรอปก่อน)
5. Toxic เป็นสายซัพพอร์ต: ให้ **เครดิตดาเมจ 50%** ของส่วนที่ทำให้คนอื่นตีแรงขึ้น (นับเข้าตารางอันดับ) ได้ไหม?
6. ป้อมเปลี่ยนหน้าตาตามธาตุ — ขัดกับ IDEA.md ข้อ "หน้าตาไม่เปลี่ยนตามเลเวล" ไหม? (เสนอ: เปลี่ยนตาม **ธาตุ/วิวัฒนาการ** ไม่ใช่ตามเลเวล · Awaken เป็นข้อยกเว้นเดียวที่ Lv.30)
7. กระสุนพิเศษจากของที่เก็บ (ไฟ/น้ำแข็ง/ระเบิด ใน IDEA.md) จะให้ **เข้ากับธาตุ** ไหม (เช่น ธาตุไฟใส่กระสุนไฟ = โบนัส)? หรือแยกกันไว้ก่อน
