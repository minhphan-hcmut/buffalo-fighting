# Hướng dẫn chạy game *Chọi trâu: Đấu trường lễ hội*

Game chưa đóng gói thành file `.exe`, nên cần chạy từ mã nguồn bằng Godot. Làm theo một trong
hai cách dưới đây; nếu bạn nhờ AI agent (Claude Code, Codex, ...) chạy giúp, chỉ cần đưa nó
file này và bảo "làm theo mục Dành cho AI agent".

## 1. Cần chuẩn bị

| Thứ cần | Ghi chú |
|---|---|
| **Godot 4.7.2 – bản Standard** | Tải ở <https://godotengine.org/download/archive/4.7.2-stable/>. **Không** dùng bản .NET/C#. Bản 4.7.x khác cũng chạy được; bản 4.6 trở xuống thì không. |
| Git | Để tải mã nguồn. Hoặc tải ZIP trên GitHub (*Code → Download ZIP*). |
| Card đồ họa hỗ trợ OpenGL 3.3 | Game dùng renderer *Compatibility*, máy văn phòng/laptop thường đều được. |

Godot là một file chạy duy nhất, không cần cài: giải nén ra là dùng.
Không cần Blender, Python hay thư mục `.claude/` để chơi.

## 2. Cách nhanh: dùng giao diện Godot

1. Tải mã nguồn:
   ```sh
   git clone https://github.com/minhphan-hcmut/buffalo-fighting.git
   ```
2. Mở Godot → **Import** → chọn file `buffalo-fighting/project.godot` → **Import & Edit**.
3. Lần đầu Godot sẽ nhập tài nguyên (model, texture, âm thanh), mất khoảng 1–3 phút. Chờ thanh
   tiến trình ở góc dưới chạy xong.
4. Nhấn **F5** (hoặc nút ▶ góc trên bên phải) để vào game.

## 3. Cách chạy bằng dòng lệnh

Thay `godot` bằng đường dẫn tới file Godot của bạn nếu nó chưa có trong PATH, ví dụ
`"C:\Tools\Godot_v4.7.2-stable_win64.exe"`.

```sh
git clone https://github.com/minhphan-hcmut/buffalo-fighting.git
cd buffalo-fighting
godot --headless --path . --import    # chỉ cần lần đầu: nhập tài nguyên, tự thoát khi xong
godot --path .                         # mở game ở menu chính
```

## 4. Dành cho AI agent

Mục tiêu: mở cửa sổ game cho người dùng xem. Làm đúng thứ tự:

1. **Tìm Godot 4.7.x Standard.** Thử `godot --version`. Nếu không có, tìm file
   `Godot_v4.7*-stable_*` (Windows: `*.exe`, không phải bản `_console`; macOS: `Godot.app`;
   Linux: `*.x86_64`) trong thư mục Downloads/Desktop/Program Files. Không thấy thì nhờ người dùng
   tải ở link trong mục 1 rồi giải nén; đừng tự cài bản khác 4.7.x.
2. Kiểm tra phiên bản bắt đầu bằng `4.7` và **không** có chữ `mono`.
3. Clone repo (mục 3) nếu chưa có; nếu đã có thì `git pull` trên nhánh `main`.
4. Chạy `godot --headless --path <repo> --import` và chờ lệnh tự thoát (lần đầu vài phút).
   Dòng cảnh báo `WARNING`/`ObjectDB leaked` khi thoát là bình thường, không phải lỗi.
5. Chạy `godot --path <repo>` **không** kèm `--headless`, để chạy nền/không chặn terminal.
   Một cửa sổ 1280×720 mở ra ở menu chính là thành công.
6. Không sửa file nào trong repo, không chạy Blender hay MCP, không commit.
7. Muốn kiểm tra nhanh mà không mở cửa sổ: `bash tools/run_tests.sh` (cần Git Bash trên Windows),
   dòng cuối phải là `N checks, 0 failed`.

## 5. Điều khiển (bàn phím + chuột)

| Phím | Tác dụng |
|---|---|
| `W A S D` | Đi theo hướng camera |
| Chuột | Xoay camera/hướng trâu |
| Chuột trái | **Húc** |
| `Space` | **Hổ lao** (lao tới) |
| `G` | **Gạt sừng** (đúng lúc thì phản đòn) |
| Giữ chuột phải | **Ghìm** (đỡ đòn) |
| Khi khóa sừng | `W A S D` đẩy tới · chuột trái **Móc** · chuột phải **Nhả** |
| `Esc` | Tạm dừng, mở Cài đặt; click chuột trái để khóa chuột lại |
| `F12` | Chụp màn hình |

Luật ngắn gọn: hạ **khí thế** đối thủ về 0 để nó lui sới (thắng). Hết 90 giây thì bên khí thế cao
hơn thắng. Mọi đòn tốn **sức**, nghỉ thì hồi. Chi tiết xem **Cách chơi** trong menu.

## 6. Nên thử gì

- **Sân tập**: tập từng đòn, không thua. Nên vào đây trước nếu mới chơi.
- **Solo · Mùa hội**: 5 vòng từ Vòng loại tới Chung kết, đối thủ AI mạnh dần, có Phần Lễ.
- **Đấu tự do**: chọn thẳng 1 trong 5 vòng.
- **LAN**: hai máy cùng mạng. Một máy *Tạo phòng* (port 7777), máy kia *Vào phòng* bằng địa chỉ
  IPv4 của máy tạo (xem bằng `ipconfig` trên Windows).

## 7. Gặp lỗi

| Hiện tượng | Cách xử lý |
|---|---|
| Godot báo project của phiên bản mới hơn / lỗi script lúc mở | Sai phiên bản. Dùng đúng Godot 4.7.x Standard. |
| Báo lỗi C#/.NET | Đang dùng bản .NET, đổi sang bản Standard. |
| Màn hình đen, báo lỗi OpenGL | Cập nhật driver card đồ họa; laptop 2 GPU thì chọn GPU rời cho Godot. |
| Thiếu texture/model, màu hồng | Tài nguyên chưa nhập xong: chạy lại lệnh `--import` hoặc mở bằng giao diện và chờ. |
| Game giật | `Esc` → Cài đặt → Đồ họa → chọn **Thấp**. |
| LAN không vào được phòng | Cùng mạng Wi-Fi/LAN; cho phép Godot qua Windows Firewall (mạng Private); nhập đúng IPv4. |
