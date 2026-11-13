# AGENTS.md

Hướng dẫn cho AI agent (Claude Code, Codex, ...) khi làm việc trong repo này.

## Tổng quan dự án

- **Game:** *Chọi trâu: Đấu trường lễ hội*. Game 3D low-poly, gameplay 2.5D trên mặt phẳng XZ, camera bám sau trâu, thấp qua vai phải (nghiêng 22°).
- **Engine:** Godot 4.7, renderer GL Compatibility. Scene chính: `res://scenes/main_menu.tscn`.
- **Chế độ chơi:** SOLO (đấu AI, 3 profile) và LAN (ENet, port 7777).
- **Luật:** dùng SPIRIT và STAMINA, không có HP/gore. Trận kết thúc bằng FLEE, TIME hoặc LOT.
- **Thiết kế:** GDD chuẩn là `docs/GDD_Choi_Trau_v0.7.md` (bản mới nhất). `docs/Game-Design-Document.md` (v0.4) và `docs/GDD.md` (tóm tắt đối chiếu v0.4) chỉ để tham khảo lịch sử; lịch sử thay đổi GDD ở `docs/CHANGELOG_GDD.md`.

## Cấu trúc thư mục

**Đọc `docs/ARCHITECTURE.md` trước khi sửa code**: luồng một trận, bản đồ từng file, dữ liệu
trong `data/` và "muốn sửa X thì mở đâu".

- `scenes/`: menu, lobby, arena và trâu.
- `scripts/core/`: mô phỏng trận đấu (`match_controller.gd`, `buffalo.gd`, `combat_resolver.gd`,
  `clash_system.gd`, `arena_bounds.gd`, input, mạng) và lớp trình bày chỉ đọc (`buffalo_animator.gd`,
  `buffalo_feedback.gd`, `match_vfx.gd`, `match_audio.gd`, `follow_camera.gd`, `match_outro.gd`,
  `arena_builder.gd`, `low_poly.gd`, `ceremony_diorama.gd`). Lớp trình bày không được đổi trạng thái gameplay.
- `scripts/ai/`: FSM AI. `scripts/network/`: ENet Host/Join. `scripts/ui/`: menu, lobby, HUD, Phần Lễ.
- `data/`: mọi con số chỉnh được, đọc qua `GameBalance`. `balance.json` là luật chơi; `presentation.json`
  là hình, tiếng, HUD (không đổi kết quả trận). Thêm `levels.json`, `ai_profiles.json`, `ceremony.json`,
  `audio.json`. Không hardcode số trong script.
- `assets/shaders/`: shader (`horn_glow.gdshader`). `assets/ui/festival_theme.tres`: theme mặc định.
- `assets/characters/buffalo_hero/`: model trâu đang dùng trong game `buffalo_hero.glb`, nguồn Blender ở `assets/blender/ancient_east_water_buffalo_HERO.blend` (bản gốc duy nhất; không sửa bản copy ngoài repo).
- `assets/characters/buffalo/`: model trâu low-poly cũ `buffalo.glb` (nguồn `assets/blender/buffalo.blend`), giữ làm dự phòng; game không còn load.
- `assets/source/`, `assets/blender/`, `docs/`, `references/`: có `.gdignore`, Godot không import và không đóng gói vào bản build.
- `tools/*.py`: script Blender dựng/kiểm tra model trâu (`build_`, `polish_`, `restyle_`, `validate_buffalo.py`). `tools/run_tests.sh`: chạy toàn bộ test. `tools/profile_models.gd`: đo hiệu năng render model (thử nghiệm, không phải test).
- `references/`: ảnh tham khảo trâu. `tests/`: test headless GDScript.
- `addons/godot_mcp/`, `tools/godot-mcp/`, `.mcp.json`: Godot MCP và Blender MCP.

## Quy ước code

- File `.uid` và `.import` **phải** được commit (Godot 4.4+ cần chúng). Không commit `.godot/`.
- Theo `.editorconfig` của repo. Viết code khớp phong cách xung quanh.
- Tài liệu và README viết bằng tiếng Việt.

## Kiểm tra

Chạy test headless trước khi commit thay đổi logic:

```sh
bash tools/run_tests.sh                                        # toàn bộ, thoát 1 nếu có lỗi
godot --headless --path . --script res://tests/<tên_test>.gd   # chạy lẻ một test
```

Test mới đặt tên `tests/<tên>_test.gd` để runner tự nhận; báo lỗi bằng `quit(1)` (không dùng `assert()`). Test hai tiến trình (host/client) thêm vào `run_pair` trong `tools/run_tests.sh`.

## Quy định commit

- **Branch:** `<type>/<mô-tả-ngắn>` mô tả nội dung thay đổi, ví dụ `feat/core-gameplay-prototype`, `fix/lan-disconnect`. Không đặt tên theo ngày (`day-2`, ...).
- **Subject** theo Conventional Commits: `<type>(<scope>): <message>`
  - Ví dụ: `feat(combat): add clash hook timing`, `fix(network): handle peer disconnect`, `docs(gdd): update v0.5 notes`.
  - `type`: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `style`, `build`, `ci`.
  - `scope`: module bị ảnh hưởng, ví dụ `core`, `combat`, `ai`, `network`, `ui`, `assets`, `tools`, `gdd`.
- **Body:** tùy chọn, **tối đa 3 dòng**.
- **Không** thêm dòng `Co-Authored-By` hay bất kỳ trailer ghi công nào cho AI.
- Mỗi commit một thay đổi logic; tách commit theo nhóm (code, asset, docs) khi hợp lý.

## Theo dõi quota Codex (owner chốt 12/11/2026)

Claude Code là leader, Codex là worker chạy qua Orca. Luật này thay mọi luật limit trước đó.

Chỉ theo dõi **khung 5 giờ** của Codex; khung tuần owner tự theo dõi.

**Nhịp đọc** theo phần trăm còn lại: trên 50%: 15 phút · 31–50%: 5 phút · 20–30%: 90 giây ·
7–19%: 1 phút · dưới 7%: 30 giây.

**Dưới 20%: dừng êm**, không để worker bị cắt ngang:
1. Leader nhắn worker bằng `orca orchestration send --to dispatch:<id>`: làm nốt việc đang dở tới điểm
   lưu gần nhất rồi dừng, không nhận việc mới.
2. Worker dừng ở điểm lưu, ghi tiến độ vào report của run: phần đã xong, phần dở, vị trí cụ thể
   (file/node), bước tiếp theo.
3. Leader kiểm tiến độ thật (file, canvas, evidence), rồi cập nhật handoff, plan và các md liên quan.
4. Leader và worker cùng tạm ngừng. Leader không tự làm thay; chỉ làm tiếp khi owner ra lệnh.

**Từ 3% trở xuống:** dừng worker ngay dù chưa tới điểm lưu, kiểm phần ghi dở, rồi làm bước 2–4.

**Làm tiếp:** owner đổi sang tài khoản Codex khác và ra lệnh thì mở worker Codex mới với spec tiếp nối.
Nếu chờ quota reset thì đợi tới giờ reset cộng 2 phút rồi mới giao lại. Không dùng Antigravity làm
worker thay thế.

**Cách đọc quota:**
- Thanh trạng thái Codex phải có `five-hour-limit` trong `tui.status_line` của `~/.codex/config.toml`
  và của mỗi account home Orca (`%APPDATA%\orca\codex-accounts\*\home\config.toml`).
- Đọc từ terminal của worker:
  `orca terminal read --terminal <t> --screen | grep -oE '5h [0-9]+% left' | tail -1 | sed -E 's/^5h ([0-9]+)% left$/\1/' || true`.
  Không đọc được số thì **không** coi là còn quota.
- Terminal không hiện số: đọc `primary.used_percent` (khung 300 phút) trong `rollout-*.jsonl` mới nhất
  của account đang dùng (`%APPDATA%\orca\codex-accounts\<id>\home\sessions\`); còn lại = 100 − số đó.
- Mỗi worker mới phải bật lại Monitor gắn với terminal của worker đó. Monitor chỉ đọc dòng quota,
  không đọc mail Orca, không điều khiển worker.
