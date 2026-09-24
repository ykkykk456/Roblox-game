---
name: roblox-ui
description: Workflow สร้างหรือแก้หน้าจอ UI ในเกม Roblox (Inventory, ร้านค้า, เมนู, HUD) ใช้เมื่องานหลักคือหน้าจอฝั่ง Client
---

# UI IMPLEMENTATION WORKFLOW

แต่ละ Step เปิดเฉพาะไฟล์ในช่อง "โหลด" (path นับจาก `Roblox_AI_Org_By_Function/`)

| Step | บทบาท | โหลด | ผลลัพธ์ |
|---|---|---|---|
| 1 | UX_Architect | `02_Product_UX/Skills/UX_Architect.md` | โครงหน้าจอ + GUI hierarchy + การควบคุม Touch/KBM/Gamepad |
| 2 | Visual_Director *(ข้ามถ้าใช้สไตล์เดิม)* | `06_Art_Audio/Skills/Visual_Director.md` | สี ฟอนต์ ขนาด → แก้ที่ `src/client/UI/Theme.luau` ที่เดียว · ถ้าต้องใช้รูปใหม่ → Asset_Integrator (`06_Art_Audio/Skills/Asset_Integrator.md`) ลงทะเบียน `rbxassetid://` |
| 3 | Client_UI_Scripter | `05_CTO/Skills/Client_UI_Scripter.md` | `src/client/UI/<Name>UI.luau` (+ Controller ถ้ามีการโต้ตอบ) · **ใช้ของที่มีอยู่ก่อนเขียนใหม่**: `Components.luau` (screen/panel/button/label/toggle/slider) · `Panels.luau` (เปิด-ปิดแผงทีละอัน) · `Theme.luau` (สี/ฟอนต์) |
| 4 | Networking_Specialist *(เฉพาะเมื่อ UI ต้องเรียก Remote ใหม่)* | `05_CTO/Skills/Networking_Specialist.md` | ชื่อใน `Remotes.luau` + handler ผ่าน `Guard` |
| 5 | ตรวจรับ | `/roblox-review` | เช็กจอเล็ก/มือถือ/Gamepad + Remote |

UI ที่แค่แสดงผลและไม่มี Remote ใหม่ มักเข้าเกณฑ์ Fast Lane
