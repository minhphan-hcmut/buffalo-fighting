# Refactor có kiểm chứng theo rubric

## Quyết định đã được duyệt
Người dùng duyệt refactor chọn lọc HUD, menu và API controller; tạo module con và test; cập nhật kiến trúc/GDD/tài liệu; tiếp tục hồi quy → playtest và cân bằng có bằng chứng → build/demo. Điều phối qua Orca. Không commit.

## Mục tiêu
Tách trách nhiệm để dễ kiểm tra và vấn đáp, giữ hành vi game trong giai đoạn refactor. Không viết lại combat, physics, networking hay animator. Không thay đổi số liệu trong commit/changeset refactor. SessionState vẫn là nguồn tiến trình duy nhất.

## Các hướng đã cân nhắc
A chỉ nghiệm thu: ít rủi ro nhưng giữ UI tập trung. B refactor chọn lọc + nghiệm thu: được chọn. C viết lại kiến trúc: loại do không có bằng chứng cần thiết và rủi ro hồi quy cao.

## Ranh giới
- HUD: tách tutorial, training, pause/settings và kết quả LAN; giữ cập nhật thanh tài nguyên/đồng hồ/CLASH và ghép module.
- Menu: tách lựa chọn chế độ, kết quả/thẻ văn hóa, điều phối Solo; không nhân bản SessionState.
- Controller: API công khai thay truy cập chi tiết nội bộ HUD; giữ thứ tự tick và payload LAN.
- Các module sở hữu node/signal/tween phải giải phóng theo scene, không callback sau free.

## Nghiệm thu
Baseline trước sửa; regression sau từng nhóm; kiểm tra render và input thật 720p/1080p. Solo trọn mùa, retry, training/free play, replay, settings/pause; LAN pause/rematch/disconnect. Kiểm tra dữ liệu người chơi bằng đường dẫn cô lập. Không giảm coverage để xanh test.
Cân bằng chỉ đổi sau số liệu/quan sát; ghi trước/sau, chạy lại mô phỏng và cập nhật GDD. Agent playtest không thay thế người ngoài nhóm.
Build độc lập và đo FPS trên cấu hình ghi rõ; nếu thiếu runtime/templates/máy mục tiêu thì báo blocker, không tuyên bố đạt rubric.

## Quyền sở hữu và an toàn
Main tích hợp và debug runtime. Orca worker nhận nhiệm vụ giới hạn; reviewer độc lập. Không hai writer cùng file. Sau hai lần sửa cùng lỗi thất bại main tự điều tra. Theo dõi và thu hồi tài nguyên thuộc nhiệm vụ.
File docs/GDD_Choi_Trau_v0.8.md xuất hiện untracked trước khi bắt đầu: bảo toàn, không ghi đè; cần đọc trước khi quyết định tài liệu chuẩn.
