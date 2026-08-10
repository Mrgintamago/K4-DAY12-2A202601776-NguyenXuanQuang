# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: ..........................  Mã học viên: ..........................

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi chạy test `test_thieu_api_token_thi_fail_fast`, việc bỏ `API_TOKEN` làm `Settings` ném `ValidationError` ngay lúc khởi tạo. Trong tình huống deploy lên Railway mà quên khai báo secret, lỗi sẽ xuất hiện ngay trong log build/startup thay vì để service khởi động với token mặc định như `changeme`. Nhờ vậy có thể sửa biến môi trường trước khi service nhận bất kỳ request nào và trước khi một token yếu hoặc công khai bị dùng để gọi API.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Sau khi gọi `emit("chat_completed", client_id="sv01", usd_cost=0.12)`, log có dạng một JSON object trên một dòng: `{"event":"chat_completed","severity":"INFO","ts":"...","client_id":"sv01","usd_cost":0.12}`. Từ cấu trúc này có thể lọc/đếm các event `chat_completed` theo `severity`, và tổng hợp chi phí theo `client_id` hoặc theo thời gian `ts`. Một `print("đã trả lời xong")` chỉ là chuỗi tự do nên không có trường dữ liệu ổn định để hệ thống logging lọc, truy vấn hay tạo cảnh báo.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 270 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Image multi-stage nhỏ hơn khoảng 1.46 GB. Bản một stage giữ nguyên base image Python đầy đủ và toàn bộ môi trường dùng để cài/build dependency trong runtime image. Bản multi-stage dùng `python:3.11-slim`, cài dependency ở stage builder với `--prefix=/install`, rồi runtime chỉ copy package đã cài cùng `app/` và `utils/`; vì vậy không mang theo các phần build context và layer không cần thiết để phục vụ app.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi build lại sau khi chỉ thêm một comment tạm vào `app/main.py`. Docker báo `CACHED` cho `COPY requirements.txt .` và `RUN pip install --no-cache-dir --prefix=/install -r requirements.txt`; các layer runtime trước khi copy source cũng được cache. `COPY --chown=appuser:appuser app ./app` và `COPY ... utils ./utils` chạy lại vì build context source đã đổi. Nếu đặt `COPY . .` trước `RUN pip install`, thay đổi một ký tự trong source sẽ làm layer copy toàn bộ source đổi trước, khiến layer cài dependency mất cache và phải chạy lại. Tôi đã xóa comment thử nghiệm sau khi kiểm tra.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> *Câu trả lời của bạn*

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> HTTP 401 cần `WWW-Authenticate: Bearer` để client biết server yêu cầu cơ chế xác thực Bearer theo chuẩn HTTP, thay vì phải đoán cách gửi credential. Service trả cùng một thông báo `invalid or missing bearer token` cho thiếu header, sai scheme và sai token để không tiết lộ cho người đang dò token rằng họ đã vượt qua được bước nào. CP3 đã kiểm tra cả các trường hợp này, đồng thời dùng `secrets.compare_digest` để tránh rò rỉ timing khi so sánh token.

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> Với `capacity=10`, client chỉ gửi được tối đa 10 request liên tiếp trước khi nhận 429, dù đã im lặng 10 phút. Tốc độ nạp là 10 token/phút, nhưng `min(capacity, ...)` chặn số token ở 10. Nếu bỏ `min`, sau 10 phút bucket có thể tích thêm 100 token (hoặc 110 nếu trước đó đã đầy), tạo burst rất lớn và làm rate limit gần như mất tác dụng. CP3 đã kiểm tra cả refill và giới hạn capacity.

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> Hạn mức $30/tháng cho phép một sự cố hoặc client bị lộ token tiêu hết tối đa $30 trước khi reset vào tháng sau. Hạn mức $1/ngày giới hạn thiệt hại của một ngày xuống $1, sau đó service tự phục hồi khi key chi phí chuyển sang ngày UTC mới. Vì vậy daily budget phát hiện và chặn thiệt hại sớm hơn, còn monthly budget phù hợp hơn cho kiểm soát tổng chi tiêu dài hạn nhưng phản ứng chậm trước burst lúc 2 giờ sáng.

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Nếu gộp hai endpoint và cho liveness check Redis, Redis mất kết nối 30 giây sẽ làm cả ba container trả unhealthy. Orchestrator lần lượt restart cả ba instance thay vì chỉ để load balancer rút traffic; trong lúc Redis hồi phục, không còn instance nào phục vụ request và người dùng nhận lỗi. Khi tách probe, `/healthz` vẫn 200 vì process còn sống, còn `/readyz` trả 503; load balancer chỉ ngừng gửi request mới tới các instance chưa ready mà không restart đồng loạt.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lần deploy đầu tiên bị Railway đánh dấu `FAILED`. Log ghi `Invalid value for '--port': '$PORT' is not a valid integer`. Nguyên nhân là `railway.toml` truyền `uvicorn ... --port $PORT` trực tiếp, nên Uvicorn nhận chuỗi literal thay vì biến môi trường đã được shell thay thế. Tôi sửa `startCommand` thành `sh -c 'uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}'`, deploy lại thành công và xác nhận `/healthz` 200, `/readyz` 200.
