# 09_Workflows — สารบัญ Workflow

Workflow ทุกตัวย้ายไปเป็น **Claude Skill** ที่ `.claude/skills/` (ที่ root ของ repo) เพื่อให้ Claude Code โหลดเองเมื่องานตรงกัน และโหลด Skill บทบาทเป็นราย Step แทนการโหลดทั้งหมดตั้งแต่ต้น
เนื้อหาเป็น Markdown ธรรมดา คนหรือ AI ตัวอื่นเปิดอ่านได้เหมือนเดิม

| งาน | Skill (พิมพ์ใน Claude Code) | ไฟล์ |
|---|---|---|
| หาไอเดีย/แก้ปัญหาผู้เล่น (Design Thinking) | `/roblox-design-thinking` | `.claude/skills/roblox-design-thinking/SKILL.md` |
| ฟีเจอร์ใหม่ (ระบบ + UI) | `/roblox-feature` | `.claude/skills/roblox-feature/SKILL.md` |
| สร้าง/แก้หน้าจอ UI | `/roblox-ui` | `.claude/skills/roblox-ui/SKILL.md` |
| แก้บั๊ก | `/roblox-bugfix` | `.claude/skills/roblox-bugfix/SKILL.md` |
| ปรับราคา/Balance | `/roblox-economy` | `.claude/skills/roblox-economy/SKILL.md` |
| สร้างแมพ/ฉาก (World_Builder) | `/roblox-map` | `.claude/skills/roblox-map/SKILL.md` |
| ตรวจก่อนส่ง (QA + Security) | `/roblox-review` | `.claude/skills/roblox-review/SKILL.md` |

งานเล็กที่เข้าเกณฑ์ **Fast Lane** (ดู `CLAUDE.md`) ไม่ต้องใช้ Workflow
