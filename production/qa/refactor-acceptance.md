# Ma trận nghiệm thu refactor — 17/11/2026

**Bản tích hợp tài liệu để main review, KHÔNG đánh dấu toàn task/game/release hoàn tất.**
Phạm vi: spec/plan đã duyệt ở `docs/superpowers/{specs,plans}/2026-11-17-rubric-refactor*.md`.
GDD canonical vẫn `docs/GDD_Choi_Trau_v0.7.md`; draft untracked v0.8 được bảo toàn để main
đối chiếu/tích hợp/phê duyệt riêng. Không có phê duyệt GDD mới từ báo cáo này.

## 1. Cách đọc evidence theo rubric

Các cột là **loại bằng chứng khác nhau**, không phải chuỗi điểm cộng tự động. Chưa có bảng
điểm/ngưỡng rubric định lượng riêng được xác minh trong task tài liệu này; không tự gán điểm
hoặc đạt FPS mục tiêu. “Có” dưới đây luôn giới hạn theo đường đã kiểm ở báo cáo nguồn.

| Tiêu chí | Implemented / code | Headless / assertions | Staged render + routed input | Live gameplay | Target performance | External human evidence |
|---|---|---|---|---|---|---|
| Tách trách nhiệm, API, lifecycle | HUD/menu façade + 7 module, sole SessionState; hai public HUD intents | Presenter/overlay/SoloFlow event-state-free regressions; suite audit 80/80 | 720p/1080p views/transitions đã review | Không suy ra combat đúng từ extraction | Chưa đo | Chưa có |
| Tutorial, năm drills, counters | Tutorial/training owners, stats collector riêng duy nhất cho trận | Queue/slot/paused clocks/dirty writes/lifecycle; training clock fixture repair | Task1 tutorial + năm drill panels/pause/settings; Task3 training mount/exit | Chưa có evidence hoàn thành drills qua combat thật; popup/CLASH chưa đủ ảnh | Chưa đo | Chưa có |
| Pause/settings/focus | Một shell, close intent không resume, consent LAN giữ nguyên | 25 overlay checks, actual controller Esc/manager disconnect và pair tests | Task2 Solo/training mouse/settings; LAN wait/confirm/result/disconnect **staged** | Actual two-window LAN chưa hoàn tất (R1) | llvmpipe không là target | Chưa có |
| Solo năm vòng/retry/rites/card | Mode/result views + flow, overlay identity/static cache giữ nguyên | Loss retry, 5 arenas, next/closing, hidden/reveal/double-award và prefetch-after-free | Task3 menu/rites + staged 5 results/closing, narrow supplemental free/training có completion marker | Không có bằng chứng đánh thắng trọn mùa bằng gameplay người chơi | Chưa đo | Chưa có |
| Free play/training không tăng mùa | SessionState giữ contract, training không result/card | Existing free_play/training tests và SoloFlow integration | Change-match/change-drill/focus qua routed mouse | Chưa phải full combat/playtest | Chưa đo | Chưa có |
| Replay/outro/result/readiness | Code hiện có, không rewrite trong refactor | Existing suite bao replay/outro/settled results | Staged results không chứng minh live replay/outro | Cần cross-check gameplay thật, LAN R1 mở | Chưa đo | Chưa có |
| LAN input/pause/rematch/disconnect | Không đổi transport/tick/payload; test harness sửa fresh/consent contract | 5 pairs trong 80/80; rematch reset/epoch và disconnect coverage | LAN UI staged ở hai size, **không có actual pair result screenshots** | R1: lobby/arena reached rồi slow, chưa root cause/fix | Chưa target two-machine run | Chưa có |
| Cân bằng/độ khó | Không đổi balance; 5 progression profiles + DRILL riêng | 100 main AI-v-AI trials, 25 cells, NORMAL đối chứng, 4/cell | Simulator bỏ presentation/UI | Không phải player skill/progression evidence | Tick seconds không là FPS | Chưa có; chưa biện minh tuning |
| Persistence/settings/notebook | SessionState sole progress, settings/notebook lưu riêng; mùa trong phiên | Hidden/visible/idempotency và persistence tests trong suite; paths QA cô lập | Visible reveal được kiểm; không dùng save thật | Cần packaged relaunch và invalid/unreadable path checklist | Không áp dụng | Chưa có |
| Build/demo/distribution | Có Windows Desktop x86_64 embedded PCK preset | Không thay thế export | Không có packaged render evidence | Chưa chạy Windows sạch | Chưa đo máy mục tiêu | Chưa demo/playtest ngoài nhóm |
| Asset provenance/credits | Có CSV nguồn/license nhưng inventory chưa khớp runtime | Không phải legal clearance | Ảnh không chứng minh quyền sử dụng | Chưa đủ điều kiện kết luận phân phối | Không áp dụng | Cần owner xác minh, không bịa nguồn/license |

## 2. Kết luận đã có và giới hạn quan trọng

### Regression và lifecycle

- Baseline 76/77, lỗi harness LAN; Task0 test repair qua review 77/77. Harness gốc có thể
  nhận movement cũ trước pause thành “resume”; sửa stage/deadline/fresh marker và negative
  controls, sau đó Task2 phân loại consent chỉ trong synchronous answer actual request.
  Đây **không phải** kết luận networking production/root cause unreliable đã được sửa.
- Task1 initial full 77/78 có training rest failure. Runtime probe xác định manual
  move_and_slide ngoài physics frame dùng process delta; main sửa fixture await physics_frame,
  giữ DT/assertions/tick budgets. Independent final gate 78/78, không sửa simulation để xanh.
- Task2 full 79/79, code/headless review nhận; actual LAN window gate còn R1. Task3 full
  **80 checks, 0 failed, exit 0**, reviewer audit đúng 80 logs, không SCRIPT ERROR/Parse Error
  hay ERROR ngoài resource-at-exit. Báo cáo nguồn: `refactor-task3-review-2026-11-17.md`,
  logs cục bộ `/tmp/ltrgame-task3.TTcRs4/{full.exit,full-runner.log,full/}`.
- Shutdown `ObjectDB instances were leaked at exit` / `resources still in use at exit`
  (và baseline PagedAllocator diagnostics) vẫn tồn tại. Exit xanh và weakrefs presenter
  cụ thể không chứng minh toàn app leak-free hoặc mọi nondeterminism đã biến mất.

### Render/input không phải combat playtest

- Task1/2/3 contact sheets `production/qa/evidence/task{1,2,3}-contact-{720,1080}.png`
  được reviewer mở kiểm, main đã xem theo plan. Physical captures 1280×720/1920×1080,
  logical viewport 1280×720 do stretch; Xvfb/GL Compatibility/llvmpipe, không target GPU.
- Input qua Viewport.push_input/root routing hoặc button signals theo từng report, không
  người ngoài nhóm chơi bằng bàn phím desktop. AI physics thường tắt/stage cho ảnh ổn định.
- Task3 season harness exit 0 **thiếu final completion marker**: chỉ nhận assertions/ảnh
  paths thực có, không nhận free/training tail. Narrow supplemental cả hai size có
  `TASK3 FREE WINDOW failures=0`; mọi win/result vẫn staged, stats zero expected.

### R1 LAN là blocker xác minh còn mở

`refactor-task2-review-2026-11-17.md` ban đầu chỉ có last print connection starts. Followup
`refactor-task2-window-investigation-2026-11-17.md` chứng minh **cả hai nhận lobby_ready,
đổi scene và mount arena xong rồi tiến rất chậm trên dual llvmpipe windows**, process/physics
vẫn tiến. Không phải kết luận pre-lobby connection failure, firewall hay generic ENet/Xvfb.
Explicit FPS và Low preset không fix; main thử LP_NUM_THREADS=2 cũng timeout host/client124
(`/tmp/ltrgame-main-lan-threads.wHYrXW` theo plan). Không có actual pair result ảnh mới,
không root cause được chứng minh; cần profile actual arena/result_ready/outro path, đối chứng
original HUD/controller hoặc hardware render, không tiếp tục đoán/rewrite transport/tăng timeout.

### Balance và build readiness

Nguồn: `refactor-balance-build-readiness-2026-11-17.md` + JSON trong `evidence/`.
100 main trials = 5 level × 5 progression opponents × 4, NORMAL đối chứng; mỗi cell hai
trận mỗi hướng nhưng seed khác, không matched crossover/all-pairs. Main sample 100 FLEE,
không TIME/LOT; NORMAL thắng EASY 20/20, EASY_PLUS14/20, NORMAL10/20,
NORMAL_PLUS10/20, HARD0/20, CI rộng. Pilot/smoke/HARD repeat không cộng main sample;
unfiltered aborted matrix (có DRILL, 708 completed partial trials) bị loại, không giấu timeout.
**Không tuning nào được biện minh**; không đổi balance từ mẫu nhỏ/AI policy, không human evidence.

Audit templates 4.7.2.stable: default `/home/konits/.local/share/godot/export_templates/`
rỗng, không thấy custom/adjacent templates. Windows debug/release x86_64 binaries thiếu;
**không export thử**, không có artifact/exit export hay clean Windows run. Hướng dẫn export
trong README là lệnh tương lai có điều kiện, không bằng chứng build. Cần templates đúng bản,
export/package inventory/hash, credits bundle và Windows target execution/performance riêng.

### Provenance hiện chưa đủ

`docs/ASSET_CREDITS.csv` ghi nhiều nguồn/license (Quaternius/Kenney/Poly Haven/procedural
sounds), đó là recorded claims không phải independent legal clearance. CSV vẫn gọi old
`assets/characters/buffalo/buffalo.glb` là current trong khi scene dùng HERO; thiếu entries
HERO/ancient_east, bamboo fence, sparse_grass; một số trâu/icon/reference còn unknown/unverified.
Không sửa CSV hoặc tự suy license. CSV dưới docs có `.gdignore` nên không mặc định ship;
owner cần inventory/quyền hiện tại và distributable credits/license bundle trước phân phối.

## 3. Tích hợp tài liệu trong dispatch này

Đã đọc AGENTS, spec/plan được duyệt, **toàn bộ 13 `production/qa/refactor-*.md` có trước
report này**, bảy extracted scripts, façade menu và controller/HUD API paths thực tế.
README sửa ba thành năm progression profiles, hai thành năm pairs, mô tả rig runtime thay
blend-shape foot animation cũ, nghi lễ 3D thay mô tả tĩnh; không rewrite material không liên quan.
ARCHITECTURE ghi actual ownership/lifecycle/static prefetch/public contract và dependency
`controller._level_config()` **vẫn còn**, không bịa public level_config mới.

`SoloFlow.result_data()`/`select_card()` được ghi rõ là commands **reserve season card** bằng
append `culture_cards_seen`, không getter idempotent/polling. Actual view guard displayed_result;
notebook award chỉ khi card visible-in-tree qua card_visible/mark_shown và meta awarded,
kể cả final card reserve trước closing reveal. SessionState vẫn sole progress store.

### Exact files của worker (chỉ 6 file, không commit)

Modified:
1. `docs/ARCHITECTURE.md`
2. `README.md`
3. `HUONG_DAN_CHAY.md`
4. `docs/CHANGELOG_GDD.md`

New:
5. `production/qa/refactor-acceptance.md` (report này)
6. `docs/REFRACTOR_DEMO_CHECKLIST.md`

Không sửa gameplay/config/tests/credits CSV/GDD v0.7 hoặc draft v0.8. Shared workspace đã có
code/test/docs/evidence edits từ main/tasks khác khi worker bắt đầu; không nhận chúng là edits
của worker. Không chạy lại full suite/render/simulator/export trong task docs, không workers,
không app/server/terminal/process nền được tạo; không có tài nguyên owned cần giữ/đóng.

### Diff và factual checks

- `git diff --check`: exit 0 trước khi ghi report và kiểm lại sau toàn changeset.
- `git diff --stat -- docs/ARCHITECTURE.md README.md HUONG_DAN_CHAY.md docs/CHANGELOG_GDD.md`:
  4 tracked files, 166 insertions(+), 26 deletions(-); new docs chưa hiện trong tracked diff stat.
- Python read-only kiểm Markdown fences cân bằng và local links của cả 6 files: không missing
  links; không là Markdown renderer/full linter. Actual scripts/pairs/API names đối chiếu bằng rg/read.
- SHA-256 hai GDD đối chiếu baseline, không đổi:
  - v0.7 `1fa1e2c8e2c7ec9e705d34ac29f9468f37738fc44b766ad9b35c7508bea3866a`
  - v0.8 `9a01509488e71694066ee47632a9bcc2e6219f83fe13a75c0b30fd8713d6cf9c`
- Runtime absolute path tài liệu chỉ là **local example**, portable setup dùng GODOT executable
  người dùng cung cấp. Linux XDG isolation mẫu không được coi portable Windows sandbox.

## 4. Còn lại / factual uncertainties để main quyết định

- [ ] Main review actual docs diff và toàn refactor integration, không dùng report này như sign-off.
- [ ] R1 actual pair rendered/input 720/1080 và two-machine LAN; root cause slow arena chưa rõ.
- [ ] Live combat/full season/retry/replay/outro/CLASH/popup/cross-settings coverage theo
  `docs/REFRACTOR_DEMO_CHECKLIST.md`; staged screenshots không thay các mục này.
- [ ] External humans, consent/notes/observations thật; chưa có testers/quotes để báo cáo.
- [ ] Target rubric thresholds/hardware và raw frame-time measurements; chưa có FPS claim.
- [ ] Templates/export/hash/package inventory, credits/license bundle và Windows sạch.
- [ ] Owner xác minh current-asset provenance và xử lý shutdown diagnostics theo scope riêng.
- [ ] Main đối chiếu/tích hợp draft GDD riêng; không chuyển canonical chỉ vì version lớn hơn.

Không có kết luận “overall complete”, “release ready”, “production LAN fixed” hay “balance
approved” ở gate này. Main sở hữu quyết định tích hợp và các ngoại lệ/defer phải ghi rõ evidence.
