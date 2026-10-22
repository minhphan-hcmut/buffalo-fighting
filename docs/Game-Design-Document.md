---
title: "GDD SKELETON — CHỌI TRÂU: ĐẤU TRƯỜNG LỄ HỘI"
subtitle: "Tài liệu thiết kế + hợp đồng tích hợp cho team 3 người"
date: "14/10/2026"
lang: vi
---

> **Trạng thái:** DRAFT v0.1 — baseline đề xuất; chỉ chuyển sang **LOCKED v1.0** sau khi cả ba thành viên duyệt. Đây là game đối kháng hư cấu, đồ họa cách điệu, không mô phỏng chi tiết hoặc cổ vũ hành vi gây hại cho động vật ngoài đời.

# 0. Document Control — nguồn sự thật chung

**Quy tắc chống mismatch (bắt buộc):**

1. Một khái niệm chỉ có **một tên chính thức**: `HP`, `STAMINA`, `HORN`, `DASH`, `GUARD`, `RING_OUT`, `MATCH_END`.
2. Mọi hằng số gameplay chỉ khai báo trong `data/balance.json`; GDD diễn giải ý nghĩa, code không được nhân bản magic number.
3. Core code phát tín hiệu/nhận input qua contract mục 9; UI, AI và Network không được ghi trực tiếp HP/transform của trâu.
4. File thuộc module người nào thì người đó review merge; sửa API liên module cần cả A/B/C duyệt PR.
5. Một thay đổi rule phải cập nhật **GDD + config + test + changelog** cùng PR; không chỉ sửa riêng code.
6. Không tự thêm tính năng rồi coi là nghĩa vụ MVP; mọi thay đổi phải có Decision ID.

**Decision log ban đầu**

| ID | Quyết định (đề xuất khóa) | Lý do | Trạng thái |
|:--|:--|:--|:--|
| DEC-01 | 2D top-down, không 3D | Khả thi với 3 người, tập trung cảm giác húc va chạm | Proposed |
| DEC-02 | Godot 4.4.1, GDScript, Windows | Một engine, công cụ Physics/AI/LAN cùng hệ sinh thái | Proposed |
| DEC-03 | Một map nền, ba cấu hình trận PvE + LAN 1v1 | Chứng minh độ khó tăng nhưng kiểm soát asset | Proposed |
| DEC-04 | Host-authoritative, chỉ LAN trực tiếp | Network thật, tránh hạ tầng matchmaking | Proposed |
| DEC-05 | Không gore; trâu/nhân vật cách điệu | Art phù hợp phong cách lễ hội và thời gian nhóm | Proposed |

# 1. High Concept & Vision (Rubric 1.1 — 15đ)

**One-sentence pitch.** Người chơi điều khiển một chú trâu cách điệu trong đấu trường lễ hội, căn hướng di chuyển, quản lý thể lực và chọn thời điểm húc/né/đỡ để đánh bại trâu AI hoặc một người chơi LAN.

- **Genre:** 2D top-down, arena combat / action versus.
- **Nền tảng & input:** Windows, keyboard; LAN cho hai thiết bị chạy game. Độ phân giải thiết kế 1280×720, tỷ lệ 16:9.
- **Đối tượng:** Người chơi 12+ thích trận đấu ngắn, dễ học nhưng có kỹ năng căn góc và quản lý stamina.
- **USP 1:** Giao tranh phụ thuộc **góc đối đầu + vận tốc tương đối + vị trí**; không chỉ spam nút đánh.
- **USP 2:** Chiến thuật **húc–phòng thủ–hồi thể lực** với phản hồi vật lý rõ ràng.
- **USP 3:** Cùng bộ gameplay chơi được **solo với FSM AI** và **LAN PvP**.
- **Design pillars:** (P1) nhìn là hiểu va chạm; (P2) input phản hồi nhanh; (P3) mỗi trận 90 giây đủ nhịp chiến thuật; (P4) cùng một luật cho PvE và PvP.
- **Non-goals:** Online matchmaking qua Internet, tài khoản, cửa hàng, nâng cấp, nhiều giống trâu gameplay khác nhau, mô phỏng sinh học thật, máu me, ragdoll, cơ chế sinh tồn.

**Game tham chiếu (học nguyên tắc, không sao chép):** *Nidhogg* — áp lực vị trí và đấu tay đôi; *Rocket League* — va chạm và hướng tiếp cận tạo chiều sâu kỹ năng. Game này chủ động đơn giản hóa điều khiển và vật lý so với các ví dụ.

# 2. Core Loop & Luật chơi (Rubric 1.2 — 20đ)

![Sơ đồ core loop](gdd_assets/core_loop.png){ width=80% }

**REQUIREMENTS**

| ID | Luật / cơ chế | Nghiệm thu tối thiểu | Owner |
|:--|:--|:--|:--|
| REQ-G01 | Di chuyển 8 hướng bằng WASD, ngắm theo hướng di chuyển gần nhất | Điều khiển trâu ở 60 FPS, không xuyên đối thủ | A |
| REQ-G02 | `HORN` đánh về phía trước khi đủ stamina/cooldown | Chỉ trúng trong phạm vi và cung trước, trừ HP đúng 1 lần | A |
| REQ-G03 | `DASH` lao nhanh có quán tính và va chạm | Có đẩy lùi + phản hồi, trừ stamina; không xuyên vật thể | A |
| REQ-G04 | `GUARD` giảm sát thương, làm chậm di chuyển | Giữ guard giảm đúng hệ số, có tiêu hao stamina | A |
| REQ-G05 | 90 giây/trận; KO, bị hất khỏi vòng, hết giờ | Luôn chuyển RESULT; có hòa khi hết giờ bằng HP | A |
| REQ-G06 | Solo: 3 trận liên tiếp với AI tăng độ khó | Thắng mở trận kế; thua cho phép Retry cùng trận | B/C |
| REQ-G07 | LAN 2 người: host và client điều khiển hai trâu | Trạng thái HP/timer/kết quả nhất quán ở 2 bản game | B |

**Input map dùng chung**

| Hành động | Phím | Điều kiện |
|:--|:--|:--|
| MOVE | W/A/S/D | Chuyển 2 trục thành vector chuẩn hóa (đi chéo không nhanh hơn) |
| HORN | J | Khi không stunned, không guard, đủ 20 stamina, hết cooldown |
| DASH | Space | Khi không stunned, không guard, đủ 28 stamina, hết cooldown |
| GUARD | K (giữ) | Không thể kích hoạt HORN/DASH trong lúc guard |
| PAUSE | Esc | PvE pause thời gian; PvP chỉ mở menu, không pause host |
| CONFIRM / BACK | Enter / Esc | Các menu |

**Ưu tiên input khi bấm đồng thời:** `GUARD` đang giữ thì chặn HORN/DASH; nếu nhấn HORN và DASH cùng tick mà không guard thì **HORN thắng**, chỉ trừ 20 stamina và không kích hoạt DASH. DASH khóa hướng mặt tại thời điểm bắt đầu trong 0,22 giây. Cú DASH chỉ gây hit nếu tiếp xúc thân và `dot(facing, direction_to_target) ≥ cos(50°)` tại lúc va chạm.

**Luật thắng/thua ưu tiên (thống nhất máy chủ):**

1. Nếu một trâu có HP ≤ 0 sau xử lý hit: đối phương thắng `KO`.
2. Nếu vị trí tâm trâu ra khỏi giới hạn hợp lệ trong 0,20 giây liên tục: đối phương thắng `RING_OUT`.
3. Nếu hết 90 giây: trâu HP cao hơn thắng `TIME`; HP bằng nhau là `DRAW`.
4. Khi kết thúc, gameplay đóng băng, âm thanh/cảnh RESULT chạy một lần; PvE hòa tính là **chưa vượt trận**, có nút Retry.
5. Nếu hai điều kiện thắng xảy ra cùng tick, ưu tiên `KO` rồi `RING_OUT` rồi `TIME`; nếu hai trâu cùng KO trong tick → `DRAW`.

**Các trạng thái trận:** `READY → COUNTDOWN(3s) → PLAYING(90s) → RESULT`; `RESULT → RETRY/LOBBY/MENU`. Không tác động HP và không nhận input chiến đấu ngoài `PLAYING`.

![Sơ đồ trạng thái trận](gdd_assets/match_states.png){ width=82% }

# 3. Combat, Physics & Số liệu cân bằng (Rubric 1.3 + điều kiện Physics)

Các giá trị này là **target v0.1**; điều chỉnh sau playtest phải ghi Change Request. Đơn vị khoảng cách/tốc độ dùng pixel (px), thời gian dùng giây (s). Cả 2 trâu dùng cùng stats; AI khó hơn nhờ quyết định tốt hơn, không gian lận HP/damage.

| `data/balance.json` key | Giá trị v0.1 | Mô tả |
|:--|--:|:--|
| `hp_max` | 100 | Máu tối đa |
| `stamina_max` | 100 | Thể lực tối đa |
| `walk_speed` | 210 px/s | Tốc độ đi bộ trên nền khô |
| `acceleration` | 1000 px/s² | Gia tốc đạt tốc độ mong muốn |
| `deceleration` | 1300 px/s² | Hãm khi thả phím |
| `buffalo_radius` | 24 px | Bán kính va chạm thân |
| `horn_range` | 72 px | Khoảng cách tâm tối đa có thể trúng |
| `horn_half_angle` | 40° | Cung trước tính từ hướng mặt |
| `horn_damage` | 18 HP | Một lần trúng HORN |
| `horn_cost` | 20 | Stamina tiêu hao HORN |
| `horn_active_s` | 0.18 s | Cửa sổ nhận hit |
| `horn_cooldown_s` | 0.75 s | Hồi chiêu |
| `dash_speed` | 390 px/s | Vận tốc lao đầu tối đa |
| `dash_active_s` | 0.22 s | Thời gian DASH |
| `dash_damage` | 14 HP | Sát thương khi DASH chạm trực diện |
| `dash_cost` | 28 | Stamina tiêu hao DASH |
| `dash_cooldown_s` | 1.20 s | Hồi chiêu |
| `guard_damage_multiplier` | 0.45 | Nhận 45% sát thương gốc |
| `guard_speed_multiplier` | 0.55 | Tốc độ khi guard |
| `guard_stamina_per_s` | 12 | Hao thể lực khi guard |
| `stamina_regen_per_s` | 18 | Hồi stamina khi không dùng kỹ năng |
| `stamina_regen_delay_s` | 0.75 | Trễ hồi sau tiêu stamina |
| `hit_invulnerability_s` | 0.45 | Chống trúng hit liên hoàn |
| `knockback_speed` | 200 px/s | Xung lực đẩy lùi tức thời |
| `arena_radius` | 295 px | Bán kính đường biên vẽ |
| `match_duration_s` | 90 s | Thời gian trận |

**Công thức bắt buộc để tránh lệch code:**

- `move_dir = raw_input.normalized()` khi độ dài > 1; `target_velocity = move_dir * walk_speed * terrain_factor * guard_factor`. `velocity = move_toward(velocity, target_velocity, acceleration * dt)`; khi không input dùng `deceleration * dt`.
- HORN hợp lệ khi `distance(attacker,target) ≤ horn_range`, `dot(facing, direction_to_target) ≥ cos(40°)` và attack đang active; hitbox chỉ gây một hit cho mỗi target trong cùng action.
- DASH gây hit khi đang active và có tiếp xúc vật lý ở phía trước; nếu đồng thời đủ điều kiện HORN thì **chỉ lấy HORN** (không cộng dồn damage).
- `damage_taken = round(base_damage * (guard ? 0.45 : 1.0))`; máu được clamp `[0,100]`. Hit bị miễn nhiễm trong 0,45s sau khi nhận hit hợp lệ.
- Khi trúng hit: `velocity += direction_away * knockback_speed`; guard giảm knockback còn 60%; xử lý va chạm qua `CharacterBody2D.move_and_slide()`.
- Stamina = clamp(stamina − cost/drain + regen, 0,100); **không hồi** khi guard hoặc trong 0,75s sau khi tiêu; nếu stamina = 0, guard tự hủy.
- `RING_OUT` xảy ra khi `distance(buffalo_center, arena_center) > arena_radius − buffalo_radius` kéo dài ≥ 0,20s. Biên vòng là luật, **không phải tường cản trâu**.
- `terrain_factor`: đất thường = 1,00; vùng bùn = 0,80 (áp dụng vận tốc tối đa, không đổi sát thương). Physics chạy `_physics_process` 60Hz ở host/local.

**Tránh nhập nhằng:** HORN không phải đánh từ xa; phải lọt cung trước. DASH không luôn gây damage — phải va chạm trực diện. Không cộng stack HORN + DASH. Trâu không có animation gameplay khác nhau làm thay đổi hitbox. Mức độ ngẫu nhiên combat = **0** để dễ test và đồng bộ.

# 4. AI, Network & Kiến trúc trận

## 4.1 AI — Finite State Machine (REQ-AI01)

AI đưa ra cùng loại `InputFrame` như người chơi; tuyệt đối không gọi thẳng hàm gây sát thương hay chỉnh vị trí. Các state: `APPROACH` (tiếp cận), `STRAFE` (đổi góc), `ATTACK` (căn rồi HORN/DASH), `GUARD` (đỡ đòn), `RECOVER` (giữ khoảng cách để hồi stamina). AI dùng vị trí/HP/stamina mà cả người chơi có thể nhìn thấy; không nhìn input sắp tới của người chơi.

| Profile | Khoảng phản ứng | Quy tắc nổi bật | Trận |
|:--|:--|:--|:--|
| `EASY` | 0.65 s | Chủ yếu approach; tấn công khi dưới 100px và đủ stamina | 1 |
| `NORMAL` | 0.40 s | Strafe khi bị đối đầu, guard khi người chơi dash trong tầm | 2 |
| `HARD` | 0.25 s | Chủ động giữ góc, chọn dash khi cách 100–170px, biết hồi stamina | 3 |

Hạn chế AI: tối đa một quyết định lớn trong mỗi nhịp phản ứng, cooldown và stamina y như player. `ai_seed` cố định cho replay kiểm thử; không dùng ML, không yêu cầu Internet. **Acceptance:** bot có thể kết thúc trận, không đứng yên >5s khi đang PLAYING và còn khả năng di chuyển.

## 4.2 Network — ENet LAN 1v1 (REQ-N01..04)

MVP hỗ trợ **LAN trực tiếp**, host mở phòng trên một port cấu hình (mặc định 7777), client nhập IPv4 LAN để Join. Không có matchmaking/relay/NAT traversal/server ngoài; nếu 2 máy không chung LAN thì không cam kết kết nối được. Bản Windows có đủ màn Host/Join, thông báo đang kết nối, lỗi kết nối, ngắt kết nối.

- **Host-authoritative:** máy host tính vật lý, damage, AI (chỉ ở solo), timer, winner. Client chỉ gửi input và hiển thị snapshot. Không mô phỏng combat xác quyết trên client.
- **Ổn định API:** B gửi `move + guard` qua gói không bảo đảm thứ tự ở ~20 Hz; sự kiện bấm `HORN`/`DASH` qua RPC reliable, có `seq` tăng để host bỏ gói action trùng; host kiểm tra stamina/cooldown.
- **Replication:** host phát `MatchSnapshot` ~15 Hz; client nội suy vị trí để hình ảnh mượt, nhưng HP/RESULT nhận từ host (các thay đổi trạng thái quan trọng phát reliable).
- **Disconnect:** nếu khách thoát trong trận, cả hai được chuyển sang màn thông báo `CONNECTION_LOST`/Result bị hủy; không trao thắng mặc định. Host có thể về Lobby rồi chơi trận mới.
- **Bảo mật tối thiểu:** peer chỉ có quyền điều khiển slot được gán, không tin HP/vị trí/timer gửi từ client; lobby giới hạn 2 peer, timeout kết nối 10s.

**Test network bắt buộc:** 2 instance trên 2 máy LAN, Host/Join thành công, cả hai nhìn thấy di chuyển, cùng công bố đúng winner, client mất kết nối không soft-lock. Đừng hứa đồng bộ vật lý deterministic trên 2 máy; chỉ host là nguồn sự thật.

# 5. Màn chơi, tiến trình và nội dung (Rubric 1.4)

**MVP dùng một scene đấu trường tái sử dụng**, với ba cấu hình `level_id` khác nhau; mức độ khó đến từ AI và địa hình bùn. Trong Solo, thắng mở trận tiếp theo; thua hoặc hòa cho phép Replay cùng trận. Không có tiền tệ/shop/upgrade — **kinh tế là N/A**; stamina là tài nguyên chiến đấu cần cân bằng.

| Level ID | Tên trận | Mục tiêu / tiến trình | Arena config | AI |
|:--|:--|:--|:--|:--|
| L01 | Khai Hội | Học MOVE → HORN → DASH → GUARD bằng lời nhắc | Đất khô, không bùn | EASY |
| L02 | Bùn Lầy | Quản lý stamina và né vùng giảm tốc | 1 vùng bùn | NORMAL |
| L03 | Chung Kết | Căn góc húc và phản công trên sân nhiều vùng chậm | 2 vùng bùn | HARD |

![Sơ đồ đấu trường và điểm xuất phát](gdd_assets/arena_layout.png){ width=82% }

**Quy chuẩn layout:** World design 1280×720; tâm đấu trường `(640,360)` px; bán kính 295px; Spawn slot 1 `(520,360)` hướng phải, slot 2 `(760,360)` hướng trái. Bùn A tâm `(550,270)`, r=65px; bùn B tâm `(730,450)`, r=65px. L01 không bật bùn, L02 bật A, L03 bật A+B. Hai trâu bắt đầu không chồng collider, mọi vùng nằm trong vòng. Camera cố định toàn sân; không cuộn map.

**Pacing mục tiêu:** Menu/chọn chế độ ≤20s; tutorial gợi ý ≤30s; một trận ≤90s + 3s đếm ngược + ≤12s result. Hướng dẫn hiển thị theo ngữ cảnh, không khóa gameplay chờ đủ thao tác; người chơi có thể tự khám phá. Tổng Solo thông thường ~5–10 phút bao gồm retry (ước tính, cần playtest).

**Inventory content (MVP):** 1 prefab trâu gameplay × 2 skin màu khác; 1 map nền × 3 cấu hình; 2 vùng bùn tối đa; 4 action; 3 cấu hình AI; 6 trạng thái UI chính; 1 track nhạc nền; 6+ hiệu ứng âm thanh. Không có vật phẩm nhặt trên sân, NPC người dẫn chuyện hay tuyến truyện dài.

# 6. Bối cảnh, nhân vật và cách kể chuyện (Rubric 1.5)

Bối cảnh **lễ hội giả tưởng lấy cảm hứng từ không khí sân đình Việt Nam**: cờ hội, trống và khán giả minh họa cách điệu. Người chơi điều khiển “Trâu Đỏ” đấu với “Trâu Xanh”. Cả hai có stats như nhau; màu chỉ giúp phân biệt slot và không mang giá trị sức mạnh. Hành trình Solo đi từ trận Khai Hội tới Chung Kết, truyền tải bằng bảng giới thiệu trận, lời bình ngắn trước trận và màn trao danh hiệu sau khi thắng L03.

**Narrative delivery:** Mỗi trận có một câu giới thiệu, tên đối thủ và nhãn độ khó; không có cutscene dài, đối thoại phân nhánh hay hệ thống quest. Tên/biểu tượng văn hóa chỉ dùng ở mức hư cấu; không tuyên bố đây là mô phỏng chính xác nghi thức hay luật của lễ hội có thật. Hiệu ứng va chạm hoạt hình, không hiển thị máu hoặc thương tích chi tiết.

# 7. Art, Audio, UI/UX (Rubric 1.6)

## 7.1 Style guide

- Phong cách: 2D top-down, stylized cartoon, silhouette thân và sừng đọc được từ xa; animation idle/walk/dash/hit/guard/victory.
- Palette đề xuất: đất nâu `#8A5A3B`, đỏ gạch `#B6453B`, xanh chàm `#33546D`, vàng hội `#E8BC65`, nền giấy `#F2E6CF`.
- Tương phản: Trâu Đỏ có viền sáng 2px, Trâu Xanh viền tối 2px; UI kết hợp icon + chữ, không chỉ dùng màu.
- Feedback phải có: hoạt ảnh giật ngắn lúc húc, bụi, flash hit, âm thanh impact; camera shake nhẹ có thể tắt trong Settings.
- Moodboard cần bổ sung: 4–6 hình tham khảo có link, tác giả, license (gắn ở Phụ lục, **TBD** trước GDD v1.0).

## 7.2 Screen flow & mockup chữ

`BOOT → MAIN MENU → [SOLO / LAN / SETTINGS / QUIT]`

`SOLO → LEVEL INTRO → COUNTDOWN → MATCH → RESULT → [NEXT / RETRY / MENU]`

`LAN → HOST/JOIN → LOBBY → COUNTDOWN → MATCH → RESULT → [REMATCH / LOBBY / MENU]`

```text
┌──────────────────── HUD 1280×720 ────────────────────────┐
│ [ĐỎ] HP ███████░░  STA █████░  01:12  HP ██████░░ [XANH] │
│                                                           │
│                 [    ARENA / TWO BUFFALO    ]             │
│                                                           │
│ [WASD] Di chuyển  [J] Húc  [SPACE] Lao  [K] Đỡ        │
└───────────────────────────────────────────────────────────┘
```

HUD game dùng health/stamina bars cho cả hai; countdown và kết quả ở giữa; tutorial prompt ở cạnh dưới. Pause menu PvE: Resume / Restart / Settings / Main Menu. PvP menu: Resume View / Leave Match / Settings (không pause trận host). Settings MVP: Master, Music, SFX (0–100%), fullscreen toggle, camera shake toggle; phím cố định. Font có dấu tiếng Việt.

## 7.3 Asset & audio checklist

| Nhóm | Asset tối thiểu | Owner |
|:--|:--|:--|
| Character | 2 buffalo skins + idle, walk, dash, horn, guard, hit, win | C |
| Environment | Ground, ring border, mud decal, banner, audience silhouettes | C |
| UI | Buttons, bars, countdown, win/lose/draw, connection status | C |
| VFX | Impact flash, dust, dash trail, ring-out indicator | C |
| SFX | Menu click, horn swing, horn hit, dash, guard hit, crowd cheer, countdown | C |
| Music | Menu/arena loop (có thể dùng 1 track nếu scope thiếu) | C |

Nguồn asset ngoài: bắt buộc `docs/ASSET_CREDITS.csv` với `asset_id, file_path, author, source_url, license, modification, ai_generated`; asset AI tạo cũng phải khai báo. Không sử dụng asset chưa rõ quyền sử dụng.

# 8. Technical Design, MVP và phi chức năng (Rubric 1.7, A02 2.5–2.7)

**Engine baseline:** Godot **4.4.1** với GDScript và ENet Multiplayer API; cần xác minh cả 3 máy cài cùng build và khóa phiên bản trong README khi ký GDD v1.0. Đây là lựa chọn thiết kế, không có yêu cầu phải dùng phiên bản mới nhất.

**Các scene (contract đường dẫn):**

```text
res://scenes/MainMenu.tscn
res://scenes/ModeSelect.tscn
res://scenes/Lobby.tscn
res://scenes/Arena.tscn
res://scenes/Result.tscn
res://scenes/Buffalo.tscn
res://scripts/core/              # A: physics, combat, rules, events
res://scripts/ai/                # B: bot FSM
res://scripts/network/           # B: host/client/RPC
res://scripts/ui/                # C: menus, HUD, screens
res://data/balance.json          # A owns; mọi module chỉ đọc
res://data/levels.json           # C owns; A/B read
res://data/ai_profiles.json      # B owns; A/C read
res://docs/GDD.md                # shared source
res://docs/CHANGELOG_GDD.md
res://docs/ASSET_CREDITS.csv
res://tests/                     # mỗi owner thêm test của module
```

**Single-player:** `GameMode.SOLO` dùng AI làm nguồn input slot 2; local physics/combat ở cùng máy. **LAN:** `GameMode.LAN` dùng input từ client slot 2; chỉ host xử lý authoritative world.

**Target chất lượng:** 60 FPS tại 1280×720 trên máy Windows mục tiêu [**chưa điền cấu hình cụ thể**]; không crash, không lỗi kẹt scene, thời gian từ Main Menu đến đấu được đo trong playtest. Mỗi kết quả hiển thị được sau ≤2s từ event kết thúc. Không có save game lâu dài: progress Solo trong phiên; restart game trở về L01 (được thông báo rõ trong UI). Không hỗ trợ controller/mobile trong MVP.

## 8.1 MVP vs Optional vs Out

| MUST — chấm theo GDD | SHOULD — thêm khi ổn | OUT — không hứa |
|:--|:--|:--|
| Solo L01–L03, 4 action, HUD/Result | 2–3 skin mỹ thuật thêm | Online matchmaking |
| Physics hit/collision/ring-out | Animation nâng cấp | Shop, vật phẩm, nâng cấp |
| 3 AI FSM profiles, LAN Host/Join 1v1 | VFX nâng cấp | Rank, tài khoản, cloud save |
| Tutorial ngữ cảnh, pause/settings cơ bản | Replay cuối trận | Thêm boss / map lớn |
| 1 arena × 3 cấu hình, audio và README | Controller | Multiplayer >2 |

**Thứ tự giảm scope nếu bị trễ:** (1) cắt skin, decor, VFX phụ; (2) cắt nhạc bổ sung; (3) giảm độ phức tạp logic AI HARD, nhưng giữ 3 profile; (4) dùng cùng layout với 2 vùng bùn bật/tắt; **không được tự cắt** physics, AI, Network thật, full core loop hay README/build. Nếu buộc cắt một MUST, phải mở Change Request và ghi sai khác A01/A02, vì có rủi ro trừ điểm.

# 9. Hợp đồng tích hợp liên module — ANTI-MISMATCH

Đây là phần **chuẩn kỹ thuật nhóm buộc tuân theo**. Không merge bất kỳ PR nào phá contract chưa được chấp thuận.

## 9.1 Data contracts

**`InputFrame`** (do local input, AI hoặc Network adapter tạo):

```text
player_slot: int                 # chỉ 1 hoặc 2
move: Vector2                   # hai trục, normalize length <= 1
horn_pressed: bool              # cạnh nhấn, không phải giữ
 dash_pressed: bool             # cạnh nhấn, không phải giữ
 guard_held: bool               # trạng thái giữ
seq: int                        # tăng đơn điệu theo player_slot
```

**`MatchConfig`** (từ levels + balance):

```text
level_id: StringName            # L01 | L02 | L03 | LAN01
mode: StringName                # SOLO | LAN
ai_profile: StringName          # EASY | NORMAL | HARD | NONE
mud_zones: Array[StringName]    # [] | [A] | [A, B]
duration_s: float               # 90
```

**`MatchSnapshot`** (host/local core xuất cho HUD và network):

```text
tick: int
phase: StringName               # READY | COUNTDOWN | PLAYING | RESULT
remaining_ms: int
players: [
 {slot:int, position:Vector2, facing:Vector2,
  hp:int, stamina:float, action:StringName}
]
winner_slot: int                # 0 nếu DRAW hoặc chưa xong
end_reason: StringName          # KO | RING_OUT | TIME | DRAW | NONE
```

**Signals chuẩn từ `MatchController`:**

```text
match_started(level_id)
combat_event(event_name, source_slot, target_slot, value)
resource_changed(slot, hp, stamina)
match_ended(winner_slot, end_reason)
```

- A sở hữu `MatchController`, phát signal; C/UI subscribe để vẽ HUD và result, **không sửa HP**.
- B/AI gọi `submit_input(InputFrame)` cho slot 2; B/Network đưa input từ client vào `submit_input` sau validate peer/slot. Không gọi `apply_damage` ngoài core.
- `end_reason` và enum name viết chính xác như trên, dùng kiểu StringName/enums ánh xạ; không đặt tên riêng theo ý từng người.
- Trạng thái authoritative được A trả qua `get_snapshot()`; client B dùng snapshot để cập nhật view, không chạy lại va chạm để quyết định winner.

## 9.2 Ownership & điểm bàn giao

| Interface / File | Producer → Consumer | Điều kiện ký nhận |
|:--|:--|:--|
| `Buffalo.tscn`, `MatchController` | A → B,C | C spawn được, B gửi InputFrame được; sample scene chạy |
| `AIController.gd` | B → A,C | Tạo InputFrame cho slot 2, không lỗi khi match kết thúc |
| `NetworkManager.gd` | B → A,C | Host/Join và snapshot hoạt động với 2 instance LAN |
| `Arena.tscn`, `HUD.gd`, menu | C → A,B | Node paths theo contract, subscribe signal, hiển thị đúng slot |
| `levels.json` | C → A,B | L01/L02/L03/LAN01 hợp lệ, bùn bật đúng cấu hình |
| `ai_profiles.json` | B → A,C | EASY/NORMAL/HARD đúng nhịp phản ứng, không sửa stat trâu |
| `balance.json` | A → B,C | Một nơi duy nhất chứa chỉ số gameplay |

**Định nghĩa API ổn định:** Một module độc lập phải có scene harness/mock cho module chưa xong. Ví dụ B chạy AI với `MockMatchSnapshot`, C chạy HUD với `MockCombatEvent`, A chạy combat với input ảo. Không để phụ thuộc scene chính mới test được.

## 9.3 Quy trình Git & change management

- Branch: `main` chỉ giữ build chạy; `develop` tích hợp; `feature/A-...`, `feature/B-...`, `feature/C-...` theo người/module.
- Nhịp làm việc: ngày đầu thống nhất DTO/enum/path; PR nhỏ tối thiểu 2–3 lần/tuần/người; integration ít nhất 2 lần/tuần; mỗi PR phải chạy smoke test.
- PR template: `Mã REQ | thay đổi | contract ảnh hưởng? | ảnh/video test | cách kiểm tra | reviewer`.
- Thay API công khai: tạo `CR-###` với **lý do, trước/sau, ảnh hưởng A/B/C, test cập nhật, người phê duyệt**.
- Tài liệu cập nhật: `CHANGELOG_GDD.md` có cột Date, Version, CR ID, Before, After, Reason, Test impact, Approved by.
- No merge khi thiếu: build chạy, không xung đột input/signal/node paths, không có thay đổi MUST không được duyệt.

## 9.4 Ma trận rủi ro tích hợp

| Rủi ro | Triệu chứng | Cách ngăn |
|:--|:--|:--|
| Khác tên `HORN` / `ATTACK` | AI bấm không có tác dụng | Một InputFrame chuẩn, test gửi action giả |
| UI đọc HP riêng | 2 máy khác thanh máu | Chỉ snapshot/resource signal từ host |
| Cùng sửa `Arena.tscn` | Git scene conflict | C sở hữu scene, A/B chỉ sửa prefab/script của mình |
| Network cho client tự tính hit | Winner lệch trên hai máy | Host authoritative, game state chỉ ở host |
| Chỉ làm AI rồi thiếu network | Không đạt điều kiện môn | Demo LAN ngay từ milestone giữa kỳ |
| Scope nở vô hạn | Không có build cuối kỳ | Giữ MUST nhỏ, bỏ SHOULD trước |

# 10. Production Plan — Team 3 người

**Timeline mẫu 6 tuần**; khi biết lịch nộp thực tế, cả nhóm thay bằng ngày chính xác và đóng dấu version. Không coi các ngày tương đối này là hạn do giảng viên quy định.

| Tuần | A — Core/Physics | B — AI/Network | C — UI/Content/QA | Demo gate |
|:--|:--|:--|:--|:--|
| W1 | InputFrame, buffalo move, stats | Bot mock, host/join skeleton | Arena greybox, HUD mock, GDD lock | Dự án cùng chạy, không lỗi import |
| W2 | Hit, dash, guard, HP, ring-out | FSM EASY; input peer slot | Main menu, result, tutorial | 1 trận solo hoàn chỉnh với asset placeholder |
| W3 | MatchController, signal, test | LAN 2 instance + snapshot | 3 layout config, art cơ bản | Vertical slice AI + LAN được |
| W4 | Cân bằng hit, test edge cases | NORMAL/HARD, disconnect | Animation, VFX, SFX | MVP tất cả MUST chạy từ menu đến result |
| W5 | Fix combat bugs/performance | Fix network latency & FSM | Playtest người ngoài, UI polish | Báo cáo playtest + chốt tuning |
| W6 | Regression, technical explanation | LAN demo script/README cùng nhóm | Build/export, credits, slides demo | Build Release + README + GDD changelog |

**Definition of Done chung cho mỗi REQ:** (1) có code/asset đúng owner; (2) test chấp nhận pass; (3) không phá interface; (4) có commit/PR; (5) có evidence (ảnh/video hoặc log); (6) cập nhật GDD/CHANGELOG nếu khác v1.0.

# 11. QA, Playtest, Demo & điều kiện nộp (Rubric A02)

**Test cases tối thiểu (đánh dấu P/F + link evidence trong `docs/TEST_REPORT.md`):**

| Test ID | Scenario | Expected result |
|:--|:--|:--|
| T01 | MOVE chéo | Không nhanh hơn MOVE ngang |
| T02 | HORN ngoài cung 40° | Không trừ HP |
| T03 | HORN trúng trong tầm | −18 HP đúng 1 lần khi không guard |
| T04 | GUARD khi trúng HORN | Nhận round(18×0.45)=8 HP |
| T05 | DASH stamina <28 | Không kích hoạt; không âm stamina |
| T06 | Nhấn HORN + DASH cùng tick | Chỉ kích hoạt HORN, trừ 20 stamina, không cộng damage |
| T07 | Ra ngoài vòng >0,20s | Kết thúc `RING_OUT` |
| T08 | Timer = 0, HP khác nhau | `TIME` với winner đúng |
| T09 | Timer = 0, HP bằng nhau | `DRAW`; solo cho Retry |
| T10 | L01→L02→L03 | Thắng chuyển đúng level; bùn/AI đúng config |
| T11 | Host/Join LAN trên 2 máy | Cả hai điều khiển và hiển thị cùng winner |
| T12 | Client ngắt mạng khi PLAYING | Không soft-lock; hiện thông báo / về lobby |
| T13 | Settings volume và pause solo | Âm lượng đổi, PvE timer dừng khi pause |
| T14 | Build Windows mới tải về | Chạy theo README, không cần mở editor |
| T15 | FPS trong 3 phút chơi thử | Target 60 FPS; ghi máy và chỉ số thực |
| T16 | Asset credit + AI disclosure | Mọi asset ngoài/AI có nguồn và quyền sử dụng |

**Playtest ngoài nhóm:** ít nhất 3 người (mục tiêu, không phải số bắt buộc rubric). Ghi thời gian hiểu controls, tỷ lệ thắng L01/L02/L03, số lần spam đòn, lỗi va chạm, cảm nhận hit, lỗi LAN, FPS, thay đổi trước/sau. Chỉ số khởi điểm đề xuất: ≥80% hiểu mục tiêu trong 30s; ≥70% người chơi thấy rõ nguyên nhân mất HP; ≥90% trận kết thúc bình thường; LAN 10/10 trận test không lệch winner. Đây là tiêu chuẩn nhóm tự đề xuất, chưa đo thực tế.

**Demo script 4–6 phút:** mở menu → Solo L01 giới thiệu input → thể hiện guard/dash/horn/KO hoặc ring-out → chuyển L02 (bùn) → khởi chạy 2 bản game LAN → kết thúc trận/Result → giải thích kiến trúc AI, Physics, Network. Ba người chuẩn bị trả lời phần do mình sở hữu và hiểu luồng dữ liệu liên module.

**Submission gate:** xuất `builds/Windows/` + `README.md` (engine/version, cách chạy Solo, Host/Join LAN, phím, lỗi phổ biến, cấu hình test), `docs/GDD.md`, `CHANGELOG_GDD.md`, `TEST_REPORT.md`, `ASSET_CREDITS.csv`, `AI_USAGE.md`, mã nguồn, lịch sử Git. **Không có build chạy theo README → A02 tối đa 40/100** theo rubric; ưu tiên bảo đảm build sớm.

# 12. Rubric Traceability — GDD → Test → Người chịu trách nhiệm

| Rubric | Điểm | Vị trí trong GDD | Evidence A02 |
|:--|--:|:--|:--|
| A01 1.1 Vision | 15 | §1 | Pitch, USP, reference analysis |
| A01 1.2 Core gameplay | 20 | §2–3 | Sơ đồ loop, controls, T01–T09 |
| A01 1.3 Balance | 15 | §3–4 | Config, công thức, báo cáo tuning |
| A01 1.4 Level/content | 15 | §5 | Arena sketch, level config, T10 |
| A01 1.5 World/characters | 10 | §6 | Intro, hai nhân vật, ending progression |
| A01 1.6 Art/Audio/UI | 10 | §7 | Style guide, mockup, asset/SFX list |
| A01 1.7 Technical/Scope | 10 | §8–10 | Module plan, MVP/owner, milestones |
| A01 1.8 Consistency | 5 | §0, §9, §12 | Decision log, single source, CR |
| A02 2.1 Complete vs GDD | 20 | §8, §11 | MUST checklist, full-loop build |
| A02 2.2 Feel | 20 | §2–3, §7 | Playtest hit/input feedback |
| A02 2.3 Levels/balance | 10 | §3, §5, §11 | 3 trận, tuning log |
| A02 2.4 Art/audio/UI | 10 | §7 | HUD/menu/result/music/SFX |
| A02 2.5 Code/physics | 15 | §3–4, §8–9 | State machine, vector/collision, Git |
| A02 2.6 Stability/FPS | 10 | §8, §11 | Crash test, soft-lock, FPS report |
| A02 2.7 Build/docs | 5 | §11 | Windows build, README, credits |
| A02 2.8 Playtest/demo | 10 | §10–11 | Người ngoài nhóm, demo, vấn đáp |

**Tính điểm môn:** `Tổng = 0.60 × A01 + 0.40 × A02` (mỗi bài trên 100 trước quy đổi). A02 nghiệm thu theo GDD v1.0 và các CR hợp lệ; không đánh đồng mô tả SHOULD/OUT với MVP cam kết.

# 13. Checklist chốt GDD v1.0 và lịch sử thay đổi

- CHƯA XÁC NHẬN: Cả ba người xác nhận DEC-01..05 và tên dự án.
- CHƯA XÁC NHẬN: Điền thông tin nhóm, hạn nộp, máy benchmark, link repo.
- CHƯA XÁC NHẬN: Khóa engine chính xác; mỗi máy mở được demo giống nhau.
- CHƯA XÁC NHẬN: Đồng ý InputFrame, MatchSnapshot, Signal names và scene paths.
- CHƯA XÁC NHẬN: Chốt số liệu và logic ưu tiên thắng-thua; tạo `balance.json` theo GDD.
- CHƯA XÁC NHẬN: Vẽ hoặc chụp lại HUD mockup/moodboard với nguồn rõ ràng.
- CHƯA XÁC NHẬN: Có test harness cho A, B, C và build thử W1/W2.
- CHƯA XÁC NHẬN: Không còn TBD nào ảnh hưởng đến MUST hoặc API.
- CHƯA XÁC NHẬN: Tạo README, Asset Credits, AI Usage và changelog trước A02.

**Changelog GDD**

| Version | Ngày | Thay đổi | Lý do | Phê duyệt |
|:--|:--|:--|:--|:--|
| 0.1 | 14/10/2026 | Tạo skeleton, scope, rule, API, phân công đề xuất | Chuẩn bị A01 + phát triển song song A02 | Chưa ký |
| 1.0 | [TBD] | Khóa thiết kế MVP sau review | Ngăn mismatch | A/B/C ký |

**Các quyết định cần kiểm chứng đầu tiên:** (a) LAN được giảng viên chấp nhận cho điều kiện “Network” hay cần kết nối Internet? (b) Có bắt buộc nộp đúng engine/format khác không? (c) Timeline thực tế bao nhiêu tuần? Những điểm này **không được rubric đã cung cấp quy định chi tiết**, nên baseline LAN/Godot ở trên là đề xuất triển khai, cần xác nhận với giảng viên khi thuận tiện. Không để các TBD này làm ngưng prototype physics/AI.

---


