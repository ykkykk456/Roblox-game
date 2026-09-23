---
paths:
  - "src/server/**"
---

# กฎโค้ดฝั่ง Server (`src/server/`)

บทบาท: `Services/` = Gameplay_Scripter · `Network/` = Networking_Specialist · `Data/` = DataStore_Backend
(persona เต็มอยู่ที่ `Roblox_AI_Org_By_Function/05_CTO/Skills/` — เปิดเมื่อทำ Full Workflow เท่านั้น)

- ไฟล์ใหม่ = ModuleScript คืน `{ Init = fn?, Start = fn? }` · `init.server.luau` เรียก Init ทุกตัวก่อน แล้วค่อย Start
- **ทุก Remote** รับผ่าน `Network/Guard.luau` เท่านั้น:
  `Guard.connect(remote, { rate = n, per = วินาที, args = { "number", "string" } }, handler)`
  แล้วใน handler ตรวจ **ช่วงค่า** และ **สิทธิ์** ต่อ (เช่น มีไอเทมจริงไหม เงินพอไหม) ก่อนแก้สถานะ
- Client ส่งเจตนา (`"buy", itemId`) ไม่ใช่ผลลัพธ์ (`"setCoins", 999`) — ถ้าเจอ Remote แบบหลัง = บั๊กความปลอดภัย
- ใช้ `RemoteEvent` เป็นหลัก · `RemoteFunction` เฉพาะจำเป็น และห้าม Server เรียก `InvokeClient`
- เงิน/ไอเทม/ความก้าวหน้า แก้ผ่าน `Data/PlayerData.luau` (`get` / `update`) เท่านั้น ห้ามเรียก DataStoreService เองที่อื่น
- ตัวเลขราคา/รางวัล/เพดาน อ่านจาก `src/shared/Config/` ห้าม hard-code
- ลูปต่อเฟรม (`Heartbeat`) ใช้เท่าที่จำเป็น · ล้าง connection/ข้อมูลผู้เล่นใน `PlayerRemoving`
