# Tóm tắt GDD v0.7 (bản đọc nhanh cho agent)

> Nguồn chuẩn: `docs/GDD_Choi_Trau_v0.7.md` (1488 dòng). File này chỉ để định hướng
> nhanh; khi cần trích chính xác hoặc khi hai bên lệch nhau, **GDD thắng**. Số liệu
> thật nằm ở `data/balance.json`, `data/ai_profiles.json`, `data/levels.json`.
> Đọc GDD theo mục: `Grep "^#"` để lấy dòng tiêu đề rồi Read bằng offset/limit.
> Tóm tắt lập ngày 2026-11-10, đối chiếu code tại `6c8df26`.

## §0 Quy ước, vai trò, quyết định

- Mức yêu cầu: **MUST / SHOULD / OUT**. Nghiệm thu ở Assignment 02 (A02).
- Thuật ngữ (Bảng 1): SPIRIT = Khí thế, STAMINA = Sức, HORN = Húc (chuột trái),
  DASH = Hổ lao (Space), GUARD = Ghìm (giữ chuột phải), CLASH = Khóa sừng (≤ 1,5 s),
  PUSH/HOOK/RELEASE = Đẩy/Móc/Nhả, `lock_balance` −100…+100 (dương có lợi cho slot 1),
  PINNED là điều kiện (không phải state), kết thúc FLEE/TIME/LOT, host = Chủ phòng.
- **Từ cấm** trong UI/tài liệu: "máu, HP, hòa, đo ván, lủi sới". Dùng "chịu thua /
  lui sới / thắng thế".
- Vai trò nhóm: **A** core gameplay (`scripts/core`, `balance.json`); **B** AI + mạng
  (`scripts/ai`, `scripts/network`, `ai_profiles.json`); **C** nội dung, trình bày
  (UI, asset, `levels.json`, Phần Lễ).
- Mọi đổi luật cập nhật **cùng lúc**: GDD + config + test + `docs/CHANGELOG_GDD.md`,
  kèm Decision ID.
- Quyết định đáng nhớ: DEC-08 (CLASH ba lựa chọn) còn **Proposed**, chờ playtest;
  DEC-12 SPIRIT không hồi; DEC-14 va chạm hai oval, CLASH ở 2,9 m; DEC-15 AI giữ hở
  0,1–0,5 m; DEC-16 kết trận MUST chỉ là đóng băng hai trâu, trâu thua đi ra cổng
  là SHOULD.

## §1 Tổng quan

- Làng chài hư cấu miền Bắc, lấy cảm hứng Đồ Sơn. Trâu **06 giáp Đông, cờ đỏ** đấu
  trâu **17 giáp Tây, cờ xanh**. Độ tuổi 12+. Trận ≤ 90 s; trọn Solo 5–10 phút.
- USP: (1) góc và vị trí quyết định; (2) thắng bằng làm vỡ SPIRIT, không có HP;
  (3) cùng luật PvE/PvP, thêm Phần Lễ.
- Trụ cột: P1 va chạm đọc được ngay; P2 input nhạy (buffer 0,10 s); P3 trận ≤ 90 s;
  P4 AI và người cùng luật; P5 trung thành với lễ hội thật.
- Non-goal: matchmaking online, shop, nâng cấp, máu me, cá cược, cảnh hiến sinh.
- Game tham khảo: Nidhogg, Rocket League, For Honor, posture của Sekiro.

## §2 Điều khiển và luật trận

- WASD theo camera (ngang ×0,7, lùi ×0,5). Húc 20 STAMINA; Hổ lao 28; Ghìm cần ≥ 10;
  Esc pause (PvP: bên kia phải đồng ý).
- Cùng tick: HORN thắng DASH; RELEASE thắng HOOK. Buffer 0,10 s, không xếp hàng.
- **Thứ tự tick (§2.2):** input → bắt đầu action, trừ STAMINA → nếu CLASH thì chạy
  CLASH, bỏ bước 4–5 → move_and_slide, kẹp ellipse, tách hai trâu (4 cặp oval,
  3 lượt) → xử lý hit hai chiều từ cùng trạng thái; hit vào kẻ đang commit và đang
  nhắm lại thành CLASH → timer, hồi STAMINA, kiểm tra kết thúc, snapshot.
- Cửa sổ commit: startup + active của HORN, active của DASH.
- **§2.3 Tương tác:** HORN×HORN đều commit → CLASH. DASH×HORN → CLASH, bias +20 cho
  bên dash. Hit vào GUARD hợp lệ → SPIRIT ×0,45, knockback ×0,60, không stun.
  Bất tử 0,45 s, nhưng CLASH kiểm tra trước bất tử.
- **§2.4 CLASH:** vào khóa blend 0,1 s, tâm cách 2,9 m, model xoay hình 10°.
  - PUSH: 0,5 + 0,5 × STAMINA/max, tốn 15 STAMINA/s, cặp trượt 1,7 m/s × hiệu số.
  - HOOK: 20 STAMINA, startup 0,15 s, +35 lock_balance.
  - RELEASE: nhả trúng lúc đối thủ đang startup móc → đối thủ −12 SPIRIT, stun 0,5 s;
    nhả sai → bên nhả mất 10 + 0,12 × lợi thế đối thủ, stun 0,3 s; cùng nhả → không ai mất.
  - |lock_balance| = 100 → bên thua −22 SPIRIT, stun 0,6 s, knockback ×1,5.
  - Hết giờ → mất round(0,2 × |balance|), tối thiểu 3; chỉ không mất khi balance đúng 0.
  - Cooldown CLASH 1,0 s. PINNED (oval thân cách rào ≤ 0,35 m) nhân SPIRIT mất ×1,5.
  - Đẩy thuần tối đa ~90 điểm trong 1,5 s → phá khóa cần HOOK, bias dash, hoặc đối
    thủ cạn sức.
- **§2.5 Kết trận:** kiểm tra LOT → FLEE → TIME (đúng 90 s mà CLASH đang chạy thì
  giải CLASH trước). LOT dùng `match_seed`; kết quả gửi reliable; hoạt cảnh bốc thăm
  ≤ 2 s. SHOULD: camera lên cao, trâu thua ra cổng gần nhất, người dắt đón ở hành
  lang, trâu thắng chào khán giả ~4 s kèm trống hội.
- **§2.6 Phase:** READY → COUNTDOWN (3 s; phím giữ từ trước phải nhả ra) → PLAYING → RESULT.
- **§2.7 Chế độ:** Solo L01 → L02 → L03; thua (kể cả LOT) thì chơi lại trận đó.
  LAN cùng luật.

## §3 Hệ thống

- **Di chuyển:** hệ số theo hướng 1,0 / 0,7 / 0,5 (ngưỡng 45° / 135°); tăng tốc 42,
  giảm 54; xoay 540°/s; bùn ×0,8. Rào 32 đoạn. Oval thân r 0,8, đoạn −0,3…0,85;
  oval đầu r 0,45, đoạn −1,0…−0,6. Khoảng hở đo từ oval đầu.
- **Tài nguyên:** SPIRIT 100, không hồi. STAMINA 100, hồi 18/s sau 0,75 s; GUARD
  rút 12/s; STAMINA về 0 thì GUARD tự hủy.
- **Combat:** HORN tầm 0,5 m, nón 40°, 18 SPIRIT. DASH ghi đè vận tốc 16,25 m/s
  trong 0,22 s (~3,6 m), hở trúng 0,15 m, nón 50°, 14 SPIRIT. SPIRIT mất =
  round(base × g × p) (g = guard, p = pinned). Knockback 8,3 m/s, hitstun 0,3 s.
  **Không có ngẫu nhiên trong combat.**
- **Cân bằng:** ~6 cú húc để thắng; ~5 cú húc thì phải lùi hồi sức.
- **AI (§3.5):** FSM APPROACH / STRAFE / ATTACK / GUARD / RECOVER / CLASH, chỉ sinh
  InputFrame (cùng luật với người). EASY 0,65 s, không dash, CLASH chỉ đẩy (L01);
  NORMAL 0,40 s, móc 35% (L02); HARD 0,25 s, dash ở 2,5–5 m, móc 35% / nhả 25% (L03).
  RECOVER khi STAMINA < 25 tới > 60, giữ cách 5 m.
- **Mạng (§3.6):** port 7777, host-authoritative. Di chuyển `unreliable_ordered`
  30 Hz; action reliable có seq; snapshot 30 Hz gồm trạng thái CLASH. Mất kết nối →
  CONNECTION_LOST, không xử thắng. REQ-N05 (giả lập trễ 50 ms phía host) **chưa làm**.
- **Tiến trình:** chỉ trong phiên, không lưu file.

## §4 Sân, màn, nội dung

- Sân ellipse bán trục 14 × 11 m. Cổng Tây (x = −14) và Đông (x = +14), rộng 3,5 m,
  hành lang 6 m. Vạch vôi x = ±10. Bùn A (−3,3, −3,3), B (3,3, 3,3), r 2,7.
- L01 đất khô, EASY, 5 nhắc hướng dẫn (Bảng 15); L02 bùn A, NORMAL; L03 bùn A+B, HARD.
- Nhịp: menu ≤ 20 s; cảnh lễ ≤ 15 s, bỏ qua được; màn kết quả ≤ 12 s (gồm ~4 s chào).
- MVP: người dắt, trống, múa cờ là sprite động; ≥ 8 SFX.
- **Phần Lễ (§4.5):** MUST: dâng hương + thượng cờ trước Solo; rước trâu thắng về
  đình sau L03. SHOULD: rước nước trước L01; các giáp dắt trâu ra trước L02; rước
  thánh với trống cờ trước L03. Năm thẻ văn hóa: SHOULD.
- **Quy tắc nội dung (§4.6):** không máu; không trâu húc người; không cá cược; tên
  địa danh thật chỉ trong thẻ văn hóa có nguồn; tắt được rung camera.

## §5 Mỹ thuật, âm thanh, UI

- Bảng màu: Đất #8A5A3B, Đỏ #B6453B, Chàm #33546D, Vàng #E8BC65, Giấy #F2E6CF.
- 9 animation: idle, walk, horn, dash, guard, hit, clash, flee, victory.
  Viền đội: đỏ sáng / xanh tối.
- HUD 5 thành phần. Settings: âm lượng, fullscreen, rung, độ nhạy chuột.
- Bảng 19 game feel: FLEE đi kèm camera chuyển góc cao.

## §6 Kỹ thuật, sản xuất

- Godot 4.7.2; Blender → glb. Thứ tự cắt scope: skin/trang trí/VFX → nhạc → AI HARD
  → layout dùng chung.
- Milestone: M1–M3 xong; M4 mới thử hai tiến trình trên một máy; M5–M6 chưa đánh giá.
- Mục tiêu: 60 FPS ở 1280×720; kết quả hiện ≤ 2 s sau sự kiện kết thúc.
- Tài liệu bắt buộc: `docs/AI_USAGE.md` (**chưa có**), `docs/ASSET_CREDITS.csv`,
  `docs/CHANGELOG_GDD.md`.
- Có 4 câu hỏi playtest cần trả lời và bảng rủi ro trong GDD.

## Phụ lục

- A: lý do thiết kế. A.5 sân bầu dục theo sân Hải Lựu; chào khán giả 4 s thay vì chạy
  vòng. A.7 bảng so sánh thực tế và game.
- B: nguồn B1–B18. C: bảng cân bằng (Bảng 26–27) và REQ-G01…G12, AI01, N01…N05.
- D: ý tưởng OUT (vẫn ghi diễn hoạt kết trận "chưa làm"). E: changelog v0.3 → v0.7.

## Đối chiếu GDD ↔ code (2026-11-10)

| Mục GDD | Trạng thái |
|---|---|
| Combat, CLASH, kết trận MUST | Khớp v0.7 (review `scripts/core`) |
| Kết quả LAN gửi reliable | Sửa ở `a04b23b` (branch local) |
| §2.5 SHOULD diễn hoạt kết trận | Làm một phần ở `9b8f4af`: camera lên cao, trâu thua ra cổng, trâu thắng quay về camera, bốc thăm ≤ 1,5 s. **Thiếu:** người dắt, rào hành lang, trống hội. "Chào khán giả" mới là cách hiểu của Claude |
| Phần Lễ MUST | Có màn khai hội tĩnh và lời kết tĩnh (`main_menu.gd`); chưa kiểm tra đủ yêu cầu |
| Nhắc hướng dẫn L01 (5 nhắc) | HUD chỉ có một dòng hướng dẫn tĩnh; chưa đối chiếu Bảng 15 |
| Thẻ văn hóa, cảnh lễ SHOULD | Chưa thấy trong code |
| REQ-N05 trễ 50 ms | Chưa làm |
| `docs/AI_USAGE.md` | Chưa có file |
| `docs/CHANGELOG_GDD.md` | Mới tới v0.4.1; chưa ghi thay đổi kết trận |
