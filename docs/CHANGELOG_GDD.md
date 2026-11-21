# Changelog GDD

## v0.7.4 — 22/11/2026 (bản 1.0.0)

Bổ sung ngoài GDD v0.7, đều không đổi luật chơi hay payload LAN:

- **Đổi phím:** 8 hành động đổi được ở Cài đặt → Điều khiển (bàn phím hoặc nút chuột), gán trùng thì đổi chỗ; `Esc`, `F12` cố định. Gợi ý phím ở HUD, Cách chơi, Sân tập đọc phím đang gán.
- **Tiếng Anh:** toàn bộ chữ trong game (kể cả Phần Lễ, thẻ văn hóa, Sân tập) có bản tiếng Anh; tiếng Việt mặc định. Tên riêng (Chọi trâu, Đồ Sơn, ông trâu, tên giáp) giữ tiếng Việt, kèm giải thích.
- **Màn THỰC HIỆN** (tiếng Anh: CREDITS) và nhãn phiên bản 1.0.0 ở menu.
- **Màn chờ "ĐANG VÀO SÂN"** khi vào trận, thay màn đen.
- **Giao diện:** bảng kết quả ôm theo nội dung; chữ đếm ngược đặt cao hơn, không đè thanh khí thế; nền tạm dừng nâu ấm.
- **Chuyển động trâu:** thêm cổ và hông vào bộ xương dựng lúc chạy. Cổ nhìn đối thủ, đi trước khi rẽ, cúi trước khi húc, lắc khi choáng; hông trễ khi rẽ nên thân cong; lò xo có độ nảy. Chỉ là trình bày.
- **Hiệu năng:** hiệu ứng va chạm dùng lại đèn và biên dịch shader trước dưới màn che; khung tệ nhất trên card tích hợp (Cao) 320 → 36 ms.

## v0.7.3 — 22/11/2026

Ghi lại các thay đổi đã có trong game từ 13/11 tới bản nộp; PDF gốc v0.7 chưa sửa theo.

- **Gạt sừng (thêm, ngoài GDD v0.7):** phím `G`. Cửa sổ gạt 0,15 s, cung trước 60°, tốn 10 STAMINA, hồi 0,8 s; gạt hụt chậm 0,45 s. Gạt trúng HORN làm bên đánh STUNNED 0,5 s, trúng DASH 0,7 s và bị đẩy lùi. Ngay sau đó có 0,5 s phản đòn: HORN khởi động 0,08 s, sát thương × 1,3. Số ở `parry_*`, `counter_*` trong `data/balance.json`.
- **Chế độ chơi:** Solo có Mùa hội 5 vòng (L01 Vòng loại → L05 Chung kết, `data/levels.json`) kèm Phần Lễ; thêm Đấu tự do (chọn thẳng một vòng) và Sân tập (5 bài, Sức vô hạn, không thua). AI bài tập nghỉ 0,8 s sau khi bị gạt choáng (`post_stun_rest_s` trong `data/ai_profiles.json`) để người tập thấy rõ choáng.
- **Màn phụ:** Cách chơi (4 tab, demo từng đòn dùng VFX thật), Sổ tay lễ hội (thẻ văn hóa đã mở), Cài đặt 5 tab (âm thanh, điều khiển, camera, đồ họa, hiệu ứng) dùng chung ở menu và pause, lưu giữa các lần chạy; tự tạm dừng khi game mất focus (tắt được).
- **Kết trận:** trâu đứng yên rồi mới hiện kết quả; người dắt dẫn trâu thua ra cổng; màn kết quả có bảng chỉ số hai cột và lý do thắng (FLEE/TIME/LOT).
- **LAN:** phòng chờ ghi địa chỉ IPv4 của máy tạo phòng để máy kia nhập; đấu lại (ĐẤU LẠI) không cần tạo phòng mới; camera kết quả quay về trâu thắng; HUD hiện ping (đổi màu cảnh báo khi trễ cao). Đã thử 9 trận ở 3 mức mạng giả lập (`tools/lan_netem_proxy.py`), thay cho REQ-N05 (trễ 50 ms phía host); chưa thử trên hai máy thật.
- **Cân bằng:** mô phỏng 6020 trận AI đấu AI (`tools/balance_sim.gd`). Đề xuất `dash_cost` 28→32, `dash_damage` 14→12 cải thiện ít nên **chưa áp**; `data/balance.json` giữ nguyên.
- **Giao diện:** ba tầng nút (chính/phụ/chữ) thống nhất mọi màn, menu chính dạng danh sách; HUD tách thành các presenter (`hud_training.gd`, `hud_tutorial.gd`, `lan_result_view.gd`), không đổi hành vi.

## v0.7.2 — 13/11/2026

- Bảng 17: làm 3 màn Phần Lễ SHOULD (rước nước trước L01, các giáp đưa trâu vào hội trước L02, trống khai hội và múa cờ trên sới trước L03). Mỗi màn hiện một lần mỗi mùa hội, bỏ qua bằng một phím. Chữ ở `data/ceremony.json`, cảnh ở `scripts/core/ceremony_diorama.gd`.
- Thẻ văn hóa (SHOULD): 5 thẻ 73–77 chữ, có nguồn [B1]–[B15], mở một thẻ chưa xem sau mỗi trận Solo; thắng chung kết ưu tiên thẻ di sản. Nội dung `data/culture_cards.json` chờ người dùng/giảng viên duyệt.
- Mục 2.6 và 4.6: hai người dắt đứng ở đầu trâu lúc COUNTDOWN rồi đi ra cổng trước hiệu lệnh (`scripts/core/release_handlers.gd`). Mục 2.5: trâu thắng chào khán giả trong tiếng trống hội. Phụ lục D bỏ ghi "chưa làm".
- Trâu dùng da trâu thật có sẵn trong model (`Buffalo.use_natural_skin()`), bỏ da bạc/crôm trình diễn.

## v0.7.1 — 13/11/2026

- Camera (DEC-01, REQ-G11, bảng tuning): đổi từ nghiêng 45° / 9 m / FOV 75° sang góc thấp qua vai phải: 22° / 5,2 m / FOV 58°, lệch vai 1 m, tâm nhìn cao 1,7 m. Lý do: ở 45° trâu nhỏ, chỉ thấy lưng, cú húc thiếu lực; camera thấp không lệch vai thì trâu mình che đối thủ. Số nằm ở `camera_*` trong `data/presentation.json`.
- Đánh đổi: tầm nhìn sau lưng còn khoảng 2 m (trước đây ≥ 5 m), nên REQ-G11 bỏ tiêu chí "≥ 5 m sau lưng"; bị ép rào vẫn có vòng cảnh báo, rào hai bên vẫn trong khung.
- Trúng đòn: camera giật vào (`camera_punch_*`: 0,16 s, FOV hẹp 4°, tiến 0,45 m); HỔ LAO và phản đòn mạnh gấp 1,6. Chỉ là trình bày, không đổi kết quả trận; tắt cùng tùy chọn rung camera.
- PDF gốc v0.7 chưa sửa theo; bản markdown này là bản đúng.

## v0.4.1 — 01/11/2026

- AI: giữ nguyên quyết định (move, guard) suốt cửa sổ `reaction_s`, nút cạnh chỉ gửi ở tick quyết định; giữ khoảng hở `approach_gap`/`min_gap`; RECOVER có trễ (vào < 25, ra > 60 STAMINA); DASH theo `dash_min_range`/`dash_max_range` của profile. Ngưỡng và xác suất CLASH chuyển vào `data/ai_profiles.json`.
- Va chạm: mỗi trâu là hai capsule 2D (thân + đầu). `separate()` bỏ vận tốc hướng vào nhau, lặp tối đa 3 lượt; sân co theo từng trục. Tầm HORN/DASH đo bằng khoảng hở từ đầu bên đánh (`horn_reach` 0,5, `dash_hit_gap` 0,15), thay `horn_range`.
- CLASH: giữ nguyên luật; đối mặt ở `clash_distance` 2,9 m, vào khóa nội suy trong `clash_enter_blend_s` 0,1 s, `balance` đổi tên `lock_balance`, HUD có thanh giằng co "KHÓA SỪNG" và snapshot LAN mang trạng thái CLASH.
- Knockback: thêm `knockback_time` (`knockback_time_s` 0,3 s) đặt mỗi khi trâu nhận impulse, kể cả GUARD hợp lệ không stun; `separate()` không lọc vận tốc của trâu đang có `knockback_time`. Lúc thoát CLASH, trâu thua giữ knockback của `apply_loss`; chỉ trâu còn lại (không có knockback) bị zero velocity.
- Xóa `buffalo_radius` (không còn script nào đọc). `clash_weights` của AI chỉ giữ `RELEASE` và `HOOK`; PUSH là phần xác suất còn lại. Thêm `back_off_speed`, `strafe_radial_clamp`, `faces_dot`, `wall_*` vào `ai_profiles.json`.
- CLASH và vận tốc: lúc vào CLASH zero vận tốc (và knockback) của cả hai trâu. Lúc thoát, trâu thua giữ knockback do `apply_loss` đặt (`knockback_time_s` 0,3 s); chỉ trâu còn lại, không có knockback, bị zero vận tốc.
- LAN: client áp `facing`, action state (NORMAL, GUARD, STUNNED, FLEE...) và trạng thái CLASH từ snapshot; các trường `action`, `facing`, `position` thiếu hoặc sai kiểu được xử lý an toàn (đã có test); chưa bảo đảm cho mọi trường khác của payload. `tests/lan_match_host.gd` và `lan_match_client.gd` tự kiểm kết quả và thoát mã 1 nếu sai.
- Giới hạn đã biết: kiểm tra xuyên model (`tests/clash_pose_test.gd`) mới đo điểm mõm (z −2,03) ở pose khóa sừng. Sừng, toàn bộ mesh, các pose khác ngoài CLASH và va chạm sát cổng chưa được xác minh. Harness LAN mới chạy trên localhost với một kịch bản CLASH.
- Hằng số còn viết cứng chuyển vào `data/balance.json` (`lock_balance_max`, `lock_split_min_spirit`, `lock_push_*`, `net_interp_rate`, `arena_fence_segments`).

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
