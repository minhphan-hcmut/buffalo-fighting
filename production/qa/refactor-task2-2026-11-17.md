# Task 2 — Pause/settings/LAN result, 17/11/2026

## Kết quả và giới hạn

Triển khai giới hạn Task 2, không commit/subworker, không đổi simulation/balance/transport/SessionState/menu. **Full runner chạy đúng một lần: exit 0, 79 checks, 0 failed** (baseline Task 1: 78 checks). Không chạy cửa sổ/chụp ảnh: main còn review actual diff và nghiệm thu render/input 720p/1080p; headless không chứng minh render acceptance. Shutdown ObjectDB/resources diagnostics vẫn xuất hiện, không tuyên bố log sạch hay sửa leak toàn ứng dụng.

Đã đọc AGENTS/CLAUDE, ARCHITECTURE, spec/plan, baseline compatibility và Task1 final gate, toàn bộ HUD/controller và affected tests trước sửa. Giữ edits Task 0/1 có sẵn, gồm `tests/training_parry_rest_test.gd` physics-frame repair và `tests/network_client_harness.gd`; không sửa hai file này. `tests/pause_test.gd`/`settings_screen_test.gd` không cần sửa: coverage mới nằm trong test lifecycle mới, mọi assertions cũ giữ nguyên.

## Ownership/API/diff

- NEW `scripts/ui/match_pause_view.gd` (+ Godot-generated UID): Node scene-owned quản lý **một** overlay shell, pause/wait/confirmation actions, SettingsScreen và lifecycle/focus restoration. Nhận root Control + dictionary callbacks `resume/restart/leave/change_training/answer/sensitivity`; không nhận HUD hoặc controller. Shell vẫn là con của HUD root, root vẫn `get_child(0)`.
- NEW `scripts/ui/lan_result_view.gd` (+ UID): Node scene-owned nhận chính pause shell, rematch/leave Callables; render text/stats/status read-view, không sở hữu controller/network hay collector mới. `MatchStats` duy nhất tiếp tục được HUD tạo và subscribe như trước.
- `scripts/ui/hud.gd`: façade delegation giữ readable/writable properties `pause_overlay/panel/title/detail/actions`, `settings_screen/showing_settings`, `lan_result_shown/rematch_button/note`, `stats_panel`; giữ các methods cũ `_place_pause_panel`, `_clear_pause_actions`, `_pause_button`, `_show_lan_result`, `_return_to_menu` cùng public pause/settings/rematch methods. Task1 tutorial/training và HUD dirty/text-scale code giữ nguyên. HUD 983 → 842 dòng; hai module mới 206/119 dòng.
- **Public HUD additions duy nhất:** `close_settings_if_open() -> bool` (true chỉ khi đóng modal đang mở, không thay pause), `return_to_menu() -> void` (logic menu cũ). `_return_to_menu()` là compatibility alias. Controller chỉ đổi 2 call sites: Esc settings gọi close intent; LAN ready-result Esc gọi public menu intent. Controller không còn đọc `settings_screen/showing_settings` hoặc gọi private `_return_to_menu`; phase/tick/payload/outro order không đổi.
- Result và pause dùng cùng shell: ResultShade/PauseShade, alignment/font/panel anchors và stats được reset rõ khi quay lại pause; không tạo overlay thứ hai. Shell free khi modal mở sẽ close modal trước khi mất cây để trả focus modes cho covered controls, xóa rematch references và có thể dựng lại qua `show_pause()`.
- Presenter signals dùng bound methods (không lambda giữ HUD trong SettingsScreen), tweens từ UiMotion vẫn gắn node nút; owner exit đóng modal/nhả shell và callback references. Không thêm global subscription.
- `tests/network_host_harness.gd`: thêm `answering_pause_request/answered_pause_state` guard, chỉ ghi accepted pause/resume trong **synchronous answer của actual request**, không dùng `connected` làm consent. Giữ fresh seq/marker và toàn bộ Task0 checks.
- `tests/lan_rematch_pair.gd`: thêm assertions fresh result refs/hidden clean shell sau scene reload; dùng public menu intent ở hai đường leave. Giữ mọi ENet identity/epoch/stats/result/disconnect assertions.
- NEW `tests/match_overlay_lifecycle_test.gd` (+ UID): 25 checks qua arena/controller/viewport input và manager thật: public close consumption, Solo/LAN Esc giữ pause/focus, shell free/recreate, same root/shade identity, result→pause clean layout/stats, request→confirmation button→manager pause, peer disconnect lúc pause/settings→CONNECTION_LOST và rematch disabled/menu focus. Host harness positive actual pause/resume và negative connected reset(false)/disconnect(false) đi cặp; không dùng connected để phân loại.

## RED → GREEN (evidence `/tmp/ltrgame-task2`)

Test mới đầu tiên chạy trên implementation baseline, `logs/red.log`, **exit 1**, bốn failures có chủ đích:
1. `HUD exposes explicit settings-close and menu intents`.
2. `show_pause recreates a freed overlay`.
3. `connected reset(false) without answered request is NOT accepted resume`.
4. `disconnect while paused is NOT accepted resume`.

Không Parse Error/SCRIPT ERROR. Test guard baseline missing recreation để RED là assertion failure, không crash invalid access. Sau extraction + guard harness: `logs/green1.log` **exit 0**, 18 checks. Bổ sung real LAN controller/confirmation/disconnect regression và paired rematch reset checks: `logs/green2.log` **exit 0**, 25 checks. Existing behavior regressions bổ sung đi qua code thật; không tuyên bố chúng từng fail baseline. Không có failed implementation attempt sau RED, không retry cùng defect để ép xanh.

### Commands/exits

Working root `/home/konits/projects/ltrgame/buffalo-fighting`, runtime duy nhất `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`.

```sh
mkdir -p /tmp/ltrgame-task2/{data,config,cache,logs}
# RED, GREEN1, GREEN2: cùng command, output lần lượt red.log/green1.log/green2.log
 env XDG_DATA_HOME=/tmp/ltrgame-task2/data \
 XDG_CONFIG_HOME=/tmp/ltrgame-task2/config XDG_CACHE_HOME=/tmp/ltrgame-task2/cache \
 timeout 90 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
 --headless --path . --script res://tests/match_overlay_lifecycle_test.gd
```

Focused import `--headless --path . --editor --import --quit` với `timeout 90`: exit 0, tạo ba UID mới. Cùng XDG isolation, `timeout 120 <Godot> --headless --path . --script res://tests/<name>.gd` cho `pause_test`, `settings_screen_test`, `pause_layout_test`, `ui_hierarchy_test`, `hud_presenters_test`, `rumble_hud_screenshot_test`, `lan_result_camera_test`: **mỗi exit 0**. Logs `<name>.log` trong evidence logs.

Focused pairs cùng XDG isolation, mỗi process `timeout 90`, host chạy nền rồi `sleep 2`, client foreground, `wait host`: `network_host_harness.gd`/`network_client_harness.gd` và `lan_rematch_pair.gd -- --host`/`-- --client`; cả bốn process **exit 0**. Logs `network_{host,client}.log`, `lan_rematch_{host,client}.log`.

Full suite **một lần**, không retry:

```sh
env XDG_DATA_HOME=/tmp/ltrgame-task2/full-data \
 XDG_CONFIG_HOME=/tmp/ltrgame-task2/full-config \
 XDG_CACHE_HOME=/tmp/ltrgame-task2/full-cache \
 GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
 TEST_LOG_DIR=/tmp/ltrgame-task2/logs/full TEST_TIMEOUT=180 \
 timeout 1800 bash tools/run_tests.sh \
 > /tmp/ltrgame-task2/logs/full-runner.log 2>&1
```

`logs/full-runner.exit`: **0**; runner final line **79 checks, 0 failed**. Full includes all five LAN pairs (network, match, rematch, ping, combat readability) and preserved training physics-frame regression. Scan `rg -n 'SCRIPT ERROR|Parse Error' logs/full`: no matches. All `ERROR:` lines observed in full scan are resource-at-exit diagnostics (including nested restart child output); ObjectDB/PagedAllocator shutdown noise also retained. `git diff --check`: exit 0.

## Cleanup / main gate

Không tạo GUI/server/proxy/worker terminal nào. Focused pairs và full runner đã wait host, mọi timeout/Godot processes kết thúc; `ps` không còn task-owned Godot/runner process. Xóa isolated `data/config/cache/full-data/full-config/full-cache`; giữ logs và scratch baseline pause block trong `/tmp/ltrgame-task2` cho audit, không xóa shared `.godot` hay dữ liệu người dùng. Không đụng draft GDD v0.8, Task1 evidence/docs hoặc edits khác.

Main còn actual diff review và window render/input 720p/1080p cho pause, settings/focus, wait/confirmation, LAN outro/readiness/result/rematch/peer-left, text scale và mouse capture; Task 2 implementation/headless bounded gate không tự thay acceptance này. Tasks 3–4 và shutdown leak investigation ngoài task.
