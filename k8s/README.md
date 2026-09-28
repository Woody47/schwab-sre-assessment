# Kubernetes manifests

`scripts/render.py` generates application resources, ServiceMonitor, dashboard ConfigMap and monitoring Helm values from an explicit project, image digest and cluster name.

Generated files live in `.generated/primary` and `.generated/secondary`; they are intentionally excluded from source control. Deploy with `scripts/deploy.sh`, which uses explicit Kubernetes contexts. Both apps have two replicas, CPU HPA, PDB, ConfigMap, probes and restricted container execution. Grafana credentials are generated per cluster into a Kubernetes Secret, not written into these files.
