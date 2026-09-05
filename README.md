# Production-Grade Multi-Tenant E-Commerce Platform

A robust, highly scalable backend architecture for a multi-vendor e-commerce platform, built exclusively on **PostgreSQL** and the **Supabase** ecosystem. 

This project demonstrates an advanced "Thick Database" architecture, pushing critical business logic, multi-tenant isolation, and strict access controls down to the lowest possible data layer to guarantee maximum security, performance, and data integrity.

---

## 🌟 Key Features

*   **Strict Multi-Tenancy:** Guaranteed data isolation between vendors using PostgreSQL Row Level Security (RLS). Vendor A can never access Vendor B's catalog or orders.
*   **Atomic Checkout Transactions:** A 14-step ACID-compliant checkout flow built entirely in `plpgsql`. It handles inventory locking, subtotal calculations, and coupon application, rolling back completely if any single step fails.
*   **Concurrency Control:** Native pessimistic row-level locking (`SELECT ... FOR UPDATE`) prevents race conditions and double-spending during high-traffic inventory updates.
*   **Granular RBAC:** Dynamic Role-Based Access Control enforcing permissions across Customers, Vendor Employees, Vendor Managers, and Platform Admins.
*   **JSONB Flexibility:** Specialized GIN indexing on unstructured JSONB variant attributes enables lightning-fast, highly flexible product catalogs without EAV schema bloat.
*   **Defense in Depth:** Security is layered from IP allowlisting at the network edge to `SECURITY DEFINER` constraints on backend RPC execution.

---

## 🛠️ Technology Stack

*   **Database:** PostgreSQL 15+
*   **Backend as a Service:** Supabase
*   **Authentication:** Supabase Auth (GoTrue) / JWTs
*   **Storage:** Supabase Storage (S3-compatible)
*   **Background Jobs:** `pg_cron`
*   **Event Hooks:** Supabase Webhooks / `pg_net`

---

## 📁 Repository Structure

```text
├── supabase/
│   ├── migrations/      # Sequential SQL files to build the database state
│   ├── seed.sql         # Seed data containing vendors, products, and users
│   └── tests/           # Database testing scripts
│
├── sql/                 # Standalone SQL scripts grouped by topic
│   ├── crud.sql
│   ├── joins.sql
│   ├── subqueries.sql
│   ├── cte.sql
│   ├── window_functions.sql
│   ├── transactions.sql
│   ├── concurrency.sql
│   ├── jsonb.sql
│   └── optimization.sql
│
├── sql_challenges/      # Complex analytical query implementations
│
└── docs/                # Comprehensive architectural documentation
    ├── architecture.md
    ├── database-design.md
    ├── security.md
    ├── rls.md
    ├── networking.md
    ├── transactions.md
    ├── concurrency.md
    ├── indexing.md
    ├── optimization.md
    └── backup-recovery.md
```

---

## 📚 Documentation

Detailed documentation explaining the architectural and security decisions made during the implementation of this system can be found in the `docs/` directory:

1.  [Architecture Overview](docs/architecture.md)
2.  [Database Design & ERD](docs/database-design.md)
3.  [Security & Threat Modeling](docs/security.md)
4.  [Row Level Security (RLS)](docs/rls.md)
5.  [Network Security & Rate Limiting](docs/networking.md)
6.  [Transactions & Checkout Flow](docs/transactions.md)
7.  [Concurrency & Race Conditions](docs/concurrency.md)
8.  [Indexing Strategy](docs/indexing.md)
9.  [Query Optimization](docs/optimization.md)
10. [Backup & Recovery](docs/backup-recovery.md)

---

## 🚀 Setup & Deployment

Because the entire architecture is defined via SQL migrations, the environment is highly reproducible.

1.  **Initialize Supabase:**
    ```bash
    supabase start
    ```
2.  **Apply Migrations:**
    The local Supabase instance will automatically run all files in `supabase/migrations/` in sequential order to build the schema, roles, policies, and triggers.
3.  **Seed Data:**
    The `supabase/seed.sql` file will populate the database with a realistic dataset (vendors, customers, products, and inventory) for immediate testing.
