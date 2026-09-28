SELECT timestamp, severity, resource.labels.cluster_name AS cluster,
       resource.labels.pod_name AS pod, jsonPayload.app AS app,
       jsonPayload.status AS status, jsonPayload.path AS path,
       jsonPayload.latency_ms AS latency_ms, jsonPayload.request_id AS request_id
FROM `PROJECT_ID.sre_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND jsonPayload.status >= 500
ORDER BY timestamp DESC LIMIT 100;
