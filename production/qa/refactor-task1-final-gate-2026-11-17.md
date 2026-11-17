# Task 1 — independent final gate, 17/11/2026

## Kết quả và phạm vi

**Full suite chạy đúng một lần: exit 0, 78 checks, 0 failed.** Review actual diff test repair xác nhận không đổi DT, assertions hay tick budgets; physics-frame runtime probe xác nhận cơ chế sửa đúng clock đã điều tra. Render thực Solo tutorial và cả năm training drills ở cửa sổ **1280×720 và 1920×1080**, có 22 screenshots và hai contact sheets đã mở bằng read image để tự kiểm. Main vẫn là người quyết định nghiệm thu/integration; không coi kết quả này chứng minh mọi intermittent/focus/input hoặc toàn rubric đã resolved.

## Review actual repair

`tests/training_parry_rest_test.gd` bỏ năm `await process_frame` trước khi tắt automatic arena physics. Sau `add_child`/assign current_scene, tắt physics ngay trong cùng synchronous continuation; không có frame await xen vào. Mỗi manual `_physics_process(DT)` trong countdown, tìm attack, stun, early-rest và resume đều có `await physics_frame` ngay trước đó. Tất cả tám checks, DT=1/60, 600-tick pre-stun và 360-tick resume budgets, rest threshold giữ nguyên. Không có production simulation change trong repair.

Probe tối thiểu ngoài repo chạy đúng await physics_frame rồi velocity=(1,0,0), move_and_slide():

```text
PHYSICS_PROBE inphys=true physics_dt=0.01666666666667
process_dt=0.0 displacement=(0.016667, 0.0, 0.0)
```

Exit 0; đây là bằng chứng runtime rằng continuation chạy trong physics frame và movement dùng physics timestep, thay vì dựa vào ba lần pass main đã cung cấp. Đối chiếu probe trước ở report review: ngoài physics frame displacement chỉ 0.00595 khi physics_dt=1/60 và process_dt=0.005949667. Vì vậy repair nhắm đúng cơ chế clock mismatch, không kéo budget hay giảm assertion. Test vẫn đọc singleton input và không tắt auto-pause; đây là giới hạn độc lập về fixture isolation chưa chứng minh gây failure, không được diễn đạt rằng tất cả nguồn nondeterminism biến mất.

## Full isolated suite — một lần, không retry

Evidence root: **`/tmp/ltrgame-task1-final-gate.5map1a7h`**. Working root `/home/konits/projects/ltrgame/buffalo-fighting`.

```sh
env XDG_DATA_HOME=<evidence>/xdg/data \
    XDG_CONFIG_HOME=<evidence>/xdg/config \
    XDG_CACHE_HOME=<evidence>/xdg/cache \
    GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
    TEST_LOG_DIR=<evidence>/logs/full TEST_TIMEOUT=180 \
    timeout 1800 bash tools/run_tests.sh
```

`logs/full-runner.exit` = 0, `logs/full-runner.log` = **78 checks, 0 failed**. `logs/full/training_parry_rest_test.log` ghi đủ horn/dash attack-before, no-early, resumes và profile checks, `TRAINING PARRY REST: 0 failures`. New presenter regression cũng chạy trong suite. Scan toàn logs/full không có Parse Error/SCRIPT ERROR. Shutdown ObjectDB/resources diagnostics vẫn là nợ baseline, không tuyên bố log sạch. Không chạy full lần hai.

## Render thực: harness, isolation và input

Đã đọc toàn `tests/review_window_harness.gd`, nhất là `shot` write path `review-*`, `run`, `training`, key/click helpers trước khi chạy. Để không ghi đè evidence ngoài quyền hoặc chạy thừa toàn season/LAN, tạo **harness bên ngoài repo** `<evidence>/render_gate.gd` extends harness đó, override run/shot, tái dùng `enter_match`, **toàn training() hiện có** và input helpers. Không sửa test/game/config trong repo.

Run tạo Solo L01 arena thật, chụp movement hint; phát combat_event và stage guard queue để chụp hint 4 (staging view, không tuyên bố người chơi đã bị AI húc), pause/resume qua controller, kiểm tutorial clock không tiến khi pause. Sau đó dùng menu training thật, chọn từng drill dummy/dash/horn/release/hook, chụp panel, gửi Esc qua `Viewport.push_input` (không OS keyboard), mở settings/đồ họa và Esc trở về pause, đổi bài/về menu qua button signals của harness. Mỗi run: **11 screenshots, 0 failures**. AI physics bị tắt theo `enter_match` gốc để stage ảnh ổn định; đây là rendered view/transition inspection, không phải manual combat playtest.

Mọi cửa sổ chạy trên **Xvfb display riêng `xvfb-run -a`**, không lấy focus/pointer/keyboard của desktop người dùng. Không GUI automation hay browser cần thiết. Runtime Godot 4.7.2 GL Compatibility, **Mesa llvmpipe LLVM 22.1.8 software render**, dummy audio; không đo FPS target/GPU acceptance.

Final invocation shape:

```sh
env XDG_DATA_HOME=<evidence>/render-<size>-xdg/data \
    XDG_CONFIG_HOME=<evidence>/render-<size>-xdg/config \
    XDG_CACHE_HOME=<evidence>/render-<size>-xdg/cache \
 timeout 300 xvfb-run -a -s '-screen 0 2200x1400x24' \
 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
 [--resolution 1920x1080 --position 0,0] \
 --path /home/konits/projects/ltrgame/buffalo-fighting \
 --rendering-method gl_compatibility --audio-driver Dummy \
 --script <evidence>/render_gate.gd [-- --large]
```

Các flags trong [] chỉ cho 1080 final. Render logs cuối `logs/render-720.log` và `logs/render-1080.log` không có SCRIPT ERROR/Parse Error; mỗi run exit 0, 11 screenshots. Physical window capture dùng `/usr/bin/import -window root` trong **display Xvfb riêng**, crop bằng window position/size. Screenshot cuối physical sizes đúng 1280×720/1920×1080; viewport logical 1280×720 là project canvas_items stretch, không phải physical resolution sai.

### Capture harness failures được giữ, không đếm làm acceptance

1. `root.get_texture().get_image()` của harness gốc cho 1280×720 ngay cả physical window 1080; tên file 1080 không đủ bằng chứng. Initial logs giữ `render-*-viewport-initial.log`.
2. Thử DisplayServer.screen_get_image default screen báo index -1, rồi explicit screen 0 trả null trên Xvfb build này. Logs giữ `render-*-screen-index-error.log`/`*-screen-null-error.log`; exit 0 giả của async harness **không được tính pass** vì scan thấy SCRIPT ERROR và 0 captures.
3. X11 capture đúng size nhưng set window size sau mount chưa làm surface đầu render 1080 đúng trong Xvfb không WM; ảnh có black area, đã tự xem contact sheet và bác bỏ. Log giữ `render-1080-resize-mismatch.log`. Final 1080 khởi tạo bằng CLI `--resolution 1920x1080 --position 0,0`, physical capture đầy đủ không black area; không đổi gameplay/config.

Không phải suite/test retries để làm xanh; đây là capture infrastructure correction có log giữ nguyên. Screenshot acceptance cuối overwrite các ảnh thử cùng authorized task1 paths, logs lỗi không xóa.

## Ảnh đã tự kiểm bằng read image

Trong `production/qa/evidence/`:

- `task1-solo-tutorial-{movement,guard,pause}-{720,1080}.png`
- `task1-training-{720,1080}.png` (chooser)
- `task1-training-{dummy,dash,horn,release,hook}-{720,1080}.png`
- `task1-pause-{720,1080}.png`, `task1-pause-graphics-{720,1080}.png`
- `task1-contact-{720,1080}.png`: tổng hợp đủ 11 frames mỗi size, mở cả hai bằng read image sau final capture. Cũng mở ảnh horn 1080 full-resolution để kiểm không còn black area và text.

Quan sát: tutorial movement/guard nằm gọn ở strip đáy, chữ tiếng Việt hiển thị; thanh tài nguyên/timer phía trên không đè panel. Training title/counter ở top center, năm tên/counter đúng drill, không crop hoặc overlap banner; controls strip đáy nằm trong khung. Pause/settings panel nằm trong viewport, primary/focus action nổi rõ; guard hint tiếp tục nằm dưới pause shade. 1080 scale đầy đủ tương ứng, không còn black margins/capture crop. Không quan sát popup success hoặc clash active trong ảnh gate này: lifecycle/event/popup/dirty behavior có regression headless nhưng **không tuyên bố đã kiểm popup/clash rendered** từ bộ ảnh này. Không input chuột/camera live hoặc người ngoài nhóm playtest.

## Cleanup và bàn giao

- Đã xóa isolated `xdg`, `probe-xdg`, `render-720-xdg`, `render-1080-xdg`; giữ logs, probe/harness ngoài repo và screen scratch để audit.
- Tất cả Godot/Xvfb/runner do task tạo đã kết thúc; `ps` không còn matching live processes, không đóng terminal/process khác. Không tạo scratch project copy lần này, không xóa shared `.godot` cache.
- `git diff --check` exit 0. Chỉ tạo authorized task1 images và báo cáo này; không sửa gameplay/test/config, không commit/subworker.
- Main còn quyết định nhận Task 1 và cập nhật plan/handoff. Full rendered rubric, popup/clash visual regression nếu cần, Tasks 2–4, export/target performance/human playtest nằm ngoài kết luận gate này.
