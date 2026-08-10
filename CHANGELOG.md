# Changelog — Day 12 Cloud Services & Deployment

Ghi lại thay đổi theo checkpoint để review trước khi commit. Không ghi giá trị secret vào file này.

## Unreleased

### CP1 — Config, Health & Logging

**Trạng thái:** Hoàn tất — đã xác minh bằng checkpoint.

#### Phạm vi thay đổi dự kiến

- `app/config.py`
  - Khai báo đủ 7 trường cấu hình trong `Settings`.
  - Giữ `api_token` là biến bắt buộc, không có giá trị mặc định.
  - Dùng giá trị mặc định theo specification cho các biến không nhạy cảm.
- `app/logging_utils.py`
  - Hoàn thiện `emit()` để ghi đúng một dòng JSON ra stdout.
  - Bảo đảm có `event`, `severity` viết hoa, `ts` theo ISO UTC và các field bổ sung.
- `app/main.py`
  - Hoàn thiện `GET /healthz` không nhận dependency.
  - Trả 200 cùng `status`, `service`, `version`; trả 503 khi draining.

#### Review checklist

- [x] Không hard-code `API_TOKEN` hoặc bất kỳ secret nào.
- [x] `Settings(_env_file=None)` đọc đúng biến môi trường và thiếu `API_TOKEN` gây validation error.
- [x] Một lần gọi `emit()` chỉ tạo một dòng JSON hợp lệ, không bị escape tiếng Việt.
- [x] `healthz()` không truy cập Redis hay dùng `Depends`.
- [x] `python -m pytest tests/test_cp1.py -v` pass toàn bộ 13 test.
- [ ] Đã xem `git diff -- app/config.py app/logging_utils.py app/main.py` trước khi commit.

#### Evidence cần lưu sau khi hoàn tất

```text
Lệnh: python -m pytest tests/test_cp1.py -v
Kết quả: 13 passed, 2 warnings, 0.73s
Ngày/giờ: 2026-08-10
Commit: `Checkpoint 1: config, logging, healthz`
```

## CP0 — Setup & Baseline

**Trạng thái:** Done.

- Repository đúng tên, đang ở branch `main`.
- `.env` được Git ignore và không bị track.
- `API_TOKEN` và `REDIS_URL` đã được cấu hình cục bộ (giá trị không được ghi lại).
- Redis phản hồi PING thành công.
- Python/pytest chạy được; baseline thu thập 101 test non-Docker.
