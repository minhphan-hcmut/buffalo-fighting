# Task 3 — review độc lập và render/input (17/11/2026)

## Kết luận

Không tìm thấy regression mức blocker/high/medium trong phạm vi extraction Task 3 qua đọc code đầy đủ, audit log và các đường render/input dưới đây. Main vẫn sở hữu quyết định integration/nghiệm thu; đây **không phải** nghiệm thu toàn game, full combat playtest, export hay đo performance. **R1 actual dual-window LAN vẫn chặn release**, không được điều tra hoặc coi đã sửa trong review này.

Đã đọc AGENTS/CLAUDE, ARCHITECTURE, approved spec/plan, baseline và báo cáo implementation; đọc **toàn bộ** actual `main_menu.gd` (416), `solo_mode_view.gd` (189), `solo_result_view.gd` (285), `solo_flow.gd` (136), `solo_flow_test.gd` (173) và original main_menu 678 dòng từ `git show HEAD:scripts/ui/main_menu.gd`.

## Findings theo severity

- **Low / API footgun, không chặn extraction:** `scripts/ui/solo_flow.gd:79–100`: `result_data()` không phải read-only getter; gọi nó sẽ chọn/reserve thẻ qua `select_card()`, append `SessionState.culture_cards_seen`. Bản thân hai API này không idempotent theo result key. Actual production path được guard ở `solo_result_view.gd:78–94` bởi `displayed_result`, nên mỗi render result reserve một thẻ; façade `_show_culture_card()` vẫn là lệnh chọn thẻ mới như original, không phải đọc lại thẻ hiện tại. Không thấy caller production đọc `result_data()` để polling, không phát hiện double-reservation qua actual path; nên ghi rõ command side effect nếu mở rộng API, không tự sửa behavior trong refactor.
- **Thông tin / nợ baseline:** full logs có ObjectDB/resource shutdown diagnostics, không được gọi là leak-free. Không có `SCRIPT ERROR` hoặc `ERROR:` ngoài resource-in-use shutdown trong 80 logs được audit. Lifecycle assertions chứng minh node/tween cụ thể, không chứng minh toàn bộ Godot app không rò.
- **Giới hạn harness:** hai season render run exit 0 nhưng thiếu marker hoàn tất cả harness sau final result; không dùng exit 0 này làm bằng chứng cho free-play/training tail. Đã chạy harness hẹp riêng có explicit completion marker ở cả hai kích thước và bổ sung bằng chứng tương ứng. Lần season đầu timeout 124 sau L03, không đổi test/budget production để làm xanh.

## Ownership, semantics và lifecycle

- SessionState vẫn là nguồn mode/progress duy nhất; SoloFlow không giữ bản sao season/level/result lâu dài. Dictionary từ `result_data()` chỉ dùng ngay trong render. Stats block lấy đúng collector `arena.hud.stats` duy nhất.
- Mode view sở hữu page thật; close remove/queue-free page, focus row mới; callback selection bound vào SoloFlow. Exit không mutate parent trong teardown.
- Result view sở hữu nodes/tweens, `scene_changed` dùng node-bound `reset_result`; `_exit_tree` kill result/card tweens. `card_visible` là notification, flow gọi CultureCards; view không save SessionState/notebook trực tiếp.
- Reservation lúc dựng result vẫn như original, kể cả final card đang bị closing che; notebook chỉ award khi panel/card visible-in-tree. Meta `awarded` đặt trước signal (`solo_result_view.gd:209–219`) chặn duplicate notification khi deferred visibility callback gặp alpha còn 0. CultureCards cũng giữ notebook idempotent. Không đánh đồng reservation với notebook award.
- Retry gọi SessionState.retry, nạp scene mới; next lấy rites trước và chỉ begin_solo sau rite để giữ result key cũ. Season năm vòng, loss retry, next-rite/free, final retry/menu-only có assertions qua controller/scene thật trong new test đã audit. Closing continuation node-bound; clear_rite hide/queue-free trước reveal, CeremonyView.finish có done guard.
- Free play không tăng mùa/closing; change-match đặt return flag rồi SessionState.return_to_menu; actual mouse path trở lại L01 focus. Training không result/card, actual dummy arena và change-drill trở về dummy focus; unlimited toggle đi qua real control tới SessionState.
- Static `_arena_scene`, `_prefetch_arena`, `_finish_prefetch`, `_go_to_arena` vẫn trên façade, callback static thu request sau menu free; root `SoloSessionOverlay` name/meta/identity giữ qua năm arena. Audited prefetch và lifecycle logs, không rerun full vô ích.

## Audit test evidence (không duplicate full suite)

`/tmp/ltrgame-task3.TTcRs4/full.exit` = `0`; `full-runner.log` kết thúc **80 checks, 0 failed**; `full/` có đúng **80 log files**. Scan Python mọi dòng trong mọi log: không SCRIPT ERROR, không ERROR ngoài `resources still in use at exit`. `solo_flow_test.log` có actual assertions hidden/reveal/double award, tween/free/scene callback, five arena identity, loss retry, rites/order, final menu-only và free trong next rite. Existing seven tests `five_levels/free_play/training/culture_cards/festival_notebook/arena_prefetch/ui_hierarchy` diff với HEAD rỗng; không sửa hoặc giảm assertion nào. `git diff --check` exit 0 khi kiểm cuối.

## Render và input thật, cô lập desktop

Đã đọc existing `tests/review_window_harness.gd` đầy đủ và `/tmp/ltrgame-task2-review/render.gd` trước reuse. Scratch scripts mới bên ngoài repo:

- `/tmp/task3-review-render.gd`: extends existing harness, kế thừa root.push_input mouse/key helpers, actual menu/season/rite controls; staged TIME bằng controller end-rule, fresh Space skip outro; physical screenshots.
- `/tmp/task3-review-free.gd`: bounded bổ sung free-play L05/result/change-match và training dummy/change-drill; có explicit `TASK3 FREE WINDOW failures=0` trước quit.

Invocation thực tế (cho mỗi kích thước, chạy Xvfb riêng và wait/kill đúng PID sở hữu):

```bash
Xvfb :93 -screen 0 1280x720x24 -nolisten tcp
Xvfb :94 -screen 0 1920x1080x24 -nolisten tcp
# cwd /home/konits/projects/ltrgame/buffalo-fighting
DISPLAY=:93 XDG_DATA_HOME=/tmp/ltrgame-task3-review/720/data \
 XDG_CONFIG_HOME=/tmp/ltrgame-task3-review/720/config \
 XDG_CACHE_HOME=/tmp/ltrgame-task3-review/720/cache LP_NUM_THREADS=2 \
 timeout 720 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
 --path . --resolution 1280x720 --position 0,0 --script /tmp/task3-review-render.gd
# 1080: DISPLAY=:94, XDG prefix /1080, --resolution 1920x1080, trailing -- --large
# narrow supplemental: same environment, timeout 240, --script /tmp/task3-review-free.gd
```

Logs/exits retained `/tmp/ltrgame-task3-review/logs/`:

| Run | Exit | Bằng chứng dùng |
|---|---:|---|
| render720 initial | 124 | Không tính hoàn tất; partial tới L03 |
| render720-final | 0 | Actual menu/chooser/free/training pages, opening/water/giap/drums, staged five results + closing hidden/reveal/once; không tính tail |
| render1080-final | 0 | Như trên, physical 1920×1080; không tính tail |
| free720 initial | 0 | Không có completion marker, không dùng làm pass |
| free720-final | 0 | `TASK3 FREE WINDOW failures=0`; actual mouse change-match + focus, training mount + change-drill/focus |
| free1080-final | 0 | `TASK3 FREE WINDOW failures=0`; cùng actual paths |

Initial narrow run click ngay scene_changed trước layout ổn định không có completion marker; scratch harness được thêm wait_view trước click đầu, không chỉnh app/test production. Existing root.push_input đi qua GUI event routing, không chỉ emit pressed; không dùng desktop pointer/keyboard. Xvfb root capture qua `/usr/bin/import -window root` chỉ thuộc display riêng :93/:94, crop theo actual window position/size. Assert physical window = 1280×720/1920×1080; PIL kiểm lại 34 raw PNG đúng kích thước. Godot logical viewport vẫn 1280×720 với project stretch ở 1080p: không nhầm logical viewport image là screenshot 1080p.

## Ảnh đã đọc/kiểm

`production/qa/evidence/task3-contact-720.png` và `task3-contact-1080.png`: đã mở bằng image read, mỗi sheet bao 17 raw frames. Đọc thêm raw `task3-staged-season-l05-720.png`, `task3-staged-season-l03-720.png`, `task3-training-1080.png` để kiểm chữ/culture/actions ở độ phân giải thực. Không thấy clipping/overlap cản thao tác ở các trang và result được chụp; nút primary/focus và năm culture cards đọc được. Rites sau L01 còn left shade của overlay nên caption phía trái tối hơn opening/water; hành vi này đã tồn tại ở original overlay, không phát hiện regression extraction.

Raw image tên `task3-{menu,chooser,freeplay,training,rite-opening,rite-water,rite-giap,rite-drums,staged-rite-closing,staged-season-l01..l05,staged-freeplay-result,change-mode-return,training-arena}-{720,1080}.png`. **Mọi win/result là STAGED**, stats zero là expected, không phải đã đánh thắng combat qua input hay playtest AI/balance. Training arena chỉ mount/start/pause/exit, không phải hoàn thành drill bằng combat.

## Cleanup và còn lại

Không chỉnh gameplay/tests/config, không commit, không nested worker/server/browser. Godot và Xvfb mỗi run bounded, đã wait kết thúc và kill đúng Xvfb PID sở hữu; kiểm `ps` cuối không còn process của task. Xóa isolated data/config/cache của review, giữ scratch scripts và logs cho main reproduce; không xóa cache .godot dùng chung hoặc dữ liệu người chơi. Chỉ thêm report này và task3 PNG evidence trong repo.

Main còn integration/acceptance cuối, actual combat/replay/settings cross-check nếu checklist release yêu cầu; export/templates/performance/external playtest không được chứng minh ở đây. R1 actual dual-window LAN vẫn là release blocker riêng, không suy ra pass từ headless hay staged views.
