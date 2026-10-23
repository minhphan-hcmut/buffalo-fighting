# Changelog GDD

## v0.4 — 22/10/2026

- Thay prototype 3D cũ bằng combat 2.5D theo GDD: SPIRIT/STAMINA, HORN/DASH/GUARD, countdown 90 giây, hit theo cung, guard hướng trước, PINNED và CLASH đối xứng.
- Thêm balance/level/AI JSON, FSM ba profile, tiến trình Solo, arena bầu dục có cổng và vùng bùn, HUD/pause/settings trong menu và trận.
- Thêm ENet Host/Join, kiểm tra peer/sequence, input/action tách kênh, timeout, snapshot 30 Hz và yêu cầu đồng thuận pause LAN.
- Giữ nguyên GLB trâu hiện tại; cập nhật test combat, AI, camera, asset và smoke.
- Thêm tóm tắt triển khai liên kết tới [GDD Skeleton v0.4](GDD_Skeleton_Choi_Trau_v0.4.docx); không chép lại toàn bộ tài liệu thiết kế.
- Giữ định hướng hình ảnh theo yêu cầu góc nhìn 45° kiểu 2.5D; scene, nhân vật và camera vẫn dùng nền tảng 3D theo v0.4, không chuyển thành game thuần 2D.
- Bổ sung flow Solo theo kết quả: chơi lại trận hiện tại, đi tiếp khi thắng hoặc về menu; giữ tiến trình mở khóa trong phiên.
- Bổ sung màn khai hội tĩnh khi vào Solo lần đầu và lời kết tĩnh khi thắng chung kết; nội dung nghi lễ chỉ dùng lời dẫn trang trọng, không minh họa hiến sinh hay bạo lực.
- Các màn SHOULD, minh họa nghi lễ và hoạt cảnh trong trận vẫn ngoài phạm vi cập nhật này; không tuyên bố chúng đã được triển khai.
- Ghi rõ draft `Game-Design-Document.md` v0.1 còn chứa giả định 2D/HP/KO/RING_OUT trái với v0.4; không sửa file ngoài phạm vi.
- Sửa 5 lỗi nghiêm trọng v0.4: (#1) trâu xoay theo camera_yaw mỗi tick; (#2) PINNED kích hoạt khi thân trâu sát hàng rào; (#3) knockback giảm dần theo deceleration; (#4) thả CLASH trừng phạt đối phương đang hook; (#5) Esc đến được MatchController để mở pause và pause LAN do người chơi còn lại xác nhận (host không tự duyệt). Thêm test movement, clash_pinned, pause.
- Theo GDD §2 CLASH: thua thế (lock break) STUNNED 0,6 s và knockback × 1,5 (trước đây × 1,5 chỉ áp khi PINNED); nhả trúng móc làm bên móc STUNNED 0,5 s; nhả sai STUNNED 0,3 s. PINNED trong CLASH chỉ nhân SPIRIT. Thêm key `lock_loss_stun_s`, `lock_loss_knockback_multiplier`, `lock_whiff_stun_s`, `lock_release_stun_s` vào `data/balance.json`.
- Móc bấm cùng tick nhưng không đủ stamina không được tính là đang móc khi đối phương nhả; `rotation.y` của trâu được wrap về [−π, π].
- Animation giai đoạn A (procedural, chưa có rig): `scripts/core/buffalo_animator.gd` gắn vào node `Visual`, chỉ biến đổi hình ảnh, không đụng thân vật lý. Có nhấp nhô/lắc khi đi theo tốc độ thực, chúi khi tăng tốc, nghiêng khi rẽ, thở khi đứng; tư thế riêng cho HORN (lùi lấy đà → lao + hất sừng), DASH, GUARD, STUNNED, CLASH (ngả theo lock_balance), FLEE, thắng/thua cuối trận; tai và đuôi có pivot riêng. Chân chưa bước (cần rig ở giai đoạn B). Thêm `tests/animation_test.gd`.
- Sửa lỗi không capture được chuột: Control gốc của HUD phủ toàn màn hình với mouse_filter mặc định STOP nên chặn click, CameraRig không nhận được để capture lại chuột. HUD trong trận giờ để click đi xuyên (IGNORE), pause overlay vẫn nhận click như cũ. Hạ điểm bám camera `height` từ 1,4 m xuống 1,0 m.
- Tách `match_controller.gd` (902 → 314 dòng) thành `arena_builder.gd`, `arena_bounds.gd`, `combat_resolver.gd`, `clash_system.gd`, `match_input.gd`, `match_network.gd`; không đổi hành vi, test cập nhật theo API mới (`arena.combat`, `arena.clash`, `ArenaBounds`).
