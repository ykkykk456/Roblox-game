#!/usr/bin/env python3
"""ตรวจว่าไฟล์ .lua/.luau เปลี่ยนแค่คอมเมนต์ (เทียบกับ git ref) — ใช้หลังงาน "เพิ่มคอมเมนต์อย่างเดียว"
วิธีใช้: python3 tools/check_comments_only.py [ref=HEAD]
ตัดคอมเมนต์ --[[ ]] / -- ... และบรรทัดว่างออกทั้งสองฝั่ง แล้วเทียบโค้ดที่เหลือ (ไม่สนช่องว่างท้ายบรรทัด)"""
import subprocess, sys

def strip(src: str) -> list[str]:
    out, i, n = [], 0, len(src)
    buf = []
    while i < n:
        c = src[i]
        if c in "\"'`":  # สตริง: เก็บทั้งก้อน
            q = c; buf.append(c); i += 1
            while i < n and src[i] != q:
                if src[i] == "\\": buf.append(src[i]); i += 1
                if i < n: buf.append(src[i]); i += 1
            if i < n: buf.append(src[i]); i += 1
            continue
        if src.startswith("[[", i) or src.startswith("[=[", i):
            end = "]]" if src.startswith("[[", i) else "]=]"
            j = src.find(end, i); j = n if j < 0 else j + len(end)
            buf.append(src[i:j]); i = j; continue
        if src.startswith("--", i):
            if src.startswith("--[[", i) or src.startswith("--[=[", i):
                end = "]]" if src.startswith("--[[", i) else "]=]"
                j = src.find(end, i); i = n if j < 0 else j + len(end)
            else:
                j = src.find("\n", i); i = n if j < 0 else j
            continue
        buf.append(c); i += 1
    for line in "".join(buf).split("\n"):
        s = line.rstrip()
        if s.strip():
            out.append(s)
    return out

ref = sys.argv[1] if len(sys.argv) > 1 else "HEAD"
files = subprocess.run(["git", "diff", "--name-only", ref, "--", "*.lua", "*.luau"], capture_output=True, text=True).stdout.split()
bad = 0
for f in files:
    try:
        old = subprocess.run(["git", "show", f"{ref}:{f}"], capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError:
        print(f"NEW  {f}"); bad += 1; continue
    try:
        new = open(f, encoding="utf-8").read()
    except FileNotFoundError:
        print(f"DEL  {f}"); bad += 1; continue
    if strip(old) != strip(new):
        bad += 1
        a, b = strip(old), strip(new)
        for k in range(max(len(a), len(b))):
            if k >= len(a) or k >= len(b) or a[k] != b[k]:
                print(f"CODE {f}\n  เดิม: {a[k] if k < len(a) else '<จบ>'}\n  ใหม่: {b[k] if k < len(b) else '<จบ>'}")
                break
    else:
        print(f"ok   {f}")
print("ผ่าน: เปลี่ยนแค่คอมเมนต์" if bad == 0 else f"ไม่ผ่าน {bad} ไฟล์")
sys.exit(1 if bad else 0)
