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
| `buffalo.gd` | Một con trâu: máy trạng thái hành động (`State`), di chuyển, SPIRIT/STAMINA, bộ đệm input. `use_natural_skin()` cho model dùng da trâu thật thay bản da bạc trong file glb. |
| `combat_resolver.gd` | Kiểm tra trúng đòn và tính khí thế mất, đẩy lùi. Thứ tự: bất tử → gạt sừng → ghìm → trúng; đánh sườn/lưng ×1,25. |
| `clash_system.gd` | Khóa sừng: thanh kéo co, móc, nhả, ai thua thì mất khí thế. |
| `arena_bounds.gd` | Hình học sân bầu dục: va chạm thân/đầu, giới hạn rào, trạng thái bị ép rào, vùng bùn. |
| `input_frame.gd` | Một tick ý định của một con trâu. |
| `match_input.gd` | Đọc bàn phím/chuột thành `InputFrame`. |
| `match_network.gd` | Nối `MatchController` với LAN: gửi/nhận input, snapshot, sự kiện. |
| `session_state.gd` | Dữ liệu sống qua các lần đổi scene: chế độ, màn hiện tại, kết quả trước, thẻ văn hóa và màn Phần Lễ đã xem (`take_rites_before()`). |
| `game_balance.gd`, `data_file.gd` | Đọc số từ `data/`. |
| `yaw_basis.gd` | Vector trước/phải theo góc quay. |

### `scripts/core/`: trình bày (không đổi kết quả trận)

| File | Việc của nó |
|---|---|
| `buffalo_animator.gd` | Chuyển động thủ tục cho model trâu: lúc chạy dựng bộ xương 4 chân (đùi + cẳng, skin mềm) cho `HeroBody`, chân xoay quanh hông/gối nên không bị kéo dãn; húc, lao, khóa sừng. Thân chỉ ngửa tối đa `MAX_NOSE_UP_DEG` (3°) để móng trước không nhấc khỏi đất khi bị húc. Lúc bị dắt ra (FLEE), bước chân tính theo tốc độ dắt nên đủ sải. File `.glb` gốc không đổi. | Khi thân chúi mũi (húc, lao, gồng sừng), `_ground_legs` gập chân bằng IK hai đoạn để móng không lún xuống đất (chân trước chống ra trước, `leg_ground_*`); góc chúi tối đa `max_nose_down_deg`.
| `buffalo_feedback.gd` | Chữ nổi trên đầu trâu, chỉ cho khoảnh khắc đáng gọi tên ("GẠT SỪNG!", "PHẢN ĐÒN!", "ĐÁNH SƯỜN!", "ĐÁNH LƯNG!", "HỤT"), và màu sừng phát sáng; shader ở `assets/shaders/horn_glow.gdshader`. |
| `match_vfx.gd` | Hiệu ứng chỉ đọc. Trúng đòn (húc, lao, phản, sườn/lưng): chớp sao lõi trắng, tia lửa kéo vệt theo hướng bay (shader cộng sáng, `ALIGN_Y_TO_VELOCITY`), sóng xung kích billboard, đèn Omni lóe ngắn (giới hạn số đèn), vòng vàng dưới đất và chùm đất văng theo hướng bị đẩy; đòn nặng mạnh hơn. Đỡ: tia lửa bật ngược; gạt sừng: chớp lớn + vòng tia lửa; khóa sừng: cú va lúc bắt đầu, tia lửa định kỳ và khi móc. Vung sừng: cung chém vàng trước đầu; bắt đầu lao: chớp muzzle, vòng bụi và đất bắn ngược ở móng sau. Ngoài ra: vệt cày khi trượt lùi, bụi từng móng khi lao, hơi thở khi đuối sức, tia ghìm, vòng vàng khi bị ép rào. Sprite Kenney Particle Pack (CC0) ở `assets/vfx/kenney_particle_pack/`. Rung camera theo lực ở `follow_camera.gd`. |
| `match_audio.gd`, `game_audio.gd` | Âm thanh trận đấu; `GameAudio` là autoload phát nhạc và tiếng, âm lượng theo `data/audio.json`. Cú trúng ghép lớp theo lực (va gỗ Kenney + `sfx_impact_thump`; cú lao/phản đòn dùng bản nặng + lớp `sfx_heavy_crack_N`), `COUNTER_HIT` nâng cấp chứ không phát trùng. Bốn tiếng tự tạo sinh lại bằng `python tools/gen_combat_sfx.py`. |
| `follow_camera.gd` | Camera bám sau trâu, thấp qua vai phải (22°); giật vào và rung khi trúng đòn, zoom khi khóa sừng; cuối trận lên cao nhìn toàn sân, rồi (Solo) hạ xuống quay chậm quanh trâu thắng. |
| `match_outro.gd` | Đoạn kết: bốc thăm (nếu hòa), rồi trâu thua ra cổng. Solo: người dắt của bên thua (áo cùng màu) chạy từ cổng vào đầu trâu, trâu đứng chờ, rồi dắt bằng dây thừng ra cổng (`result_lead_*`, `result_handler_*`). LAN: trâu tự đi ra. |
| `lead_rope.gd` | Dây thừng võng giữa tay người dắt và mũi trâu (vài đoạn trụ mảnh, `result_rope_*`). |
| `release_handlers.gd` | Hai người dắt trâu đứng ở đầu trâu lúc đếm ngược rồi đi vòng cung bên trái trâu (tránh camera vai phải) ra cổng trước hiệu lệnh (GDD 2.6, 4.6). Chỉ đọc `countdown_time`. `SHIRTS`: màu áo người dắt theo bên, dùng chung với đoạn kết. |
| `arena_builder.gd` | Phần sân mà trận đấu cần: bùn (shader `mud_patch` + bộ scan CC0 Poly Haven "Brown Mud 03" ở `assets/textures/mud/`), hàng rào tre (có va chạm) và hai cổng, mặt trời, bầu trời, cờ trên lưng trâu. |
| `arena_gates.gd` | Hai cổng tre ở khe hàng rào (±X), chỉ để nhìn, không va chạm: đóng khi đang đấu (biên oval chặn trâu ở đó, nên khe không được trông như để mở), mở lúc đếm ngược cho người dắt đi ra và từ RESULT cho phần kết; ngoài trận (menu, Phần Lễ) luôn mở. Key `gate_swing_s`, `gate_open_deg`. |
| `arena_dressing.gd` | Cảnh lễ hội quanh sân, chỉ để nhìn: bãi cỏ, nền đất nện (scan CC0 Poly Haven "Sand 01", `assets/textures/earth/earth_floor.tres`), khán đài và đám đông đứng (model dân làng dựng sẵn qua `LowPoly.crowd_villager_mesh`, 2 MultiMesh: đứng yên / giơ tay; màu áo và nón theo custom data; shader `crowd_bob`), đình trống, cột cờ và dây cờ đuôi nheo uốn nhẹ bằng shader `flag_wave`, cây tròn xen cau/dừa (Kenney Nature Kit, CC0, tô lại màu qua `_palm_mesh`) thành vòng sau khán đài và một rừng thưa xa hơn (`scenery_grove_*`, mỗi vòng một seed), đồi. Màu nền cố ý dịu để trâu nổi bật. |
| `crowd_reaction.gd` | Độ hào hứng của khán giả (0..1) theo sự kiện combat, giảm dần; đẩy vào shader `crowd_bob` để đám đông nhún/reo. Chỉ đọc. |
| `low_poly.gd` | Hàm dựng khối dùng chung (hộp, trụ, cầu). Người dân: model rig Quaternius "Animated Human" (CC0, `assets/characters/villager/`), đổi màu áo theo bảng màu, nón lá gắn xương đầu, clip Stand/Walk/Run/Working, tư thế đánh trống/cầm cờ (`make_drummer`, `drum_swing`). `crowd_villager_mesh()` nướng model ở tư thế Stand (skinning tính tay) thành mesh tĩnh có nón, gắn nhãn bộ phận ở UV.x cho khán đài. `flag_cloth()` + `flag_material()`: lá cờ chia lưới và vật liệu `flag_wave` dùng chung cho sân và Phần Lễ. |
| `ceremony_diorama.gd` | Cảnh 3D của 5 màn Phần Lễ theo lịch hội: `opening` (1/8), `water` rước nước (7/8), `giap` các giáp đưa trâu vào hội (8/8), `drums` trống khai hội, múa cờ trên sới (9/8), `closing` (10/8). Cờ dải và cờ hội dùng plane chia nhỏ, shader `flag_wave` giữ mép buộc cố định. Sương nhẹ (`ceremony_fog_density`) và bóng dịu (`ceremony_shadow_opacity`); không dùng tonemap filmic vì làm cảnh bạc màu. |
| `low_poly.gd` (ghi chú màu) | `LowPoly.tone()` đưa màu bảng palette của vật liệu thường về tông đậm hơn theo `ui_palette_depth` (GL Compatibility hiện albedo thường nhạt hơn màu instance của `multi()`). Dùng cho `material()`, texture dân làng và uniform khán giả. |
| `menu_backdrop.gd` | Cảnh 3D sau menu chính: sới lễ hội, hai trâu đỏ/xanh đối đầu, người dắt trâu xanh đứng lệch ra cạnh mông trâu (`HANDLER_SPOT`; bên đỏ nằm sau cột nút nên không đặt), camera lượn chậm. |

### Các thư mục khác

| Đường dẫn | Nội dung |
|---|---|
| `scripts/ai/ai_controller.gd` | AI Solo (FSM) tạo `InputFrame` như người chơi; 3 hồ sơ trong `data/ai_profiles.json`. |
| `scripts/network/network_manager.gd` | Autoload `NetworkManager`: kết nối ENet, tạm dừng hai bên, kênh tin nhắn thô. |
| `scripts/ui/hud.gd` | HUD trong trận: thanh khí thế/sức, đồng hồ, khóa sừng (bảng dưới đồng hồ, có dòng phím riêng; thanh gợi ý ẩn khi khóa), tutorial, thanh phím rich text (phím vàng đậm, hành động màu giấy), menu tạm dừng (co theo nội dung). |
| `scripts/ui/main_menu.gd` | Menu chính (cột trái trên nền `MenuBackdrop`) và luồng Solo: bảng kết quả cột trái cạnh trâu thắng, trận tiếp, Phần Lễ; tạo bảng Cách chơi độc lập và khôi phục menu khi đóng. Nạp sẵn `arena.tscn` ở luồng nền từ lúc mở menu (`_prefetch_arena`), vào trận qua `_go_to_arena` nên không đứng hình. |
| `scripts/ui/how_to_play.gd` | Bảng Cách chơi 3 tab: Luật chơi (từ khóa vàng), Các đòn, Điều khiển; focus, Esc và nút quay lại. |
| `scripts/ui/move_demo.gd` | Một SubViewport dựng lười khi mở Các đòn: hai scene trâu thật diễn 6 timeline lặp, không gọi combat; dừng render/animator khi ẩn, giải phóng cùng bảng. Tuning `demo_*` trong `presentation.json`. |
| `scripts/ui/controls_diagram.gd` | Sơ đồ bàn phím, chuột và phím khóa sừng; keycap dùng chung với minh họa đòn. Tuning `ui_howto_*`. |
| `scripts/ui/culture_cards.gd` | Chọn thẻ văn hóa chưa xem sau trận Solo; ưu tiên thẻ di sản khi thắng chung kết, lưu danh sách đã xem trong `SessionState`. |
| `scripts/ui/ceremony_view.gd` | Màn Phần Lễ toàn màn hình: cảnh 3D + chú thích + nút tiếp tục. |
| `scripts/ui/lobby.gd`, `settings_controls.gd` | Sảnh LAN; các dòng cài đặt dùng chung cho menu và tạm dừng. |
| `scenes/` | `main_menu.tscn` (scene khởi động), `arena.tscn`, `buffalo.tscn`, `lobby.tscn`. |
| `assets/shaders/flag_wave.gdshader` | Sóng cờ chỉ đổi đỉnh: mép buộc cố định, biên độ tăng ra mép tự do; pha theo vị trí XZ, màu MultiMesh qua `INSTANCE_CUSTOM` để chạy đúng GL Compatibility. Tuning `flag_*` trong `presentation.json`. |
| `assets/ui/festival_theme.tres` | Theme mặc định của project (màu nút, panel, chữ). |
| `tests/` | Test headless; xem mục Test bên dưới. |

## Dữ liệu trong `data/`

| File | Chứa gì | Đổi file này thì |
|---|---|---|
| `balance.json` | Luật chơi: tốc độ, sát thương, thời gian đòn, khóa sừng, kích thước sân. | Trận đấu chơi khác đi; host và client phải dùng cùng bản. |
| `presentation.json` | Cảm giác nhìn/nghe: camera, chuyển động, hiệu ứng, HUD, tutorial, đoạn kết. | Chỉ đổi cách trông, không đổi kết quả trận. |
| `levels.json` | Ba trận Solo (L01–L03) và trận LAN: tên trận, hồ sơ AI, vùng bùn. | Đổi nội dung mùa hội. |
| `ai_profiles.json` | Độ khó AI: tốc độ phản xạ, tỉ lệ gạt sừng, phản đòn. | Đổi độ khó. |
| `ceremony.json` | Chữ và thời lượng 5 màn Phần Lễ. `water`/`giap`/`drums` hiện trước L01/L02/L03, mỗi màn một lần mỗi mùa hội. | Đổi lời dẫn nghi lễ. |
| `culture_cards.json` | Năm thẻ văn hóa, nguồn tư liệu và thẻ ưu tiên khi thắng chung kết. | Chỉ đổi nội dung thẻ sau trận Solo, không đổi kết quả trận. |
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
