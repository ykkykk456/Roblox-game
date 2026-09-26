# ROBLOX GUIDELINES — มาตรฐานโค้ดสำหรับซิงค์ผ่าน Rojo

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Active — ตรงกับ `default.project.json` ของ repo (Rojo 7.7)
**เครื่องมือ:** VS Code, Git, Rojo (**ห้ามใช้ MCP**)

> เอกสารนี้กำหนดมาตรฐานทางเทคนิคที่ทุก Skill ใน `05_CTO` ต้องใช้เมื่อ implement โค้ดจริง
> ยึดคู่กับกฎเหล็กใน `PRINCIPLES.md` โดยเฉพาะ Server Authority และ Data Safety
> **แหล่งความจริงของการจับคู่โฟลเดอร์คือ `default.project.json`** — ถ้าเอกสารนี้ขัดกับไฟล์นั้น → STOP and REPORT

---

## 1. Rojo File Structure

Rojo อ่านนามสกุลไฟล์เพื่อตัดสินว่าจะสร้าง Instance ชนิดใดใน Studio การตั้งชื่อผิดจะได้ Instance ผิดชนิดโดยไม่มี error เตือน:

| นามสกุลไฟล์ | Instance ที่ Rojo สร้าง | ใช้เมื่อ |
|---|---|---|
| `.server.luau` | `Script` | เฉพาะ `src/server/init.server.luau` (จุดเริ่มต้นฝั่ง Server) |
| `.client.luau` | `LocalScript` | เฉพาะ `src/client/init.client.luau` (จุดเริ่มต้นฝั่ง Client) |
| `.luau` | `ModuleScript` | **โค้ดทุกไฟล์ที่เหลือ** (Service, Controller, Config, Util) |

**กฎการตั้งชื่อ**
- ใช้นามสกุล `.luau` เท่านั้น (ไม่ใช้ `.lua`) ให้ตรงกับไฟล์ที่มีอยู่ในโปรเจกต์
- **Single Entry Point:** ฝั่งละ 1 Script เท่านั้น — ห้ามสร้าง `.server.luau` / `.client.luau` เพิ่ม ให้เขียนเป็น ModuleScript แล้ว `require` จาก `init` แทน (ลำดับการโหลดคาดเดาได้ ไม่มี Script แข่งกันรัน)
- ไฟล์ชื่อ `init.*` ทำให้ **โฟลเดอร์นั้นกลายเป็น Instance ตัวเดียว** และไฟล์อื่นในโฟลเดอร์กลายเป็นลูกของมัน
  - `src/server/` → `Script` ชื่อ `Server` → อ้างลูกด้วย `script.Services.X`
  - `src/client/` → `LocalScript` ชื่อ `Client` → อ้างลูกด้วย `script.Controllers.X`
- ชื่อไฟล์ (ไม่รวมนามสกุล) = ชื่อ Instance ใน Studio ต้องตรงกับที่ระบุใน Feature Spec · ใช้ PascalCase

---

## 2. Directory Standard

การจับคู่จริงใน `default.project.json`:

| โฟลเดอร์ใน repo | Instance ใน Studio | ใครเข้าถึงได้ |
|---|---|---|
| `src/server/` | `ServerScriptService.Server` | Server เท่านั้น |
| `src/shared/` | `ReplicatedStorage.Shared` | Server และ Client |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` | Client (ของผู้เล่นแต่ละคน) |

> **ไฟล์ที่อยู่นอก 3 โฟลเดอร์นี้ Rojo จะไม่ sync เข้า Studio** (ไฟล์ยังอยู่ใน VS Code แต่ไม่เข้าเกม)

โครงสร้างภายในที่กำหนด:

```
src/
├── server/                              → ServerScriptService.Server
│   ├── init.server.luau                 # จุดเริ่มต้น: require และเรียก Init() ของทุก Service
│   ├── Services/<Feature>Service.luau    # Gameplay_Scripter: ตรรกะเกมฝั่ง Server
│   ├── Network/<Feature>Handler.luau    # Networking_Specialist: รับ Remote + validate + rate limit
│   └── Data/<Name>Store.luau            # DataStore_Backend: โหลด/บันทึกข้อมูลถาวร
├── shared/                              → ReplicatedStorage.Shared
│   ├── Remotes.luau                     # Networking_Specialist: รายชื่อ Remote ทั้งหมดของเกม (ที่เดียว)
│   ├── Config/<Name>.luau               # ค่าคงที่ เช่น ราคา/Balance จาก Economy_Designer
│   └── Util/<Name>.luau                 # ฟังก์ชันที่ไม่มีผลต่อความปลอดภัย
└── client/                              → StarterPlayer.StarterPlayerScripts.Client
    ├── init.client.luau                 # จุดเริ่มต้น: require และเรียก Init() ของทุก Controller
    ├── Controllers/<Feature>Controller.luau  # Client_UI_Scripter: รับ Input / ส่งคำขอ
    └── UI/<Feature>UI.luau              # Client_UI_Scripter: สร้าง ScreenGui ลง PlayerGui ด้วยโค้ด
```

**กฎการวาง**
- ตรรกะเกม ข้อมูลลับ และการเข้าถึง DataStore → `src/server/` เท่านั้น (Client มองไม่เห็น ServerScriptService)
- สิ่งที่ใช้ร่วมทั้งสองฝั่งและ**ไม่เป็นความลับ** → `src/shared/` (ผู้เล่นอ่านโค้ดในนี้ได้ทั้งหมด)
- Remote ทุกตัวประกาศชื่อไว้ที่ `src/shared/Remotes.luau` ที่เดียว ฝั่ง Server สร้าง Instance ตอนเริ่มเกม ฝั่ง Client ใช้ `WaitForChild`
- UI สร้างด้วยโค้ดใน `src/client/UI/` (ยังไม่มีการจับคู่ `StarterGui`)
- ต้องการโฟลเดอร์ใหม่ที่ Rojo ยังไม่รู้จัก (เช่น `ServerStorage` สำหรับโมเดล, `StarterGui`) → Architecture_Lead เสนอแก้ `default.project.json` พร้อมอัปเดตตารางด้านบน **ก่อน** วางไฟล์

---

## 3. Security Rules

**หลักการหลัก: Never trust the client** — ยึดตาม `PRINCIPLES.md` กฎเหล็กข้อ 1 (Roblox Security / Server Authority)

- Client ทำได้เพียง 3 อย่าง: รับ Input, แสดงผล, ส่งคำขอผ่าน Remote — **ห้ามให้ Client ตัดสินผลลัพธ์ของเกมเอง**
- ทุก `RemoteEvent`/`RemoteFunction` ต้องมีการ validate ที่ฝั่ง Server (โค้ดใน `src/server/`) ก่อนประมวลผลเสมอ ไม่มีข้อยกเว้น โดยตรวจอย่างน้อย:
  - ชนิดข้อมูล (type) ตรงตามที่กำหนด
  - ช่วงค่า (range) อยู่ในขอบเขตที่ Economy_Designer/Systems_Designer ระบุ
  - สิทธิ์ของผู้เรียก (permission) เช่น เป็นเจ้าของไอเทมจริงหรือไม่
- ใช้ `RemoteEvent` เป็นค่าเริ่มต้น หลีกเลี่ยง `RemoteFunction` เว้นแต่จำเป็น เพราะเสี่ยง Client ทำให้ Server รอ (yield) นานเกินควร
- ต้องมี rate limiting ต่อผู้เล่นต่อ Remote เพื่อป้องกัน spam/exploit จากเครื่องมือฝั่ง Client
- ข้อมูลถาวรของผู้เล่น (ผ่าน `DataStoreService`) ต้อง validate ก่อนบันทึกทุกครั้ง และห้ามบันทึกทับข้อมูลเดิมเมื่อโหลดล้มเหลว ตาม Data Safety ใน `PRINCIPLES.md`
- ห้ามใช้การซ่อน/บดบังโค้ด (obfuscation) แทนการตรวจสอบฝั่ง Server — Security_Analyst ถือว่าไม่ผ่านหากพบรูปแบบนี้

---

## 4. เส้นทางของโค้ดจาก AI → VS Code → Studio

Rojo sync **ทางเดียว**: ไฟล์ใน `src/` → Studio · สิ่งที่แก้ในสคริปต์ใน Studio **จะไม่ถูกบันทึกกลับ** และจะถูกทับเมื่อไฟล์เปลี่ยน → แก้โค้ดในไฟล์เท่านั้น

| วิธีที่ AI ทำงาน | ขั้นตอนให้โค้ดเข้า Studio |
|---|---|
| AI รันบนเครื่องเดียวกับ VS Code (เช่น Claude Code ใน VS Code / Terminal, Cursor) | AI แก้ไฟล์ใน `src/` → `rojo serve` ที่เปิดค้างไว้ sync เข้า Studio ทันที |
| AI รันบน Cloud (เช่น Claude Code บนเว็บ/แอป) | AI commit + push ไปที่ branch → กด `git pull` ใน VS Code → Rojo sync ทันที |

**การเตรียมเครื่อง (ครั้งเดียว)**
1. `aftman install` (ติดตั้ง Rojo ตาม `aftman.toml`) และติดตั้ง Rojo Plugin ใน Studio
2. เปิดโปรเจกต์ใน VS Code → รัน `rojo serve` ที่ root ของ repo
3. ใน Studio → แท็บ Plugins → Rojo → **Connect**

**กฎ**
- ทุกการเปลี่ยนแปลงโค้ดต้องผ่าน Git เพื่อให้ตรวจสอบย้อนกลับได้
- ก่อนส่งงาน Skill ใน `05_CTO` ต้องตรวจว่าไฟล์ทุกไฟล์อยู่ใต้ `src/server`, `src/shared` หรือ `src/client` และนามสกุลตรงตามหัวข้อ 1

---

## 5. โค้ดแม่แบบที่มีในโปรเจกต์ (ใช้ต่อ ห้ามเขียนซ้ำ)

| ไฟล์ | หน้าที่ | วิธีใช้ |
|---|---|---|
| `src/server/init.server.luau` / `src/client/init.client.luau` | โหลดทุก ModuleScript ในโฟลเดอร์ย่อยอัตโนมัติ แล้วเรียก `Init()` ทุกตัว ตามด้วย `Start()` | วางไฟล์ใหม่ในโฟลเดอร์ แล้วคืน `{ Init = fn?, Start = fn? }` ไม่ต้องลงทะเบียน |
| `src/shared/Remotes.luau` | ทะเบียน Remote ที่เดียว | เพิ่มชื่อในตาราง `NAMES` · เรียกใช้ `Remotes.get("ชื่อ")` |
| `src/server/Network/Guard.luau` | rate limit + ตรวจชนิด/จำนวน argument + กัน NaN/inf/string ยาว | `Guard.connect(remote, { rate, per, args }, handler)` · handler ตรวจช่วงค่า/สิทธิ์ต่อด้วย `Guard.inRange` / `Guard.isInteger` |
| `src/server/Data/PlayerData.luau` | โหลด/บันทึกข้อมูลผู้เล่นอย่างปลอดภัย (retry, ไม่บันทึกทับเมื่อโหลดล้ม, migration, autosave, BindToClose) | `PlayerData.get(player)` · `PlayerData.update(player, function(data) ... end)` · field ใหม่เพิ่มใน `DEFAULT` |
| `src/shared/Config/Economy.luau` | ตัวเลขเศรษฐกิจทั้งหมด | Economy_Designer แก้ที่นี่ที่เดียว |
| `src/shared/Config/Tags.luau` + `src/shared/Util/Tagged.luau` | เชื่อมชิ้นส่วนที่สร้างมือใน Studio กับโค้ด | ประกาศ tag ใน `Tags` · `Tagged.each(Tags.X, function(part) ... end)` |

ลำดับโหลดฝั่ง Server: `Data/` → `Network/` → `Services/` (ข้อมูลพร้อมก่อน Remote และตรรกะเกม)

## 6. เครื่องมือตรวจโค้ด

ติดตั้งด้วย `aftman install` (เวอร์ชันกำหนดใน `aftman.toml`)

| คำสั่ง | ตรวจอะไร | ตั้งค่า |
|---|---|---|
| `stylua src` (`--check` เพื่อตรวจอย่างเดียว) | รูปแบบโค้ด (Tab, ความยาวบรรทัด 120) | `stylua.toml` |
| `selene src` | lint เช่น ตัวแปรไม่ได้ใช้ ใช้ API ผิด | `selene.toml` (`std = "roblox"`) |
| `rojo build -o build.rbxlx` | Rojo อ่านโปรเจกต์และไฟล์ทั้งหมดได้ | `default.project.json` |

## 7. แมพและวัตถุใน Workspace

**ตัดสินแล้ว (CEO): สร้างมือผสมโค้ด** — รายละเอียดใน `.claude/skills/roblox-map/SKILL.md`
- รูปทรงซับซ้อน/ตกแต่ง → สร้างมือใน Studio (ไม่อยู่ใน Git → Publish to Roblox เป็นประจำ)
- ของที่ซ้ำหรือวางตามกฎ → สร้างด้วยโค้ดใน `src/server/Services/`
- เชื่อมของที่สร้างมือกับโค้ดผ่าน CollectionService tag (`src/shared/Config/Tags.luau`) + Attribute และ `src/shared/Util/Tagged.luau` · ห้ามอ้างชื่อหรือตำแหน่งชิ้นส่วน

**แมพปัจจุบัน: หลุมอุกกาบาต v2** (`design/crater-map.md`) — พื้นเป็น `Workspace.MapGround` (Rojo sync จาก `map/ground.project.json` · สร้างด้วย `python3 tools/gen_map.py` → เห็นในโหมดแก้ไข) · ฐานสร้างด้วยโค้ดใน `MapService` จาก `src/shared/Config/Map.luau`
| ส่วน | ขนาด (stud) | หมายเหตุ |
|---|---|---|
| พื้น | วงกลมรัศมี 400 (`Map.Radius`) บล็อก 16×16 · ผิวบนที่ Y = 1 | `Map.GroundY` · ระบบอื่นอ้างความสูงพื้นจากค่านี้ |
| แอ่งกลาง | รัศมี 100 · ลึก 1–3 ขั้น | จุดบอสเกิด + ที่เก็บของ · tag `LootZone` · `PitService` ปิดตอนบอสมา |
| ถนนวงแหวน | รัศมี 100–130 | จุดที่ผู้เล่นถูกย้ายไปเมื่อบอสมา |
| ฐาน | 110 × 110 ห่างกลาง 200 · ป้อมห่างกลาง 140 | `Map.BaseCount` ฐาน (สูงสุด 8) · ชิ้นในฐานติด tag + Attribute `BaseSlot` |
| สวนหลังบ้าน | รูปพัด ±18° รัศมี 260–350 | tag `MonsterYard` (มอนไม่เกิดที่นี่แล้ว) |
| เลนมอน | 8 เลนตามแนวฐาน รัศมี 12–134 กว้าง 20 | มอนเกิดกลางแอ่งเป็น wave เดินไปหาป้อม (`Config/Map.Lane`) |

แก้ขนาดพื้น/แอ่ง/ถนน = แก้ `tools/gen_map.py` + `Config/Map.luau` ให้ตรงกัน แล้วรัน `python3 tools/gen_map.py` · แก้ฐาน = `Config/Map.luau` (ของใน Folder `Map` ถูกสร้างใหม่ทุกครั้งที่ Server เริ่ม แก้ใน Studio จะหายตอนกด Play)

## 8. โมเดล/อนิเมชันที่เจ้าของเกมนำเข้าเองใน Studio
- โมเดลที่ต้อง Clone ตอนเกมรัน (เช่นบอส) → วางใน **ServerStorage** (Rojo ไม่ยุ่ง ไม่ลบ/ไม่เขียนทับ) · บอส: `ServerStorage/Bosses/<Combat.Boss.Model>`
- โค้ดที่ Clone ต้องลบ `Script`/`LocalScript` ที่ติดมากับโมเดลเสมอ (กันสคริปต์แฝง) · ไม่มีโมเดล = มีตัวสำรองจากโค้ด เกมไม่พัง
- จัดโมเดลบอส/ตรวจริก R15 ใน Studio: วาง `tools/studio/setup_slambot.lua` ใน **View → Command Bar** (สร้าง `Bosses`, ย้ายโมเดล, สร้าง `Animations/Idle|Walk|Slam`, รายงานปัญหาใน Output)
- ID ท่าบอสใส่ได้ที่ AnimationId ของ `ServerStorage/Bosses/<Model>/Animations/<ท่า>` ใน Studio หรือ `Combat.Boss.Animations` (Config ชนะถ้าไม่ใช่ 0)
- อนิเมชัน: Publish ให้ **เจ้าของเดียวกับเกม** (เกมเป็นของ Group → Publish เข้า Group) `[Inferred]` · ใส่เลข Animation ID ใน `src/shared/Config/` (เช่น `Combat.Boss.Animations`) ไม่ hard-code ในสคริปต์
- ความละเอียด: < 10,000 สามเหลี่ยมต่อชิ้นสำหรับมือถือ (สูงสุด ~20,000) `[Unverified]`
