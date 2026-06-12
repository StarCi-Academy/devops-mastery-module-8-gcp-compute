# Flow 5 — rate limit 429 sau ngưỡng 100/min (failure mode, status: require-creds)

Variant: agnostic · tầng GCP thật · CẦN cloud credential.

## Tiền đề

- Flow 3 đã `apply` xong; `anycast_ip` đã có; rule 2000 (`rate_based_ban`, `enforce_on_key = IP`, 100/60s, ban 60s) đã active.

## Lệnh

```bash
IP=$(terraform output -raw anycast_ip)
for i in $(seq 1 150); do
  curl -s -o /dev/null -w "%{http_code} " "http://$IP/api/users"
done; echo
```

## Pass criteria

- ~100 request đầu trả `200`, các request sau trả `429` (vượt ngưỡng cell IP).
- IP bị ban 60s: tiếp tục `429` dù tốc độ đã giảm dưới ngưỡng, trong cửa sổ ban.
- Cell-based: bắn từ IP khác (hoặc qua proxy IP khác) vẫn `200` → mỗi IP có counter riêng.
- Cloud Logging thấy `enforcedSecurityPolicy.outcome=DENY` với rule priority 2000.

## Observed

Pending — cần GCP credential (require-creds).
