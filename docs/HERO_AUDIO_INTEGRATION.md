# Tích hợp model HERO và soundtest

## Đánh giá

- Nguồn: `assets/blender/ancient_east_water_buffalo_HERO.blend`, giữ nguyên nội dung nguồn.
- Hai mesh, tổng 177.132 tam giác (thân 166.924); không armature, không animation action. Texture được packed, không phụ thuộc các đường dẫn Windows trong nguồn.
- Bản gameplay: `assets/characters/buffalo_hero/buffalo_hero.glb`, 31.810 tam giác, cao khoảng 2,115 m. Có texture base color, normal, ORM và khăn. GLB khoảng 13 MB, nặng hơn model cũ; chưa benchmark FPS/GPU.
- Đầu nguồn hướng Blender +Y, khi export thành Godot -Z. Scale đồng đều và đặt chân ở Y≈0; không đổi collision/balance để giữ luật chơi.
- Model cũ ở `assets/characters/buffalo/buffalo.glb` được giữ nguyên để dự phòng. Muốn quay lại, đổi PackedScene trong `scenes/buffalo.tscn`.
- Tai/đuôi gộp vào thân: chỉ giữ animation procedural toàn thân (thở, nghiêng, lao, phản lực...). Chưa có animation bước chân theo khớp hay tai/đuôi độc lập. Không tự động rig trong đợt này.
- Hai slot dùng khăn Đông/Tây khác nhau; nhãn màu/số hiện có vẫn được giữ.

## Âm thanh

ZIP nguồn (`Sound-20261103T033158Z-1-001.zip`) chỉ giữ local ở `assets/audio/source/`, không commit; 20 file audio đã giải nén (trùng byte với ZIP) nằm trong `assets/audio/`. Ảnh hướng dẫn âm thanh đi kèm ZIP lưu ở `docs/SOUND_GUIDE.png`.

- 17 WAV PCM 16-bit và 3 OGG Vorbis, tất cả 48 kHz, độ dài hợp lệ. Nhạc nền 80 giây; loop khóa sừng 0,83 giây.
- `GameAudio` autoload tạo bus Music/SFX và pool 16 giọng, nhạc nền xuyên scene. Slider âm lượng hiện có điều khiển các bus này.
- `match_audio.gd` quan sát phase/state/displacement: đếm ngược, bắt đầu, kết quả theo local slot, khóa sừng, chuẩn bị húc, dash và bước chân đất/bùn. Host/SOLO dùng combat_event cho va chạm; LAN client dùng giảm SPIRIT trong snapshot làm fallback.
- Khóa sừng dừng khi kết thúc, tạm ngưng khi pause. Nhạc và UI tiếp tục khi mở pause.
- Button tự phát confirm/back; mất kết nối phát error. Tiếng rào hiện gắn vào đòn đánh khi đối thủ bị pinned, chưa gắn mọi va chạm rào.
- Client LAN fallback chưa phân biệt hoàn hảo mọi đòn/đỡ; chưa bổ sung giao thức mạng truyền sự kiện âm thanh. Hiệu ứng hiện là 2D, chưa spatial audio.
- Gain và nhịp bước chỉnh tại `data/audio.json`. Nhạc thắng/thua phát một lần, nhạc lễ hội và khóa sừng phát lặp.
- Chưa nghe kiểm chứng chất lượng/điểm nối loop, chưa xác nhận nội dung giọng đọc hay giấy phép asset. Cần nghe thử và xác nhận quyền sử dụng trước khi phát hành.

## Tái tạo và kiểm tra

```sh
blender --background assets/blender/ancient_east_water_buffalo_HERO.blend --python tools/export_hero_buffalo.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/hero_audio_test.gd
```

Tắt import trực tiếp `.blend` trong project để máy chạy Godot không cần cài Blender; export GLB bằng script riêng. Texture và các file `.import`/`.uid` sinh ra phải được giữ trong git.

Đã chạy 15 test: hero_audio, animation, buffalo_asset (model dự phòng), combat, movement, collision, clash_pose, clash_pinned, lan_snapshot, pause, ai, gdd_smoke, session, tpp, network_manager. Tất cả exit 0, không lỗi script/assertion. Một số test có cảnh báo ObjectDB/resource còn tồn khi thoát, chưa xử lý triệt để. Chưa chạy thử LAN hai process với audio hoặc kiểm chứng hình ảnh/âm thanh trực tiếp trong cửa sổ game; headless không chứng minh chất lượng hiển thị/nghe.
