## Scenario
ปรับค่า Balance หรือเศรษฐกิจในเกมที่มีอยู่แล้ว (เช่น ปรับราคาไอเทม อัตรารางวัล เพดานสกุลเงิน)

## Required Skills to Load
- `Departments/04_CFO/Skills/Economy_Designer.md`
- `Departments/03_Market_Data/Skills/Data_Analyst.md`
- `Departments/05_CTO/Skills/DataStore_Backend.md`
- `Departments/05_CTO/Skills/Networking_Specialist.md`
- `Departments/07_QA_Security/Skills/QA_Tester.md`

> ถ้าการปรับค่ากระทบกลยุทธ์ราคาที่ผูกกับ Robux (Developer Products/Game Passes) ให้เพิ่ม `Departments/04_CFO/Skills/Monetization_Strategist.md`

## Execution Steps
- *Step 1:* ให้ **Data_Analyst** สรุปข้อมูลปัจจุบัน (retention, การใช้จ่าย, พฤติกรรมที่เกี่ยวข้อง) พร้อมสถานะ Evidence ให้ Economy_Designer ใช้ประกอบการตัดสินใจ
- *Step 2:* ให้ **Economy_Designer** คำนวณและกำหนดค่า Balance ใหม่ (ราคา อัตรารางวัล เพดาน) พร้อมเหตุผล
- *Step 3:* ให้ **DataStore_Backend** ปรับค่าที่บันทึกถาวรให้ตรงกับค่าใหม่ โดยตรวจว่า migration ไม่ทำให้ข้อมูลผู้เล่นเดิมเสียหาย
- *Step 4:* ให้ **Networking_Specialist** ปรับขอบเขตค่า (min/max) ที่ใช้ตรวจสอบคำขอจาก Client ให้ตรงกับค่าใหม่
- *Step 5:* ให้ **QA_Tester** ทดสอบว่าค่าที่ปรับทำงานถูกต้องและไม่ทำให้เศรษฐกิจเฟ้อ/ตัน ก่อนสรุปผล Pass/Fail
