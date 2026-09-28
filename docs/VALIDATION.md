# Validation record — September 27, 2026

## Passed in the build workspace

- Three Python integration tests: two services and Prometheus metrics; real local dependency failure/recovery; readiness path behavior.
- Terraform 1.13.3 formatting and HCL parsing (`terraform fmt -check -recursive`).
- Kubernetes generated application/dashboard schemas: 15 resources, 15 valid, zero invalid/errors.
- kube-prometheus-stack 91.7.1 Helm template rendering. Rendered monitoring schemas: 72 resources, 63 valid, nine skipped because their custom-resource schemas were unavailable, zero invalid/errors.
- Shell script syntax, Python compilation, dashboard JSON and workload consistency checks.
- Grafana BigQuery query format checked against plugin source and corrected to time-series format 0; datasource query cost cap configured.

## Blocked or not run

- Full Terraform provider validation: provider initialization was obtained from the official HashiCorp release, but the execution environment rejects the provider's Unix socket (`socket: operation not permitted`). No provider validation or plan success is claimed.
- Terraform apply, GKE scheduling, image build/push, real load-balancer traffic, SQL execution against BigQuery, Workload Identity authentication and live dashboard rendering: no authenticated target GCP account or Docker daemon is present.
- Kubernetes custom-resource server validation, Grafana BigQuery plugin runtime installation, cluster failover and readiness incident drill: require the deployed environment.
- GitHub workflow execution and public/private Git publishing: no GitHub connection supplied.

## Version choices

Terraform CLI used: 1.13.3. Google provider pinned: 7.46.1. Helm used: 3.19.0. Monitoring chart: 91.7.1. BigQuery Grafana plugin: 3.4.1. Application Python base tag: 3.12-slim; deployment resolves the built image to an immutable digest. Initialize providers normally in Cloud Shell and commit the resulting dependency lock files.

See `evidence/local-validation.txt` for actual command outputs. Local passes are not proof of a working cloud deployment. Run the README acceptance checks before submission.
