# CS6.302 – Software System Development
## Assignment 1 – Database Design
### Team 14 — Project 5: GigTask

**Project selection:** `project no = (team no % 5) + 1`; for Team 14, this gives Project 5 (GigTask).  
**Team:** 14  
**Due date:** 4 September 2026

## 1. Project overview

GigTask is a freelance micro-jobs marketplace implemented across PostgreSQL and MongoDB.

PostgreSQL stores transactional entities:
- clients
- freelancers
- contracts
- wallet_audit_logs

MongoDB stores flexible/realtime entities:
- GigReviews
- WorkerLocations

The implementation covers:
- wallet/escrow CHECK constraints
- immutable wallet audit trigger
- partial unique index for one active contract per freelancer
- materialized view for freelancer lifetime earnings
- atomic gig funding procedure
- 7-day moving-average + DENSE_RANK analytics
- 2dsphere + TTL indexes
- `$geoNear` nearest-worker workflow
- `$facet` review analytics
- Python stress-data generators

## 2. Assumptions

1. Currency is represented as `NUMERIC(12,2)` and is assumed to be the same currency for all clients/contracts.
2. A contract is "active" only when its status is `IN PROGRESS`.
3. Funding moves money from `clients.escrow_balance` into the contract's funded amount; the contract budget is therefore the amount reserved for that contract.
4. A client must have enough escrow balance before a contract can be funded.
5. A freelancer can have at most one `IN PROGRESS` contract, enforced by a partial unique index.
6. A completed contract contributes its budget to lifetime earnings.
7. Worker locations are GeoJSON points in `[longitude, latitude]` order.
8. Worker location documents contain `is_available`; `$geoNear` is followed by a match for availability.
9. Worker location records expire after 7200 seconds.
10. Review ratings are integers 1–5. Skill tags are stored as an array.
11. The geospatial workflow uses a 5 km radius (`5000` metres).
12. The seeders intentionally generate synthetic data and are not included as raw database dumps.
13. MongoDB's TTL deletion is asynchronous; expiry is not guaranteed to occur exactly at 7200 seconds.
14. PostgreSQL transaction control is handled according to PostgreSQL procedure semantics. The funding procedure locks the client row, validates the balance, performs the update and insert atomically, and commits on success. If an error is raised, PostgreSQL aborts the transaction; the caller should not wrap the CALL in an already-open transaction when using the procedure's COMMIT.

## 3. Repository structure

```text
team14_a1/
├── README.md
├── docs/
│   ├── relational_erd.png
│   └── mongo_schema_map.json
├── sql/
│   ├── 01_schema_ddl.sql
│   ├── 02_indexes.sql
│   ├── 03_triggers_and_audit.sql
│   ├── 04_stored_procedures.sql
│   ├── 05_materialized_views.sql
│   └── 06_window_analytics.sql
├── mongo/
│   ├── 01_collections_and_indexes.js
│   ├── 02_workflow3_geonear.js
│   └── 03_workflow4_facet.js
├── data_generation/
│   ├── postgres_seeder.py
│   ├── mongo_seeder.py
│   └── requirements.txt
└── performance/
    ├── postgres_explain_analyzes.txt
    └── mongo_execution_stats.json
```

## 4. Setup

### PostgreSQL

Create a database, then run in this order:

```bash
psql -d gigtask -f sql/01_schema_ddl.sql
psql -d gigtask -f sql/02_indexes.sql
psql -d gigtask -f sql/03_triggers_and_audit.sql
psql -d gigtask -f sql/04_stored_procedures.sql
psql -d gigtask -f sql/05_materialized_views.sql
```

Run the seed generator after installing Python requirements:

```bash
python -m pip install -r data_generation/requirements.txt
python data_generation/postgres_seeder.py
```

Run analytics:

```bash
psql -d gigtask -f sql/06_window_analytics.sql
```

### MongoDB

Open `mongosh` and run:

```javascript
load("mongo/01_collections_and_indexes.js")
load("mongo/02_workflow3_geonear.js")
load("mongo/03_workflow4_facet.js")
```

Seed:

```bash
python data_generation/mongo_seeder.py
```

Set `MONGO_URI` if MongoDB is not local.

## 5. Workflow 1 — Atomic Gig Funding

Example:

```sql
CALL sp_execute_gig_funding(1, 1, 250.00);
```

The procedure:
1. locks the client row using `FOR UPDATE`;
2. validates the requested amount;
3. verifies sufficient escrow balance;
4. deducts the client balance;
5. inserts the contract as `FUNDED`;
6. commits on success.

The wallet update fires the audit trigger.

## 6. Workflow 2 — Window analytics

`06_window_analytics.sql`:
- aggregates daily completed-contract revenue per freelancer;
- generates a calendar date series;
- calculates a 7-day moving average using a window frame;
- ranks freelancers with `DENSE_RANK()`.

The date-series approach makes the seven-day frame represent calendar days rather than merely the previous seven populated rows.

## 7. Workflow 3 — Nearest available worker

`02_workflow3_geonear.js` uses:
- `WorkerLocations.location` 2dsphere index;
- `$geoNear`;
- `maxDistance: 5000`;
- `distanceField`;
- availability filtering.

The example coordinate is replaceable with the actual job-site coordinate.

## 8. Workflow 4 — Multi-faceted review analytics

`03_workflow4_facet.js` uses `$facet` to produce in one aggregation:
1. rating distribution;
2. top skill tags after `$unwind`;
3. overall average rating.

## 9. Performance proof

The assignment requires raw execution statistics. The following evidence was generated from the seeded PostgreSQL and MongoDB databases.

PostgreSQL:

```bash
psql -d gigtask -f sql/06_window_analytics.sql
```

For the heavy query, run:

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- paste the SELECT statement from 06_window_analytics.sql here
;
```

Save the complete output to:

`performance/postgres_explain_analyzes.txt`

MongoDB:

```javascript
db.WorkerLocations.explain("executionStats").aggregate([
  {
    $geoNear: {
      near: { type: "Point", coordinates: [77.5946, 12.9716] },
      key: "location",
      distanceField: "distanceMeters",
      maxDistance: 5000,
      spherical: true
    }
  },
  { $match: { is_available: true } },
  { $limit: 10 }
]);
```

Save the complete JSON output to:

`performance/mongo_execution_stats.json`

**Do not fabricate these outputs.** The final submitted README should contain the actual plans from your database environment.

## 10. Verification checklist

- [ ] Team 14 uses Project 5.
- [ ] All SQL scripts execute without errors.
- [ ] Trigger creates audit rows after wallet updates.
- [ ] Partial unique index rejects a second `IN PROGRESS` contract for the same freelancer.
- [ ] Materialized view refreshes concurrently after its unique index exists.
- [ ] PostgreSQL has 100,000+ audit rows and 50,000+ contracts after seeding.
- [ ] MongoDB has 500,000+ worker-location pings after seeding.
- [ ] `$geoNear` uses the 2dsphere index.
- [ ] TTL index is present with 7200 seconds.
- [ ] Actual `EXPLAIN ANALYZE` and Mongo `executionStats` are copied into `performance/`.
- [ ] GitHub URL and final commit hash are added below.

## 11. Final GitHub information

**GitHub repository:** `https://github.com/Vikash-Maddheshiya-961/team14_a1`  
**Final commit hash:** `ca14023f28bf28798d69535bc9d3a1838a57b500`

## 12. Submission

Create the ZIP with only source/scripts/docs. Do not include:
- database dumps;
- CSV exports;
- MongoDB collection exports;
- Python virtual environments;
- `__pycache__`.

The final ZIP must be strictly under 20 MB.

### 9.1 Actual PostgreSQL EXPLAIN ANALYZE output

```text
                                                                                QUERY PLAN                                                                                
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=348.84..434.17 rows=3413 width=44) (actual time=3.772..6.931 rows=3420.00 loops=1)
   Group Key: ((created_at)::date), freelancer_id
   Buffers: shared hit=16 read=19
   ->  Sort  (cost=348.84..357.38 rows=3413 width=17) (actual time=3.740..3.992 rows=3439.00 loops=1)
         Sort Key: ((created_at)::date), freelancer_id
         Sort Method: quicksort  Memory: 231kB
         Buffers: shared hit=16 read=19
         ->  Index Only Scan using idx_completed_contracts_analytics on contracts  (cost=0.29..148.55 rows=3413 width=17) (actual time=0.168..1.965 rows=3439.00 loops=1)
               Index Cond: (created_at >= (CURRENT_DATE - '30 days'::interval))
               Heap Fetches: 11
               Index Searches: 1
               Buffers: shared hit=10 read=19
 Planning:
   Buffers: shared hit=212 read=1
 Planning Time: 1.421 ms
 Execution Time: 7.311 ms
(16 rows)


### 9.1 Actual PostgreSQL EXPLAIN ANALYZE output

```text
                                                                                QUERY PLAN                                                                                
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 GroupAggregate  (cost=348.84..434.17 rows=3413 width=44) (actual time=3.772..6.931 rows=3420.00 loops=1)
   Group Key: ((created_at)::date), freelancer_id
   Buffers: shared hit=16 read=19
   ->  Sort  (cost=348.84..357.38 rows=3413 width=17) (actual time=3.740..3.992 rows=3439.00 loops=1)
         Sort Key: ((created_at)::date), freelancer_id
         Sort Method: quicksort  Memory: 231kB
         Buffers: shared hit=16 read=19
         ->  Index Only Scan using idx_completed_contracts_analytics on contracts  (cost=0.29..148.55 rows=3413 width=17) (actual time=0.168..1.965 rows=3439.00 loops=1)
               Index Cond: (created_at >= (CURRENT_DATE - '30 days'::interval))
               Heap Fetches: 11
               Index Searches: 1
               Buffers: shared hit=10 read=19
 Planning:
   Buffers: shared hit=212 read=1
 Planning Time: 1.421 ms
 Execution Time: 7.311 ms
(16 rows)