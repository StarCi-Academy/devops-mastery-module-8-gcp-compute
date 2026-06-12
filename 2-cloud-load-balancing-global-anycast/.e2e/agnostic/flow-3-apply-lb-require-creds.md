# Flow 3 — terraform apply dựng global HTTP(S) LB (status: require-creds)

Variant: agnostic · tạo resource GCP THẬT (forwarding rule tính tiền theo giờ) → cần `GOOGLE_APPLICATION_CREDENTIALS` (hoặc ADC) + `GOOGLE_PROJECT`.

## Lệnh

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/lab-sa-key.json
export GOOGLE_PROJECT=<your-project-id>
gcloud services enable compute.googleapis.com --project "$GOOGLE_PROJECT"
terraform apply -var="project=$GOOGLE_PROJECT" -auto-approve

terraform output -raw anycast_ip
gcloud compute backend-services get-health \
    "$(terraform output -raw backend_service_name)" --global
```

## Pass criteria (khi creds được cấp)

- `apply` → `Apply complete! Resources: 8 added` (template → health check → MIG → firewall → backend service → url map → target proxy → global forwarding rule theo dependency graph).
- Output `anycast_ip` non-empty và nằm trong dải IP global của Google (vd `34.120.x.y`).
- `backend-services get-health` → mọi instance `HEALTHY` sau ~1-2 phút (firewall đã mở `130.211.0.0/22` + `35.191.0.0/16`).
- `curl -s "http://$(terraform output -raw anycast_ip)/"` → `Hello from starci-lb-... (us-central1-a)` sau 3-5 phút LB propagate.

## Trạng thái

Offline gate (Flow 1-2) PASS. Flow này tạo global forwarding rule tính tiền theo giờ nên CHỜ lab credential — `require-creds`. Khi có creds, chạy kèm `terraform destroy -var="project=$GOOGLE_PROJECT" -auto-approve` NGAY sau để zero-cost (forwarding rule là cost driver chính).
