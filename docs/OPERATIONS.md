# Operational checks

## Suggested demo SLO

Proposed availability: 99.9% successful eligible customer requests over 30 days. Proposed latency: 95% of eligible requests under 300 ms. These are design targets, not achieved measurements. Define eligible paths and whether expected 4xx count before adopting an SLO. For a 30-day time-based 99.9% target the illustrative error budget is 43.2 minutes; request-based budgets must be calculated from request counts. No production alert routing is configured.

## Controlled failover verification

After baseline smoke checks, save the secondary app HPAs and deployment replica counts locally. Remove the two secondary HPAs temporarily (otherwise they undo scale-to-zero), then scale only secondary App A and App B deployments to zero. Keep primary workloads healthy. Continuously request `/app-a`, `/app-b`, and `/api/summary`, recording timestamp, status and returned cluster. Wait for LB health/NEG propagation and quantify observed failed requests/recovery; do not assume instantaneous failover. Confirm successful responses identify `primary` after secondary drains.

Restore secondary Deployment replicas to two, reapply the generated application manifests (which restore HPAs), wait for both deployments, and confirm all NEG backends healthy. Run this only on the disposable assessment. Use a separate terminal or recovery automation to restore resources if the test terminal fails. Never modify both regions at once. A real regional outage includes additional failure modes beyond this test.

## Fast triage

```bash
kubectl -n apps get pods,deploy,svc,hpa,pdb -o wide
kubectl -n apps get endpointslices
kubectl -n apps describe pod POD_NAME
kubectl -n apps logs deploy/app-a --tail=100
kubectl -n apps get events --sort-by=.lastTimestamp
kubectl -n monitoring get pods
```

Always specify the intended `--context` when multiple clusters are configured. These examples use the currently selected context.

- Pending Pods: check allocatable capacity, requests, autoscaler events and quota.
- ImagePullBackOff: verify the image digest and node Artifact Registry Reader role.
- Public 502/503: inspect global backend health, Pod readiness, NEG membership, TCP 8080 firewall and NetworkPolicy.
- Cannot access Kubernetes API: compare current operator public IP to authorized CIDR. Update Terraform with the new trusted CIDR.
- CPU HPA shows unknown: allow metrics propagation, verify resource requests and resource metrics API; application Prometheus metrics are not required for CPU HPA.
- Rollback: redeploy a prior immutable image digest, watch rollout, then run end-to-end smoke checks. Reconcile the source/manifests afterward.

## Small demo limitations

Pods are lightweight but monitoring is not free. Cluster autoscaling may increase node count. Prometheus uses ephemeral storage with six-hour / 1 GB retention, and Grafana dashboards are source-provisioned. Pod replacement loses monitoring history and UI-only edits. External exports and source files are the assessment artifacts. PDB protects voluntary eviction only; it is not a guarantee of availability during crashes or zone loss.
