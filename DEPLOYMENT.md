# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `python -m pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyễn Xuân Quang |
| Mã học viên | 2A202601776 |
| Repo | https://github.com/Mrgintamago/K4-DAY12-2A202601776-NguyenXuanQuang |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://chat-production-43e3.up.railway.app |
| Platform | Railway |
| Ngày deploy | 2026-08-10 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `API_TOKEN` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | Redis service trong cùng Railway project |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |
| `LLM_PROVIDER` | ✅ | mock (không gọi API bên ngoài) |

## Lệnh Kiểm Tra

Public URL: `https://chat-production-43e3.up.railway.app`

```powershell
# 1. Liveness — mong đợi 200 {"status":"ok"}
Invoke-WebRequest -Uri "https://chat-production-43e3.up.railway.app/healthz" -Method Get

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
Invoke-WebRequest -Uri "https://chat-production-43e3.up.railway.app/readyz" -Method Get

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
Invoke-WebRequest -Uri "https://chat-production-43e3.up.railway.app/chat" -Method Post `
  -ContentType "application/json" -Body '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
$headers = @{
  Authorization = "Bearer $env:API_TOKEN"
  "X-Client-Id" = "sv-test"
}
$payload = @{ message = "Deploy là gì?" } | ConvertTo-Json -Compress
$requestBody = [System.Text.Encoding]::UTF8.GetBytes($payload)
Invoke-RestMethod -Uri "https://chat-production-43e3.up.railway.app/chat" -Method Post `
  -Headers $headers -ContentType "application/json; charset=utf-8" -Body $requestBody

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
$rateBody = [System.Text.Encoding]::UTF8.GetBytes((@{ message = "test" } | ConvertTo-Json -Compress))
1..15 | ForEach-Object {
  try {
    (Invoke-WebRequest -Uri "https://chat-production-43e3.up.railway.app/chat" -Method Post `
      -Headers $headers -ContentType "application/json; charset=utf-8" -Body $rateBody).StatusCode
  } catch {
    $_.Exception.Response.StatusCode.value__
  }
}
```

## Kết Quả Chạy Thật

Dán output của các lệnh trên vào đây:

```
healthz: 200 {"status":"ok"}
readyz: 200 {"status":"ready","redis":true}
chat không token: 401 Unauthorized
chat có token: 200 (reply trả về bình thường)
rate limit burst 15 request: 200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/healthz.png` — kết quả gọi `/healthz` từ trình duyệt hoặc PowerShell

