# AGENTS.md

Hướng dẫn cho AI agent (Claude Code, Codex, ...) khi làm việc trong repo này.

## Tổng quan dự án

- **Game:** *Chọi trâu: Đấu trường lễ hội*. Game 3D low-poly, gameplay 2.5D trên mặt phẳng XZ, camera bám sau trâu (góc nghiêng 45°).
- **Engine:** Godot 4.7, renderer GL Compatibility. Scene chính: `res://scenes/main_menu.tscn`.
- **Chế độ chơi:** SOLO (đấu AI, 3 profile) và LAN (ENet, port 7777).
- **Luật:** dùng SPIRIT và STAMINA, không có HP/gore. Trận kết thúc bằng FLEE, TIME hoặc LOT.
- **Thiết kế:** GDD chuẩn là `docs/GDD_Choi_Trau_v0.7.md` (bản mới nhất). `docs/Game-Design-Document.md` (v0.4) và `docs/GDD.md` (tóm tắt đối chiếu v0.4) chỉ để tham khảo lịch sử; lịch sử thay đổi GDD ở `docs/CHANGELOG_GDD.md`.

## Cấu trúc thư mục

- `scenes/`: menu, lobby, arena và trâu.
- `scripts/core/`: logic lõi (balance, input frame, session state, trâu, trận đấu: `match_controller.gd`, `combat_resolver.gd`, `clash_system.gd`, `arena_builder.gd`, `arena_bounds.gd`, `match_input.gd`, `match_network.gd`).
- `scripts/ai/`: FSM AI. `scripts/network/`: ENet Host/Join. `scripts/ui/`: menu, lobby, HUD. Camera bám trâu ở `scripts/core/follow_camera.gd`.
- `data/`: chỉ số game (`balance.json`, `levels.json`, `ai_profiles.json`). Chỉnh balance ở đây, không hardcode trong script.
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
