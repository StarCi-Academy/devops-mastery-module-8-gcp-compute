# Flow 4 — verify DNSSEC chain of trust + lấy DS record (status: require-creds)

Variant: agnostic · tầng GCP thật · CẦN cloud credential.

## Biến môi trường cần

- Như Flow 3. DNSSEC đã bật ở `apply` (`dnssec_config.state = "on"`).

## Lệnh

```bash
# Lấy DS record (KSK) để publish ở parent zone / Cloud Domains
gcloud dns dns-keys list --zone=web-zone \
  --format="table(type,algorithm,keyTag,digests[0].digest,isActive)"

# Sau khi publish DS ở parent, verify chain of trust qua resolver validate
dig @1.1.1.1 <dns_name> A +dnssec
```

## Pass criteria

- `dns-keys list` hiển thị 2 key: 1 `keySigning` (KSK) + 1 `zoneSigning` (ZSK); row KSK chứa digest để publish DS.
- Sau khi DS publish ở parent zone, `dig @1.1.1.1 ... +dnssec` có flag `ad` (Authenticated Data) trong header → resolver validate chain of trust thành công.
- Nếu DS chưa publish: zone vẫn signed (có RRSIG) nhưng KHÔNG có flag `ad` (chain chưa nối tới parent) — đây là pitfall phổ biến.

## Observed

Pending — cần GCP credential + quyền publish DS ở parent zone (require-creds).
