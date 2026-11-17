# Chọi trâu: Đấu trường lễ hội

Source game Godot nằm trực tiếp tại thư mục dự án này. Đây là game 3D low-poly với gameplay 2.5D trên mặt phẳng XZ, camera bám sau trâu, thấp qua vai phải (nghiêng 22 độ). Mở `project.godot` bằng Godot 4.7.2 (bản Standard, phiên bản đã kiểm chứng) để chạy.

**Chạy game lần đầu (người hoặc AI agent): xem [`HUONG_DAN_CHAY.md`](HUONG_DAN_CHAY.md).**

## Điều khiển

- `W/A/S/D`: đi theo hướng camera; đi ngang và lùi có hệ số tốc độ riêng.
- Chuột: xoay camera quanh trâu; thân trâu quay theo camera với giới hạn tốc độ.
- Chuột trái: HORN; trong CLASH dùng để móc.
- `Space`: DASH.
- `G`: PARRY (gạt sừng).
- Giữ chuột phải: GUARD; trong CLASH nhấn xuống để nhả khóa.
- `Esc`: tạm dừng và thả chuột (LAN: gửi yêu cầu tạm dừng cho đối phương); click chuột trái để khóa chuột lại.

Trận dùng SPIRIT và STAMINA, không có HP/gore. Trận kết thúc bằng FLEE, TIME hoặc LOT. Mùa Solo có năm profile AI theo L01–L05: EASY, EASY_PLUS, NORMAL, NORMAL_PLUS, HARD; các profile DRILL dành riêng Sân tập. Cấu hình bùn theo level. Mỗi level đọc chỉ số từ `data/balance.json`, `data/levels.json` và `data/ai_profiles.json`.

## Cấu trúc

Chi tiết từng file và luồng một trận: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

- `scenes/`: menu, lobby, arena và trâu.
- `scripts/core/`: mô phỏng trận đấu (trâu, combat, khóa sừng, sân, input, mạng) và lớp trình bày
  (chuyển động trâu, hiệu ứng, âm thanh, camera, đoạn kết, dựng sân và Phần Lễ).
- `scripts/ai/`: FSM AI. `scripts/network/`: ENet Host/Join. `scripts/ui/`: façade menu/HUD,
  presenter tutorial/training/pause/kết quả LAN, `solo_mode_view`/`solo_result_view` và `solo_flow`,
  lobby, Phần Lễ. SessionState là nguồn tiến trình duy nhất; xem ownership/API trong kiến trúc.
- `data/`: `balance.json` (luật chơi), `presentation.json` (hình, tiếng, HUD), `levels.json`,
  `ai_profiles.json`, `ceremony.json`, `audio.json`.
- `assets/characters/buffalo_hero/buffalo_hero.glb`: model gameplay hiện tại; nguồn tại `assets/blender/ancient_east_water_buffalo_HERO.blend`.
- `assets/characters/buffalo/buffalo.glb`: model dự phòng; nguồn tại `assets/blender/buffalo.blend`.
- `assets/audio/`: âm thanh gameplay; ZIP nguồn chỉ giữ local trong `assets/audio/source/` (không commit).
- `assets/environment/`: model rào tre và vật liệu sân đất/cỏ dùng trong game.
- `assets/blender/bamboo_fence.blend`: nguồn Geometry Nodes của hàng rào tre.
- `assets/source/`: archive tải về giữ local (không commit ZIP); không được Godot import.
- `tools/export_bamboo_fence.py`, `tools/import_sparse_grass.py`: chuyển nguồn asset thành tài nguyên game.
- `production/qa/evidence/`: ảnh kiểm tra giao diện và môi trường trong game.
- `references/`: ảnh tham khảo, bao gồm `water-buffalo-reference.jpg`.
- `tools/godot-mcp/` và `addons/godot_mcp/`: Godot MCP.
- `.mcp.json`: đăng ký MCP cho Godot và Blender.

## Tái tạo asset môi trường

Chạy từ thư mục repo, dùng Blender trong PATH (hoặc thay `blender` bằng đường dẫn bản cài):

```sh
blender --background --disable-autoexec assets/blender/bamboo_fence.blend \
  --python tools/export_bamboo_fence.py -- --output assets/environment/bamboo_fence.glb
blender --background --disable-autoexec --python tools/import_sparse_grass.py -- \
  --source assets/source/sparse_grass_4k.blend.zip --output assets/environment/sparse_grass
```

ZIP sân cỏ gốc lớn hơn giới hạn file GitHub thông thường nên chỉ giữ local. Khi clone mới,
đặt bản tải `sparse_grass_4k.blend.zip` vào `assets/source/` nếu cần tái tạo texture;
chạy game không cần ZIP hoặc Blender vì tài nguyên đã chuyển đổi được commit đầy đủ.
Không tự động ghi đè texture `.import`: các map sân cần `mipmaps/generate=true`
để tránh nhiễu khi nhìn xa. Vật liệu lát theo không gian thế giới, một ô mỗi 4 m.
Nguồn Blender/ZIP không bị thay đổi khi chạy script. Rào giữ va chạm và hai cổng cũ;
sân dùng albedo/normal/roughness 2K, không dùng displacement hình học.

## Chạy và kiểm tra

Chạy `project.godot`, chọn SOLO hoặc LAN từ menu. Host LAN dùng port 7777; client nhập IPv4 của host.

Các bài kiểm tra headless (import project, chạy mọi `tests/*_test.gd` và **năm** cặp LAN hai tiến trình, in bảng PASS/FAIL, thoát 1 nếu có lỗi). POSIX shell, từ root repo:

```sh
# Đổi thành executable Godot Standard của máy bạn; runner cũng nhận GODOT.
export GODOT="${GODOT:-godot}"
"$GODOT" --version
bash tools/run_tests.sh
"$GODOT" --headless --path . --script res://tests/combat_test.gd
```

Log mặc định `.godot/test-logs/`; cách chạy XDG cô lập và ví dụ absolute path cục bộ ở
[Hướng dẫn chạy](HUONG_DAN_CHAY.md). Không dùng progress thật để kiểm tra hỏng file/reset.

Xuất bản Windows (cần cài export templates Godot 4.7.2 qua *Editor → Manage Export Templates*):

```sh
mkdir -p build/windows
"$GODOT" --headless --path . --export-debug "Windows Desktop" build/windows/buffalo-fighting.exe
```

Đây là lệnh hướng dẫn, **chưa phải bằng chứng đã export**: audit 17/11/2026 thiếu templates
4.7.2.stable nên không export thử; cần templates tương thích, kiểm nội dung gói và chạy `.exe`
trên Windows sạch không editor/source trước nghiệm thu. Credits/provenance asset hiện tại còn
thiếu HERO, rào tre, sparse_grass; không coi các mô tả nguồn trong repo là xác nhận quyền phân phối.

LAN vẫn cần kiểm tra hai instance trên hai máy cùng mạng để nghiệm thu ENet, đồng bộ kết quả và disconnect.
R1 dual-window hiện còn mở: đã tới lobby/arena rồi tiến rất chậm trên llvmpipe, **không phải**
kết luận kết nối thất bại trước lobby. Full suite hiện được audit **80/80**, vẫn có shutdown diagnostics;
ảnh staged 720p/1080p và 100 trận AI-v-AI không thay live gameplay, target FPS hay human playtest.
Xem [ma trận nghiệm thu](production/qa/refactor-acceptance.md) và
[checklist demo](docs/REFRACTOR_DEMO_CHECKLIST.md); chưa tuyên bố toàn task/release hoàn tất.
GDD chuẩn vẫn [v0.7](docs/GDD_Choi_Trau_v0.7.md), v0.8 là draft chưa thay canonical.

Asset HERO gốc là mesh chưa rig; `buffalo_animator.gd` dựng skeleton chân/skin mềm **chỉ hình ảnh**
lúc runtime, dùng IK hai đoạn giữ móng trên đất; không phải bước chân bằng blend shape runtime.
Nhịp bước theo quãng đường thực tế (đi tới/lùi/ngang). Có thể chỉnh `gait_stride_length`, `gait_step_reach`, `gait_hoof_lift` trong `data/presentation.json`. Khi clash, chân bước ngắn theo hướng dịch chuyển thực tế (tiến/lùi), đứng yên thì trụ chân; chỉnh bằng `clash_gait_stride_length`, `clash_gait_step_reach`, `clash_gait_hoof_lift`, không đổi lực đẩy. Chuyển tiếp vào khóa sừng dùng easing; tốc độ dịch chuyển cặp trâu tăng/giảm dần theo `clash_slide_acceleration`/`clash_slide_deceleration`, hãm trước khi đảo hướng và bỏ đà bị chặn ở hàng rào. Luật tính balance, stamina và kết quả clash không đổi. Motion húc sừng có ba pha lấy lực → thúc/hất → hồi thế; chỉnh biên độ bằng `horn_visual_windup`, `horn_visual_reach`, `horn_visual_dip_deg`, `horn_visual_toss_deg` (chỉ hình ảnh, không đổi hitbox hoặc thời gian đòn). Dash có nén thân, thúc lao và hồi thế ghìm đà bằng hình ảnh; chỉnh `dash_visual_reach`, `dash_visual_dip_deg`, `dash_visual_brake_pitch_deg`, không đổi vận tốc hoặc thời gian gameplay. Trên LAN, snapshot gửi kèm tiến độ đòn và client nội suy giữa hai snapshot; nghi lễ hiện có cảnh 3D và âm thanh/decor đã triển khai, nhưng chất lượng live gameplay, hiệu năng máy mục tiêu và bản đóng gói vẫn cần nghiệm thu riêng.
