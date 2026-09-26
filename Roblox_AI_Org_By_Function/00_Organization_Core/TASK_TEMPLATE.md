# TASK TEMPLATE

> คัดลอกเนื้อหาด้านล่างทั้งหมดไปใช้เป็นใบสั่งงานใหม่ 1 ชิ้น แล้วกรอกในวงเล็บ `[ ]`

```markdown
## Task ID & Title
- Task ID: [เช่น T-0001]
- Title: [ชื่องานสั้นๆ]

## Status
- [ ] Backlog
- [ ] In Progress
- [ ] QA
- [ ] Done

## Required Workflow & Skills
- Workflow ที่ใช้: [Fast Lane / /roblox-design-thinking / /roblox-feature / /roblox-ui / /roblox-bugfix / /roblox-economy / /roblox-map]
- ไฟล์ Skill ที่ต้องหยิบให้ AI อ่าน:
  - [<แผนก>/Skills/<Skill_Name>.md]
  - [<แผนก>/Skills/<Skill_Name>.md]

## Context & Objective
- เป้าหมายของงานนี้: [อธิบายสั้นๆ ว่าทำไปเพื่ออะไร]
- บริบทที่จำเป็นต้องรู้ก่อนเริ่ม: [ลิงก์/อ้างอิงเอกสารหรือ Task อื่นที่เกี่ยวข้อง]

## Evidence Status
| ข้อเท็จจริง/สมมติฐานสำคัญ | สถานะ | หมายเหตุ |
|---|---|---|
| [ข้อความ] | Verified / Inferred / Assumed / Proposed / Unverified | [แหล่งที่มา หรือเหตุผล] |

## Acceptance Criteria
- [ ] [เงื่อนไขที่ 1 ที่ต้องผ่าน]
- [ ] [เงื่อนไขที่ 2 ที่ต้องผ่าน]
- [ ] [เงื่อนไขที่ 3 ที่ต้องผ่าน]

## Handoff Notes
- ส่งต่อไปที่: [Skill/แผนกถัดไป หรือ "None"]
- สิ่งที่ต้องแนบไปด้วย: [ไฟล์/ข้อมูล/ผลลัพธ์ที่ต้องส่งมอบ]
- คำถามค้าง/ความเสี่ยง: [ระบุ หรือ "None"]
```

---

## หมายเหตุการใช้งาน (ไม่ต้องคัดลอกส่วนนี้)

- **Task ID & Title:** ระบุรหัสที่ไม่ซ้ำกันเพื่อใช้อ้างอิงข้ามเอกสาร
- **Status:** อัปเดตทุกครั้งที่งานเปลี่ยนขั้น ให้ตรงกับสถานะจริง
- **Required Workflow & Skills:** ดูวิธีเลือกได้จาก `ROUTING_GUIDE.md` · งาน Fast Lane ไม่ต้องระบุไฟล์ Skill
- **Evidence Status:** ทุกแถวต้องติดสถานะตาม `PRINCIPLES.md` (Verified / Inferred / Assumed / Proposed / Unverified) ห้ามเว้นว่าง
- **Acceptance Criteria:** ต้องตรวจสอบได้จริง ไม่ใช่ความเห็นเชิงอัตวิสัย
- **Handoff Notes:** เขียนตามแนวทาง Department Handoff Format ใน `ARCHITECTURE.md` ฉบับย่อสำหรับใบสั่งงานเดียว
