# Khai báo sử dụng công cụ AI

Theo GDD v0.7 §6.7 và quy định môn học, file này khai báo mọi chỗ nhóm dùng công cụ AI
cho code, văn bản và asset của *Chọi trâu: Đấu trường lễ hội*.

> Các dòng có **[NHÓM ĐIỀN]** là thông tin chỉ nhóm biết; cần điền trước khi nộp.

## 1. Công cụ đã dùng

| Công cụ | Dùng vào việc gì | Ai điều khiển |
|---|---|---|
| Claude Code (Anthropic) | Đọc GDD, lập kế hoạch, viết và review code GDScript, viết test headless, sửa lỗi, viết tài liệu kỹ thuật (`docs/ARCHITECTURE.md`, README), soạn spec giao việc cho Codex | Thành viên nhóm ra yêu cầu và duyệt từng đợt |
| OpenAI Codex (qua Orca) | Làm các phần việc có phạm vi rõ theo spec: tính năng UI/cài đặt, VFX, tối ưu hiệu năng, test, chụp ảnh kiểm tra | Claude Code giao spec; nhóm duyệt kết quả |
| Blender MCP | Dựng/chỉnh model low-poly bằng script Python trong Blender (`tools/build_*.py`, `polish_*`, `restyle_*`) | Thành viên nhóm |
| Godot MCP | Thao tác editor/scene, chạy và chụp màn hình game khi kiểm tra | Thành viên nhóm |
| Orca | Điều phối: mở worker Codex, chuyển spec/báo cáo, theo dõi quota | Claude Code, nhóm giám sát |
| **[NHÓM ĐIỀN]** công cụ khác (ví dụ ChatGPT, công cụ tạo ảnh/3D) | | |

## 2. Phần nào có AI tham gia

- **Code gameplay, AI đối thủ, mạng LAN, UI, VFX, âm thanh (`scripts/`)**: phần lớn được viết
  với sự hỗ trợ của Claude Code và Codex, theo luật trong GDD do nhóm thiết kế.
- **Test (`tests/`, `tools/run_tests.sh`)**: viết với AI; nhóm chạy lại toàn bộ trước khi merge.
- **Công cụ kiểm thử** (`tools/balance_sim.gd` mô phỏng AI đấu AI, `tools/lan_netem_proxy.py` giả lập mạng kém): AI viết; chỉ dùng để đo, không tự đổi luật.
- **Dữ liệu cân bằng (`data/*.json`)**: con số ban đầu theo GDD; AI đề xuất chỉnh, nhóm quyết định.
- **Văn bản trong game** (hướng dẫn, thẻ "Bạn có biết?", lời loa): AI soạn nháp, nhóm duyệt
  nội dung văn hóa.
- **Bản tiếng Anh** (`data/lang/en.po`): Claude Code dịch từ chữ tiếng Việt; nhóm duyệt.
- **Chuyển động trâu** (bộ xương dựng lúc chạy, cổ/hông có lò xo): Claude Code viết code; model gốc không đổi.
- **Ảnh màn chờ** `assets/ui/loading_arena.jpg`: chụp từ chính game, không do mô hình sinh ảnh tạo.
- **Tài liệu**: GDD do nhóm viết; `docs/ARCHITECTURE.md`, README, `HUONG_DAN_CHAY.md`, `docs/CHANGELOG_GDD.md`,
  `design/game-brief.md` và file này do AI soạn từ code, nhóm duyệt.
- **Âm thanh tự tổng hợp** (`tools/gen_combat_sfx.py`): tạo bằng code, không dùng mô hình sinh âm thanh.

## 3. Asset

Nguồn và giấy phép của từng asset ghi ở `docs/ASSET_CREDITS.csv` (cột `ai_generated`).
Asset bên ngoài đều là CC0 (Kenney, Quaternius, Poly Haven), không do AI tạo.

- Model trâu HERO `assets/characters/buffalo_hero/` (nguồn `assets/blender/ancient_east_water_buffalo_HERO.blend`):
  **[NHÓM ĐIỀN]** nguồn gốc, có dùng công cụ AI tạo 3D/texture không. Đồng thời thêm dòng vào `ASSET_CREDITS.csv`.
- Ảnh tham khảo `references/vietnamese_buffalo_concept.png`: **[NHÓM ĐIỀN]** ảnh chụp/vẽ tay hay do AI tạo.
- Model trâu cũ `assets/characters/buffalo/` (không còn dùng trong game): dựng bằng script Blender qua Blender MCP.

## 4. Nhóm kiểm soát kết quả AI thế nào

- Mọi thay đổi chạy qua bộ test headless (`bash tools/run_tests.sh`) và phải xanh trước khi commit.
- Thay đổi người chơi nhìn thấy được thì chạy game thật và chụp ảnh kiểm tra.
- Mỗi đợt việc của Codex có spec ghi rõ file được sửa và bằng chứng hoàn thành;
  Claude Code review và chạy lại test; thành viên nhóm duyệt và quyết định commit.
- Luật chơi, quyết định thiết kế và nội dung văn hóa do nhóm quyết; AI không tự đổi GDD.
- Commit không có dòng ghi công AI tự động; việc dùng AI được khai báo tập trung ở file này.
