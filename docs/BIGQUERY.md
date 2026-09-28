# BigQuery schema and query contract

The sink writes partitioned tables to `PROJECT_ID.sre_logs`. GKE application logs on stdout normally appear in `stdout`; other log IDs create other tables. The first arriving log determines additional payload fields. Keep field types consistent and use `sql/schema.sql` before executing dashboard queries.

| Expected field | Type | Origin |
|---|---|---|
| `timestamp` | TIMESTAMP | Cloud Logging entry timestamp; time filter/partition pruning |
| `severity` | STRING | Structured severity (INFO or ERROR) |
| `resource.labels.cluster_name` | STRING | GKE resource labels |
| `resource.labels.namespace_name` | STRING | `apps` |
| `resource.labels.pod_name` | STRING | Pod identity |
| `jsonPayload.app` | STRING | `app-a` or `app-b` |
| `jsonPayload.cluster` | STRING | `primary` or `secondary` |
| `jsonPayload.status` | INTEGER | HTTP status code |
| `jsonPayload.latency_ms` | FLOAT | Application handling duration |
| `jsonPayload.path` | STRING | Bounded route label; unknown paths become `unmatched` |
| `jsonPayload.request_id` | STRING | Per-request UUID |
| `jsonPayload.parent_request_id` | STRING | A request ID carried on A→B calls |

Field case is not significant in BigQuery SQL. Raw exported nested paths must still match the actual schema; do not substitute the different Log Analytics linked-dataset schema. The SQL files target a Logging export, not Log Analytics.

`latency_ms` measures service-side handling and includes a dependency call for A's summary route. It does not include all client-to-edge network latency. Internal B requests and external B requests are both counted. A synthetic client SLI should use an external probe or LB logs to avoid double-counting a customer journey.

Health and metrics paths do not emit application request logs, preventing probe noise in these panels. BigQuery approximate quantiles are appropriate for a demo but unstable with few requests. Generate sustained low-volume traffic first. No-data differs from zero-error.

## Debugging

1. `bq ls PROJECT_ID:sre_logs` — no `stdout` table can mean no new application traffic, propagation delay or sink IAM failure.
2. Inspect sink writer identity; it must hold `roles/bigquery.dataEditor` on this dataset.
3. Check Cloud Logging export errors and BigQuery `export_errors` tables for schema conflicts. Do not change numeric status fields into strings.
4. Grafana 403: verify KSA `monitoring/grafana`, its GSA annotation, Workload Identity User binding, Job User role and dataset Data Viewer.
5. No metric panels: check ServiceMonitor selector, Prometheus targets, kubelet permissions and correct cluster Grafana instance.
6. Cap query bytes and retain time filters. Seven-day default table expiration bounds table lifetime; change to partition expiration for long-running production logging rather than letting whole tables expire.

The app code supplies logs; schema descriptions here are an expected contract, not evidence that any cloud table exists yet.
