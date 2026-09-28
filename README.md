# Charles Schwab SRE assessment — Woodworth Hamed

Reproducible two-region GKE demonstration with two stateless web services, a global public application endpoint, structured logs exported to BigQuery, and Grafana dashboards.

**Status: source package built and locally tested; NOT deployed to GCP.** No live endpoint, real cloud dashboard screenshot, GCP execution evidence, or hosted Git repository exists yet. See [validation](docs/VALIDATION.md) and [requirements](docs/REQUIREMENTS.md). Do not submit this repository as a running environment until the live acceptance checks pass.

## What this builds

- Zonal GKE Standard clusters `sre-primary` (`us-central1-a`) and `sre-secondary` (`us-east1-b`), private nodes, dedicated subnet and alias IP ranges per cluster, Cloud NAT, Workload Identity, restricted public control planes.
- App A and App B in both clusters, two replicas each, HPA, PodDisruptionBudget, rolling updates, non-root read-only containers, network policies.
- Global external Application Load Balancer with standalone zonal NEGs from both clusters; `/app-b` routes to B, other routes to A. Optional managed TLS for an owned domain.
- Cloud Logging → partitioned BigQuery dataset with a seven-day default table lifetime. Grafana and Prometheus on each GKE cluster, BigQuery authentication through Workload Identity.
- Six-panel Grafana dashboard JSON: BigQuery error rate and p50/p95/p99 application latency across both clusters; local cluster restarts, CPU, memory, and request rate.
- Local integration tests, a repeatable Kubernetes readiness incident drill, evidence collection, GitHub validation workflow, and cleanup procedure.

This is a small assessment environment, not a production landing zone. Two zonal clusters provide region separation but not a multi-zone control plane in either region. Grafana runs on GCP; it is **not** Grafana Cloud SaaS. Traces, profiling, WAF, Binary Authorization, Secret Manager integration and stateful services are not implemented. The requirement matrix explicitly records these gaps.

## 1. Prerequisites and costs

Use Google Cloud Shell or an authenticated Linux workstation. Required commands: `gcloud`, `gke-gcloud-auth-plugin`, `terraform` 1.6+, `kubectl`, Docker, Helm 3, Python 3.12+, `bq`, `curl`. Cloud Shell has many of these; install missing tools through their official instructions. Ensure Docker daemon is running.

Use a dedicated billing-enabled sandbox project and enough regional CPU, disk, GKE and load-balancer quota. The operator needs permissions to enable APIs, create GKE/networking/Artifact Registry/BigQuery resources, manage project and service-account IAM, and act as the node service account. Only the bootstrap operator needs this broad setup authority. For a newly created project, the operator also needs project creation and billing association permissions. Do not grant Owner to runtime workloads.

**This is not guaranteed free.** Budget for two cluster management fees minus applicable credits, 2–6 nodes, boot disks, NAT gateways/traffic, public IPv4, global forwarding rules/load balancing, logging and BigQuery. Current GKE free-tier credit does not make nodes or load balancing free. Configure billing alerts in the console; alerts do not stop spending. Keep the demo online only for the agreed review window. Review [cost and cleanup notes](docs/CLEANUP.md).

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
# Set ADC quota project after ensuring Service Usage Consumer permission:
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

No passwords or service-account JSON keys are needed in the repository.

## 2. Configure and review infrastructure

```bash
cp terraform/core/terraform.tfvars.example terraform/core/terraform.tfvars
# Edit project_id and admin_cidr. Determine the public egress IPv4 of your
# operator/Cloud Shell session through your approved IP-check mechanism.
# admin_cidr must be that trusted address/range; normally x.x.x.x/32.
terraform -chdir=terraform/core init
terraform -chdir=terraform/core fmt -check
terraform -chdir=terraform/core validate
terraform -chdir=terraform/core plan -out=core.tfplan
terraform -chdir=terraform/core apply core.tfplan
```

The default uses an existing project. To create one, set `create_project=true` and `billing_account`; optionally supply a real `folder_id`. A personal GCP account does not need an invented organization/folder. The project resource uses a prevent-deletion policy. API enablement, cluster provisioning and IAM propagation can take time.

The initial state is local. Keep it private and backed up. For a shared workflow, create a separate protected GCS state bucket, enable object versioning and uniform bucket-level access, add a `backend "gcs"` block with a distinct prefix for each root module, and run `terraform init -migrate-state`. Do not store the backend bucket inside the stack it protects. Commit `.terraform.lock.hcl` after normal authenticated initialization; it contains dependency hashes, not credentials.

## 3. Build and deploy

```bash
bash scripts/build.sh
# Reviewed chart version used for this package. Upgrade intentionally.
export HELM_CHART_VERSION=91.7.1
bash scripts/deploy.sh
python3 scripts/discover-negs.py
terraform -chdir=terraform/edge init
terraform -chdir=terraform/edge validate
terraform -chdir=terraform/edge plan -out=edge.tfplan
terraform -chdir=terraform/edge apply edge.tfplan
terraform -chdir=terraform/edge output
```

Build pushes one immutable container digest. Two deployments configure its independent A and B roles. Both clusters host their own in-cluster A → B call; this call does not traverse regions. Image digests, generated manifests and discovered NEG locations are saved under ignored local paths.

**NEG bootstrap ordering matters:** initial standalone-NEG readiness gates allow pods to become ready before a backend health check is attached. After edge provisioning, verify all endpoints healthy; a Kubernetes rollout alone does not prove public reachability.

The global edge root is deliberately separate from cluster creation: the GKE controller must create its NEGs before Terraform can attach them. Do not apply both roots simultaneously. Allow several minutes for load-balancer propagation.

## 4. Validate and generate useful data

```bash
bash scripts/smoke.sh
python3 scripts/load.py "$(terraform -chdir=terraform/edge output -raw url)"
# Optional deliberate readiness failure, ONLY on this assessment secondary cluster:
bash scripts/incident-drill.sh
bash scripts/smoke.sh
```

The smoke check asserts both services and A → B calls succeed and checks backend health for both regions. It records live evidence under `evidence/live/`. The load generator includes 404 requests; 404s are not server errors, so a zero 5xx rate is expected during healthy operation. The readiness drill preserves healthy old replicas; it need not cause customer-facing 5xx. Do not invent a nonzero error graph.

The readiness drill is **not** a cross-region failover test. See [resilience verification](docs/OPERATIONS.md) for a separate controlled failover procedure. Test events and screenshots must be identified as deliberate experiments.

## 5. Inspect BigQuery and Grafana

After generating traffic, allow log export delivery time. A sink exports new matching logs; it does not backfill historical data.

```bash
export PROJECT_ID="$(terraform -chdir=terraform/core output -raw project_id)"
bq ls "$PROJECT_ID:sre_logs"
sed "s/PROJECT_ID/$PROJECT_ID/g" sql/schema.sql | bq query --use_legacy_sql=false --location=US
sed "s/PROJECT_ID/$PROJECT_ID/g" sql/error_rate.sql | bq query --use_legacy_sql=false --location=US --maximum_bytes_billed=1000000000
bash scripts/grafana.sh primary
```

Log in as `admin` using the secret retrieval command printed by the script. In Cloud Shell use Web Preview on port 3000. Open **SRE assessment — applications and clusters**. The two BigQuery panels query both clusters; the four Prometheus panels describe the cluster where this Grafana runs. Stop the port-forward, then run `bash scripts/grafana.sh secondary` to inspect the other region.

The dashboard is provisioned from `observability/dashboard.json`, with your project substituted during rendering. For a standalone import, replace `PROJECT_ID` and ensure datasource UIDs are `bigquery` and `prometheus`. The provisioned BigQuery datasource caps **Max bytes billed** at 1 GB/query; verify that setting in the UI before prolonged use. Refresh is one minute, not real time. Save a screenshot/export only after queries return real data. `docs/BIGQUERY.md` defines the expected schema and troubleshooting steps.

## 6. Optional HTTPS

After obtaining the global IP, add an A record for an owned hostname at your DNS provider. Set `domain = "assessment.yourdomain.example"` in `terraform/edge/tls.auto.tfvars` and review/apply a new edge plan. The code creates a managed certificate, HTTPS listener and HTTP redirect. Wait for certificate status `ACTIVE`; certificate issuance requires correct public DNS. Do not use the placeholder domain. Cloud DNS zone ownership/delegation is not automated.

## 7. Publish the personal Git repository

After extracting the archive, create a private or public repository in your own GitHub account, according to the recruiter's access requirements. The package does not create an external repository.

```bash
git init -b main
git add .
git status --short
# Review: no tfvars, state, credentials, .generated content or raw live logs.
git commit -m "Build two-region GKE SRE assessment"
git remote add origin https://github.com/YOUR_USERNAME/schwab-sre-assessment.git
git push -u origin main
```

Copy sanitized cloud evidence into a deliberate `submission/` directory, with real UTC timestamps, tested URL, cloud deployment status, and actual observations. Add screenshots if requested. Give the reviewer access to the repository; public app endpoints contain synthetic demonstration data only. Do not expose Grafana publicly.

## 8. Teardown

Follow [CLEANUP.md](docs/CLEANUP.md). Destroy the edge before removing the Services that own NEGs, then monitoring/apps, then core resources. Preserve evidence and Terraform state until resource deletion is confirmed. Do not simply close Cloud Shell: billable resources continue running.

## Documentation

- [Architecture and design decisions](docs/ARCHITECTURE.md)
- [Requirement coverage and explicit gaps](docs/REQUIREMENTS.md)
- [BigQuery schema](docs/BIGQUERY.md)
- [Observed local incident and cloud drill](docs/TROUBLESHOOTING.md)
- [Operations, SLO and failover verification](docs/OPERATIONS.md)
- [Validation results](docs/VALIDATION.md)
- [Submission checklist](docs/SUBMISSION.md)
- [Official source references](docs/SOURCES.md)
