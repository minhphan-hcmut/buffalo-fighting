# Chọi trâu — Tóm tắt triển khai

**Nguồn thiết kế:** [GDD Skeleton Chọi Trâu v0.4](GDD_Skeleton_Choi_Trau_v0.4.docx). DOCX là tài liệu thiết kế chuẩn; trang này chỉ tóm tắt đối chiếu với repo, không thay thế hay sao chép GDD.

## Định hướng

GDD v0.4 xác định game đối kháng hư cấu phong cách **3D low-poly**, góc nhìn thứ ba nghiêng 45°; gameplay diễn ra trên mặt phẳng XZ. Trải nghiệm được trình bày theo hướng 2.5D góc nhìn 45° như yêu cầu, trên scene/nhân vật 3D, không phải game thuần 2D.

Thiết kế đặt trận đấu trong không khí lễ hội Việt Nam, gồm Phần Lễ trang trọng và phần thi đấu; nội dung cần tiết chế, không gore, không cá cược và không mô phỏng hiến sinh. Solo được thiết kế thành ba chặng vòng loại, bán kết, chung kết với AI tăng độ khó.

## Hiện trạng repo

- Đã có camera bám trâu, pitch 45°, chuột xoay ngang; điều khiển và chiến đấu 3D gồm HORN, DASH, GUARD, SPIRIT/STAMINA và CLASH.
- Đã có cấu hình ba level Solo, profile AI EASY/NORMAL/HARD, retry trận hiện tại, mở trận kế khi thắng và trở về menu mà không xóa tiến trình trong phiên.
- Menu Solo có màn khai hội tĩnh một lần mỗi phiên. Màn kết quả đọc winner/reason từ session state, đưa lựa chọn chơi lại, đi tiếp khi thắng hoặc về menu; thắng chung kết hiển thị lời kết tĩnh về rước ông trâu vô địch về đình và khép mùa hội.
- Các màn nghi lễ SHOULD, hình minh họa nghi lễ, hoạt cảnh dắt-thả trâu, âm thanh và cảnh trâu lui sới/chào khán giả vẫn chưa được triển khai trong phạm vi này.

Đây là ảnh chụp phạm vi triển khai theo repo hiện tại; yêu cầu, số liệu và nghi lễ trong DOCX vẫn là thiết kế, không mặc nhiên là tính năng đã hoàn tất hoặc đã được playtest.

**Mismatch tài liệu có sẵn:** [Game-Design-Document.md](Game-Design-Document.md) vẫn là draft v0.1 với định hướng 2D, HP/KO và RING_OUT; các điểm này xung đột với v0.4 (3D, SPIRIT/FLEE và PINNED). Trong phạm vi cập nhật này, xem DOCX v0.4 là nguồn thiết kế chuẩn; draft cũ chưa được sửa.
