# ROUTING GUIDE — คู่มือเลือกไฟล์ Skill ให้ AI

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Active
**ผู้ใช้เอกสารนี้:** CEO / Game Owner เมื่อต้องเลือกไฟล์ Skill ป้อนให้ AI ทำงาน

> เอกสารนี้คือภาคปฏิบัติของหลัก **Progressive Context** ที่วางไว้ใน `ARCHITECTURE.md`
> ดูรายชื่อ Skill ทั้งหมดได้ที่ `00_Organization_Core/Index/SKILLS_ARCHITECTURE.md` และดู Template สถานการณ์สำเร็จรูปได้ที่โฟลเดอร์ `09_Workflows/`

---

## 1. ทำไมห้ามโหลดทั้ง 17 Skill พร้อมกัน (Token Efficiency)

- แต่ละ Skill คือ Persona เฉพาะทาง มี Scope, Non-Responsibilities และ Roblox Context ของตัวเอง — โหลดทุกไฟล์พร้อมกันแปลว่า Context ส่วนใหญ่ไม่เกี่ยวกับงานตรงหน้าเลย
- ยิ่ง Context ยาว AI ยิ่งเสีย Token ไปกับส่วนที่ไม่เกี่ยวข้อง และเสี่ยงสับสนบทบาท เช่น ทำตัวเป็น QA_Tester ทั้งที่กำลังขอให้เขียนสคริปต์
- Progressive Context (`ARCHITECTURE.md` หัวข้อ 4) กำหนดไว้แล้วว่าให้โหลดเฉพาะไฟล์ที่จำเป็น — คู่มือนี้บอกว่า "จำเป็น" แปลว่าไฟล์ไหนบ้างในแต่ละสถานการณ์
- ผลลัพธ์ที่ต้องการ: Context สั้น ตรงประเด็น ตรวจสอบย้อนกลับได้ว่างานอิงไฟล์ Skill ใด

---

## 2. วิธีใช้คู่มือนี้

ใช้ Claude Code: ส่วนใหญ่ **ไม่ต้องเลือกไฟล์เอง** — `CLAUDE.md` โหลดทุกครั้ง, กฎของโฟลเดอร์ใน `.claude/rules/` โหลดเองตามไฟล์ที่แก้, และ Workflow เป็น Skill ที่ Claude เรียกเองหรือพิมพ์สั่งได้

1. **Fast Lane** — งานเล็กที่ครบทุกข้อ: แตะไม่เกิน ~3 ไฟล์ · ไม่เพิ่ม Remote ใหม่ · ไม่เปลี่ยนโครงข้อมูล DataStore · ไม่แตะเงิน/ไอเทม/การซื้อ → สั่งงานตรงๆ ได้เลย Claude สวมบทบาทที่ต้องใช้เอง แล้วจบด้วย `/roblox-review` แบบย่อ
2. **ตรงกับ Workflow** → ใช้ Skill ในหัวข้อ 4 (แต่ละ Step โหลด Skill บทบาทเฉพาะที่ต้องใช้)
3. **ไม่ตรงกับอะไรเลย** → ใช้กฎการจับคู่ในหัวข้อ 3 ประกอบกับ `00_Organization_Core/Index/SKILLS_ARCHITECTURE.md`
4. **ไม่แน่ใจว่างานเป็นของใคร** → เริ่มจาก `08_Operations/Skills/Project_Router.md`

## 3. กฎการจับคู่ (Pairing Rules)

> หลักทั่วไป: ถ้า Skill ที่จะใช้ต้อง "คุยข้าม Client-Server" หรือ "ใช้ผลจากอีก Skill" ให้จับคู่ไฟล์ที่เกี่ยวข้องมาด้วยเสมอ

| ถ้ามี Skill นี้... | และงานเกี่ยวข้องกับ... | ต้องมี Skill นี้ด้วย |
|---|---|---|
| `Client_UI_Scripter` | การส่งคำขอไปยัง Server (ซื้อของ บันทึกค่า ฯลฯ) | `Networking_Specialist` |
| `Gameplay_Scripter` | รับคำขอจาก Client หรือส่งผลลัพธ์กลับ | `Networking_Specialist` |
| `Gameplay_Scripter` | บันทึก/อ่านข้อมูลถาวรของผู้เล่น | `DataStore_Backend` |
| `Networking_Specialist` | Remote ที่แก้ไขข้อมูลถาวร | `DataStore_Backend` |
| `UX_Architect` | ฟีเจอร์ใหม่ที่ต้องมีหน้าจอ | `Client_UI_Scripter` (และ `Visual_Director` ถ้าต้องกำหนดหน้าตา) |
| `Visual_Director` | asset ที่ต้องนำไปใช้ในเกมจริง | `Asset_Integrator` (จัดการ ID/สิทธิ์) ก่อนส่งต่อ `Client_UI_Scripter`/`Gameplay_Scripter` |
| `Economy_Designer` | ค่าที่ต้องบังคับใช้จริงในเกม | `DataStore_Backend` (implement) และ `Networking_Specialist` (ตรวจสอบขอบเขตค่า) |
| Skill ที่สร้าง/แก้ระบบใดๆ ใน `05_CTO` | งานใหม่ที่ยังไม่มีสเปกสถาปัตยกรรม | `Architecture_Lead` (ตรวจก่อนเริ่ม) |
| งานที่พร้อม implement แล้ว | ก่อนปล่อยเวอร์ชัน | `QA_Tester` และ `Security_Analyst` (บังคับคู่กันเสมอ) |
| ทุกงานที่เปลี่ยนมือข้าม Skill/แผนก | การส่งต่องาน | `Project_Router` เพื่อยืนยันเส้นทางและ Handoff |

**ข้อยกเว้น:** งานเชิงเอกสารล้วน (เช่น Game_Director ทำ Vision Doc, Player_Researcher ทำ Persona) ไม่ต้องจับคู่กับ Skill ฝั่ง Implementation

---

## 4. Workflow ที่มีให้แล้ว (Claude Skills)

| Skill | ใช้เมื่อ |
|---|---|
| `/roblox-design-thinking` | ยังไม่รู้จะสร้างอะไร หาไอเดีย หรือแก้ปัญหาผู้เล่น (Empathize → Define → Ideate → Prototype → Test) ก่อนส่งต่อ Workflow อื่น |
| `/roblox-feature` | สร้างฟีเจอร์ใหม่ตั้งแต่ต้น (มีทั้งระบบและ UI) |
| `/roblox-ui` | สร้างหรือแก้หน้าจอ UI |
| `/roblox-bugfix` | แก้บั๊กที่มีอยู่แล้ว |
| `/roblox-economy` | ปรับค่า Balance/เศรษฐกิจ |
| `/roblox-map` | สร้าง/แก้แมพ ฉาก และวัตถุในโลกเกม |
| `/roblox-review` | ตรวจงานก่อนส่ง (QA + Security + Data Safety รอบเดียว) |

ไฟล์อยู่ที่ `.claude/skills/<ชื่อ>/SKILL.md` (root ของ repo) · สารบัญ: `09_Workflows/README.md`
