# Flow 5 — split-horizon: cùng tên domain trả 2 response khác (status: DONE, real GCP — một phần)

Variant: agnostic · tầng GCP thật · failure/edge mode · credential đã sẵn sàng. Chạy trên zone thật vừa `apply` (xem `flow-3-apply-done.md`), trước khi `destroy`.

## Lệnh chạy thật — nửa PUBLIC (query thẳng anycast nameserver, không cần delegation)

```powershell
nslookup lab.starci-academy.dev. ns-cloud-a1.googledomains.com
nslookup -type=MX lab.starci-academy.dev. ns-cloud-a1.googledomains.com
nslookup -type=TXT lab.starci-academy.dev. ns-cloud-a1.googledomains.com
```

## Output (thực tế, 2026-07-10)

```
Server:  UnKnown
Address:  2001:4860:4802:32::6a

Name:    lab.starci-academy.dev
Address:  34.120.0.10
```

```
lab.starci-academy.dev  MX preference = 10, mail exchanger = mail.lab.starci-academy.dev
```

```
lab.starci-academy.dev  text =
        "v=spf1 include:_spf.google.com ~all"
```

*Kết luận:* query thẳng vào authoritative nameserver `ns-cloud-a1.googledomains.com` (bỏ qua resolver đệ quy công cộng — không cần domain được delegate) trả đúng `apex_public_ip = 34.120.0.10` từ output `apply`, đúng MX/TXT record đã khai trong `main.tf`. Zone **public** phục vụ đúng dữ liệu thật.

Verify thêm — xác nhận domain **chưa** delegate ra ngoài (đúng thiết kế `$0`, không đăng ký domain):

```
nslookup lab.starci-academy.dev. 8.8.8.8
→ *** dns.google can't find lab.starci-academy.dev.: Non-existent domain
```

Kết quả `NXDOMAIN` qua resolver công cộng `8.8.8.8` là **đúng kỳ vọng**: zone tồn tại thật trên Cloud DNS (verify được bằng cách query thẳng nameserver ở trên) nhưng KHÔNG có ai trỏ NS ở domain cha `starci-academy.dev` vào 4 nameserver này — đúng như thiết kế lab (subdomain test-only, không tốn phí đăng ký).

## Phần KHÔNG chạy được thật — ghi nhận minh bạch (không fake `-done`)

Pass criteria gốc còn nửa **PRIVATE**: "SSH vào một VM gắn vào `starci-dns-vpc`, `dig <dns_name> A +short` → trả `internal_ip`". Bước này **không bị chặn bởi credential** mà bị chặn vì module Terraform của lesson này **không định nghĩa `google_compute_instance` nào** — chỉ có VPC + 2 managed zone (đúng scope pure-DNS của bài). Dựng thêm 1 VM chỉ để chạy `dig` nội bộ sẽ tạo resource ngoài phạm vi `main.tf` của lesson + phát sinh chi phí Compute Engine không cần thiết cho một bài học DNS — ngoài scope module này.

Bằng chứng gián tiếp đã có: `google_dns_managed_zone.private` tạo thành công (`flow-3-apply-done.md`), `private_visibility_config.networks` trỏ đúng `google_compute_network.api_vpc.id` (đọc trực tiếp trong `main.tf`, verify ở `##### 2.1.3.4`), và `terraform plan` xác nhận `google_dns_record_set.a_apex_private` có `rrdatas = ["10.0.0.100"]` — cơ chế split-horizon (2 zone cùng `dns_name`, khác `visibility`, private bind đúng VPC) đã được tạo thật và đúng cấu hình; phần còn thiếu chỉ là bước quan sát trực quan từ bên trong VPC.

## Cleanup

Zone + VPC đã `terraform destroy` sạch cùng phiên — xem `flow-3-apply-done.md`.
