# SKILLS ARCHITECTURE — สารบัญ Specialist Skills

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Active — ทุก Skill เขียนเสร็จและใช้งานได้
**Progressive Context:** ไฟล์ Skill คือ **Level 3 (Skill / Procedure)** — โหลดเฉพาะ Skill ที่งานนั้นใช้ ไม่โหลดทั้งโฟลเดอร์ `Skills/`

> ไฟล์ Skill ทุกไฟล์มีเนื้อหาครบแล้ว (Scope, Non-Responsibilities, Roblox Context, Handoff Format)
> การแก้ไขเนื้อหา Skill ต้องได้รับอนุมัติจาก Gemini/CEO

---

## 1. ภาพรวม

- **8 แผนก · 17 Skills**
- ทุก Skill อยู่ที่ `<แผนก>/Skills/<Skill_Name>.md` และอยู่ในแผนกเดียว
- ใช้ชื่อ Skill ตามที่กำหนดเท่านั้น ห้ามเปลี่ยนชื่อ

---

## 2. สารบัญ Skills

Path ในตารางนับจาก `Roblox_AI_Org_By_Function/`

| # | แผนก | Skill | Path | สถานะ |
|---|---|---|---|---|
| 1 | `01_CEO` | Game_Director | `01_CEO/Skills/Game_Director.md` | Active |
| 2 | `02_Product_UX` | Systems_Designer | `02_Product_UX/Skills/Systems_Designer.md` | Active |
| 3 | `02_Product_UX` | UX_Architect | `02_Product_UX/Skills/UX_Architect.md` | Active |
| 4 | `03_Market_Data` | Player_Researcher | `03_Market_Data/Skills/Player_Researcher.md` | Active |
| 5 | `03_Market_Data` | Data_Analyst | `03_Market_Data/Skills/Data_Analyst.md` | Active |
| 6 | `04_CFO` | Economy_Designer | `04_CFO/Skills/Economy_Designer.md` | Active |
| 7 | `04_CFO` | Monetization_Strategist | `04_CFO/Skills/Monetization_Strategist.md` | Active |
| 8 | `05_CTO` | Architecture_Lead | `05_CTO/Skills/Architecture_Lead.md` | Active |
| 9 | `05_CTO` | Gameplay_Scripter | `05_CTO/Skills/Gameplay_Scripter.md` | Active |
| 10 | `05_CTO` | Client_UI_Scripter | `05_CTO/Skills/Client_UI_Scripter.md` | Active |
| 11 | `05_CTO` | DataStore_Backend | `05_CTO/Skills/DataStore_Backend.md` | Active |
| 12 | `05_CTO` | Networking_Specialist | `05_CTO/Skills/Networking_Specialist.md` | Active |
| 13 | `06_Art_Audio` | Visual_Director | `06_Art_Audio/Skills/Visual_Director.md` | Active |
| 14 | `06_Art_Audio` | Asset_Integrator | `06_Art_Audio/Skills/Asset_Integrator.md` | Active |
| 15 | `07_QA_Security` | QA_Tester | `07_QA_Security/Skills/QA_Tester.md` | Active |
| 16 | `07_QA_Security` | Security_Analyst | `07_QA_Security/Skills/Security_Analyst.md` | Active |
| 17 | `08_Operations` | Project_Router | `08_Operations/Skills/Project_Router.md` | Active |

**จำนวนต่อแผนก:** 01 (1) · 02 (2) · 03 (2) · 04 (2) · 05 (5) · 06 (2) · 07 (2) · 08 (1) = **17**

---

## 3. หมายเหตุสถาปัตยกรรม (Roblox-specific)

- `05_CTO` แยก `DataStore_Backend`, `Networking_Specialist` และ `Client_UI_Scripter` ออกจากกัน เพื่อรักษาความปลอดภัยแบบ Server Authority (`PRINCIPLES.md` ข้อ 1)

---

## 4. ข้อยุติที่เคยเป็น Open Item

- `Asset_Integrator` (`06_Art_Audio`): **ปิดแล้ว** — ดูแลทะเบียน Asset ID, สิทธิ์ และ Moderation เท่านั้น ไม่เขียนสคริปต์ งานนำ asset ไปใช้ในเกมเป็นของ `Gameplay_Scripter` / `Client_UI_Scripter` (`05_CTO`)
