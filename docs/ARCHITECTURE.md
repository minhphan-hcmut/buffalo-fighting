# Kiến trúc code

Tài liệu này giúp người mới (và AI agent của họ) đọc hiểu repo trong 10 phút: code nằm
ở đâu, một trận chạy ra sao, và muốn sửa một thứ thì mở file nào. Luật chơi chi tiết ở
GDD `docs/GDD_Choi_Trau_v0.7.md`; quy ước code, test, commit ở `AGENTS.md`.

## Năm ý cần nhớ

1. **Code tách hai lớp.** Lớp *mô phỏng* (gameplay) quyết định trận đấu. Lớp *trình bày*
   (hình, tiếng, chữ, camera) chỉ đọc trạng thái và nghe sự kiện, không bao giờ đổi kết quả.
2. **Mọi input đi qua `InputFrame`.** Bàn phím, AI và máy client LAN đều tạo cùng một kiểu
   `InputFrame`, nên mô phỏng không cần biết ai đang điều khiển.
3. **`MatchController.simulate_tick()` là bước gameplay duy nhất**, 60 lần/giây. Trên LAN chỉ
   host chạy nó; client nhận snapshot và hiển thị lại.
4. **Mọi con số chỉnh được nằm trong `data/`**, đọc qua `GameBalance`. Không ghi số
   trực tiếp trong script.
5. **Mọi thứ nhìn thấy đều dựng bằng code** từ khối có sẵn của Godot (`LowPoly`,
   `ArenaBuilder`, `ArenaDressing`, `CeremonyDiorama`). Chỉ có model trâu, vân đất của sân và
   âm thanh là asset nhập vào.

## Một trận chạy như thế nào

```text
 Bàn phím ─ MatchInput ─┐
 AI ─────── AIController ┼─► InputFrame ─► MatchController.simulate_tick()  (60 Hz)
 Client LAN ─ MatchNetwork┘                  │
                                             ├─ Buffalo ×2       trạng thái, di chuyển, SPIRIT/STAMINA
                                             ├─ CombatResolver   húc, hổ lao, ghìm, gạt sừng, phản đòn
                                             ├─ ClashSystem      khóa sừng (đẩy, móc, nhả)
                                             ├─ ArenaBounds      giới hạn sân, ép rào, bùn
                                             └─ _check_match_end FLEE / TIME / LOT
                                             │
                          signal combat_event(tên, nguồn, đích, giá trị)
                                             │
     ┌──────────────┬──────────────┬─────────┴────┬──────────────┬──────────────┐
  BuffaloFeedback  MatchVFX     MatchAudio       HUD        FollowCamera   (lớp trình bày)
  chữ nổi, sừng    bụi, tia      tiếng           thanh, giờ,  rung, zoom
  phát sáng        lửa, vòng     theo sự kiện    tutorial     khi khóa sừng
```

Khi một đòn trúng, mô phỏng phát `combat_event` và đặt **hitstop** (dừng hình 4–6 tick).
Trong lúc dừng hình, input vẫn được ghi vào bộ đệm của trâu nên không mất phím.

**LAN:** host chạy toàn bộ mô phỏng và gửi snapshot 30 lần/giây (`MatchNetwork`). Sự kiện
combat được gửi riêng theo kênh tin cậy, nên client hiện cùng chữ, hiệu ứng và tiếng
như host. Client chỉ gửi input; nó không tự tính luật.

**Màn chơi Solo:** `main_menu.gd` → Phần Lễ mở hội (`CeremonyView`) → `arena.tscn`
(Vòng loại L01) → `MatchOutro` (trâu thua lui khỏi sới) → bảng kết quả → trận tiếp theo
(L02, L03) → thắng chung kết thì Phần Lễ khép hội. Tiến trình lưu trong `SessionState`.

## Bản đồ file

### `scripts/core/`: mô phỏng (gameplay)

| File | Việc của nó |
|---|---|
| `match_controller.gd` | Gốc của scene `arena.tscn`: phase (đếm ngược, đấu, kết quả), đồng hồ, tạm dừng, luật thắng, hitstop, tạo các module khác. |
| `buffalo.gd` | Một con trâu: máy trạng thái hành động (`State`), di chuyển, SPIRIT/STAMINA, bộ đệm input. |
| `combat_resolver.gd` | Kiểm tra trúng đòn và tính khí thế mất, đẩy lùi. Thứ tự: bất tử → gạt sừng → ghìm → trúng; đánh sườn/lưng ×1,25. |
| `clash_system.gd` | Khóa sừng: thanh kéo co, móc, nhả, ai thua thì mất khí thế. |
| `arena_bounds.gd` | Hình học sân bầu dục: va chạm thân/đầu, giới hạn rào, trạng thái bị ép rào, vùng bùn. |
| `input_frame.gd` | Một tick ý định của một con trâu. |
| `match_input.gd` | Đọc bàn phím/chuột thành `InputFrame`. |
| `match_network.gd` | Nối `MatchController` với LAN: gửi/nhận input, snapshot, sự kiện. |
| `session_state.gd` | Dữ liệu sống qua các lần đổi scene: chế độ, màn hiện tại, kết quả trước. |
| `game_balance.gd`, `data_file.gd` | Đọc số từ `data/`. |
| `yaw_basis.gd` | Vector trước/phải theo góc quay. |

### `scripts/core/`: trình bày (không đổi kết quả trận)

| File | Việc của nó |
|---|---|
| `buffalo_animator.gd` | Chuyển động thủ tục cho model trâu chưa có rig: bước chân, húc, lao, khóa sừng. `make_matte()` bỏ ánh kim loại của model và nhuộm da xám đá. |
| `buffalo_feedback.gd` | Chữ nổi trên đầu trâu ("HÚC", "GẠT SỪNG!") và màu sừng phát sáng; shader ở `assets/shaders/horn_glow.gdshader`. |
| `match_vfx.gd` | Hạt hiệu ứng: chớp sáng khi trúng, tia lửa ghìm/gạt, bụi, vòng vàng khi bị ép rào. |
| `match_audio.gd`, `game_audio.gd` | Âm thanh trận đấu; `GameAudio` là autoload phát nhạc và tiếng, âm lượng theo `data/audio.json`. |
| `follow_camera.gd` | Camera bám sau trâu, thấp qua vai phải (22°); giật vào và rung khi trúng đòn, zoom khi khóa sừng; cuối trận lên cao nhìn toàn sân, rồi (Solo) hạ xuống quay chậm quanh trâu thắng. |
| `match_outro.gd` | Đoạn kết: bốc thăm (nếu hòa), trâu thua lui ra cổng, người dẫn trâu đứng chờ. |
| `arena_builder.gd` | Phần sân mà trận đấu cần: bùn, hàng rào tre (có va chạm) và hai cổng, mặt trời, bầu trời, cờ trên lưng trâu. |
| `arena_dressing.gd` | Cảnh lễ hội quanh sân, chỉ để nhìn: bãi cỏ, khán đài và đám đông (MultiMesh), đình trống, cột cờ, cây, đồi. |
| `low_poly.gd` | Hàm dựng khối dùng chung (hộp, trụ, cầu, người dân đội nón). |
| `ceremony_diorama.gd` | Cảnh 3D Phần Lễ: đình, bàn thờ, trống, cột cờ, đoàn rước. |
| `menu_backdrop.gd` | Cảnh 3D sau menu chính: sới lễ hội, hai trâu đỏ/xanh đối đầu, camera lượn chậm. |

### Các thư mục khác

| Đường dẫn | Nội dung |
|---|---|
| `scripts/ai/ai_controller.gd` | AI Solo (FSM) tạo `InputFrame` như người chơi; 3 hồ sơ trong `data/ai_profiles.json`. |
| `scripts/network/network_manager.gd` | Autoload `NetworkManager`: kết nối ENet, tạm dừng hai bên, kênh tin nhắn thô. |
| `scripts/ui/hud.gd` | HUD trong trận: thanh khí thế/sức, đồng hồ, khóa sừng, tutorial, menu tạm dừng. |
| `scripts/ui/main_menu.gd` | Menu chính (cột trái trên nền `MenuBackdrop`) và luồng Solo: bảng kết quả cột trái cạnh trâu thắng, trận tiếp, Phần Lễ. |
| `scripts/ui/ceremony_view.gd` | Màn Phần Lễ toàn màn hình: cảnh 3D + chú thích + nút tiếp tục. |
| `scripts/ui/lobby.gd`, `settings_controls.gd` | Sảnh LAN; các dòng cài đặt dùng chung cho menu và tạm dừng. |
| `scenes/` | `main_menu.tscn` (scene khởi động), `arena.tscn`, `buffalo.tscn`, `lobby.tscn`. |
| `assets/ui/festival_theme.tres` | Theme mặc định của project (màu nút, panel, chữ). |
| `tests/` | Test headless; xem mục Test bên dưới. |

## Dữ liệu trong `data/`

| File | Chứa gì | Đổi file này thì |
|---|---|---|
| `balance.json` | Luật chơi: tốc độ, sát thương, thời gian đòn, khóa sừng, kích thước sân. | Trận đấu chơi khác đi; host và client phải dùng cùng bản. |
| `presentation.json` | Cảm giác nhìn/nghe: camera, chuyển động, hiệu ứng, HUD, tutorial, đoạn kết. | Chỉ đổi cách trông, không đổi kết quả trận. |
| `levels.json` | Ba trận Solo (L01–L03) và trận LAN: tên trận, hồ sơ AI, vùng bùn. | Đổi nội dung mùa hội. |
| `ai_profiles.json` | Độ khó AI: tốc độ phản xạ, tỉ lệ gạt sừng, phản đòn. | Đổi độ khó. |
| `ceremony.json` | Chữ và thời lượng hai màn Phần Lễ. | Đổi lời dẫn nghi lễ. |
| `audio.json` | Âm lượng nhạc/tiếng và nhịp tiếng bước chân. | Đổi độ to nhỏ. |

Cả `balance.json` và `presentation.json` đều đọc bằng `GameBalance.get_number("tên_key")`.
Một key chỉ được nằm ở một file (`tests/data_files_test.gd` kiểm tra điều này).

## Sự kiện combat

`MatchController.combat_event(tên, nguồn, đích, giá trị)`: `nguồn`/`đích` là slot 1 (đỏ)
hoặc 2 (xanh).

| Nhóm | Tên sự kiện |
|---|---|
| Bắt đầu hành động | `HORN_START`, `DASH_START`, `PARRY_START`, `COUNTER_START`, `WHIFF_START`, `RELEASE_START` |
| Trúng đòn | `HORN_HIT`, `DASH_HIT`, `FLANK_HIT`, `BACK_HIT`, `GUARD_HIT`, `PARRY_SUCCESS`, `COUNTER_HIT` |
| Khóa sừng | `CLASH_START`, `CLASH_HOOK`, `CLASH_LOSS`, `CLASH_WHIFF` |

## Muốn sửa X thì mở đâu

- **Chỉnh một con số** (sát thương, tốc độ, độ dài hiệu ứng): tìm key trong `data/balance.json`
  hoặc `data/presentation.json`. Thêm key mới thì đặt vào đúng file theo bảng trên.
- **Thêm hoặc đổi hiệu ứng cho một sự kiện:** `match_vfx.gd` (`on_combat_event`), chữ nổi ở
  `buffalo_feedback.gd` (`WORDS`), tiếng ở `match_audio.gd`. Không cần đụng mô phỏng.
- **Thêm một đòn mới:** trạng thái trong `buffalo.gd`, tính trúng trong `combat_resolver.gd`,
  phím trong `input_frame.gd` + `match_input.gd` + `match_network.gd` (gửi qua LAN), AI trong
  `ai_controller.gd`, rồi thêm số vào `data/balance.json` và test trong `tests/`.
- **Đổi giao diện trận:** `hud.gd` và `assets/ui/festival_theme.tres`.
- **Đổi cảnh sân hay Phần Lễ:** `arena_builder.gd` (phần có va chạm), `arena_dressing.gd`
  (cảnh trang trí), `ceremony_diorama.gd`; người và đồ vật dựng bằng `LowPoly`.
- **Đổi góc camera:** các key `camera_*` trong `data/presentation.json`; code ở `follow_camera.gd`.

## Test

`bash tools/run_tests.sh` chạy mọi `tests/*_test.gd` và các cặp test LAN hai tiến trình (host +
client), in bảng PASS/FAIL. Mỗi test là một script `extends SceneTree`, báo lỗi bằng `quit(1)`.
Thay đổi người chơi nhìn thấy được thì chụp ảnh lưu ở `production/qa/evidence/`.
