# SKILLS ARCHITECTURE — สารบัญ Specialist Skills

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Phase 3 — Department → Skills Architecture
**Progressive Context:** ไฟล์ Skill คือ **Level 3 (Skill / Procedure)** — โหลดเฉพาะ Skill ที่งานนั้นใช้ ไม่โหลดทั้งโฟลเดอร์ `Skills/`

> โครงสร้างนี้เตรียมไว้สำหรับ Phase 4 (Skill Specification)
> ไฟล์ Skill ทุกไฟล์ยังเป็นโครงร่าง (`Pending Phase 4 Specification`) — ห้ามเพิ่มเนื้อหาก่อนได้รับอนุมัติ

---

## 1. ภาพรวม

- **8 แผนก · 17 Skills**
- ทุก Skill อยู่ที่ `Departments/<แผนก>/Skills/<Skill_Name>.md` และอยู่ในแผนกเดียว
- ใช้ชื่อ Skill ตามที่กำหนดเท่านั้น ห้ามเปลี่ยนชื่อ

---

## 2. สารบัญ Skills

Path ในตารางนับจาก `Departments/`

| # | แผนก | Skill | Path | สถานะ |
|---|---|---|---|---|
| 1 | `01_CEO` | Game_Director | `01_CEO/Skills/Game_Director.md` | Pending |
| 2 | `02_Product_UX` | Systems_Designer | `02_Product_UX/Skills/Systems_Designer.md` | Pending |
| 3 | `02_Product_UX` | UX_Architect | `02_Product_UX/Skills/UX_Architect.md` | Pending |
| 4 | `03_Market_Data` | Player_Researcher | `03_Market_Data/Skills/Player_Researcher.md` | Pending |
| 5 | `03_Market_Data` | Data_Analyst | `03_Market_Data/Skills/Data_Analyst.md` | Pending |
| 6 | `04_CFO` | Economy_Designer | `04_CFO/Skills/Economy_Designer.md` | Pending |
| 7 | `04_CFO` | Monetization_Strategist | `04_CFO/Skills/Monetization_Strategist.md` | Pending |
| 8 | `05_CTO` | Architecture_Lead | `05_CTO/Skills/Architecture_Lead.md` | Pending |
| 9 | `05_CTO` | Gameplay_Scripter | `05_CTO/Skills/Gameplay_Scripter.md` | Pending |
| 10 | `05_CTO` | Client_UI_Scripter | `05_CTO/Skills/Client_UI_Scripter.md` | Pending |
| 11 | `05_CTO` | DataStore_Backend | `05_CTO/Skills/DataStore_Backend.md` | Pending |
| 12 | `05_CTO` | Networking_Specialist | `05_CTO/Skills/Networking_Specialist.md` | Pending |
| 13 | `06_Art_Audio` | Visual_Director | `06_Art_Audio/Skills/Visual_Director.md` | Pending |
| 14 | `06_Art_Audio` | Asset_Integrator | `06_Art_Audio/Skills/Asset_Integrator.md` | Pending |
| 15 | `07_QA_Security` | QA_Tester | `07_QA_Security/Skills/QA_Tester.md` | Pending |
| 16 | `07_QA_Security` | Security_Analyst | `07_QA_Security/Skills/Security_Analyst.md` | Pending |
| 17 | `08_Operations` | Project_Router | `08_Operations/Skills/Project_Router.md` | Pending |

**จำนวนต่อแผนก:** 01 (1) · 02 (2) · 03 (2) · 04 (2) · 05 (5) · 06 (2) · 07 (2) · 08 (1) = **17**

---

## 3. หมายเหตุสถาปัตยกรรม (Roblox-specific)

- `05_CTO` แยก `DataStore_Backend`, `Networking_Specialist` และ `Client_UI_Scripter` ออกจากกัน เพื่อรักษาความปลอดภัยแบบ Server Authority (`PRINCIPLES.md` ข้อ 1)

---

## 4. Open Item สำหรับ Phase 4 `[Proposed]`

- `Asset_Integrator` (`06_Art_Audio`): ต้องกำหนดขอบเขตใน Phase 4 ให้สอดคล้องกับ `06_Art_Audio/DEPARTMENT_INFO.md` ซึ่งระบุว่างานนำ asset ไปประกอบใช้ในเกมเป็นของ `05_CTO`
