# Query Optimization

## 📌 Optimization Methodology

Query optimization ensures the database utilizes the most efficient execution path to retrieve data. The primary tool for diagnosing slow queries in PostgreSQL is `EXPLAIN ANALYZE`.

### The Workflow
1.  **Identify Bottleneck:** Run the slow query prefixed with `EXPLAIN ANALYZE`.
2.  **Analyze Output:** Locate expensive nodes (e.g., Sequential Scans, high execution times).
3.  **Optimize:** Apply indexes, rewrite CTEs, or adjust join logic.
4.  **Compare:** Re-run `EXPLAIN ANALYZE` and compare the *Execution Time* and *Actual Rows* read.

---

## 📊 Reading `EXPLAIN ANALYZE`

The output provides a node tree detailing how the Query Planner decided to execute the SQL.

### Scan Types (How data is read)
*   **Sequential Scan (`Seq Scan`):** The database reads every single row in the table. 
    *   *Diagnosis:* Acceptable for tiny tables (e.g., a table with 10 statuses), but highly detrimental for large tables like `orders` or `audit_logs`. Indicates a missing index.
*   **Index Scan (`Index Scan`):** The database traverses a B-Tree index to find the exact location of the data, then fetches the row from the disk. Highly efficient.
*   **Index Only Scan:** The database finds all required data directly within the index itself without even touching the main table disk. The ultimate optimization.
*   **Bitmap Scan:** Used when an index matches many rows. The database builds a bitmap of pages in memory, sorts them, and then fetches the blocks sequentially. More efficient than a pure Index Scan when returning a large percentage of a table.

### Join Strategies (How tables are linked)
*   **Nested Loop:** For every row in Table A, loop through Table B to find matches. Extremely fast if Table A has very few rows (e.g., 1 user) and Table B is indexed. Terrible for large datasets.
*   **Hash Join:** Reads Table A, builds a hash table in memory, then scans Table B probing the hash table for matches. Efficient for joining large, unsorted datasets.
*   **Merge Join:** Both tables are sorted (often via indexes) and zipped together. Highly efficient for massive joins, provided the data is already ordered.

---

## 📈 Key Metrics to Monitor

When comparing "Before" and "After" optimization states, focus on:

1.  **Estimated Rows vs. Actual Rows:** 
    *   *Concept:* The Query Planner uses statistics to guess how many rows a step will produce (`rows=1000`). `EXPLAIN ANALYZE` shows the reality (`actual rows=5`).
    *   *Diagnosis:* If there is a massive discrepancy between the estimate and reality, the planner makes bad decisions (e.g., choosing a Hash Join instead of a Nested Loop). Running `ANALYZE table_name;` updates the statistics and often fixes the issue.
2.  **Execution Time:** The total time taken in milliseconds. Does not include network latency to the client.

### Example Optimization Scenario
*   *Before:* `SELECT * FROM orders WHERE vendor_id = 'XYZ' AND created_at > '2026-01-01'` results in a **Sequential Scan** taking 450ms.
*   *Fix:* Implement a composite index: `CREATE INDEX idx_orders_vendor_date ON orders(vendor_id, created_at);`
*   *After:* Re-running the query results in an **Index Scan** taking 3ms.
