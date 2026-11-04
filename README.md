# Chọi trâu: Đấu trường lễ hội

Source game Godot nằm trực tiếp tại thư mục dự án này. Đây là game 3D low-poly với gameplay 2.5D trên mặt phẳng XZ, camera bám sau trâu và giữ góc nghiêng 45 độ. Mở `project.godot` bằng Godot 4.x để chạy.

## Điều khiển

- `W/A/S/D`: đi theo hướng camera; đi ngang và lùi có hệ số tốc độ riêng.
- Chuột: xoay camera quanh trâu; thân trâu quay theo camera với giới hạn tốc độ.
- Chuột trái: HORN; trong CLASH dùng để móc.
- `Space`: DASH.
- Giữ chuột phải: GUARD; trong CLASH nhấn xuống để nhả khóa.
- `Esc`: tạm dừng và thả chuột (LAN: gửi yêu cầu tạm dừng cho đối phương); click chuột trái để khóa chuột lại.

Trận dùng SPIRIT và STAMINA, không có HP/gore. Trận kết thúc bằng FLEE, TIME hoặc LOT. Solo có ba profile AI và cấu hình bùn theo level. Mỗi level đọc chỉ số từ `data/balance.json`, `data/levels.json` và `data/ai_profiles.json`.

## Cấu trúc

- `scenes/`: menu, lobby, arena và trâu.
- `scripts/core/`: balance, input frame, session state, trâu (`buffalo.gd`, `buffalo_animator.gd`) và trận đấu:
  - `match_controller.gd`: phase, timer, pause, luật thắng; điều phối các module dưới.
  - `arena_builder.gd` / `arena_bounds.gd`: dựng sân, rào, bùn; giới hạn sân và PINNED.
  - `combat_resolver.gd`: HORN/DASH/GUARD, sát thương và knockback.
  - `clash_system.gd`: khóa sừng (PUSH/HOOK/RELEASE).
  - `match_input.gd`: đọc input local; `match_network.gd`: đồng bộ LAN.
- `scripts/ai/`: FSM AI.
- `scripts/network/`: ENet Host/Join.
- `scripts/ui/`: menu, lobby và HUD.
- `assets/characters/buffalo/buffalo.glb`: model gameplay mới nhất, giữ nguyên từ Blender source `assets/blender/buffalo.blend`.
- `tools/godot-mcp/` và `addons/godot_mcp/`: Godot MCP.
- `.mcp.json`: đăng ký MCP cho Godot và Blender.

## Chạy và kiểm tra

Chạy `project.godot`, chọn SOLO hoặc LAN từ menu. Host LAN dùng port 7777; client nhập IPv4 của host.

Các bài kiểm tra headless:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/gdd_smoke_test.gd
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/ai_test.gd
godot --headless --path . --script res://tests/tpp_test.gd
godot --headless --path . --script res://tests/buffalo_asset_test.gd
godot --headless --path . --script res://tests/network_manager_test.gd
godot --headless --path . --script res://tests/session_test.gd
godot --headless --path . --script res://tests/movement_test.gd
godot --headless --path . --script res://tests/clash_pinned_test.gd
godot --headless --path . --script res://tests/collision_test.gd
godot --headless --path . --script res://tests/clash_pose_test.gd
godot --headless --path . --script res://tests/lan_snapshot_test.gd
# Hai tiến trình, chạy host trước rồi client sau ~2 s: trận LAN có CLASH
godot --headless --path . --script res://tests/lan_match_host.gd
godot --headless --path . --script res://tests/lan_match_client.gd
godot --headless --path . --script res://tests/pause_test.gd
godot --headless --path . --script res://tests/animation_test.gd
godot --headless --path . --script res://tests/hero_audio_test.gd
```

LAN vẫn cần kiểm tra hai instance trên hai máy cùng mạng để nghiệm thu ENet, đồng bộ kết quả và disconnect. Asset trâu chưa có rig; chuyển động hiện là procedural (giai đoạn A), có bước chân chéo và nhấc móng cho model HERO bằng blend shape runtime, nhịp bước theo quãng đường thực tế (đi tới/lùi/ngang). Có thể chỉnh `gait_stride_length`, `gait_step_reach`, `gait_hoof_lift` trong `data/balance.json`. Khi clash, chân bước ngắn theo hướng dịch chuyển thực tế (tiến/lùi), đứng yên thì trụ chân; chỉnh bằng `clash_gait_stride_length`, `clash_gait_step_reach`, `clash_gait_hoof_lift`, không đổi lực đẩy. Chuyển tiếp vào khóa sừng dùng easing; tốc độ dịch chuyển cặp trâu tăng/giảm dần theo `clash_slide_acceleration`/`clash_slide_deceleration`, hãm trước khi đảo hướng và bỏ đà bị chặn ở hàng rào. Luật tính balance, stamina và kết quả clash không đổi. Motion húc sừng có ba pha lấy lực → thúc/hất → hồi thế; chỉnh biên độ bằng `horn_visual_windup`, `horn_visual_reach`, `horn_visual_dip_deg`, `horn_visual_toss_deg` (chỉ hình ảnh, không đổi hitbox hoặc thời gian đòn). LAN dùng đồng hồ visual cục bộ khi snapshot không có tiến độ đòn, nên không bảo đảm trùng từng frame với host; phần animation, nghi lễ tĩnh, audio và decor cần hoàn thiện tiếp.
