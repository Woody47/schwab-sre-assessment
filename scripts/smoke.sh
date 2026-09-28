#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require curl
URL="$(terraform -chdir=terraform/edge output -raw url)"
mkdir -p evidence/live
for path in /app-a /app-b /api/summary; do
  response="$(curl --fail --silent --show-error --retry 10 --retry-all-errors --retry-delay 10 --max-time 10 "$URL$path")"
  printf '%s\n' "$response"
  RESPONSE="$response" PATH_CHECK="$path" python3 - <<'PY'
import json,os
x=json.loads(os.environ['RESPONSE']); p=os.environ['PATH_CHECK']
assert x['application']==('app-b' if p=='/app-b' else 'app-a')
assert x['cluster'] in ['primary','secondary']
if p=='/api/summary': assert x['upstream']['application']=='app-b'
PY
done
for CLUSTER in primary secondary; do
  context "$CLUSTER"
  kubectl --context "$CONTEXT" -n apps get deploy,pods,hpa,pdb -o wide > "evidence/live/$CLUSTER-workloads.txt"
  kubectl --context "$CONTEXT" -n apps logs -l app=app-a --tail=10 > "evidence/live/$CLUSTER-app-a-logs.txt"
done
for APP in app-a app-b; do
  gcloud compute backend-services get-health "sre-$APP" --global --project "$PROJECT_ID" --format=json > "evidence/live/$APP-backends.json"
  python3 - "evidence/live/$APP-backends.json" <<'PY'
import json,sys
x=json.load(open(sys.argv[1]))
assert len(x)>=2, 'Expected backends in both regions'
for b in x:
 health=b.get('status',{}).get('healthStatus',[])
 assert health and all(h['healthState']=='HEALTHY' for h in health), b
PY
done
printf '%s\n' "$URL" > evidence/live/endpoint.txt
printf 'Smoke checks passed. Inspect both Grafana instances and BigQuery next.\n'
