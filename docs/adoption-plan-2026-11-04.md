# Kế hoạch adoption — Chọi trâu: Đấu trường lễ hội

> **Generated**: 2026-11-04
> **Project phase**: Production (suy luận: 20 file `.gd`, ~3.800 dòng, 15 test headless)
> **Engine**: Godot 4.7, GL Compatibility (theo `project.godot`) — **chưa khai báo** trong `project.yaml` của studio
> **Template version**: CCGS 1.2.0 (`ltrgame/project.yaml`)
> **Workflow tier**: `minimal` (mặc định, chưa chạy `/start`)

Làm theo thứ tự. Đánh dấu từng mục khi xong. Chạy lại `/adopt` bất cứ lúc nào để kiểm tra lại.

---

## Step 1: Fix Blocking Gaps

### 1.1 Studio và game nằm ở hai root khác nhau
**Vấn đề:** Studio (`.claude/`, `project.yaml`, `design/`, `production/`) nằm ở `ltrgame/`, còn game là repo git con `ltrgame/buffalo-fighting/` với code ở `scripts/` (không phải `src/`). Mọi skill đọc `ltrgame/design/` và `ltrgame/production/` nên thấy dự án trống — hook SessionStart đã báo "NEW PROJECT".

**Cách xử lý (chọn một):**
- **A (khuyến nghị):** Coi `buffalo-fighting/` là project root của studio: copy/symlink `.claude/`, `CLAUDE.md`, `project.yaml` vào đó (hoặc mở Claude Code tại `buffalo-fighting/`), giữ `scripts/` làm code root (Godot không bắt buộc `src/`).
- **B:** Giữ studio ở `ltrgame/`, khai báo đường dẫn code root/tests/docs trỏ vào `buffalo-fighting/` trong `project.yaml`.

Lưu ý xung đột quy ước: `buffalo-fighting/AGENTS.md` cấm trailer `Co-Authored-By` và giới hạn body commit 3 dòng — quy định của repo game được ưu tiên.

**Time**: 30 min
- [x] Đã chọn A và áp dụng (2026-11-04): symlink `.claude/*` → `../../.claude/`, copy `project.yaml`, tạo `design/`, `production/`, cập nhật `.gitignore`
- [ ] Biết trước: hook `detect-gaps.sh` chỉ tìm code ở `src/`/`Assets/`/`Source/`, nên sẽ vẫn báo "no source code" dù code nằm ở `scripts/`
- [ ] Mở session mới tại root đã chọn, hook không còn báo "NEW PROJECT"

---

## Step 2: Fix High-Priority Gaps

### 2.1 Engine chưa cấu hình trong studio
**Vấn đề:** `project.yaml` không có `engine.*`, `technical-preferences.md` còn `[TO BE CONFIGURED]` — skill kỹ thuật và agent specialist không biết đây là Godot/GDScript.
**Fix:** `/setup-engine` → Godot 4.7, GDScript, GL Compatibility, physics mặc định của 4.7 (ghi lại bản editor đã cài vào `VERSION.md`).
**Time**: 30 min
- [ ] `engine.name/version/language/rendering/physics` có trong `project.yaml`
- [ ] `specialists.code` = `godot-gdscript-specialist`

### 2.2 Thiếu `design/game-brief.md`
**Vấn đề:** Ở tier `minimal`, brief là bản ghi thiết kế duy nhất mà skill đọc; GDD hiện có (`docs/Game-Design-Document.md`, 35 KB, 13 chương theo rubric) không khớp định dạng nào skill nhận ra.
**Fix:** `/reverse-document` từ `docs/Game-Design-Document.md` + code hiện có → `design/game-brief.md` theo `.claude/docs/templates/game-brief.md` (6 trường bắt buộc: core loop, MVP, build order...). Không sửa GDD gốc.
**Time**: 1 session
- [ ] `design/game-brief.md` có đủ 6 trường bắt buộc, không còn placeholder

---

## Step 3: Bootstrap Infrastructure

Not on the minimal path — the brief's build order is the plan. Next: `/create-stories` (or `/dev-story` once stories exist).

---

## Step 4: Medium-Priority Gaps

### 4.1 Không chạy được test headless trên máy này
**Vấn đề:** `godot`/`godot4` không có trong PATH, nên 15 test trong `tests/` và yêu cầu "run-and-observe" (screenshot evidence) không thực hiện được.
**Fix:** Cài Godot 4.7.x hoặc tạo symlink `~/.local/bin/godot`.
**Time**: 5 min
- [ ] `godot --version` trả về 4.7.x
- [ ] Tất cả lệnh test trong `README.md` pass

### 4.2 Test framework khác chuẩn studio
**Vấn đề:** Test là script `--script` tự viết, trong khi lệnh CI của studio giả định gdUnit4 (`addons/gdUnit4/`). `/smoke-check`, `/regression-suite`, `/test-evidence-review` sẽ không tìm thấy runner.
**Fix:** `/test-setup` — chọn: bọc các test hiện có bằng một runner script, hoặc chuyển dần sang gdUnit4. Không xóa test cũ.
**Time**: 1 session
- [ ] Có một lệnh duy nhất chạy toàn bộ test, trả exit code ≠ 0 khi fail

### 4.3 Chưa chọn rigor / chưa chạy onboarding
**Vấn đề:** `project.yaml` không có `modes.rigor`/`modes.automation`; mọi thứ đang chạy theo mặc định (`minimal`, `solo`).
**Fix:** `/start` (nhánh "bring in an existing game") hoặc `/settings modes.rigor=<...>`.
**Time**: 5 min
- [ ] `modes.rigor` được đặt có chủ đích

### 4.4 Naming và performance budget chưa cấu hình
**Vấn đề:** `naming.*`, `performance.*` trống — `/code-review`, `/perf-profile`, `/asset-audit` không có chuẩn để so.
**Fix:** Điền qua `/setup-engine` hoặc `/settings` (snake_case file/hàm, PascalCase class theo GDScript; budget FPS/draw call cho GL Compatibility).
**Time**: 30 min
- [ ] `naming.*` và `performance.*` có giá trị

---

## Step 5: Optional Improvements

### 5.1 GDD không theo 8 section chuẩn (advisory ở `minimal`)
`docs/Game-Design-Document.md` thiếu cả 8 heading chuẩn (Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria). Chỉ cần nếu sau này nâng lên `standard`/`full`: tách theo hệ thống bằng `/design-system retrofit` vào `design/gdd/`.
- [ ] (tùy chọn) Tách GDD theo hệ thống

### 5.2 Tài liệu thiết kế trùng lặp
Có `docs/GDD.md` (tóm tắt), `docs/Game-Design-Document.md` (đầy đủ) và `docs/GDD_Skeleton_Choi_Trau_v0.4.docx`. Ghi rõ bản nào là nguồn sự thật trong `AGENTS.md`/brief để agent không đọc nhầm.
- [ ] Đã chỉ định một nguồn sự thật

---

## What to Expect from Existing Stories

Chưa có story nào. Khi tạo bằng `/create-stories`, story sẽ có đủ trường theo template.

---

## Re-run

Chạy lại `/adopt` sau khi xong Step 2 để xác nhận không còn gap BLOCKING/HIGH.
