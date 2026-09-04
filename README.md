# CS6.302 – Software System Development
## Assignment 1 – Database Design
### Team 14 — Project 5: GigTask

**Project selection:** `project no = (team no % 5) + 1`; for Team 14, this gives Project 5 (GigTask).  
**Team:** 14  

## Team Members
1. **Name:** Vikash Maddheshiya <br>
   **Roll number:** 2026202015
2. **Name:** Yerra Gnanadeepak <br>
   **Roll number:** 2026201008
3. **Name:** Vigneshwar Mahalingam <br>
   **Roll number:** 2026204005
4. **Name:** VarshithaVallabhadasu <br>
   **Roll number:** 2026204002
   
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
- automatic wallet audit trigger
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
3. Funding deducts the requested amount from `clients.escrow_balance` and creates a `FUNDED` contract whose `budget` represents the amount reserved for that contract.
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
14_a1/
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

Create a database called gigtask, then run in this order:

```bash
sudo -u postgres psql -d gigtask -f sql/01_schema_ddl.sql
sudo -u postgres psql -d gigtask -f sql/02_indexes.sql
sudo -u postgres psql -d gigtask -f sql/03_triggers_and_audit.sql
sudo -u postgres psql -d gigtask -f sql/04_stored_procedures.sql
sudo -u postgres psql -d gigtask -f sql/05_materialized_views.sql
```

Run the seed generator after installing Python requirements:

```bash
python -m pip install -r data_generation/requirements.txt
python data_generation/postgres_seeder.py
```

Run analytics:

```bash
sudo -u postgres psql -d gigtask -f sql/06_window_analytics.sql
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
5. inserts the contract with status `FUNDED` and the requested amount as its `budget`;
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

The example coordinate can be replaced with the actual job-site coordinate.

## 8. Workflow 4 — Multi-faceted review analytics

`03_workflow4_facet.js` uses `$facet` to produce in one aggregation:
1. rating distribution;
2. top skill tags after `$unwind`;
3. overall average rating.



## 9. Performance Proof

Performance results for the PostgreSQL and MongoDB workflows were collected from the seeded databases using the respective database execution-analysis tools.

The complete raw performance outputs are stored in the `performance/` directory.

### 9.1 PostgreSQL

Performance was measured using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` on the Workflow 2 window-analytics query.

**Overview:**
- Planning Time: `4.207 ms`
- Execution Time: `17030.441 ms`
- The plan contains `WindowAgg` operations for the 7-day moving average and `DENSE_RANK()`.
- Approximately `3,660,000` freelancer-day rows were processed.

**Raw output:** `performance/postgres_explain_analyzes.txt`

### 9.2 MongoDB

Performance was measured using `explain("executionStats")` on the Workflow 3 `$geoNear` nearest-worker query.

**Overview:**
- Execution Time: `54 ms`
- Total Index Keys Examined: `9,748`
- Total Documents Examined: `9,220`
- Geospatial stage: `GEO_NEAR_2DSPHERE`
- Index used: `location_2dsphere`

**Raw output:** `performance/mongo_execution_stats.json`

The performance outputs were generated from the seeded database environments and were not manually fabricated.

## 10. Verification checklist

- [✓] Team 14 uses Project 5.
- [✓] All SQL scripts execute without errors.
- [✓] Trigger creates audit rows after wallet balance updates.
- [✓] Partial unique index rejects a second `IN PROGRESS` contract for the same freelancer.
- [✓] Materialized view refreshes correctly after its required unique index exists.
- [✓] PostgreSQL contains 100,000+ wallet audit rows and 50,000+ contracts after seeding.
- [✓] MongoDB contains 500,000+ worker-location pings after seeding.
- [✓] `$geoNear` uses the 2dsphere index.
- [✓] TTL index is present with an expiration time of 7200 seconds.
- [✓] Actual PostgreSQL `EXPLAIN ANALYZE` output is stored in `performance/postgres_explain_analyzes.txt`.
- [✓] Actual MongoDB `executionStats` output is stored in `performance/mongo_execution_stats.json`.
- [✓] GitHub repository URL and final commit hash are included below.

## 11. Final GitHub information

**GitHub repository:** `https://github.com/ygd06/14_a1`

**Final commit hash:** `af2b0039d80bd9f2ccb15deb73fca0a24274838a`

