# Flow 5 — backend unhealthy → LB drop khỏi rotation (status: require-creds)

Variant: agnostic · cần LB đã apply ở Flow 3 → `require-creds`.

## Lệnh

```bash
IP=$(terraform output -raw anycast_ip)
MIG=$(terraform output -raw mig_name)
# Phá /healthz trên 1 backend → health check fail
INST=$(gcloud compute instance-groups managed list-instances "$MIG" \
    --region=us-central1 --format="value(instance)" | head -1)
ZONE=$(gcloud compute instances list --filter="name=( $(basename "$INST") )" \
    --format="value(zone)")
gcloud compute ssh "$(basename "$INST")" --zone="$ZONE" \
    --command="sudo rm -f /var/www/html/healthz && sudo systemctl restart nginx"

# Quan sát backend chuyển UNHEALTHY và LB ngừng route về nó
gcloud compute backend-services get-health \
    "$(terraform output -raw backend_service_name)" --global
for i in $(seq 1 20); do curl -s "http://$IP/"; sleep 2; done
```

## Pass criteria (khi creds được cấp)

- Sau `unhealthy_threshold = 3 × check_interval = 10s` (≈30s), backend bị phá `/healthz` chuyển `UNHEALTHY` trong `get-health`.
- Vòng curl KHÔNG còn nhận response từ instance bị phá — LB tự drop khỏi rotation, traffic dồn sang backend healthy còn lại (autohealer của MIG cũng recreate VM sau đó).
- Tổng số response lỗi (502) ≤ vài lần trong cửa sổ 30s — chứng minh LB phản ứng theo health check tầng application, không phải hypervisor.

## Trạng thái

`require-creds`. Đây là failure-mode demo (không phải happy-path): backend còn `RUNNING` ở tầng OS nhưng fail probe `/healthz` vẫn bị LB loại. Chạy `terraform destroy` ngay sau để zero-cost.
