## Scenario
แก้ไขบั๊กที่มีอยู่แล้วในเกม (เช่น ค่าเงินคำนวณผิด, UI ค้าง, ข้อมูลผู้เล่นหาย)

## Required Skills to Load
- `07_QA_Security/Skills/QA_Tester.md`
- Skill เจ้าของโค้ดที่เกิดบั๊ก (เลือก 1 ไฟล์ตามจุดที่พบ):
  - `05_CTO/Skills/Gameplay_Scripter.md` — บั๊กเกี่ยวกับกลไกเกมเพลย์/สถานะเกม
  - `05_CTO/Skills/Client_UI_Scripter.md` — บั๊กเกี่ยวกับ UI ค้างหรือแสดงผลผิด
  - `05_CTO/Skills/DataStore_Backend.md` — บั๊กเกี่ยวกับข้อมูลผู้เล่นหาย/บันทึกผิด
  - `05_CTO/Skills/Networking_Specialist.md` — บั๊กเกี่ยวกับ Remote/การสื่อสาร Client-Server
- `07_QA_Security/Skills/Security_Analyst.md` (เพิ่มเมื่อสงสัยว่าเป็นช่องโหว่ ไม่ใช่บั๊กทั่วไป)

## Execution Steps
- *Step 1:* ให้ **QA_Tester** ยืนยันขั้นตอนทำซ้ำ (repro steps) ความรุนแรง และระบุ Skill เจ้าของจุดที่บั๊กเกิดขึ้น
- *Step 2:* ให้ **Skill เจ้าของโค้ด** ที่เลือกไว้ข้างต้นวิเคราะห์สาเหตุและแก้ไขโดยยึด Server Authority และ Data Safety ตามเดิม
- *Step 3:* ถ้าสาเหตุเกี่ยวข้องกับความปลอดภัย/Exploit ให้ **Security_Analyst** ตรวจสอบเพิ่มเติมว่ามีช่องโหว่อื่นที่เกี่ยวข้องหรือไม่
- *Step 4:* ให้ **QA_Tester** ทดสอบซ้ำตาม repro steps เดิม และยืนยันผล Pass ก่อนปิดงาน
