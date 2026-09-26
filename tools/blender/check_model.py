"""ตรวจ build โมเดล 16-bit (Gate ก่อนส่งมอบ) → พิมพ์ ✅/❌ ทีละข้อ + เขียน out/report.md

build_model.py เรียกให้เองตอนท้าย · ตรวจซ้ำอย่างเดียว (ไม่ build ใหม่):
  python3 tools/blender/check_model.py art/models/<name>/spec.json
  blender -b -P tools/blender/check_model.py -- art/models/<name>/spec.json
exit code 0 = ผ่านทุกข้อ · 1 = มีข้อไม่ผ่าน
"""

import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent.parent
PALETTE_PATH = Path(__file__).resolve().parent / "palette16.json"
MAX_TRIS_PER_MESH = 20000  # [Inferred] เพดาน triangle ต่อ MeshPart ของ Roblox — เผื่อไว้ใช้ภายหลัง
COLOR_TOLERANCE = 0.002


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_color):
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4))


def palette_name_of(rgb, palette):
    for name, hex_color in palette.items():
        if all(abs(a - b) <= COLOR_TOLERANCE for a, b in zip(rgb, hex_to_linear(hex_color))):
            return name
    return None


def signed_volume(mesh):
    total = 0.0
    for poly in mesh.polygons:
        pts = [mesh.vertices[i].co for i in poly.vertices]
        for i in range(1, len(pts) - 1):
            total += pts[0].dot(pts[i].cross(pts[i + 1])) / 6.0
    return total


def run(spec, palette, report_path=None, spec_label=""):
    brief = spec.get("brief", {})
    grid, size = spec["grid"], spec["size_studs"]
    voxel = size[0] / grid[0]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    results = []

    def check(ok, label, detail=""):
        results.append((bool(ok), label, detail))

    # 1) Brief ครบ
    missing = [k for k in ("purpose", "max_colors", "max_tris") if k not in brief]
    check(not missing, "Brief ครบ (purpose, max_colors, max_tris)", f"ขาด: {', '.join(missing)}" if missing else "")
    voxel_sizes = [s / g for s, g in zip(size, grid)]
    check(
        max(voxel_sizes) - min(voxel_sizes) < 1e-6,
        "voxel เป็นลูกบาศก์ (size_studs ÷ grid เท่ากันทุกแกน)",
        f"{[round(v, 4) for v in voxel_sizes]}",
    )

    # 2) ชิ้นส่วนตรง Brief
    names = {o.name for o in meshes}
    wanted = set(spec["parts"])
    check(
        names == wanted,
        "ชิ้นส่วนตรงกับ spec",
        f"ขาด {sorted(wanted - names)} · เกิน {sorted(names - wanted)}" if names != wanted else ", ".join(sorted(names)),
    )

    # 3) สีจาก palette เท่านั้น + ไม่เกินจำนวน
    used, outside = set(), []
    for obj in meshes:
        for mat in obj.data.materials:
            if mat is None:
                outside.append(f"{obj.name}: ช่อง material ว่าง")
                continue
            color_name = palette_name_of(tuple(mat.diffuse_color)[:3], palette)
            if color_name:
                used.add(color_name)
            else:
                outside.append(f"{obj.name}/{mat.name}")
    check(not outside, "ทุกสีอยู่ใน palette16.json", "; ".join(outside) if outside else ", ".join(sorted(used)))
    max_colors = brief.get("max_colors", 0)
    check(len(used) <= max_colors, f"จำนวนสี ≤ {max_colors}", f"ใช้ {len(used)} สี")

    # 4) ลุค 16-bit: shading แบน · ไม่มัน ไม่เป็นโลหะ ไม่มี texture ภาพ
    smooth = [o.name for o in meshes if any(p.use_smooth for p in o.data.polygons)]
    check(not smooth, "Shading แบบ Flat ทุกหน้า", ", ".join(smooth))
    bad_mats = []
    for mat in {m for o in meshes for m in o.data.materials if m}:
        if mat.roughness < 0.9 or mat.metallic > 0.0:
            bad_mats.append(f"{mat.name} (roughness {mat.roughness:.2f}, metallic {mat.metallic:.2f})")
        tree = getattr(mat, "node_tree", None)
        if tree and any(n.type == "TEX_IMAGE" for n in tree.nodes):
            bad_mats.append(f"{mat.name} มี texture ภาพ")
    check(not bad_mats, "Material ด้าน ไม่มีโลหะ/texture", "; ".join(bad_mats))

    # 5) ขนาดและจุด pivot
    if meshes:
        corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        lo = Vector([min(c[i] for c in corners) for i in range(3)])
        hi = Vector([max(c[i] for c in corners) for i in range(3)])
        dims = hi - lo
        size_ok = all(abs(dims[i] - size[i]) <= voxel + 1e-4 for i in range(3))
        check(
            size_ok,
            f"ขนาดตรง Brief ±1 voxel ({size[0]}×{size[1]}×{size[2]} studs)",
            f"ได้ {dims.x:.2f}×{dims.y:.2f}×{dims.z:.2f}",
        )
        center = (lo + hi) / 2
        pivot_ok = abs(lo.z) < 1e-4 and abs(center.x) <= voxel + 1e-4 and abs(center.y) <= voxel + 1e-4
        check(
            pivot_ok,
            "Pivot ที่ฐานกลาง (ฐาน z = 0, กลาง x/y ≈ 0)",
            f"ฐาน z = {lo.z:.3f} · กลาง ({center.x:.2f}, {center.y:.2f})",
        )
    else:
        check(False, "มี mesh อย่างน้อย 1 ชิ้น", "ไม่พบ mesh")

    # 6) งบ triangle
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes}
    total = sum(tris.values())
    max_tris = brief.get("max_tris", 0)
    check(total <= max_tris, f"Triangle รวม ≤ {max_tris}", f"{total} tris")
    over = [f"{n} ({t})" for n, t in tris.items() if t > MAX_TRIS_PER_MESH]
    check(not over, f"Triangle ต่อชิ้น ≤ {MAX_TRIS_PER_MESH}", ", ".join(over))

    # 7) Geometry สะอาด
    problems = []
    for obj in meshes:
        mesh = obj.data
        in_face = {i for p in mesh.polygons for i in p.vertices}
        loose = len(mesh.vertices) - len(in_face)
        if loose:
            problems.append(f"{obj.name}: vertex ลอย {loose}")
        keys = [tuple(sorted(p.vertices)) for p in mesh.polygons]
        if len(keys) != len(set(keys)):
            problems.append(f"{obj.name}: หน้าซ้อน {len(keys) - len(set(keys))}")
        if signed_volume(mesh) <= 0:
            problems.append(f"{obj.name}: normal กลับด้าน/ปริมาตรไม่ปิด")
    check(not problems, "Geometry สะอาด (ไม่มี vertex ลอย/หน้าซ้อน, normal ชี้ออก)", "; ".join(problems))

    # 8) Transform ถูก apply
    bad_tf = [
        o.name
        for o in bpy.data.objects
        if any(abs(s - 1) > 1e-6 for s in o.scale) or any(abs(r) > 1e-6 for r in o.rotation_euler)
    ]
    check(not bad_tf, "Scale = 1 และ Rotation = 0 ทุก object", ", ".join(bad_tf))

    passed = all(ok for ok, _, _ in results)
    lines = [f"# ผลตรวจ build: {spec['name']}", ""]
    if spec_label:
        lines += [f"spec: `{spec_label}`", ""]
    lines += [f"ผลรวม: {'✅ ผ่าน' if passed else '❌ ไม่ผ่าน'}", "", "| | ข้อ | รายละเอียด |", "|---|---|---|"]
    for ok, label, detail in results:
        mark = "✅" if ok else "❌"
        print(f"{mark} {label}" + (f" — {detail}" if detail else ""))
        lines.append(f"| {mark} | {label} | {detail} |")
    lines += ["", f"Triangle ต่อชิ้น: " + ", ".join(f"{n} {t}" for n, t in sorted(tris.items()))]
    if report_path:
        Path(report_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("ผลรวม:", "✅ ผ่าน" if passed else "❌ ไม่ผ่าน")
    return passed


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    spec_path = Path(args[0]).resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    palette = {k: v for k, v in json.loads(PALETTE_PATH.read_text(encoding="utf-8")).items() if not k.startswith("_")}
    out_dir = spec_path.parent / "out"
    bpy.ops.wm.open_mainfile(filepath=str(out_dir / f"{spec['name']}.blend"))
    try:
        label = spec_path.relative_to(ROOT)
    except ValueError:
        label = spec_path.name
    sys.exit(0 if run(spec, palette, out_dir / "report.md", label) else 1)


if __name__ == "__main__":
    main()
