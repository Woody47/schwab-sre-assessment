#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require helm
: "${HELM_CHART_VERSION:?Set HELM_CHART_VERSION to the reviewed kube-prometheus-stack chart version; see README}"
IMAGE="$(cat .generated/image.txt)"
GRAFANA_SA="$(terraform -chdir=terraform/core output -raw grafana_service_account)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
for CLUSTER in primary secondary; do
  context "$CLUSTER"
  OUT=".generated/$CLUSTER"
  python3 scripts/render.py --project "$PROJECT_ID" --image "$IMAGE" --cluster "$CLUSTER" --grafana-sa "$GRAFANA_SA" --output "$OUT"
  kubectl --context "$CONTEXT" apply -f "$OUT/apps.json"
  kubectl --context "$CONTEXT" create namespace monitoring --dry-run=client -o yaml | kubectl --context "$CONTEXT" apply -f -
  if ! kubectl --context "$CONTEXT" -n monitoring get secret grafana-admin >/dev/null 2>&1; then
    # Create secret through stdin; do not place credentials in shell args or repository files.
    python3 -c 'import json,secrets; print(json.dumps({"apiVersion":"v1","kind":"Secret","metadata":{"name":"grafana-admin","namespace":"monitoring"},"stringData":{"admin-user":"admin","admin-password":secrets.token_urlsafe(32)}}))' | kubectl --context "$CONTEXT" apply -f -
  fi
  helm upgrade --install obs prometheus-community/kube-prometheus-stack --version "$HELM_CHART_VERSION" \
    --namespace monitoring --kube-context "$CONTEXT" -f "$OUT/monitoring-values.json" --wait --timeout 15m
  kubectl --context "$CONTEXT" apply -f "$OUT/servicemonitor.json" -f "$OUT/dashboard.json"
  kubectl --context "$CONTEXT" -n apps rollout status deployment/app-a --timeout=10m
  kubectl --context "$CONTEXT" -n apps rollout status deployment/app-b --timeout=10m
done
printf 'Applications and monitoring deployed. Run scripts/discover-negs.py next.\n'
