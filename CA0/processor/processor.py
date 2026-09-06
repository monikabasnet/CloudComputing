import json
import os
import threading
from collections import defaultdict

from flask import Flask, jsonify
from kafka import KafkaConsumer
from pymongo import MongoClient


# Kafka settings
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "auth-events")

# Mongo settings
MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE", "threat_monitor")
MONGODB_COLLECTION = os.getenv("MONGODB_COLLECTION", "security_events")

# API port
API_PORT = int(os.getenv("API_PORT", "8080"))

# Validate config
if not MONGODB_URI:
    raise RuntimeError("MONGODB_URI environment variable is required")


# Mongo connection
mongo_client = MongoClient(MONGODB_URI)
database = mongo_client[MONGODB_DATABASE]
collection = database[MONGODB_COLLECTION]


# Failure counters
failed_attempts = defaultdict(int)


# Classify event
def classify_event(event):
    username = event["username"]
    source_ip = event["source_ip"]
    success = event["success"]

    # Tracking key
    key = (username, source_ip)

    # Check success
    if success:
        failed_attempts[key] = 0
        status = "NORMAL"
    else:
        # Count failure
        failed_attempts[key] += 1
        count = failed_attempts[key]

        # Assign status
        if count >= 5:
            status = "POSSIBLE_BRUTE_FORCE"
        elif count >= 3:
            status = "SUSPICIOUS"
        else:
            status = "FAILED_LOGIN"

    # Enrich event
    processed_event = event.copy()
    processed_event["failed_attempts"] = failed_attempts[key]
    processed_event["status"] = status

    return processed_event


# Process events
def process_events():

    # Kafka consumer
    consumer = KafkaConsumer(
        KAFKA_TOPIC,
        bootstrap_servers=KAFKA_BROKER,
        value_deserializer=lambda value: json.loads(
            value.decode("utf-8")
        ),
        auto_offset_reset="earliest",
        enable_auto_commit=False,
        group_id="ca0-threat-processor"
    )

    print(
        f"Listening for authentication events on "
        f"'{KAFKA_TOPIC}'..."
    )

    # Consume messages
    for message in consumer:
        try:
            event = message.value

            print(f"Received event: {event}")

            # Classify event
            processed_event = classify_event(event)

            # Store event
            result = collection.insert_one(processed_event)

            # Commit offset
            consumer.commit()

            print(
                f"Stored event_id={processed_event.get('event_id')} "
                f"status={processed_event.get('status')} "
                f"failed_attempts="
                f"{processed_event.get('failed_attempts')} "
                f"mongodb_id={result.inserted_id}"
            )

        except KeyError as error:
            print(
                f"Skipping malformed event. "
                f"Missing field: {error}"
            )

        except Exception as error:
            print(f"Error processing event: {error}")


# Flask app
app = Flask(__name__)


# Health endpoint
@app.get("/health")
def health():
    try:
        # Check MongoDB
        mongo_client.admin.command("ping")

        return jsonify({
            "status": "ok",
            "kafka_topic": KAFKA_TOPIC,
            "mongodb": "connected"
        })

    except Exception:
        return jsonify({
            "status": "error",
            "mongodb": "unavailable"
        }), 503


# Events endpoint
@app.get("/events")
def get_events():

    # Fetch events
    events = list(
        collection.find(
            {},
            {"_id": 0}
        ).sort("_id", -1).limit(100)
    )

    return jsonify(events)


# Alerts endpoint
@app.get("/alerts")
def get_alerts():

    # Fetch alerts
    alerts = list(
        collection.find(
            {
                "status": {
                    "$in": [
                        "SUSPICIOUS",
                        "POSSIBLE_BRUTE_FORCE"
                    ]
                }
            },
            {"_id": 0}
        ).sort("_id", -1).limit(100)
    )

    return jsonify(alerts)


# Start application
if __name__ == "__main__":

    # Kafka thread
    kafka_thread = threading.Thread(
        target=process_events,
        daemon=True
    )

    kafka_thread.start()

    print(f"REST API listening on port {API_PORT}")

    # Start API
    app.run(
        host="0.0.0.0",
        port=API_PORT,
        debug=False
    )