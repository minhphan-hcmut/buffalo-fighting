# Rubric Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor HUD/menu/controller theo phạm vi người dùng duyệt, với hồi quy và bằng chứng runtime.
**Architecture:** HUD/menu giữ façade tương thích cho callers; module con sở hữu trách nhiệm và vòng đời. SessionState và simulation không nhân bản.
**Tech Stack:** Godot 4.7.2, GDScript, ENet, shell runner.
**Spec:** docs/superpowers/specs/2026-11-17-rubric-refactor-design.md

## Global Constraints
- Không commit; không ghi đè draft GDD v0.8.
- Không đổi balance, transport hoặc tick order trong refactor.
- Dùng Godot /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64, XDG data/config/cache cô lập.
- Không giảm assertions để có test xanh. Không hai writer sửa cùng file.
- Main tích hợp và nghiệm thu; báo cáo worker không thay nghiệm thu toàn ứng dụng.

## Review Focus
- Input cũ trước pause không được chứng minh resume thành công (Task 0).
- Callback/signal sau scene free không truy cập node đã mất (Tasks 1–3).
- Settings đóng phải giữ pause và trả focus đúng chỗ (Task 2).
- LAN disconnect/result/rematch không hiển thị state cũ (Tasks 2,4).
- Retry/free play/training không tăng mùa hoặc trao thẻ hai lần (Task 3).

## Task 0: Sửa contract kiểm tra LAN baseline, không rewrite mạng
**Files:** tests/network_host_harness.gd, tests/network_client_harness.gd; production/qa/refactor-lan-regression-2026-11-17.md.
**Interfaces:** NetworkManager signals lobby_ready/input_received/pause_request_received/pause_state_changed; send_input, request_pause, answer_pause, send_snapshot.
- [x] Baseline và trace: báo cáo refactor-lan-investigation-2026-11-17.md chứng minh false-positive trước pause và movement flake.
- [x] Test host chỉ nhận marker mới sau accepted resume; giữ checks action, pause/resume và snapshot. Negative control không gửi marker phải fail.
- [x] Thay sleeps bên trong harness bằng event predicates với deadline hữu hạn; stream movement 30 Hz sau accepted resume, không switch reliable. Runner vẫn có sleep khởi chạy client 2 s.
- [x] Chạy 10 pair isolated đều pass; original-client và no-fresh-marker controls fail đúng. Nguyên nhân zero callback transport trước đó vẫn unresolved.
- [x] Main đọc actual diff và independent review; full runner exit 0, 77/77 (production/qa/refactor-task0-review-2026-11-17.md). Đây là test repair, không phải tuyên bố production network đã được sửa.

Ruling: Chấp nhận Task 0 để tiến hành HUD extraction. Host có thể coi reset/disconnect false là resume nhưng toàn pair vẫn fail do thiếu consent/request và marker; không phải blocker của extraction. Task 2 phải bổ sung regression disconnect-while-paused và phân loại signal theo request thực, không chỉ manager.connected. Shutdown leak diagnostics giữ là nợ baseline, không tuyên bố log sạch.

## Task 1: HUD tutorial và training
**Files:** scripts/ui/hud.gd; new scripts/ui/hud_tutorial.gd, scripts/ui/hud_training.gd; tests/hud_presenters_test.gd.
**Interfaces:** tutorial presenter nhận controller, label-update callback; training presenter nhận controller và root Control. HUD giữ delegated getters/setters cho contract trong báo cáo baseline, giữ dirty-write counters và root-child identity.
- [x] Viết lifecycle/event regressions: pause không tiến tutorial, đúng queue, training chỉ đếm event đúng slot/drill, free scene không callback treo.
- [x] Tách state và methods theo seams baseline, ownership duy nhất và façade tương thích.
- [x] Named tests và hud_presenters_test đạt; full gate sau sửa clock fixture đạt 78/78, exit 0.

Ruling: Main nhận Task 1 theo production/qa/refactor-task1-final-gate-2026-11-17.md và đã đọc hai contact sheets 720/1080. Main sửa training_parry_rest_test.gd để await physics_frame trước manual ticks, giữ nguyên assertions/budgets; runtime probe xác nhận inphys=true/displacement=1/60. Render bao tutorial và năm drills/pause/settings, chưa bao popup/CLASH live hoặc performance. Các mục này thuộc acceptance cuối, không coi là đã playtest combat.

## Task 2: Pause/settings/LAN result và API controller
**Files:** scripts/ui/hud.gd, scripts/core/match_controller.gd; new scripts/ui/match_pause_view.gd, scripts/ui/lan_result_view.gd; tests/pause_test.gd, settings_screen_test.gd, lan_rematch_pair.gd.
**Interfaces:** HUD public close_settings_if_open() -> bool, return_to_menu() -> void thay controller chạm settings_screen/private method; pause view sở hữu shell duy nhất dùng chung LAN result, callbacks resume/restart/leave/answer/rematch.
- [ ] Regression real controller Esc/settings close, pause consent, focus restore, disconnect disables rematch.
- [x] Tách shell/actions/settings và LAN result; giữ façade test cũ, stats collector duy nhất.
- [ ] Cổng nghiệm thu cuối: focused/full headless đạt 79/79 và review không thấy regression; staged UI/render 720/1080 đạt, nhưng actual two-window LAN chưa hoàn tất.

Ruling: Task 2 nhận code review/headless, CHƯA nghiệm thu đầy đủ. Không trì hoãn menu độc lập vì window investigation chưa rõ: Task 3 được triển khai, Task 4/release vẫn chặn bởi R1. Báo cáo refactor-task2-window-investigation-2026-11-17.md sửa boundary: lobby/arena mount thành công, sau đó tiến chậm trên llvmpipe. Main thử original unmodified pair với LP_NUM_THREADS=2, cùng XDG cho handshake file, timeout100: host/client124; logs /tmp/ltrgame-main-lan-threads.wHYrXW. Chưa xác định nguyên nhân, không tiếp tục đoán/sửa mạng hay tăng timeout. Cần profile actual arena/result_ready/outro path, đối chứng original HUD/controller trước extraction hoặc hardware render khi nghiệm thu cuối.

## Task 3: Menu và điều phối Solo
**Files:** scripts/ui/main_menu.gd; new scripts/ui/solo_mode_view.gd, solo_result_view.gd, solo_flow.gd; tests/solo_flow_test.gd.
**Interfaces:** flow dùng SessionState trực tiếp, callbacks chọn season/level/drill/retry/next/menu; result view chỉ trình bày và thông báo thẻ đã visible. Giữ _arena_scene static cache và SoloSessionOverlay identity trên façade.
- [x] Regression mùa năm vòng/retry/free play/training, thẻ chỉ awarded khi visible, prefetch callback hoàn tất sau menu free.
- [x] Tách từng view rồi flow, RED/GREEN từng seam.
- [x] Focused tests và full suite 80/80; independent review và physical render720/1080, main đã xem cả contact sheets.

Ruling: Main nhận Task3 extraction theo refactor-task3-review-2026-11-17.md. Low API footgun: result_data/select_card có side effect reserve thẻ, guard displayed_result bảo vệ actual path; cần tài liệu hóa command semantics, không thêm state/idempotency ngoài scope. Staged results không phải combat playtest; season harness thiếu final completion marker nên chỉ nhận paths có assertion/ảnh và narrow supplemental completion.

## Task 4: Nghiệm thu và bàn giao
**Files:** docs/ARCHITECTURE.md, README.md, HUONG_DAN_CHAY.md, production/qa/refactor-acceptance.md, docs/CHANGELOG_GDD.md; GDD chỉnh sau đối chiếu draft, không tự thay canonical pointer.
- [ ] Full runner + actual render/input 720p/1080p, full Solo và LAN transition checklist; lưu evidence và cấu hình máy.
- [ ] Chạy balance simulator với seeds tái lập; playtest trực tiếp theo kịch bản, không giả lập báo cáo người ngoài nhóm. Chỉ đề nghị/tinh chỉnh balance khi có observation và before/after, test lại riêng.
- [ ] Kiểm templates/export, build chạy độc lập; nếu thiếu template báo blocker và xin cung cấp/cài đặt, không tự tuyên bố build đạt.
- [ ] Cập nhật kiến trúc/GDD sai khác đã kiểm chứng và demo script/phân công vấn đáp; liệt kê kiểm chứng cần người thật.
- [ ] Review toàn changeset, kiểm git diff, cleanup owned resources, giữ app cuối nếu người dùng cần.

## Trạng thái
Thiết kế/phạm vi đã được người dùng duyệt bằng 'ừn, làm đi', sau tạm dừng đã yêu cầu 'tiếp tục'. Task 0 đã qua independent review/full suite 77/77. Task 1 đã nghiệm thu full suite 78/78 và render 720/1080; Task 2 code/headless 79/79 đã review nhưng live-window LAN gate R1 còn mở. Task 3 đã nghiệm thu extraction/headless80/80/render; Task 4 bắt đầu, release vẫn phải giải quyết R1. Không commit. Không dùng lỗi transport chưa rõ để trì hoãn vô hạn hay rewrite mạng.
