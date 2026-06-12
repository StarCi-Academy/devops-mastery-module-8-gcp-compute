# Flow 3 — terraform apply tạo global LB + Armor + CDN + DNS (status: require-creds)

Variant: agnostic · tầng GCP thật · CẦN cloud credential.

## Biến môi trường cần

- `GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json` HOẶC `gcloud auth application-default login`.
- `GOOGLE_PROJECT=<your-project-id>` (hoặc truyền `-var project=<id>`).
- `TF_VAR_signed_url_key=$(head -c 16 /dev/urandom | base64 | tr +/ -_)` (base64url 128-bit).
- `-var backend_instance_group=<MIG self_link từ bài 1>` (để có backend thật phục vụ traffic).
- Service account role tối thiểu: `Compute Load Balancer Admin` + `Compute Security Admin` + `DNS Administrator`.

## Lệnh

```bash
export GOOGLE_PROJECT="<your-project-id>"
export TF_VAR_signed_url_key=$(head -c 16 /dev/urandom | base64 | tr +/ -_)
terraform apply -auto-approve \
  -var "project=$GOOGLE_PROJECT" \
  -var "backend_instance_group=<MIG self_link>"
terraform output anycast_ip
```

## Pass criteria

- `apply` tạo đủ stack: security_policy, health_check, backend_service (enable_cdn + security_policy attached), signed_url_key, url_map, target_http_proxy, global_forwarding_rule, dns_managed_zone, dns_record_set.
- `terraform output -raw anycast_ip` trả về một IPv4 global (anycast).
- `gcloud compute backend-services describe starci-web-backend --global --format="value(securityPolicy)"` trỏ về security policy URL.
- `gcloud compute backend-services describe starci-web-backend --global --format="value(cdnPolicy.cacheMode)"` → `USE_ORIGIN_HEADERS`.

## Observed

Pending — cần GCP credential (require-creds). Cleanup: `terraform destroy -auto-approve -var "project=$GOOGLE_PROJECT"`.
