# Task 1 — tách tutorial/training HUD, 17/11/2026

## Trạng thái

Đã triển khai extraction trong đúng phạm vi, không commit. **Chưa qua cổng full suite:** lần chạy đầy đủ exit **1**, **78 checks, 1 failed** (`training_parry_rest_test`); chạy riêng test đó sau đó exit **0**. Không coi lần chạy riêng xanh là thay thế full suite đỏ; main cần phân loại lỗi không ổn định này trước khi chấp nhận integration.

Không sửa controller, combat, balance, pause/settings/LAN/menu hay test cũ. Hai file `tests/network_{host,client}_harness.gd` đã modified từ Task 0 được giữ nguyên.

## API, ownership và diff

- `scripts/ui/hud_tutorial.gd` mới, `extends Node`: `setup(controller, RichTextLabel, text_update: Callable)`, `enabled()`, `queue_hint(id)`, `on_combat_event(...)`, `update(delta) -> bool`. Sở hữu hoàn toàn `tutorial_seen/queue/current/time/front_hit`, `controls_hint_time`, nội dung `CONTROLS/TUTORIAL`; trả hint visibility cho façade. Callback cập nhật rich text đi qua HUD `_set_tutorial_text`, giữ cache và `label_writes` tại HUD.
- `scripts/ui/hud_training.gd` mới, `extends Node`: `setup(controller, root: Control, label_update: Callable)`, `count(key)`, `success(text)`, `on_combat_event(...)`, `update(delta)`. Sở hữu panel, counter, popup, dictionary counts, popup time, released flag và dirty flag. Panel vẫn là child trực tiếp của root Control để không đổi text-scale/layout/tree identity; presenter giải phóng panel khi rời cây độc lập nếu còn hợp lệ.
- `scripts/ui/hud.gd`: chỉ giữ properties delegated get/set cho mọi tutorial/training field của compatibility contract; wrappers giữ `_build_training_panel`, `_training_count/success/event`, `_tutorial_enabled/event`, `_queue_tutorial`, `_update_tutorial`. Không có bản sao state ở façade. Root Control vẫn `get_child(0)`; thêm hai sibling Node `TrainingPresenter`, `TutorialPresenter` sau root. Training connect trước tutorial, tutorial trước stats như baseline. HUD giữ resource/timer/clash/banner/pause/results/layout, throttle và accumulated delta, dirty-write helpers/counters.
- Presenter controller cố ý không typed để tránh chu trình type HUD -> presenter -> MatchController -> HUD. Cả hai ngắt signal và xóa Callable/controller reference tại `_exit_tree`; không tạo coroutine, deferred callback hay tween mới.
- `tests/hud_presenters_test.gd` mới: 28 checks qua scene arena thật, combat_event thật và HUD `_process`; pause/resume qua controller. Kiểm ordered queue/front-hit, hint 6 sau hint 4, mutable façade state, đúng slot/drill, dirty writes chính xác, popup pause, accumulated delta Thấp, stable render không ghi thừa, free HUD trong khi controller còn sống rồi emit event/recreate, weak reference presenter đã giải phóng, scene free/recreate counters mới.
- Ba `.gd.uid` mới do Godot import sinh. `git diff --check` exit **0**.

## TDD RED → GREEN

Tên break: thiếu scene-owned presenter sẽ không thể tách state/signal lifecycle khỏi HUD và kiểm owner đã free khi thay view trong lúc controller còn sống; event regression bổ sung bắt sai queue/slot/drill/pause/delta/dirty writes và subscription trùng.

1. Tạo test trước production change, chạy `hud_presenters_test`: **exit 1**, 3 assertion failures đúng mục tiêu: thiếu tutorial owner, thiếu training owner, thiếu hai owner được giải phóng. Các behavior assertions khác chạy qua baseline và pass. Log `logs/red.log`.
2. Extract production code. Lần thử đầu exit 0 nhưng scan thấy **SCRIPT ERROR** tại test gán untyped Array vào property `Array[int]`; không tính là GREEN. Sửa test dùng biến `Array[int]` trước khi gán, giữ nguyên assertion/coverage, không đổi production contract. Log lưu `logs/green.log` để không che lần lỗi này.
3. Chạy lại new test cùng bốn test yêu cầu: cả năm exit **0**, không Parse Error/SCRIPT ERROR; test mới **28 checks, 0 failed**. Đây mới là GREEN của regression mới, không phải full-suite GREEN.

## Lệnh và kết quả chính xác

Working directory `/home/konits/projects/ltrgame/buffalo-fighting`. Runtime `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`.

Dùng cùng prefix cho mọi Godot process, không đọc/ghi settings người chơi thật:

```bash
env XDG_DATA_HOME=/tmp/ltrgame-task1-worker/data \
    XDG_CONFIG_HOME=/tmp/ltrgame-task1-worker/config \
    XDG_CACHE_HOME=/tmp/ltrgame-task1-worker/cache
```

RED chạy prefix trên + `timeout 90 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/hud_presenters_test.gd`, redirect `logs/red.log`: exit **1**.

Named runs (mỗi command dùng prefix trên):

```bash
timeout 180 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path . --script res://tests/<name>_test.gd
```

| name | exit | kết quả |
|---|---:|---|
| hud_presenters | 0 | 28 checks, 0 failed |
| combat_readability_tutorial | 0 | 0 failures |
| training | 0 | 177 checks, 0 failed |
| hud_efficiency | 0 | 0 failures; golden snapshots không đổi |
| rumble_hud_screenshot | 0 | 104 checks, 0 failed |

Full runner thực thi một lần:

```bash
env XDG_DATA_HOME=/tmp/ltrgame-task1-worker/data \
    XDG_CONFIG_HOME=/tmp/ltrgame-task1-worker/config \
    XDG_CACHE_HOME=/tmp/ltrgame-task1-worker/cache \
    GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
    TEST_LOG_DIR=/tmp/ltrgame-task1-worker/logs/full TEST_TIMEOUT=180 \
    timeout 1800 bash tools/run_tests.sh \
    > /tmp/ltrgame-task1-worker/logs/full-runner.log 2>&1
```

**Exit 1, 78 checks, 1 failed.** Import, tất cả test còn lại, cả năm LAN pairs và new test đều PASS. Scan `logs/full` không có Parse Error/SCRIPT ERROR.

### Lỗi cần main phân loại

`logs/full/training_parry_rest_test.log` có hai assertion failures:

- `horn drill attacks before the stun` (`tests/training_parry_rest_test.gd:46`)
- `horn drill resumes attacking after the rest` (`:65`)

Test thực sự chạy controller `_physics_process(1/60)` và chờ trạng thái `HORN_STARTUP` trong 600 bước, rồi chờ attack trở lại trong 360 bước. Test này không đọc HUD counters; chưa chứng minh nguyên nhân là extraction hoặc baseline/timing/input/focus. Không sửa test, AI hay controller ngoài phạm vi.

Concrete reproduction command: prefix XDG trên + `timeout 180 /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/training_parry_rest_test.gd`. Chạy đúng một lần riêng sau full failure: **exit 0**, cả 8 checks pass, log `logs/training_parry_rest-repro.log`. Không lặp suite/test để tạo kết luận xanh, không bỏ/giảm assertion. Full failure còn nguyên bằng chứng.

## Giới hạn và cleanup

- Chỉ headless; không mở GUI, chụp ảnh hay tuyên bố render/playtest acceptance 720p/1080p. Main sở hữu rendered inspection và independent review.
- Shutdown diagnostics ObjectDB/resources vẫn có ở nhiều test PASS, bao gồm new test (38 instances / 9 resources ở lần named run); không tuyên bố log sạch hoặc giải quyết leak toàn game. Weakrefs kiểm trực tiếp hai presenter sau HUD free đều null; điều đó không chứng minh mọi resource khác đã nhả.
- Toàn bộ lệnh đều bounded `timeout`; không worker/server/terminal con hoặc process nền ngoài runner tạo. Runner đã kết thúc/wait host; kiểm `ps -eo pid,ppid,comm,args` với `Godot_v4.7.2`, `run_tests.sh`, `timeout 90/180/1800` không còn process phù hợp.
- Xóa isolated data/config/cache sau test; chỉ giữ `/tmp/ltrgame-task1-worker/logs` cho main đọc. Không xóa `.godot` dùng chung hoặc dữ liệu/terminal người dùng. Không commit.

## Checklist bàn giao

- [x] Đọc instructions, architecture, spec/plan/baseline, full HUD và named tests trước code.
- [x] RED rõ ràng trước extraction; GREEN regression mới với 28 checks.
- [x] Hai scene-owned presenter, state sở hữu một nơi, façade compatibility và dirty counters.
- [x] Named tutorial/training/efficiency/rumble tests giữ nguyên đều exit 0.
- [x] Full runner thực thi có timeout, ghi rõ failure, một lần repro riêng không che suite đỏ.
- [x] Cleanup process/data cô lập và giữ logs.
- [ ] Main phân loại lỗi training_parry_rest không ổn định, quyết định integration.
- [ ] Main independent review và actual rendered inspection; Tasks 2–4 chưa làm.
