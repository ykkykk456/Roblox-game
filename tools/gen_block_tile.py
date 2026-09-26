"""สร้างภาพ texture พื้นบล็อกสีส้ม (ต่อกันได้ไร้รอยต่อ) → assets/textures/block_tile.png

รันซ้ำได้: python3 tools/gen_block_tile.py
ภาพ 1 แผ่น = 6 x 6 ช่อง · ช่องละ 32 px · สลับบล็อกสีอ่อน/เข้มทีละ 3 x 3 ช่อง
แต่ละช่องมีปุ่มสี่เหลี่ยมนูน หรือเส้นมุมรูปตัว L สลับกัน (เลียนแบบภาพอ้างอิงของเจ้าของเกม)
ใช้ไลบรารีมาตรฐานเท่านั้น (ไม่ต้องติดตั้ง Pillow)
"""

import struct
import zlib
from pathlib import Path

CELL = 32
CELLS = 6
SIZE = CELL * CELLS

LIGHT = (243, 163, 72)
DARK = (228, 141, 52)


def shade(color, amount):
    return tuple(max(0, min(255, round(c * amount))) for c in color)


def pixel(x, y):
    cx, cy = x // CELL, y // CELL
    base = LIGHT if ((cx // 3) + (cy // 3)) % 2 == 0 else DARK
    lx, ly = x % CELL, y % CELL

    # ร่องระหว่างช่อง
    if lx < 2 or ly < 2:
        return shade(base, 0.86)
    # ขอบนูนบน-ซ้าย / เงาล่าง-ขวาของช่อง
    if lx < 4 or ly < 4:
        return shade(base, 1.06)
    if lx > CELL - 3 or ly > CELL - 3:
        return shade(base, 0.93)

    if (cx + cy) % 2 == 0:
        # ปุ่มสี่เหลี่ยมนูนกลางช่อง
        lo, hi = 11, 22
        if lo <= lx <= hi and lo <= ly <= hi:
            if lx <= lo + 1 or ly <= lo + 1:
                return shade(base, 1.08)
            if lx >= hi - 1 or ly >= hi - 1:
                return shade(base, 0.8)
            return shade(base, 0.9)
    else:
        # เส้นมุมรูปตัว L ด้านบนซ้าย
        if (8 <= lx <= 20 and 8 <= ly <= 10) or (8 <= lx <= 10 and 8 <= ly <= 20):
            return shade(base, 0.8)
    return base


def write_png(path: Path):
    raw = bytearray()
    for y in range(SIZE):
        raw.append(0)  # filter: none
        for x in range(SIZE):
            raw.extend(pixel(x, y))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "assets" / "textures" / "block_tile.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_png(out)
    print(f"wrote {out} ({SIZE}x{SIZE})")
