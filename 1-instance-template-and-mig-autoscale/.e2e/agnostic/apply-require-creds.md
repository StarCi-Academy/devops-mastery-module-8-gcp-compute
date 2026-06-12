# E2E — apply require-creds

`terraform fmt/validate/init` run offline (done). `terraform plan/apply` create
REAL GCP resources and need credentials + a project.

## Env required

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/lab-sa-key.json   # or: gcloud auth application-default login
export GOOGLE_PROJECT=<your-project-id>
gcloud services enable compute.googleapis.com --project "$GOOGLE_PROJECT"

terraform apply -var="project=$GOOGLE_PROJECT" -auto-approve
```

Least-privilege service account: `Compute Instance Admin (v1)` + `Compute
Viewer` is enough; NEVER use a project Owner key.

## Pass criteria (when creds are granted)

- `apply` → `Apply complete! Resources: 4 added` (template → health check → MIG → autoscaler).
- `gcloud compute instance-groups managed list-instances $(terraform output -raw mig_name) --region=us-central1` → `target_size` (2) instances `RUNNING`, spread across >= 2 zones (`us-central1-a/-b/-c`).
- `gcloud compute region-autoscalers describe starci-mig-autoscaler --region=us-central1` shows `cpuUtilization.utilizationTarget: 0.6`, `minNumReplicas: 1`, `maxNumReplicas: 3`.

## Cleanup (mandatory)

```bash
terraform destroy -var="project=$GOOGLE_PROJECT" -auto-approve
```

`e2-micro` in us-central1 is always-free for 1 instance/month; running 2-3 VMs
plus the second always-free region overlap can leave billable hours, so destroy
right after the lab.
