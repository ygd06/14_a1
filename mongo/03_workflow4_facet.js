use gigtask;


db.GigReviews.aggregate([
  {
    $facet: {
      rating_distribution: [
        {
          $group: {
            _id: "$rating",
            count: { $sum: 1 }
          }
        },
        {
          $sort: { _id: 1 }
        }
      ],

      top_skill_tags: [
        { $unwind: "$skill_tags" },
        {
          $group: {
            _id: "$skill_tags",
            count: { $sum: 1 }
          }
        },
        {
          $sort: { count: -1, _id: 1 }
        },
        { $limit: 20 }
      ],

      overall_average_rating: [
        {
          $group: {
            _id: null,
            average_rating: { $avg: "$rating" },
            review_count: { $sum: 1 }
          }
        }
      ]
    }
  }
]);
