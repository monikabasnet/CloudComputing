import json
import os
from collections import defaultdict

from kafka import KafkaConsumer
from pymongo import MongoClient


# Configuration
KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "auth-events")

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE", "threat_monitor")
MONGODB_COLLECTION = os.getenv("MONGODB_COLLECTION", "security_events")

if not MONGODB_URI:
    raise RuntimeError("MONGODB_URI environment variable is required")


# Track consecutive failed login attempts by username and source IP
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


# Connect to MongoDB
mongo_client = MongoClient(MONGODB_URI)
database = mongo_client[MONGODB_DATABASE]
collection = database[MONGODB_COLLECTION]


# Connect to Kafka
consumer = KafkaConsumer(
    KAFKA_TOPIC,
    bootstrap_servers=KAFKA_BROKER,
    value_deserializer=lambda value: json.loads(value.decode("utf-8")),
    auto_offset_reset="earliest",
    enable_auto_commit=True,
    group_id="ca0-threat-processor"
)


print(f"Listening for authentication events on '{KAFKA_TOPIC}'...")


# Consume and process events continuously
for message in consumer:
    try:
        event = message.value

        print(f"Received event: {event}")

        processed_event = classify_event(event)

        result = collection.insert_one(processed_event)

        print(
            f"Stored event_id={processed_event.get('event_id')} "
            f"status={processed_event.get('status')} "
            f"failed_attempts={processed_event.get('failed_attempts')} "
            f"mongodb_id={result.inserted_id}"
        )

    except KeyError as error:
        print(f"Skipping malformed event. Missing field: {error}")

    except Exception as error:
        print(f"Error processing event: {error}")