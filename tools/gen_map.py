"""สร้างพื้นแมพแบบบล็อก → map/ground.project.json (Rojo sync เข้า Workspace.MapGround ให้เห็นใน Studio ตอนแก้แมพ)
และภาพผังมุมบน → docs/map-sketch/map-v2.png

รันซ้ำได้ทุกครั้งที่แก้ตัวเลข:  python3 tools/gen_map.py
ตัวเลขต้องตรงกับ src/shared/Config/Map.luau (หมวด "พื้น", Pit, Road, Base, Yard)
ใช้ไลบรารีมาตรฐานเท่านั้น

สีของบล็อกบอกโซน (เห็นได้ทันทีใน Studio):
  ส้มลายสลับ = พื้นทั่วไป · เหลืองทราย 3 ขั้น = แอ่งเก็บของ/จุดบอส · ส้มเข้ม = ถนนวงแหวน
  ครีม = ลานฐาน 8 ช่อง · พีช = สวนหลังบ้าน (มอนเกิด) · น้ำตาล = กำแพงขอบแมพ
"""

import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ---- ต้องตรงกับ Config/Map.luau ----
GROUND_Y = 1
RADIUS = 400
TILE = 16
EDGE_HEIGHT = 3
PIT_STEPS = [(45, 3), (75, 2), (100, 1)]  # (รัศมีไม่เกิน, ความลึก) เรียงจากในออกนอก
ROAD = (100, 130)
MAX_BASES = 8
BASE_DISTANCE = 200
BASE_SIZE = 110
YARD = (260, 350, math.radians(18))
TURRET_DISTANCE = 140
BOTTOM_Y = GROUND_Y - 5  # ก้นของทุกบล็อก (บล็อกเป็นเสาถึงระดับเดียวกัน ไม่มีช่องโหว่ข้างขั้นบันได)

COLORS = {
    "floor": ((243, 163, 72), (228, 141, 52)),
    "pit": ((255, 214, 110), (242, 192, 82)),
    "road": ((200, 116, 42), (186, 104, 34)),
    "pad": ((244, 228, 198), (234, 214, 180)),
    "yard": ((251, 198, 150), (243, 184, 134)),
    "edge": ((150, 86, 38), (138, 78, 32)),
}


def slot_axes(slot):
    angle = -math.pi / 2 + (slot - 1) * 2 * math.pi / MAX_BASES
    return angle, (math.cos(angle), math.sin(angle)), (-math.sin(angle), math.cos(angle))


def angle_diff(a, b):
    return abs((a - b + math.pi) % (2 * math.pi) - math.pi)


def pit_depth(r):
    for outer, depth in PIT_STEPS:
        if r < outer:
            return depth
    return 0


def zone(x, z):
    r = math.hypot(x, z)
    if r < PIT_STEPS[-1][0]:
        return "pit"
    if ROAD[0] <= r < ROAD[1]:
        return "road"
    a = math.atan2(z, x)
    for slot in range(1, MAX_BASES + 1):
        angle, out, right = slot_axes(slot)
        u = x * out[0] + z * out[1]
        v = x * right[0] + z * right[1]
        if abs(u - BASE_DISTANCE) <= BASE_SIZE / 2 and abs(v) <= BASE_SIZE / 2:
            return "pad"
        if YARD[0] <= r <= YARD[1] and angle_diff(a, angle) <= YARD[2]:
            return "yard"
    return "floor"


def build_tiles():
    count = int(RADIUS // TILE) + 1
    inside = {}
    for ix in range(-count, count + 1):
        for iz in range(-count, count + 1):
            x, z = ix * TILE, iz * TILE
            if math.hypot(x, z) <= RADIUS - TILE / 2:
                inside[(ix, iz)] = (x, z)

    tiles = []
    for (ix, iz), (x, z) in sorted(inside.items()):
        edge = any((ix + dx, iz + dz) not in inside for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        kind = "edge" if edge else zone(x, z)
        top = GROUND_Y + (EDGE_HEIGHT if edge else -pit_depth(math.hypot(x, z)))
        shade = (ix + iz) % 2
        tiles.append({"ix": ix, "iz": iz, "x": x, "z": z, "top": top, "kind": kind, "color": COLORS[kind][shade]})
    return tiles


def write_project(tiles):
    children = {}
    for t in tiles:
        height = t["top"] - BOTTOM_Y
        name = f"{'Pit' if t['kind'] == 'pit' else 'Tile'}_{t['ix']}_{t['iz']}"
        children[name] = {
            "$className": "Part",
            "$properties": {
                "Anchored": True,
                "Locked": True,
                "CanTouch": False,
                "Material": "SmoothPlastic",
                "TopSurface": "Studs",
                "BottomSurface": "Smooth",
                "Color": [round(c / 255, 5) for c in t["color"]],
                "Size": [TILE, height, TILE],
                "Position": [t["x"], BOTTOM_Y + height / 2, t["z"]],
            },
        }
    project = {"name": "MapGround", "tree": {"$className": "Folder", **children}}
    out = ROOT / "map" / "ground.project.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(project, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return out


def write_preview(tiles):
    """ภาพมุมบน: 1 บล็อก = 4 px · เส้นขาว = ป้อม 8 จุด · กากบาทแดง = จุดบอส"""
    scale = 4
    count = int(RADIUS // TILE) + 1
    px = TILE * scale // 2  # พิกเซลต่อบล็อก
    width = (2 * count + 1) * px
    image = [[(40, 44, 52)] * width for _ in range(width)]

    def put(cx, cz, color, half):
        for yy in range(cz - half, cz + half):
            for xx in range(cx - half, cx + half):
                if 0 <= xx < width and 0 <= yy < width:
                    image[yy][xx] = color

    def to_px(x, z):
        return int((x / TILE + count + 0.5) * px), int((z / TILE + count + 0.5) * px)

    for t in tiles:
        cx, cz = to_px(t["x"], t["z"])
        put(cx, cz, t["color"], px // 2)
    for slot in range(1, MAX_BASES + 1):
        _, out, _ = slot_axes(slot)
        cx, cz = to_px(out[0] * TURRET_DISTANCE, out[1] * TURRET_DISTANCE)
        put(cx, cz, (255, 255, 255), 3)
    cx, cz = to_px(0, 0)
    for d in range(-8, 9):
        put(cx + d, cz + d, (220, 40, 40), 1)
        put(cx + d, cz - d, (220, 40, 40), 1)

    raw = bytearray()
    for row in image:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    out = ROOT / "docs" / "map-sketch" / "map-v2.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, width, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    return out


if __name__ == "__main__":
    tiles = build_tiles()
    counts = {}
    for t in tiles:
        counts[t["kind"]] = counts.get(t["kind"], 0) + 1
    print(f"wrote {write_project(tiles)} — {len(tiles)} blocks {counts}")
    print(f"wrote {write_preview(tiles)}")
