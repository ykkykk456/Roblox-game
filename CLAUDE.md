# Roblox Game — คู่มือหลักสำหรับ Claude

ไฟล์นี้โหลดอัตโนมัติทุกครั้ง = **Level 1 (Core)** ของ Progressive Context
เอกสารองค์กรฉบับเต็มอยู่ที่ `Roblox_AI_Org_By_Function/` — เปิดเฉพาะไฟล์ที่ต้องใช้ (Level 5) ไม่ต้องอ่านทั้งหมด

## โปรเจกต์
- เกม Roblox เขียนด้วย Luau · sync เข้า Studio ด้วย Rojo 7.7 (`default.project.json`) · **ห้ามใช้ MCP**
- Rojo sync ทางเดียว ไฟล์ → Studio: แก้โค้ดในไฟล์เท่านั้น
- ไฟล์นอก 3 โฟลเดอร์นี้จะ **ไม่เข้าเกม**:

| โฟลเดอร์ | Studio | ใส่อะไร |
|---|---|---|
| `src/server/` | ServerScriptService.Server | `Services/` ตรรกะเกม · `Network/` รับ Remote + validate · `Data/` DataStore |
| `src/shared/` | ReplicatedStorage.Shared | `Remotes.luau` · `Config/` ค่าคงที่/Balance/`Tags` · `Util/` เช่น `Tagged` (ผู้เล่นอ่านได้ ห้ามมีความลับ) |
| `src/client/` | StarterPlayerScripts.Client | `Controllers/` Input + ส่งคำขอ · `UI/` สร้าง ScreenGui ด้วยโค้ด |

- ใช้ `.luau` · มี Script ฝั่งละ 1 ตัว (`init.server.luau` / `init.client.luau`) ที่โหลดทุก ModuleScript ในโฟลเดอร์ย่อยให้อัตโนมัติ → **ไฟล์ใหม่เป็น ModuleScript เสมอ** คืนตาราง `{ Init = fn?, Start = fn? }`
- รายละเอียดครบ: `Roblox_AI_Org_By_Function/00_Organization_Core/ROBLOX_GUIDELINES.md`

## กฎเหล็ก (ย่อ — ฉบับเต็ม `PRINCIPLES.md`)
1. **Server Authority** — Client ส่ง "เจตนา" เท่านั้น Server คำนวณผล · ทุก Remote ต้องผ่าน `Guard` (type/range/สิทธิ์ + rate limit) · ห้ามเก็บเงิน/ไอเทมเป็นความจริงที่ Client
2. **Data Safety** — DataStore ครอบ `pcall` + retry · **โหลดไม่สำเร็จ = ห้ามบันทึกทับ** · มีค่าเริ่มต้นสำรอง · เปลี่ยน schema ต้องมี migration
3. **Evidence** — ข้อเท็จจริงสำคัญเรื่อง API/พฤติกรรม Roblox ติดป้าย `[Verified]` `[Inferred]` `[Assumed]` `[Proposed]` `[Unverified]` · ไม่แน่ใจ = `[Unverified]`
4. ข้อกำหนดขัดกัน/คลุมเครือ/ต้องละเมิดกฎ → **STOP and REPORT** (ไม่เดา) · ตัวเลขราคา/Balance ไม่ตัดสินเอง → ใช้ `src/shared/Config/`

## เลือกวิธีทำงาน
**Fast Lane** — ใช้เมื่อครบทุกข้อ: แตะไม่เกิน ~3 ไฟล์ · ไม่เพิ่ม Remote ใหม่ · ไม่เปลี่ยนโครงข้อมูล DataStore · ไม่แตะเงิน/ไอเทม/การซื้อ
→ ทำจบในรอบเดียว สวมบทบาทที่ต้องใช้ได้เอง → จบด้วย `/roblox-review` แบบย่อ → รายงาน 3 บรรทัด (ทำอะไร · ไฟล์ไหน · ความเสี่ยง)

**Full Workflow** — นอกจากนั้น ใช้ skill ตามงาน (แต่ละ step โหลด Skill บทบาทเฉพาะที่ต้องใช้):

| งาน | Skill |
|---|---|
| ฟีเจอร์ใหม่ (ระบบ + UI) | `/roblox-feature` |
| สร้าง/แก้หน้าจอ UI | `/roblox-ui` |
| แก้บั๊ก | `/roblox-bugfix` |
| ปรับราคา/Balance | `/roblox-economy` |
| สร้างแมพ/ฉาก/Level | `/roblox-map` |
| ตรวจก่อนส่งงาน (QA + Security) | `/roblox-review` |

ไม่แน่ใจว่างานเป็นของใคร → `Roblox_AI_Org_By_Function/00_Organization_Core/ROUTING_GUIDE.md`

## คำสั่งตรวจโค้ด (ถ้าติดตั้งเครื่องมือแล้วด้วย `aftman install`)
- `stylua src` จัดรูปแบบ · `selene src` ตรวจ lint · `rojo build -o build.rbxlx` ตรวจว่า Rojo อ่านโปรเจกต์ได้

## Git
- ทำงานบน branch ที่ได้รับมอบหมาย · commit ข้อความชัดเจน · ผู้ใช้ `git pull` แล้ว `rojo serve` จะ sync เข้า Studio เอง
