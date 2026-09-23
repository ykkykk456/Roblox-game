---
name: roblox-economy
description: Workflow ปรับค่า Balance หรือเศรษฐกิจในเกม Roblox (ราคาไอเทม อัตรารางวัล เพดานสกุลเงิน ราคา Robux) ใช้เมื่อผู้ใช้ขอเปลี่ยนตัวเลขเกี่ยวกับเงิน รางวัล หรือความยาก
---

# ECONOMY REBALANCE WORKFLOW

หลัก: ตัวเลขทั้งหมดอยู่ที่ `src/shared/Config/Economy.luau` ที่เดียว — Server ใช้ค่าชุดเดียวกันทั้งตอนคำนวณและตอน validate การปรับ Balance ส่วนใหญ่จึงเป็นการแก้ไฟล์เดียว

1. **ข้อมูลประกอบ** *(ถ้าผู้ใช้มีตัวเลขจริง เช่น retention/การใช้จ่าย)*: บทบาท Data_Analyst `Roblox_AI_Org_By_Function/03_Market_Data/Skills/Data_Analyst.md` สรุปพร้อมป้าย Evidence
2. **กำหนดค่าใหม่**: บทบาท Economy_Designer `Roblox_AI_Org_By_Function/04_CFO/Skills/Economy_Designer.md` → แก้ `Config/Economy.luau` พร้อมเหตุผลเป็น comment สั้นๆ · ราคาที่เป็น Robux (Game Pass/Developer Product) เปิด `04_CFO/Skills/Monetization_Strategist.md` เพิ่ม
3. **เช็กผลกระทบ** (ทำเฉพาะที่เกี่ยว):
   - ค่าใหม่ทำให้ข้อมูลที่บันทึกไว้แล้วผิด (เช่น ลดเพดานเงินต่ำกว่าที่ผู้เล่นมีอยู่) → บทบาท DataStore_Backend เพิ่ม migration ใน `src/server/Data/PlayerData.luau`
   - มี hard-code ตัวเลขนอก Config → ย้ายเข้า Config
4. **ตรวจ**: `/roblox-review` เน้น ค่าติดลบ/หารศูนย์/ได้เงินไม่จำกัด · สรุปตาราง ค่าเดิม → ค่าใหม่
