# Requirement coverage

All “implemented” entries refer to code, not a completed cloud deployment.

| Assessment item | Package coverage | Acceptance evidence still needed |
|---|---|---|
| New project / folder | Optional project creation and existing-folder attachment; existing-project default | Actual billing-enabled project; folder only if available |
| Dev/Ops/SRE/CI IAM | Parameterized additive IAM grants; least-privilege node/Grafana identities | Real group mappings and team RBAC decisions |
| Two GKE clusters | Implemented, separate regions, zonal Standard | Both clusters Running |
| Segregated networking | VPC, cluster subnets, separate Pod/Service ranges, NAT, API access, firewall | Connectivity and authorized operator access |
| Shared VPC | Optional; not implemented | Not required for standalone personal project |
| Two apps, multi-pod, HPA | Implemented in both clusters | Replica and HPA output |
| ConfigMaps / secrets | App ConfigMaps; generated Grafana Kubernetes Secret | Working Grafana login; apps need no secret |
| Single global endpoint / failover | Terraform global external ALB + standalone NEGs; substitutes for MCI | Healthy regional backends, public URL, controlled failover result |
| HTTPS / DNS | Managed TLS supported with supplied domain; DNS record manual | Actual owned hostname and ACTIVE certificate |
| Cloud Logging / Monitoring | GKE collection enabled; logs sink to BigQuery | Log entries and GKE metrics |
| Grafana hosted in cloud | Self-hosted on GKE in both clusters | Successful live UI access; not Grafana Cloud SaaS |
| Four or more panels | Six-panel JSON export supplied | Real data in panels after deployment |
| BigQuery log queries | Schema inspection, errors, latency, incident queries | Queries against actual sink-created tables |
| Tracing / profiling / Error Reporting | Not implemented; request-ID log correlation only | Explicit scope reduction or additional implementation |
| VPC/firewall/LB log export to BQ | LB logging enabled; BQ sink currently selects GKE resource logs only; VPC/firewall flow logs not enabled | Optional extension, not full coverage |
| Service mesh / mTLS | Not implemented (optional in brief) | Scope note |
| Cloud Armor / Binary Authorization | Not implemented | Scope note; required if reviewer insists on all security items |
| Secret Manager | Not implemented; no application secret required | Scope note |
| Stateful HA / backups | No stateful application dependencies; infrastructure reproducible | Not applicable to demo app; no backup recovery claim |
| Screenshot or dashboard export | Source dashboard JSON export supplied | Prefer live screenshot plus deployment-specific export |
| Troubleshooting scenario | Actual local upstream outage tested; scripted GKE probe drill | Run and record GKE drill if cloud-specific incident is expected |
| Personal Git link | Files and validation workflow supplied | Publish in user's Git account |

Free-tier allowance in the brief does not make every omission automatically acceptable. Confirm material scope reductions with the reviewer. This package emphasizes the core acceptance items; it must not be described as a fully implemented enterprise environment.
