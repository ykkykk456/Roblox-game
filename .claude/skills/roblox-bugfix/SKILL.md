---
name: roblox-bugfix
description: Workflow แก้บั๊กในเกม Roblox (ค่าเงินผิด, UI ค้าง, ข้อมูลผู้เล่นหาย, Remote ทำงานผิด, ช่องโหว่ exploit) ใช้เมื่อผู้ใช้รายงานว่ามีบางอย่างทำงานผิด
---

# BUG FIX WORKFLOW

1. **ทำซ้ำให้ได้ก่อน** (บทบาท QA_Tester — เปิด `Roblox_AI_Org_By_Function/07_QA_Security/Skills/QA_Tester.md` เฉพาะบั๊กที่ซับซ้อน): เขียน repro steps + ผลที่คาด vs ผลจริง + ความรุนแรง · ถ้าข้อมูลไม่พอ ถามผู้ใช้ ห้ามเดา
2. **หาเจ้าของจากตำแหน่งไฟล์** แล้วแก้ที่ต้นเหตุ (กฎของโฟลเดอร์โหลดอัตโนมัติจาก `.claude/rules/`):
   - `src/server/Services/` ตรรกะเกม · `src/server/Network/` Remote/validation · `src/server/Data/` ข้อมูลหาย/บันทึกผิด · `src/client/` UI
3. **ถ้าเกี่ยวกับความปลอดภัย** (Client ส่งค่าที่ไม่ควรเชื่อ, ไม่มี rate limit, ได้ของฟรี) → ค้นหา Remote อื่นที่มีรูปแบบเดียวกันแล้วแก้พร้อมกัน
4. **ยืนยัน**: ไล่ repro steps เดิมอีกครั้ง (อธิบายวิธีทดสอบใน Studio ให้ผู้ใช้) + `/roblox-review` แบบย่อเฉพาะไฟล์ที่แก้

รายงาน: สาเหตุ · ไฟล์ที่แก้ · วิธีทดสอบซ้ำ
