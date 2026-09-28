-- Replace PROJECT_ID. Table is created by the sink after the first app stdout log.
SELECT TIMESTAMP_TRUNC(timestamp, MINUTE) AS minute,
       jsonPayload.app AS app, resource.labels.cluster_name AS cluster,
       COUNT(*) AS requests, COUNTIF(jsonPayload.status >= 500) AS errors,
       ROUND(100 * SAFE_DIVIDE(COUNTIF(jsonPayload.status >= 500), COUNT(*)), 2) AS error_pct
FROM `PROJECT_ID.sre_logs.stdout`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND jsonPayload.app IN ('app-a', 'app-b')
GROUP BY 1,2,3 ORDER BY 1 DESC;
