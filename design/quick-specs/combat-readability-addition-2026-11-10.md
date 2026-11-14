# Quick Design Spec: Đọc đòn + va chạm (Gạt sừng → Phản đòn, phạt húc hụt, sườn/lưng, hitstop, nhận diện đòn)

**Type**: Addition
**System**: Combat (§2.2–2.3, §3.3), AI (§3.5), Game feel (§5.4)
**GDD Reference**: `docs/GDD_Choi_Trau_v0.7.md` — Bảng 8, Bảng 9, §3.3 Combat, Bảng 19, Phụ lục A.4, Phụ lục C (bảng cân bằng)
**Decision IDs**: DEC-17, DEC-18, DEC-19, DEC-20, DEC-21
**Date**: 2026-11-10 · **Rà soát cân bằng**: 2026-11-11 (xem mục cuối; số liệu bên dưới đã cập nhật)
**Xem trực quan**: `design/gameplay.html`

## Change Summary

Thêm một thế phòng thủ cần canh thời điểm (Gạt sừng, phím G) có phần thưởng là Phản đòn,
làm cú húc dễ đọc hơn (startup dài hơn, cúi đầu sâu, sừng sáng, chữ nổi), phạt húc hụt,
thưởng đánh sườn/lưng, và thêm hitstop cho mỗi va chạm.

## Motivation

- **P1 "va chạm đọc được ngay"** chưa đạt: startup húc 0,12 s ngắn hơn phản xạ người
  (0,2–0,25 s), nên húc là đòn để đoán, không phải để đọc. Ghìm (block giữ phím) an toàn
  nhưng không thưởng việc đọc đòn.
- **Câu hỏi playtest 1** ("Đánh trượt có tạo cơ hội phản công rõ ràng không?"): hiện
  recovery 0,20 s như nhau dù trúng hay trượt → spam chuột trái gần như không bị phạt.
- **USP "góc và vị trí quyết định"**: hiện góc chỉ quyết định Ghìm có che được hay không,
  chưa quyết định độ mạnh đòn.
- MDA: tăng *Challenge* (đọc–phản ứng) và *Sensation* (hitstop, tín hiệu đòn), không đổi
  luật thắng (vẫn làm vỡ SPIRIT, không có HP).

## Design Delta

### 1. Startup HORN (DEC-21, đã chốt)

GDD hiện tại (Phụ lục C; Phụ lục A.4):

> | horn_startup_s / horn_active_s / horn_recovery_s | 0,12 / 0,18 / 0,20 s | Ba pha của HORN |

> AI dự đoán thay vì phản ứng: startup húc 0,12 s ngắn hơn cả phản ứng của HARD (0,25 s),
> giống người thật; AI quyết định theo khoảng cách và góc như người chơi giỏi đoán đòn.

Đổi thành: `horn_startup_s` = **0,25 s** (15 frame ở 60 Hz; bản 10/11 ghi 0,20 s). Lệch có
chủ ý với A.4: phản xạ trung bình của người ≈ 0,25 s (≈ 16 frame), nên 0,20 s vẫn là đòn
phải đoán; 0,25 s cộng tín hiệu từ frame đầu (cúi đầu, sừng sáng, tiếng thở) là ngưỡng người
chơi đã quen có thể gạt bằng phản xạ, người mới vẫn gạt bằng đoán. A.4 viết lại: AI vẫn
quyết định theo khoảng cách và góc; AI gạt theo tỉ lệ profile, không theo phản xạ (R6).

### 2. Húc hụt (DEC-18)

GDD hiện tại (Bảng 8):

> | HORN recovery (0,20 s) | × 0,50 | Theo camera | Không (được buffer) |

Đổi thành: HORN hết pha active mà **không gây hit hợp lệ nào và không vào CLASH** →
recovery **0,40 s** (`horn_whiff_recovery_s`). Trúng (kể cả trúng Ghìm) hoặc vào CLASH →
giữ 0,20 s. Bị gạt trúng → không vào recovery mà vào choáng của Gạt sừng (mục 3).
DASH giữ nguyên.

### 3. Gạt sừng (G) → Phản đòn (DEC-17, đã chốt)

GDD hiện tại (Bảng 9):

> | HORN / DASH | GUARD | A nằm trong cung guard 60° của B | SPIRIT mất × 0,45, knockback × 0,60; B không bị stun; không tạo CLASH |

Giữ nguyên dòng GUARD. Thêm hành động PARRY và các dòng mới ở mục "New Rules / Values".

### 4. Sườn / lưng (DEC-19)

GDD hiện tại (§3.3):

> SPIRIT mất: spirit_loss = round(base_damage × g × p); g = 0,45 nếu đòn nằm trong cung
> guard, ngược lại 1; p = 1,5 nếu PINNED, ngược lại 1.

Đổi thành: `spirit_loss = round(base_damage × g × max(p, f, c))`, với f (sườn/lưng) và c
(phản đòn) định nghĩa ở dưới.

### 5. Hitstop và nhận diện đòn (DEC-20, DEC-21)

GDD hiện tại (Bảng 19):

> | HORN startup | Trâu cúi đầu | Tiếng thở mạnh | — |

Đổi thành: thêm hitstop ở tầng mô phỏng và các tín hiệu nhận diện (sừng sáng, chữ nổi),
chi tiết ở dưới. Các hiệu ứng va chạm khác của Bảng 19 (bụi, flash, vệt hổ lao) không
thuộc spec này.

## New Rules / Values

### R1. Gạt sừng (PARRY) — action mới, phím G

1. **Điều kiện bấm:** không STUNNED/FLEE, không trong CLASH, hết cooldown, STAMINA ≥ 10.
   **Bấm được khi đang GUARD** (GUARD tạm ngắt trong lúc gạt, giữ chuột phải thì GUARD
   tiếp tục sau khi gạt kết thúc). Không bấm được khi đang startup/active/recovery của
   HORN hoặc DASH (được buffer 0,10 s như HORN/DASH).
2. **Chi phí:** trừ 10 STAMINA lúc bắt đầu; cooldown 0,8 s tính từ lúc bắt đầu.
3. **Pha:** active 0,15 s ngay từ tick bấm (không startup). Di chuyển trong active ×0,30,
   khóa xoay thân.
4. **Gạt trúng:** một hit HORN hoặc DASH hợp lệ tới B trong lúc B đang active PARRY, và
   A nằm trong cung trước của B: hướng từ B tới A lệch ≤ 60° so với hướng mặt B (nón ±60°,
   cùng `guard_half_angle` với GUARD) → thay cho mọi dòng Bảng 9 khác:
   - B mất **0 SPIRIT**, không knockback, không stun; PARRY của B kết thúc ngay.
   - A **STUNNED 0,50 s** (A đang DASH: **0,70 s**), knockback ghi đè dir_away × **2 m/s**
     trong 0,3 s (giật lùi ≈ 0,6 m). A không nhận miễn nhiễm (A không bị hit).
   - Hitstop 6 tick (R4).
   - B mở **cửa sổ Phản đòn 0,5 s**.
5. **Gạt hụt:** hết 0,15 s mà không gạt trúng → recovery **0,45 s**, di chuyển ×0,5,
   không ra action mới (được buffer). Bị trúng trong recovery = trúng đầy đủ như trâu đang
   recovery (Bảng 9 dòng "recovery").
6. **A ở sườn/lưng B** (lệch > 60°): PARRY không có tác dụng; hit đầy đủ, áp f (R3).
7. **Ưu tiên với CLASH:** PARRY không ở cửa sổ cam kết, nên hit vào trâu đang PARRY không
   bao giờ tạo CLASH.
8. **Cùng tick:** B bấm G ở tick N và hit của A tính ở bước 5 của tick N → gạt trúng
   (action mới bắt đầu ở bước 2 trước bước 5, giống ví dụ CLASH của Bảng 9).
9. **Bất tử xét trước Gạt:** B đang bất tử (0,45 s sau khi bị trúng) thì hit tới B bị bỏ
   qua như hiện nay, kể cả khi B đang PARRY: không gạt trúng, A không choáng, PARRY của B
   chạy tiếp. Lý do: không thưởng cho việc gạt một đòn vốn đã vô hại. Thứ tự xét: CLASH →
   bất tử → Gạt sừng → Ghìm → trúng đầy đủ.

### R2. Phản đòn (counter)

1. Trong 0,5 s sau khi gạt trúng, HORN của B **bắt đầu** trong cửa sổ là đòn phản:
   startup **0,08 s** (thay 0,25 s), active và recovery như HORN thường, chi phí và
   cooldown như HORN thường.
2. Hệ số c = **1,3** khi đòn phản trúng (18 → 23), ngược lại c = 1.
3. Cửa sổ đóng khi B bắt đầu HORN (dù trúng hay trượt), bắt đầu DASH/PARRY, bị hit, vào
   CLASH, hoặc hết 0,5 s. DASH trong cửa sổ là DASH thường.
4. Đòn phản đi qua Bảng 9 như HORN thường: A còn đang STUNNED (Bảng 9 dòng "STUNNED") nên
   ăn trọn; nếu A đã hồi và đang Ghìm hợp lệ thì vẫn ×0,45.
5. Hitstop khi đòn phản trúng: 6 tick.

> Ghi chú tuning: A choáng 0,50 s. B cần ≈ 0,15 s nhận ra mình gạt trúng + ≈ 0,17 s bước
> lên tối đa 0,6 m (tăng tốc 42 m/s²) + 0,08 s startup ≈ 0,40 s < 0,50 s, nên đòn phản kịp
> trúng khi B phản ứng ngay. Bấm trễ (sau ~0,42 s) thì A đã hồi và Ghìm/Gạt được: thưởng
> cho người phản nhanh.
> Bản 10/11 (choáng 0,40 s, giật lùi 4 m/s ≈ 1,2 m) cần ≈ 0,43 s nên đòn phản hay hụt.

### R3. Sườn / lưng

- θ = góc giữa hướng mặt của nạn nhân và hướng từ nạn nhân tới kẻ đánh (0° = chính diện).
- θ ≤ 60°: trước, f = 1. 60° < θ ≤ 120°: **sườn**, f = 1,25. θ > 120°: **lưng**, f = 1,25.
- Áp cho HORN, DASH và đòn phản; không áp cho mất SPIRIT trong CLASH (hai bên luôn đối mặt).
- Công thức đầy đủ: `spirit_loss = round(base × g × max(p, f, c))`, SPIRIT kẹp [0, 100].
  Ba hệ số thưởng (dồn rào p, sườn/lưng f, phản đòn c) **không nhân dồn**, chỉ lấy hệ số
  lớn nhất. g và f loại trừ nhau (nón guard ±60° trùng đúng vùng "trước" θ ≤ 60°).
- Lý do lấy max: nhân dồn cho phép một cú mất tới 18 × 1,5 × 1,25 × 1,3 = 44 Khí thế (gần
  nửa thanh, bằng 2,4 cú húc), trong khi SPIRIT không hồi và trận cần ~6 cú. Lấy max thì
  cú mạnh nhất là 27 (1,5 cú húc): vẫn đáng thưởng, không lật trận bằng một pha.
- Ví dụ: húc lưng 18 × 1,25 = 22,5 → **23**; húc lưng khi PINNED 18 × max(1,5; 1,25) =
  **27**; đòn phản 18 × 1,3 = 23,4 → **23**; đòn phản khi A bị dồn rào 18 × 1,5 = **27**.

### R4. Hitstop (DEC-20)

- Khi sự kiện xảy ra ở bước 5 của tick N, host đóng băng mô phỏng **H tick** kể từ tick
  N+1: không di chuyển, không trừ timer action/cooldown/đồng hồ trận, không hồi STAMINA.
  Input trong lúc đóng băng vẫn vào buffer 0,10 s; buffer cũng đóng băng.
- H = **4** khi HORN/DASH trúng (kể cả trúng Ghìm). H = **6** khi gạt trúng, đòn phản
  trúng, vào CLASH. Nhiều sự kiện cùng tick → lấy H lớn nhất, không cộng.
- LAN: host gửi `hitstop_ticks` trong snapshot; client chỉ hiển thị, không tự tính. Mô
  phỏng vẫn tất định vì chỉ host chạy.
- Camera shake/flash vẫn chạy theo thời gian thực trong lúc hitstop.

### R5. Nhận diện đòn (DEC-21)

- **Cúi đầu:** HORN startup cúi 18° (đang 10°) kèm thân lùi lấy đà.
- **Sừng sáng** (emission trên vật liệu sừng): vàng = HORN startup/active và Móc startup;
  đỏ = DASH active; trắng mờ = GUARD; xanh lá lóe = PARRY active và lúc gạt trúng; vàng
  nhấp nháy = đang có cửa sổ Phản đòn.
- **Chữ nổi** Label3D trên đầu trâu, 0,6 s: HÚC, HỔ LAO, GẠT SỪNG!, PHẢN ĐÒN!, ĐÁNH SƯỜN!,
  ĐÁNH LƯNG!, HỤT, MÓC, NHẢ. Chữ có viền, không chỉ dựa vào màu (accessibility §5).
- **Âm thanh** lấy từ asset có sẵn: thở mạnh (HORN startup), chân dồn (DASH), đỡ + va sừng
  (gạt trúng), khán giả reo (đòn phản trúng).

### R6. AI (§3.5)

| Profile | Tỉ lệ gạt khi thấy HORN/DASH tới | Tỉ lệ phản đòn sau khi gạt trúng |
|---|---|---|
| EASY (L01) | 0 | 0 |
| NORMAL (L02) | 0,15 | 0,5 |
| HARD (L03) | 0,25 | 1,0 |

- AI quyết định gạt **một lần mỗi đòn** của người chơi, ngay khi đòn bắt đầu startup, bằng
  RNG có seed của trận (như tỉ lệ móc/nhả hiện có) → combat vẫn tất định. Nếu quyết định
  gạt, AI bấm G **0,10 s trước lúc đòn dự kiến tới** (HORN: 0,15 s sau khi startup bắt
  đầu), không đợi `reaction_s`: tỉ lệ đã thay cho phản xạ. Nếu đợi phản xạ như bản 10/11
  thì NORMAL (0,40 s) luôn bấm muộn hơn startup 0,25 s và không bao giờ gạt trúng.
- HARD 0,35 → 0,25: với 0,35 và phản đòn 100%, mỗi cú húc của người chơi vào HARD chỉ
  còn lời +3,7 Khí thế (0,65 × 18 − 0,35 × 23); với 0,25 là +7,8, vẫn khó nhưng thắng được.
- AI chỉ sinh InputFrame (bấm G), cùng điều kiện STAMINA/cooldown như người.

### Tham số mới (`data/balance.json`, `data/ai_profiles.json`)

| Key | Mặc định | Khoảng hợp lý | Ghi chú |
|---|---|---|---|
| `horn_startup_s` | 0,25 (đang 0,12) | 0,22–0,28 | DEC-21 |
| `horn_whiff_recovery_s` | 0,40 | 0,30–0,50 | DEC-18 |
| `parry_active_s` | 0,15 | 0,10–0,20 | DEC-17 |
| `parry_whiff_recovery_s` | 0,45 | 0,35–0,55 | Gạt hụt hở tổng 0,60 s |
| `parry_stamina_cost` | 10 | 5–15 | |
| `parry_cooldown_s` | 0,8 | 0,6–1,2 | |
| `parry_half_angle` | 60 | = `guard_half_angle` | Nửa góc nón, như `horn_half_angle` |
| `parry_stun_horn_s` / `parry_stun_dash_s` | 0,50 / 0,70 | 0,4–0,8 | |
| `parry_recoil_speed` | 2,0 m/s | 1–4 | Giật lùi ≈ 0,6 m |
| `parry_move_multiplier` / `parry_whiff_move_multiplier` | 0,30 / 0,50 | | |
| `counter_window_s` | 0,5 | 0,3–0,7 | |
| `counter_horn_startup_s` | 0,08 | 0,05–0,12 | |
| `counter_damage_multiplier` | 1,3 | 1,1–1,5 | |
| `flank_min_deg` / `back_min_deg` | 60 / 120 | | |
| `flank_damage_multiplier` / `back_damage_multiplier` | 1,25 / 1,25 | 1,0–1,5 | |
| `hitstop_hit_ticks` / `hitstop_heavy_ticks` | 4 / 6 | 0–8 | 0 = tắt |
| `horn_startup_head_pitch_deg` | 18 | 12–24 | Trình bày |
| `parry_chance` / `counter_chance` (mỗi profile AI) | bảng R6 | 0–1 | `ai_profiles.json` |

## Affected Systems

| System | Impact | Action Required |
|---|---|---|
| Input (`input_frame`, `match_input`) | Thêm phím G / action PARRY | Thêm input action, field trong InputFrame |
| Trâu (`buffalo.gd`) | State PARRY active/recovery, cửa sổ phản đòn, startup HORN động | Cập nhật state machine |
| Combat (`combat_resolver.gd`) | Dòng Bảng 9 mới, công thức f × c, recovery húc hụt | Cập nhật + test |
| Trận (`match_controller.gd`) | Hitstop đóng băng tick | Cập nhật vòng tick |
| CLASH (`clash_system.gd`) | Startup 0,25 s làm cửa sổ cam kết dài hơn → tỉ lệ vào CLASH khi hai bên cùng húc tăng | Không đổi code; đo khi playtest (REQ-G09) |
| Mạng (`match_network.gd`) | Action PARRY reliable có seq; snapshot thêm hitstop, cửa sổ phản đòn | Cập nhật snapshot |
| AI (`scripts/ai`) | Gạt và phản đòn theo profile | Cập nhật FSM + `ai_profiles.json` |
| HUD / trình bày | Sừng sáng, chữ nổi, cúi đầu 18°, lời nhắc phím G | Cập nhật; nhắc tutorial thứ 6 chờ nhóm quyết |
| GDD + CHANGELOG | Nhiều bảng đổi | Bước 2 của kế hoạch (xin duyệt riêng) |

## Acceptance Criteria

- [ ] Mọi giá trị trong bảng tham số đọc từ `data/balance.json` / `data/ai_profiles.json`, không hardcode.
- [ ] HORN có startup 0,25 s; đòn đầu tiên gây hit ở tick đầu sau 0,25 s.
- [ ] HORN hết active không trúng ai, không vào CLASH → recovery 0,40 s; trúng hoặc trúng Ghìm → 0,20 s.
- [ ] B bấm G, HORN của A trúng trong 0,15 s từ phía trước → B mất 0 SPIRIT, A STUNNED 0,50 s; với DASH thì 0,70 s.
- [ ] B đang bất tử và đang PARRY bị chạm → không gạt trúng, A không choáng, B không mất gì.
- [ ] B bấm G và hit tới cùng tick → gạt trúng.
- [ ] A ở sườn/lưng B (θ > 60°) khi B đang PARRY → B mất đầy đủ × 1,25.
- [ ] Gạt hụt: B ở recovery 0,45 s; hit trong lúc đó trừ đầy đủ; G bấm lại bị chặn tới hết cooldown 0,8 s.
- [ ] Đang giữ GUARD bấm G → PARRY bắt đầu; hết PARRY mà vẫn giữ chuột phải → trở lại GUARD.
- [ ] Không bấm được G trong CLASH; hit vào trâu đang PARRY không bao giờ tạo CLASH.
- [ ] HORN bắt đầu trong 0,5 s sau gạt trúng có startup 0,08 s và trừ 23 SPIRIT (không guard, không pinned, trước mặt).
- [ ] Húc lưng trừ 23; húc lưng khi PINNED trừ 27 (không phải 34); đòn phản khi A bị dồn rào trừ 27.
- [ ] Hit trúng đóng băng mô phỏng 4 tick; gạt trúng / phản đòn / vào CLASH 6 tick; đồng hồ trận không trôi trong lúc đó.
- [ ] LAN: test hai tiến trình cho thấy client và host cùng SPIRIT, cùng kết quả gạt, cùng số tick hitstop.
- [ ] AI EASY không bao giờ bấm G; HARD gạt khoảng 25%, NORMAL khoảng 15% đòn trên một seed cố định (kết quả lặp lại được); AI đã quyết định gạt thì gạt trúng khi đòn tới đúng lúc dự kiến.
- [ ] Ảnh chụp trong `production/qa/evidence/`: sừng sáng theo từng màu, chữ GẠT SỪNG! và PHẢN ĐÒN!, cúi đầu 18°.
- [ ] Không hồi quy: 22 check hiện có của `bash tools/run_tests.sh` vẫn qua (sau khi cập nhật các test phụ thuộc horn_startup 0,12 s); GUARD vẫn ×0,45, ×0,60 knockback, không stun; CLASH vẫn kiểm tra trước miễn nhiễm.

## GDD Update Required?

**Có** — `docs/GDD_Choi_Trau_v0.7.md` và `docs/CHANGELOG_GDD.md`, xin duyệt riêng ở bước 2
(hiện cũ/mới trước khi sửa):

- Bảng 1: thuật ngữ PARRY / Gạt sừng, Phản đòn, hitstop.
- Bảng 7 (điều khiển): phím G. Bảng 8: dòng PARRY active/recovery; HORN recovery khi hụt 0,40 s.
- Bảng 9: ba dòng PARRY (gạt trúng, gạt hụt, sườn/lưng); ví dụ cùng tick đổi theo startup 0,25 s.
- Bảng 11: tỉ lệ gạt / phản đòn theo profile.
- §2.3, §3.3: công thức `round(base × g × max(p, f, c))`; hitstop vào thứ tự tick §2.2.
- Bảng 19: sừng sáng, chữ nổi, cúi đầu 18°, hitstop.
- Phụ lục A.4: viết lại lý do startup 0,25 s. Phụ lục C: tham số mới. Bảng DEC: thêm DEC-17…21; REQ mới cho PARRY và hitstop.
- DEC-13 (sơ đồ phím): thêm "G gạt sừng".

## Câu hỏi còn mở (không chặn spec)

- Tên chính thức cho PARRY ("Gạt sừng" đang tạm).
- Khi nào hiện lời nhắc tutorial thứ 6 ở L01.
- Chữ nổi cho cả hai trâu hay chỉ đối thủ; có tùy chọn tắt trong Settings không.
- Độ trễ LAN khi bấm G phía client: đo lại khi làm REQ-N05 (50 ms).
- Ghìm ×0,45 → ×0,6 nếu playtest thấy không ai dùng G.

## Rà soát cân bằng (2026-11-11)

### Cách rà

Dùng **frame data** của game đối kháng: mỗi đòn chia ba pha **startup** (chuẩn bị, chưa
gây hit), **active** (đang gây hit), **recovery** (hồi, bị đánh được). Từ đó xét:

- **Frame advantage**: sau khi đòn trúng / bị chặn, bên nào hành động lại trước.
- **Whiff punish**: đòn hụt có hở đủ lâu để đối thủ phạt không (startup đòn phạt +
  thời gian áp sát ≤ thời gian hở).
- **Phản xạ**: người trung bình ≈ 0,25 s (≈ 16 frame); đòn có startup dưới mức đó phải
  đoán, không phản ứng kịp.
- **TTK** (số đòn để thắng) và **rủi ro / phần thưởng** (risk/reward): lựa chọn càng rủi ro
  thì thưởng càng lớn, và mỗi lựa chọn đều có cách khắc (kiểu oẳn tù tì của Sirlin).

### Bảng frame data (60 Hz)

| Đòn | Startup | Active | Recovery | Cooldown | Khí thế | Sức |
|---|---|---|---|---|---|---|
| Húc | 0,25 s (15 f) | 0,18 s (11 f) | 0,20 s trúng / 0,40 s hụt | 0,75 s | 18 | 20 |
| Hổ lao | 0 | 0,22 s (13 f) | 0,25 s (15 f) | 1,2 s | 14 | 28 |
| Gạt sừng | 0 | 0,15 s (9 f) | 0 trúng / 0,45 s hụt | 0,8 s | 0 nhận | 10 |
| Phản đòn | 0,08 s (5 f) | 0,18 s | 0,20 / 0,40 s | như Húc | 23 | 20 |
| Trúng đòn | choáng 0,30 s, bất tử 0,45 s, bật lùi ≈ 2,5 m (Ghìm: không choáng, ≈ 1,5 m) | | | | | |

### Kết quả

| # | Kiểm tra | Kết quả | Xử lý |
|---|---|---|---|
| 1 | TTK: 6 Húc / 8 Hổ lao / 13 Húc vào Ghìm / 5 Phản đòn | Hợp với trận 90 s | Giữ |
| 2 | Cú mạnh nhất khi nhân dồn hệ số: 44 | **Lệch**: một pha gần nửa thanh | Lấy max(p, f, c): tối đa 27 |
| 3 | Combo vô hạn: choáng 0,30 s < phần còn lại của đòn ≈ 0,38 s, bật lùi 2,5 m, bất tử 0,45 s | Không có combo, trúng xong về trung lập | Giữ |
| 4 | Húc vào Ghìm: bên Ghìm bị đẩy 1,5 m, không phạt kịp; mất 8 mỗi cú | Ghìm an toàn nhưng thua cuộc đua mất Khí thế, không phải lối chơi thống trị | Giữ ×0,45 |
| 5 | Startup Húc 0,20 s < phản xạ 0,25 s | **Lệch** với mục tiêu "đọc được": Gạt chỉ là đoán | 0,25 s |
| 6 | Đòn phản sau gạt: cần ≈ 0,15 + 0,22 (bước 1,1 m) + 0,08 ≈ 0,45 s, A choáng 0,40 s | **Lệch**: đòn phản hay hụt vì A bị đẩy 1,2 m | Choáng 0,50 s, giật lùi 2 m/s: cần ≈ 0,40 s < 0,50 s |
| 7 | Gạt hụt: hở 0,50 s; đối thủ đứng sẵn trong tầm cần phản xạ 0,25 + startup 0,25 = 0,50 s | **Lệch**: không phạt kịp, bấm G bừa gần như miễn phí | Recovery hụt 0,45 s (hở 0,60 s) |
| 8 | Rủi ro / phần thưởng Gạt so với Ghìm: Ghìm chắc mất 8; Gạt đúng +23 (nếu phản trúng), sai −18 → Gạt có lợi khi đoán đúng ≥ 25% (phản luôn trúng) đến ~30% (phản trúng 7/10) | Gạt đáng dùng, nhưng hụt bị phạt rõ | Giữ |
| 9 | Húc hụt: hở 0,40 s, cả chu kỳ 0,83 s; người thấy trước cần ≈ 0,55 s để phạt | Phạt được | Giữ |
| 10 | Gạt khi đang bất tử | **Lệch**: thưởng cho việc gạt đòn vốn vô hại | Xét bất tử trước |
| 11 | AI gạt sau `reaction_s` | **Lỗi**: NORMAL 0,40 s luôn muộn hơn startup | Quyết định khi đòn bắt đầu, bấm trước 0,10 s |
| 12 | AI HARD gạt 35% + phản 100% | Mỗi cú húc của người chỉ lời +3,7 | Gạt 25% (+7,8) |
| 13 | Hổ lao: 0,5 Khí thế/Sức (Húc 0,9); không startup nên không gạt bằng phản xạ | Yếu về sát thương, mạnh về áp sát và CLASH | Giữ, đo khi playtest |
| 14 | Hitstop 4 / 6 tick (67 / 100 ms) | Trong khoảng game đối kháng thường dùng | Giữ |
| 15 | Cửa sổ cam kết Húc 0,43 s (v0.7: 0,30 s) | CLASH sẽ xảy ra nhiều hơn | Đo khi playtest (REQ-G09) |
| 16 | LAN: client thấy đòn trễ ≈ 50 ms (snapshot 30 Hz + làm mượt), kể cả mạng nhanh | Client khó gạt bằng phản xạ hơn host | Đo khi làm REQ-N05; nếu lệch rõ, nới cửa sổ gạt cho client |

### Nguồn

- Frame data, frame advantage, whiff punish: Dustloop, "Reading and using frame data";
  inthirdperson.com, "Understanding frame advantage as it relates to safe on block".
- Cân bằng bằng frame data: Game Developer, "Theory: aiding asymmetrical balance with frame data".
- Phản xạ ≈ 0,25 s, đòn ≥ 16 frame phản ứng được: Infil, "On Reaction Times" (ki.infil.net/reaction.html).
- Gạt và rủi ro: bài về parry của Street Fighter III / SF6 (cửa sổ ngắn, hụt bị phạt nặng; SF6 phải giảm Drive Parry vì quá an toàn).
- Oẳn tù tì có phần thưởng khác nhau: Sirlin, "Designing Yomi" (sirlin.net/articles/designing-yomi).
