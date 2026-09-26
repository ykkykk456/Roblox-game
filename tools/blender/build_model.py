"""สร้างโมเดล voxel สไตล์ 16-bit ใน Blender จากไฟล์ spec → art/models/<name>/out/

รันได้ 2 แบบ (ผลเหมือนกัน):
  python3 tools/blender/build_model.py art/models/<name>/spec.json         (ต้อง pip install bpy ก่อน)
  blender -b -P tools/blender/build_model.py -- art/models/<name>/spec.json (ใช้โปรแกรม Blender)

ขั้นแรกตรวจการเชื่อมต่อ Blender (blender_status.py) · ไม่เชื่อมต่อ = หยุดทันที exit code 1
ผลลัพธ์อยู่ใน Blender เท่านั้น: <name>.blend · preview.png · preview_<ท่า>.png · report.md
(ไม่ส่งออก FBX/OBJ และห้ามนำเข้า Roblox — ข้อตกลงกับผู้ใช้ 2026-09-26)
จบด้วยการตรวจ build (check_model.py) อัตโนมัติ · ไม่ผ่าน = exit code 1

รูปแบบ spec (ดูตัวอย่างที่ art/models/example_slime/spec.json):
  grid = [กว้าง X, ลึก Y, สูง Z] หน่วย voxel · size_studs = ขนาดจริง [X, Y, Z] (1 หน่วย Blender = 1 stud)
  colors = { ตัวอักษร: ชื่อสีใน palette16.json }
  parts = { ชื่อชิ้น: [คำสั่งวาด...] } → 1 ชิ้น = 1 object (แยกไว้ให้ขยับ/animate ได้)
    โมเดลที่มีข้อต่อ เขียนชิ้นเป็น object แทน list:
      {"ops": [...], "pivot": [x,y,z], "parent": "Torso"}  pivot = จุดหมุน (หน่วย voxel ที่มุมกริด) · parent = ชิ้นที่ต่ออยู่
      {"mirror_of": "ArmR"}                                  ชิ้นกระจกซ้าย-ขวาของ ArmR (pivot/parent กลับด้านให้เอง R→L)
  poses = { ชื่อท่า: { ชื่อชิ้น: [องศา X, Y, Z] } } (ไม่บังคับ) → preview_<ท่า>.png ทดสอบข้อต่อ แล้วคืนท่ายืนก่อนบันทึก
  คำสั่งวาด (ทำตามลำดับ ตัวหลังทับตัวก่อน):
    {"box": [x0,y0,z0, x1,y1,z1], "c": "G"}                 กล่อง (รวมขอบทั้งสองฝั่ง)
    {"ellipsoid": [cx,cy,cz, rx,ry,rz], "c": "G"}           วงรี (หน่วย voxel, จุดศูนย์กลางใช้ทศนิยมได้)
    {"front": [...แถว], "y": 0, "x0": 0, "z0": 0}           ภาพพิกเซลมองจากหน้า: แถวบนสุด = Z สูงสุด
    {"top": [...แถว], "z": 0, "x0": 0, "y0": 0}             ภาพพิกเซลมองจากบน: แถวล่างสุด = ด้านหน้า (Y ต่ำ)
    {"decal": [...แถว], "x0": 0, "z0": 0}                    ระบายบนผิวด้านหน้า (หน้า ตา ปาก) เปลี่ยนสี voxel หน้าสุดของแต่ละคอลัมน์
    ตัวอักษรในแถว: "." หรือช่องว่าง = ไม่เปลี่ยน · "-" = ลบ voxel · อื่นๆ = สีตาม colors
    ใส่ "erase": true ใน box/ellipsoid = ลบแทนการเติม · "recolor": true = เปลี่ยนสีเฉพาะ voxel ที่มีอยู่แล้ว
  ด้านหน้าโมเดลหันไปทาง −Y ของ Blender (มุม Front ของ Blender)
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blender_status  # noqa: E402

_connected, _status = blender_status.connect()
print(_status)
if not _connected:
    print(blender_status.HOW_TO_FIX)
    sys.exit(1)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import check_model  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
PALETTE_PATH = Path(__file__).resolve().parent / "palette16.json"


def load_palette():
    data = json.loads(PALETTE_PATH.read_text(encoding="utf-8"))
    return {name: value for name, value in data.items() if not name.startswith("_")}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_color):
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4))


# ---------- วาด voxel ----------


def paint_part(ops, grid, colors):
    gx, gy, gz = grid
    cells = {}

    recolor = False

    def put(x, y, z, key, erase=False):
        if not (0 <= x < gx and 0 <= y < gy and 0 <= z < gz):
            return
        if recolor:
            if (x, y, z) in cells and not erase:
                cells[(x, y, z)] = key
            return
        if erase:
            cells.pop((x, y, z), None)
        else:
            cells[(x, y, z)] = key

    def paint_rows(rows, to_xyz):
        for r, row in enumerate(rows):
            for col, ch in enumerate(row):
                if ch in ". ":
                    continue
                x, y, z = to_xyz(r, col)
                if ch == "-":
                    put(x, y, z, None, erase=True)
                else:
                    if ch not in colors:
                        raise ValueError(f"ตัวอักษร '{ch}' ไม่มีใน colors ของ spec")
                    put(x, y, z, ch)

    for op in ops:
        recolor = bool(op.get("recolor"))
        erase = bool(op.get("erase"))
        key = op.get("c")
        if not erase and "c" in op and key not in colors:
            raise ValueError(f"สี '{key}' ไม่มีใน colors ของ spec")
        if "box" in op:
            x0, y0, z0, x1, y1, z1 = op["box"]
            for x in range(min(x0, x1), max(x0, x1) + 1):
                for y in range(min(y0, y1), max(y0, y1) + 1):
                    for z in range(min(z0, z1), max(z0, z1) + 1):
                        put(x, y, z, key, erase)
        elif "ellipsoid" in op:
            cx, cy, cz, rx, ry, rz = op["ellipsoid"]
            for x in range(gx):
                for y in range(gy):
                    for z in range(gz):
                        d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 + ((z + 0.5 - cz) / rz) ** 2
                        if d <= 1.0:
                            put(x, y, z, key, erase)
        elif "front" in op:
            rows = op["front"]
            y, x0, z0 = op.get("y", 0), op.get("x0", 0), op.get("z0", 0)
            paint_rows(rows, lambda r, col: (x0 + col, y, z0 + len(rows) - 1 - r))
        elif "top" in op:
            rows = op["top"]
            z, x0, y0 = op.get("z", 0), op.get("x0", 0), op.get("y0", 0)
            paint_rows(rows, lambda r, col: (x0 + col, y0 + len(rows) - 1 - r, z))
        elif "decal" in op:
            # ระบายสีบนผิวด้านหน้า: แต่ละช่องเปลี่ยนสี voxel ที่อยู่หน้าสุด (Y ต่ำสุด) ของคอลัมน์ (x, z) นั้น
            rows = op["decal"]
            x0, z0 = op.get("x0", 0), op.get("z0", 0)
            for r, row in enumerate(rows):
                for col, ch in enumerate(row):
                    if ch in ". ":
                        continue
                    if ch not in colors:
                        raise ValueError(f"ตัวอักษร '{ch}' ไม่มีใน colors ของ spec")
                    x, z = x0 + col, z0 + len(rows) - 1 - r
                    front = [y for y in range(gy) if (x, y, z) in cells]
                    if front:
                        cells[(x, min(front), z)] = ch
        else:
            raise ValueError(f"ไม่รู้จักคำสั่งวาด: {op}")
    return cells


# ---------- greedy meshing: รวมหน้าสีเดียวกันที่ติดกันเป็นสี่เหลี่ยมใหญ่ ลดจำนวน triangle ----------


def greedy_quads(cells, grid):
    quads = []  # (corner0..3 เป็นพิกัด voxel, สี)
    for d in range(3):
        u, v = (d + 1) % 3, (d + 2) % 3
        for s in (1, -1):
            for t in range(grid[d]):
                mask = {}
                for (pos, key) in cells.items():
                    if pos[d] != t:
                        continue
                    n = list(pos)
                    n[d] += s
                    if tuple(n) in cells:
                        continue  # หน้านี้ถูกบัง = ไม่ต้องสร้าง
                    mask[(pos[u], pos[v])] = key
                done = set()
                for a in range(grid[u]):
                    for b in range(grid[v]):
                        key = mask.get((a, b))
                        if key is None or (a, b) in done:
                            continue
                        h = 1
                        while (a, b + h) not in done and mask.get((a, b + h)) == key:
                            h += 1
                        w = 1
                        while all(
                            (a + w, b + k) not in done and mask.get((a + w, b + k)) == key for k in range(h)
                        ):
                            w += 1
                        for i in range(w):
                            for k in range(h):
                                done.add((a + i, b + k))
                        p = t + 1 if s > 0 else t

                        def corner(ua, vb):
                            c = [0, 0, 0]
                            c[d], c[u], c[v] = p, ua, vb
                            return tuple(c)

                        ring = [corner(a, b), corner(a + w, b), corner(a + w, b + h), corner(a, b + h)]
                        if s < 0:
                            ring.reverse()  # ให้ normal ชี้ออกนอกตัวเสมอ
                        quads.append((ring, key))
    return quads


# ---------- สร้าง scene ----------


def make_materials(colors, palette):
    materials = {}
    for key, name in colors.items():
        if name not in palette:
            raise ValueError(f"สี '{name}' ไม่มีใน palette16.json")
        mat = bpy.data.materials.get(f"P16_{name}") or bpy.data.materials.new(f"P16_{name}")
        rgb = hex_to_linear(palette[name])
        mat.diffuse_color = (*rgb, 1.0)
        mat.roughness = 1.0
        mat.metallic = 0.0
        tree = getattr(mat, "node_tree", None)
        bsdf = tree.nodes.get("Principled BSDF") if tree else None
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Metallic"].default_value = 0.0
        materials[key] = mat
    return materials


def build_mesh(part_name, quads, grid, voxel, materials, pivot_world):
    gx, gy, _ = grid
    ox, oy, oz = pivot_world
    verts, index, faces, face_mats = [], {}, [], []
    used = []
    for ring, key in quads:
        face = []
        for c in ring:
            if c not in index:
                index[c] = len(verts)
                # vertex เก็บแบบเทียบกับ pivot → origin ของ object อยู่ที่ข้อต่อ หมุนแล้วหมุนรอบข้อต่อ
                verts.append(((c[0] - gx / 2) * voxel - ox, (c[1] - gy / 2) * voxel - oy, c[2] * voxel - oz))
            face.append(index[c])
        if key not in used:
            used.append(key)
        faces.append(face)
        face_mats.append(used.index(key))

    mesh = bpy.data.meshes.new(part_name)
    mesh.from_pydata(verts, [], faces)
    for key in used:
        mesh.materials.append(materials[key])
    for poly, mat_index in zip(mesh.polygons, face_mats):
        poly.material_index = mat_index
        poly.use_smooth = False  # shading แบบแบน = ลุค 16-bit
    mesh.update()

    obj = bpy.data.objects.new(part_name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mirror_cells(cells, grid):
    gx = grid[0]
    return {(gx - 1 - x, y, z): key for (x, y, z), key in cells.items()}


def pivot_to_world(pivot, grid, voxel):
    return Vector(((pivot[0] - grid[0] / 2) * voxel, (pivot[1] - grid[1] / 2) * voxel, pivot[2] * voxel))


def render_poses(poses, size, out_dir):
    """เรนเดอร์ท่าทดสอบข้อต่อ (องศา XYZ ต่อชิ้น) แล้วคืนทุกชิ้นกลับท่ายืน"""
    import math

    for pose_name, rotations in poses.items():
        for part_name, degrees in rotations.items():
            obj = bpy.data.objects.get(part_name)
            if obj is None:
                raise ValueError(f"ท่า {pose_name}: ไม่มีชิ้น '{part_name}'")
            obj.rotation_euler = [math.radians(d) for d in degrees]
        bpy.context.view_layer.update()
        render_preview(size, out_dir / f"preview_{pose_name}.png")
        for obj in bpy.data.objects:
            obj.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


def render_preview(size, out_path):
    scene = bpy.context.scene
    # จัดกล้องตามกรอบของที่เห็นจริง (ท่าที่ยกแขนสูงจะไม่ถูกตัด)
    bpy.context.view_layer.update()
    corners = [o.matrix_world @ Vector(c) for o in bpy.data.objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector([min(c[i] for c in corners) for i in range(3)])
    hi = Vector([max(c[i] for c in corners) for i in range(3)])
    center = (lo + hi) / 2
    extent = max(hi - lo)
    radius = max(max(size), extent) * 1.2

    target = bpy.data.objects.new("PreviewTarget", None)
    target.location = center
    scene.collection.objects.link(target)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = extent * 1.6
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    cam.location = center + Vector((radius * 0.9, -radius * 1.3, radius * 0.8))
    track = cam.constraints.new("TRACK_TO")
    track.target = target
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.view_settings.view_transform = "Standard"  # สีตรง palette (ค่าเริ่มต้น AgX ทำให้สีซีด)
    scene.render.film_transparent = True
    scene.render.filter_size = 0.0  # ขอบคมแบบพิกเซล
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)

    # กล้อง/เป้าใช้แค่เรนเดอร์ ไม่เก็บในไฟล์ส่งมอบ
    bpy.data.objects.remove(cam)
    bpy.data.objects.remove(target)
    bpy.data.cameras.remove(cam_data)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    spec_path = Path(args[0]).resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    palette = load_palette()

    name = spec["name"]
    grid = spec["grid"]
    size = spec["size_studs"]
    voxel = size[0] / grid[0]
    out_dir = spec_path.parent / "out"
    out_dir.mkdir(exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    materials = make_materials(spec["colors"], palette)

    root = bpy.data.objects.new(name, None)  # Empty ที่ฐานกลาง = จุด pivot ของทั้งโมเดล
    bpy.context.scene.collection.objects.link(root)
    parts = check_model.normalize_parts(spec)
    objects, pivots = {}, {}
    for part_name, part in parts.items():
        cells = paint_part(part["ops"], grid, spec["colors"])
        if part["mirror"]:
            cells = mirror_cells(cells, grid)
        if not cells:
            print(f"⚠ ชิ้น {part_name} ว่าง (ไม่มี voxel)")
            continue
        pivots[part_name] = pivot_to_world(part["pivot"], grid, voxel)
        objects[part_name] = build_mesh(part_name, greedy_quads(cells, grid), grid, voxel, materials, pivots[part_name])
    # ผูกข้อต่อ: location ของลูก = ตำแหน่งข้อต่อเทียบกับข้อต่อของพ่อ (parent inverse = identity)
    for part_name, obj in objects.items():
        parent_name = parts[part_name]["parent"]
        parent = objects.get(parent_name) if parent_name else None
        if parent_name and parent is None:
            raise ValueError(f"{part_name}: parent '{parent_name}' ไม่มีหรือว่าง")
        obj.parent = parent or root
        obj.location = pivots[part_name] - (pivots[parent_name] if parent else Vector((0, 0, 0)))
    bpy.context.view_layer.update()

    blend_path = out_dir / f"{name}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    render_preview(size, out_dir / "preview.png")
    render_poses(spec.get("poses", {}), size, out_dir)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    try:
        label = spec_path.relative_to(ROOT)
    except ValueError:
        label = spec_path.name
    ok = check_model.run(spec, palette, out_dir / "report.md", label)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
