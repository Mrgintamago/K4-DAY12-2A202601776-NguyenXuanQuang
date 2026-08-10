# Nhật ký thay đổi — Day 12 Cloud Services & Deployment

Ghi lại thay đổi theo checkpoint để review trước khi commit. Không ghi giá trị secret vào file này.

## Chưa phát hành

### Tùy chọn nhà cung cấp AI Box / DeepSeek

- Thêm `LLM_PROVIDER`, endpoint/model/key AI Box, timeout và các biến cấu hình đơn giá token.
- Thêm luồng gọi AI Box tương thích OpenAI; `mock` vẫn là nhà cung cấp mặc định.
- Không thêm API key vào source control hoặc file môi trường cục bộ.

### CP2 — Docker runtime an toàn

- Thay image một stage bằng Dockerfile builder/runtime dùng `python:3.11-slim`.
- Cài dependencies trước khi copy code; runtime chỉ nhận package đã cài và source cần thiết.
- Thêm user không phải root `appuser`, Docker healthcheck `/healthz` và khởi động Uvicorn với `${PORT:-8000}`.
- Thêm service Compose `chat` phụ thuộc Redis, nội suy biến môi trường an toàn và healthcheck.
- Loại `.env`, môi trường ảo, cache và Git metadata khỏi Docker build context.
- Xác minh: `python -m pytest tests/test_cp2.py -v` có 16/16 test pass, gồm build image và kiểm tra kích thước.
- Đo thực tế cho reflection: image một stage `day12-chat:single` là 1.73 GB; image multi-stage `day12-chat:multi` là 270 MB.
- Thí nghiệm cache cho reflection: sau khi chỉ thêm một comment trong `app/main.py`, layer `COPY requirements.txt` và `RUN pip install` là `CACHED`; layer copy source chạy lại. Comment thử nghiệm đã được xóa.

### CP3 — Bảo mật API và kiểm soát chi phí

- Cài xác thực Bearer theo RFC 6750, so sánh token constant-time và trả 401 kèm `WWW-Authenticate`.
- Cài token bucket Redis theo từng client, gồm refill, capacity cap, TTL và `Retry-After` khi trả 429.
- Cài cost guard theo client/ngày, gồm kiểm tra trước LLM, cộng dồn chi phí và trả 402 khi vượt hạn mức.
- Hoàn thiện luồng `/chat`: auth → rate limit → budget → LLM → record chi phí → JSON log.
- Xác minh: chạy `LLM_PROVIDER=mock` tạm thời khi test để không gọi AI Box; `tests/test_cp3.py` có 29/29 test pass.
- Regression: CP1–CP3 chạy cùng Docker build thật có 58/58 test pass.

### CP4 — Mở rộng và độ tin cậy

- Chuyển lịch sử hội thoại sang Redis List theo từng client, giữ tối đa 12 message mới nhất và đặt TTL ba ngày.
- Thêm `ping()` an toàn, không để lỗi Redis thoát thành lỗi HTTP 500.
- Hoàn thiện `/readyz` để phản ánh Redis và trạng thái draining.
- Cài graceful draining cho SIGTERM/SIGINT, giữ và gọi lại handler trước đó của Uvicorn.
- Xác minh: `LLM_PROVIDER=mock` cùng `tests/test_cp4.py` có 19/19 test pass.

### CP5 — Deploy Railway

- Tạo project `day12-chat`, Redis service và service `chat` trên Railway.
- Đặt biến runtime trên dashboard; dùng `LLM_PROVIDER=mock` để smoke test không gọi API ngoài.
- Sửa `railway.toml` để expand `$PORT` qua `sh -c`; deployment lần hai thành công.
- Public URL: `https://chat-production-43e3.up.railway.app`.
- Smoke test: `/healthz` 200, `/readyz` 200, `/chat` không token 401, có token 200; burst 15 request cho 5 lần 429 cuối.
- Xác minh: `tests/test_cp5.py` có 9 passed, 4 skipped (fallback không áp dụng).

### Bonus — CI/CD GitHub Actions

- Thêm `.github/workflows/ci.yml` chạy khi push và pull request vào `main`.
- Job `test` cài `requirements.txt` và loại test cần deployment thật; job `build` kiểm tra Docker image.
- Job `deploy` chỉ chạy sau `test` và `build`, chỉ ở push `main`, rồi smoke test `/healthz`.
- Thêm CI badge vào `README.md`; cần khai báo `RAILWAY_TOKEN` (Secret), `RAILWAY_PROJECT_ID` và `PUBLIC_URL` (Variables) trên GitHub.
- Xác minh local: 11/11 kiểm tra cấu trúc bonus pass; badge cần workflow chạy thật trên GitHub.

### CP1 — Config, Health & Logging

**Trạng thái:** Hoàn tất — đã xác minh bằng checkpoint.

#### Thay đổi đã thực hiện

- `app/config.py`
  - Khai báo đủ 7 trường cấu hình trong `Settings`.
  - Giữ `api_token` là biến bắt buộc, không có giá trị mặc định.
  - Dùng giá trị mặc định theo đặc tả cho các biến không nhạy cảm.
- `app/logging_utils.py`
  - Hoàn thiện `emit()` để ghi đúng một dòng JSON ra stdout.
  - Bảo đảm có `event`, `severity` viết hoa, `ts` theo ISO UTC và các trường bổ sung.
- `app/main.py`
  - Hoàn thiện `GET /healthz` không nhận dependency.
  - Trả 200 cùng `status`, `service`, `version`; trả 503 khi draining.

#### Danh sách kiểm tra review

- [x] Không hard-code `API_TOKEN` hoặc bất kỳ secret nào.
- [x] `Settings(_env_file=None)` đọc đúng biến môi trường và thiếu `API_TOKEN` gây lỗi validation.
- [x] Một lần gọi `emit()` chỉ tạo một dòng JSON hợp lệ, không escape tiếng Việt.
- [x] `healthz()` không truy cập Redis hay dùng `Depends`.
- [x] `python -m pytest tests/test_cp1.py -v` pass toàn bộ 13 test.
- [x] Đã xem `git diff -- app/config.py app/logging_utils.py app/main.py` trước khi commit.

#### Bằng chứng sau khi hoàn tất

```text
Lệnh: python -m pytest tests/test_cp1.py -v
Kết quả: 13 passed, 2 warnings, 0.73s
Ngày/giờ: 2026-08-10
Commit: `4ac68e7 Checkpoint 1: config, logging, healthz`
```

## CP0 — Thiết lập & kiểm tra nền

**Trạng thái:** Hoàn tất.

- Repository đúng tên, đang ở nhánh `main`.
- `.env` được Git bỏ qua và không bị theo dõi.
- `API_TOKEN` và `REDIS_URL` đã được cấu hình cục bộ (giá trị không được ghi lại).
- Redis phản hồi PING thành công.
- Python/pytest chạy được; kiểm tra nền thu thập 101 test non-Docker.
