# ผลตรวจ build: example_slime

spec: `art/models/example_slime/spec.json`

ผลรวม: ✅ ผ่าน

| | ข้อ | รายละเอียด |
|---|---|---|
| ✅ | Brief ครบ (purpose, max_colors, max_tris) |  |
| ✅ | voxel เป็นลูกบาศก์ (size_studs ÷ grid เท่ากันทุกแกน) | [0.5, 0.5, 0.5] |
| ✅ | ชิ้นส่วนตรงกับ spec | Body, Sprout |
| ✅ | ข้อต่อถูกต้อง (parent มีจริง ไม่วนลูป pivot ในกริด) | 0 ข้อต่อ |
| ✅ | ทุกสีอยู่ใน palette16.json | black, brown, dark_green, green, lime, pink, white |
| ✅ | จำนวนสี ≤ 7 | ใช้ 7 สี |
| ✅ | Shading แบบ Flat ทุกหน้า |  |
| ✅ | Material ด้าน ไม่มีโลหะ/texture |  |
| ✅ | ขนาดตรง Brief ±1 voxel (8×8×7 studs) | ได้ 8.00×8.00×7.00 |
| ✅ | Pivot ที่ฐานกลาง (ฐาน z = 0, กลาง x/y ≈ 0) | ฐาน z = 0.000 · กลาง (0.00, 0.00) |
| ✅ | Triangle รวม ≤ 3000 | 824 tris |
| ✅ | Triangle ต่อชิ้น ≤ 20000 |  |
| ✅ | Geometry สะอาด (ไม่มี vertex ลอย/หน้าซ้อน, normal ชี้ออก) |  |
| ✅ | Scale = 1 และ Rotation = 0 ทุก object |  |

Triangle ต่อชิ้น: Body 788, Sprout 36
