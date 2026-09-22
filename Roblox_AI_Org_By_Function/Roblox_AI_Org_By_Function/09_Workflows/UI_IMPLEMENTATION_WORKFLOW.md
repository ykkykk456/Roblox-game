## Scenario
สร้างหรือแก้ไขหน้าจอ UI (เช่น หน้า Inventory ใหม่, ปรับหน้าร้านค้า, เพิ่มเมนูตั้งค่า)

## Required Skills to Load
- `Departments/02_Product_UX/Skills/UX_Architect.md`
- `Departments/06_Art_Audio/Skills/Visual_Director.md`
- `Departments/05_CTO/Skills/Client_UI_Scripter.md`
- `Departments/05_CTO/Skills/Networking_Specialist.md`
- `Departments/07_QA_Security/Skills/QA_Tester.md`

> ถ้า UI ต้องใช้ asset ใหม่ (ไอคอน รูปภาพ) ให้เพิ่ม `Departments/06_Art_Audio/Skills/Asset_Integrator.md` ก่อนถึง Step 3

## Execution Steps
- *Step 1:* ให้ **UX_Architect** ออกแบบโครงหน้าจอ (wireframe), navigation flow และ GUI hierarchy
- *Step 2:* ให้ **Visual_Director** กำหนดหน้าตาเชิงภาพของ UI (สี ฟอนต์ สไตล์) ตามโครงที่ UX_Architect วางไว้ และออก Asset Brief ถ้าต้องใช้ asset ใหม่
- *Step 3:* ให้ **Client_UI_Scripter** เขียน LocalScript สร้าง ScreenGui/SurfaceGui ตามสเปกจาก Step 1–2
- *Step 4:* ให้ **Networking_Specialist** ตรวจว่า Remote ที่ UI เรียกใช้มีอยู่และตรวจสอบข้อมูลขาเข้าครบถ้วน (ประสานกับ Client_UI_Scripter หากต้องเพิ่ม Remote ใหม่)
- *Step 5:* ให้ **QA_Tester** ตรวจสอบการใช้งานจริงข้ามอุปกรณ์ (PC/มือถือ/คอนโซล) เทียบกับเกณฑ์ตรวจรับ ก่อนสรุปผล Pass/Fail
