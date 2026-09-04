use gigtask;

// Flexible review documents.
db.createCollection("GigReviews", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["freelancer_id", "rating", "skill_tags", "created_at"],
      properties: {
        freelancer_id: { bsonType: "int" },
        rating: { bsonType: "int", minimum: 1, maximum: 5 },
        skill_tags: {
          bsonType: "array",
          items: { bsonType: "string" }
        },
        created_at: { bsonType: "date" }
      }
    }
  },
  validationLevel: "moderate"
});

// Real-time worker locations.
db.createCollection("WorkerLocations");

db.GigReviews.createIndex({ freelancer_id: 1, created_at: -1 });
db.GigReviews.createIndex({ rating: 1 });

db.WorkerLocations.createIndex({ location: "2dsphere" });
db.WorkerLocations.createIndex(
  { created_at: 1 },
  { expireAfterSeconds: 7200 }
);

print("GigReviews indexes:");
printjson(db.GigReviews.getIndexes());

print("WorkerLocations indexes:");
printjson(db.WorkerLocations.getIndexes());
