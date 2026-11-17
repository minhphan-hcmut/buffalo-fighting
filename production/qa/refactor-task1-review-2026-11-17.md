# Review độc lập Task 1 — 17/11/2026

## Kết luận

**Không gọi intermittent đã resolved; chưa đề nghị nghiệm thu toàn Task 1 chỉ dựa vào test count.** Đã đọc AGENTS, spec/plan được duyệt, baseline compatibility, báo cáo Task 1, toàn diff HUD, toàn hai presenter và regression mới. Không thấy regression logic trực tiếp trong extraction; tìm được cơ chế timing không xác định trong test cũ bằng runtime probe, nhưng **quan hệ nhân quả riêng với extraction và lỗi resume của full run vẫn unresolved** sau giới hạn 10 paired attempts. Main sở hữu integration/fix và rendered acceptance.

## Review code (khác với giả thuyết root cause)

- State tutorial/training có đúng một owner ở presenter; các property get/set trên HUD không giữ bản sao, Array/Dictionary getter trả cùng mutable state. `controls_hint_time`, `tutorial_time`, dirty/released flags đều delegated.
- Root Control vẫn child 0. TrainingPanel vẫn trực tiếp dưới root, tên/layout/font/counter khởi tạo giữ nguyên; hai Node sibling thêm sau root không chèn vào cây Control dùng text-scale/mouse recursion. `_apply_text_scale` và banner/clash offset vẫn do façade quản lý.
- Subscription thứ tự training → tutorial → stats giữ nguyên. Không có write gameplay/controller trong hai presenter; event predicates/slot/drill và thứ tự xử lý `CLASH_START`, release/win, refill giống code gốc.
- `_exit_tree` mỗi presenter disconnect bound combat callback khi controller còn hợp lệ, xóa Callable/controller; tutorial xóa label. Training giải phóng panel nếu còn sống, xóa ba UI references. Không coroutine/tween/deferred mới. Regression thật free HUD khi controller còn sống, emit event rồi recreate, kiểm số subscriptions, weakrefs và counter mới.
- Dirty-write accounting vẫn qua `_label`/`_set_tutorial_text` façade, kể cả popup/counter. Direct initial counter assignment giống baseline. Tutorial `_alpha` bản chuyển tương đương helper cũ. Stable render không làm text/range writes mới.
- Throttle vẫn chỉ façade `_process`: Low PLAYING không pause tích lũy delta rồi chuyển cùng delta tới cả presenter; pause bypass throttle và không tăng controls/tutorial/popup clocks. Việc queue hoặc chọn hint hết giờ trong pause vẫn có thể xảy ra như baseline, không phải thay đổi ở extraction. Countdown reset controls và result/clash visibility không đổi.
- Regression mới 28 checks đi qua arena/controller signal/HUD `_process`, không chỉ test helper; chạy độc lập trong scratch exit 0, `HUD PRESENTERS: 28 checks, 0 failed`, không Parse Error/SCRIPT ERROR. Đây không thay full suite hoặc rendered inspection.
- Điểm giới hạn không nâng thành blocker chưa có repro: presenter không thiết kế để tháo rồi add lại cùng instance (exit xóa controller/Callable); HUD hiện luôn tạo presenter mới. Test chưa kiểm riêng remove presenter khỏi HUD rồi vẫn gọi HUD `_process`; không có caller hiện tại làm việc đó. Setup không phải API idempotent, giống `_build_training_panel` gốc không idempotent.

## Điều tra timing: đường chạy thực

`training_parry_rest_test.gd:29–34` add arena, await **5 process_frame** trong khi automatic controller physics/presentation còn bật, rồi mới `set_physics_process(false)`. Sau đó gọi `_physics_process(1/60)` trong coroutine **ngoài physics frame**, không await giữa các bước.

Controller `_physics_process` đọc pause/phase rồi `_read_player_input` → `simulate_tick`; input vẫn đọc singleton Input và CameraRig yaw, không phải injected neutral frame. `simulate_tick` gọi AI, facing/timers/state bằng delta thủ công, rồi `_simulate_actor` → `Buffalo.simulate_movement` → **CharacterBody3D.move_and_slide() không nhận delta thủ công**. AI horn drill chỉ nhấn horn khi head_gap <= approach_gap, hướng đúng, cooldown hết và stamina đủ; rest sau stun chỉ chặn input trong `drill_rest`. Drill nhánh này không dùng RNG dù match seed dựa wall clock.

`MatchController._notification` có auto-pause focus-out (setting mặc định true trong fixture này); fixture không tắt auto-pause hay inject input. Đó là nguồn uncontrolled có thể có về mặt code, **không phải nguyên nhân quan sát được ở paired failures**: cả ba failure đều paused=false, input=(0,0), player đứng yên. Không có bằng chứng input/focus gây ba failure này. Năm awaited frames cũng không tương đương năm physics ticks: log countdown sau setup khác nhau.

### Cơ chế đã đo được, không cần đoán

Scratch probe tối thiểu tạo CharacterBody3D, await 5 process frames, velocity=(1,0,0), gọi move_and_slide một lần ngoài physics frame:

```text
DELTA_PROBE inphys=false physics_dt=0.01666666666667
process_dt=0.00594966666667 displacement=(0.00595, 0.0, 0.0)
```

Vậy movement của đường test này dùng **process delta**, không phải DT=1/60 của timers/AI. Trong tight loop delta process giữ nguyên từ frame cuối đã await. Lượng đường di chuyển cho 600 lần gọi phụ thuộc thời gian frame trước đó; horn cần đi từ x=10 tới khoảng x=-6.7. Với dtproc thấp, hết 600 ticks vẫn chưa tới range, nên assertion trước stun fail dù AI đang tiến đúng.

Ví dụ paired current failure 03:

```text
before_stun: tick=600 paused=false state=NORMAL input=(0,0)
opponent.x=-3.570489 velocity.x=-8.75 gap=3.529511
dtphys=0.01666666666667 dtproc=0.00260991667614 inphys=false
```

Cùng failure đó sau rest attack xảy ra tại tick 821, gap=0.374917. Current 08/09 cũng chưa tới range ở tick 600 (gap 1.190325 / 2.265534), dtproc 0.003059792 / 0.002853. Original pass 01 cần tới **544 ticks**, dtproc=0.00355775, trong khi original 10 chỉ cần 201 ticks, dtproc=0.009845333; cùng code gốc không có timestep simulation ổn định. Quan sát displacement, velocity và ngưỡng range khớp cơ chế trên.

### Giả thuyết còn mở

- Bằng chứng mạnh: test manual tick trong process callback làm movement phụ thuộc wall-clock frame, khác clock AI/state, giải thích trực tiếp pre-stun failures quan sát được.
- Extraction có thể thay frame/setup cost khiến ngưỡng timing nhạy hơn; **không chứng minh production simulation đổi** và không được coi 0/10 original failure là proof baseline an toàn. Cần main quyết định cách kiểm deterministic qua physics-frame thật hoặc fixture cách ly movement clock, giữ nguyên assertions/phạm vi hành vi.
- Full worker failure có cả pre-stun và resume; ba scratch failures chỉ có pre-stun, resume đều pass. Chưa có instrumentation của lần full failure, nên nguyên nhân cụ thể resume không được xác nhận; có thể cùng thiếu quãng đường trong budget, nhưng hiện chỉ là giả thuyết.
- Không sửa test/controller/presenter để ép xanh, không tăng budget, không chạy lại paired attempts vượt giới hạn, không gọi lỗi đã sửa.

## So sánh paired có giới hạn và bằng chứng

Root evidence: **`/tmp/ltrgame-task1-review-1794882094`**. HEAD `21ae5af576fa128dff88aef76c7f0cd5eec3bc60`.

Tạo một copy ngoài repo (bao gồm import cache hiện có, không phải fresh-import). Mọi code/test/config/assets khác giữ giống nhau; chỉ thay `scripts/ui/hud.gd` giữa snapshot current và `git show HEAD:scripts/ui/hud.gd`. Hai presenter mới vẫn tồn tại ở cả hai variant, nhưng original HUD không dùng chúng. Không overwrite HUD trong working repo. Instrumentation chỉ thêm trace ở bốn checkpoint của **bản test scratch**, không thay vòng lặp/điều kiện/assertion; `instrumentation.diff` và `training_parry_rest_instrumented.gd` giữ nguyên để audit.

Mỗi lần fresh Godot process và fresh XDG_DATA/CONFIG/CACHE_HOME dưới evidence root; cùng executable `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`, `timeout 90`, `--headless --path <scratch>/project --script res://tests/training_parry_rest_test.gd`. Cùng project path để tránh khác path; thứ tự đảo current/original theo pair chẵn/lẻ. Có đúng **10 pairs, 20 runs**:

| Pair | Current exit | Original exit |
|---|---:|---:|
| 1 | 0 | 0 |
| 2 | 0 | 0 |
| 3 | **1** | 0 |
| 4 | 0 | 0 |
| 5 | 0 | 0 |
| 6 | 0 | 0 |
| 7 | 0 | 0 |
| 8 | **1** | 0 |
| 9 | **1** | 0 |
| 10 | 0 | 0 |

`results.json` lưu exit/path từng run; tất cả log (kể cả failures) dưới `logs/NN-variant.log`. Ngoài budget paired chỉ chạy một probe delta tối thiểu và một `hud_presenters_test` cho review lifecycle, không thêm rest-test retry/full suite. Retain cả `logs/prior-full-failure.log` và `logs/prior-isolated-pass.log` sao từ evidence worker, không làm mất lỗi trước. Main đã cung cấp ba isolated pass `/tmp/ltrgame-main-task1-check.ucb6ri`; không dùng chúng phủ nhận failure. Shutdown ObjectDB/resources warnings vẫn tồn tại ở log pass và probe, không tuyên bố log sạch.

## Checklist và cleanup

- [x] Review actual diff và đầy đủ presenter/test mới; đọc actual AI/controller/input/movement path.
- [x] 10 paired attempts hữu hạn, same-rest-of-project, giữ mọi failure và instrumentation.
- [x] Probe runtime xác nhận process-delta movement ngoài physics frame; tách observation và giả thuyết.
- [x] Không sửa source/test/config của repo; chỉ tạo báo cáo được cấp phép này, không commit/subworker/GUI.
- [x] Xóa scratch project và isolated XDG data/config/cache; giữ logs, original/current HUD snapshots, instrumentation/probe và SHA manifest. Probe/test process đều đã exit; `ps` không còn process Godot/task scratch thuộc lượt này. Không đụng process/terminal khác.
- [x] `git diff --check` exit 0.
- [ ] Chưa resolved attribution riêng HUD hoặc full-run resume failure; main phân loại/fix và nghiệm thu.
- [ ] Full suite mới và actual render/input 720p/1080p chưa chạy trong review này; không có build/playtest acceptance.
