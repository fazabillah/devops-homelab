from flask import Flask, jsonify, Response, g, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import os
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP request count',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint']
)

@app.before_request
def before_request():
    g.start_time = time.time()

@app.after_request
def after_request(response):
    duration = time.time() - g.start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown'
    ).observe(duration)
    return response

@app.route("/")
def index():
    return jsonify({
        "status": "ok",
        "version": os.getenv("APP_VERSION", "unknown"),
        "environment": os.getenv("ENVIRONMENT", "development")
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
