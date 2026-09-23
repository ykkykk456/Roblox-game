---
name: roblox-feature
description: Workflow สร้างฟีเจอร์เกม Roblox ใหม่ตั้งแต่ต้นที่มีทั้งระบบฝั่ง Server, Remote และ UI (เช่น ระบบภารกิจ ร้านค้า คราฟไอเทม) ใช้เมื่อผู้ใช้ขอฟีเจอร์ใหม่ที่ใหญ่เกิน Fast Lane
---

# NEW FEATURE WORKFLOW

ก่อนเริ่ม: ถ้างานผ่านเกณฑ์ **Fast Lane** ใน `CLAUDE.md` → ไม่ต้องใช้ workflow นี้
แต่ละ Step **เปิดเฉพาะไฟล์ในช่อง "โหลด"** (path นับจาก `Roblox_AI_Org_By_Function/`) · ผลของแต่ละ Step เขียนสั้นๆ ต่อท้ายใน Feature Spec ไม่ต้องทำ Handoff 8 หัวข้อ

| Step | บทบาท | โหลด | ผลลัพธ์ |
|---|---|---|---|
| 1 | Systems_Designer | `02_Product_UX/Skills/Systems_Designer.md` | Feature Spec: กฎของระบบ + เกณฑ์ตรวจรับที่ทดสอบได้ + ค่าที่ต้องใช้ใน Config |
| 2 | UX_Architect *(ข้ามถ้าไม่มีหน้าจอ)* | `02_Product_UX/Skills/UX_Architect.md` | โครงหน้าจอ + flow + การควบคุมต่ออุปกรณ์ |
| 3 | Architecture_Lead | `05_CTO/Skills/Architecture_Lead.md` | รายการไฟล์ที่จะสร้าง (ตามโฟลเดอร์ใน `CLAUDE.md`) + รายชื่อ Remote + ข้อมูลที่ต้องบันทึก |
| 4 | Networking_Specialist | `05_CTO/Skills/Networking_Specialist.md` | เพิ่มชื่อใน `src/shared/Remotes.luau` + `src/server/Network/<Feature>Handler.luau` ผ่าน `Guard` |
| 5 | Gameplay_Scripter | `05_CTO/Skills/Gameplay_Scripter.md` | `src/server/Services/<Feature>Service.luau` |
| 5b | DataStore_Backend *(เฉพาะเมื่อบันทึกข้อมูลถาวร)* | `05_CTO/Skills/DataStore_Backend.md` | เพิ่ม field ใน `DEFAULT` + migration ใน `src/server/Data/PlayerData.luau` |
| 6 | Client_UI_Scripter | `05_CTO/Skills/Client_UI_Scripter.md` | `src/client/Controllers/` + `src/client/UI/` |
| 7 | ตรวจรับ | ใช้ skill `/roblox-review` | Pass/Fail ตามเกณฑ์จาก Step 1 |

เพิ่มเติม: ฟีเจอร์มีราคา/รางวัล → ก่อน Step 3 เปิด `04_CFO/Skills/Economy_Designer.md` ใส่ค่าใน `src/shared/Config/Economy.luau` (ถ้าผู้ใช้ไม่ได้ให้ตัวเลข → ใส่ค่าชั่วคราวติด `[Proposed]` และแจ้งผู้ใช้)

ปิดงาน: รายงาน ไฟล์ที่แก้ · Remote ใหม่ · ผล review · คำถามค้าง
