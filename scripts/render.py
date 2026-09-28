#!/usr/bin/env python3
"""Render deployable JSON (valid YAML) from explicit deployment inputs."""
import argparse,json,pathlib
p=argparse.ArgumentParser()
p.add_argument('--project',required=True);p.add_argument('--image',required=True)
p.add_argument('--cluster',required=True,choices=['primary','secondary'])
p.add_argument('--grafana-sa',required=True);p.add_argument('--output',required=True)
a=p.parse_args();out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
def obj(kind,name,spec=None,api='v1',ns='apps',**kwargs):
 d={'apiVersion':api,'kind':kind,'metadata':{'name':name}}
 if ns:d['metadata']['namespace']=ns
 if spec is not None:d['spec']=spec
 d.update(kwargs);return d
items=[obj('Namespace','apps',ns=None),obj('ServiceAccount','web',automountServiceAccountToken=False)]
for app in ['app-a','app-b']:
 labels={'app':app}
 env={'APP_NAME':app,'CLUSTER_NAME':a.cluster,'UPSTREAM_URL':'http://app-b.apps.svc.cluster.local:8080'}
 items.append(obj('ConfigMap',app,data=env))
 items.append(obj('Deployment',app,api='apps/v1',spec={
  'replicas':2,'selector':{'matchLabels':labels},
  'strategy':{'type':'RollingUpdate','rollingUpdate':{'maxSurge':1,'maxUnavailable':0}},
  'template':{'metadata':{'labels':labels},'spec':{
   'serviceAccountName':'web','automountServiceAccountToken':False,'terminationGracePeriodSeconds':30,
   'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}},
   'topologySpreadConstraints':[{'maxSkew':1,'topologyKey':'kubernetes.io/hostname','whenUnsatisfiable':'ScheduleAnyway','labelSelector':{'matchLabels':labels}}],
   'containers':[{'name':'web','image':a.image,'imagePullPolicy':'IfNotPresent',
    'ports':[{'name':'http','containerPort':8080}],
    'envFrom':[{'configMapRef':{'name':app}}],
    'resources':{'requests':{'cpu':'100m','memory':'64Mi'},'limits':{'cpu':'500m','memory':'128Mi'}},
    'securityContext':{'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}},
    'readinessProbe':{'httpGet':{'path':'/readyz','port':'http'},'periodSeconds':5},
    'livenessProbe':{'httpGet':{'path':'/healthz','port':'http'},'initialDelaySeconds':10,'periodSeconds':10},
    'startupProbe':{'httpGet':{'path':'/healthz','port':'http'},'failureThreshold':30,'periodSeconds':2}}]}}}))
 svc=obj('Service',app,spec={'selector':labels,'ports':[{'name':'http','port':8080,'targetPort':'http'}]})
 svc['metadata']['labels']=labels
 svc['metadata']['annotations']={'cloud.google.com/neg':json.dumps({'exposed_ports':{'8080':{'name':f'sre-{a.cluster}-{app}'}}})}
 items.append(svc)
 items.append(obj('HorizontalPodAutoscaler',app,api='autoscaling/v2',spec={
  'scaleTargetRef':{'apiVersion':'apps/v1','kind':'Deployment','name':app},'minReplicas':2,'maxReplicas':4,
  'metrics':[{'type':'Resource','resource':{'name':'cpu','target':{'type':'Utilization','averageUtilization':65}}}],
  'behavior':{'scaleDown':{'stabilizationWindowSeconds':180}}}))
 items.append(obj('PodDisruptionBudget',app,api='policy/v1',spec={'minAvailable':1,'selector':{'matchLabels':labels}}))
 # Ingress: peer apps, monitoring, and Google proxy/health-check ranges only.
 items.append(obj('NetworkPolicy',app,api='networking.k8s.io/v1',spec={
  'podSelector':{'matchLabels':labels},'policyTypes':['Ingress','Egress'],
  'ingress':[{'from':[{'podSelector':{}},{'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'monitoring'}}},
                     {'ipBlock':{'cidr':'130.211.0.0/22'}},{'ipBlock':{'cidr':'35.191.0.0/16'}}],
              'ports':[{'port':8080,'protocol':'TCP'}]}],
  'egress':[{'to':[{'podSelector':{}}],'ports':[{'port':8080,'protocol':'TCP'}]},
            {'to':[{'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'kube-system'}}}],
             'ports':[{'port':53,'protocol':'UDP'},{'port':53,'protocol':'TCP'}]}]}))
(out/'apps.json').write_text(json.dumps({'apiVersion':'v1','kind':'List','items':items},indent=2))
sm=obj('ServiceMonitor','web',api='monitoring.coreos.com/v1',ns='monitoring',spec={
 'namespaceSelector':{'matchNames':['apps']},'selector':{'matchExpressions':[{'key':'app','operator':'In','values':['app-a','app-b']}]},
 'endpoints':[{'port':'http','path':'/metrics','interval':'30s'}]})
sm['metadata']['labels']={'release':'obs'}
(out/'servicemonitor.json').write_text(json.dumps(sm,indent=2))
dashboard=json.loads(pathlib.Path('observability/dashboard.json').read_text().replace('PROJECT_ID',a.project))
cm=obj('ConfigMap','assessment-dashboard',ns='monitoring',data={'assessment.json':json.dumps(dashboard)})
cm['metadata']['labels']={'grafana_dashboard':'1'}
(out/'dashboard.json').write_text(json.dumps(cm,indent=2))
values={
 'defaultRules':{'create':False},'alertmanager':{'enabled':False},
 'kubeEtcd':{'enabled':False},'kubeControllerManager':{'enabled':False},'kubeScheduler':{'enabled':False},'kubeProxy':{'enabled':False},
 'prometheus':{'prometheusSpec':{'retention':'6h','retentionSize':'1GB','resources':{'requests':{'cpu':'200m','memory':'512Mi'},'limits':{'memory':'1536Mi'}},
   'externalLabels':{'cluster':a.cluster},'serviceMonitorSelectorNilUsesHelmValues':True}},
 'grafana':{'serviceAccount':{'create':True,'name':'grafana','annotations':{'iam.gke.io/gcp-service-account':a.grafana_sa}},
  'admin':{'existingSecret':'grafana-admin','userKey':'admin-user','passwordKey':'admin-password'},
  'service':{'type':'ClusterIP'},'persistence':{'enabled':False},
  'plugins':['grafana-bigquery-datasource@3.4.1'],
  'resources':{'requests':{'cpu':'100m','memory':'256Mi'},'limits':{'memory':'512Mi'}},
  'additionalDataSources':[{'name':'BigQuery','uid':'bigquery','type':'grafana-bigquery-datasource','access':'proxy',
     'jsonData':{'authenticationType':'gce','defaultProject':a.project,'processingLocation':'US','MaxBytesBilled':1000000000}}],
  'sidecar':{'dashboards':{'enabled':True,'label':'grafana_dashboard'},'datasources':{'defaultDatasourceEnabled':True,'uid':'prometheus'}}}}
(out/'monitoring-values.json').write_text(json.dumps(values,indent=2))
