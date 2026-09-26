"""ตรวจการเชื่อมต่อ Blender — ต้องรันทุกครั้งก่อนปั้นโมเดล (Step 0 ของ /blender-model)

  python3 tools/blender/blender_status.py            (ใช้ bpy ที่ pip install ไว้)
  blender -b -P tools/blender/blender_status.py      (ใช้โปรแกรม Blender)

ตรวจ 3 อย่าง: เรียก Blender ได้ (import bpy) · สร้าง/บันทึกไฟล์ .blend ได้ · เรนเดอร์ภาพพรีวิวได้
exit code 0 = เชื่อมต่อพร้อมปั้น · 1 = ยังไม่พร้อม (ห้ามปั้นจนกว่าจะแก้)
build_model.py เรียก connect() ของไฟล์นี้เองก่อนเริ่ม build ทุกครั้ง
"""

import sys
import tempfile
from pathlib import Path

HOW_TO_FIX = """วิธีแก้:
  - ยังไม่มี bpy: python3 -m venv <scratchpad>/bvenv && <scratchpad>/bvenv/bin/pip install -r tools/blender/requirements.txt
    (ต้องใช้ Python 3.11 ให้ตรงกับ bpy 5.0.1)
  - เรนเดอร์ไม่ได้ / error libEGL: apt-get install -y libegl1 libegl-mesa0 libgl1-mesa-dri
  - มีโปรแกรม Blender ในเครื่อง: blender -b -P tools/blender/blender_status.py"""


def connect(render_test=False):
    """คืน (พร้อมไหม, ข้อความสถานะ) · ไม่ exit เอง"""
    try:
        import bpy
    except ImportError as err:
        return False, f"🔌 ❌ ยังไม่เชื่อมต่อ Blender (import bpy ไม่ได้: {err})"

    mode = "โปรแกรม Blender" if bpy.app.binary_path and not bpy.app.binary_path.endswith("python") else "bpy module"
    version = bpy.app.version_string
    try:
        with tempfile.TemporaryDirectory() as tmp:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.mesh.primitive_cube_add()
            bpy.ops.wm.save_as_mainfile(filepath=str(Path(tmp) / "probe.blend"))
            if render_test:
                scene = bpy.context.scene
                cam = bpy.data.objects.new("ProbeCam", bpy.data.cameras.new("ProbeCam"))
                cam.location = (4, -4, 3)
                cam.rotation_euler = (1.1, 0, 0.8)
                scene.collection.objects.link(cam)
                scene.camera = cam
                scene.render.engine = "BLENDER_WORKBENCH"
                scene.render.resolution_x = scene.render.resolution_y = 32
                scene.render.filepath = str(Path(tmp) / "probe.png")
                bpy.ops.render.render(write_still=True)
                if not (Path(tmp) / "probe.png").exists():
                    raise RuntimeError("เรนเดอร์แล้วไม่ได้ไฟล์ภาพ")
            bpy.ops.wm.read_factory_settings(use_empty=True)
    except Exception as err:  # noqa: BLE001 — รายงานทุกความผิดพลาดเป็นสถานะ
        return False, f"🔌 ❌ Blender {version} ({mode}) เรียกได้ แต่ทำงานไม่ครบ: {err}"
    detail = "สร้าง/บันทึก/เรนเดอร์ได้" if render_test else "สร้าง/บันทึกได้"
    return True, f"🔌 ✅ เชื่อมต่อ Blender {version} ({mode}) · {detail}"


def main():
    ok, message = connect(render_test=True)
    print(message)
    if not ok:
        print(HOW_TO_FIX)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
