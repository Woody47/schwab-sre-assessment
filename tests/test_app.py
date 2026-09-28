import unittest, subprocess,sys,os,socket,time,urllib.request,urllib.error,json,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def port():
 with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
class Integration(unittest.TestCase):
 def start(self,app,upstream=''):
  p=port(); log=tempfile.TemporaryFile(mode='w+')
  env={**os.environ,'APP_NAME':app,'PORT':str(p),'CLUSTER_NAME':'test','UPSTREAM_URL':upstream}
  proc=subprocess.Popen([sys.executable,str(ROOT/'app/server.py')],env=env,stdout=log,stderr=log)
  self.addCleanup(log.close);self.addCleanup(lambda: (proc.terminate(),proc.wait(timeout=5)))
  url=f'http://127.0.0.1:{p}'
  for _ in range(100):
   try:urllib.request.urlopen(url+'/readyz',timeout=.1).close();break
   except Exception:time.sleep(.02)
  else:self.fail('server did not start')
  return url,proc,log
 def get(self,url):
  try:r=urllib.request.urlopen(url,timeout=5)
  except urllib.error.HTTPError as e:r=e
  with r:return r.status,r.read().decode()
 def test_two_services_and_metrics(self):
  b,_,_=self.start('app-b');a,_,_=self.start('app-a',b)
  code,body=self.get(a+'/api/summary');self.assertEqual(code,200)
  self.assertEqual(json.loads(body)['upstream']['application'],'app-b')
  self.assertEqual(self.get(a+'/missing')[0],404)
  m=self.get(a+'/metrics')[1]
  self.assertIn('http_requests_total{app="app-a",route="/api/summary",status="200"} 1',m)
  self.assertIn('http_request_duration_seconds_count{app="app-a"} 2',m)
 def test_actual_dependency_failure_and_recovery(self):
  bp=port(); a,_,log=self.start('app-a',f'http://127.0.0.1:{bp}')
  code,body=self.get(a+'/api/summary');self.assertEqual(code,502)
  self.assertEqual(json.loads(body)['error'],'upstream unavailable')
  proc=subprocess.Popen([sys.executable,str(ROOT/'app/server.py')],env={**os.environ,'APP_NAME':'app-b','PORT':str(bp)},stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  self.addCleanup(lambda:(proc.terminate(),proc.wait(timeout=5)))
  for _ in range(100):
   code,_=self.get(a+'/api/summary')
   if code==200:break
   time.sleep(.02)
  self.assertEqual(code,200)
  time.sleep(.03);log.seek(0)
  logs=[json.loads(l) for l in log.read().splitlines()]
  self.assertTrue(any(x['status']==502 and x['severity']=='ERROR' for x in logs))
  self.assertTrue(any(x['status']==200 for x in logs))
 def test_readiness_wrong_path(self):
  a,_,_=self.start('app-a')
  self.assertEqual(self.get(a+'/wrong-ready-path')[0],404)
  self.assertEqual(self.get(a+'/readyz')[0],200)
if __name__=='__main__':unittest.main(verbosity=2)
