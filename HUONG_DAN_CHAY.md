# Hướng dẫn chạy game *Chọi trâu: Đấu trường lễ hội*

Game chưa đóng gói thành file `.exe`, nên cần chạy từ mã nguồn bằng Godot. Làm theo một trong
hai cách dưới đây; nếu bạn nhờ AI agent (Claude Code, Codex, ...) chạy giúp, chỉ cần đưa nó
file này và bảo "làm theo mục Dành cho AI agent".

## 1. Cần chuẩn bị

| Thứ cần | Ghi chú |
|---|---|
| **Godot 4.7.2 – bản Standard** | Tải ở <https://godotengine.org/download/archive/4.7.2-stable/>. **Không** dùng bản .NET/C#. 4.7.2 là bản đã kiểm chứng; chưa bảo đảm các bản khác. |
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

Thay `godot` bằng đường dẫn tới file Godot Standard của bạn nếu chưa có trong PATH.
Ví dụ POSIX shell dưới đây dùng biến `GODOT`; PowerShell dùng `$env:GODOT` và gọi
`& $env:GODOT --path .` (ví dụ executable Windows `C:\Tools\Godot_v4.7.2-stable_win64.exe`).

```sh
git clone https://github.com/minhphan-hcmut/buffalo-fighting.git
cd buffalo-fighting
export GODOT="${GODOT:-godot}"          # hoặc absolute path executable đã giải nén
"$GODOT" --version                    # mong đợi 4.7.2 Standard, không mono
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --path .                     # mở game ở menu chính
```

## 4. Dành cho AI agent

Mục tiêu: mở cửa sổ game cho người dùng xem. Làm đúng thứ tự:

1. **Tìm Godot 4.7.2 Standard.** Thử `godot --version`. Nếu không có, tìm file
   `Godot_v4.7*-stable_*` (Windows: `*.exe`, không phải bản `_console`; macOS: `Godot.app`;
   Linux: `*.x86_64`) trong thư mục Downloads/Desktop/Program Files. Không thấy thì nhờ người dùng
   tải ở link trong mục 1 rồi giải nén; đừng tự cài bản khác 4.7.x.
2. Kiểm tra đúng `4.7.2` và **không** có chữ `mono`; không mặc định bản 4.7.x khác tương đương.
3. Clone repo (mục 3) nếu chưa có; nếu đã có thì kiểm `git status`, không tự pull/ghi đè edits người dùng.
4. Chạy `"$GODOT" --headless --path <repo> --editor --import --quit` và đợi exit.
   Kiểm exit và Parse Error/SCRIPT ERROR. ObjectDB/resources shutdown diagnostics hiện còn là
   nợ đã ghi nhận, không bỏ qua mọi ERROR chỉ vì process exit 0.
5. Chạy `"$GODOT" --path <repo>` **không** kèm `--headless`; theo dõi PID do mình tạo.
   Cửa sổ menu 1280×720 chỉ chứng minh startup; kiểm input/focus/resize/quit riêng, không
   gọi đó là nghiệm thu gameplay hay release. Nếu người dùng cần chơi, giữ app cuối hoạt động.
6. Không sửa file nào trong repo, không chạy Blender hay MCP, không commit.
7. Chạy full headless bằng `GODOT="$GODOT" bash tools/run_tests.sh` (cần shell thích hợp;
   Windows có thể dùng Git Bash và các tiện ích runner cần). Runner chạy năm cặp LAN,
   không phải chỉ hai; kiểm exit và log, không chỉ dòng cuối. Latest audited gate 80/80,
   còn shutdown diagnostics và các gates live/build/performance ở checklist dưới.

### Ví dụ cục bộ đã dùng trong đợt refactor (không phải đường dẫn portable)

```sh
cd /home/konits/projects/ltrgame/buffalo-fighting
export GODOT=/home/konits/projects/Godot/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --version
# Linux QA: dữ liệu tạm, không dùng settings/notebook người chơi thật.
QA=$(mktemp -d /tmp/ltrgame-doc-example.XXXXXX)
mkdir -p "$QA"/{data,config,cache,logs}
env XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache" \
  GODOT="$GODOT" TEST_LOG_DIR="$QA/logs" TEST_TIMEOUT=180 \
  timeout 3600 bash tools/run_tests.sh > "$QA/runner.log" 2>&1
rc=$?; printf 'runner exit=%s; logs=%s\n' "$rc" "$QA"
```

Đây là **lệnh mẫu tái lập**, không phải lần chạy mới từ tài liệu. Giữ log/exit, kiểm process
thuộc run đã kết thúc rồi mới xóa data/config/cache của QA; không xóa user:// thật hay `.godot`
dùng chung. XDG là ví dụ Linux; máy khác cần vùng user-data thử riêng và kiểm vị trí thực tế.

### Export/demo chưa được nghiệm thu

Preset `Windows Desktop` xuất x86_64 với embedded PCK. Cần cài templates **4.7.2.stable**
được cho phép trước, rồi `mkdir -p build/windows` và chạy
`"$GODOT" --headless --path . --export-debug "Windows Desktop" build/windows/buffalo-fighting.exe`.
Audit 17/11 thiếu templates; **chưa export thử**, chưa có bản Windows sạch được nghiệm thu.
Export thành công cũng chưa đủ: kiểm gói tài nguyên/credits và chạy trên Windows không
editor/source, đo hiệu năng/input trên phần cứng mục tiêu. Provenance HERO/rào tre/sparse_grass
còn thiếu, cần owner xác minh trước phân phối; không tự điền license.

Xem [ma trận nghiệm thu](production/qa/refactor-acceptance.md) và
[demo/playtest checklist](docs/REFRACTOR_DEMO_CHECKLIST.md). R1 actual dual-window LAN còn mở:
lobby/arena đã mount rồi tiến chậm trên llvmpipe, chưa rõ root cause; không đồng nhất với lỗi
firewall/pre-lobby. Ảnh staged và headless pass không thay được kiểm live hai máy.

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
