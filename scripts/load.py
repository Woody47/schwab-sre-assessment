#!/usr/bin/env python3
"""Bounded demonstration traffic. Run only against your assessment endpoint."""
import argparse,time,urllib.request,urllib.error,collections
p=argparse.ArgumentParser();p.add_argument('url');p.add_argument('--requests',type=int,default=120);a=p.parse_args()
assert 1<=a.requests<=2000
counts=collections.Counter()
for i in range(a.requests):
 path=['/app-a','/app-b','/api/summary','/missing'][i%4]
 try:
  with urllib.request.urlopen(a.url.rstrip('/')+path,timeout=5) as r:counts[r.status]+=1
 except urllib.error.HTTPError as e:counts[e.code]+=1
 except Exception:counts['connection_error']+=1
 time.sleep(.5)
print(dict(counts))
