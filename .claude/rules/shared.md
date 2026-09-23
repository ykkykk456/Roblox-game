---
paths:
  - "src/shared/**"
---

# กฎโค้ดส่วนกลาง (`src/shared/`)

- ทุกอย่างในนี้ **Client อ่านได้** → ห้ามมีความลับ ห้ามมีตรรกะตัดสินผลที่ Client เรียกใช้แทน Server ได้
- `Remotes.luau` = ทะเบียน Remote ที่เดียวของเกม: เพิ่ม Remote ใหม่ = เพิ่มชื่อในตาราง `NAMES` เท่านั้น
- `Config/*.luau` = แหล่งเดียวของตัวเลข Balance/ราคา (เจ้าของค่า: Economy_Designer) · ใช้ `table.freeze` · Server ใช้ค่าเดียวกันตอน validate
- `Util/` = ฟังก์ชันบริสุทธิ์ ไม่มี side effect ไม่แตะ DataStore/Remote
