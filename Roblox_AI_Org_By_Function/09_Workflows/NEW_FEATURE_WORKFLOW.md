## Scenario
สร้างฟีเจอร์ใหม่ตั้งแต่ต้น ที่มีทั้งกลไกเกมเพลย์ การสื่อสาร Client-Server และหน้าจอ UI (เช่น ระบบภารกิจใหม่, ระบบคราฟไอเทม)

## Required Skills to Load
- `02_Product_UX/Skills/Systems_Designer.md`
- `02_Product_UX/Skills/UX_Architect.md`
- `05_CTO/Skills/Architecture_Lead.md`
- `05_CTO/Skills/Gameplay_Scripter.md`
- `05_CTO/Skills/Networking_Specialist.md`
- `05_CTO/Skills/Client_UI_Scripter.md`
- `07_QA_Security/Skills/QA_Tester.md`
- `07_QA_Security/Skills/Security_Analyst.md`

> ถ้าฟีเจอร์ต้องบันทึกข้อมูลถาวร (เช่น ความก้าวหน้า ไอเทมที่ได้) ให้เพิ่ม `05_CTO/Skills/DataStore_Backend.md`
> ถ้าฟีเจอร์เกี่ยวกับเศรษฐกิจ/ราคา ให้เพิ่ม `04_CFO/Skills/Economy_Designer.md`

## Execution Steps
- *Step 1:* ให้ **Systems_Designer** ออกแบบกฎของระบบและเขียน Feature Spec พร้อมเกณฑ์ตรวจรับ
- *Step 2:* ให้ **UX_Architect** ออกแบบโครงหน้าจอและ user flow ของฟีเจอร์นั้น
- *Step 3:* ให้ **Architecture_Lead** ตรวจสเปกทางเทคนิค และแบ่งงานให้ Gameplay_Scripter / Networking_Specialist / Client_UI_Scripter (และ DataStore_Backend ถ้าต้องบันทึกข้อมูล)
- *Step 4:* ให้ **Gameplay_Scripter** implement ตรรกะฝั่ง Server ตาม Feature Spec
- *Step 5:* ให้ **Networking_Specialist** สร้าง Remote API และตรวจสอบข้อมูลขาเข้าจาก Client
- *Step 6:* ให้ **Client_UI_Scripter** implement UI ตามโครงหน้าจอของ UX_Architect โดยเรียก Remote ที่ Networking_Specialist กำหนด
- *Step 7:* ให้ **QA_Tester** ทดสอบตามเกณฑ์ตรวจรับข้ามอุปกรณ์ และ **Security_Analyst** ตรวจ Server Authority ก่อนสรุปผล Pass/Fail
