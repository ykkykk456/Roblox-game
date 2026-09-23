---
name: roblox-map
description: Workflow สร้างหรือแก้แมพ ฉาก พื้นที่ Level Design และวัตถุในโลกเกม Roblox (Workspace, Terrain, spawn, zone, วัตถุที่โต้ตอบได้) ใช้เมื่องานเกี่ยวกับโลกของเกมมากกว่าระบบหรือ UI
---

# MAP / WORLD WORKFLOW (บทบาท World_Builder)

**วิธีที่ใช้ในโปรเจกต์นี้ (CEO ตัดสินแล้ว): สร้างมือผสมโค้ด**

| ส่วนของแมพ | ใครทำ | อยู่ที่ไหน |
|---|---|---|
| รูปทรงซับซ้อน ตกแต่ง Terrain ฉาก (ทำด้วยโค้ดยาก) | ผู้ใช้สร้างมือใน Studio | ไฟล์ place ใน Studio (ไม่อยู่ใน Git) |
| ของที่ซ้ำเยอะ วางตามกฎ/ตาราง/สุ่ม (เหรียญ แถวแพลตฟอร์ม ด่านที่ generate) | Claude เขียนโค้ด | `src/server/Services/<ชื่อ>Service.luau` |
| พฤติกรรมของชิ้นที่สร้างมือ (จุดเกิด กับดัก ประตู ของเก็บได้) | ผู้ใช้ติด **tag** ใน Studio · Claude เขียนโค้ดที่อ่าน tag | tag ประกาศใน `src/shared/Config/Tags.luau` · ใช้ `src/shared/Util/Tagged.luau` |

กฎการเชื่อมมือ ↔ โค้ด
- โค้ดหาชิ้นส่วนผ่าน **tag หรือ Attribute เท่านั้น** ห้ามอ้างชื่อ/ตำแหน่ง (`workspace.Map.Part27`) เพราะผู้ใช้แก้ในมือได้ตลอด
- ค่าที่ปรับต่อชิ้นได้ (ดาเมจ, เวลา respawn) ใช้ **Attribute** บนชิ้นนั้น + ค่า default ในโค้ด
- tag ใหม่: เพิ่มใน `Tags.luau` ก่อน แล้วบอกผู้ใช้เป็นรายการ "ติด tag X ให้ชิ้นแบบไหน + Attribute อะไร"
- `[Inferred]` Rojo ไม่ลบของใน Workspace ที่ไม่ได้อยู่ใน `default.project.json` (ค่าเริ่มต้นของ service คือไม่ยุ่งกับ instance ที่ไม่รู้จัก) — ของที่สร้างมือจึงปลอดภัยจาก sync
- ของที่สร้างมือไม่อยู่ใน Git → เตือนผู้ใช้ให้ **Publish to Roblox** เป็นประจำ (Roblox เก็บประวัติเวอร์ชันของ place)

ขั้นตอน:
1. **Layout** (บทบาท Systems_Designer ถ้าแมพมีกลไก): โซน · จุดเกิด · เส้นทาง · วัตถุโต้ตอบ + ชื่อ tag ที่ใช้
2. **แบ่งงาน**: ส่วนที่สร้างมือ → เขียนรายการ tag/Attribute ให้ผู้ใช้ · ส่วนที่สร้างด้วยโค้ด → เขียน Service · แล้วเขียนโค้ดที่อ่าน tag ด้วย `Tagged.each`
3. **วัตถุโต้ตอบ** (เหรียญ, กับดัก, ประตู): ตรวจการชน/รับของที่ **Server** เสมอ (`Touched` ฝั่ง Server + เช็กระยะ/cooldown) ห้ามให้ Client บอกว่า "เก็บแล้ว"
4. **ประสิทธิภาพมือถือ**: Anchored ทุกชิ้นที่ไม่ขยับ · `CanCollide/CanTouch/CanQuery = false` กับของตกแต่ง · ลดจำนวน Part (รวมเป็น Mesh/Union) · พิจารณา `Workspace.StreamingEnabled` สำหรับแมพใหญ่ `[Unverified: ต้องทดสอบกับแมพจริง]`
5. **ตรวจ**: `/roblox-review` + ให้ผู้ใช้เดินทดสอบใน Studio (Play) ตามรายการจุดที่ต้องเช็ก
