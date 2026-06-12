# Flow 1 — terraform fmt + validate (status: done)

Variant: agnostic · chạy offline thật, KHÔNG cần GCP credential.

## Lệnh

```bash
terraform fmt -check -diff
terraform validate
```

## Output thật

```
Success! The configuration is valid.
```

- `terraform v1.14.2`, provider `hashicorp/google v6.50.0`.
- `fmt -check` exit 0 (không có diff — code đã ở dạng canonical).
- `validate` xác nhận mọi argument hợp lệ với schema provider: `load_balancing_scheme = "EXTERNAL_MANAGED"` trên cả backend service và global forwarding rule, `backend.balancing_mode = "RATE"`, `enable_cdn = true` với `cdn_policy.cache_key_policy`, đúng một protocol block `http_health_check`, `url_map.path_rule.paths` bắt đầu bằng `/`.

## Kết luận

Cấu hình HCL đúng cú pháp, đã format chuẩn, mọi tham chiếu resource/biến giải được (forwarding rule → proxy → url map → backend service → MIG). Hai lệnh chạy hoàn toàn offline — bắt lỗi sớm trong CI trước khi tốn tiền cloud. PASS.
