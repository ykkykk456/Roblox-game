---
name: roblox-map
description: Workflow สร้างหรือแก้แมพ ฉาก พื้นที่ Level Design และวัตถุในโลกเกม Roblox (Workspace, Terrain, spawn, zone, วัตถุที่โต้ตอบได้) ใช้เมื่องานเกี่ยวกับโลกของเกมมากกว่าระบบหรือ UI
---

# MAP / WORLD WORKFLOW (บทบาท World_Builder)

**ข้อจำกัดของ Rojo ในโปรเจกต์นี้** `[Verified: default.project.json]`: Workspace มีแค่ Baseplate ที่กำหนดใน `default.project.json` — ชิ้นส่วนแมพที่สร้างมือใน Studio **ไม่ได้อยู่ใน Git** และ Rojo จะไม่ลบ/ไม่บันทึกมัน
เลือกวิธีกับผู้ใช้ก่อนเริ่ม (ครั้งแรกครั้งเดียว แล้วบันทึกลง `ROBLOX_GUIDELINES.md`):
- **A. สร้างแมพในโค้ด** (แนะนำสำหรับแมพที่เป็นกฎ/ตาราง/สุ่ม): `src/server/Services/MapService.luau` สร้าง Part/Model ตอนเริ่มเกม — อยู่ใน Git ครบ
- **B. สร้างแมพมือใน Studio** แล้วโค้ดอ้างอิงผ่าน **CollectionService tag / Attribute** (เช่น tag `SpawnPoint`, `Coin`, `KillZone`) — โค้ดไม่ผูกชื่อหรือตำแหน่งของชิ้นส่วน
- **C. เก็บแมพเป็นไฟล์** `.rbxm` แล้วเพิ่ม mapping ใน `default.project.json` (ต้องให้ Architecture_Lead เสนอและผู้ใช้อนุมัติ)

ขั้นตอน:
1. **Layout** (บทบาท Systems_Designer ถ้าแมพมีกลไก): โซน · จุดเกิด · เส้นทาง · วัตถุโต้ตอบ + ชื่อ tag ที่ใช้
2. **สร้าง/เชื่อม**: วิธี A เขียน MapService · วิธี B เขียนรายการ tag/Attribute ให้ผู้ใช้วางใน Studio + โค้ดที่อ่าน tag
3. **วัตถุโต้ตอบ** (เหรียญ, กับดัก, ประตู): ตรวจการชน/รับของที่ **Server** เสมอ (`Touched` ฝั่ง Server + เช็กระยะ/cooldown) ห้ามให้ Client บอกว่า "เก็บแล้ว"
4. **ประสิทธิภาพมือถือ**: Anchored ทุกชิ้นที่ไม่ขยับ · `CanCollide/CanTouch/CanQuery = false` กับของตกแต่ง · ลดจำนวน Part (รวมเป็น Mesh/Union) · พิจารณา `Workspace.StreamingEnabled` สำหรับแมพใหญ่ `[Unverified: ต้องทดสอบกับแมพจริง]`
5. **ตรวจ**: `/roblox-review` + ให้ผู้ใช้เดินทดสอบใน Studio (Play) ตามรายการจุดที่ต้องเช็ก
