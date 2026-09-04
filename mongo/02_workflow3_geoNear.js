use gigtask;

const jobSite = {
  type: "Point",
  coordinates: [77.5946, 12.9716]
};

const explainResult = db.WorkerLocations.explain("executionStats").aggregate([
  {
    $geoNear: {
      near: jobSite,
      key: "location",
      distanceField: "distanceMeters",
      maxDistance: 5000,
      spherical: true
    }
  },
  {
    $match: {
      is_available: true
    }
  },
  {
    $limit: 10
  },
  {
    $project: {
      _id: 1,
      freelancer_id: 1,
      is_available: 1,
      location: 1,
      distanceMeters: 1,
      created_at: 1
    }
  }
]);
print(EJSON.stringify(explainResult, null, 2));
