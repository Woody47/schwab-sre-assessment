# Observed incident: App A dependency unavailable

**Environment:** local Python HTTP processes during automated integration testing, September 27, 2026. This is a deliberate local fault injection, not a GKE production incident.

**Symptom:** App A's `/api/summary` returned HTTP 502 with `upstream unavailable`. Its structured log recorded ERROR severity and numeric status 502. App A itself remained running and its health endpoint was available.

**Reproduction:** configure `UPSTREAM_URL` to a local TCP port with no listening App B process, then request the summary endpoint. The test controls the dependency rather than fabricating a log entry.

**Diagnosis:** the summary route depends on B. A was responsive, but the dependency socket was not available. In GKE the equivalent investigation is: inspect B's Deployment/Pods, Service selector, EndpointSlices, readiness events, DNS resolution and NetworkPolicy before changing A's resource limits.

**Resolution actually tested:** start App B at the configured dependency address, repeat the summary request, and observe HTTP 200 containing `upstream.application = app-b`. The test verifies both the failed and recovered logs. A's existing two-second upstream timeout bounds failure latency; a 502 distinguishes dependency failure from a client route error.

**Prevention:** validate dependency configuration and A→B calls in post-deployment checks. Keep readiness aligned with the service's ability to serve traffic. Whether readiness should depend on downstream health is an explicit design choice; tying every readiness probe to downstreams can cause cascading removal of otherwise useful endpoints.

Reproduce with:

```bash
python3 -m unittest discover -s tests -v
```

## Separate GKE drill — not yet executed

`scripts/incident-drill.sh` patches the secondary App B readiness path to `/wrong-ready-path` (returns 404). The new replica should remain NotReady and rollout should time out; `maxUnavailable=0` keeps old replicas serving. It records Pod events/rollout state, then restores `/readyz` through an EXIT trap and waits for recovery.

Before running, ensure old replicas are healthy and the endpoint works. Record actual UTC start/recovery timestamps, specific Pod events, HTTP results, and any deviation from expectations. If the shell is force-killed, manually restore the correct probe path and wait for rollout. The exact patch commands are in the script. Do not label this pending drill as completed.
