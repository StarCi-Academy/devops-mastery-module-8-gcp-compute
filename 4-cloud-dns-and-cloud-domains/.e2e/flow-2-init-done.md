# Flow 2 — terraform init (status: DONE, offline)

Variant: agnostic · tầng LOCAL · KHÔNG cần credential.

## Lệnh

```bash
terraform init
```

## Observed (run 2026-06-10)

- `- Installed hashicorp/google v6.50.0 (signed by HashiCorp)`
- `Terraform has been successfully initialized!`
- Sinh `.terraform.lock.hcl` ghi version `6.50.0` + checksum.

`init` resolve `~> 6.0` ra `6.50.0`, tải plugin và khoá version qua lock file (commit vào git để CI reproduce). Chỉ tải plugin, chưa gọi GCP API — không cần credential.
