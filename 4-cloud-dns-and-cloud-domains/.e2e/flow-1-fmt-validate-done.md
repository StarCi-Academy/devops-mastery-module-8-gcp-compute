# Flow 1 — terraform fmt + validate (status: DONE, offline)

Variant: agnostic · tầng LOCAL · KHÔNG cần credential.

## Lệnh

```bash
terraform fmt -check -diff
terraform validate
```

## Observed (run 2026-06-10, Terraform v1.14.2, windows_amd64)

- `terraform fmt -diff` → no diff (code đã đúng canonical format).
- `terraform validate` → `Success! The configuration is valid.`

Bộ argument hợp lệ với schema provider `hashicorp/google ~> 6.0`: `dnssec_config.state` nhận `on/off/transfer`; `visibility` nhận `public/private`; `default_key_specs.key_type` nhận `keySigning/zoneSigning`; record_set `type`/`ttl`/`rrdatas` hợp lệ. Chạy hoàn toàn offline, không gọi GCP API.

## Re-verified (2026-07-10)

Chạy lại `terraform fmt -check -diff -no-color` (exit 0, no diff) + `terraform validate -no-color` → `Success! The configuration is valid.` — kết quả không đổi.
