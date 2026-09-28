#!/usr/bin/env python3
"""Discover controller-created NEGs from both clusters; never infer their zones."""
import json,subprocess,pathlib,time
root=pathlib.Path(__file__).resolve().parents[1]
def run(*args):return subprocess.check_output(args,cwd=root,text=True)
project=run('terraform','-chdir=terraform/core','output','-raw','project_id').strip()
backends={'app-a':[],'app-b':[]}
for cluster,zone in [('primary','us-central1-a'),('secondary','us-east1-b')]:
 run('gcloud','container','clusters','get-credentials','sre-'+cluster,'--zone',zone,'--project',project)
 ctx=f'gke_{project}_{zone}_sre-{cluster}'
 for app in backends:
  for attempt in range(60):
   svc=json.loads(run('kubectl','--context',ctx,'-n','apps','get','svc',app,'-o','json'))
   status=json.loads(svc['metadata'].get('annotations',{}).get('cloud.google.com/neg-status','{}'))
   name=status.get('network_endpoint_groups',{}).get('8080')
   if name and status.get('zones'):break
   time.sleep(5)
  else:raise SystemExit(f'NEG not ready: {cluster}/{app}. Inspect service events.')
  backends[app].extend({'name':name,'zone':z} for z in status['zones'])
p=root/'terraform/edge/backends.auto.tfvars.json'
p.write_text(json.dumps({'project_id':project,'backends':backends},indent=2))
print('Wrote discovered backends to',p)
