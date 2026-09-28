"""Two stateless demo services, structured logs, and Prometheus metrics. No dependencies."""
import json, os, time, threading, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

APP = os.getenv("APP_NAME", "app-a")
CLUSTER = os.getenv("CLUSTER_NAME", "local")
UPSTREAM = os.getenv("UPSTREAM_URL", "")
BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5]
lock = threading.Lock()
counts = {}
bucket_counts = [0] * len(BUCKETS)
duration_count = 0
duration_sum = 0.0

def metrics():
    with lock:
        rows = ['# TYPE http_requests_total counter']
        for (route, status), count in counts.items():
            rows.append(f'http_requests_total{{app="{APP}",route="{route}",status="{status}"}} {count}')
        rows.append('# TYPE http_request_duration_seconds histogram')
        for b, count in zip(BUCKETS, bucket_counts):
            rows.append(f'http_request_duration_seconds_bucket{{app="{APP}",le="{b}"}} {count}')
        rows += [f'http_request_duration_seconds_bucket{{app="{APP}",le="+Inf"}} {duration_count}',
                 f'http_request_duration_seconds_count{{app="{APP}"}} {duration_count}',
                 f'http_request_duration_seconds_sum{{app="{APP}"}} {duration_sum}']
        return '\n'.join(rows) + '\n'

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        global duration_count, duration_sum
        start = time.monotonic()
        path = urlsplit(self.path).path
        if path == '/metrics':
            self.respond(200, metrics().encode(), 'text/plain; version=0.0.4')
            return
        if path in ('/healthz', '/readyz'):
            self.respond(200, b'{"status":"ok"}')
            return
        status = 200
        request_id = str(uuid.uuid4())
        body = {'application': APP, 'cluster': CLUSTER, 'hostname': os.getenv('HOSTNAME', 'local'),
                'request_id': request_id, 'message': 'Charles Schwab SRE assessment demo'}
        route = path if path in ('/', '/app-a', '/app-b', '/api/summary') else 'unmatched'
        if path == '/api/summary' and APP == 'app-a':
            try:
                # Keep this URL configuration-only; never fetch a user-supplied URL.
                with urlopen(Request(UPSTREAM + '/app-b', headers={'X-Request-ID': request_id}), timeout=2) as response:
                    body['upstream'] = json.load(response)
            except Exception:
                status = 502
                body['error'] = 'upstream unavailable'
        elif path not in ('/', '/' + APP):
            status = 404
            body['error'] = 'not found'
        self.respond(status, json.dumps(body).encode())
        elapsed = time.monotonic() - start
        with lock:
            counts[(route, status)] = counts.get((route, status), 0) + 1
            duration_count += 1
            duration_sum += elapsed
            for i, upper in enumerate(BUCKETS):
                bucket_counts[i] += int(elapsed <= upper)
        print(json.dumps({'severity': 'ERROR' if status >= 500 else 'INFO', 'app': APP,
                          'cluster': CLUSTER, 'path': route, 'status': status,
                          'latency_ms': round(elapsed * 1000, 3), 'request_id': request_id,
                          'parent_request_id': self.headers.get('X-Request-ID', '')}), flush=True)

    def respond(self, status, data, content_type='application/json'):
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0', int(os.getenv('PORT', '8080'))), Handler).serve_forever()
