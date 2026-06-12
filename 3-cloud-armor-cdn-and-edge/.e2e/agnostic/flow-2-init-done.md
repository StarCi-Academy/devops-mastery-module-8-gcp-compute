# Flow 2 — terraform init (status: done)

Variant: agnostic · tầng LOCAL · KHÔNG cần cloud credential.

## Lệnh

```bash
cd .repo/devops-mastery-module-8-gcp-compute/3-cloud-armor-cdn-and-edge
terraform init
```

## Pass criteria

- `init` tải provider `hashicorp/google` và in `Terraform has been successfully initialized!`.
- Sinh `.terraform.lock.hcl` ghim version + checksum.

## Observed (chạy thật 2026-06-10)

- `- Installed hashicorp/google v6.50.0 (signed by HashiCorp)`.
- `Terraform has been successfully initialized!`.
- Không cần credential (chỉ tải plugin, chưa gọi GCP API).
