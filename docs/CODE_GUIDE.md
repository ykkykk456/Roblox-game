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
| **ธาตุป้อม** 🔥💧🪨🌪️ (ตัวคูณดาเมจ/ยิงเร็ว, ชื่อ, คำอธิบาย, สี, ผลกระสุน, Passive) | `src/shared/Config/Elements.luau` | `Elements.<ธาตุ>` (`Damage` `FireRate` `Shot` `Passive`) |
| **สกิลกด Q ของแต่ละธาตุ** (ชื่อ คูลดาวน์ ดาเมจ จำนวนลูก ฯลฯ) | `Config/Elements.luau` | `Elements.<ธาตุ>.Skill` (`Cooldown` `Pattern` `Status`) |
| ราคาเปลี่ยนธาตุ (เลือกครั้งแรกฟรี) | `Config/Elements.luau` | `ChangeElementCost` |
| สีบอลไฟตามเลเวล (ธาตุไฟ) | `Config/Elements.luau` | `FireColors` |
| เลเวลที่หน้าตาป้อมอัปขั้น (ทุก 10 เลเวล) · ป้อมโตขั้นละเท่าไร | `Config/Elements.luau` | `LookTiers` `LookScalePerTier` |
| หน้าตาป้อมโค้ดแต่ละธาตุ + ของแต่งตามขั้น (ชิ้นส่วน ขนาด สี) | `src/server/Services/TurretLook.luau` | `buildFire` `buildWater` `buildEarth` `buildWind` `tierDecor` |
| **ใช้โมเดลป้อมที่ปั้นเอง** แทนป้อมโค้ด | Studio: `ServerStorage > TurretModels` · ค่า: `Config/Elements.luau` | ดูหัวข้อ "โมเดลป้อมที่ import เอง" ด้านล่าง · `CustomModel` |
| ใบพัดหมุน/ลูกแก้วลอย/วงแหวนลอยบนป้อม (ขยับฝั่ง Client) | `TurretLook.luau` (ค่า `anim`) · `src/client/Controllers/TurretAnimController.luau` | |
| เอฟเฟกต์กระสุน/สกิล (ที่เห็นบนจอ) | `src/client/Controllers/TurretController.luau` | ฟังก์ชันวาดตาม `Kind` (`drawFireball` `drawWave` ...) |
| ความเร็วกระสุน (ดาเมจเข้าตอนกระสุนถึง · ภาพกับดาเมจใช้ค่าเดียวกัน) · ชนิดที่โดนทันที | `Config/Combat.luau` | `Turret.Projectile` (`Speed` `Speeds` `Instant` `MaxTravel`) |
| หน้าเลือกธาตุ (ปุ่ม ตำแหน่ง ข้อความ) · ปุ่มลัด C | `src/client/UI/ElementUI.luau` | |
| **อุปกรณ์ป้อม** (ราคาเปิดช่อง · ค่าสถานะต่อช่อง/ระดับ · โบนัสธาตุตรง · เพดาน · ย่อย/รวม · ดรอปบอส + โอกาส + pity · ขนาดกระเป๋า · ชื่อชิ้น) | `src/shared/Config/Equipment.luau` | `SlotPrices` `MainStat` `NeutralMainStat` `MatchBonus` `FullSetBonus` `Caps` `Rarities` `Drops` `InventoryCap` `Names` |
| สูตรรวมโบนัสอุปกรณ์ / ขั้นตอนสุ่มดรอป / ล้างข้อมูลอุปกรณ์ตอนโหลด | `src/shared/Util/GearMath.luau` | `bonus` `rollTables` `pickRarity` `applyPity` `sanitize` |
| หน้าตาชิ้นอุปกรณ์บนป้อม (ปลอกลำกล้อง กลไก แกน เกราะ) | `src/server/Services/TurretLook.luau` | `gearPieces` `GEAR_MATERIAL` |
| ราคาอัปป้อม · เงินจากมอน · เงินรางวัลบอส | `src/shared/Config/Economy.luau` | `Turret` `MonsterReward` `Boss` |
| มอน (จำนวนต่อ wave, เลือด, ความเร็ว, เวลาพัก) | `Config/Combat.luau` | `Monster.*` |
| บอส (เวลาอยู่, ช่วงเวลามา, ลำดับสลับ, ท่า Animation ID, ทุบ) | `Config/Combat.luau` | `Boss.*` (`Rotation`, `Animations`, `Duration`, `SlamDamage`) |
| ตำแหน่งบอส / ป้อม / บ้าน | **ใน Studio** ติด Tag `BossSpawn` `Turret1..6` `House1..6` | ชื่อ Tag อยู่ `Config/Tags.luau` |
| เลนมอน / ระยะเกิด · การวัดพื้นตามเลน (มอนเดินติดพื้น) | `src/shared/Config/Map.luau` | `Layout.*` (`FloorSampleStep` `FloorMaxClimb` `FloorProbeDepth`) `Lane.*` |
| หน้าจอ HUD เงิน / แถบบอส / ปุ่มสกิล / ปุ่ม "🛠 ป้อม" | `src/client/UI/HudUI.luau` · `CombatUI.luau` | |
| **อัปเกรดป้อม** (ปุ่ม · ราคา · ดาเมจก่อน→หลัง) — อยู่ในแผงป้อม ใต้ช่องอุปกรณ์ · **ไม่มีปุ่มลัดคีย์บอร์ด** (เดิม U/Y ถูกถอด · เมาส์/แตะเท่านั้น) | `src/client/UI/TurretPanelUI.luau` | `buildUpgradeBox` `renderUpgrade` · ราคา → `Config/Economy.luau` |
| **คลิก/แตะป้อมตัวเองในโลก → เปิดแผงป้อม** · ปุ่ม "🛠 ป้อม" ลอยเหนือป้อม | `src/client/UI/TurretTapUI.luau` | `TAP_MAX_MOVE` `TAP_MAX_SECONDS` `HIT_PADDING` `BUTTON_*` |
| แผงป้อม (คลิกป้อม → ช่องอุปกรณ์ 4 ช่อง + กล่องอัป · กดช่อง → กระเป๋าเฉพาะช่องนั้น + ปุ่ม "ใส่" บนการ์ด + ◀ ย้อนกลับ · แตะการ์ด → รายละเอียด/รวม/แยก · ป๊อปอัปของดรอป) · ปุ่มลัดสำรอง G / RB · ข้อมูลที่ใช้ ดู `design/equipment.md` หัวข้อ "สัญญากับ Client" | `src/client/UI/TurretPanelUI.luau` · `src/client/Controllers/GearController.luau` | `renderMain` `renderSlotPage` `itemCard` `renderSheet` |
| สี/ฟอนต์ UI ทั้งเกม | `src/client/UI/Theme.luau` | |
| **ฝึกสอนตอนเข้าเกม** (ข้อความแต่ละขั้น · จำนวน/เลือดมอนฝึก · เวลา · เลื่อนบอสได้นานสุด · โบนัสจบ · ปิดระบบฝึก) · สเปก `design/tutorial.md` | `src/shared/Config/Tutorial.luau` | `Steps[n].Text` `WatchMonsters` `SkillMonsters` `TrainingMonsterHp` `WatchTimeout` `ReadSeconds` `MinReadSeconds` `MaxBossHold` `RewardCoins` `Enabled` |
| ลำดับ/เงื่อนไขจบของขั้นฝึก · สิ่งที่ล็อกระหว่างฝึก | `src/server/Services/TutorialService.luau` | `enterStep` `Start` (ลูปเช็กขั้น) `allows` `holdBoss` |

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
| `Services/TurretService.luau` | ป้อม: สร้าง · เล็ง · ยิง · อัปเลเวล · ใช้สกิลธาตุ (คูลดาวน์) · เลือดป้อม · Passive ป้อม |
| `Services/TurretElementService.luau` | เลือก/เปลี่ยนธาตุ (หักเงิน) · ผลกระสุน (ระเบิด ช้าลง ถอย ทะลุ) · ติดไฟ (DoT) |
| `Services/ElementSkillService.luau` | สกิลกดของธาตุ (ยิงเป็นชุด / คลื่นตามเลน · + แบบที่เตรียมไว้ให้วิวัฒนาการ) |
| `Services/TurretLook.luau` | หน้าตาป้อมตามธาตุ + ขั้นเลเวล · หรือโมเดลที่ import เอง |
| `Network/ElementHandler.luau` | รับคำขอเลือกธาตุ (Remote `ChooseElement`) |
| `Services/ServerBoardService.luau` | สกอร์บอร์ดเซิร์ฟ "ดาเมจรวม" (รายชื่อผู้เล่นขวาบน · สะสมทุกรอบบอส · ไม่บันทึก) · ตารางซ้ายบน = ดาเมจรอบนี้ (รีเซ็ตทุกบอส ใช้แจกรางวัล) |
| `Services/BossService.luau` | บอส (🔒 ล็อก) |
| `Services/MonsterService.luau` | มอนเป็น wave ตามเลน |
| `Services/LayoutService.luau` | อ่านตำแหน่งจาก Tag ในแมพ |
| `Services/MapService.luau` | สร้าง/ล็อกแมพ · จุดเกิด |
| `Services/GearService.luau` | อุปกรณ์ป้อม: ใส่/ถอด · เปิดช่อง · ย่อย · รวม 3→1 · ดรอปจากบอส · โบนัสให้ป้อม (ระบบกาชาถูกถอดแล้ว) |
| `Services/TutorialService.luau` | ฝึกสอน 5 ขั้น: เลื่อนขั้น (Server เท่านั้น) · มอนฝึก · เติมเงินขั้นอัป · เลื่อนบอสตอนมีคนฝึกขั้นมอน · โบนัสจบ · บอกระบบอื่นว่าทำอะไรได้ (`isDone` `step` `allows`) |
| `Network/TutorialHandler.luau` | รับปุ่ม "เข้าใจแล้ว!" ขั้นสุดท้าย (Remote `TutorialAck`) |
| `Network/GearHandler.luau` | รับคำขออุปกรณ์ (Remote `EquipGear` `UnequipGear` `UnlockGearSlot` `SalvageGear` `SalvageRarity` `MergeGear`) |
| `Data/PlayerData.luau` | เซฟ/โหลดข้อมูลผู้เล่น (ระวัง!) |
| `Network/Guard.luau` | ด่านตรวจทุกคำขอจากผู้เล่น (กันโกง) |

## โมเดลป้อมที่ import เอง (แทนป้อมโค้ด)
รายละเอียดเต็มอยู่หัวไฟล์ `src/server/Services/TurretLook.luau` (หัวข้อ "📦 วิธีทำโมเดลป้อมเอง")
1. Studio: สร้างโฟลเดอร์ `ServerStorage > TurretModels` · ใส่ Model ชื่อ `<ธาตุ>_<เลเวลขั้น>` เช่น `Fire_1` `Fire_10` `Fire_20` … `Fire_50` (ไม่มีขั้นนั้น → ใช้ขั้นต่ำกว่าที่ใกล้สุด → ชื่อ `Fire` เฉยๆ → ไม่มีเลย = ป้อมโค้ด) · ยังไม่เลือกธาตุ = `Unchosen`
2. ตั้งชื่อชิ้น: `Base` (ฐาน อยู่นิ่ง) · `Head` (หมุนซ้าย-ขวา · จุดหมุนเล็ง) · `Barrel` (ก้ม/เงย) · `Spin` (ไม่ใส่ก็ได้ หมุนรอบลำกล้อง) · `Glow` (ไม่ใส่ก็ได้ = สีธาตุเรืองแสง) · Attachment `Muzzle` ใต้ Barrel ที่ปากกระบอก (ไม่ใส่ก็ได้)
3. Pivot ของ Model ตั้งตรง ลูกศรหน้า (-Z) ชี้ไปทางปากกระบอก · เกมวางก้นโมเดลบนแท่น `TurretN` และหันไปทางบอสเอง
4. เกมตั้งให้เอง: Anchored ทุกชิ้น · ชิ้นที่ไม่ใช่ Base ไม่ชน · ลบ Script ในโมเดลทิ้ง · ขนาด → `Elements.CustomModel.Height` (ว่าง = ขนาดเดิม)
5. หน้าตาอัปทุก 10 เลเวล (`Elements.LookTiers`) → ถึงขั้นใหม่ เกมเปลี่ยนโมเดลให้เอง

## เพิ่มของใหม่
- **ไฟล์ใหม่**: วางใน `Services/` (Server) หรือ `Controllers/` / `UI/` (Client) ได้เลย ระบบโหลดให้อัตโนมัติ · ต้อง `return { Init = ..., Start = ... }`
- **ปุ่มใหม่ที่ส่งคำขอถึง Server**: ต้องเพิ่ม Remote ใน `src/shared/Remotes.luau` + รับผ่าน `Guard` ใน `src/server/Network/` → ให้ Claude ทำด้วย `/roblox-feature` ปลอดภัยกว่า

## ตรวจว่าแก้แค่คอมเมนต์
`python3 tools/check_comments_only.py` — ใช้หลังแก้คอมเมนต์ ถ้าเผลอแก้โค้ดจะบอกบรรทัดที่เปลี่ยน
