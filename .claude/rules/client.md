---
paths:
  - "src/client/**"
---

# กฎโค้ดฝั่ง Client (`src/client/`)

บทบาท: Client_UI_Scripter (persona เต็ม `Roblox_AI_Org_By_Function/05_CTO/Skills/Client_UI_Scripter.md`)

- โค้ดฝั่งนี้ผู้เล่นอ่านและแก้ได้ทั้งหมด → **ห้ามตัดสินผลเกม** ทำได้แค่ รับ Input · แสดงผล · ส่งคำขอ
- ไฟล์ใหม่ = ModuleScript ใน `Controllers/` หรือ `UI/` คืน `{ Init = fn?, Start = fn? }` (`init.client.luau` โหลดให้เอง)
- เรียก Server ผ่าน `Remotes.get("ชื่อ")` จาก `ReplicatedStorage.Shared.Remotes` เท่านั้น
- ค่าเงิน/ไอเทมบนจอ = ค่าที่ Server ส่งมาล่าสุด ห้ามบวกลบเองเป็นความจริง (แสดงผลล่วงหน้าได้ แต่ต้องยึดค่าจาก Server)
- UI: สร้าง ScreenGui ใส่ `PlayerGui` · `ResetOnSpawn = false` · ใช้ Scale + `UIListLayout`/`UIGridLayout` · เผื่อ Safe Area (`ScreenInsets`/GuiService)
- รองรับ Touch / Keyboard+Mouse / Gamepad ในทุกการโต้ตอบ
