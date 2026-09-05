# Backup & Recovery Architecture

## 📌 Disaster Recovery Strategy

While the platform is built on managed infrastructure (Supabase), a robust, documented backup and recovery strategy is required to protect against catastrophic failures, malicious data deletion, or faulty application migrations.

---

## 💾 Database Backups

Supabase handles automated backups, but understanding the mechanisms and augmenting them is critical for production readiness.

### 1. Automated Physical Backups (Daily)
*   **Mechanism:** Supabase automatically takes daily physical snapshots of the entire PostgreSQL cluster.
*   **Use Case:** Severe catastrophic failure of the primary database node.
*   **RPO (Recovery Point Objective):** Up to 24 hours of data loss.

### 2. Point-in-Time Recovery (PITR)
*   **Mechanism:** For production tiers, Supabase continuously archives Write-Ahead Logs (WAL).
*   **Use Case:** "Oops" moments. If an admin accidentally drops a critical table or runs an `UPDATE` without a `WHERE` clause at 2:05 PM, the database can be precisely restored to its exact state at 2:04 PM.
*   **RPO:** Minimal (seconds/minutes), drastically reducing data loss compared to daily snapshots.

### 3. Logical Backups (Offsite/Cold Storage)
*   **Mechanism:** Using `pg_dump` via scheduled external scripts (e.g., GitHub Actions) to generate standard `.sql` files.
*   **Use Case:** Vendor lock-in mitigation and absolute disaster recovery if the primary cloud provider suffers a total ecosystem outage. These backups are encrypted and pushed to an external storage bucket (e.g., AWS S3).

---

## 📦 Storage Backup Considerations

Database backups do **not** include files hosted in Supabase Storage (e.g., product images).

*   **Strategy:** Storage buckets must be synced independently. A scheduled chron job utilizing the Supabase Storage API or an S3-compatible client will mirror the `product-images` bucket to a secondary, offsite cloud provider.
*   **Soft Deletes:** Storage policies should ideally prevent hard deletes of assets, or utilize a "trash" bucket configuration to prevent accidental data loss.

---

## 🔄 Migration Rollback Strategy

Database migrations modify schema (creating tables, altering columns). A failed migration can break the application.

*   **Idempotency:** All migration scripts must be idempotent (e.g., `CREATE TABLE IF NOT EXISTS`, `DROP INDEX IF EXISTS`) so they can be re-run safely.
*   **Rollback Scripts:** Every `.sql` migration file should have a corresponding "down" migration documented or prepared. 
    *   *Example:* If `005_products_add_column.sql` runs `ALTER TABLE products ADD COLUMN weight INT;`, the rollback procedure is `ALTER TABLE products DROP COLUMN weight;`.
*   **Zero-Downtime:** Destructive changes (like dropping a column) are avoided. Instead, columns are deprecated, data is migrated to the new schema slowly, and the old column is removed only in a subsequent, verified release.

---

## 🏥 Recovery Testing

A backup is only as good as its last successful restoration.

*   **Staging Clones:** Before major production releases, the staging environment is wiped and restored using the latest production backup to verify the integrity of the backup files and the restoration procedure.
*   **Drill Documentation:** Runbooks detailing the exact CLI commands or dashboard clicks required to initiate a PITR or a full pg_dump restore must be maintained and practiced quarterly by the engineering team.
