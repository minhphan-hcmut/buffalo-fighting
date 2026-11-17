# Task2 window R1 — bounded followup, 17/11/2026

## Kết luận

**R1 chưa đóng; không có root cause/fix được chứng minh và không có ảnh actual pair mới.** Đã thu hẹp đáng kể: không phải generic Xvfb/ENet, không phải autoload startup hay không poll multiplayer trước lobby. Instrumented actual game pair **cả hai nhận lobby_ready, đổi scene arena thành công**, sau đó chạy cực chậm trên hai llvmpipe windows; process/physics vẫn tiến nhưng simulation timers không theo kịp wall time. Dòng log cuối `LAN connection starts` ở report trước **không đủ để đặt boundary tại await lobby_ready**: đó chỉ là print cuối trước first match assertion. Báo cáo này sửa cách diễn giải đó.

Không xác định slow path cụ thể là renderer CPU oversubscription, physics, hay một callback trong arena. Hai hypothesis fixes không thành công đã dừng theo yêu cầu: explicit FPS setting và Low preset. Không production/test/config changes; main sở hữu fix và acceptance.

## So sánh tối thiểu

Scratch `/tmp/ltrgame-task2-window-investigation`, runtime `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`. Dùng minimal probe main cung cấp `/tmp/ltrgame-window-enet-probe.gd`, chỉ đổi port 47939 → **47946** trong scratch; root 640×360, 8-second SceneTree timer, process callback in ticks. Hai windows riêng Xvfb, host trước client 1 s, isolated XDG per role.

| Run | Kết quả |
|---|---|
| Bare probe empty project `/tmp/ltrgame-main-window-probe.DjkETz/project` | Host/client exit 0, CONNECTED cả hai, timer DONE ticks 7009/6551 |
| Cùng probe actual game project + nguyên autoloads | Host/client exit 0, CONNECTED cả hai, timer DONE ticks 4949/5173 |
| Cùng game probe thêm duy nhất `Engine.max_fps=60` | Host/client exit 0, CONNECTED cả hai, DONE ticks 474/474 |
| Unmodified `res://tests/lan_rematch_pair.gd`, window runtime, **không --window** để không ghi ảnh ngoài quyền | Host/client timeout 20 s, exit 124; chỉ connection starts được in |
| Scratch copy original thêm process/physics/timer/scene milestones | Cả hai GOT LOBBY, BEFORE CHANGE, AFTER CHANGE, SCENE CHANGED; timeout 14–15 s, exit124 |

Game probe dùng cùng autoloads Screenshots/JoyRumble/GameAudio/NetworkManager, nên không có bằng chứng chúng block toàn loop ở startup. Instrumented pair `paused=false`, maxfps=60 trước arena. Không local pointer/focus/keyboard trên desktop.

## Hai hypothesis đã thử, không fix

### H1 — Engine.max_fps bị GraphicsQuality.apply_live reset khi arena mount

Đọc đầy đủ `scripts/core/graphics_quality.gd`: `apply_live()` gọi `apply_fps_limit()`, default limit index0 chọn VSync và Engine.max_fps=0; scripted mode dùng High preset. `scripts/core/arena_builder.gd:54–55` apply_sun/apply_live khi build. Pair gốc chỉ đặt Engine.max_fps=60, không đặt GraphicsQuality limit; đây là khác biệt thực so với earlier successful staged render harness.

Scratch instrumented pair thêm `GraphicsQuality.set_fps_limit(GraphicsQuality.FPS_LIMITS.find(60))` trước connect (giữ assertions/actions nguyên). **Không fix:** host/client outer timeout65 exit124. Process/physics và timer 3s chạy sau scene mount, maxfps60; host process120/physics444 trước hết wall budget. Không tuyên bố VSync root cause.

### H2 — scripted High preset quá nặng cho hai software windows

Trên H1 scratch thêm `GraphicsQuality.set_preset(GraphicsQuality.LOW)` (presentation-only, không production data), log wall milliseconds ở process milestones. **Không fix:** host/client outer timeout85 exit124, không tới first result assertions. Nhưng định lượng được loop vẫn sống:

```text
host process60 wall_ms=2405 physics65
host process120 wall_ms=23401 physics160
host process180 wall_ms=40715 physics605
host process240 wall_ms=53126 physics1051
host process300 wall_ms=70608 physics1517
client process60 wall_ms=36238 physics431
client process120 wall_ms=48918 physics880
client process180 wall_ms=66812 physics1342
client process240 wall_ms=81574 physics1775
```

Process delta thường 0.08–0.13s trong khi wall elapsed giữa process milestones lên tới 12–21s. Physics counts/simulation timers tiến chậm hơn wall; 55-second SceneTree timeout không in trước outer timeout không chứng minh frozen thread. Không kéo timeouts vô hạn, không thử hypothesis3. LOW thử nghiệm không phải retained target graphics acceptance.

## Đọc code / boundary

Đã đọc project.godot (bốn autoloads), toàn GameAudio và screenshot_service, graphics_quality; NetworkManager callback setup đã đọc từ review trước. GameAudio ready khởi tạo audio voices và music, UI button hook; screenshot_service xây control toast, scene_changed callback, process tick, không capture chủ động ở probe/pair. GraphicsQuality là static class, không autoload; arena build mới apply live settings.

Original headless pair trong prior review (không rerun full/headless lần nữa task này) pass cả hai với same assertions, xác định rendering/window-vs-headless boundary còn open. Không có bằng chứng Task2 presenters làm thay đổi ENet/tick/payload, và không sửa gameplay để đẩy test qua.

**Repro nhỏ nhất hiện có cho boundary:** actual project + original lan_rematch_pair window; thêm process/physics logging và scene milestones trong scratch chứng minh scene mount xong rồi slow. Bare actual-project probe không mount arena thì pass, có/không cap60 đều pass. Bước hợp lý cho main là profile actual arena frame/physics và native thread stack/CPU, hoặc minimal single-arena rendering pair, không tiếp tục quy cho lobby/ENet hoặc blindly rewrite autoloads.

## Commands / evidence

Invocation shape mỗi role, host background rồi sleep1 (probe)/sleep2(pair), wait cả hai; mỗi role display riêng:

```sh
env XDG_DATA_HOME=<scratch>/<case>/data XDG_CONFIG_HOME=<scratch>/<case>/config \
 XDG_CACHE_HOME=<scratch>/<case>/cache timeout <14|15|20|65|85> \
 xvfb-run -a [-s '-screen 0 2200x1400x24'] <Godot> \
 [--resolution 1280x720] --path <empty-project|game-root> \
 --rendering-method gl_compatibility --audio-driver Dummy \
 --script <probe.gd|probe-cap.gd|instrumented.gd|fps-explicit.gd|low.gd|res://tests/lan_rematch_pair.gd> \
 -- --host|--client
```

Scratch logs:
- `logs/probe-{empty,game}-{host,client}.log/.exit`: all0.
- `logs/cap-{host,client}.log/.exit`: all0.
- `logs/original-{host,client}.log/.exit`: all124.
- `logs/instrumented-{host,client}.log/.exit`: all124; second milestone run `instrumented2-*.log` retained (both outer timeout14).
- `logs/explicit-{host,client}.log/.exit`: all124.
- `logs/low-{host,client}.log/.exit`: all124, wall/physics samples above.

No Parse Error/SCRIPT ERROR found in these investigation runs. VSync unsupported warning on Xvfb retained. No full suite rerun, no new screenshots claimed. Scratch code created only outside repo; report is only repo write.

## Cleanup

All owned Godot/Xvfb/timeout processes finished/timeout reaped, `ps` showed no matching live processes. Deleted owned isolated XDG case directories; retained probe/harness/logs audit files only. No desktop input, no worker/terminal creation, no commit/source/test/config edit, no change to prior report/images or shared .godot. `git diff --check` exit0. Main still needs actual pair rendered 720/1080 acceptance or explicit decision to defer it.
