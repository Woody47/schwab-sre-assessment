SELECT TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
       jsonPayload.app AS app, resource.labels.cluster_name AS cluster,
       APPROX_QUANTILES(jsonPayload.latency_ms,100)[OFFSET(50)] AS p50_ms,
       APPROX_QUANTILES(jsonPayload.latency_ms,100)[OFFSET(95)] AS p95_ms,
       APPROX_QUANTILES(jsonPayload.latency_ms,100)[OFFSET(99)] AS p99_ms
FROM `PROJECT_ID.sre_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND jsonPayload.app IN ('app-a','app-b')
GROUP BY 1,2,3 ORDER BY 1 DESC;
