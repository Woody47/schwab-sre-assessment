# Submission checklist — complete only with observed evidence

- [ ] Personal Git URL exists and reviewer can access it.
- [ ] Core and edge Terraform validate and plan against the target account.
- [ ] Both clusters are Running and both apps have at least two available replicas each.
- [ ] Public `/app-a`, `/app-b` and `/api/summary` return expected JSON.
- [ ] Both regions' NEGs are healthy.
- [ ] Actual application URL and tested UTC timestamp recorded.
- [ ] Six Grafana panels display real data; project-specific dashboard export included.
- [ ] BigQuery schema checked; example SQL executes with bounded scan costs.
- [ ] Local incident honestly labelled, or actual GKE drill recorded with events and recovery.
- [ ] Optional failover experiment labelled and results recorded if run.
- [ ] No credential, state, raw secret, personal log or private tfvars committed.
- [ ] Scope omissions match reviewer expectations.
- [ ] Review window and teardown time agreed.

Suggested submission note after deployment: state the actual repo URL, public endpoint, tested date/time, dashboard artifact path, SQL directory, incident document and explicit omitted optional controls. Do not claim production-grade compliance, automatic tracing, successful DR or zero cost without evidence.
