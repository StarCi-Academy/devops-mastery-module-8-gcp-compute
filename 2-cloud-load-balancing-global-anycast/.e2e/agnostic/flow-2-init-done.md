# Flow 2 — terraform init tải provider và khoá version (status: done)

Variant: agnostic · chạy offline thật, KHÔNG cần GCP credential.

## Lệnh

```bash
terraform init
```

## Output thật (rút gọn)

```
- Installing hashicorp/google v6.50.0...
- Installed hashicorp/google v6.50.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

- `init` resolve `~> 6.0` ra `6.50.0`, tải plugin về `.terraform/providers/` và sinh `.terraform.lock.hcl` kèm checksum.
- Không gọi GCP API → KHÔNG cần credential.

## Kết luận

`init` chỉ tải plugin và khoá version để mọi máy/CI ra đúng provider — cốt lõi reproducibility. PASS, offline.
