# Task 3 — menu và điều phối Solo (17/11/2026)

## Phạm vi và checklist
- [x] Đọc AGENTS/CLAUDE, ARCHITECTURE, spec, plan, baseline compatibility, menu và bảy test yêu cầu đầy đủ.
- [x] RED/GREEN seam mode chooser qua scene/nút thật.
- [x] RED/GREEN seam result/culture, visible-only notebook và lifecycle.
- [x] RED/GREEN seam flow, season/retry/next/rites/free-play/training.
- [x] Focused suite sau từng seam; full bounded isolated suite cuối.
- [x] Kiểm diff/ownership và cleanup; main review/render độc lập còn chờ.

Ruling: triển khai trực tiếp trong shared workspace theo dispatch, chỉ ghi changeset được duyệt; không tạo worktree/worker/commit hay ledger ngoài allowlist. Báo cáo này là ledger Task 3. Task 2 headless 79/79 đã review; R1 actual two-window LAN chưa giải quyết và vẫn chặn release, không thuộc task này. Headless không phải playtest.

## Thiết kế dự kiến
MainMenu giữ façade/static prefetch và overlay identity; SoloModeView sở hữu page/focus; SoloResultView sở hữu result nodes/tweens và thông báo card visible; SoloFlow dùng SessionState trực tiếp để sequencing/nghi lễ/actions, không giữ bản sao progress. Các callback được bind vào node sống cùng presenter.

## Kết quả implementation và API

- `scripts/ui/main_menu.gd`: 678 → 416 dòng; giữ static `_arena_scene`, `_prefetch_arena`, `_finish_prefetch`, return flags, `_ensure_session_overlay` và root `/root/SoloSessionOverlay` + `session_overlay` meta. Giữ methods test-facing bằng delegation và getters cho `solo_page`, `ceremony_layer`, result nodes; `displayed_result`/`result_tween` giữ setter. Settings/howto/backdrop và LAN entry không đổi.
- `SoloModeView extends Control`: `setup(season, free_play, training, unlimited, back)`, `show_chooser/show_free_play/show_training/close`; sở hữu child `SoloPage`, rows, focus và toggles. Chỉ gửi selection intents, không begin/save session. MainMenu không bị view gọi ngược để sequencing.
- `SoloResultView extends Control`: `setup(retry, next, menu, change, closing, result_data, select_card)`; sở hữu shade/result panel/stage/actions/card và result/card tweens. `card_visible(card_id)` phát một lần trên card node khi visible-in-tree; flow ghi notebook. Scene-changed reset là node-bound method; exit kills tweens. View không ghi SessionState. Stats block dùng collector thật duy nhất `arena.hud.stats`.
- `SoloFlow extends Node`: season/free-play/training intents, retry/next/menu/change, `play_rites/closing/clear_rite`, `result_data/select_card/card_visible`. Dùng SessionState trực tiếp, không mirror tiến trình. `result_data()` trả snapshot dùng ngay để render, không lưu bản sao lâu dài. Season card được reserve vào `culture_cards_seen` lúc dựng result như contract test cũ (kể cả closing đang che); **notebook award chỉ khi card thực sự được reveal**, một lần/card. Next giữ last result tới khi rite xong rồi mới `begin_solo`.
- Nghi lễ là child của façade để giữ compatibility; SoloFlow giữ sequencing/callback bound vào chính nó, façade/flow chết thì continuation tự mất. Mode view sở hữu page child thật; result view sở hữu result child/tweens thật.
- UID mới cho ba module và `tests/solo_flow_test.gd` được Godot import sinh; không sửa test cũ, controller/HUD/network/data/GDD/plan hay commit.

## RED/GREEN và sự cố quan sát

Logs tại `/tmp/ltrgame-task3.TTcRs4` (local evidence, không portable artifact).

| Seam | RED thực tế (exit 1) | GREEN |
|---|---|---|
| Mode | `mode-red.log`: real Solo button thiếu scene-owned mode presenter; các lifecycle/focus assertions khác pass | `mode-{solo_flow,five_levels,free_play,training,culture_cards,festival_notebook,arena_prefetch,ui_hierarchy}.log`, cả 8 exit 0 |
| Result | `result-red.log`: overlay thiếu scene-owned result presenter; hidden/visible/double-award, free during result/closing assertions chạy thật | `result-<test>.log`, cả 8 exit 0 |
| Flow | `flow-red.log`: season event thiếu scene-owned SoloFlow; real loss retry, cả 5 arena, next rites và final closing assertions chạy thật | `flow-<test>.log`, cả 8 exit 0 |

Hai lần chạy test đầu mỗi test-addition bắt warning-as-error do infer WeakRef từ Variant; đã sửa explicit `WeakRef`, rồi mới ghi RED assertion thực, không coi parse error là RED hợp lệ. Scan result RED còn phát hiện `SoloModeView._exit_tree -> close -> host.remove_child` đụng parent đang teardown (mode focused trước đó exit 0 nhưng có diagnostic); stack/recent diff chỉ ra root cause, bỏ parent mutation và chuyển page thành child thật của mode view, focused/full cuối không còn diagnostic này. Không có hai lần sửa thất bại cùng defect.

`solo_flow_test.gd` dùng scene/control/controller thật và Button.pressed/CeremonyView.finished paths: chooser replace/back/free focus; invisible card chưa award, reveal award, toggle không double; free giữa tween/closing/next rite, scene_changed sau free, overlay recreate không state cũ; season opening→water, loss retry L01, thắng đủ 5 vòng, đúng giap/drums, overlay instance/meta không đổi, final result không next. Existing free_play/training tests đi qua mọi level/drill và change/retry/menu, no progression/rites/result cho training; prefetch test xác nhận static callback hoàn tất sau menu free.

## Lệnh và verification cuối

Runtime `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`, headless. Mọi import/test dùng XDG data/config/cache dưới `/tmp/ltrgame-task3.TTcRs4/{data,config,cache}`; không dùng save người chơi thật. Import mỗi seam `timeout 180 ... --headless --path . --editor --import`, cả ba exit 0.

```bash
cd /home/konits/projects/ltrgame/buffalo-fighting
D=/tmp/ltrgame-task3.TTcRs4
export XDG_DATA_HOME="$D/data" XDG_CONFIG_HOME="$D/config" XDG_CACHE_HOME="$D/cache"
G=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64
for t in solo_flow five_levels free_play training culture_cards festival_notebook arena_prefetch ui_hierarchy; do
  timeout 180 "$G" --headless --path . --script "res://tests/${t}_test.gd" > "$D/logs/final-${t}.log" 2>&1
  echo "$t=$?"
done
GODOT="$G" TEST_LOG_DIR="$D/full" TEST_TIMEOUT=180 timeout 3600 bash tools/run_tests.sh > "$D/full-runner.log" 2>&1
echo $? > "$D/full.exit"
```

- Focused cuối **8/8 exit 0**, gồm lifecycle additions cuối và mode page ownership refinement.
- Full isolated bounded suite cuối **exit 0, 80 checks, 0 failed** (79 trước Task3 + solo_flow mới); `full.exit` chứa `0`. Đã chạy full hai lần trong implementation, cả hai 80/80, không thay assertions/test budgets.
- `git diff --check` exit 0; diff bảy test cũ rỗng. Scan toàn bộ `full/` không `SCRIPT ERROR` hay `ERROR:` ngoài shutdown `resources still in use at exit`; baseline ObjectDB/PagedAllocator/resource shutdown noise vẫn tồn tại, không tuyên bố sạch leak. New lifecycle test cuối báo 29 ObjectDB/8 resources ở quit; chỉ assertions WeakRef/tween chứng minh presenter lifecycle cụ thể, không phải toàn app leak-free.

## Giới hạn và cleanup

Không chạy cửa sổ/render inspection/input người thật, không playtest, export hay đo performance; main còn phải review changeset, render 720/1080 và acceptance cuối. Không điều tra LAN R1 hoặc tuyên bố fixed; actual two-window LAN vẫn là blocker release riêng dù pair headless xanh.

Không tạo worker/server/browser/PTY/service. Mọi Godot/runner có bounded timeout, đã kết thúc và `ps` không còn Godot/run_tests thuộc task khi kiểm cuối; không đóng terminal/tiến trình người dùng. Xóa isolated data/config/cache và scratch riêng; giữ logs/full-runner/full.exit tại đường dẫn trên cho main kiểm. Shared `.godot` import cache không xóa. Bảo toàn toàn bộ các file pre-existing/worker khác; chỉ changeset allowlist Task3 được chỉnh.
