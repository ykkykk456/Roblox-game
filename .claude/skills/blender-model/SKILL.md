---
name: blender-model
description: Workflow รับความต้องการโมเดล 3D แล้วสร้างใน Blender ด้วยสคริปต์ เป็นสไตล์เกมยุค 16-bit (voxel สีจาก palette จำกัด shading แบน) พร้อมตรวจ build ก่อนส่งมอบ ใช้เมื่อผู้ใช้ขอโมเดล ตัวละคร มอน บอส ไอเทม หรือของในฉากแบบ 16-bit/pixel/voxel · จบที่ Blender ไม่นำเข้า Roblox
---

# BLENDER MODEL WORKFLOW (16-bit)

**ข้อตกลงกับผู้ใช้:** Claude ส่งความต้องการไปสร้างใน **Blender** เท่านั้น · **ไม่นำโมเดลเข้า Roblox** (ไม่แตะ `src/`, ไม่แตะ Studio, ไม่อัปโหลด asset) · การนำเข้า Roblox เป็นงานแยกเมื่อผู้ใช้สั่งเอง

ทำตามลำดับ Step ห้ามข้าม · แต่ละ Step เปิดเฉพาะไฟล์ในช่อง "โหลด" (path นับจาก `Roblox_AI_Org_By_Function/`)

| Step | บทบาท | โหลด | ผลลัพธ์ |
|---|---|---|---|
| 1 รับความต้องการ | Visual_Director | `06_Art_Audio/Skills/Visual_Director.md` | **Model Brief** ครบทุกช่อง (ตารางด้านล่าง) · ช่องไหนผู้ใช้ไม่ได้บอกและเดาไม่ได้จากบริบท → **ถามก่อน ห้ามเดา** |
| 2 เขียน Spec | Visual_Director | `tools/blender/palette16.json` | `art/models/<name>/spec.json` — Brief + grid + สี + คำสั่งวาดแยกตามชิ้น |
| 3 Build ใน Blender | Tech Artist (Claude) | `tools/blender/build_model.py` (อ่าน docstring รูปแบบ spec) | รัน build → `out/<name>.blend` `.fbx` `.obj` `preview.png` `report.md` |
| 4 ตรวจ build (Gate) | QA | — | Checklist อัตโนมัติผ่าน **ทุกข้อ** + Claude เปิดดู `preview.png` เองว่าตรง Brief · ไม่ผ่าน → กลับ Step 2 (แก้ spec ไม่แก้ไฟล์ .blend มือ) |
| 5 ส่งมอบ | — | — | ส่ง `preview.png` ให้ผู้ใช้ดู + รายงาน 4 บรรทัด → commit `art/models/<name>/` → push · **หยุดที่นี่** |

## Step 1 — Model Brief (ต้องครบก่อนเริ่ม Step 2)

| ช่อง | ความหมาย | ตัวอย่าง |
|---|---|---|
| `name` | ชื่อไฟล์ ตัวเล็ก + `_` | `fire_golem` |
| `purpose` | ใช้ทำอะไร / บุคลิก | บอสแมพ 1 ตัวใหญ่ หน้าดุ |
| `size_studs` | ขนาดจริง [กว้าง X, ลึก Y, สูง Z] (1 หน่วย Blender = 1 stud) | `[12, 8, 16]` |
| `grid` | ความละเอียด voxel · ต้องได้ลูกบาศก์ (size ÷ grid เท่ากันทุกแกน) · ยิ่งน้อยยิ่ง "16-bit" | `[24, 16, 32]` |
| `max_colors` | จำนวนสีสูงสุด (16-bit ปกติ 4–12 สี) | `8` |
| `max_tris` | งบ triangle รวม (ตัวเล็ก ≤ 3,000 · บอส ≤ 10,000) | `8000` |
| `animate_parts` | ชิ้นที่ต้องแยกไว้ขยับภายหลัง | `["Head", "ArmL", "ArmR"]` |
| สีหลัก | เลือกจาก `palette16.json` เท่านั้น | `red`, `orange`, `black` |

ภาพอ้างอิงจากผู้ใช้ (ถ้ามี) → สรุปรูปทรง/สีเป็นข้อความใน `brief.notes`

## Step 2 — กติกาเขียน Spec
- ด้านหน้าโมเดลหัน **−Y** (มุม Front ของ Blender) · ฐานอยู่ที่ z = 0 · โมเดลกึ่งกลางกริดในแกน X/Y
- 1 ชิ้นใน `parts` = 1 object ใน Blender · ชิ้นใน `animate_parts` ต้องเป็น part แยก
- ลำดับวาดที่แนะนำ: ทรงหลัก (`ellipsoid`/`box`) → แถบสี/เงา (`recolor`) → หน้า ตา ปาก (`decal`) → รายละเอียดเล็ก (`front`/`top`)
- สไตล์ 16-bit: ใช้เงา 2 ระดับ (สีหลัก + สีเข้มด้านล่าง/สีอ่อนไฮไลต์) · ตาอย่างน้อย 2×2 voxel · ไม่ใช้ gradient หลายขั้น
- รูปแบบคำสั่งวาดครบอยู่ใน docstring ของ `tools/blender/build_model.py` · ตัวอย่างใช้งานจริง: `art/models/example_slime/spec.json`

## Step 3 — คำสั่ง Build
ใน cloud (ไม่มีโปรแกรม Blender): ติดตั้งครั้งแรก `python3 -m venv <scratchpad>/bvenv && <scratchpad>/bvenv/bin/pip install -r tools/blender/requirements.txt`
- ถ้าเรนเดอร์พรีวิวแล้ว error เรื่อง `libEGL` → `apt-get install -y libegl1 libegl-mesa0 libgl1-mesa-dri` `[Verified: 2026-09-26]`

```
<scratchpad>/bvenv/bin/python tools/blender/build_model.py art/models/<name>/spec.json
```
ผู้ใช้ที่มี Blender ในเครื่อง: `blender -b -P tools/blender/build_model.py -- art/models/<name>/spec.json`
ตรวจซ้ำอย่างเดียว: `tools/blender/check_model.py` (argument เดียวกัน)

## Step 4 — Build Checklist (check_model.py ตรวจให้อัตโนมัติ)
1. Brief ครบ · voxel เป็นลูกบาศก์
2. ชิ้นส่วนตรงกับ spec
3. ทุกสีอยู่ใน `palette16.json` · จำนวนสี ≤ `max_colors`
4. Shading แบบ Flat · material ด้าน (roughness ≥ 0.9) ไม่มีโลหะ ไม่มี texture ภาพ
5. ขนาดตรง `size_studs` ±1 voxel · pivot ที่ฐานกลาง
6. Triangle รวม ≤ `max_tris` · ต่อชิ้น ≤ 20,000
7. Geometry สะอาด: ไม่มี vertex ลอย/หน้าซ้อน · normal ชี้ออก
8. Scale = 1, Rotation = 0 ทุก object

**ตรวจด้วยตาเพิ่ม (Claude ต้องเปิด `preview.png` ดูเอง):** รูปทรงอ่านออกว่าเป็นอะไร · หน้าหันถูกทาง · สีตรง Brief · ไม่มีรู/ชิ้นลอยผิดที่

## Step 5 — รายงานส่งมอบ
```
โมเดล: <name> — <purpose>
ไฟล์: art/models/<name>/out/ (.blend · .fbx · .obj · preview.png · report.md)
สเปก: <X×Y×Z studs> · <tris> tris · <n> สี · ชิ้น: <parts>
ผลตรวจ: ✅ ผ่าน 8/8 · ข้อสังเกต: <ถ้ามี>
```

## STOP and REPORT เมื่อ
- ผู้ใช้ขอสีที่ไม่มีใน palette → เสนอสีใกล้สุด หรือขอให้ Visual_Director เพิ่มใน `palette16.json` (ห้ามใส่ hex ตรงใน spec)
- งบ triangle ไม่พอกับรายละเอียดที่ขอ → เสนอลด grid หรือเพิ่มงบ ให้ผู้ใช้เลือก
- ผู้ใช้ขอให้นำเข้า Roblox → อยู่นอกข้อตกลงของ skill นี้ ถามก่อนว่าจะเปิดงานใหม่หรือไม่
