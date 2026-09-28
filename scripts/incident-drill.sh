#!/usr/bin/env bash
# Deliberate, recoverable readiness failure in the secondary assessment cluster only.
source "$(dirname "$0")/common.sh"
context secondary
mkdir -p evidence/live
restore() {
 kubectl --context "$CONTEXT" -n apps patch deploy app-b --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/readyz"}]'
 kubectl --context "$CONTEXT" -n apps rollout status deploy/app-b --timeout=5m
}
trap restore EXIT
kubectl --context "$CONTEXT" -n apps patch deploy app-b --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/wrong-ready-path"}]'
if kubectl --context "$CONTEXT" -n apps rollout status deploy/app-b --timeout=75s; then
 echo 'Unexpected success: inspect probe configuration'; exit 1
fi
kubectl --context "$CONTEXT" -n apps describe pods -l app=app-b > evidence/live/readiness-incident.txt
kubectl --context "$CONTEXT" -n apps get deploy,rs,pods -o wide >> evidence/live/readiness-incident.txt
printf 'Recorded readiness failure; exit trap restores the correct probe.\n'
