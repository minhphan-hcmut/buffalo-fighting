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
5. **Cảnh được ghép bằng code và asset nhập vào** (`LowPoly`, `ArenaBuilder`,
   `ArenaDressing`, `CeremonyDiorama`): trâu HERO, dân làng, cây, rào tre, vật liệu đất/cỏ,
   sprite VFX và âm thanh. Không đồng nhất dựng cảnh thủ tục với tự tạo toàn bộ asset.

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
(L02–L05) → thắng chung kết thì Phần Lễ khép hội. Tiến trình lưu trong `SessionState`.

## Bản đồ file

### `scripts/core/`: mô phỏng (gameplay)

| File | Việc của nó |
|---|---|
| `match_controller.gd` | Gốc của scene `arena.tscn`: phase (đếm ngược, đấu, kết quả), đồng hồ, tạm dừng, luật thắng, hitstop, tạo các module khác. Solo tự mở pause khi mất focus trong COUNTDOWN/PLAYING nếu bật cài đặt; LAN không tự pause và luôn giữ hitstop. Sân tập dùng cấu hình `training`: không kết thúc trận/đếm giờ, hồi khí thế theo ngưỡng, giữ sức AI đầy và tùy chọn sức người chơi vô hạn. |
| `buffalo.gd` | Một con trâu: máy trạng thái hành động (`State`), di chuyển, SPIRIT/STAMINA, bộ đệm input. `use_natural_skin()` cho model dùng da trâu thật thay bản da bạc trong file glb. |
| `combat_resolver.gd` | Kiểm tra trúng đòn và tính khí thế mất, đẩy lùi. Thứ tự: bất tử → gạt sừng → ghìm → trúng; đánh sườn/lưng ×1,25. |
| `clash_system.gd` | Khóa sừng: thanh kéo co, móc, nhả, ai thua thì mất khí thế. |
| `arena_bounds.gd` | Hình học sân bầu dục: va chạm thân/đầu, giới hạn rào, trạng thái bị ép rào, vùng bùn. |
| `input_frame.gd` | Một tick ý định của một con trâu. |
| `match_input.gd` | Đọc bàn phím/chuột thành `InputFrame`; chặn nút đang giữ/click vừa nhả từ menu hoặc pause cho tới input mới. `configure_ui()` gắn A/B của gamepad vào chọn/quay lại, dùng chung ở menu, sảnh và trận. |
| `match_network.gd` | Nối `MatchController` với LAN: gửi/nhận input, snapshot, sự kiện; giữ kết quả trước snapshot trễ/rời trận. Tái đấu chỉ từ kết quả: mỗi bên đồng ý, host phát REMATCH_START tin cậy rồi hai scene nạp lại, giữ ENet/slot, state/stats mới. Epoch chặn input/snapshot/RESULT/COMBAT từ trận cũ, kể cả khoảng nạp scene. Peer rời ở bất kỳ lúc nào → khóa tái đấu, giữ kết quả và hiện thông báo. |
| `session_state.gd` | Dữ liệu sống qua các lần đổi scene: mùa Solo năm vòng theo `SOLO_LEVELS` (L01–L05), màn hiện tại, kết quả trước, thẻ văn hóa và màn Phần Lễ đã xem (`take_rites_before()` trước L01/L03/L05). Cờ `free_play`/`training` giữ mô phỏng SOLO nhưng chặn tăng vòng/nghi lễ, giữ tiến trình mùa khi rời trận. Sân tập chọn `drill_id` qua `begin_training()`; Sức vô hạn mặc định tắt, lưu cùng các cài đặt comfort bằng ConfigFile. |
| `game_balance.gd`, `data_file.gd` | Đọc số từ `data/`. |
| `yaw_basis.gd` | Vector trước/phải theo góc quay. |

### `scripts/core/`: trình bày (không đổi kết quả trận)

| File | Việc của nó |
|---|---|
| `buffalo_animator.gd` | Chuyển động thủ tục cho model trâu: lúc chạy dựng bộ xương 4 chân (đùi + cẳng, skin mềm) cho `HeroBody`, chân xoay quanh hông/gối nên không bị kéo dãn; húc, lao, khóa sừng. Thân chỉ ngửa tối đa `MAX_NOSE_UP_DEG` (3°) để móng trước không nhấc khỏi đất khi bị húc. Lúc bị dắt ra (FLEE), bước chân tính theo tốc độ dắt nên đủ sải. File `.glb` gốc không đổi. | Khi thân chúi mũi (húc, lao, gồng sừng), `_ground_legs` gập chân bằng IK hai đoạn để móng không lún xuống đất (chân trước chống ra trước, `leg_ground_*`); góc chúi tối đa `max_nose_down_deg`.
| `buffalo_feedback.gd` | Chữ nổi cho khoảnh khắc đáng gọi tên ("GẠT SỪNG!", "PHẢN ĐÒN!", "ĐÁNH SƯỜN!", "ĐÁNH LƯNG!", "HỤT"): màu lấy theme, parry pha PAPER, cỡ/giữ ngắn qua `combat_callout_*`; chiếu khung đầu/sừng đối thủ để dời chữ lên hoặc sang bên, bỏ chữ khi cực gần không còn chỗ an toàn. Horn glow/shader giữ độc lập ở `assets/shaders/horn_glow.gdshader`. |
| `match_vfx.gd` | Hiệu ứng chỉ đọc. Trúng đòn (húc, lao, phản, sườn/lưng): chớp sao lõi trắng, tia lửa kéo vệt theo hướng bay (shader cộng sáng, `ALIGN_Y_TO_VELOCITY`), sóng xung kích billboard, đèn Omni lóe ngắn (giới hạn số đèn), vòng vàng dưới đất và chùm đất văng theo hướng bị đẩy; đòn nặng mạnh hơn. Đỡ: tia lửa bật ngược; gạt sừng: chớp lớn + vòng tia lửa; khóa sừng: cú va lúc bắt đầu, tia lửa định kỳ và khi móc. Vung sừng: cung chém vàng trước đầu; bắt đầu lao: chớp muzzle, vòng bụi và đất bắn ngược ở móng sau. Ngoài ra: vệt cày khi trượt lùi, bụi từng móng khi lao, hơi thở khi đuối sức, tia ghìm, vòng vàng khi bị ép rào. Sprite Kenney Particle Pack (CC0) ở `assets/vfx/kenney_particle_pack/`. Rung camera theo lực ở `follow_camera.gd`. `warm_up()`: 2 khung đầu trận, dưới màn che tối, bắn một bản mọi preset trước camera cùng đèn gần như tắt để shader biên dịch trước, tránh giật lần đầu lao/trúng/khóa sừng (key `vfx_warm_up_*`); đếm frame bằng callback process_frame gắn node, tự ngắt khi rời cây, không coroutine treo sau free. |
| `match_audio.gd`, `game_audio.gd` | Âm thanh trận đấu; `GameAudio` là autoload phát nhạc và tiếng, âm lượng theo `data/audio.json`. Cú trúng ghép lớp theo lực (va gỗ Kenney + `sfx_impact_thump`; cú lao/phản đòn dùng bản nặng + lớp `sfx_heavy_crack_N`), `COUNTER_HIT` nâng cấp chứ không phát trùng. Bốn tiếng tự tạo sinh lại bằng `python tools/gen_combat_sfx.py`. Khi thoát, GameAudio dừng/null stream, bỏ cache/voice references; MatchAudio nhả loop riêng và bỏ deferred impact sau khi rời cây. AudioServer headless có thể còn báo playback chưa nhả ở quit tức thời, xem báo cáo đợt 10. |
| `match_rumble.gd` | Autoload `JoyRumble` nhớ thiết bị nhập từ menu sang trận; chỉ rung tay cầm người chơi cục bộ theo combat_event. Dừng khi pause, kết quả, rời trận, đổi sang bàn phím/chuột hoặc tắt cài đặt. Biên độ/thời gian đọc `rumble_*` từ presentation; callable rung/dừng thay được trong test headless. |
| `follow_camera.gd` | Camera bám sau trâu: Gần/Vừa/Xa và vai Phải/Trái, mặc định Vừa/Phải giữ 5,2 m và 22°; đổi khung hình êm khi chỉnh trong pause, giữ ống kính trong biên oval kể cả khe cổng không có collision: sát rào thì rút cần trước (tối thiểu `camera_bounds_min_length_m`), hết mức mới nâng góc (tối đa `camera_bounds_max_pitch_deg`). Giật/rung khi trúng đòn, zoom khi khóa sừng; cuối trận lên cao rồi quay quanh trâu thắng theo phía vai đã chọn. |
| `match_outro.gd` | Đoạn kết: bốc thăm (nếu hòa), rồi trâu thua ra cổng. Solo: người dắt của bên thua (áo cùng màu) chạy từ cổng vào đầu trâu, trâu đứng chờ, rồi dắt bằng dây thừng ra cổng (`result_lead_*`, `result_handler_*`); sau `result_skip_grace_s` có thể bấm phím/click/nút gamepad mới để bỏ qua phần trình bày và mở kết quả, không đổi bên thắng/lý do. Trước bảng Solo/skip, xóa vận tốc lọc bằng API animator có sẵn, cập nhật pose với cap `result_settle_max_s`, không thêm thời gian outro. Controller xóa hitstop cuối trận sau replay để animator tiếp tục cập nhật. HUD hiện gợi ý nhỏ sau khoảng chờ. LAN: trâu tự đi ra, không skip. |
| `match_replay.gd` | Chỉ Solo/Đấu tự do, FLEE: ring buffer `replay_seconds` cuối, phát `replay_speed` lần bằng hai bản sao không collision và camera ngang trước outro. Ghi transform, state/time/duration và trạng thái public của animator để khởi tạo chuyển động; gọi `sample_motion`/`update_pose` sẵn có, không sửa animator hoặc rewind mô phỏng. Context MatchController tách khỏi cây chỉ cấp dữ liệu khóa sừng cho animator, không chạy `_ready`/tick/mạng. HUD/VFX trận thật ẩn trong replay. Fresh key/click/gamepad bỏ qua sau grace như outro; không đổi Engine.time_scale/kết quả/stats/mùa. Cài đặt Hiệu ứng mặc định bật. Bổ sung ngoài GDD v0.7; tuning `replay_*`. |
| `lead_rope.gd` | Dây thừng võng giữa tay người dắt và mũi trâu (vài đoạn trụ mảnh, `result_rope_*`). |
| `release_handlers.gd` | Hai người dắt trâu đứng ở đầu trâu lúc đếm ngược rồi đi vòng cung bên trái trâu (tránh camera vai phải) tới miệng cổng rồi đi thẳng qua khe cổng (không xuyên rào) trước hiệu lệnh (GDD 2.6, 4.6). Chỉ đọc `countdown_time`. `SHIRTS`: màu áo người dắt theo bên, dùng chung với đoạn kết. |
| `arena_builder.gd` | Phần sân mà trận đấu cần: bùn (shader `mud_patch` + bộ scan CC0 Poly Haven "Brown Mud 03" ở `assets/textures/mud/`), hàng rào tre (có va chạm) và hai cổng, mặt trời, bầu trời, cờ trên lưng trâu. Preset Thấp gom mesh tre tĩnh theo vật liệu và từng cụm `graphics_fence_batch_segments_low` đoạn bằng SurfaceTool; giữ nguyên tam giác/màu/collision, cổng vẫn chuyển động riêng. Vừa/Cao dựng như cũ. |
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
| `scripts/ai/ai_controller.gd` | AI Solo (FSM) tạo `InputFrame` như người chơi; 5 hồ sơ mùa hội trong `data/ai_profiles.json`. Nhánh DRILL riêng chỉ tạo InputFrame cho Bao cát, Hổ lao, Húc, Móc theo nhịp hoặc Đẩy; không sửa state trực tiếp và không đi qua quyết định FSM cũ. |
| `scripts/network/network_manager.gd` | Autoload `NetworkManager`: ENet, đồng thuận pause, kênh tin nhắn thô và yêu cầu tái đấu client→host tin cậy (chỉ peer đã nối được gửi). Gắn/kiểm tra match_epoch trên snapshot/event/input/action; tái đấu giữ peer và sequence tăng đều, chỉ xóa input/pause cũ. RTT bằng timestamp RPC không tin cậy khoảng 1 Hz để không cộng thời gian truyền lại; xác minh peer và timestamp đang chờ, giới hạn tuổi mẫu, EMA rồi phát `ping_changed` khi số nguyên đổi. Rời mạng xóa mẫu. HUD chỉ tạo nhãn ping cho LAN, cảnh báo theo `lan_ping_warning_ms`, không format theo frame. Bổ sung tái đấu ngoài GDD v0.7. |
| `scripts/ui/ui_motion.gd` | Phản hồi hover/focus/nhấn cho nút, pop banner, bảng kết quả trượt/mờ vào và fade đổi scene bằng ảnh khung hình cũ; không trì hoãn gameplay. Tuning `ui_motion_*`, `ui_fade_*`, `ui_banner_*` trong `presentation.json`. |
| `scripts/ui/hud.gd` | HUD trong trận: thanh khí thế/sức, đồng hồ, khóa sừng (bảng dưới đồng hồ, có dòng phím riêng; thanh gợi ý ẩn khi khóa), tutorial, thanh phím rich text (phím vàng đậm, hành động màu giấy), menu tạm dừng (co theo nội dung). Banner đếm ngược/Vào trận neo trên giữa tại `hud_banner_top`, chừa cả mức pop tối đa ở cỡ Thường/Lớn. Sân tập giữ vị trí riêng, thay đồng hồ bằng panel tên bài/bộ đếm/popup, chỉ đọc combat_event; menu pause có Đổi bài tập thay Chơi lại. Kết quả LAN ở cột trái với shade như Solo (`lan_result_*`), camera thắng dùng cùng `FollowCamera.show_winner()` ở cả host/client. |
| `scripts/ui/match_stats.gd` | Bộ đếm chỉ đọc cho từng trận, nhìn theo local_slot (Solo, Đấu tự do và cả hai máy LAN). HORN_HIT/DASH_HIT đếm đòn; COUNTER_HIT, FLANK_HIT/BACK_HIT là chú thích của cùng đòn nên không cộng trùng. Khối hai cột hiện trên kết quả; Sân tập dùng bộ đếm riêng. Chơi lại tạo collector mới. |
| `scripts/ui/hud_text.gd` | Cỡ chữ HUD Thường/Lớn, nhớ cỡ gốc để đổi qua lại không nhân dồn; chỉ ghi metadata/font override khi giá trị đổi. HUD cache chuỗi timer/phím/countdown/khóa sừng, StyleBox sức; helper chỉ ghi text/Range/alpha/visibility/color khi đổi, dirty counter label_writes/range_writes để test. Cao/Vừa giữ phản hồi từng frame, Thấp vẫn có throttle. Hiệu ứng đổi cỡ chữ trực tiếp khi pause; trang cài đặt giữ kích thước cũ. |
| `scripts/ui/screenshot_service.gd` | Autoload `Screenshots`: F12 ở mọi scene lưu PNG duy nhất trong user://screenshots; tạo thư mục, kiểm tra lỗi lưu rồi mới hiện toast. Ưu tiên xử lý input trước các scene để không bỏ qua outro/Phần Lễ. Thư mục và nguồn frame có thể tiêm khi test. |
| `scripts/ui/main_menu.gd` | Menu chính (cột trái trên nền `MenuBackdrop`) và luồng Solo: chọn Mùa hội, Đấu tự do (cả năm vòng mở sẵn) hoặc Sân tập (5 bài + Sức vô hạn, phím lấy từ `MoveDemo.MOVES`); bảng kết quả cột trái cạnh trâu thắng, trận tiếp, Phần Lễ. Kết quả tự do có Chơi lại/Đổi trận/Về menu, giữ thẻ văn hóa và không khép mùa; Sân tập không mở kết quả/thẻ. Tạo bảng Cách chơi độc lập và khôi phục menu khi đóng. Nạp sẵn `arena.tscn` ở luồng nền từ lúc mở menu (`_prefetch_arena`); callback tĩnh `_finish_prefetch` lấy kết quả và tự ngắt kể cả khi đã rời menu sang LAN, không giữ request nền tới lúc quit. Vào trận qua `_go_to_arena` nên không đứng hình. |
| `scripts/ui/how_to_play.gd` | Bảng Cách chơi 4 tab: Luật chơi (từ khóa vàng), Các đòn, Điều khiển, Sổ tay; tab chữ/vạch vàng, Quay lại quiet. Tab/Shift+Tab đi qua thanh tab và nội dung đang chọn; Enter/chuột hoặc trái/phải đổi trang, tránh mất đường vào danh sách đòn/Sổ tay. |
| `scripts/ui/festival_notebook.gd` | Sổ tay liệt kê mọi thẻ từ culture_cards.json, thẻ chưa mở bị khóa; chọn bằng focus/chuột, nội dung dài cuộn bằng chuột hoặc phím lên/xuống khi focus phần chữ. Lịch sử riêng `user://festival_notebook.json` do CultureCards kiểm tra/lưu, chỉ mở khi thẻ thực sự hiện ở kết quả (kể cả sau Phần Lễ khép hội), không thay tiến trình mùa. Bổ sung ngoài GDD v0.7. |
| `scripts/ui/howto_diagrams.gd` | Ba thẻ Luật chơi: thanh khí thế/đồng hồ, thanh sức/hồi sức, trâu nhìn từ trên với vùng sườn/lưng và rào. Vẽ bằng `_draw()`, nhãn số đọc GameBalance, không đổi demo 3D. |
| `scripts/ui/move_demo.gd` | Một SubViewport dựng lười khi mở Các đòn: hai scene trâu thật diễn 6 timeline lặp, không gọi combat. Một `MatchVFX` dùng chung với trận nhận giao diện đọc cặp trâu/pause/phase/clash/pinned; sự kiện phát một lần tại mốc timeline, xóa hiệu ứng khi đổi đòn/lặp. Dừng render/animator/hạt khi ẩn, giải phóng cùng bảng. Tuning `demo_*` trong `presentation.json`. |
| `scripts/ui/controls_diagram.gd` | Sơ đồ bàn phím, chuột và phím khóa sừng; keycap dùng chung với minh họa đòn. Tuning `ui_howto_*`. |
| `scripts/ui/culture_cards.gd` | Chọn thẻ văn hóa chưa xem trong mùa Solo qua SessionState; ưu tiên thẻ di sản khi thắng chung kết. Lịch sử sưu tầm Sổ tay lưu riêng, giữ qua lần chạy; file hỏng → rỗng, test `--script` mặc định không đọc/ghi file người chơi. |
| `scripts/ui/ceremony_view.gd` | Màn Phần Lễ toàn màn hình: cảnh 3D + chú thích + nút tiếp tục. |
| `scripts/core/graphics_quality.gd`, `scripts/ui/fps_overlay.gd` | Cài đặt Đồ họa: preset Thấp/Vừa/Cao + Khán giả, Bóng đổ, Môi trường, Chi tiết model, Độ phân giải 3D, Giới hạn FPS (Theo màn hình/30–144/Không giới hạn), Hiện FPS. Lưu `user://graphics.cfg` (riêng với settings); GPU tích hợp tự vào Thấp; test `--script` luôn dùng Cao, không đọc/ghi file người chơi. Thấp còn gom hàng rào theo cụm, cập nhật HUD live PLAYING ở `graphics_hud_refresh_hz_low` (30 Hz), giảm số hạt/thời gian bụi và bỏ emitter trang trí (`graphics_vfx_*_low`); chớp/tia va chạm chính và warm-up vẫn giữ. HUD cộng dồn delta để timer hiệu ứng không chậm; pause/countdown/result cập nhật ngay. Vừa/Cao và mô phỏng giữ nguyên. Bổ sung hiệu năng ngoài GDD v0.7. |
| `scripts/ui/lobby.gd` | Sảnh LAN: tạo/vào phòng, trạng thái kết nối và đường quay về menu. |
| `scripts/ui/settings_screen.gd`, `settings_controls.gd`, `settings_row.gd`, `settings_selector.gd` | Một overlay Cài đặt dùng chung menu/pause, 5 tab Âm thanh / Điều khiển / Camera / Đồ họa / Hiệu ứng; hàng đồng nhất có cột điều khiển cố định và cuộn theo focus. Selector chuyển vòng bằng mũi tên/Left/Right/D-pad; Q/E hoặc LB/RB đổi tab. Khôi phục mặc định chỉ reset tab hiện tại (Đồ họa dùng preset tự chọn theo GPU + FPS mặc định). Giữ nguyên SessionState/GraphicsQuality, khóa focus phía sau, Xong/Esc/B trả focus về nút mở và giữ trạng thái pause/LAN. |
| `scenes/` | `main_menu.tscn` (scene khởi động), `arena.tscn`, `buffalo.tscn`, `lobby.tscn`. |
| `assets/shaders/flag_wave.gdshader` | Sóng cờ chỉ đổi đỉnh: mép buộc cố định, biên độ tăng ra mép tự do; pha theo vị trí XZ, màu MultiMesh qua `INSTANCE_CUSTOM` để chạy đúng GL Compatibility. Tuning `flag_*` trong `presentation.json`. |
| `assets/ui/festival_theme.tres` | Theme mặc định: `PrimaryButton` vàng/chữ mực, `SecondaryButton` tối/chữ giấy (cũng là Button mặc định), `QuietButton` chữ trầm/vạch focus vàng. Biến thể menu/tab/hàng dùng chữ/vạch vàng cho lựa chọn chính thay nền đặc, theo kiểu rail của Settings. |
| `tests/ui_hierarchy_test.gd`, `tests/ui_unify_window_harness.gd`, `tests/hud_callout_test.gd` | Kiểm một primary, không nút kem, khung hình và focus Tab/Shift+Tab trên các màn ở 720p/1080p; bảng stats nhãn/số, trạng thái tái đấu LAN và hint/callout tránh đầu đối thủ. Harness chụp năm ảnh `ui14-*` bằng cửa sổ thật, tách khỏi runner headless. |
| `tests/` | Test headless; xem mục Test bên dưới. |
| `tools/balance_sim.gd`, `tests/balance_sim_smoke_test.gd` | Mô phỏng AI-vs-AI bằng scene/controller/combat thật, giữ collider, bỏ trình bày và ghi JSON thống kê theo seed. CLI mặc định 200 trận/cặp; lọc `--level`, `--pair`, đổi bên nửa lượt bằng `--swap-sides`, thử `--set=key=value` chỉ trong bộ nhớ; không ghi balance hay tiến trình Solo. Smoke bốn trận kiểm kết thúc và lặp seed. |
| `tests/lan_ping_pair.gd` | Cặp ENet trong runner: đo RTT, Solo không có nhãn, LAN hiện đúng số/màu và chỉ ghi khi đổi, rời mạng xóa số cũ. `--proxy --profile=clean/typical/bad` kiểm relay 7778→7777 trong ±20 ms trên mean sau warm-up; `--window` lưu hai ảnh ping bằng cửa sổ thật. |
| `tools/lan_netem_proxy.py`, `tests/lan_netem_window_harness.gd` | Relay UDP stdlib để giả lập độ trễ/jitter/mất gói từng chiều (host 7777, client qua proxy 7778); harness hai cửa sổ chạy ba trận thật, tái đấu, pause, ngắt client/vào lại và host thoát. `--self-test` kiểm relay, không thêm cổng vào UI. |
| `tests/frame_pacing_window_harness.gd`, `tests/vfx_reuse_test.gd` | Đo cửa sổ Solo 180 giây Thấp/Cao, CSV từng frame và JSON 20 frame tệ nhất cùng mốc đòn/emitter/audio/HUD. Controller nạp cache cue đã khai báo trước countdown; vòng bụi lao dùng Curve bất biến chung. Test chống nạp âm thanh lần đầu giữa combat và kiểm Curve dùng lại đúng dữ liệu. Không đổi preset, model hay hiệu ứng. |

Trang Hiệu ứng còn có **Rung tay cầm** (mặc định bật) và **Cỡ chữ HUD** (Thường/Lớn, mặc định Thường), lưu/kiểm tra kiểu boolean trong SessionState. Bốn tiện ích thống kê/rung/cỡ chữ/F12 là bổ sung được duyệt ngoài GDD v0.7; chỉ trình bày, không thay mô phỏng hay payload LAN. Tuning `stats_*`, `rumble_*`, `hud_*`, `screenshot_*` nằm trong `presentation.json`. Test: `match_stats_test.gd`, `rumble_hud_screenshot_test.gd`.

## Ownership sau extraction HUD/menu (17/11/2026)

Các mô tả HUD/menu ở bản đồ trên là trách nhiệm **tổng thể của façade**, không phải toàn bộ
implementation còn ở một file. Không thay combat, physics, tick order, transport hay balance.

| File | Owner và giao diện thực tế |
|---|---|
| `scripts/ui/hud.gd` | CanvasLayer façade: root Control vẫn child 0; resource/timer/banner/CLASH/ping, throttle + accumulated delta, text-scale/dirty-write counters. Tạo **một** `MatchStats` collector; properties/wrappers tương thích delegate, không copy state presenter. |
| `scripts/ui/hud_tutorial.gd` | Node `TutorialPresenter`: `setup(controller, label, text_update)`, `enabled`, `queue_hint`, `on_combat_event`, `update(delta) -> bool`; sở hữu queue/seen/current/time/front-hit và controls clock. Rich text vẫn ghi qua HUD để giữ dirty counters. |
| `scripts/ui/hud_training.gd` | Node `TrainingPresenter`: `setup(controller, root, label_update)`, `count`, `success`, `on_combat_event`, `update`; sở hữu counters/popup/dirty flags và TrainingPanel trực tiếp dưới HUD root. Chỉ quan sát combat, không sửa mô phỏng. |
| `scripts/ui/match_pause_view.gd` | Node `PauseView`: một shell pause/settings dùng chung kết quả LAN; `setup(root, callbacks)` nhận resume/restart/leave/change_training/answer/sensitivity. Sở hữu modal, actions, focus; `ensure_shell` dựng lại shell đã free. |
| `scripts/ui/lan_result_view.gd` | Node `LanResultView`: `setup(shell, rematch, leave)`, `show_result(text, stats, has_lan, status)`, `update_rematch(status)`; cùng shell, chỉ giữ references nút/note, không tạo collector/mạng/progress mới. |
| `scripts/ui/main_menu.gd` | Façade menu/settings/howto/LAN, static loader, flags trở về training/free play và `/root/SoloSessionOverlay` (`session_overlay` meta). Overlay giữ identity qua arena, ẩn HUD khi Solo result ready và không replay. |
| `scripts/ui/solo_mode_view.gd` | Control `SoloModeView`: `setup(season, free_play, training, unlimited, back)`, `show_chooser/show_free_play/show_training/close`; sở hữu SoloPage, rows/toggles/focus, chỉ phát selection intents. |
| `scripts/ui/solo_result_view.gd` | Control `SoloResultView`: `setup(retry, next, menu, change, closing, result_data, select_card)`; sở hữu result/card nodes và tweens, `displayed_result` guard; phát `card_visible(card_id)`, không ghi notebook trực tiếp. Stats display lấy collector `arena.hud.stats`. |
| `scripts/ui/solo_flow.gd` | Node `SoloFlow`: `start_season/select_free_play/select_training/retry/next_match/return_to_menu`, rites/closing và card commands. Dùng **SessionState duy nhất** cho mode/progress; không mirror mùa hay kết quả lâu dài. CeremonyView là child façade, flow giữ sequencing. |

### Public controller/HUD contract và ranh giới còn lại

- Controller public intents hiện có: `request_pause_from_menu()`, `resume_from_menu()`;
  Solo thay pause cục bộ, LAN gửi yêu cầu cần peer đồng ý. Signals `combat_event` và
  `match_ended` là đường quan sát; `announcer_active()/announcer_text()` cấp lời dẫn.
- HUD public `close_settings_if_open() -> bool`: true chỉ khi đóng modal đang mở, **không
  resume/đổi consent**; controller Esc dùng bool để consume input. `return_to_menu() -> void`
  rời ENet nếu LAN, cập nhật SessionState và chuyển scene; `_return_to_menu()` chỉ là alias cũ.
- HUD giữ `show_pause()`, `show_pause_wait(bool)`, `show_pause_confirmation(peer_id, bool)`,
  `hide_pause()`, `show_settings()`, `show_result(winner_slot, reason)`,
  `update_lan_rematch(disconnected=false)` cho controller/network callers.
- Đây **không phải** DTO/read-only API toàn controller: HUD vẫn đọc state/controller.lan,
  gọi `controller._level_config()` và bridge sensitivity tới CameraRig; chưa có public
  `level_config()` mới. Hai call sites controller đã bỏ private HUD/settings access, không
  suy rộng thành đã xóa mọi dependency nội bộ.

### Lifecycle, prefetch và thẻ văn hóa

- Tutorial/training disconnect combat signal, xóa callback/controller references khi exit;
  training giải phóng panel riêng. Training → tutorial → stats giữ thứ tự subscription.
- Pause shell exit đóng SettingsScreen để trả focus, xóa result references qua
  `actions_cleared`; LAN result không giữ references trận cũ khi reload/rematch. UI tweens
  gắn node; SoloResultView kill result/card tweens khi exit, `scene_changed` reset dùng
  node-bound method. Mode page là child thật, teardown không mutate parent.
- Static `_arena_scene`, `_prefetch_arena()`, `_finish_prefetch()` và instance method
  `_go_to_arena()` vẫn trên **façade main_menu**, không đưa cache/loader vào flow. Callback process_frame static
  thu threaded request rồi tự disconnect kể cả menu đã free/chuyển LAN, không coroutine
  giữ menu sống. Nếu chưa xong, `_go_to_arena()` lấy request đang chạy hoặc load fallback.
- **`SoloFlow.result_data()` là command có side effect, không phải getter để polling.** Nó
  gọi `select_card(final_win)`, chọn/reserve thẻ bằng append `SessionState.culture_cards_seen`.
  Cả hai không tự idempotent theo result key; actual view guard `displayed_result` mới bảo vệ
  đường render. Façade `_show_culture_card()` cũng là lệnh chọn mới, không đọc lại thẻ hiện tại.
- Reservation trong mùa khác notebook award: `card_visible` chỉ phát khi card/panel
  visible-in-tree (meta `awarded` chặn lặp), flow mới gọi `CultureCards.mark_shown`.
  Chung kết reserve trước nhưng chỉ award sau closing reveal. Retry/free play/training
  không được diễn giải thành tăng mùa; training không có result/card.
- Lifecycle regressions không chứng minh toàn app leak-free: shutdown ObjectDB/resources
  diagnostics còn tồn tại. Evidence và gates chưa đạt: [refactor acceptance](../production/qa/refactor-acceptance.md).

## Dữ liệu trong `data/`

| File | Chứa gì | Đổi file này thì |
|---|---|---|
| `balance.json` | Luật chơi: tốc độ, sát thương, thời gian đòn, khóa sừng, kích thước sân. | Trận đấu chơi khác đi; host và client phải dùng cùng bản. |
| `presentation.json` | Cảm giác nhìn/nghe: camera, chuyển động, hiệu ứng, HUD, tutorial, đoạn kết; `comfort_flash_soft_scale`, kích thước trang Hiệu ứng/Đấu tự do. | Chỉ đổi cách trông, không đổi kết quả trận. |
| `levels.json` | Năm trận Solo (L01–L05) và trận LAN: tên trận, hồ sơ AI, vùng bùn, số hiệu và giáp của đối thủ; `difficulty_labels` ánh xạ profile sang nhãn độ khó ở Đấu tự do. | Đổi nội dung mùa hội và nhãn danh sách trận tự do. |
| `ai_profiles.json` | Độ khó AI: tốc độ phản xạ, tỉ lệ gạt sừng, phản đòn. | Đổi độ khó. |
| `training.json` | Năm bài tập: id, tên, mục tiêu, DRILL profile, id đòn để dùng lại lời phím, các bộ đếm và mẫu chữ HUD. | Đổi danh sách/nội dung Sân tập; luật riêng dùng `training_*` trong balance/presentation. |
| `ceremony.json` | Chữ và thời lượng 5 màn Phần Lễ. `water`/`giap`/`drums` hiện trước L01/L03/L05, mỗi màn một lần mỗi mùa hội. | Đổi lời dẫn nghi lễ. |
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
- **Đổi giao diện trận:** façade `hud.gd`, các presenter tutorial/training/pause/LAN result
  ở bảng ownership bên trên và `assets/ui/festival_theme.tres`.
- **Đổi lựa chọn/luồng/kết quả Solo:** `solo_mode_view.gd` / `solo_flow.gd` /
  `solo_result_view.gd`; `main_menu.gd` giữ façade và static prefetch.
- **Đổi cảnh sân hay Phần Lễ:** `arena_builder.gd` (phần có va chạm), `arena_dressing.gd`
  (cảnh trang trí), `ceremony_diorama.gd`; người và đồ vật dựng bằng `LowPoly`.
- **Đổi góc camera:** các key `camera_*` trong `data/presentation.json`; code ở `follow_camera.gd`.

## Test

`bash tools/run_tests.sh` chạy mọi `tests/*_test.gd` và các cặp test LAN hai tiến trình (host +
client), in bảng PASS/FAIL. Mỗi test là một script `extends SceneTree`, báo lỗi bằng `quit(1)`.
Thay đổi người chơi nhìn thấy được thì chụp ảnh lưu ở `production/qa/evidence/`.

## Các đường thoát giao diện

- Cài đặt dùng một overlay với năm tab, không có trang con Đồ họa/Hiệu ứng. Esc/B hoặc Xong đóng
  overlay và trả focus về nút Cài đặt của menu/pause; toàn bộ focus được giữ trong tab, footer và
  thanh tab khi mở. Kiểm tra bằng `settings_screen_test.gd`; ảnh cửa sổ qua `settings_window_harness.gd`.
- Sảnh LAN có focus Tạo phòng lúc vào, Quay lại khi chờ; Esc/B rời sảnh và đóng ENet.
- Trận LAN kết thúc hoặc mất kết nối có bảng kết quả với Về menu, Esc/B cũng về menu
  khi kết quả đã sẵn sàng. Pause LAN không có Chơi lại; tái đấu có giao thức đồng thuận
  riêng ở bảng kết quả (không phải restart từ pause).
- Sân tập đặt đếm ngược/Vào trận bên dưới bảng tên bài, cùng vùng thông báo khóa sừng.
- Kiểm thử hồi quy đợt rà soát: `tests/review_regressions_test.gd`, `lan_snapshot_test.gd`.
  Hai harness có cửa sổ `review_window_harness.gd` và `review_lan_window_harness.gd` dùng
  để rà luồng/chụp bằng chứng ở 1280×720 và 1920×1080, không nằm trong runner headless.
