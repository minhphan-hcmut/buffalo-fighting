# Checklist demo và playtest sau refactor

**Trạng thái 17/11/2026: kế hoạch kiểm chứng còn chờ, không phải biên bản đã demo thành công.**
Main review [acceptance matrix](../production/qa/refactor-acceptance.md) trước khi quyết định
phạm vi trình diễn/release. GDD chuẩn v0.7 không đổi; draft v0.8 chưa tự động được duyệt.

## 1. Điều kiện trước buổi demo

- [ ] Chốt build/changeset và người phụ trách vận hành, người ghi lỗi, người giải thích
  simulation/input/LAN, người giải thích UI/lifecycle/data; ghi tên thật khi được phân công,
  không coi danh sách vai trò này là đã có người nhận.
- [ ] Đóng R1 bằng actual pair evidence hoặc main ghi rõ quyết định defer và giới hạn demo:
  lobby/arena đã tới nhưng hai llvmpipe windows tiến chậm; root cause chưa rõ.
- [ ] Cung cấp templates 4.7.2.stable đúng platform với quyền được duyệt; ghi engine/template
  version, exact export command, log/exit, SHA-256/kích thước artifact. Chưa export thử hiện tại.
- [ ] Kiểm package có data/scene/asset cần thiết, không chứa test/tools/dev server/QA/user data;
  kiểm thực tế không chỉ suy từ exclude filter hoặc `.gdignore`.
- [ ] Owner xác minh inventory/nguồn/license HERO/ancient_east, bamboo fence, sparse_grass và
  các mục unknown khác; sửa credits theo bằng chứng ở task riêng. Chuẩn bị credits/license
  bundle người chơi đọc được (CSV dưới docs không mặc định nằm trong gói).
- [ ] Chạy `.exe` trên Windows sạch không editor/source tree; ghi OS/CPU/GPU/driver/RAM,
  resolution, preset, FPS cap, render scale, input devices và log khởi động/thoát.
- [ ] Dùng user-data thử riêng; chỉ reset progress khi owner cho phép. Backup dữ liệu cần giữ;
  kiểm file invalid/unreadable không bị im lặng ghi đè bằng dữ liệu rỗng.

## 2. Kịch bản chạy thật (lặp ở 1280×720 và 1920×1080)

Ghi mỗi bước PASS/FAIL/CHƯA CHẠY + log/ảnh/video, thao tác, expected/actual; không đánh dấu
PASS bằng ảnh staging hoặc emit event thay input gameplay.

- [ ] Fresh start → menu → Tab/Shift+Tab/Enter/B/Esc/mouse focus; resize và window/fullscreen.
- [ ] Cách chơi/Sổ tay/settings: tab, cuộn, chữ Việt, HUD Thường/Lớn, comfort/audio/camera,
  đóng trả focus; không bị input lọt qua modal.
- [ ] Solo Mùa hội → opening/water → L01: movement/camera/húc/lao/ghìm/gạt/phản đòn bằng
  input thật; xác nhận SPIRIT/STAMINA, tutorial queue, hitstop và tells đọc được.
- [ ] Live CLASH: đẩy/móc/nhả, success popup training và callouts không che đầu/sừng;
  staged ảnh hiện có chưa bao hết những khoảnh khắc này.
- [ ] Pause → settings → Esc vẫn pause → resume; fresh input sau resume, mouse capture,
  mất/nhận focus theo setting; không callback cũ sau đổi scene.
- [ ] Trận thật → FLEE replay/outro/fresh skip → stats/result; loss/retry không tăng mùa;
  thắng → next/rites đúng L03/L05 → đủ năm vòng → closing → card reveal/award đúng một lần.
  Kiểm TIME/LOT riêng có ghi rõ nếu dùng fixture, không gọi fixture là trận thắng thật.
- [ ] Free play chọn L01–L05 → result/retry/change-match/menu, không tăng mùa/closing.
- [ ] Năm training drills + unlimited toggle; hoàn thành đòn bằng input thật, pause/change-drill,
  không result/culture/progression; kiểm counter và popup.
- [ ] LAN **hai máy** cùng mạng: host/join, cả hai điều khiển và nhận combat/snapshot;
  pause accept/reject, resume consent/fresh input, settings giữ pause/focus.
- [ ] LAN result_ready/outro → hai bên rematch consent → fresh scene/stats/epoch;
  disconnect khi đang đấu/paused/settings/result/wait-rematch, khóa rematch và về menu.
- [ ] Quit/relaunch → settings/graphics/notebook còn đúng; mùa chỉ giữ trong phiên, không
  hứa save mùa. Kiểm dữ liệu hỏng chỉ ở path bỏ được; không thử trên save thật.

## 3. Hiệu năng mục tiêu (chưa đo trong refactor)

- [ ] Chốt cấu hình và ngưỡng rubric cụ thể trước chạy; ghi nguồn rubric, không tự đặt thành đạt.
- [ ] Đo frame-time trong combat/VFX/crowd, replay/outro, pause/settings và LAN ở 720p/1080p;
  ghi thời lượng/sample count, average FPS, p95/p99 frame ms hoặc 1% low, spikes và cấu hình.
- [ ] Cold start/import không trộn vào steady-state; giữ raw CSV/log, kiểm resize/input latency.
  llvmpipe staging và wall time headless simulator **không** chứng minh target GPU/FPS.

## 4. Playtest người ngoài nhóm (chưa có evidence)

- [ ] Mời novice và người có kinh nghiệm, ghi số người/tiêu chí tuyển/thiết bị/consent thật;
  ẩn danh phù hợp, không bịa danh tính hoặc trích dẫn.
- [ ] Không hướng dẫn trước các câu cần đo: hiểu SPIRIT/STAMINA, mục tiêu, tells/gạt/CLASH,
  camera/mouse capture, Sân tập, nghi lễ/card, pause và LAN rematch.
- [ ] Ghi level/profile/seed nếu có, thời gian, retries/completion, lỗi, cảm nhận công bằng,
  mệt/motion/accessibility; tách quan sát khỏi diễn giải và gợi ý.
- [ ] Không gọi 100 AI trials là human playtest: mẫu chỉ 4/cell, NORMAL đối chứng, không
  all-pairs, tất cả FLEE. Tuning chỉ sau hypothesis + bằng chứng + before/after được duyệt.
- [ ] Tổng hợp findings và quyết định main (fix/defer/không đổi) với evidence; không sửa balance
  chỉ vì một người thua hoặc từ tỷ lệ thắng AI nhỏ.

## 5. Bàn giao và vấn đáp

- [ ] Giải thích InputFrame → host simulate_tick → snapshot/event → read-only presentation;
  chỉ đúng file ownership và hai public HUD intents trong ARCHITECTURE.
- [ ] Giải thích sole SessionState, static prefetch sau menu free, root overlay identity,
  reservation side effect của result_data/select_card khác notebook visible-only award.
- [ ] Đính kèm full runner exit/log + diagnostic scan, rendered/input evidence, known issues,
  build hash/package inventory, target measurement và human notes theo từng loại riêng.
- [ ] Kiểm cleanup PID/server/terminal chỉ thuộc nhiệm vụ; giữ app cuối người dùng cần,
  không đóng tài nguyên khác. Main review toàn changeset và tự quyết định release;
  checklist này không tự cấp trạng thái hoàn tất.
