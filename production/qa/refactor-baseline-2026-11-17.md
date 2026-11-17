# Baseline trước refactor — 17/11/2026

## Phạm vi và kết luận

- Worker chỉ điều tra baseline; không sửa gameplay, test, config, GDD hay file người dùng; không commit, không tạo worker khác.
- Đã đọc `AGENTS.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, spec `docs/superpowers/specs/2026-11-17-rubric-refactor-design.md`, runner và hai UI script đầy đủ.
- Git/game root: `/home/konits/projects/ltrgame/buffalo-fighting`; thư mục Orca cha không phải git root.
- HEAD: `21ae5af576fa128dff88aef76c7f0cd5eec3bc60`.
- **Baseline không xanh:** runner exit **1**, **77 checks: 76 PASS, 1 FAIL**; lỗi `network_pair_host` (exit 1). Import, mọi `*_test.gd`, các cặp LAN còn lại đều PASS theo exit code.
- Không chạy cửa sổ game, không chụp hình, không playtest, không đo FPS, không build/export. Sự tồn tại display/GPU không chứng minh UI/game chạy đạt rubric.

## Checklist bằng chứng

- [x] Đọc yêu cầu/repo/runner trước khi chạy.
- [x] Tìm runtime/version/templates/display, không cài đặt.
- [x] Chạy full runner với dữ liệu người dùng cô lập, giữ log và exit code.
- [x] Ghi lỗi, không sửa/rerun để làm xanh.
- [x] Inventory integration tests và seam/dependency tương thích.
- [x] Đọc v0.8 untracked, đối chiếu vai trò v0.7, bảo toàn cả hai.
- [x] Kiểm git status/diff và process sống sau test; chỉ tạo báo cáo này trong repo.

## Môi trường và runtime

Thời điểm kiểm tra cuối: `2026-11-17T00:46:16+07:00` (local).

| Mục | Kết quả quan sát |
|---|---|
| OS/kernel | Linux fedodo x86_64, `7.3.3-200.fc44.x86_64`, Fedora fc44 |
| PATH | `command -v godot`, `godot4`, `godot-mono`, `Godot`, `Godot_v4.7-stable_linux.x86_64` không trả executable |
| Runtime tìm thấy | `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64` |
| `--version` | `4.7.2.stable.official.ed1daf0bf` (exit 0) |
| GUI session | `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-1`, `XDG_SESSION_TYPE=wayland` |
| X11 probe | `timeout 10 xdpyinfo` truy cập được X.Org/XWayland, X.Org version 24.1.14 |
| OpenGL probe | `timeout 10 glxinfo -B`: direct rendering Yes, accelerated Yes, AMD Radeon 780M Graphics, Mesa 26.2.6, OpenGL core/compat 4.6, GLES 3.2 |
| Export templates | `/home/konits/.local/share/godot/export_templates/` tồn tại nhưng **rỗng** |
| Preset repo | Chỉ `Windows Desktop`, x86_64, embedded PCK, output `build/windows/buffalo-fighting.exe`; không custom template trong preset |

Tìm file bằng `find /home/konits /opt /usr/local/bin /usr/bin /mnt/c -maxdepth 5 -iname '*godot*' -type f`; kiểm thêm runtime directory và default Godot data directory. Không cài runtime/template, không đụng zip trong Trash. PATH là blocker cho lệnh tài liệu nguyên trạng nhưng có thể dùng `GODOT=...` như dưới; missing Windows export templates là blocker export mặc định. Chưa thử export nên không có build success/failure exit code. Chưa chứng minh GUI Godot mount/input/render/resize/quit: chỉ chứng minh display và driver hiện có.

## Full baseline: lệnh chính xác, isolation, kết quả

Đã đọc `tools/run_tests.sh` trước. Runner `cd` về repo, `GODOT` hỗ trợ absolute path, `TEST_TIMEOUT` mặc định 180 s, `TEST_LOG_DIR` override được; import không có timeout riêng. Sau import, runner chạy glob `tests/*_test.gd`, rồi năm cặp host/client (host chạy nền, client khởi động sau 2 s). Mỗi test/pair process có `timeout 180`; runner đợi host rồi tổng hợp exit code, không fail-fast.

Invocation đã thực thi:

```bash
cd /home/konits/projects/ltrgame/buffalo-fighting
BASELINE_DIR=$(mktemp -d /tmp/ltrgame-refactor-baseline-20261117.XXXXXX)
mkdir -p "$BASELINE_DIR"/{data,config,cache,logs}
env XDG_DATA_HOME="$BASELINE_DIR/data" \
    XDG_CONFIG_HOME="$BASELINE_DIR/config" \
    XDG_CACHE_HOME="$BASELINE_DIR/cache" \
    GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
    TEST_LOG_DIR="$BASELINE_DIR/logs" TEST_TIMEOUT=180 \
    bash tools/run_tests.sh > "$BASELINE_DIR/runner.log" 2>&1
rc=$?
printf '%s\n' "$rc" > "$BASELINE_DIR/runner.exit"
```

`BASELINE_DIR` thực tế: **`/tmp/ltrgame-refactor-baseline-20261117.u0svI8`**. File `runner.exit` chứa `1`; `runner.log` chứa toàn bộ bảng 77 checks và từng log nằm dưới `logs/`. Đây là log tạm cục bộ, không phải artifact portable/đã commit.

Isolation áp dụng cho mọi process con, bao gồm cả import và hai tiến trình LAN. Đã quan sát log Godot dưới `.../data/godot/app_userdata/Chọi trâu- Đấu trường lễ hội/logs/`, chứng minh XDG_DATA_HOME có tác dụng. Settings/graphics/notebook của người dùng thật dưới `~/.local/share/godot/app_userdata/` không được dùng làm đường dẫn test. Import vẫn dùng cache `.godot/` hiện có trong repo (ignored), không phải fresh-cache baseline; tracked diff sau chạy rỗng. Đây không phải kiểm chứng filesystem sandbox tuyệt đối, mà là user-data isolation bằng XDG cùng các test-path riêng sẵn có.

### Lỗi thực tế

`logs/network_pair_host.log`:

```text
PASS: host binds test port
PASS: host receives reliable client HORN action
PASS: host receives pause and resume requests
ERROR: host receives client input after resume
  [0] check (res://tests/network_host_harness.gd:36)
  [1] run (res://tests/network_host_harness.gd:25)
NETWORK HOST FAILURES: 1
```

Host bind thành công test port **47931**, có client nối và ngắt. Client exit 0, nhận snapshot host-authoritative và accepted pause/resume. Host harness chờ cố định 5 s rồi kiểm cờ `received_client_resume` từ callback `_on_input_received` (`slot == 2`, `move_y` truthy, `horn` false); lần chạy này cờ không được bật. Không kết luận root cause là networking hay timing; không sửa và không rerun lỗi trong nhiệm vụ baseline.

Năm cặp được runner gọi: `network_pair`, `lan_match`, `lan_rematch`, `lan_ping`, `combat_readability_lan`; chỉ host của cặp đầu fail. Runner cũng chạy `combat_readability_lan_test.gd` riêng trước cặp LAN theo glob hiện tại.

Nhiều test PASS vẫn có `ObjectDB instances were leaked at exit`/`resources still in use at exit` và PagedAllocator diagnostics. Chúng là nợ baseline, không được đánh đồng với log sạch; sau lọc các shutdown diagnostics trên, lỗi còn lại duy nhất là `host receives client input after resume`. Không có Parse Error/SCRIPT ERROR được quan sát qua scan log. Exit code PASS không chứng minh không rò tài nguyên hay không có lỗi shutdown.

## Inventory UI integration hiện có

Các test dưới đây thực sự mở scene/control/controller hoặc truy cập UI thật; không chỉ kiểm helper. Tất cả `*_test.gd` được runner baseline gọi; các file harness khác không tự nằm trong glob.

| Nhóm | File và trọng tâm |
|---|---|
| Layout/hierarchy | `ui_hierarchy_test.gd` (720p/1080p, primary/focus, Solo/LAN result), `pause_layout_test.gd` (pause/wait/confirm/settings/menu), `banner_layout_test.gd`, `hud_countdown_test.gd`, `hud_callout_test.gd`, `lan_ping_layout_test.gd` |
| Dirty writes/throttle | `hud_efficiency_test.gd`, `graphics_quality_test.gd`; `frame_pacing_window_harness.gd` đọc `hud.label_writes` và đo frame |
| Tutorial/controls | `combat_readability_tutorial_test.gd` (queue/front hit/paused state), `howto_accuracy_test.gd` (HUD controls), `combat_readability_test.gd`, `arena_polish_test.gd` |
| Season/flow/rites | `session_test.gd`, `five_levels_test.gd`, `free_play_test.gd`, `training_test.gd`, `arena_prefetch_test.gd`, `gdd_smoke_test.gd` |
| Results/culture | `culture_cards_test.gd`, `festival_notebook_test.gd`, `match_stats_test.gd`, `visual_polish_test.gd`, `polish_batch1_test.gd`, `polish_batch2_test.gd` |
| Settings | `settings_screen_test.gd`, `comfort_settings_test.gd`, `camera_options_test.gd`, `rumble_hud_screenshot_test.gd`, `tpp_test.gd` |
| Outro/replay | `match_outro_test.gd`, `outro_skip_test.gd`, `replay_test.gd`, `solo_announcer_outro_test.gd`, `review_regressions_test.gd`; `result_settled_test.gd` kiểm pose kết quả |
| LAN paths | `lan_snapshot_test.gd`, `lan_result_camera_test.gd`; pair `lan_match_client.gd`, `lan_rematch_pair.gd`, `lan_ping_pair.gd` kiểm HUD thật/rematch/disconnect/ping |
| Other UI coverage | `how_to_play_test.gd`, `howto_rules_test.gd`, `ui_motion_test.gd` kiểm các component liên quan, không thay thế controller/menu integration |

Window harness đã inventory nhưng **không chạy**: `ui_unify_window_harness.gd`, `settings_window_harness.gd`, `review_window_harness.gd` (`--large` cho 1080p), `review_lan_window_harness.gd` (host/client, 720p/1080p), `solo_settled_window_harness.gd`, `frame_pacing_window_harness.gd`, `lan_netem_window_harness.gd`; `lan_ping_pair.gd --window` hỗ trợ ảnh. Các harness ảnh ghi trực tiếp `res://production/qa/evidence/*.png`, ngoài quyền ghi task này nên không chạy. Headless layout/focus assertions không thay thế render inspection/input thật ở 720p/1080p.

## Extraction seams đề nghị (chỉ tư vấn, chưa triển khai)

Line references là baseline: HUD **1071** dòng, menu **678** dòng.

### HUD

1. **Tutorial presenter**: đưa `TUTORIAL`, `tutorial_seen/queue/current/time/front_hit`, `controls_hint_time`, `_tutorial_enabled`, `_queue_tutorial`, `_tutorial_event`, `_update_tutorial` (952–1014) vào module scene-owned. Input: mode, level_id, training flag, local_slot, paused, combat_event, hai actor transforms/forward; output hint plain text/alpha/visibility. `_set_tutorial_text` (932–949) có thể giữ trên façade vì nó sở hữu rich text cache + `label_writes`; không tách mất dirty-write accounting. Keep event subscription order and paused-time semantics.
2. **Training presenter**: `_build_training_panel`, `_training_count`, `_training_success`, `_training_event` (299–375) + popup decay trong `_process` (834–841). Sở hữu panel/counters/popup/time/released/dirty. Input read-only drill dictionary + events + paused delta. Chỉ HUD façade quyết định banner/clash top và text-scale layout; không đưa balance/training simulation vào module.
3. **Pause/settings presenter**: `_build_pause_overlay`, `_place_pause_panel`, `_clear_pause_actions`, `_pause_button`, `show_pause/wait/confirmation`, `hide_pause`, `show_settings`, sensitivity bridge (378–506, 596–652). Inject callbacks resume/restart/leave/change-training, answer_pause và sensitivity setter. Giữ node `PauseShade`, focus owner, visible mouse, layout shrink/center và settings closed behavior.
4. **LAN result presenter**: `_show_lan_result`, `update_lan_rematch` (507–593). Nó hiện dùng **cùng pause shell/actions/stats**: chia sẻ explicit shell interface từ pause module, không tạo overlay thứ hai hay copy `rematch_button/note` state. Input result text/readiness/stats + rematch status/actions; local/disconnected/remote ready phải giữ primary/button focus logic. `show_result` (1036–1048) vẫn façade nhận signal và chuẩn bị text trước outro.
5. **Giữ HUD làm façade**: resource bars/trails, timer, center/banner, clash, announcer, ping, text-size layout, `_process` throttle/accumulated delta và kết quả fade. Giữ stats collector duy nhất cho trận. Không chuyển children làm thay đổi `get_child(0)` root assumption của `_apply_text_scale` nếu chưa cập nhật tương đương.

### Menu

1. **Mode chooser presenter**: `_close_solo_page`, `_solo_page`, `_solo_back`, `_show_solo_chooser`, `_show_free_play`, `_show_training`, `_select_training_row` (227–387). Module sở hữu `SoloPage`, focus, rows và toggles; emit chọn season/level/drill/back. SessionState begin/save vẫn đi qua flow/controller callback duy nhất, không tạo session mirror.
2. **Solo flow coordinator**: `_start_solo`, `_play_rites`, `_enter_arena`, `_ensure_session_overlay`, retry/next/menu/change-free-play (214–224, 390–412, 438–447, 646–673). Duy trì overlay duy nhất `/root/SoloSessionOverlay` sống qua đổi arena và meta `session_overlay`; giữ thứ tự `take_rites_before` rồi `begin_solo` ở next để không rebuild kết quả dưới Phần Lễ. Training không hiện result/culture; free play không tăng mùa/closing rite.
3. **Result/culture presenter**: `_build_session_overlay`, `_show_result`, `_show_culture_card`, `_culture_card_label`, `_fade_culture_card`, `_show_closing_ceremony`, `_round_name` (450–643). Sở hữu result nodes/tween/culture child; nhận actions và SessionState read view, giữ `CultureCards.mark_shown` chỉ khi thẻ thực sự visible. Chốt nơi duy nhất append `culture_cards_seen`, tránh double-award do delegate gọi lại.
4. **Giữ prefetch single-owner**: static `_arena_scene`, `_prefetch_arena`, `_finish_prefetch`, `_go_to_arena` (415–435) cùng host hoặc loader dùng chung. Static `process_frame` callback phải lấy threaded request kể cả menu đã free/chuyển LAN, rồi disconnect; không đổi sang coroutine giữ menu sống. `arena_prefetch_test` đọc static cache bằng `Script.get`.
5. Mọi module sở hữu node/signal/tween phải sống cùng scene/presenter; callback sau `queue_free`, deferred visibility callback, closing ceremony focus target, scene_changed reset và static prefetch disconnect cần regression riêng. Chuyển lifecycle có kiểm chứng, không chỉ kéo method sang file mới.

## Compatibility contract đầy đủ theo scan member/dependency

Tìm bằng `rg -n 'hud\.|_hud\.|menu\.|_menu\.' scripts tests`, scan mọi member khai báo trong hai script với mọi dotted reference trong `scripts/**/*.gd` và `tests/*.gd`, rồi tìm dynamic `get/set/call/call_deferred`. Scan lexical có thể dính common-name alias; danh sách dưới là contract bảo thủ cần giữ façade/delegating getters/setters thay vì sửa giảm test coverage. Test ghi vào một số state trực tiếp, do đó read-only getter hoặc bản sao mảng là chưa đủ.

### HUD được code khác gọi

- `match_controller.gd`: `set_script(HUD)`, assign `controller`, signal `match_ended -> show_result`, `_return_to_menu`, `showing_settings`, `settings_screen.close()`, `show_pause_wait`, `show_pause`, `hide_pause`, `show_pause_confirmation`.
- `match_network.gd`: `show_result`, `update_lan_rematch(true)` khi disconnect, `update_lan_rematch()` khi trạng thái đổi.
- `match_replay.gd`: `visible`, `hide()`, restore `visible`.
- `main_menu.gd`: `hud.visible`, `hud.stats.create_block()`; không thay stats thành bộ đếm khác trong presenter.

### HUD được tests/harness quan sát hoặc sửa

- Methods/constants: `_process`, `_return_to_menu`, `_show_lan_result`, `_training_success`, `_tutorial_event`, `_update_ping`, `hide_pause`, `show_pause`, `show_pause_confirmation`, `show_pause_wait`, `show_result`, `show_settings`, `update_lan_rematch`, `CONTROLS`, `TIMER_WARNING`.
- Actor/resources: `controller`, `player_spirit`, `player_stamina`, `opponent_spirit`, `opponent_stamina`, `spirit_trails`, `spirit_labels`, `stamina_labels`, `low_stamina`, `warning_time`, `label_writes`, `range_writes`.
- Main strips: `timer_label`, `announcer_label`, `center_label`, `top_bar`, `previous_phase`, `fight_banner_time`, `controls_hint_time`.
- Clash: `clash_bar`, `clash_hook_label`, `clash_keys_label`, `clash_panel`, `clash_time_label`, `clash_title`.
- Tutorial: `tutorial_current`, `tutorial_front_hit`, `tutorial_label`, `tutorial_queue`, `tutorial_seen`.
- Training: `training_panel`, `training_counter`, `training_counts`, `training_popup`, `training_popup_time`.
- Overlay/result: `pause_actions`, `pause_detail`, `pause_overlay`, `pause_panel`, `pause_title`, `settings_screen`, `showing_settings`, `rematch_button`, `rematch_note`, `result_label`, `stats`, `stats_panel`.
- Identity/tree assumptions: `TrainingPanel`, `LanPing`, `PauseShade`, `ResultShade`, `RematchButton`, `MatchStats`; retain CanvasLayer visibility, descendants that tests search recursively and focusable button text/order/theme.

### Dependencies HUD đọc/gọi ra ngoài

- Controller direct: `_level_config()` (private dependency cần public replacement), `active_clash`, `announcer_active()`, `announcer_text()`, `combat_event`, `countdown_time`, `get_node("CameraRig").mouse_sensitivity`, `lan`, `level_id`, `local_slot`, `mode`, `network`, `opponent`, `outro`, `paused`, `phase`, `player`, `remaining_time`, `result_ready`, `resume_from_menu()`.
- Nested: `network.ping_changed`, `ping_ms`, `answer_pause(bool)`, `leave()`; `lan.request_rematch()`, `peer_left`, `can_rematch()`, `local_wants_rematch`, `remote_wants_rematch`; `outro.can_skip()`, `is_revealing_lot()`, `time`; actors `spirit`, `stamina`, `global_position`, `forward()`, `clash_hooked`; `training.counters/name/counter_text/get("attack_event", "")`; level dictionary `opponent_number/opponent_giap`.
- Shared: `SessionState.hud_text_large`, `return_to_menu()`; `GameBalance.get_angle/get_int/get_number`; `GraphicsQuality.hud_refresh_interval()`; `HudText.apply/scale_factor/set_size`; `UiMotion.attach/banner_scale/change_scene`; `SettingsControls.MUTED`; `ControlsDiagram.GOLD/PAPER`; `SettingsScreen.new`, `on_sensitivity`, `closed`, `open/close`; `MatchStats.new/on_combat_event/create_block`.
- Cross-script static write: `load("res://scripts/ui/main_menu.gd").return_to_training = true`.
- Controller API seam suggestion: expose read-only `level_config()` and HUD-result/outro/pause/rematch view/accessors, plus intent methods for resume/answer/leave/rematch/sensitivity; maintain existing values/tick order/payload and existing façade callers while introducing them. Do not hide snapshot state in a second cache with different timing.

### Menu được scripts/tests/harness gọi

- Properties: `menu_layout`, `menu_settings_layer`, `solo_page`, `ceremony_layer`, `result_actions`, `result_detail`, `result_panel`, `result_title`; preserve `result_stage/result_tween/displayed_result` semantics even though no specific external dotted reference found.
- Methods: `_close_solo_page`, `_ensure_session_overlay`, `_enter_arena`, `_process`, `_round_name`, `_show_free_play`, `_show_how_to_play`, `_show_result`, `_show_settings`, `_show_solo_chooser`, `_show_training`, `_start_solo`, `_unhandled_input`.
- Static: `return_to_training` set by HUD; `return_to_free_play` used internally; `_arena_scene` dynamically read by `arena_prefetch_test.gd:33,35,45` via `menu_script.get(...)` or `menu.get_script().get(...)`. Preserve single cache and return flags across scene lifetimes.
- Overlay constructors in tests set the original script, name `SoloSessionOverlay`, meta `session_overlay`, then expect `_ready` to build compatible fields. New modules must not break this construction path.
- Nodes/tests rely on `SoloButton`, `HowToPlayButton`, `SettingsButton`, `SoloPage`, `SoloBack`, `SeasonButton`, `FreePlayButton`, `TrainingButton`, level IDs `L01`–`L05`, drill IDs, `UnlimitedStamina`, training child `Keys`/`Description`, `HowToPlay`, `Backdrop`, `MenuBackdrop`, `LeftShade`, `CultureCard` (meta `card_id`), `MatchStats` and action text/order/focus.

### Dependencies menu đọc/gọi ra ngoài

- `SessionState`: `SOLO_LEVELS`, `begin_free_play(level)`, `begin_solo()`, `begin_training(drill)`, `culture_cards_seen`, `free_play`, `last_match_level`, `last_reason`, `last_winner`, `level_id`, `mode`, `retry()`, `return_to_menu()`, `save_settings()`, `take_rites_before(level)`, `training_unlimited_stamina`.
- Current `MatchController`: `phase`, `result_ready`, `hud.visible`, `hud.stats`, `replay == null || !replay.active`; also `scene.get("phase")/get("result_ready")` are dynamic reads.
- `MatchInput.configure_ui`; `/root/GameAudio` cast `FestivalAudio.play_music`; `GraphicsQuality.apply_live/apply_viewport`; `GameBalance.get_int/get_number`; `DataFile.load_json` for levels/training/culture; `MoveDemo.MOVES` fields `id/keys`; `ControlsDiagram.GOLD/PAPER/keycap`; `SettingsControls.MUTED/row_style/style_toggle`; `SettingsScreen.closed/open/close`; `HowToPlay.closed`; `MenuBackdrop.new`; `CeremonyView.create` and `finished`; `CultureCards.next_card/mark_shown`; `HudText.apply/set_size`; `UiMotion.attach/change_scene/enter_result`.
- Engine lifecycle: `ResourceLoader.load_threaded_request/get_status/get`, global `SceneTree.process_frame` static subscription, `scene_changed`, `current_scene`, root overlay lookup, `Input.mouse_mode`, focus, `queue_free`, scene reload/change and node-bound tweens.

## GDD v0.8: hiện trạng read-only so với v0.7

- Trước task `docs/GDD_Choi_Trau_v0.8.md` **untracked**. Đọc đủ 321 dòng; file tự ghi rõ **“Bản thảo để duyệt”**, mô tả main sau PR #10 (`21ae5af`), **chưa thay tài liệu chuẩn**. AGENTS/CLAUDE/ARCHITECTURE vẫn trỏ v0.7.
- v0.7 có 1492 dòng, bản chuyển từ PDF theo trang, chi tiết luật/tick order/tables/nguồn hình; v0.8 là bản viết lại dễ đọc theo chủ đề, không phải patch nhỏ hay tài liệu đã duyệt. Không thể tự đổi canonical pointer chỉ vì số phiên bản cao hơn.
- v0.8 mô tả rõ chức năng code hiện có/bổ sung ngoài scope v0.7: Đấu tự do, năm bài Sân tập, replay FLEE, stats, Sổ tay lưu riêng, rematch/ping LAN, đồ họa và settings/comfort/gamepad/F12. Nêu rõ mùa chỉ giữ trong phiên (không save mùa), notebook/settings lưu qua lần chạy, không bảo đảm LAN hai máy/tay cầm/hiệu năng nhiều cấu hình.
- Các luật chính vẫn SPIRIT/STAMINA, 90 s, FLEE/TIME/LOT; phụ lục có số liệu tham khảo và nguồn code/data, không phải quyền đổi balance. Không thực hiện audit exhaustive mọi con số GDD trong task này.
- Không sửa, rename, stage hay overwrite hai GDD. SHA-256:
  - v0.7: `1fa1e2c8e2c7ec9e705d34ac29f9468f37738fc44b766ad9b35c7508bea3866a`
  - v0.8: `9a01509488e71694066ee47632a9bcc2e6219f83fe13a75c0b30fd8713d6cf9c`

## Git, lệnh điều tra và cleanup

Trước và ngay sau full tests:

```text
$ git status --short
?? docs/GDD_Choi_Trau_v0.8.md
?? docs/superpowers/
$ git diff --stat
# rỗng
```

Kiểm sau ghi báo cáo xác nhận status chỉ thêm `?? production/qa/refactor-baseline-2026-11-17.md` ngoài hai untracked docs trên có từ trước; `git diff --stat` vẫn rỗng, `git diff --exit-code -- scripts tests data project.godot export_presets.cfg docs/GDD_Choi_Trau_v0.7.md` exit 0, hai SHA-256 GDD vẫn như trên. Không gameplay/test/config change; không commit. Main có thể đang làm file khác cùng workspace: không nhận những thay đổi đồng thời đó là của worker này.

Các lệnh điều tra chính ngoài invocation đã ghi: `git rev-parse HEAD`, `git status --short`, `git diff --stat`, `command -v`, `find` runtime/template, runtime `--version`, `xdpyinfo`, `glxinfo -B`, `wc -l`, `sha256sum`, `rg` UI consumers/dynamic calls/test inventory/log diagnostics, Python regex read-only inventory member references. Không export, GUI game launch, server/proxy hay terminal con nào được tạo.

Runner đã kết thúc và tự wait mọi host; kiểm `ps -eo pid,ppid,comm,args` không còn `Godot_v`, `run_tests.sh`, `timeout 180` thuộc đợt này. Không đóng terminal/tiến trình người dùng. Đã xóa isolated data/config/cache và hai file scratch inventory/path thuộc worker; giữ **chỉ bằng chứng log** `/tmp/ltrgame-refactor-baseline-20261117.u0svI8/{logs,runner.log,runner.exit}` cho main đọc. Đây không phải process/service đang chạy; có thể xóa sau khi main lưu bằng chứng. Không xóa import cache `.godot` dùng chung. Đã nhận lệnh coordinator dừng sau báo cáo do người dùng đi ngủ: không mở rộng/triển khai và không nhận việc tiếp cho tới yêu cầu mới của người dùng.

## Việc main còn phải làm

1. Lập implementation plan, public controller API và module ownership/lifecycle; không coi báo cáo này là implementation.
2. Ghi lỗi LAN host baseline và shutdown-resource noise, điều tra root cause riêng; không giảm test coverage để xanh.
3. Regression thật qua controller/state/render sau mỗi seam; giữ các façade compatibility nói trên và thêm lifecycle/free/callback tests qua event path thật.
4. Chạy window/render/input ở 720p/1080p với user-data isolation và ảnh đúng quyền; Solo mùa/retry/training/free play/replay/settings/pause và LAN pause/rematch/disconnect vẫn cần nghiệm thu.
5. Quyết định v0.8 qua phê duyệt riêng, bảo toàn draft; không đổi GDD canonical tự động.
6. Cung cấp Godot export templates đúng 4.7.2/Windows hoặc custom template được duyệt, build độc lập, playtest ngoài nhóm và đo FPS cấu hình mục tiêu; chưa có bằng chứng đạt các mục này.
