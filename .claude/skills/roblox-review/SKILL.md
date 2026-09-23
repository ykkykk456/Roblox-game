---
name: roblox-review
description: ตรวจงานโค้ด Roblox ก่อนส่ง (รวม QA + Security + Data Safety ในรอบเดียว) ใช้เมื่อเขียน/แก้โค้ดใน src/ เสร็จ หรือผู้ใช้ขอให้ตรวจ ทบทวน รีวิว หาช่องโหว่
---

# REVIEW (QA_Tester + Security_Analyst รวมรอบเดียว)

ตรวจเฉพาะไฟล์ที่เปลี่ยน (`git diff` / `git status`) · งาน Fast Lane ใช้แค่หมวด 1–3
ต้องการเกณฑ์ละเอียด → เปิด `Roblox_AI_Org_By_Function/07_QA_Security/Skills/Security_Analyst.md` หรือ `QA_Tester.md`

**1. Rojo / โครงสร้าง**
- [ ] ทุกไฟล์อยู่ใต้ `src/server|shared|client` · นามสกุล `.luau` · ไม่มี `.server.luau`/`.client.luau` เพิ่มนอกจาก `init`
- [ ] ModuleScript ใหม่คืน `{ Init?, Start? }` หรือเป็นโมดูลข้อมูล/utility ที่ถูก require
- [ ] ถ้ามีเครื่องมือ: `stylua --check src` · `selene src` · `rojo build -o build.rbxlx` ผ่าน (ไม่มีเครื่องมือ → ระบุว่าไม่ได้รัน)

**2. Server Authority / Security**
- [ ] ทุก `OnServerEvent`/`OnServerInvoke` ผ่าน `Guard.connect` (type + rate limit) และ handler ตรวจช่วงค่า + สิทธิ์
- [ ] ไม่มี Remote ที่รับ "ผลลัพธ์" จาก Client (จำนวนเงิน, ดาเมจ, ตำแหน่งที่เชื่อตรงๆ)
- [ ] ตัวเลข NaN/inf/ติดลบ/ทศนิยม และ string ยาวผิดปกติถูกปฏิเสธ
- [ ] ไม่มีความลับหรือตรรกะตัดสินผลใน `src/shared` หรือ `src/client`

**3. Data Safety**
- [ ] แก้ข้อมูลผู้เล่นผ่าน `PlayerData` เท่านั้น · field ใหม่มีค่าใน `DEFAULT`
- [ ] เปลี่ยนโครงข้อมูล → มี migration และเพิ่ม `VERSION`
- [ ] ไม่มีเส้นทางที่บันทึกทับเมื่อโหลดล้มเหลว

**4. QA (Full Workflow)**
- [ ] ผ่านเกณฑ์ตรวจรับใน Feature Spec ทีละข้อ
- [ ] UI ใช้ได้บนจอเล็ก/Touch/Gamepad · มีสถานะระหว่างรอ Server
- [ ] ผู้เล่นออกกลางคัน / เข้าหลายคน / กดรัว ไม่ทำให้พัง

ผลลัพธ์: ตาราง หมวด → Pass/Fail + ปัญหาที่พบ (ไฟล์:บรรทัด) · Fail ด้าน Security/Data = ต้องแก้ก่อนส่ง
