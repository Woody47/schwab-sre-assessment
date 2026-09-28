#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
context "${1:-primary}"
echo 'Retrieve the admin password in another terminal using:'
printf 'kubectl --context %q -n monitoring get secret grafana-admin -o jsonpath=\x27{.data.admin-password}\x27 | base64 -d\n' "$CONTEXT"
echo 'Open http://localhost:3000 (or Cloud Shell Web Preview port 3000). Username: admin.'
kubectl --context "$CONTEXT" -n monitoring port-forward svc/obs-grafana 3000:80
