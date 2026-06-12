# Flow 3 — terraform apply tạo public zone + DNSSEC + record set + private zone (status: require-creds)

Variant: agnostic · tầng GCP thật · CẦN cloud credential.

## Biến môi trường cần

- `GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json` HOẶC `gcloud auth application-default login`.
- `GOOGLE_PROJECT=<your-project-id>` (hoặc truyền `-var project=<id>`).
- Service account role tối thiểu: `DNS Administrator` (`roles/dns.admin`) + `Compute Network Admin` (cho VPC private zone).
- (Tùy chọn) override `-var dns_name=<your-subdomain>.` để dùng domain bạn kiểm soát.

## Lệnh

```bash
export GOOGLE_PROJECT="<your-project-id>"
terraform apply -auto-approve -var "project=$GOOGLE_PROJECT"
terraform output public_zone_name_servers
```

## Pass criteria

- `apply` tạo các resource: `google_compute_network.api_vpc`, `google_dns_managed_zone.public` (DNSSEC on), 5 record set public (A/CNAME/MX/TXT/CAA), `google_dns_managed_zone.private`, 1 record set private.
- `terraform output public_zone_name_servers` trả về 4 nameserver dạng `ns-cloud-x1..x4.googledomains.com.` — bằng chứng anycast shared (KHÁC Route53 dedicated per-zone).
- `gcloud dns record-sets list --zone=web-zone` liệt kê đủ A/CNAME/MX/TXT/CAA.
- `dig @ns-cloud-x1.googledomains.com <dns_name> A +short` (thay x1 bằng nameserver thật) trả về `anycast_ip` ngay sau create, KHÔNG cần đợi delegation propagate.

## Observed

Pending — cần GCP credential (require-creds). Cleanup: `terraform destroy -auto-approve -var "project=$GOOGLE_PROJECT"`.
