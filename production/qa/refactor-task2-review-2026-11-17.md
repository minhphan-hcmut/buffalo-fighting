# Task 2 — independent review, 17/11/2026

## Kết luận / finding

Không tìm thấy production regression cụ thể trong Task 2 qua actual code review và các transitions đã chạy. **Render gate LAN hai tiến trình chưa hoàn tất**: xem R1; main quyết định accept/reject, không dùng báo cáo này để tuyên bố LAN window acceptance đầy đủ.

- **R1 — Medium, verification gap (không quy lỗi production):** `tests/lan_rematch_pair.gd:45` (`await manager.lobby_ready`), temporary window-copy tương ứng. Hai cặp window/Xvfb 720/1080 chỉ in `LAN connection starts` trên cả hai phía rồi timeout ngoài 100 s (exit 124 cả bốn process), không tới assertion/result capture; ngay cả timer 55 s của harness không in timeout. Hybrid headless-host/window-client: host tới first result rồi timer 55 s fail (exit 1), client chỉ tới connection starts rồi outer timeout 124. **Không có ảnh actual ENet pair**. Chạy unmodified headless pair để phân loại: cả host/client exit 0, 15/16 checks và `FAILURES: 0`. Điều này không xác định nguyên nhân window runtime/event loop/transport và không cho phép tuyên bố refactor gây lỗi; main cần reproduction nhỏ/window harness riêng trước khi đóng LAN rendered gate. Không âm thầm sửa production/test để vượt qua.

## Phạm vi review và phân biệt Task 0/1

Đọc AGENTS/CLAUDE, approved spec/plan, baseline compatibility, Task1 final gate, Task2 implementation report; đọc đầy đủ `match_pause_view.gd` (206), `lan_result_view.gd` (119), HUD façade (842), lifecycle test (149), rematch pair (120), host/client harnesses (104/81), actual full HUD/controller/test diffs và các settings/network liên quan. Đọc toàn bộ existing `review_window_harness.gd`, `review_lan_window_harness.gd`, `settings_window_harness.gd` và rematch harness trước dùng.

Task0 có sẵn: host event/deadline stages, sequence/fresh marker và client stream 30 Hz; Task2 chỉ thêm synchronous answer guard vào host. Task1 có sẵn: tutorial/training presenters, delegated state, presenter regression và training physics-frame repair; không tính các thay đổi này thành Task2. Task2 là pause/result presenters, HUD ownership/delegation, hai public intents và controller hai call sites, lifecycle regression mới, hai rematch reset checks + public-menu calls, host guard.

Controller diff chỉ thay private menu call bằng public intent và settings property/private close bằng `close_settings_if_open()` bool. Không thay simulation/tick order/payload/transport/data/SessionState; HUD process simulation-independent behavior còn nguyên ngoài presenters Task1 có sẵn. Không phát hiện đổi gameplay từ extraction.

### Ownership / lifecycle

- Pause presenter nhận root + injected resume/restart/leave/change-training/answer/sensitivity Callables; result presenter nhận shell + rematch/leave, không nhận controller/network. HUD giữ một MatchStats collector/event subscription; result chỉ tạo display block.
- Một shell dưới HUD root, presenters được add sau root nên `get_child(0)` contract còn nguyên. SettingsScreen là con shell; result/pause dùng chung actions/stats, không có state mirror.
- `clear_actions()` phát signal xóa rematch refs, detach/free stats và actions; `_prepare_pause()` reset result shade, anchors, alignment/font. Result `_clear_refs()` đặt `lan_result_shown=false`; show_result đặt true sau clear. Rematch scene reload kiểm refs/stats zero và fresh hidden shell.
- Shell tree_exiting close modal để phục hồi covered focus modes, clear refs; ensure_shell dựng lại khi invalid. Bound signal methods và node-owned tweens không thêm global subscription. Window harness dùng weakref xác nhận SettingsScreen cũ đã free, chờ thêm frame rồi kiểm rebuilt shell không bị old callback đổi state; không có SCRIPT ERROR ở final render logs.
- Settings Esc qua `Viewport.push_input`/controller giữ Solo/training/LAN pause và trả focus opener. Settings mở bằng actual mouse event ở Solo/training. Confirmation action đi qua real manager answer; staged disconnect khi paused/settings đóng modal và disable rematch, menu là available primary.
- Host guard chỉ ghi consent trong synchronous call `answer_pause(true)` của actual request và khi state trùng request; connected reset(false)/leave(false) không được coi resume. Assertions fresh marker/sequence và pause request count giữ nguyên; không giảm coverage để xanh.

## Audit 79/79 (không rerun full suite)

Đã đọc `/tmp/ltrgame-task2/logs/full-runner.exit` = **0**, runner log có **79 PASS rows, 79 checks, 0 failed**, thư mục full có 79 logs. Scan full không có SCRIPT ERROR/Parse Error. Đọc focused/full lifecycle (25 PASS), pause (15), settings (395), pause layout (47), host/client network và rematch: host fresh marker `latest_seq=3 resume_seq=1 fresh=true`; rematch host/client `FAILURES: 0`, reset checks có trong logs. Shutdown ObjectDB/resources noise vẫn còn; không nói log sạch.

Không chạy full suite lần hai. Unmodified headless rematch pair chỉ rerun vì window contradiction R1, cả hai exit 0; không thay assertions hoặc runtime data trong repo.

## Render / input evidence

Evidence root tạm: `/tmp/ltrgame-task2-review`, giữ harnesses/logs để audit. `render.gd` extends existing review harness, chỉ override run/shot và chạy bounded Task2 scenes, không chạy season/full suite. Real Solo free-play L01 và training dummy arena được mount từ scenes; auto physics tắt để stage ổn định theo existing enter_match. LAN host scene thật nhưng không có remote peer ở staged screenshots: result readiness dictionaries và confirmation/peer-disconnect fixture được stage rõ ràng, **không phải live gameplay/actual remote offer**.

Final mỗi size **10 screenshots, failures=0, exit 0**, không SCRIPT ERROR/Parse Error. Solo/training pause/settings, staged LAN wait/confirmation/result/rematch-offer/rematch-wait/disconnect đều render. Captures physical **1280×720 / 1920×1080**, X11 root capture crop theo window position/size, không dùng logical viewport image. Window khởi tạo `--resolution` từ CLI để tránh Task1 black-area pitfall. Contact sheets mở bằng read image cả hai size, mở riêng full-size disconnect 1080: panel/text/nút trong viewport, glyph Việt rõ, không crop/black margins; pause primary, settings tabs và result disabled rematch/menu primary hiển thị đúng. Staged result còn HUD/banner PLAYING phía sau vì không stage toàn outro; không dùng chúng để chứng minh completed live match/outro camera.

Repo images:
- `production/qa/evidence/task2-solo-{pause,settings}-{720,1080}.png`
- `task2-training-{pause,settings}-{720,1080}.png`
- `task2-staged-lan-{wait,confirm,result,rematch-wait,rematch-offer,disconnect}-{720,1080}.png`
- `task2-contact-{720,1080}.png` (10 frames mỗi sheet; contact sheets không phải physical window captures).

Dùng Xvfb riêng cho từng window, isolated XDG data/config/cache, không desktop focus/pointer capture. Godot 4.7.2 GL Compatibility/Mesa llvmpipe software render, dummy audio; không đo target GPU/FPS, không manual combat playtest hoặc external tester. Chưa kiểm large-text toggle rendered trong task này.

## Commands / exits / infrastructure errors

Runtime mọi command: `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`; root `/home/konits/projects/ltrgame/buffalo-fighting`.

```sh
# final render: size=720/1080, res=1280x720/1920x1080, args=''/'--large'
env XDG_DATA_HOME=<scratch>/xdg-$size/data XDG_CONFIG_HOME=<scratch>/xdg-$size/config \
 XDG_CACHE_HOME=<scratch>/xdg-$size/cache timeout 150 \
 xvfb-run -a -s '-screen 0 2200x1400x24' <Godot> --resolution "$res" --position 0,0 \
 --path <root> --rendering-method gl_compatibility --audio-driver Dummy \
 --script <scratch>/render.gd -- $args
# actual pair render attempt: same CLI shape, --script <scratch>/pair.gd,
# -- --window --host/--client [--large], host background, sleep 2, wait host,
# timeout 100; separate Xvfb display per process, shared isolated XDG per pair.
# classification rerun: timeout 75 <Godot> --headless --path <root>
# --script res://tests/lan_rematch_pair.gd -- --host/--client (sleep 2; wait host).
```

Logs `render-{720,1080}.log/.exit` final=0; `render-*-first.log` earlier successful seven-state subset retained, not separate acceptance. Initial temporary harness parse warning-as-error (`WeakRef` inferred Variant) corrected only in temp script; `render-*-initial-parse.log` retained, not counted as pass. Window attempts `pair-*-{host,client}.log/.exit` =124; hybrid logs retain host=1/client=124; headless logs/exits=0. Không lặp lại production defect để ép xanh; window failure vẫn open R1.

## Cleanup / bàn giao

Không sửa production/test/config, không commit, không dispatch helpers. Chỉ tạo authorized report và task2-* PNG; temporary harness/log files ở /tmp. `git diff --check` exit 0. Đã xóa toàn bộ owned XDG directories (render/pair/hybrid/headless), giữ logs/harness/capture scratch audit; `ps` không còn Godot/Xvfb/task2-review processes. Không đóng terminal/process của người dùng, không xóa shared `.godot`.

Main còn: quyết định accept/reject với R1, minimal reproduction cho window ENet/event-loop gap, actual pair rendered transitions nếu gate yêu cầu trước acceptance; Tasks3–4/performance/export/human playtest ngoài review này.
