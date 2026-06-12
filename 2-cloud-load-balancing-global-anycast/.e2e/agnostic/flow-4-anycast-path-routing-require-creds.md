# Flow 4 — verify anycast IP + path-based routing (status: require-creds)

Variant: agnostic · cần LB đã apply ở Flow 3 → `require-creds`.

## Lệnh

```bash
IP=$(terraform output -raw anycast_ip)
# Cùng MỘT IP cho mọi path — URL map fan-out theo path, không cần forwarding rule thứ 2
curl -s "http://$IP/"          # default_service
curl -s "http://$IP/api/users" # khớp path_rule /api/*
# CDN hit: header thứ 2 xuất hiện Age / Cache khi response cacheable
curl -sD - "http://$IP/" -o /dev/null | grep -i -E "via|age|cache"
```

## Pass criteria (khi creds được cấp)

- Cả `/` và `/api/users` resolve về CÙNG anycast IP (1 forwarding rule duy nhất) và trả `200`.
- Response body chứa tên zone backend (vd `(us-central1-a)`) — chứng minh request về region gần nhất.
- Header `Via: 1.1 google` xuất hiện (đi qua Google front-end); lần gọi thứ 2 cacheable có `Age:` tăng (Cloud CDN hit từ `enable_cdn`).

## Trạng thái

`require-creds`. Để test anycast thật từ 2 vị trí địa lý cần 2 client khác region (vd 2 VM ở us-central1 + asia-southeast1) — single-laptop chỉ thấy 1 region route. Ghi lại observation vào README submission.
