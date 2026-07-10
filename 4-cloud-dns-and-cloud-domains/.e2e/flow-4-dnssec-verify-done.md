# Flow 4 — verify DNSSEC chain of trust + lấy DS record (status: DONE, real GCP — một phần)

Variant: agnostic · tầng GCP thật · credential đã sẵn sàng. Chạy trên zone thật vừa `apply` (xem `flow-3-apply-done.md`), trước khi `destroy`.

## Lệnh chạy thật

```bash
gcloud dns dns-keys list --zone=web-zone --project=project-77b79b42-8c38-4157-a7a \
  --format="table(type,algorithm,keyTag,digests[0].digest,isActive)"
```

## Output (thực tế, 2026-07-10)

```
TYPE: keySigning
ALGORITHM: rsasha256
KEY_TAG: 46945
DIGEST: 199C8EEA0BA8F76140CBC35452FE7B73C01F635A844E30171A78FA0F634CC8B9
IS_ACTIVE: True

TYPE: zoneSigning
ALGORITHM: rsasha256
KEY_TAG: 4395
DIGEST:
IS_ACTIVE: True
```

*Kết luận:* zone thật có đúng 2 key — 1 **KSK** (`keySigning`, digest = DS record để publish ở parent) + 1 **ZSK** (`zoneSigning`, không cần digest ở DS, chỉ KSK mới publish parent) — khớp `default_key_specs` trong `main.tf`. Cả hai đều `isActive: True`.

## Phần KHÔNG chạy được thật — ghi nhận minh bạch (không fake `-done`)

Pass criteria gốc còn một bước: `dig @1.1.1.1 <dns_name> A +dnssec` phải trả flag `ad` (Authenticated Data) sau khi publish DS ở **parent zone**. Bước này **không phải bị chặn bởi credential** (credential đã có) mà bị chặn bởi một điều kiện khác — cần **domain thật được đăng ký + delegate NS** tới `ns-cloud-*.googledomains.com` ở registrar. Lab này **cố tình KHÔNG đăng ký domain** (đúng cảnh báo chi phí ở `2.1.4.1`: Cloud Domains charge ngay, non-refundable) nên không có parent zone thật để publish DS → không thể quan sát flag `ad` qua resolver công cộng mà không phát sinh chi phí đăng ký domain thật. Đây là giới hạn scope có chủ đích của bài (agnostic, `$0`), không phải chỗ né việc.

Verify thay thế đã chạy thật (không cần delegation, query thẳng authoritative nameserver — xem chi tiết + evidence ở `flow-5-split-horizon-done.md`): record A/MX/TXT resolve đúng giá trị `apply` ra, xác nhận zone signed và phục vụ đúng dữ liệu; `dns-keys list` ở trên xác nhận DNSSEC thực sự bật với đúng 2 key.

## Cleanup

Zone đã `terraform destroy` sạch cùng phiên — xem `flow-3-apply-done.md`.
