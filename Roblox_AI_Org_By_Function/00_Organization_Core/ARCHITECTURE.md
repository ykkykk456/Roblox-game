# ARCHITECTURE — สถาปัตยกรรมองค์กร

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Active — ใช้งานจริง (Phase 0–8 เสร็จแล้ว)
**ขอบเขต:** พัฒนาเกม Roblox เท่านั้น

> เอกสารนี้คู่กับ `ROLES.md` และ `PRINCIPLES.md` เป็นกฎสูงสุดขององค์กร
> หากเนื้อหาในเอกสารทั้งสามขัดแย้งกัน ให้ใช้ขั้นตอน **STOP and REPORT** ใน `ROLES.md`
> ป้าย `[Proposed]` หมายถึงข้อเสนอที่รอการอนุมัติจาก Gemini/CEO (นิยามใน `PRINCIPLES.md`)

---

## 1. วัตถุประสงค์

- กำหนดโครงสร้างและวิธีทำงานร่วมกันขององค์กร AI ที่พัฒนาเกม Roblox
- ทำให้ทุกบทบาทรู้ตรงกันว่า **อะไรอยู่ที่ไหน**, **ต้องโหลดอะไรเมื่อไหร่**, และ **ส่งต่องานอย่างไร**

---

## 2. เสาหลักของสถาปัตยกรรม

| เสาหลัก | สาระสำคัญ | ดูรายละเอียด |
|---|---|---|
| Progressive Context | โหลดเฉพาะไฟล์ที่จำเป็น เลิกโหลดไฟล์รวมทั้งหมด | หัวข้อ 4 |
| Roblox Server Authority | Server เป็นผู้ตัดสินเพียงผู้เดียว | `PRINCIPLES.md` ข้อ 1 |
| Evidence System | ทุกข้อเท็จจริงสำคัญต้องมีสถานะหลักฐาน | `PRINCIPLES.md` ข้อ 3 |
| Department Handoff Format | ส่งต่องานด้วยรูปแบบมาตรฐานเดียว | หัวข้อ 5 |

---

## 3. โครงสร้างโฟลเดอร์

> **กฎการอ้าง path:** path ของเอกสารองค์กรนับจาก `Roblox_AI_Org_By_Function/` · path ของโค้ดเกมนับจาก root ของ repo (เช่น `src/server/...`)

```
<repo root>/
├── CLAUDE.md                     # Level 1 สำหรับ Claude: กฎย่อ + โครงสร้าง + วิธีเลือก Workflow (โหลดทุกครั้ง)
├── .claude/
│   ├── rules/                    # กฎตามโฟลเดอร์ โหลดเองเมื่อแก้ src/server | src/shared | src/client
│   └── skills/                   # Workflow เป็น Skill: /roblox-feature, -ui, -bugfix, -economy, -map, -review
├── default.project.json          # แผนที่ Rojo: โฟลเดอร์ src/ → Instance ใน Studio
├── aftman.toml                   # เวอร์ชันเครื่องมือ (Rojo)
├── src/                          # โค้ดเกมทั้งหมด (Level 4) — ดู ROBLOX_GUIDELINES.md
│   ├── server/                   # → ServerScriptService.Server
│   ├── shared/                   # → ReplicatedStorage.Shared
│   └── client/                   # → StarterPlayer.StarterPlayerScripts.Client
└── Roblox_AI_Org_By_Function/    # เอกสารองค์กร (ไฟล์นี้อยู่ที่นี่)
    ├── 00_Organization_Core/     # Level 1: ARCHITECTURE, ROLES, PRINCIPLES, ROBLOX_GUIDELINES,
    │   │                         #          ROUTING_GUIDE, TASK_TEMPLATE
    │   └── Index/                # สารบัญ: DEPARTMENTS_ARCHITECTURE, SKILLS_ARCHITECTURE
    ├── 01_CEO/ … 08_Operations/  # แต่ละแผนก: DEPARTMENT_INFO.md (Level 2) + Skills/*.md (Level 3)
    └── 09_Workflows/             # สารบัญ Workflow (ตัวจริงอยู่ที่ .claude/skills/)
```

| โฟลเดอร์ | หน้าที่ |
|---|---|
| `00_Organization_Core/` | เอกสารรากฐานและคู่มือกลางขององค์กร |
| `01_CEO/` – `08_Operations/` | 8 แผนก ชื่อโฟลเดอร์ = รหัสแผนกที่ใช้อ้างในเอกสาร (เช่น `05_CTO`) |
| `09_Workflows/` | สารบัญ Workflow → ชี้ไป `.claude/skills/` |
| `CLAUDE.md`, `.claude/` (ที่ root ของ repo) | ตัวเชื่อมให้ Claude Code โหลด Context ตามระดับอัตโนมัติ |
| `src/` (ที่ root ของ repo) | โค้ด Luau ที่ Rojo sync เข้า Roblox Studio |

- ห้ามเพิ่มโฟลเดอร์หรือไฟล์ใหม่ใน `Roblox_AI_Org_By_Function/` โดยไม่ได้รับอนุมัติจาก Gemini/CEO
- การเพิ่มไฟล์โค้ดใน `src/` ทำได้ตามสเปก โดยต้องเป็นไปตาม `ROBLOX_GUIDELINES.md`

---

## 4. Progressive Context System

### 4.1 หลักการ

- โหลดเฉพาะไฟล์ที่จำเป็นต่อภารกิจตรงหน้า
- **เลิกโหลดไฟล์รวมทั้งหมด** (ห้ามมีไฟล์รวมยักษ์ที่ต้องโหลดทุกครั้ง)
- ผลที่ต้องการ: Context เล็ก โฟกัสชัด ไม่ปนข้อมูลที่ไม่เกี่ยวข้อง และตรวจย้อนกลับได้ว่างานอิงไฟล์ใด

### 4.2 ระดับของ Context (Level 1–5)

| Level | ชื่อ | เนื้อหา | ตำแหน่ง | เมื่อไหร่ที่โหลด |
|---|---|---|---|---|
| 1 | Organization Core | กฎย่อและโครงสร้างที่ต้องรู้ทุกงาน | `CLAUDE.md` (ฉบับเต็มใน `00_Organization_Core/` ถือเป็น Level 5) | ทุกครั้ง (อัตโนมัติ) |
| 2 | Department Context | ขอบเขตและกติกาของหน่วยงานที่เกี่ยวข้อง | `<แผนก>/DEPARTMENT_INFO.md` | เฉพาะหน่วยงานที่งานนั้นเกี่ยวข้อง |
| 3 | Skill / Procedure | Workflow, กฎตามโฟลเดอร์ และบทบาทเฉพาะทาง | `.claude/skills/`, `.claude/rules/`, `<แผนก>/Skills/<Skill>.md` | Workflow: เมื่องานตรง · rules: เมื่อแก้ไฟล์ในโฟลเดอร์นั้น · บทบาท: เฉพาะ Step ที่ใช้ |
| 4 | Project Context | สถานะ การตัดสินใจ และสเปกของโปรเจกต์ปัจจุบัน | `src/` และ `default.project.json` (root ของ repo) | เฉพาะไฟล์ที่งานนั้นแตะต้อง |
| 5 | Reference & Detail | รายละเอียดเชิงลึก เช่น เอกสารอ้างอิง ข้อมูลดิบ ผลงานเดิม | ระบุเป็นรายกรณี | On-demand เท่านั้น ทีละไฟล์ที่ระบุชัดเจน |

### 4.3 กฎการโหลด

1. **Level 1 (`CLAUDE.md`) โหลดเสมอ** ส่วน Level 2–5 โหลดเมื่อจำเป็นต่อภารกิจเท่านั้น · Level 2 (`DEPARTMENT_INFO.md`) ใช้เมื่อต้องตัดสินเรื่องขอบเขตแผนกเท่านั้น ไม่ต้องโหลดตอนเขียนโค้ด
2. โหลดเฉพาะไฟล์ที่ระบุในหัวข้อ Context ของ Handoff
3. ต้องการข้อมูลที่ไม่ได้โหลด → ร้องขอ **ไฟล์นั้นโดยเฉพาะ** ไม่ใช่โหลดทั้งโฟลเดอร์
4. ทุก Handoff ต้องระบุไฟล์และ Level ที่โหลด เพื่อตรวจสอบย้อนกลับได้
5. ไฟล์แต่ละไฟล์ควรเล็กและโฟกัสเรื่องเดียว

### 4.4 สิ่งที่ห้ามทำ (Anti-patterns)

- รวมทุกอย่างเป็นไฟล์เดียวหรือไฟล์รวมขนาดใหญ่
- โหลดทั้งโฟลเดอร์หรือทั้งระดับ "เผื่อไว้"
- โหลดรายละเอียด Level 5 โดยไม่มีคำขอที่ระบุไฟล์ชัดเจน

---

## 5. Department Handoff Format

### 5.1 เมื่อไหร่ต้องใช้

- **Handoff เต็ม (8 หัวข้อ):** งานส่งต่อข้ามเซสชัน/ข้าม AI, ส่งให้ Gemini/CEO ตัดสิน, หรือ Escalation
- **Handoff ย่อ:** ส่งต่อระหว่าง Step ใน Workflow เดียวกันในเซสชันเดียว และงาน Fast Lane — เขียน 3 บรรทัด:
  - `Context:` ไฟล์ที่เกี่ยวข้อง/สิ่งที่ทำแล้ว
  - `Output:` สิ่งที่ Step ถัดไปต้องส่งมอบ
  - `Risks:` ความเสี่ยง/คำถามค้าง (ไม่มีให้เขียน None)

### 5.2 หัวข้อที่ต้องมี

| # | หัวข้อ | สถานะ | ความหมาย |
|---|---|---|---|
| 1 | Source | บังคับ | ผู้ส่งมอบและขั้นตอนที่งานมาจาก |
| 2 | Target | บังคับ | ผู้รับมอบและขั้นตอนที่งานไปต่อ |
| 3 | Context | บังคับ | ไฟล์/Level ที่ต้องโหลด และสรุปสถานการณ์ที่จำเป็น |
| 4 | Decision | บังคับ | สิ่งที่ตัดสินใจแล้ว ใครตัดสิน และสิ่งที่ยังไม่ตัดสิน |
| 5 | Constraints | แนะนำ `[Proposed]` | ข้อจำกัดที่ต้องปฏิบัติตาม |
| 6 | Evidence | แนะนำ `[Proposed]` | ข้อเท็จจริงสำคัญพร้อมสถานะหลักฐาน |
| 7 | Expected Output | บังคับ | ผลลัพธ์ รูปแบบ และเกณฑ์ตรวจรับ |
| 8 | Open Questions / Risks | แนะนำ `[Proposed]` | คำถามค้างและความเสี่ยง (ไม่มีให้ระบุ "None") |

### 5.3 Template

```markdown
# DEPARTMENT HANDOFF

## 1. Source
- ผู้ส่งมอบ: <หน่วยงาน/บทบาทที่ส่งต่องาน>
- ขั้นตอน Workflow: <เช่น Research>

## 2. Target
- ผู้รับมอบ: <หน่วยงาน/บทบาทที่รับงาน>
- ขั้นตอน Workflow ถัดไป: <เช่น Design>

## 3. Context
- ไฟล์ที่ต้องโหลด:
  - Level <n>: <path/ไฟล์>
- สรุปสถานการณ์: <สั้น กระชับ เฉพาะที่ผู้รับจำเป็นต้องรู้>

## 4. Decision
- ตัดสินใจแล้ว: <รายการ>
- ผู้ตัดสินใจ: <CEO / Gemini>
- ยังไม่ตัดสินใจ: <รายการ หรือ "None">

## 5. Constraints
- <ข้อจำกัดที่ต้องปฏิบัติตาม เช่น Server Authority, ห้ามใช้ MCP, ขอบเขตงาน>

## 6. Evidence
| ข้อเท็จจริงสำคัญ | สถานะ | แหล่งที่มา |
|---|---|---|
| <...> | Verified / Inferred / Assumed / Proposed / Unverified | <...> |

## 7. Expected Output
- ผลลัพธ์ที่ต้องส่งมอบ: <...>
- รูปแบบ/ตำแหน่งไฟล์: <...>
- เกณฑ์ตรวจรับ: <...>

## 8. Open Questions / Risks
- <คำถามค้างหรือความเสี่ยง หรือ "None">
```

### 5.4 กฎการใช้

- Handoff หนึ่งฉบับ ต่อหนึ่งเป้าหมาย และหนึ่งผู้รับ
- Handoff เต็มห้ามขาดหัวข้อบังคับ
- ผู้รับพบว่า Handoff ไม่ครบหรือขัดแย้ง → **STOP and REPORT** (ดู `ROLES.md`)
- สถานะในหัวข้อ Evidence ต้องเป็นไปตามนิยามใน `PRINCIPLES.md`

---

## 6. Development Workflow

```
Idea → Research → Design → Implementation → Validation → Data
```

> `[Proposed]` — Brief ระบุ Workflow เป็น "Idea → Research → … → Data" ขั้นตอนตรงกลางเป็นข้อเสนอที่รอการยืนยัน

| # | ขั้นตอน | จุดประสงค์ | ผลลัพธ์ |
|---|---|---|---|
| 1 | Idea | นิยามแนวคิดและความต้องการ | แนวคิดพร้อมเป้าหมายที่ชัดเจน |
| 2 | Research | ศึกษาข้อเท็จจริงและข้อจำกัดของ Roblox ที่เกี่ยวข้อง | ผลวิจัยที่ติดสถานะ Evidence ครบ |
| 3 | Design | ออกแบบวิธีทำให้สอดคล้องกับ Server Authority และ Data Safety | สเปกที่ได้รับอนุมัติ |
| 4 | Implementation | สร้างตามสเปกทุกประการ ภายในขอบเขตที่กำหนด | ผลงานที่สร้างเสร็จ |
| 5 | Validation | ตรวจตามเกณฑ์ตรวจรับ รวมถึง Security และ Data Safety | รายงานผลการตรวจสอบ |
| 6 | Data | ขั้นสุดท้ายตามที่ระบุใน Brief `[Assumed]` สมมติว่าหมายถึงการจัดการและวิเคราะห์ข้อมูลที่เกิดจากผลงาน | รอ Gemini/CEO ยืนยันความหมาย |

**กฎของ Workflow**
- ทุกการเปลี่ยนขั้นตอนต้องใช้ Department Handoff Format
- ผลงานของแต่ละขั้นต้องผ่านเกณฑ์ตรวจรับก่อนส่งต่อ
- Server Authority และ Data Safety ต้องถูกตรวจตั้งแต่ขั้น Design เป็นต้นไป
- ย้อนกลับไปขั้นก่อนหน้าได้เมื่อพบปัญหา โดยต้องมี Handoff ระบุเหตุผล

---

## 7. ข้อจำกัดที่ใช้ทั้งองค์กร

- พัฒนาเกม **Roblox เท่านั้น**
- **ห้ามใช้ MCP เด็ดขาด** (รายละเอียดใน `PRINCIPLES.md`)
- ทุกงานต้องเป็นไปตามกฎเหล็ก 3 ข้อใน `PRINCIPLES.md`

---

## 8. สถานะปัจจุบันขององค์กร

| Phase | เนื้อหา | สถานะ |
|---|---|---|
| 0 | Master Architecture (ไฟล์นี้, `ROLES.md`, `PRINCIPLES.md`) | เสร็จ |
| 1 | 8 แผนก (`DEPARTMENT_INFO.md`) | เสร็จ |
| 3–4 | 17 Skills (`<แผนก>/Skills/`) | เสร็จ — ใช้งานได้ |
| 5–6 | `ROUTING_GUIDE.md` และ Workflow | เสร็จ |
| 9 | เชื่อมกับ Claude Code (`CLAUDE.md`, `.claude/rules`, `.claude/skills`), Fast Lane, Handoff ย่อ, โค้ดแม่แบบใน `src/` | เสร็จ |
| 7–8 | `TASK_TEMPLATE.md` และ `ROBLOX_GUIDELINES.md` (Rojo) | เสร็จ |

- **การเขียนโค้ด Luau อยู่ในขอบเขตแล้ว** — Skill ใน `05_CTO` เขียนโค้ดลง `src/` ได้ตามสเปก โดยยึด `ROBLOX_GUIDELINES.md`
- ขั้น Data ใน Development Workflow (หัวข้อ 6) ยังรอ Gemini/CEO ยืนยันความหมาย
