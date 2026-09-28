#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require helm
echo "Cleanup target: $PROJECT_ID. Preserve evidence and review the destruction plans."
# Interactive terraform apply prompts deliberately retained for destruction.
terraform -chdir=terraform/edge destroy
for CLUSTER in primary secondary; do
 context "$CLUSTER"
 helm uninstall obs --namespace monitoring --kube-context "$CONTEXT"
 kubectl --context "$CONTEXT" delete namespace apps monitoring --wait=true --timeout=10m
done
terraform -chdir=terraform/core apply -var=deletion_protection=false
terraform -chdir=terraform/core destroy -var=deletion_protection=false
# Nonempty BigQuery data intentionally blocks deletion; see docs/CLEANUP.md.
