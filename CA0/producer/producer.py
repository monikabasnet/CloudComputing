import json
import os
import uuid
from datetime import datetime, timezone

from kafka import KafkaProducer


KAFKA_BROKER = os.getenv("KAFKA_BROKER", "localhost:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "auth-events")


producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKER,
    value_serializer=lambda value: json.dumps(value).encode("utf-8")
)


event = {
    "event_id": str(uuid.uuid4()),
    "username": "alice",
    "source_ip": "192.0.2.15",
    "success": False,
    "timestamp": datetime.now(timezone.utc).isoformat()
}


future = producer.send(KAFKA_TOPIC, value=event)
metadata = future.get(timeout=10)

print(f"Published event: {event}")
print(
    f"Kafka topic={metadata.topic}, "
    f"partition={metadata.partition}, "
    f"offset={metadata.offset}"
)

producer.flush()
producer.close()