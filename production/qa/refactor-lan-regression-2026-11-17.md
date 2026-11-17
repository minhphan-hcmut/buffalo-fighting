# Task 0 — sửa contract regression LAN, 17/11/2026

## Phạm vi và kết quả

Chỉ sửa `tests/network_host_harness.gd`, `tests/network_client_harness.gd` và tạo báo cáo này. Không sửa NetworkManager/transport/config/GDD, không commit hay tạo worker. Đọc spec/plan và áp dụng TDD/systematic-debugging; Task 0 là test repair, **không tuyên bố baseline toàn bộ hoặc production networking đã xanh**. Full runner/main integration được plan giao main sau review, nên worker không chạy full suite hay mở rộng Task 1–4.

- [x] RED: host mới fail với client cũ mặc dù đã nhận movement trước pause và accepted resume.
- [x] Negative control stream movement cũ sau resume nhưng không gửi marker mới: host/client đều exit 1 đúng assertion.
- [x] Positive: **10/10 isolated pair attempts, host=0/client=0**; không timeout, không run zero movement.
- [x] Preserve action/snapshot/pause/resume coverage; movement vẫn unreliable_ordered channel 1 theo production, không sửa annotation.
- [x] Cleanup process và dữ liệu XDG; giữ mọi log, kể cả fail và shutdown diagnostics.
- [ ] Main review + full runner/production acceptance còn lại.

## Contract và diff

Host bỏ 5 s sleep bắt đầu từ host startup, dùng deadline **10,000 ms** một lần, không gia hạn. Trong thời gian hữu hạn host phát snapshot stage theo cadence ~30 Hz qua `send_snapshot` thật. Client bỏ các sleep 0.6/0.3 s và no-op lobby callback; đợi các predicate nhận từ signals thật:

`connected + READY → gửi HORN → ACTION (host thực sự thấy HORN) → request pause → accepted true + PAUSED → request resume → accepted false + RESUMED → stream marker → COMPLETE (host thực sự thấy marker)`.

`pause_state_changed(false)` từ `join()->leave()` không được tính accepted resume; client clear sau join và chỉ nhận state khi manager.connected. Host chụp `resume_sequence` khi accepted resume sau accepted pause. Host chỉ bật cờ fresh nếu accepted resume, `seq > resume_sequence`, `move_x == 0.5`, `move_y == -1.0`, `horn == false`; pre-pause payload luôn `move_x=0`, không thể chứng minh fresh marker. Sequence lấy từ NetworkManager payload thực, không giả mạo seq caller vì manager tự tăng sequence. Host giữ check reliable HORN, đủ hai request true→false, thêm check accepted state true→false; client giữ snapshot và accepted state checks, thêm host COMPLETE acknowledgement.

Stream client dùng `send_input` thật, cadence `1.0/30.0` s như SEND_INTERVAL production, không chuyển movement sang reliable. `--no-fresh-marker` là negative control chỉ trong test: tiếp tục gửi movement `move_x=0,move_y=-1,horn=false` sau resume, **không** đổi assertion hoặc transport. Dù seq mới và cached movement đang được host phát liên tục, không marker thì phải fail. Đây là manager-level pair, không chứng minh actor simulation/UI/controller resume; regression đó thuộc nghiệm thu khác.

Host đợi hết deadline hữu hạn để còn phát COMPLETE snapshot cho client nhận; client stream dừng khi nhận COMPLETE hoặc deadline/disconnect, không dùng sleep để đoán acknowledgement. Launcher vẫn giữ `sleep 2` tương thích runner hiện có (runner không nằm trong allowed files); **protocol bên trong harness không dựa vào sleep startup này**. Hai deadline khác nhau theo local process start; phía host có thể kết thúc trước client khi negative, client vẫn fail không COMPLETE.

Tên counters `movement_frames` đếm signal physics frames nonzero, **không phải số RPC packet callbacks**. Log `HOST FRAME` chỉ in khi seq đổi, `HOST ACCEPTED RESUME`, `HOST FRESH MARKER` và stream sent count cung cấp evidence freshness. Không giả vờ counters này là instrumentation sâu trong production.

## TDD / bằng chứng cụ thể

Evidence root: **`/tmp/ltrgame-lan-regression-20261117.nyUBgj`**; runtime `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`, log version `4.7.2.stable.official.ed1daf0bf`. Dùng `.godot` import cache hiện có, không fresh import. Mỗi run có XDG data/config/cache riêng và `host.log`, `client.log`, `exit.txt`.

### RED trước khi sửa client

Viết host state-gated marker trước, giữ client gốc rồi chạy `red-original-client-1`:

```text
host=1 client=0
HOST FRAME: seq=1 move_x=0.0 move_y=-1.0 resumed=false
HOST ACCEPTED RESUME: seq=1
PASS: host receives reliable client HORN action
PASS: host receives pause and resume requests
PASS: host accepts pause then resume
ERROR: host receives fresh client marker after accepted resume
HOST INPUT EVIDENCE: movement_frames=55 latest_seq=1 resume_seq=1 fresh=false
```

Đây là lỗi assertion mong muốn, không Parse Error hay failure thiếu connection. Nó chứng minh pre-pause movement/cached input và accepted resume không làm assertion mới tự pass.

### Negative với client mới

`negative-1`, client arg `--no-fresh-marker`: host=1/client=1. Host đã nhận nhiều movement sequence mới, `latest_seq=208`, `resume_seq=1`, `movement_frames=484`, `fresh=false`; HORN, cả request và accepted handshake đều PASS. Host fail **duy nhất fresh marker assertion**, client fail host COMPLETE acknowledgement. Không chặn toàn input để tạo false negative: stream cũ vẫn qua mạng thực sau resume và không đủ làm pass.

### Positive 10 lần, không chỉnh deadline giữa runs

| Run | Host/client exit | resume seq | marker seq | stream sends |
|---|---|---:|---:|---:|
| 1 | 0/0 | 1 | 21 | 21 |
| 2 | 0/0 | 1 | 21 | 21 |
| 3 | 0/0 | 1 | 21 | 21 |
| 4 | 0/0 | 1 | 22 | 22 |
| 5 | 0/0 | 1 | 22 | 22 |
| 6 | 0/0 | 1 | 21 | 20 |
| 7 | 0/0 | 1 | 21 | 21 |
| 8 | 0/0 | 1 | 22 | 22 |
| 9 | 0/0 | 1 | 22 | 22 |
| 10 | 0/0 | 1 | 21 | 21 |

Mọi client log `stage=COMPLETE pause_states=[true, false]`. Số sent không bằng marker seq vì trước resume đã có một input, và stream có thể gửi thêm trước COMPLETE snapshot. Các positive đều có marker sau resume; không run nào còn zero movement cả phiên, nên không kích hoạt stop condition. Tuy nhiên seq nhảy vẫn phù hợp movement unreliable bị thiếu nhiều packet trong quan sát trước; **root cause transport sâu hơn vẫn chưa xác định**, 10 pass không phải bảo đảm không còn flake.

Log có baseline shutdown warnings `4 ObjectDB instances were leaked at exit` và `1 resources still in use at exit` ở nhiều host/client. Không giấu diagnostics dưới exit 0, không sửa lifecycle production ngoài scope. Không có Parse Error/SCRIPT ERROR được quan sát. `git diff --check` exit 0.

## Lệnh chính xác và exits

Đã tạo scratch Python runner `$B/run_pairs.py`, lưu nguyên runner và diff `$B/harness.diff`. Invocation thực tế:

```bash
python3 /tmp/ltrgame-lan-regression-20261117.nyUBgj/run_pairs.py red-original-client 1
# prints red-original-client-1 1 0; command exit 0 vì collector lưu test exits
python3 /tmp/ltrgame-lan-regression-20261117.nyUBgj/run_pairs.py negative 1 --no-fresh-marker
# prints negative-1 1 1; collector exit 0
python3 /tmp/ltrgame-lan-regression-20261117.nyUBgj/run_pairs.py positive 10
# prints positive-1..10 0 0; collector exit 0
```

Runner thực thi tuần tự mỗi pair bằng `subprocess.Popen`, `time.sleep(2)`, `subprocess.run`, `host.wait(timeout=22)`. Argv mỗi process:

```bash
timeout --kill-after=2 18 \
  /home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path /home/konits/projects/ltrgame/buffalo-fighting \
  --script res://tests/network_host_harness.gd -- ''
# client tương tự --script res://tests/network_client_harness.gd -- [--no-fresh-marker]
```

Outer tool timeout 35 s cho RED; 220 s cho negative + 10 positive. Không process exit 124/137, không tăng deadline, không sửa reliable/unreliable behavior. Env per-run: XDG_DATA_HOME=`$B/<run>/data`, XDG_CONFIG_HOME=`$B/<run>/config`, XDG_CACHE_HOME=`$B/<run>/cache`. stdout/stderr mỗi process ghi trực tiếp log riêng, `exit.txt` lưu pair exit codes. Tất cả attempts đều được giữ, không rerun chọn pass hoặc xóa failure.

## Cleanup, integrity và việc main còn lại

Đợi toàn bộ host/client kết thúc, kiểm `ps` không còn Godot/timeout owned task. Xóa **chỉ** XDG data/config/cache dưới evidence root, giữ logs/exit/runner/diff; không chạm user progress hoặc `.godot` chung. Không tạo worker/server/proxy hay terminal mới. Tracked diff task chỉ hai harness; untracked docs/spec/plan và báo cáo baseline/điều tra có từ trước được giữ nguyên.

Main cần review marker/state/sequence gates và semantics snapshot stages, rồi chạy full runner sau nhận patch; không đánh đồng 10 pair pass với overall baseline green. Cần production controller/actor pause movement regression và runtime acceptance riêng theo plan. Không đổi checklist Task 0 trong plan vì file đó ngoài allowed scope.
