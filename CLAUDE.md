# Chọi trâu: Đấu trường lễ hội — Claude Code

Quy định chung cho mọi AI agent (cấu trúc thư mục, quy ước code, test, commit)
nằm ở `AGENTS.md`. Đọc file đó trước; khi hai file khác nhau, `AGENTS.md` thắng.

@AGENTS.md

## Claude Code Game Studios (CCGS)

Repo này là project root của studio. Cấu hình studio nằm ở `project.yaml`.
Thư mục `.claude/` (agents, skills, hooks, rules, docs) và `docs/engine-reference/`
**không được commit**: mỗi máy tự liên kết chúng tới bản CCGS cục bộ. Trên Windows,
với CCGS đặt ở thư mục cha (`..`):

```powershell
New-Item -ItemType Directory -Force .claude
foreach ($d in 'agents','docs','hooks','rules','scripts','skills') {
  New-Item -ItemType Junction -Path ".claude\$d" -Target "..\.claude\$d" }
foreach ($f in 'settings.json','statusline.sh') {
  New-Item -ItemType HardLink -Path ".claude\$f" -Target "..\.claude\$f" }
New-Item -ItemType Junction -Path docs\engine-reference -Target ..\docs\engine-reference
```

Khi chưa có `.claude/`, các skill và hook của studio không chạy; repo vẫn build và
test bình thường.

### Lệch so với mặc định của CCGS

- **Code root là `scripts/`, không phải `src/`.** Godot không bắt buộc `src/`.
  Các hook và skill của studio tìm code ở `src/` nên có thể báo "no source code";
  bỏ qua cảnh báo đó, đừng chuyển code sang `src/`.
- **Test là script headless tự viết**, không dùng gdUnit4. Chạy toàn bộ bằng
  `bash tools/run_tests.sh` (xem `README.md`).
- **Thiết kế:** GDD chuẩn là `docs/GDD_Choi_Trau_v0.7.md`; `design/game-brief.md`
  là bản tóm tắt dựng ngược từ code cho các skill của studio.

## Quy tắc làm việc

- Hỏi trước khi ghi file; thay đổi nhiều file cần người dùng duyệt cả bộ.
- Không commit khi chưa được yêu cầu. Commit theo `AGENTS.md` (không thêm trailer
  ghi công AI).
- Mọi thay đổi người chơi nhìn thấy được phải chạy game và lưu ảnh chụp vào
  `production/qa/evidence/`.
