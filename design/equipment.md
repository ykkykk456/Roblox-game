# Feature Spec — อุปกรณ์ป้อม (Turret Equipment) (2026-09-30)

สถานะ: **[Proposed]** · ตัวเลขทุกตัวเป็น `[Proposed]` (เจ้าของตัวเลข: `/roblox-economy`) · โค้ดฝั่ง Server/Shared/Data ทำแล้ว 2026-09-30 (UI อุปกรณ์ยังไม่ทำ · ดูหัวข้อ 14)
บทบาทผู้เขียน: Systems_Designer (กฎ) + Economy_Designer (ตัวเลข)
แทนที่: **กาชาสกิล + ตั๋วกาชา** (ถอดออกตามคำสั่งเจ้าของเกม) · ใช้ field เดิม `Gear` (PlayerData v4) ต่อ
ไฟล์ Config ที่จะสร้าง: `src/shared/Config/Equipment.luau` (โครงอยู่หัวข้อ 9)

---

## 0. สรุปสั้นๆ สำหรับเจ้าของเกม
- บอสจากไป → ทุกคนที่ตีได้ **อุปกรณ์ป้อม** (แทนตั๋วกาชา) · ตีมาก/ติดท็อป = ได้หลายชิ้น + ของหายากขึ้น
- ป้อมมี **4 ช่อง**: 🔫 ลำกล้อง · ⚙️ กลไกยิง · 🔮 แกนพลัง · 🛡️ เกราะ · เริ่มเปิด 2 ช่อง อีก 2 ช่อง **ซื้อด้วยเหรียญ**
- ระดับ 4 ขั้น: ⚪ Common · 🔵 Rare · 🟣 Epic · 🟡 Legendary
- อุปกรณ์ส่วนใหญ่มี **ธาตุ** (🔥💧🪨🌪️) → ใส่ตรงกับธาตุป้อม = ได้ **โบนัสธาตุตรง** เพิ่ม · มีแบบ **กลาง (ไม่มีธาตุ)** ค่าหลักสูงกว่าเล็กน้อยแต่ไม่มีโบนัส
- ของซ้ำ: **ย่อยเป็นเหรียญ** หรือ **รวม 3 ชิ้นเหมือนกัน → 1 ชิ้นระดับถัดไป**
- ใส่อุปกรณ์แล้ว **ป้อมมีชิ้นส่วนเพิ่ม/สีเปลี่ยน** ตามช่องและระดับ (ตรงกับ IDEA: "หน้าตาเปลี่ยนตามอุปกรณ์")
- ไม่ขายอุปกรณ์ด้วย Robux และไม่มีการสุ่มที่ใช้ Robux ในสเปกนี้ (เลี่ยงนโยบายกล่องสุ่ม) `[Proposed]`

### จุดที่ต่างจาก IDEA.md (ต้องให้เจ้าของอนุมัติแก้ IDEA.md — เอกสารนี้ไม่ได้แก้)
| IDEA.md เดิม | สเปกนี้ | เหตุผล |
|---|---|---|
| 5 ระดับ (ธรรมดา·ดี·หายาก·มหากาพย์·ตำนาน) | 4 ระดับ | เจ้าของสั่ง 2026-09-30 |
| ช่อง "ศูนย์เล็ง (คริ)" | ช่อง "เกราะ" (HP/ช็อต) | เกมยังไม่มีระบบคริ · รายการค่าสถานะที่ตกลงไม่มีคริ |
| ช่อง "แกนพลัง (ผลพิเศษ)" | แกนพลัง = สกิล (คูลดาวน์/ดาเมจสกิล) | ผูกกับสกิลธาตุที่มีแล้ว |
| แลกเปลี่ยน/ส่งให้คนอื่นได้ | **ยังไม่ทำ** (เฟสหลัง) | IDEA เองบอกเสี่ยงของซ้ำ ต้องมี session lock ก่อน |
| ดรอป: อุปกรณ์ + ตั๋วกาชา | อุปกรณ์อย่างเดียว | ถอดกาชา |

---

## 1. ช่อง (Slot)

| ช่อง | id | ค่าหลัก (ทุกชิ้นในช่องนี้มี) | เปิดยังไง |
|---|---|---|---|
| 🔫 ลำกล้อง | `Barrel` | ดาเมจ +% | เปิดตั้งแต่เริ่ม |
| ⚙️ กลไกยิง | `Mechanism` | อัตรายิง +% | เปิดตั้งแต่เริ่ม |
| 🔮 แกนพลัง | `Core` | คูลดาวน์สกิล −% | 💰 **2,500** |
| 🛡️ เกราะ | `Plating` | เลือดป้อม +% | 💰 **15,000** |

- เริ่ม **2 ช่อง** · สูงสุด **4 ช่อง** · ปลดล็อก **ตามลำดับ** (Core ก่อน Plating) กดซื้อทีละช่อง `[Proposed]`
- 1 ช่องใส่ได้ 1 ชิ้น และต้องเป็นชิ้นของช่องนั้นเท่านั้น
- เทียบราคา: 2,500 ≈ ค่าอัปป้อม Lv.1→11 รวม (2,829) · 15,000 ≈ รวม Lv.1→15 (14,540) → ผู้เล่นใหม่เปิดช่อง 3 ได้ภายในชั่วโมงแรก ช่อง 4 เป็นเป้าระยะกลาง `[Inferred: จากสูตร TurretMath.upgradeCost 25 × 1.5^(Lv−1)]`

---

## 2. ค่าสถานะ (มีแค่ 8 ชนิด)

| id | ชื่อบน UI | ผลจริง | เพดานรวม |
|---|---|---|---|
| `Damage` | ดาเมจ +% | คูณ D (ดาเมจต่อนัด · มีผลกับสกิลด้วยเพราะสกิลใช้ D) | — |
| `FireRate` | อัตรายิง +% | คูณอัตรายิงปกติ (ไม่คูณในสูตรดาเมจสกิล กันนับซ้ำ) | — |
| `BossDamage` | ดาเมจบอส +% | คูณดาเมจที่ลงบอสเท่านั้น (ยิง + สกิล) | 50% |
| `SkillCooldown` | คูลดาวน์สกิล −% | คูณคูลดาวน์สกิลธาตุ | 40% |
| `SkillDamage` | ดาเมจสกิล +% | คูณ D ที่ส่งให้สกิล | — |
| `TurretHp` | เลือดป้อม +% | คูณ `Combat.Turret.MaxHp` | 100% |
| `StunReduce` | เวลาช็อต −% | บวกกับ Passive ลม (ตัวเบา 40%) แล้วบีบเพดาน | 70% (รวม Passive) |
| `ElementMatch` | โบนัสธาตุตรง | ไม่ใช่ค่าแยก: เปิด "ค่ารอง" ของชิ้นธาตุเมื่อธาตุชิ้น = ธาตุป้อม | — |

การรวม: ทุกชิ้นที่ใส่ **บวกกัน** ต่อชนิด แล้วคูณครั้งเดียว เช่น ดาเมจ +14% +3% = ×1.17 (ไม่คูณทบ) `[Proposed]`

---

## 3. รายการอุปกรณ์ (4 ช่อง × 5 แบบ = 20 ชิ้น × 4 ระดับ)

แต่ละช่องมี 5 แบบ: 🔥 Fire · 💧 Water · 🪨 Earth · 🌪️ Wind · ⚙️ Neutral (กลาง)
id ชิ้น = `<ช่อง>_<แบบ>` เช่น `Barrel_Fire` · id ในกระเป๋า = `<ช่อง>_<แบบ>_<ระดับ>` เช่น `Barrel_Fire_Rare`

### 3.1 ค่าหลักตามระดับ (ชิ้นธาตุ ×1.0 · ชิ้นกลาง ×1.25 ปัดขึ้น)
| ช่อง · ค่าหลัก | ⚪ Common | 🔵 Rare | 🟣 Epic | 🟡 Legendary | กลาง (C/R/E/L) |
|---|---|---|---|---|---|
| Barrel · ดาเมจ +% | 4 | 8 | 14 | 22 | 5 / 10 / 18 / 28 |
| Mechanism · อัตรายิง +% | 3 | 6 | 10 | 16 | 4 / 8 / 13 / 20 |
| Core · คูลดาวน์สกิล −% | 3 | 6 | 10 | 15 | 4 / 8 / 13 / 19 |
| Plating · เลือดป้อม +% | 10 | 20 | 35 | 50 | 13 / 25 / 44 / 63 |

### 3.2 โบนัสธาตุตรง (ค่ารอง ทำงานเมื่อธาตุชิ้น = ธาตุป้อม เท่านั้น)
ธาตุเดียวกันให้ค่ารองชนิดเดียวกันทุกช่อง (จำง่าย: "ไฟ = สกิลแรง")
| ธาตุ | ค่ารอง | เหตุผล (เข้ากับ Passive/สกิลเดิม) | C | R | E | L |
|---|---|---|---|---|---|---|
| 🔥 ไฟ | ดาเมจสกิล +% | ระเบิดแรง (ลูกไฟพัด) | 5 | 10 | 16 | 25 |
| 💧 น้ำ | เลือดป้อม +% | ฟื้นฟู/ยืนระยะ | 8 | 15 | 25 | 40 |
| 🪨 ดิน | ดาเมจบอส +% | หนัก ทนทุบ สู้บอส | 3 | 6 | 10 | 15 |
| 🌪️ ลม | เวลาช็อต −% | ตัวเบา (ต่อยอด Passive) | 5 | 8 | 12 | 16 |

- **ชุดธาตุ**: ใส่ชิ้นธาตุตรงครบ 4 ช่อง → ดาเมจ **+5%** เพิ่ม `[Proposed]`
- ป้อมยังไม่เลือกธาตุ / เปลี่ยนธาตุ → ชิ้นธาตุเหลือแค่ค่าหลัก (ไม่หาย ไม่ต้องถอด) · UI ขึ้นป้าย "ธาตุไม่ตรง"
- ทางเลือกที่ชัด: **ชิ้นกลาง** ค่าหลักสูงกว่า 25% (ปลอดภัยเวลาเปลี่ยนธาตุ) vs **ชิ้นธาตุตรง** ค่ารวมสูงกว่า

### 3.3 ชื่อ + หน้าตาบนป้อม
| ชิ้น | ชื่อไทย | หน้าตาบนป้อม (Parts ล้วน ต่อจากชิ้นของ `TurretLook`) |
|---|---|---|
| Barrel_Fire | ลำกล้องลาวา | ปลอกหุ้มลำกล้อง (Cylinder สั้น) + วงแหวน Neon ส้มที่ปากกระบอก |
| Barrel_Water | ลำกล้องธารา | ปลอกใส Glass ฟ้า + วงแหวน Neon ฟ้า |
| Barrel_Earth | ลำกล้องหินผา | ปลอกเหลี่ยม Slate น้ำตาล + วงแหวน Neon อำพัน |
| Barrel_Wind | ลำกล้องวายุ | ครีบ Wedge 2 ชิ้นข้างลำกล้อง + วงแหวน Neon มิ้นต์ |
| Barrel_Neutral | ลำกล้องเหล็กกล้า | ปลอก Metal เทา + วงแหวนสีระดับ |
| Mechanism_* | กลไกเพลิง/ธารา/หินผา/วายุ/เหล็ก | กล่องข้างหัวป้อม + เฟือง (Cylinder บาง) หมุนตลอด สีตามธาตุ |
| Core_* | แกนเพลิง/ธารา/หินผา/วายุ/เหล็ก | ลูกบาศก์ Neon ลอยเหนือฐาน หมุนช้า สีตามธาตุ |
| Plating_* | เกราะเพลิง/ธารา/หินผา/วายุ/เหล็ก | แผ่นเกราะ 4 แผ่นรอบฐาน (Part บาง) วัสดุตามธาตุ |

สีตามระดับ (ขอบ/วงแหวน/ไฟเรือง): ⚪ เทา `(170,170,170)` · 🔵 ฟ้า `(70,140,255)` · 🟣 ม่วง `(170,80,255)` · 🟡 ทอง `(255,200,50)` + ประกาย (ParticleEmitter เบาๆ, Rate ≤ 5 เพื่อมือถือ)
- ชิ้นธาตุ: ตัวชิ้นสีธาตุ · ขอบ/วงแหวนสีระดับ · ชิ้นกลาง: ตัวชิ้นเหล็กเทา · ขอบสีระดับ
- ป้อมโมเดลที่ปั้นเอง (`TurretModels`): หา Attachment ชื่อ `GearBarrel`/`GearMechanism`/`GearCore`/`GearPlating` · ไม่มี = วางอ้างอิง `barrel`/`head`/`pedestal` ของ Look `[Proposed]`
- ใส่ชิ้นเดิมระดับสูงขึ้น = ชิ้นเดิม เปลี่ยนแค่สีขอบ (ใหญ่ขึ้น 5% ต่อขั้น) → เห็นความคืบหน้าจากหน้าตา

---

## 4. กติกาดรอปจากบอส (แทนตั๋วกาชาใน `BossService.finish()`)

เงื่อนไขได้ดรอป = เหมือนเงินเดิม: อยู่ในเซิร์ฟตอนบอสจากไป + ดาเมจ > 0 · **share** = ดาเมจตัวเอง ÷ ดาเมจรวม

### 4.1 จำนวนครั้งสุ่ม (rolls)
| เงื่อนไข | rolls |
|---|---|
| ทุกคนที่ตี (ขั้นต่ำ — เสาหลัก "ไม่เติมก็ได้รางวัล") | 1 |
| share ≥ 10% | +1 |
| share ≥ 25% | +1 |
| อันดับ 1 | +1 **โบนัสท็อป** (สุ่มจากตาราง "ท็อป" — การันตี Rare ขึ้นไป) |
| อันดับ 2–3 | +1 (ตารางตาม share ปกติ) |
| **เพดาน** | 4 rolls ต่อคนต่อบอส |

ตัวอย่าง 8 คนตีพอๆ กัน (share ~12%): อันดับ 1 = 1+1+1 = 3 · อันดับ 2–3 = 3 · ที่เหลือ = 2

### 4.2 โอกาสระดับ (%)
| ตาราง | ใช้เมื่อ | ⚪ C | 🔵 R | 🟣 E | 🟡 L |
|---|---|---|---|---|---|
| A | share < 10% | 72 | 23 | 4.5 | 0.5 |
| B | 10% ≤ share < 25% | 60 | 30 | 8.5 | 1.5 |
| C | share ≥ 25% | 50 | 34 | 13 | 3 |
| Top | roll โบนัสอันดับ 1 | 0 | 75 | 21 | 4 |

- **Pity**: สุ่มครบ 30 ครั้งติดโดยไม่ได้ Epic ขึ้นไป → ครั้งถัดไปได้ **Epic** แน่นอน (นับข้ามบอส เก็บใน data) `[Proposed]`
- UI ต้อง **แสดงตารางโอกาสนี้** (ปุ่ม "โอกาสดรอป") — โปร่งใสตาม IDEA แม้ไม่ใช้ Robux

### 4.3 เลือกชิ้น (หลังได้ระดับ)
1. สุ่มช่อง 1 ใน 4 เท่ากัน (25%) — **รวมช่องที่ยังล็อก** (เก็บไว้ใช้ตอนปลดล็อก)
2. สุ่มแบบ: ธาตุของป้อมตัวเอง น้ำหนัก **2** · ธาตุอื่น 1 · กลาง 1 (ธาตุตัวเอง = 2/6 ≈ 33%) · ยังไม่เลือกธาตุ = ทุกแบบ 1
- สุ่มด้วย `Random.new()` ฝั่ง Server เท่านั้น

### 4.4 ความถี่โดยประมาณ `[Inferred]`
บอสทุก ~8 นาที (อยู่ 300 วิ + พัก 180 วิ) → ~7.5 บอส/ชม. × ~2 rolls = ~15 rolls/ชม.
→ Epic ~1–2 ชิ้น/ชม. · Legendary ตรงๆ ~1 ชิ้นต่อ 4–10 ชม. (คนท็อปเร็วกว่า) → เป้าระยะยาวพอดี

---

## 5. ของซ้ำ · ย่อย · รวม · กระเป๋า

### 5.1 ย่อยเป็นเหรียญ (Salvage)
| ระดับ | ได้เหรียญ/ชิ้น |
|---|---|
| ⚪ Common | 15 |
| 🔵 Rare | 60 |
| 🟣 Epic | 250 |
| 🟡 Legendary | 1,000 |
- ย่อยได้ทีละชิ้น (เลือกจำนวน) หรือ **"ย่อยทั้งหมดระดับ X"** · **ชิ้นที่ใส่อยู่ 1 ชิ้นย่อยไม่ได้** (กันกดพลาด)

### 5.2 รวม 3 → 1 (Merge)
- 3 ชิ้น **id เดียวกัน ระดับเดียวกัน** (เช่น `Barrel_Fire_Common` ×3) → `Barrel_Fire_Rare` ×1 (ไม่สุ่ม ได้ชิ้นเดิมระดับถัดไป)
- ค่ารวม: C→R **30** · R→E **150** · E→L **600** เหรียญ (sink) · Legendary รวมต่อไม่ได้
- ต้องมีชิ้น **ที่ไม่ได้ใส่** ครบ 3 (ชิ้นที่ใส่อยู่ไม่ถูกใช้)
- กันช่องโหว่ปั๊มเงิน: ย่อย 3 ชิ้น > ย่อยผลรวม − ค่ารวมเสมอ (45 > 60−30 · 180 > 250−150 · 750 > 1000−600) → รวมเพื่อ "พลัง" ไม่ใช่เพื่อเงิน ✓

### 5.3 กระเป๋า
- เก็บได้ **150 ชิ้น** (นับทุกสำเนารวมชิ้นที่ใส่) · 1 id เก็บได้ไม่เกิน **99**
- กระเป๋าเต็มตอนได้ดรอป → ชิ้นนั้น **ย่อยเป็นเหรียญอัตโนมัติ** + แจ้งในหน้าผลดรอป ("กระเป๋าเต็ม → ได้ 60 เหรียญแทน") · ไม่มีของหาย

---

## 6. เศรษฐกิจ (เทียบของเดิม) `[Inferred จาก Config ปัจจุบัน]`

| แหล่งเหรียญ/ที่ใช้เหรียญ | ค่า | หมายเหตุ |
|---|---|---|
| รางวัลบอส (เดิม ไม่แตะ) | 50 + 300 × share | 8 คนเท่ากัน ≈ 87/บอส |
| มอน | 5 × (1 หรือ 3) ต่อตัว | ≈ 1,000–1,500/รอบบอส ถ้าเคลียร์เลนได้ |
| **ใหม่: ย่อยดรอป** | ค่าเฉลี่ย ~41 เหรียญ/roll (ตาราง A) | ~80/บอส ถ้าย่อยหมด · ≈ มูลค่าตั๋วเดิม |
| **ใหม่ sink: ปลดช่อง** | 2,500 + 15,000 | ครั้งเดียว |
| **ใหม่ sink: ค่ารวม** | 30 / 150 / 600 | ต่อครั้ง |
| อัปป้อม (เดิม) | 25 × 1.5^(Lv−1) | Lv.10→11 = 961 · Lv.20→21 = 55,420 |

**พลังที่ได้** (เทียบเลเวล): Lv.20 ป้อม DPS ≈ 105 × 2.9 = 305 · อัปทีละ 1 เลเวล ≈ +8%
- ใส่ Common ครบ 4 ช่อง ≈ DPS +9% ≈ **1 เลเวล**
- ใส่ Legendary ครบ (กลาง) ≈ 1.28 × 1.20 = **+54% ≈ 5–6 เลเวล** + สกิลถี่ขึ้น 19% + เลือด +63%
- → อุปกรณ์ "ช่วยได้จริงแต่ไม่แทนการอัปเลเวล" · ท็อปดาเมจยังมาจากเลเวล + ฝีมือกดสกิล (เสาหลัก 2)
- ความเสี่ยงเงินเฟ้อต่ำ: เหรียญจากย่อย ~5–8% ของรายได้รวมต่อรอบ

---

## 7. ข้อมูล — PlayerData v7

### 7.1 โครงใหม่
```lua
Gear = { -- v7 (แทนรูปแบบ v4 ["<ช่อง>_<ระดับ>"] = จำนวน ที่ยังไม่เคยถูกใช้)
	Items = {},          -- ["Barrel_Fire_Rare"] = 2   (จำนวนเต็ม 1..99)
	Equipped = { Barrel = "", Mechanism = "", Core = "", Plating = "" }, -- id ในกระเป๋า หรือ ""
	Slots = 2,           -- ช่องที่เปิดแล้ว 2..4 (ลำดับ Equipment.SlotOrder)
	Pity = 0,            -- rolls ติดกันที่ยังไม่ได้ Epic+
},
-- ลบ: GachaTickets, Skills, EquippedSkill (กาชาสกิล)
```

### 7.2 Migration `[6]` (v6 → v7)
```lua
[6] = function(data)
	local old = if type(data.Gear) == "table" then data.Gear else {}
	local items = {}
	for key, count in old do -- รูปแบบ v4 "Barrel_Rare" → "Barrel_Neutral_Rare" (ถ้าช่อง/ระดับถูกต้อง)
		-- แยก slot/rarity · ช่องหรือระดับไม่รู้จัก = ทิ้ง (warn) · count ปัดลง clamp 0..99
	end
	data.Gear = { Items = items, Equipped = { Barrel = "", Mechanism = "", Core = "", Plating = "" }, Slots = 2, Pity = 0 }
	-- ตั๋วกาชา → เหรียญ: 1 ใบ = 50 (≈ มูลค่าย่อยเฉลี่ยของ 1 roll) · clamp ไม่เกิน Economy.MaxCoins
	local tickets = if type(data.GachaTickets) == "number" and data.GachaTickets == data.GachaTickets then math.max(0, math.floor(data.GachaTickets)) else 0
	data.Coins = math.min((tonumber(data.Coins) or 0) + tickets * 50, Economy.MaxCoins)
	data.GachaTickets, data.Skills, data.EquippedSkill = nil, nil, nil
	return data
end,
```
- `v4 Gear` ไม่เคยมีโค้ดเขียน (เป็น `{}` ทุกคน) `[Verified: grep ไม่พบผู้เขียน Gear ใน src]` → แปลงไว้กันพลาดเท่านั้น
- ⚠️ ต้องถอด **กาชาทั้งชุดในรอบเดียวกัน** (`SkillService`, `SkillHandler`, `GachaUI`, `SkillController`, `Config/Skills` + require ใน PlayerData, Remotes `RollGacha/EquipSkill/UpgradeSkill/GachaResult`, `Economy.Gacha`, `StatsService.PUBLIC_FIELDS`) ไม่งั้น `reconcile` จะเติม field กาชากลับ/โค้ดเดิม error
- **ทำความสะอาดตอนโหลด** (ทุกครั้ง หลัง reconcile · `GearService.sanitize`): `reconcile` ไม่ตรวจ key ภายใน `Items` (template ว่าง) `[Verified: อ่าน reconcile]` → ทิ้ง id ที่ไม่มีใน Config, จำนวนไม่ใช่จำนวนเต็ม/≤0 · clamp ≤ 99 · `Slots` clamp 2..4 · `Equipped` ที่ไม่มีในกระเป๋า/ผิดช่อง/ช่องยังล็อก → `""` · `Pity` clamp 0..30
- โหลดไม่สำเร็จ = ห้ามบันทึกทับ (กฎเดิมของ PlayerData ไม่เปลี่ยน)

---

## 8. Server Authority + Remotes

หลัก: Client ส่งแค่ "อยากทำอะไร" (id เป็น string) · Server หาค่าทั้งหมดจาก Config + PlayerData · ทุกการแก้ของ/เงินทำใน `PlayerData.update` ครั้งเดียวต่อคำขอ (เช็ก → หัก → เพิ่ม ในฟังก์ชันเดียว กันของซ้ำ)

| Remote | ทิศ | argument | Guard | ตรวจที่ handler/Service |
|---|---|---|---|---|
| `EquipGear` | C→S | `(itemKey: string)` | 4/วิ | key อยู่ใน Config · มี ≥1 · ช่องของชิ้นเปิดแล้ว · **บอสไม่อยู่** |
| `UnequipGear` | C→S | `(slot: string)` | 4/วิ | slot อยู่ใน `SlotOrder` · บอสไม่อยู่ |
| `UnlockGearSlot` | C→S | ไม่มี | 2/วิ | `Slots < 4` · เงินพอ `SlotPrices[Slots+1]` |
| `SalvageGear` | C→S | `(itemKey: string, count: number)` | 5/วิ | `Guard.isInteger` 1..99 · count ≤ จำนวน − (1 ถ้าใส่อยู่) |
| `SalvageRarity` | C→S | `(rarity: string)` | 1/วิ | rarity อยู่ใน `RarityOrder` · ข้ามชิ้นที่ใส่อยู่ · ไม่รวม Legendary (กันพลาด) |
| `MergeGear` | C→S | `(itemKey: string)` | 3/วิ | ไม่ใช่ Legendary · ชิ้นไม่ได้ใส่ ≥3 · เงินพอค่ารวม · ผลไม่เกิน 99 |
| `GearDrops` | S→C | `{ { Key, New: bool, Salvaged: number? } }` | — | แสดงผลเท่านั้น |

- ห้ามเปลี่ยนอุปกรณ์ระหว่างบอส (เหมือนกฎเปลี่ยนธาตุ · กันสลับหาค่าเฉพาะหน้า) · ย่อย/รวม/ปลดช่องทำได้ทุกเวลา (ไม่แตะค่าที่ใส่อยู่)
- ส่งข้อมูลให้ Client: `StatsService` ตั้ง Attribute `Gear` = `HttpService:JSONEncode(data.Gear)` (Attribute เก็บตารางไม่ได้) · Client ใช้แสดงผลเท่านั้น
- ดรอป: สุ่ม/ให้ของที่ `GearService.grantBossDrops` เท่านั้น · ไม่มี Remote ให้ Client ขอดรอป
- ตัวเลขโบนัสทั้งหมดคำนวณที่ Server (`GearMath` ใน shared ใช้ได้ทั้งสองฝั่ง แต่ Client ใช้แค่แสดง)
- ไม่มี session lock ยังโอเค (ไม่มีแลกเปลี่ยน) · **ห้ามเปิดแลกเปลี่ยนจนกว่าจะมี session lock** `[Proposed]`

---

## 9. Config — `src/shared/Config/Equipment.luau` (โครงเสนอ)
```lua
local f = table.freeze
return f({
	SlotOrder = f({ "Barrel", "Mechanism", "Core", "Plating" }),
	StartSlots = 2, MaxSlots = 4,
	SlotPrices = f({ [3] = 2500, [4] = 15000 }),        -- ราคาเปิดช่องที่ n
	Slots = f({
		Barrel    = f({ Name = "ลำกล้อง", Icon = "🔫", Main = "Damage" }),
		Mechanism = f({ Name = "กลไกยิง", Icon = "⚙️", Main = "FireRate" }),
		Core      = f({ Name = "แกนพลัง", Icon = "🔮", Main = "SkillCooldown" }),
		Plating   = f({ Name = "เกราะ",   Icon = "🛡️", Main = "TurretHp" }),
	}),
	RarityOrder = f({ "Common", "Rare", "Epic", "Legendary" }),
	Rarities = f({
		Common    = f({ Name = "ธรรมดา",  Color = Color3.fromRGB(170,170,170), Salvage = 15,   MergeCost = 30 }),
		Rare      = f({ Name = "หายาก",   Color = Color3.fromRGB(70,140,255),  Salvage = 60,   MergeCost = 150 }),
		Epic      = f({ Name = "มหากาพย์", Color = Color3.fromRGB(170,80,255),  Salvage = 250,  MergeCost = 600 }),
		Legendary = f({ Name = "ตำนาน",   Color = Color3.fromRGB(255,200,50),  Salvage = 1000 }),
	}),
	-- ค่าหลัก (หน่วย: สัดส่วน 0.04 = 4%) ตามช่อง × ระดับ · ชิ้นกลางคูณ NeutralMultiplier
	MainStat = f({
		Barrel = f({ Common = 0.04, Rare = 0.08, Epic = 0.14, Legendary = 0.22 }),
		Mechanism = f({ ... }), Core = f({ ... }), Plating = f({ ... }),
	}),
	NeutralMultiplier = 1.25,
	-- โบนัสธาตุตรง: ธาตุ → ค่ารอง + ค่าตามระดับ
	MatchBonus = f({
		Fire  = f({ Stat = "SkillDamage", Common = 0.05, Rare = 0.10, Epic = 0.16, Legendary = 0.25 }),
		Water = f({ Stat = "TurretHp", ... }), Earth = f({ Stat = "BossDamage", ... }), Wind = f({ Stat = "StunReduce", ... }),
	}),
	FullSetBonus = f({ Stat = "Damage", Value = 0.05 }),
	Caps = f({ BossDamage = 0.5, SkillCooldown = 0.4, TurretHp = 1.0, StunReduceTotal = 0.7 }),
	Variants = f({ "Fire", "Water", "Earth", "Wind", "Neutral" }),
	Names = f({ Barrel_Fire = "ลำกล้องลาวา", ... }),   -- 20 ชื่อ (หัวข้อ 3.3)
	Drops = f({
		BaseRolls = 1, ShareRolls = f({ 0.10, 0.25 }), TopRollRank = 1, RankRolls = f({ 2, 3 }), MaxRolls = 4,
		Tables = f({  -- น้ำหนัก (รวม 100)
			A = f({ Common = 72, Rare = 23, Epic = 4.5, Legendary = 0.5 }),
			B = f({ Common = 60, Rare = 30, Epic = 8.5, Legendary = 1.5 }),
			C = f({ Common = 50, Rare = 34, Epic = 13, Legendary = 3 }),
			Top = f({ Common = 0, Rare = 75, Epic = 21, Legendary = 4 }),
		}),
		OwnElementWeight = 2, OtherWeight = 1, NeutralWeight = 1,
		PityRolls = 30, PityRarity = "Epic",
	}),
	InventoryCap = 150, StackCap = 99,
	TicketToCoins = 50,  -- ใช้ใน migration v6→v7 เท่านั้น
})
```
- `Economy.Gacha` ลบ · ตัวเลขเงินของอุปกรณ์อยู่ไฟล์นี้ทั้งหมด (ปรับผ่าน `/roblox-economy`)
- Client อ่านได้ (ตารางโอกาส/ราคา) → ไม่มีความลับ ✓

---

## 10. วิธีต่อเข้า TurretService (hook points)

ไฟล์ใหม่: `src/shared/Util/GearMath.luau` (`GearMath.bonus(gearData, element) → Bonus`) · `src/server/Services/GearService.luau` (cache โบนัสต่อผู้เล่น · คำนวณใหม่เมื่อ `PlayerData.Changed` · equip/unequip/salvage/merge/unlock/grantBossDrops/sanitize) · `src/server/Network/GearHandler.luau` · `src/client/UI/GearUI.luau`

`Bonus = { Damage, FireRate, BossDamage, SkillCooldown, SkillDamage, TurretHp, StunReduce }` (สัดส่วน · ใส่เพดานแล้ว)

| จุดในโค้ด (`TurretService.luau` ยกเว้นที่ระบุ) | เปลี่ยนเป็น |
|---|---|
| `baseDamage()` | `TurretMath.damage × (1+friend) × (1 + b.Damage)` → ยิงปกติ + สกิลได้พร้อมกัน |
| `tick()` บรรทัด `rate = ...` | `× (1 + b.FireRate)` · **ไม่แก้** `ElementMath.skillScale` (สกิลโตตามเลเวลอย่างเดียว กันนับซ้ำ) |
| `useSkill()` caster `D =` | `baseDamage × (1 + b.SkillDamage)` |
| `useSkill()` / `onElementChanged()` `setCooldown(... skill.Cooldown)` | `skill.Cooldown × (1 − b.SkillCooldown)` |
| `TurretElementService.damageBoss()` (จุดเดียวที่ตีบอส) | `amount × (1 + b.BossDamage)` **ก่อน** คูณเกราะแตก → เครดิตซัพพอร์ตคิดจากค่านี้ |
| ทุกที่ที่ใช้ `Combat.Turret.MaxHp` (build, setHealthy, revive, updateHealth, heal) | `maxHpOf(owner) = MaxHp × (1 + b.TurretHp)` |
| `stun()` | `StunSeconds × (1 − min(passive + b.StunReduce, 0.7))` |
| ภาพ | `TurretLook.setGear(look, visuals)` ใหม่ (เพิ่ม/ลบชิ้นใน `look.model` · ไม่สร้างป้อมใหม่ทั้งตัว) · เรียกตอน build และเมื่ออุปกรณ์เปลี่ยน · ช็อต = ชิ้นอุปกรณ์เป็นสีเทาด้วย (ใส่ใน `tinted`) |
| `BossService.finish()` | แทน `SkillService.grantTickets(...)` ด้วย `GearService.grantBossDrops(player, rank, entry.damage / total)` · ข้อความ Result "ได้เงิน + 🛠️ อุปกรณ์ตามดาเมจ" (แก้เฉพาะส่วนรางวัล · ไม่แตะโมเดล/ท่าบอสที่ล็อกไว้) |

- เปลี่ยนอุปกรณ์ (นอกบอส) → เลือดป้อมตั้งเป็นเต็มใหม่ · `GearService.Changed` → TurretService อัปเดตภาพ + cache
- ลำดับคูณเขียนเป็น comment "ตัวอย่างตัวเลข" แบบไฟล์เดิม เช่น `D 105 × ดาเมจ 1.22 = 128`

---

## 11. UI (มือถือก่อน)
- ปุ่ม HUD **"🛠️ อุปกรณ์"** แทนปุ่ม "กาชา" (ใช้ `Panels` เดิม) · จุดแดงเมื่อมีของใหม่/รวมได้
- **แผงอุปกรณ์** (สร้างด้วยโค้ด · `UIScale` + `UIAspectRatioConstraint` · ปุ่ม ≥ 44 px):
  1. **แถวช่อง 4 การ์ด** (จอแนวนอน 1 แถว · จอแคบ 2×2): ไอคอน + ชื่อชิ้น + ขอบสีระดับ · ช่องล็อก = 🔒 + ราคา + ปุ่ม "ปลดล็อก" (เทาถ้าเงินไม่พอ)
  2. **สรุปโบนัสรวม**: "ดาเมจ +22% · อัตรายิง +16% ..." (จาก `GearMath` ฝั่ง Client เพื่อแสดง)
  3. **แท็บกรอง**: ทั้งหมด / ลำกล้อง / กลไก / แกน / เกราะ · เรียง ระดับ → ธาตุตรงก่อน
  4. **กริดกระเป๋า** (`ScrollingFrame` + `UIGridLayout`): ช่องละชิ้น ไอคอนธาตุ + ตัวเลข ×จำนวน + ขอบสีระดับ · ป้าย ✓ ธาตุตรง · "(150/150)" มุมบน
  5. **แผ่นรายละเอียด** (กดชิ้น → เลื่อนขึ้นจากล่าง): ค่าหลัก/ค่ารอง (ค่ารองเป็นสีเทาถ้าธาตุไม่ตรง) · เทียบกับชิ้นที่ใส่อยู่ (+/− สีเขียว/แดง) · ปุ่ม **ใส่** · **รวม 3→1 (💰x)** · **ย่อย (+x💰)**
  6. ปุ่มล่าง: "ย่อยธรรมดาทั้งหมด" (ถามยืนยัน) · "ℹ️ โอกาสดรอป" (ตารางหัวข้อ 4.2)
- **หลังบอสจากไป**: ป๊อปอัปการ์ดดรอปพลิกทีละใบ (Tween 0.2 วิ) สีตามระดับ · Legendary มีแสงวิ้ง · ปุ่ม "ใส่เลย" ถ้าดีกว่าชิ้นปัจจุบัน
- ระหว่างบอส: ปุ่มใส่/ถอดเป็นเทา + ข้อความ "เปลี่ยนอุปกรณ์หลังบอสจากไป"
- ข้อความไทยทั้งหมด · ไม่มีปุ่มเล็กชิดกัน (เว้น ≥ 8 px)

---

## 12. เกณฑ์ตรวจรับ (Acceptance Criteria)
- [ ] ข้อมูล v6 เข้าเกม → v7: `GachaTickets` 3 ใบ → เหรียญ +150 · `Skills/EquippedSkill/GachaTickets` หาย · `Gear.Slots = 2` · ไม่มี error
- [ ] ข้อมูล v7 ที่ถูกแก้มั่ว (id ไม่มีจริง, จำนวน -5/1.5/1e9, Equipped ช่องล็อก) → ถูกล้างตอนโหลด ไม่ crash
- [ ] โหลด DataStore พัง → ไม่บันทึกทับ (กฎเดิม) · ของไม่หาย
- [ ] บอสจากไป: คนที่ดาเมจ > 0 ได้ ≥1 ชิ้น · อันดับ 1 ได้ชิ้น Rare+ ≥1 ชิ้น · ไม่มีใครเกิน 4 · ดาเมจ 0 ไม่ได้
- [ ] จำลองสุ่ม 100,000 ครั้งต่อตาราง → สัดส่วนระดับห่างจากตารางไม่เกิน ±0.5 จุด · pity ทำงานที่ครั้งที่ 31
- [ ] กระเป๋าเต็ม → ดรอปถูกย่อยเป็นเหรียญ + แจ้ง
- [ ] ใส่ `Barrel_Fire_Legendary` บนป้อมไฟ → ดาเมจยิง ×1.22 · ดาเมจสกิล ×1.22×1.25 · บนป้อมน้ำ → ×1.22 อย่างเดียว
- [ ] Mechanism +16% → นัด/วิ ×1.16 · ดาเมจต่อลูกของสกิลไม่เปลี่ยน
- [ ] Core −15% → คูลดาวน์ลูกไฟพัด 25 → 21.25 วิ · รวมทุกชิ้นไม่ต่ำกว่า −40%
- [ ] Plating +50% → เลือด 150 · ทุบ 40 ต้อง 4 ครั้งถึงช็อต · ลม + เกราะลม → ช็อตไม่ต่ำกว่า 6 × 0.3 = 1.8 วิ
- [ ] BossDamage ใช้กับบอสเท่านั้น (มอนไม่เปลี่ยน) และคูณก่อนเกราะแตก
- [ ] Remote ทุกตัวผ่าน `Guard` · ส่ง id มั่ว/จำนวนติดลบ/ทศนิยม/NaN/ยิงรัว → ไม่มีอะไรเปลี่ยน
- [ ] ใส่/ถอดระหว่างบอส → ถูกปฏิเสธ · ย่อยชิ้นที่ใส่อยู่ชิ้นสุดท้าย → ถูกปฏิเสธ
- [ ] รวม 3 → 1: หัก 3 + ค่ารวม ได้ 1 ระดับถัดไป ใน `PlayerData.update` ครั้งเดียว · เงินไม่พอ = ไม่เสียของ
- [ ] ปลดช่อง: เงินพอ → Slots +1 ตามราคา · ครบ 4 → กดไม่ได้
- [ ] หน้าตาป้อมมีชิ้นตามช่อง/สีระดับ · ช็อตแล้วเป็นสีเทา · ใช้ได้กับโมเดลที่ปั้นเอง
- [ ] UI ใช้ได้บนจอมือถือ (Studio Device Emulator iPhone SE / แท็บเล็ต) · ไม่มีปุ่มกาชาเหลือ
- [ ] `selene src` / `stylua src` / `rojo build` ผ่าน

---

## 13. สิ่งที่ตัดสินเองแทนเจ้าของ (แก้ได้ภายหลัง · ทั้งหมด `[Proposed]`)
1. ช่องที่ 4 = เกราะ (แทนศูนย์เล็ง/คริ) · เปิดตามลำดับ 2,500 / 15,000
2. ตั๋วกาชาเก่า 1 ใบ = 50 เหรียญ
3. ห้ามใส่/ถอดระหว่างบอส
4. ยังไม่มีแลกเปลี่ยน · ไม่มี Robux ในระบบนี้
5. ดรอปธาตุตัวเองมีโอกาส ×2 · มี pity Epic ทุก 30 rolls

---

## 14. สัญญากับ Client (สำหรับ UI agent)

> เขียนหลังทำโค้ดฝั่ง Server/Shared/Data แล้ว (2026-09-30) · UI อ่านได้อย่างเดียว ห้ามตัดสินผลเอง — ส่ง "เจตนา" ผ่าน Remote แล้ว **รอ Attribute เปลี่ยน** ค่อยวาดใหม่
> คำขอที่ผิดกฎ Server จะ **เงียบ** (ไม่ตอบ error) → UI ต้องทำปุ่มเทาเองตามกฎด้านล่าง ไม่ใช่รอคำตอบ

### 14.1 Player Attribute (บน `Players.LocalPlayer` · ตั้งโดย `Services/GearService.luau`)
| Attribute | ชนิด | ความหมาย |
|---|---|---|
| `Gear` | string (JSON) | `data.Gear` ทั้งก้อน: `{ "Items": { "<key>": count }, "Equipped": { "Barrel": key\|"", "Mechanism": …, "Core": …, "Plating": … }, "Slots": 2..4, "Pity": 0..30 }` |
| `GearSlots` | number | ช่องที่เปิดแล้ว 2..4 (ช่องที่ n เปิดเมื่อ n ≤ ค่านี้ · ลำดับ `Equipment.SlotOrder`) |
| `GearBonus` | string (JSON) | โบนัสรวมที่ Server ใช้จริง (บีบเพดานแล้ว · ตามธาตุป้อมตอนนี้): `{ "Damage", "FireRate", "BossDamage", "SkillCooldown", "SkillDamage", "TurretHp", "StunReduce" }` เป็นสัดส่วน (0.22 = 22%) · SkillCooldown/StunReduce = "ลดลง" |
| `Coins` · `Element` | number · string | (เดิม · StatsService) ใช้เช็กเงินพอ/ธาตุตรง |

- `key` = `"<ช่อง>_<แบบ>_<ระดับ>"` เช่น `"Barrel_Fire_Rare"` · แยกด้วย `GearMath.parseKey(key)` → `slot, variant, rarity`
- อ่าน JSON: `pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Gear"))` · ยังไม่มี Attribute (nil) = ข้อมูลยังโหลดไม่เสร็จ → โชว์ "กำลังโหลด"
- ⚠️ `Items` ว่างอาจถูก encode เป็น `[]` (array) แทน `{}` `[Inferred: HttpService.JSONEncode แปลงตารางว่างเป็น array]` → ให้ถือว่าเป็น map ว่างทั้งสองแบบ
- `Items[key]` นับ **ทุกสำเนารวมชิ้นที่ใส่** · ชิ้นที่ใส่อยู่ยังอยู่ใน Items (Equipped แค่ชี้ไป)
- ฟังการเปลี่ยน: `player:GetAttributeChangedSignal("Gear")` (ยิงหลังใส่/ถอด/เปิดช่อง/ย่อย/รวม/ได้ดรอป/โหลดเสร็จ/เปลี่ยนธาตุ) · `GearBonus` เปลี่ยนพร้อมกัน
- Attribute เก่าที่ **ถูกลบแล้ว**: `GachaTickets` `EquippedSkill` `Skills`

### 14.2 Remote (ชื่ออยู่ `src/shared/Remotes.luau` · ตัวรับ `src/server/Network/GearHandler.luau`)
| Remote | ทิศ | argument (`FireServer(...)`) | rate | Server ปฏิเสธเงียบเมื่อ… |
|---|---|---|---|---|
| `EquipGear` | C→S | `(key: string)` | 4/วิ | key ไม่มีจริง · มี < 1 · ช่องของชิ้นยังล็อก · ใส่ชิ้นนี้อยู่แล้ว · **บอสอยู่** |
| `UnequipGear` | C→S | `(slot: string)` เช่น `"Core"` | 4/วิ | slot ไม่มีจริง · ช่องว่าง · **บอสอยู่** |
| `UnlockGearSlot` | C→S | ไม่มี | 2/วิ | เปิดครบ 4 แล้ว · เงิน < `GearMath.nextSlotPrice(Slots)` |
| `SalvageGear` | C→S | `(key: string, count: number)` count จำนวนเต็ม 1..99 | 5/วิ | count > `GearMath.freeCount(gear, key)` (ชิ้นที่ใส่ 1 ชิ้นย่อยไม่ได้) |
| `SalvageRarity` | C→S | `(rarity: string)` `"Common"`/`"Rare"`/`"Epic"` | 1/วิ | `"Legendary"` (ไม่รับ) · ไม่มีชิ้นว่างของระดับนั้น |
| `MergeGear` | C→S | `(key: string)` | 3/วิ | Legendary · `freeCount < 3` · เงิน < `GearMath.mergeCost(rarity)` · ผลลัพธ์ (ระดับถัดไป) มีครบ 99 แล้ว |
| `GearDrops` | S→C | `OnClientEvent(list)` · `list = { { Key: string, New: boolean, Salvaged: number?, Top: boolean? } }` | — | แสดงผลเท่านั้น (ของจริงมาทาง Attribute `Gear`) |

- `GearDrops` ยิงหลังบอสจากไป (1 ครั้งต่อคน · 1–4 รายการ) · `New` = เพิ่งมี id นี้ครั้งแรก · `Salvaged` = กระเป๋า/กองเต็ม → ได้เหรียญเท่านี้แทน (ไม่ได้ของ) · `Top` = roll โบนัสอันดับ 1
- บอสอยู่ไหม: `ReplicatedStorage.BossState:GetAttribute("Active")` (เดิม) → ปุ่มใส่/ถอดเป็นเทา + ข้อความ "เปลี่ยนอุปกรณ์หลังบอสจากไป"

### 14.3 โมดูล shared ที่ UI ใช้ได้ (อ่าน/คำนวณเพื่อแสดงเท่านั้น)
- `Config/Equipment.luau`: `SlotOrder` `Slots[slot].Name/Icon/Main` · `RarityOrder` `Rarities[r].Name/Color/Salvage/MergeCost` · `Names["<ช่อง>_<แบบ>"]` · `SlotPrices` · `Drops.Tables` · `InventoryCap` (150) · `StackCap` (99) · `MainStat` / `NeutralMainStat` / `MatchBonus`
- `Util/GearMath.luau`: `parseKey` `keyOf` `mainStat(slot, variant, rarity)` `matchStat(variant, rarity, element)` `bonus(gear, element)` (ใช้เทียบ "ถ้าใส่ชิ้นนี้" ได้: ก๊อป gear แล้วแก้ Equipped แล้วเรียก bonus) `freeCount(gear, key)` `countAll(items)` `nextSlotPrice(slots)` `mergeCost(r)` `salvageValue(r)` `nextRarity(r)` `odds("A"|"B"|"C"|"Top")` (ตาราง "โอกาสดรอป") `BONUS_STATS`
  - ⚠️ `freeCount/isEquipped` ต้องการ gear ที่มี `Items` เป็นตาราง (decode แล้วแปลง `[]` เป็น `{}` ก่อน)
- สีธาตุของชิ้น: `Config/Elements.luau` → `Elements.<ธาตุ>.Color` · ชิ้นกลาง: `Equipment.NeutralColor`

### 14.4 อื่นๆ ที่ UI ควรรู้
- ปุ่ม HUD เดิม "กาชา" ถูกเปลี่ยนเป็น **"🛠 อุปกรณ์"** เรียก `Panels.toggle("Gear")` · ตอนนี้เป็นแผงชั่วคราว (`placeholderPanel` ใน `UI/HudUI.luau`) → UI จริงให้ลบบรรทัด placeholder `"Gear"` แล้ว `Panels.register("Gear", …)` แทน
- ไฟล์ที่ลบแล้ว: `UI/GachaUI.luau` `Controllers/SkillController.luau` (Remote กาชาทั้งหมดถูกลบ)
- ชิ้นบนป้อม (Server ปั้น): `workspace.Turrets.Turret_<UserId>.Gear` (Model) · ชิ้นชื่อ `GearSleeve` `GearRing` `GearBox` `GearCog` `GearCore` `GearPlate` `GearTrim` · เฟือง/แกนหมุนด้วย Attribute `Anim = "Orbit"` (TurretAnimController เดิมรองรับแล้ว)

### 14.5 สิ่งที่โค้ดต่างจากสเปกด้านบนเล็กน้อย (ตัดสินเองตามที่เจ้าของให้ทำโดยไม่ถาม · `[Proposed]`)
1. Config ใช้ตาราง `NeutralMainStat` เขียนตัวเลขตรงๆ แทน `NeutralMultiplier` (กันปัดเศษเพี้ยน · ค่าเท่ากับตารางหัวข้อ 3.1)
2. ส่ง Attribute `GearSlots` + `GearBonus` เพิ่มจาก `Gear` · ส่งจาก `GearService` (เฉพาะตอนอุปกรณ์/ธาตุเปลี่ยน) ไม่ใช่ `StatsService` (ไม่ต้อง encode JSON ทุกครั้งที่เงินเปลี่ยน)
3. เหรียญจากการย่อย (มือ/อัตโนมัติ) บวกตรงใน `PlayerData.update` เดียวกับการหักของ (atomic) · **ไม่คูณโบนัสเพื่อน** และไม่ผ่าน `Wallet.earn`
4. Sanitize: จำนวนที่ไม่ใช่จำนวนเต็ม (เช่น 1.5) = ทิ้งทั้งกอง (ตามหัวข้อ 7.2) · เกิน 99 = บีบเป็น 99 · กระเป๋ารวมเกิน 150 จากข้อมูลเสีย = ไม่ลบของ (ดรอปใหม่จะถูกย่อยอัตโนมัติจนกว่าจะต่ำกว่า 150)
5. Pity นับทุก roll รวม roll ท็อป · Legendary ตรงๆ ก็รีเซ็ต pity
6. โบนัสดาเมจบอส (`BossDamage`) คูณใน `TurretElementService.damageBoss` → มีผลกับ DoT/โซนที่ตีบอสด้วย (ทุกดาเมจบอสผ่านจุดนี้)
7. หน้าตาชิ้นบนป้อม: ยังไม่อ่าน Attachment `GearBarrel/GearMechanism/GearCore/GearPlating` ของโมเดลที่ import (วางตามหัว/ลำกล้อง/แท่นแทน) · ลม "ครีบ Wedge" ยังไม่ทำ (ใช้ปลอก + วงแหวนแบบเดียวกันทุกแบบ ต่างที่สี/วัสดุ)
8. migration `[2]` เดิมอ้าง `Config/Skills` (ลบแล้ว) → เขียนค่าเดิม `"Overdrive"` ตรงๆ แทน (ผลเหมือนเดิม และถูกลบต่อใน `[6]`)
