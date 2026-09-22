# ROBLOX GUIDELINES — มาตรฐานโค้ดสำหรับซิงค์ผ่าน Rojo

**โครงการ:** Roblox AI Development Organization
**สถานะ:** Phase 7 & 8 — Task System & Roblox Integration
**เครื่องมือ:** VS Code, Git, Rojo (**ห้ามใช้ MCP**)

> เอกสารนี้กำหนดมาตรฐานทางเทคนิคที่ทุก Skill ใน `05_CTO` ต้องใช้เมื่อ implement โค้ดจริง
> ยึดคู่กับกฎเหล็กใน `PRINCIPLES.md` โดยเฉพาะ Server Authority และ Data Safety

---

## 1. Rojo File Structure

Rojo อ่านนามสกุลไฟล์เพื่อตัดสินว่า Instance ที่สร้างขึ้นใน Studio เป็นสคริปต์ประเภทใด การตั้งชื่อผิดจะทำให้ Sync ได้ Instance ผิดชนิดโดยไม่มี error เตือน จึงต้องเคร่งครัดตามตารางนี้:

| นามสกุลไฟล์ | Instance ที่ Rojo สร้าง | รันที่ไหน | ใช้โดย Skill |
|---|---|---|---|
| `.server.lua` | `Script` | Server เท่านั้น | Gameplay_Scripter, DataStore_Backend, Networking_Specialist (ฝั่งรับ) |
| `.client.lua` | `LocalScript` | Client เท่านั้น | Client_UI_Scripter, Networking_Specialist (ฝั่งเรียก) |
| `.lua` | `ModuleScript` | ทั้งสองฝั่ง (ตามตำแหน่งที่วาง) | ทุก Skill ที่แชร์โค้ด/ค่าคงที่ร่วมกัน |

**กฎการตั้งชื่อ**
- ห้ามใช้ `.server.lua` กับโค้ดที่ต้องรันฝั่ง Client และห้ามใช้ `.client.lua` กับตรรกะที่มีผลต่อเกม
- ไฟล์ที่ชื่อ `init.server.lua`, `init.client.lua`, `init.lua` ใช้เป็นไฟล์หลักของโฟลเดอร์นั้นเมื่อต้องการรวมหลายไฟล์เป็น Instance เดียว
- ชื่อไฟล์ (ไม่รวมนามสกุล) คือชื่อ Instance ใน Studio ต้องตรงกับที่ระบุใน Feature Spec

---

## 2. Directory Standard

โครงสร้างโฟลเดอร์ `src/` ต้องล้อ Instance Tree ของ Roblox โดยตรง เพื่อให้ Rojo sync ตำแหน่งถูกต้อง:

```
src/
├── ServerScriptService/
│   └── <Feature>/
│       └── <Feature>.server.lua      # Gameplay_Scripter, DataStore_Backend
├── ServerStorage/
│   └── <Feature>/
│       └── <Module>.lua              # ข้อมูล/โมดูลที่ Client ห้ามเข้าถึง
├── ReplicatedStorage/
│   ├── Remotes/
│   │   └── <Feature>Remotes.lua      # Networking_Specialist: นิยาม RemoteEvent/RemoteFunction
│   └── Shared/
│       └── <Module>.lua              # ค่าคงที่/ฟังก์ชันที่ทั้ง Server และ Client ใช้ร่วมกัน
├── StarterPlayerScripts/
│   └── <Feature>/
│       └── <Feature>.client.lua      # Client_UI_Scripter, Networking_Specialist (ฝั่งเรียก)
└── StarterGui/
    └── <Feature>/                     # โครง GUI ที่ Client_UI_Scripter ประกอบตาม UX_Architect
```

**กฎการวาง**
- ตรรกะและข้อมูลลับ → `ServerScriptService` / `ServerStorage` เท่านั้น (Client เข้าถึงไม่ได้)
- สิ่งที่ต้องใช้ร่วมกันทั้งสองฝั่ง (ค่าคงที่ ฟังก์ชัน utility ที่ไม่มีผลต่อความปลอดภัย) → `ReplicatedStorage/Shared`
- Remote ทุกตัวประกาศไว้ที่ `ReplicatedStorage/Remotes` เท่านั้น เพื่อให้ทั้ง Server และ Client อ้างอิง path เดียวกัน
- โค้ด UI/การโต้ตอบฝั่งผู้เล่น → `StarterPlayerScripts` หรือ `StarterGui` เท่านั้น

---

## 3. Security Rules

**หลักการหลัก: Never trust the client** — ยึดตาม `PRINCIPLES.md` กฎเหล็กข้อ 1 (Roblox Security / Server Authority)

- Client ทำได้เพียง 3 อย่าง: รับ Input, แสดงผล, ส่งคำขอผ่าน Remote — **ห้ามให้ Client ตัดสินผลลัพธ์ของเกมเอง**
- ทุก `RemoteEvent`/`RemoteFunction` ใน `ReplicatedStorage/Remotes` ต้องมีการ validate ที่ฝั่ง Server (ใน `.server.lua`) ก่อนประมวลผลเสมอ ไม่มีข้อยกเว้น โดยตรวจอย่างน้อย:
  - ชนิดข้อมูล (type) ตรงตามที่กำหนด
  - ช่วงค่า (range) อยู่ในขอบเขตที่ Economy_Designer/Systems_Designer ระบุ
  - สิทธิ์ของผู้เรียก (permission) เช่น เป็นเจ้าของไอเทมจริงหรือไม่
- ใช้ `RemoteEvent` เป็นค่าเริ่มต้น หลีกเลี่ยง `RemoteFunction` เว้นแต่จำเป็น เพราะเสี่ยง Client ทำให้ Server รอ (yield) นานเกินควร
- ต้องมี rate limiting ต่อผู้เล่นต่อ Remote เพื่อป้องกัน spam/exploit จากเครื่องมือฝั่ง Client
- ข้อมูลถาวรของผู้เล่น (ผ่าน `DataStoreService`) ต้อง validate ก่อนบันทึกทุกครั้ง และห้ามบันทึกทับข้อมูลเดิมเมื่อโหลดล้มเหลว ตาม Data Safety ใน `PRINCIPLES.md`
- ห้ามใช้การซ่อน/บดบังโค้ด (obfuscation) แทนการตรวจสอบฝั่ง Server — Security_Analyst ถือว่าไม่ผ่านหากพบรูปแบบนี้

---

## 4. ความสัมพันธ์กับ Rojo/Git ในกระบวนการทำงาน

- Rojo sync คือขั้นตอนสุดท้ายหลังจากโค้ดผ่านโครงสร้างไฟล์และ Directory Standard ข้างต้นแล้วเท่านั้น
- ทุกการเปลี่ยนแปลงโค้ดต้องผ่าน Git ก่อน sync เข้า Studio เพื่อรักษาประวัติที่ตรวจสอบย้อนกลับได้
- เอกสารนี้ไม่ครอบคลุมการตั้งค่า `default.project.json` หรือรายละเอียด Rojo config อื่น ซึ่งจะกำหนดในเฟสถัดไปเมื่อเริ่มโปรเจกต์โค้ดจริง
