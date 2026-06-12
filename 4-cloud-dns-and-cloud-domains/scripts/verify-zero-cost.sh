#!/usr/bin/env bash
# verify-zero-cost.sh — after `terraform destroy`, assert no managed zone (and
# no other resource) is left behind still carrying this lesson's label. Run with
# the lesson slug as the first arg (defaults to the lab slug). NOTE: a Cloud
# Domains registration is NOT cleaned here — it is paid and non-refundable.
set -euo pipefail

LESSON_SLUG="${1:-4-cloud-dns-and-cloud-domains}"
: "${GOOGLE_PROJECT:?GOOGLE_PROJECT env var required (the GCP project ID)}"

echo "[verify] searching for resources labeled lesson=${LESSON_SLUG} in ${GOOGLE_PROJECT}..."

COUNT=$(gcloud asset search-all-resources \
  --scope="projects/${GOOGLE_PROJECT}" \
  --query="labels.lesson=${LESSON_SLUG}" \
  --format="value(name)" | wc -l | tr -d ' ')

if [ "${COUNT}" = "0" ]; then
  echo "OK: zero resources labeled lesson=${LESSON_SLUG}"
  exit 0
else
  echo "WARN: ${COUNT} resource(s) still labeled lesson=${LESSON_SLUG} — delete them to stop billing:"
  gcloud asset search-all-resources \
    --scope="projects/${GOOGLE_PROJECT}" \
    --query="labels.lesson=${LESSON_SLUG}" \
    --format="table(name,assetType)"
  exit 1
fi
