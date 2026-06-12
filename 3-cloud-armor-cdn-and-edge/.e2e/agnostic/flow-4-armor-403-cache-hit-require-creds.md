# Flow 4 — Cloud Armor 403 tại edge + Cloud CDN cache hit (status: require-creds)

Variant: agnostic · tầng GCP thật · CẦN cloud credential.

## Tiền đề

- Flow 3 đã `apply` xong; `anycast_ip` đã có; backend MIG (bài 1) phục vụ `/api/*` và `/static/*`.

## Lệnh

```bash
IP=$(terraform output -raw anycast_ip)
curl -s -o /dev/null -w "%{http_code}\n" "http://$IP/api/users?id=1"
curl -s -o /dev/null -w "%{http_code}\n" "http://$IP/api/users?id=1'%20OR%20'1'='1"
curl -sI "http://$IP/static/logo.png" | grep -Ei "^(age|via|cache-control)"
```

## Pass criteria

- Request bình thường → HTTP `200`.
- Request SQLi → HTTP `403` (rule 1000 `evaluatePreconfiguredExpr('sqli-v33-stable')`), kèm header `X-Goog-Armor-*`.
- Cloud Logging filter `jsonPayload.enforcedSecurityPolicy.outcome=DENY` thấy log block của request SQLi.
- Asset static lần 2 trả `Via: 1.1 google` + `Age > 0` → CDN cache hit từ edge.

## Observed

Pending — cần GCP credential (require-creds).
