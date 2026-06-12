# Flow 5 — split-horizon: cùng tên domain trả 2 response khác (status: require-creds)

Variant: agnostic · tầng GCP thật · failure/edge mode · CẦN cloud credential.

## Biến môi trường cần

- Như Flow 3. Public + private zone cùng `dns_name` đã tạo ở `apply`.

## Lệnh

```bash
# Từ Internet (laptop) — query public zone qua anycast nameserver:
dig @ns-cloud-x1.googledomains.com <dns_name> A +short
# → anycast_ip (vd 34.120.0.10) — public LB

# Từ trong VPC (SSH vào một VM gắn vào starci-dns-vpc):
# dig <dns_name> A +short
# → internal_ip (vd 10.0.0.100) — internal LB
```

## Pass criteria

- Cùng `dns_name`, query từ Internet trả `anycast_ip`; query từ trong VPC trả `internal_ip` → bằng chứng split-horizon hoạt động.
- `gcloud dns managed-zones list --filter="dnsName=<dns_name>"` trả về 2 zone (1 public, 1 private) cùng `dns_name` nhưng khác `visibility`.
- Edge: nếu VPC chưa bind vào private zone (`private_visibility_config.networks` thiếu), client trong VPC sẽ resolve ra `anycast_ip` (public) thay vì `internal_ip` — observable failure.

## Observed

Pending — cần GCP credential + một VM trong VPC để query nội bộ (require-creds).
