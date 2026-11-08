
import json
import logging
import os
import time
import uuid
from datetime import datetime, timezone

from kafka import KafkaProducer
from prometheus_client import Counter, start_http_server


# --------------------------------------------------
# Configuration
# --------------------------------------------------

KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "auth-events")
PRODUCE_INTERVAL = float(os.getenv("PRODUCE_INTERVAL", "1"))
METRICS_PORT = int(os.getenv("METRICS_PORT", "8000"))


# --------------------------------------------------
# Structured JSON logging
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s"
)

logger = logging.getLogger("producer")


def log_event(level, message, **fields):
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "producer",
        "level": level,
        "message": message,
        "topic": KAFKA_TOPIC,
        **fields
    }

    log_method = getattr(logger, level.lower())
    log_method(json.dumps(record))


# --------------------------------------------------
# Prometheus metrics
# --------------------------------------------------

EVENTS_PRODUCED = Counter(
    "events_produced_total",
    "Total number of events successfully published to Kafka",
    ["topic"]
)

PRODUCER_ERRORS = Counter(
    "producer_errors_total",
    "Total number of Kafka publishing errors",
    ["topic"]
)


# --------------------------------------------------
# Kafka producer
# --------------------------------------------------

def create_producer():
    security_protocol = os.getenv(
        "KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"
    )

    options = {
        "bootstrap_servers": KAFKA_BROKER,
        "security_protocol": security_protocol,
        "value_serializer": lambda value: json.dumps(value).encode("utf-8"),
    }

    if security_protocol == "SSL":
        options["ssl_cafile"] = os.getenv(
            "KAFKA_SSL_CA_FILE", "/etc/kafka-ca/ca.crt"
        )
        options["ssl_check_hostname"] = True

    return KafkaProducer(**options)


# --------------------------------------------------
# Main application
# --------------------------------------------------

def main():

    # Start Prometheus HTTP metrics endpoint
    start_http_server(METRICS_PORT)

    log_event(
        "INFO",
        "Producer metrics server started",
        metrics_port=METRICS_PORT
    )

    # Initialize Kafka producer
    producer = create_producer()

    log_event(
        "INFO",
        "Producer connected to Kafka",
        broker=KAFKA_BROKER,
        interval_seconds=PRODUCE_INTERVAL
    )

    # Continuously generate authentication events
    while True:

        event = {
            "event_id": str(uuid.uuid4()),
            "username": "alice",
            "source_ip": "192.0.2.15",
            "success": False,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        try:

            # Publish event to Kafka
            future = producer.send(
                KAFKA_TOPIC,
                value=event
            )

            # Wait for Kafka acknowledgement
            metadata = future.get(timeout=10)

            # Increment successful publish counter
            EVENTS_PRODUCED.labels(
                topic=KAFKA_TOPIC
            ).inc()

            # Write structured application log
            log_event(
                "INFO",
                "Event published successfully",
                event_id=event["event_id"],
                partition=metadata.partition,
                offset=metadata.offset
            )

        except Exception as error:

            # Count publishing failures
            PRODUCER_ERRORS.labels(
                topic=KAFKA_TOPIC
            ).inc()

            log_event(
                "ERROR",
                "Failed to publish event",
                error_type=type(error).__name__,
                error=str(error)
            )

        # Control event generation rate
        time.sleep(PRODUCE_INTERVAL)


if __name__ == "__main__":
    main()
