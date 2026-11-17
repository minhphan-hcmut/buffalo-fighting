# Điều tra baseline LAN — 17/11/2026

## Kết luận và giới hạn

**Không phải lỗi resume xác định; đã tái hiện flake ở đường movement unreliable.** Harness gốc chỉ gửi **một** input, trước pause; không gửi input mới sau resume. Cờ mang tên `received_client_resume` có thể bật **trước cả pause**, khi NetworkManager phát lại movement đã lưu và tự xóa cạnh `horn` ở tick sau. Vì vậy assertion này vừa có thể false-negative khi movement không đến, vừa false-positive về resume khi movement đến trước pause.

Đã chứng minh điểm phân kỳ bằng bản copy có instrumentation: trong 6/8 run fail, client gọi `send_input`, host nhận `submit_action` reliable nhưng **không hề vào `submit_input`**; movement giữ 0 xuyên suốt pause/resume. Trong 2/8 run pass, host vào cả hai callback, cờ resume bật trước pause. Không có bằng chứng pause làm rơi input. **Nguyên nhân sâu hơn vì sao movement unreliable không tới callback trong runtime/local scheduling này vẫn chưa xác định** (chưa có packet capture/engine-level trace); không được gọi đây là kết luận về firewall, kernel, ENet bug hoặc lỗi sequence của application.

Không sửa source/test/config/GDD trong repo, không commit, không rewrite mạng. Chỉ báo cáo này được tạo trong repo. Các probe ở `/tmp` không phải bản fix hay release evidence.

## Phạm vi, môi trường và checklist

- [x] Đọc AGENTS, CLAUDE, baseline, systematic-debugging; đọc đầy đủ hai harness, runner, NetworkManager; đối chiếu MatchNetwork/MatchController và các pair khác.
- [x] Tái hiện gốc nhiều lần, XDG riêng, timeout hữu hạn, đợi process kết thúc.
- [x] Instrument ở bản copy ngoài repo; lưu cả pass/fail và nêu rõ giới hạn kết luận.
- [x] Đề nghị fix/test tối thiểu, không triển khai trong repo.
- [x] Kiểm cleanup process và git diff.

Runtime: `/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64`, log version `4.7.2.stable.official.ed1daf0bf`. Game/git root `/home/konits/projects/ltrgame/buffalo-fighting`. HEAD baseline `21ae5af576fa128dff88aef76c7f0cd5eec3bc60`; hai harness có từ commit `edc5c21`, không phải refactor mới. Không chạy full suite lần nữa, không GUI/export/netem, không sửa user's progress. Dùng import cache `.godot` hiện có, không fresh import.

Evidence root: **`/tmp/ltrgame-lan-investigation-20261117.syYXPz`**. Các directory `original-*`, `trace-*`, `resumed-stream-*`, `reliable-control-*` chứa `host.log`, `client.log`, `exit.txt`. `summary.json` tổng hợp kết quả. Đây là log tạm cục bộ cần main lưu nếu muốn portable artifact.

## Reproduction gốc và kết quả

Runner `run_pair` chạy host, `sleep 2`, client; mỗi process `timeout`, host harness tự chờ 5 s tính từ lúc host ready, client chờ 0.6 s rồi gửi một input, sau đó pause/resume cách nhau 0.3 s và leave. Thời gian load executable/autoload của process client nằm trong ngân sách 5 s của host; điều này tạo thêm race độc lập với movement.

Lệnh tương đương runner đã chạy tuần tự 5 lần (không chạy song song hai pair trên cùng port):

```bash
cd /home/konits/projects/ltrgame/buffalo-fighting
B=/tmp/ltrgame-lan-investigation-20261117.syYXPz
G=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64
# i = 1..5; mkdir -p "$B/original-$i"/{data,config,cache}
D="$B/original-$i"
export XDG_DATA_HOME="$D/data" XDG_CONFIG_HOME="$D/config" XDG_CACHE_HOME="$D/cache"
timeout --kill-after=2 15 "$G" --headless --path . \
  --script res://tests/network_host_harness.gd -- '' > "$D/host.log" 2>&1 &
host=$!
sleep 2
timeout --kill-after=2 15 "$G" --headless --path . \
  --script res://tests/network_client_harness.gd -- '' > "$D/client.log" 2>&1
client_rc=$?
wait "$host"; host_rc=$?
printf 'host=%s client=%s\n' "$host_rc" "$client_rc" > "$D/exit.txt"
```

Thực thi qua Python `subprocess.Popen`/`run` với argv đúng như trên, per-run `env`, `time.sleep(2)`, `host.wait(timeout=20)`; outer bash timeout 70 s cho 5 run. Không sửa runner. Không có timeout exit 124/137.

| Run gốc | Host/client exit | Kết quả |
|---|---|---|
| 1 | 1 / 0 | pause-request assertion fail; movement/resume assertion PASS |
| 2–4 | 0 / 0 | cả hai PASS |
| 5 | 1 / 0 | đúng baseline: `host receives client input after resume` fail, reliable HORN và pause/resume PASS |

Run 1 cho thấy một race khác: client có thể nhận đủ hai state nhưng host hết ngân sách trước khi quan sát đủ request; không dùng race này để giải thích thay lỗi movement run 5. Chưa instrument riêng để kết luận chính xác race phụ này.

## Trace actual event path

### Movement/action

1. Client harness dòng 26 gọi `send_input` một lần, `move_y=-1`, `horn=true`.
2. `NetworkManager.send_input` (332+) tách payload thành movement `submit_input` **unreliable_ordered channel 1**, và action `submit_action` **reliable channel 0**. Sequence tăng nội bộ, không dùng seq caller làm monotonic source.
3. `submit_input` (374+) mới ghi `move_y` vào `_remote_frame`. Reliable action chỉ ghi cạnh action, không mang movement.
4. `_physics_process` (109+) phát `_remote_frame` mỗi tick, sau đó set `horn/dash/...` false. Nó không bị gate bởi `_match_paused` và harness không pause SceneTree.
5. Host harness callback (43+) chỉ yêu cầu movement nonzero, horn false; **không kiểm pause history, resume state, sequence mới hoặc thời điểm nhận**. Khi movement đến, tick kế HORN đã đủ bật cờ ngay trước pause.

### Pause/resume

Client `request_pause(true/false)` → reliable `request_pause_rpc` → host cập nhật pending requester/state → host harness `_on_pause_request` gọi `answer_pause(true)` → `_finish_pause_request` đổi `_match_paused`, emit local và reliable `set_pause_state` → client emit `pause_state_changed`. Không bước nào của đường này gửi lại movement hoặc biến action thành movement.

### Evidence trace fail vs pass

Chỉ thêm `print` ở đầu `send_input`, `submit_input`, `submit_action`, `request_pause`, `_finish_pause_request`, `set_pause_state`; host print mỗi khi payload đổi và khi nhận pause request. Không đổi assertion/timer/transport ở nhóm `trace-*`.

`trace-1/client.log`: send_input t=1416; request true t=1720, accepted true t=1727; request false t=2024, accepted false t=2037. `trace-1/host.log` (clock riêng từng process):

```text
2984 neutral input: move_y=0 horn=false
3425 submit_action horn=true
3432 host input move_y=0 horn=true pauses=[]
3453 host input move_y=0 horn=false pauses=[]
3729 host pause true / _finish_pause_request true
4032 host pause false / _finish_pause_request true
ERROR: host receives client input after resume
```

**Không có `submit_input` callback trong toàn bộ log**, instrumentation đặt trước mọi guard nên không phải `same_match`, peer hoặc `_accept_sequence` từ chối sau khi vào function.

`trace-6/host.log`:

```text
3706 submit_input move_y=-1 seq=1
3706 submit_action horn=true
3713 host input move_y=-1 horn=true pauses=[]
3734 host input move_y=-1 horn=false pauses=[]
4010 host pause true
4313 host pause false
PASS: host receives client input after resume
```

Tại t=3734 callback đã thỏa assertion khi `pauses=[]`, rõ ràng trước t=4010 pause đầu tiên. 8 run trace: host fail 1–5,8; pass 6,7; mọi client exit 0. Số callback submit_input tương ứng 0,0,0,0,0,1,1,0. Không đồng nhất timestamp giữa hai process.

## Probe phân biệt (không phải fix)

Tạo bản copy bằng `cp -a --reflink=auto <game-root> "$B/probe-project"` (925 MB logical, copy cache/assets; không sửa source gốc). Giữ diff cuối trong `*.probe-final.diff` ở evidence root. Với mỗi nhóm dùng cùng lệnh pair ở trên, đổi `--path` sang copy, XDG nằm trong thư mục nhóm; process timeout 15 s, outer timeout 100/65/45 s cho nhóm 8/5/3 run.

1. **trace-1..8:** instrumentation-only như trên.
2. **resumed-stream-1..5:** thêm 10 lần gửi `move_x=0.5, move_y=-1, horn=false` cách nhau 1/30 s, bắt đầu 0.1 s sau request resume; thêm assertion mới yêu cầu marker 0.5 được nhận khi host đã thấy true→false. Giữ nguyên mọi assertion cũ. Host/client 1/0 ở run 1, 0/0 ở run 2–5. Số submit_input callback 0,11,11,1,2; marker assertion pass ở 2–5, fail ở 1. **Resend ngắn đơn thuần chưa đủ bảo đảm trong môi trường này**; không được trình bày probe này là fix đã xong.
3. **reliable-control-1..3:** giữ nguyên probe 2, chỉ đổi annotation movement sang `reliable` channel 1 ở copy. Cả 3 run 0/0 và nhận đủ 11 callback movement/run. Đây là differential control khoanh vùng transport, **không phải đề nghị chuyển production movement sang reliable**. Ba pass không chứng minh không còn flake.

Sự khác biệt 0/11 callback toàn run cần điều tra engine/transport sâu hơn nếu production cũng gặp symptom; chưa có bằng chứng đủ để quy cho scheduling/drop cụ thể. Các giả thuyết UDP loss/transport setup chưa kiểm chứng. Không kéo kết luận “resend đã sửa” từ 4/5 run pass.

## So với production và pair đang PASS

- `MatchController._physics_process` (262+) return khi `paused`; khi resume, client đang PLAYING gọi lại `lan.upload_input`.
- `MatchNetwork.upload_input` (59–76) merge edge và upload liên tục ở 30 Hz; không chỉ gửi một packet trước pause như harness. Pause là controller boolean, không đóng ENet. Resume tiếp tục sample/send fresh input.
- `lan_match_client.gd` chờ `lobby_ready`, instantiate arena thật, theo physics frames đến 900; tests về snapshot/HUD/clash/result, không phải assertion fresh input after pause.
- `lan_rematch_pair.gd` và `lan_ping_pair.gd` chờ connection/scene/phase bằng events và frame loops; kiểm rematch/epoch/disconnect/ping. Các PASS baseline của chúng không chứng minh pause/resume-input correctness.
- `combat_readability_lan_test.gd` có gọi `arena.lan.upload_input` và chờ physics frames; không dùng cờ mang nghĩa resume từ movement cũ. Không rerun các pair này ở task giới hạn hiện tại.

## Khuyến nghị tối thiểu cho main

**Fix đầu tiên nên giới hạn ở harness, không network rewrite và không đổi transport production khi chưa có production repro.**

1. Thay khoảng chờ fixed-start bằng deadline hữu hạn và event/state predicate: connected → action seen → accepted pause → accepted resume → fresh movement seen. Cả host/client phải chờ handshake thật; không chỉ sleep rồi giả định.
2. Chỉ tính cờ movement khi resume đã được chấp thuận và payload mang marker/sequence **mới, khác trước pause**. Assert old input trước pause không làm test pass; assert neutral/no post-resume send làm test fail.
3. Sau accepted resume, gửi movement theo đường production `MatchNetwork.upload_input`/30 Hz qua arena thật hoặc mô phỏng stream đúng cadence trong manager-only harness cho test transport. Giữ reliable action coverage, movement unreliable và các assertion gốc về ý nghĩa; không bỏ assertion để xanh. Dùng deadline bounded rộng hơn startup budget, log sequence/state khi fail.
4. Vì stream probe vẫn fail 1/5, **chưa có patch tối thiểu được chứng minh ổn định**. Trước khi nhận fix, chạy nhiều pair isolated và giữ failing logs; nếu tiếp tục zero movement callback toàn session, tách reproduction ENet/RPC tối thiểu hoặc trace packet/engine trước khi sửa NetworkManager. Không chỉ tăng sleep hoặc switch reliable để che failure.
5. Regression production qua controller: giữ movement trước pause, consent true, consent false, sample marker mới sau resume; kiểm host nhận fresh sequence và actor được mô phỏng sau resume, không chuyển động khi paused; thêm negative case marker không gửi thì test fail. Chạy lại full runner sau main quyết định patch.

## Cleanup và toàn vẹn

Mọi child process đều được wait; `ps -eo pid,ppid,args | grep -E 'Godot_v|timeout.*15'` sau các run không có process test còn sống. Không tạo terminal/worker/server/proxy mới, không đụng terminal khác. Đã xóa bản project copy và XDG data/config/cache thuộc các run; giữ logs, exit files, summary, probe diffs. Không xóa `.godot` gốc.

Git status trước báo cáo chỉ có untracked v0.8, `docs/superpowers/`, báo cáo baseline; `git diff --stat` rỗng. Chỉ file báo cáo điều tra này là thay đổi repo thuộc worker. Main sở hữu quyết định fix/integration và kiểm release; điều tra này không tuyên bố network hoặc refactor đã xanh.
