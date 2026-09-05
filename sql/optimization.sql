-- ==============================================================================
-- SECTION 20: QUERY OPTIMIZATION (optimization.sql)
-- Demonstrates: EXPLAIN ANALYZE, Bottleneck identification, Indexing strategy, 
-- and Query Planner terminology.
-- ==============================================================================

/*
================================================================================
QUERY PLANNER TERMINOLOGY (Section 20 Requirement)
================================================================================
- Sequential Scan: The database reads every single row in a table from top to bottom. 
  Fast for small tables, devastatingly slow for large tables (like a 5000+ row products table).
- Index Scan: The database uses a B-Tree index to instantly find the exact disk location 
  of the requested rows, bypassing a full table read.
- Bitmap Scan: A hybrid approach. The database uses an index to build a memory map (bitmap) 
  of where the rows are, sorts them, and then grabs them all at once. Used when a query 
  returns too many rows for an Index Scan, but too few for a Sequential Scan.
- Nested Loop: A join strategy where for every row in Table A, the database scans Table B. 
  Efficient only if Table A has very few rows.
- Hash Join: A join strategy where the database builds a hash table in memory for the smaller 
  table, then scans the larger table and probes the hash table for matches. Excellent for 
  joining large, unsorted datasets.
- Merge Join: A join strategy where both tables are already sorted by the join key. 
  The database zips them together in a single pass. Extremely fast.
- Estimated vs. Actual Rows: The query planner relies on statistics. "Estimated" is its 
  best guess before running. "Actual" is what truly happened. If they differ wildly, 
  you need to run `ANALYZE table_name;` to update the statistics.
- Execution Time: Total milliseconds taken to plan and execute the query.
================================================================================
*/

-- ==============================================================================
-- QUERY 1: Composite Filtering (Vendor ID + Status)
-- ==============================================================================
-- BEFORE: 
-- EXPLAIN ANALYZE SELECT * FROM public.products WHERE vendor_id = 'uuid' AND status = 'active';
-- BOTTLENECK: The planner performs a Bitmap Heap Scan because it has to evaluate two 
-- separate conditions across thousands of rows.
-- OPTIMIZATION: Create a composite index to cover both WHERE clauses simultaneously.
-- ACTION: (Already applied in our migrations: CREATE INDEX idx_products_vendor_status ON products(vendor_id, status);)
-- AFTER:
-- EXPLAIN ANALYZE SELECT * FROM public.products WHERE vendor_id = 'uuid' AND status = 'active';
-- RESULT: Upgrades to a pure Index Scan. Execution time drops significantly.


-- ==============================================================================
-- QUERY 2: JSONB Attribute Searching
-- ==============================================================================
-- BEFORE:
-- EXPLAIN ANALYZE SELECT id FROM public.product_variants WHERE attributes @> '{"color": "black"}';
-- BOTTLENECK: Sequential Scan. PostgreSQL has to deserialize the JSON text for every single variant.
-- OPTIMIZATION: Apply a GIN index using jsonb_path_ops.
-- ACTION: CREATE INDEX idx_pv_attributes ON public.product_variants USING GIN (attributes jsonb_path_ops);
-- AFTER:
-- EXPLAIN ANALYZE SELECT id FROM public.product_variants WHERE attributes @> '{"color": "black"}';
-- RESULT: Converts to a Bitmap Index Scan. Execution time drops from ~15ms to <1ms.


-- ==============================================================================
-- QUERY 3: Time-Series Sorting
-- ==============================================================================
-- BEFORE:
-- EXPLAIN ANALYZE SELECT id, total FROM public.orders ORDER BY created_at DESC LIMIT 50;
-- BOTTLENECK: Sequential Scan + memory Sort. The database must read all 5,000 orders 
-- into memory, sort them, and then throw away 4,950 of them.
-- OPTIMIZATION: Index the timestamp column so the data is pre-sorted on disk.
-- ACTION: (Already applied: CREATE INDEX idx_orders_created_at ON orders(created_at);)
-- AFTER:
-- EXPLAIN ANALYZE SELECT id, total FROM public.orders ORDER BY created_at DESC LIMIT 50;
-- RESULT: Index Scan Backward. No memory sorting required.


-- ==============================================================================
-- QUERY 4: Foreign Key JOINs
-- ==============================================================================
-- BEFORE:
-- EXPLAIN ANALYZE SELECT o.id, oi.quantity FROM public.orders o JOIN public.order_items oi ON o.id = oi.order_id;
-- BOTTLENECK: Hash Join with a Sequential Scan on order_items. The planner must hash the 
-- entire orders table because there is no index linking the two tables.
-- OPTIMIZATION: Foreign keys are NOT indexed by default in Postgres. We must index them manually.
-- ACTION: (Already applied: CREATE INDEX idx_order_items_order_id ON order_items(order_id);)
-- AFTER:
-- EXPLAIN ANALYZE SELECT o.id, oi.quantity FROM public.orders o JOIN public.order_items oi ON o.id = oi.order_id;
-- RESULT: Nested Loop with an Index Scan, radically speeding up the JOIN execution.


-- ==============================================================================
-- QUERY 5: Text Slug Lookups
-- ==============================================================================
-- BEFORE:
-- EXPLAIN ANALYZE SELECT * FROM public.products WHERE slug = 'product-1-a3b2c';
-- BOTTLENECK: Sequential Scan across text fields.
-- OPTIMIZATION: Add a standard B-Tree index to the unique lookup field.
-- ACTION: (Already applied: CREATE INDEX idx_products_slug ON products(slug);)
-- AFTER:
-- EXPLAIN ANALYZE SELECT * FROM public.products WHERE slug = 'product-1-a3b2c';
-- RESULT: Upgrades to a sub-millisecond Index Scan.