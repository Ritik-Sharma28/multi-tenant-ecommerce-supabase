# Indexing Strategy

## 📌 Indexing Overview

To ensure the platform remains highly performant as tenant data grows into the millions of rows, a comprehensive indexing strategy is implemented. Without indexes, PostgreSQL relies on slow **Sequential Scans** (reading every row in a table to find a match), which degrades performance linearly as data grows.

---

## 🗂️ Core Index Types

### 1. Foreign Key Indexes
By default, PostgreSQL does *not* automatically index foreign keys. However, foreign keys are heavily utilized in `JOIN` operations and cascading deletes.
*   *Implementation:* B-Tree indexes are explicitly created on all foreign keys (e.g., `vendor_id`, `category_id`, `user_id`, `product_id`).
*   *Benefit:* Speeds up relational lookups (e.g., "Find all products for Vendor A") and prevents full table locks during `DELETE` operations on parent tables.

### 2. High-Selectivity Columns
Columns frequently used in `WHERE` clauses for exact matching or filtering.
*   **SKU (`product_variants.sku`):** `UNIQUE` index. Fast lookups for inventory syncs.
*   **Slugs (`products.slug`, `categories.slug`):** `UNIQUE` index. Optimizes frontend URL routing (e.g., `/product/iphone-15`).
*   **Order Status (`orders.status`):** Indexed to optimize dashboards (e.g., "Show all 'pending' orders").
*   **Coupon Code (`coupons.code`):** `UNIQUE` index. Instant validation during checkout.

### 3. Range & Sorting Queries
Columns frequently used for date-based filtering and `ORDER BY` operations.
*   **Created Timestamp (`created_at`):** Indexed on high-volume tables (`orders`, `audit_logs`) to rapidly filter by date ranges (e.g., "Orders in the last 30 days") and sort chronological feeds.

---

## 🔗 Composite Indexes

Composite indexes cover multiple columns simultaneously. They are crucial for queries that frequently filter on specific combinations of data.

*   *Implementation Example:* `CREATE INDEX idx_products_vendor_category ON products (vendor_id, category_id);`
*   *Why it's important:* When a user views a specific category on a specific vendor's storefront (e.g., "Show 'Electronics' from 'Vendor A'"), the database can satisfy both `WHERE` conditions simultaneously from a single index, rather than finding all Vendor A products and then sequentially filtering for Electronics.
*   *Rule of Thumb:* Column order matters. The most selective column (the one that filters out the most rows) is placed first.

---

## 📄 JSONB Indexing

PostgreSQL provides specialized indexes for `JSONB` data, which are vital for our flexible `product_variants.attributes` design.

### GIN (Generalized Inverted Index)
*   *Implementation:* `CREATE INDEX idx_variant_attributes ON product_variants USING GIN (attributes);`
*   *Benefit:* GIN indexes map every key and value within the JSON payload. This allows for lightning-fast queries across arbitrary attributes without knowing the schema in advance.
*   *Example Query:* Finding all products where color is 'black'.
    ```sql
    SELECT * FROM product_variants WHERE attributes @> '{"color": "black"}';
    ```
    Without a GIN index, the database would have to parse the JSON for every row sequentially. With GIN, it functions like a search engine index, instantly returning the matching rows.
