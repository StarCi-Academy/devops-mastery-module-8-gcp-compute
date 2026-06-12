# Flow 1 — terraform fmt + validate (status: done)

Variant: agnostic · tầng LOCAL · KHÔNG cần cloud credential.

## Lệnh

```bash
cd .repo/devops-mastery-module-8-gcp-compute/3-cloud-armor-cdn-and-edge
terraform fmt -check -diff
terraform validate
```

## Pass criteria

- `terraform fmt -check` exit 0 (code đã đúng format canonical, không có diff).
- `terraform validate` in `Success! The configuration is valid.`.

## Observed (chạy thật 2026-06-10, Terraform v1.14.2 on windows_amd64)

- `terraform fmt -diff` → không in diff (code đã canonical sẵn).
- `terraform validate` → `Success! The configuration is valid.`
- Xác nhận bộ argument đúng schema provider `hashicorp/google`: `google_compute_security_policy.rule` (action/priority/match.expr/rate_limit_options/adaptive_protection_config), `google_compute_backend_service` (enable_cdn/cdn_policy/security_policy), `google_compute_url_map` (host_rule/path_matcher), `google_compute_global_forwarding_rule`, `google_dns_managed_zone`, `google_dns_record_set` đều hợp lệ.
