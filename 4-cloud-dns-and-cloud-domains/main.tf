# main.tf — Cloud DNS lab. A public managed zone with DNSSEC + a full record set
# (A/CNAME/MX/TXT/CAA), plus a PRIVATE split-horizon zone of the SAME dns_name
# bound to a dedicated VPC that resolves to an internal IP. Each argument maps
# 1:1 to a Terraform Registry argument and is explained line-by-line in the
# lesson body (codeExplaining). Unlike AWS Route53 (nameservers dedicated per
# hosted zone), Cloud DNS serves every zone from the same global anycast
# nameserver set (ns-cloud-*.googledomains.com) — see name_servers output.

locals {
  common_labels = {
    lesson = var.lesson
    env    = "lab"
  }
}

# A dedicated VPC the private split-horizon zone binds to. Created here so the
# lab is self-contained; in production this is the api-vpc from the network
# lesson. GCP VPCs are GLOBAL (a single VPC spans every region) — unlike AWS.
resource "google_compute_network" "api_vpc" {
  name                    = "starci-dns-vpc"
  auto_create_subnetworks = true
}

# The PUBLIC managed zone — authoritative for the domain, resolvable from the
# Internet. visibility="public" exposes it to the world; DNSSEC is turned on so
# resolvers can cryptographically validate the chain of trust.
resource "google_dns_managed_zone" "public" {
  # name — "User assigned name for this resource. Must be unique within the project."
  name = "web-zone"
  # dns_name — "The DNS name of this managed zone, for instance 'example.com.'."
  dns_name = var.dns_name
  # description — "A textual description field. Defaults to 'Managed by Terraform'."
  description = "Lab public zone for ${var.dns_name}"
  # visibility — "public zones are exposed to the Internet, while private zones
  # are visible only to Virtual Private Cloud resources."
  visibility = "public"
  # labels — "A set of key/value label pairs to assign to this ManagedZone."
  labels = local.common_labels
  # force_destroy — "Set this true to delete all records in the zone." Lab-only:
  # lets `terraform destroy` remove the zone even if extra records linger.
  force_destroy = true

  # dnssec_config — "DNSSEC configuration". Google auto-generates KSK+ZSK, signs
  # every RRset with RRSIG, and rotates keys; the learner only flips state="on"
  # and publishes the DS record at the parent zone.
  dnssec_config {
    # state — "Specifies whether DNSSEC is enabled, and what mode it is in"
    state = "on"
    # non_existence — "Specifies the mechanism used to provide authenticated
    # denial-of-existence responses." nsec3 hashes record names to block zone
    # walking (nsec would leak the next record name to an enumerator).
    non_existence = "nsec3"
    default_key_specs {
      # algorithm — "String mnemonic specifying the DNSSEC algorithm of this key"
      algorithm = "rsasha256"
      # key_length — "Length of the keys in bits"
      key_length = 2048
      # key_type — "Specifies whether this is a key signing key (KSK) or a zone
      # signing key (ZSK)."
      key_type = "keySigning"
      # kind — "Identifies what kind of resource this is"
      kind = "dns#dnsKeySpec"
    }
    default_key_specs {
      algorithm  = "rsasha256"
      key_length = 1024
      key_type   = "zoneSigning"
      kind       = "dns#dnsKeySpec"
    }
  }
}

# A record at the apex -> the global anycast IP of the Cloud LB (the global
# forwarding rule from the load-balancing lesson). One IP, served from every
# Google edge POP worldwide — that is what makes a GCP global LB different from
# a regional AWS ALB.
resource "google_dns_record_set" "a_apex" {
  # name — "The DNS name this record set will apply to."
  name = google_dns_managed_zone.public.dns_name
  # managed_zone — "The name of the zone in which this record set will reside."
  managed_zone = google_dns_managed_zone.public.name
  # type — "The DNS record set type."
  type = "A"
  # ttl — "The time-to-live of this record set (seconds)." 300s allows fast
  # DNS-based failover/cutover.
  ttl = 300
  # rrdatas — "The string data for the records in this record set whose meaning
  # depends on the DNS type." For an A record: the IPv4 address.
  rrdatas = [var.anycast_ip]
}

# CNAME www -> apex. rrdatas for a CNAME must be a single fully-qualified name.
resource "google_dns_record_set" "cname_www" {
  name         = "www.${google_dns_managed_zone.public.dns_name}"
  managed_zone = google_dns_managed_zone.public.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = [google_dns_managed_zone.public.dns_name]
}

# MX record (priority 10) for mail routing.
resource "google_dns_record_set" "mx" {
  name         = google_dns_managed_zone.public.dns_name
  managed_zone = google_dns_managed_zone.public.name
  type         = "MX"
  ttl          = 3600
  rrdatas      = ["10 mail.${google_dns_managed_zone.public.dns_name}"]
}

# TXT SPF record. The data must be wrapped in escaped quotes per DNS TXT rules.
resource "google_dns_record_set" "txt_spf" {
  name         = google_dns_managed_zone.public.dns_name
  managed_zone = google_dns_managed_zone.public.name
  type         = "TXT"
  ttl          = 3600
  rrdatas      = ["\"v=spf1 include:_spf.google.com ~all\""]
}

# CAA record — anti-rogue-CA best practice: only Let's Encrypt may issue a
# certificate for this domain, so a compromised account at any OTHER CA cannot
# mint a valid cert.
resource "google_dns_record_set" "caa" {
  name         = google_dns_managed_zone.public.dns_name
  managed_zone = google_dns_managed_zone.public.name
  type         = "CAA"
  ttl          = 3600
  rrdatas      = ["0 issue \"letsencrypt.org\""]
}

# The PRIVATE split-horizon zone — SAME dns_name as the public zone, but
# visibility="private" and bound to api_vpc. Clients inside the VPC get the
# internal IP; clients on the Internet get the public anycast IP. No DNSSEC on a
# private zone (it never leaves the VPC, so there is no public chain of trust).
resource "google_dns_managed_zone" "private" {
  name        = "web-zone-private"
  dns_name    = var.dns_name
  description = "Lab split-horizon private zone for ${var.dns_name}"
  visibility  = "private"
  labels      = local.common_labels

  # private_visibility_config.networks — "The list of VPC networks that can see
  # this zone." network_url — "The id or fully qualified URL of the VPC network
  # to bind to." This VPC-level binding is how GCP scopes a private zone (AWS
  # Route53 associates a private hosted zone with a VPC similarly).
  private_visibility_config {
    networks {
      network_url = google_compute_network.api_vpc.id
    }
  }
}

# Apex A record in the PRIVATE zone -> internal LB IP. Same name as the public
# A record, different answer — the essence of split-horizon DNS.
resource "google_dns_record_set" "a_apex_private" {
  name         = google_dns_managed_zone.private.dns_name
  managed_zone = google_dns_managed_zone.private.name
  type         = "A"
  ttl          = 300
  rrdatas      = [var.internal_ip]
}
