# Review độc lập Task 0 — 17/11/2026

## Kết luận cổng

**Full runner mới: exit 0, 77 checks, 0 failed.** Không phát hiện false-positive chặn tích hợp trong **toàn bộ pair hiện tại**; patch sửa đúng contract marker sau accepted resume và giữ transport production. Có một điểm hardening mức Medium ở phân loại signal phía host, nêu dưới đây; main quyết định accept/reject và cho phép HUD extraction, reviewer không tự nghiệm thu production LAN hay Tasks 1–4.

Đọc AGENTS.md, spec, plan Task 0, investigation/regression reports; đối chiếu actual git diff của hai harness với toàn bộ NetworkManager. HEAD `21ae5af576fa128dff88aef76c7f0cd5eec3bc60`. Không sửa code, transport, balance, GDD; không commit hoặc tạo worker. Chỉ tạo báo cáo này và logs riêng.

## Findings theo severity

### Medium — host tự phân loại reset/disconnect false thành accepted resume (hardening, không chứng minh pair false-pass)

- `tests/network_host_harness.gd:90–96`: sau khi `accepted_pause=true`, bất kỳ `pause_state_changed(false)` nào đều bật `accepted_resume`, không kiểm request resume đang được trả lời.
- `scripts/network/network_manager.gd:260–270`: `_on_peer_disconnected` phát false khi xóa remote frame; host vẫn `connected=true`. `leave():152–171` cũng phát false. Vì vậy riêng assertion host `:41` không đủ chứng minh consent resume trong mọi failure path.
- Ranh giới thực tế: initial host()/leave() reset không gây lỗi vì chưa accepted pause; final leave() ở `:44` xảy ra sau assertions. Disconnect trước resume trong flow hiện tại không làm **pair** xanh: host thiếu request false (`:40`), client `_fail_connection` đặt connected=false trước false và client đòi chính xác `[true,false]` + RESUMED + COMPLETE. Không thấy đường false-pass toàn pair do cached pre-pause movement, vì marker 0.5 không được gửi trước accepted client resume.
- Đề nghị main cân nhắc ràng buộc signal host với pending request false/đang answer, kèm negative disconnect-while-paused; không chỉ kiểm `manager.connected` vì host vẫn true khi remote mất. Không sửa trong review.

### Low — deadline host tính cả startup client và chưa chứng minh chịu snapshot loss có kiểm soát

- `tests/network_host_harness.gd:32–38`, `tests/network_client_harness.gd:28–35`, `tools/run_tests.sh:41–44`: mỗi bên có một deadline 10 s không gia hạn; host bắt đầu trước client và launcher còn sleep 2 s. Đây là bounded, không deadlock; client startup chậm/CPU pressure có thể làm host hết ngân sách trước client. Báo cáo implementation thừa nhận sleep launcher còn nguyên, không giấu thay đổi scope.
- Snapshot stage được phát lặp mỗi ~33 ms, `NetworkManager:426–440` vẫn unreliable_ordered channel 2. Stage hiện tại không bị bỏ qua do loss một packet: client chỉ hành động sau thấy stage, host giữ stage cho đến hành động tiếp theo; COMPLETE tiếp tục được phát đến hết deadline. Không phát hiện race đòi đúng một snapshot ngắn ngủi. Nếu mất toàn snapshot trước deadline, client fail đúng thay vì pass.
- Chưa có netem/packet-loss hoặc startup-stress control; không được gọi đây là bằng chứng transport đã ổn định. Đây không phải yêu cầu rewrite transport hay tăng timeout tiếp.

### Low — suite exit xanh nhưng vẫn có shutdown diagnostics

63/77 log chứa warning/error diagnostics; các ERROR quan sát được là resources còn dùng lúc exit, không có `SCRIPT ERROR`, parse error hoặc assertion failure trong full run. Hai network harness đều báo `4 ObjectDB instances were leaked` và `1 resources still in use`. `tools/run_tests.sh:15–21,25` chấm exit code, không coi mọi Godot ERROR là test failure. Đây là tồn tại lifecycle cần được giữ rõ, không kết luận do patch mới hoặc coi là suite sạch tuyệt đối.

## Contract và evidence đã kiểm

- Host `:67–82`: slot 2, marker `(0.5,-1)`, horn false, accepted resume và sequence lớn hơn resume baseline; cached pre-pause `(0,-1)` không thể tự chứng minh resume.
- Client `:29–36,54–62`: HORN reliable chỉ một lần; chỉ stream marker sau thấy cả pause/resume state và host stages; movement send_input thật ~30 Hz, không đổi annotation unreliable_ordered channel 1.
- Client `:24–27,78–81` xử lý đúng join/leave reset: join reset bị bỏ qua và array clear; `_fail_connection` đặt connected=false trước false. Host initial reset cũng không thể bật resume khi chưa accepted pause. Không có regression coverage mới cho actor/controller thực hoặc no-movement-while-paused; manager vẫn phát cached input mỗi physics tick và harness không pause SceneTree.
- NetworkManager `_remote_frame.seq` có thể đến từ movement **hoặc action** (`:399–417`); vì harness chỉ có một HORN trước pause và không gửi action sau đó, seq mới + marker hiện tại vẫn đủ phân biệt movement mới. Không khái quát biến này thành movement-only RPC counter.
- Đọc logs thật tại `/tmp/ltrgame-lan-regression-20261117.nyUBgj`, không chỉ tin bảng báo cáo: RED host=1/client=0, pre-pause movement seq=1 và accepted resume nhưng fresh=false; negative host=1/client=1, latest_seq=208/resume_seq=1/fresh=false và client stage RESUMED; positive-1..10 đều 0/0, marker seq 21 hoặc 22, client COMPLETE và `[true,false]`. Saved runner lưu test exit riêng dù collector exit 0. Controls phân biệt được false-positive cached movement; không phải bằng chứng nguyên nhân UDP/ENet đã được sửa. Không tái chạy các controls trong review, không sửa fixture để mô phỏng kết quả.
- Full-run pair mới: resume_seq=1, marker_seq=22, sent=22, host fresh=true; client COMPLETE, pause_states=[true,false]. Không zero-movement session ở run này; root cause sâu hơn của các zero callbacks trước đây vẫn unresolved.

## Full runner chính xác

Evidence root: `/tmp/ltrgame-task0-review-full-20261117.z3b7Ep`.

```bash
cd /home/konits/projects/ltrgame/buffalo-fighting
B=/tmp/ltrgame-task0-review-full-20261117.z3b7Ep
timeout --signal=TERM --kill-after=10s 1200s env \
  GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64 \
  XDG_DATA_HOME="$B/data" XDG_CONFIG_HOME="$B/config" XDG_CACHE_HOME="$B/cache" \
  TEST_LOG_DIR="$B/logs" bash tools/run_tests.sh > "$B/full-run.log" 2>&1
# wrapper ghi $? vào "$B/exit.txt"
```

Runtime log `4.7.2.stable.official.ed1daf0bf`; bắt đầu `2026-11-17T08:56:26+07:00`, kết thúc `09:01:07+07:00` (281 s). Default per-test timeout 180 s giữ nguyên; outer bound 1200 s bao cả import chưa có timeout riêng trong runner. Thực thi toàn bộ import, 66 standalone tests, 5 LAN pairs (10 process checks): **77 checks, 0 failed, exit 0**, không exit 124/137. Từng log tại `$B/logs`, summary đầy đủ tại `full-run.log`, exit tại `exit.txt`, tổng hợp warnings/errors tại `diagnostics.txt`. Dùng import cache repo hiện có; không hứa fresh checkout/import sạch.

Minh bạch attempts: lần launch đầu `/tmp/ltrgame-task0-review-20261117.vlzQzA` bị reviewer dừng có chủ đích do wrapper thiếu lưu exit, chưa hoàn thành full runner; `ABORTED.txt` và mọi log đã giữ lại. Không dùng attempt đó làm evidence pass và không xóa failures chọn lọc. Launch thứ hai ở trên chạy trọn; không thay test/deadline để xanh.

## Cleanup và blockers còn lại

Tất cả process thuộc hai launch đã kết thúc; kiểm ps không còn Godot/run_tests owned review. Đã xóa chỉ XDG data/config/cache trong hai evidence roots, giữ logs và metadata; không chạm user's progress hay xóa .godot repo. `git diff --check` exit 0; tracked changes vẫn chỉ hai harness implementation; report này là file mới duy nhất của reviewer.

Không có blocker runtime cho **full-suite gate vừa chạy**. Main còn quyết định hardening signal host trước tích hợp và cập nhật checklist plan; production controller/actor pause-resume/disconnect, UI/render acceptance, và điều tra nguyên nhân transport vẫn chưa được review này xác nhận. Mười pass trước cộng một full-run pass không chứng minh hết flake hay networking production được sửa.
