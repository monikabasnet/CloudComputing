
import json
import logging
import os
import threading
import time
from collections import defaultdict
from datetime import datetime, timezone

from flask import Flask, Response, jsonify, request, g
from kafka import KafkaConsumer
from pymongo import MongoClient
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)


# --------------------------------------------------
# Application configuration
# --------------------------------------------------

KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "auth-events")

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DATABASE = os.getenv(
    "MONGODB_DATABASE", "threat_monitor"
)
MONGODB_COLLECTION = os.getenv(
    "MONGODB_COLLECTION", "security_events"
)

API_PORT = int(os.getenv("API_PORT", "8080"))

if not MONGODB_URI:
    raise RuntimeError("MONGODB_URI is required")


# --------------------------------------------------
# Structured JSON logging
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)

logger = logging.getLogger("processor")


def log_event(level, message, **fields):
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "processor",
        "level": level,
        "message": message,
        "topic": KAFKA_TOPIC,
        **fields,
    }

    getattr(logger, level.lower())(json.dumps(record))


# --------------------------------------------------
# Prometheus metrics
# --------------------------------------------------

EVENTS_PROCESSED = Counter(
    "events_processed_total",
    "Total events successfully processed",
    ["topic"],
)

MONGODB_INSERTS = Counter(
    "mongodb_inserts_total",
    "Total successful MongoDB inserts",
    ["collection"],
)

PROCESSING_ERRORS = Counter(
    "processing_errors_total",
    "Total Kafka event processing errors",
    ["error_type"],
)

HTTP_REQUESTS = Counter(
    "http_requests_total",
    "Total REST API requests",
    ["method", "endpoint", "status"],
)

HTTP_DURATION = Histogram(
    "http_request_duration_seconds",
    "REST API request duration in seconds",
    ["method", "endpoint"],
    buckets=(
        0.005, 0.01, 0.025, 0.05,
        0.1, 0.25, 0.5, 1.0, 2.5, 5.0
    ),
)


# --------------------------------------------------
# MongoDB connection
# --------------------------------------------------

mongo_client = MongoClient(MONGODB_URI)
database = mongo_client[MONGODB_DATABASE]
collection = database[MONGODB_COLLECTION]


# --------------------------------------------------
# Authentication classification
# --------------------------------------------------

failed_attempts = defaultdict(int)


def classify_event(event):
    username = event["username"]
    source_ip = event["source_ip"]
    success = event["success"]

    key = (username, source_ip)

    if success:
        failed_attempts[key] = 0
        status = "NORMAL"
    else:
        failed_attempts[key] += 1
        count = failed_attempts[key]

        if count >= 5:
            status = "POSSIBLE_BRUTE_FORCE"
        elif count >= 3:
            status = "SUSPICIOUS"
        else:
            status = "FAILED_LOGIN"

    processed_event = event.copy()
    processed_event["failed_attempts"] = failed_attempts[key]
    processed_event["status"] = status

    return processed_event


# --------------------------------------------------
# Kafka event processing
# --------------------------------------------------

def process_events():
    security_protocol = os.getenv(
        "KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"
    )

    options = {
        "bootstrap_servers": KAFKA_BROKER,
        "security_protocol": security_protocol,
        "value_deserializer": lambda value: json.loads(
            value.decode("utf-8")
        ),
        "auto_offset_reset": "earliest",
        "enable_auto_commit": False,
        "group_id": "ca0-threat-processor",
    }

    if security_protocol == "SSL":
        options["ssl_cafile"] = os.getenv(
            "KAFKA_SSL_CA_FILE", "/etc/kafka-ca/ca.crt"
        )
        options["ssl_check_hostname"] = True

    consumer = KafkaConsumer(KAFKA_TOPIC, **options)

    log_event(
        "INFO",
        "Kafka consumer started",
        broker=KAFKA_BROKER,
        consumer_group="ca0-threat-processor",
    )

    for message in consumer:
        try:
            event = message.value

            processed_event = classify_event(event)

            result = collection.insert_one(processed_event)

            MONGODB_INSERTS.labels(
                collection=MONGODB_COLLECTION
            ).inc()

            consumer.commit()

            EVENTS_PROCESSED.labels(
                topic=KAFKA_TOPIC
            ).inc()

            log_event(
                "INFO",
                "Event processed and stored",
                event_id=processed_event.get("event_id"),
                status=processed_event.get("status"),
                failed_attempts=processed_event.get(
                    "failed_attempts"
                ),
                mongodb_id=str(result.inserted_id),
                partition=message.partition,
                offset=message.offset,
            )

        except KeyError as error:
            PROCESSING_ERRORS.labels(
                error_type="malformed_event"
            ).inc()

            log_event(
                "ERROR",
                "Malformed event",
                error_type="KeyError",
                error=str(error),
            )

        except Exception as error:
            PROCESSING_ERRORS.labels(
                error_type=type(error).__name__
            ).inc()

            log_event(
                "ERROR",
                "Event processing failed",
                error_type=type(error).__name__,
                error=str(error),
            )


# --------------------------------------------------
# Flask REST API
# --------------------------------------------------

app = Flask(__name__)


@app.before_request
def start_request_timer():
    if request.path != "/metrics":
        g.request_start_time = time.perf_counter()


@app.after_request
def record_http_metrics(response):
    if request.path == "/metrics":
        return response

    duration = time.perf_counter() - getattr(
        g, "request_start_time", time.perf_counter()
    )

    endpoint = request.url_rule.rule if request.url_rule else "unmatched"

    HTTP_REQUESTS.labels(
        method=request.method,
        endpoint=endpoint,
        status=str(response.status_code),
    ).inc()

    HTTP_DURATION.labels(
        method=request.method,
        endpoint=endpoint,
    ).observe(duration)

    log_event(
        "INFO" if response.status_code < 500 else "ERROR",
        "REST request completed",
        method=request.method,
        endpoint=endpoint,
        status_code=response.status_code,
        duration_seconds=round(duration, 6),
    )

    return response


# --------------------------------------------------
# Prometheus metrics endpoint
# --------------------------------------------------

@app.get("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST,
    )


# --------------------------------------------------
# Health endpoint
# --------------------------------------------------

@app.get("/health")
def health():
    try:
        mongo_client.admin.command("ping")

        return jsonify({
            "status": "ok",
            "kafka_topic": KAFKA_TOPIC,
            "mongodb": "connected",
        })

    except Exception as error:
        log_event(
            "ERROR",
            "MongoDB health check failed",
            error_type=type(error).__name__,
        )

        return jsonify({
            "status": "error",
            "mongodb": "unavailable",
        }), 503


# --------------------------------------------------
# Events endpoint
# --------------------------------------------------

@app.get("/events")
def get_events():
    events = list(
        collection.find(
            {},
            {"_id": 0},
        ).sort("_id", -1).limit(100)
    )

    return jsonify(events)


# --------------------------------------------------
# Alerts endpoint
# --------------------------------------------------

@app.get("/alerts")
def get_alerts():
    alerts = list(
        collection.find(
            {
                "status": {
                    "$in": [
                        "SUSPICIOUS",
                        "POSSIBLE_BRUTE_FORCE",
                    ]
                }
            },
            {"_id": 0},
        ).sort("_id", -1).limit(100)
    )

    return jsonify(alerts)


# --------------------------------------------------
# Application startup
# --------------------------------------------------

if __name__ == "__main__":
    kafka_thread = threading.Thread(
        target=process_events,
        daemon=True,
    )

    kafka_thread.start()

    log_event(
        "INFO",
        "REST API starting",
        api_port=API_PORT,
    )

    app.run(
        host="0.0.0.0",
        port=API_PORT,
        debug=False,
    )
