# Flow 3 — terraform apply tạo public zone + DNSSEC + record set + private zone (status: DONE, real GCP)

Variant: agnostic · tầng GCP thật · credential đã sẵn sàng (ADC `levan020305@gmail.com`, project `project-77b79b42-8c38-4157-a7a`).

## Biến môi trường dùng

- `gcloud auth application-default login` (ADC) — không dùng key file.
- `GOOGLE_PROJECT=project-77b79b42-8c38-4157-a7a`.
- Role thực tế trên account: đủ quyền tạo `google_dns_managed_zone` (public + private) + `google_dns_record_set` + `google_compute_network`.

## Lệnh chạy thật

```bash
export GOOGLE_PROJECT="project-77b79b42-8c38-4157-a7a"
terraform apply -auto-approve -input=false -no-color -var="project=$GOOGLE_PROJECT"
terraform output public_zone_name_servers
```

## Output Apply (thực tế, 2026-07-10)

```
google_compute_network.api_vpc: Creating...
google_dns_managed_zone.public: Creating...
google_dns_managed_zone.public: Creation complete after 1s [id=projects/project-77b79b42-8c38-4157-a7a/managedZones/web-zone]
google_dns_record_set.a_apex: Creating...
google_dns_record_set.mx: Creating...
google_dns_record_set.caa: Creating...
google_dns_record_set.cname_www: Creating...
google_dns_record_set.txt_spf: Creating...
google_dns_record_set.txt_spf: Creation complete after 2s
google_dns_record_set.a_apex: Creation complete after 2s
google_dns_record_set.mx: Creation complete after 2s
google_dns_record_set.caa: Creation complete after 4s
google_dns_record_set.cname_www: Creation complete after 4s
google_compute_network.api_vpc: Creation complete after 55s [id=projects/project-77b79b42-8c38-4157-a7a/global/networks/starci-dns-vpc]
google_dns_managed_zone.private: Creating...
google_dns_managed_zone.private: Creation complete after 0s [id=projects/project-77b79b42-8c38-4157-a7a/managedZones/web-zone-private]
google_dns_record_set.a_apex_private: Creating...
google_dns_record_set.a_apex_private: Creation complete after 4s

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

apex_private_ip = "10.0.0.100"
apex_public_ip = "34.120.0.10"
private_zone_id = "projects/project-77b79b42-8c38-4157-a7a/managedZones/web-zone-private"
public_zone_id = "projects/project-77b79b42-8c38-4157-a7a/managedZones/web-zone"
public_zone_name_servers = tolist([
  "ns-cloud-a1.googledomains.com.",
  "ns-cloud-a2.googledomains.com.",
  "ns-cloud-a3.googledomains.com.",
  "ns-cloud-a4.googledomains.com.",
])
```

- `terraform state list` sau apply → 9 resource đúng như plan (1 VPC, 2 managed zone, 6 record set).
- `gcloud dns record-sets list --zone=web-zone --project=project-77b79b42-8c38-4157-a7a` liệt kê đủ A/CNAME/MX/TXT/CAA (verify chéo qua nslookup trực tiếp — xem `flow-4-dnssec-verify-done.md` + `flow-5-split-horizon-done.md`).

## Cleanup (thực tế, cùng phiên chạy)

```bash
terraform destroy -auto-approve -input=false -no-color -var="project=$GOOGLE_PROJECT"
```

```
Destroy complete! Resources: 9 destroyed.
```

- `terraform state list` sau destroy → rỗng (exit code 1, không resource nào).
- `gcloud dns managed-zones list --filter="labels.lesson=4-cloud-dns-and-cloud-domains"` → rỗng.
- `gcloud compute networks list --filter="name=starci-dns-vpc"` → rỗng.
- Không còn resource GCP nào sống sau lesson. E2E apply→destroy **PASS** hoàn toàn.
