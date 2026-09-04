import os
import random
from datetime import datetime, timedelta, timezone
from pymongo import MongoClient
from faker import Faker

fake = Faker()
random.seed(14)

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.getenv("MONGO_DB", "gigtask")

PINGS = 500_000
REVIEWS = 100_000
BATCH = 10_000

SKILLS = [
    "python", "sql", "javascript", "react", "java",
    "cpp", "design", "testing", "devops", "data-analysis",
    "writing", "marketing"
]

def seed_worker_locations(db):
    col = db.WorkerLocations
    col.delete_many({})

    now = datetime.now(timezone.utc)
    batch = []

    for i in range(PINGS):
        # Bengaluru-area synthetic points.
        lon = random.uniform(77.45, 77.75)
        lat = random.uniform(12.85, 13.15)

        batch.append({
            "freelancer_id": random.randint(1, 10_000),
            "is_available": random.random() < 0.65,
            "location": {
                "type": "Point",
                "coordinates": [lon, lat]
            },
            "created_at": now - timedelta(seconds=random.randint(0, 300))
        })

        if len(batch) >= BATCH:
            col.insert_many(batch)
            batch.clear()

    if batch:
        col.insert_many(batch)

def seed_reviews(db):
    col = db.GigReviews
    col.delete_many({})

    batch = []
    for i in range(REVIEWS):
        tags = random.sample(SKILLS, k=random.randint(1, 4))
        batch.append({
            "freelancer_id": random.randint(1, 10_000),
            "rating": random.randint(1, 5),
            "skill_tags": tags,
            "created_at": fake.date_time_between(
                start_date="-365d",
                end_date="now",
                tzinfo=timezone.utc
            ),
            "comment": fake.sentence()
        })

        if len(batch) >= BATCH:
            col.insert_many(batch)
            batch.clear()

    if batch:
        col.insert_many(batch)

def main():
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]

    seed_worker_locations(db)
    seed_reviews(db)

    print("WorkerLocations:", db.WorkerLocations.count_documents({}))
    print("GigReviews:", db.GigReviews.count_documents({}))

if __name__ == "__main__":
    main()