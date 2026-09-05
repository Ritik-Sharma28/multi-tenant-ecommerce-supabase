# Row Level Security (RLS)

## 📌 RLS Overview

Row Level Security (RLS) is the linchpin of our multi-tenant architecture. While database grants dictate *which tables* a user can query, RLS policies mathematically filter *which rows* within those tables are returned or mutated based on the user's authenticated identity.

*   **Default Deny:** By enabling RLS on every application table (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`), PostgreSQL defaults to a "deny all" posture. If no policy explicitly allows access, the operation fails silently (returns 0 rows for SELECT) or throws an error (for INSERT/UPDATE/DELETE).
*   **Dynamic Resolution:** Policies utilize `auth.uid()` (provided by Supabase GoTrue) to establish the user's identity securely at execution time.

---

## 🎭 Role-Specific Access Policies

The system enforces strict data isolation based on three primary user personas:

### 1. Customers
Customers operate in a highly restricted, user-centric context.
*   **Profiles:** Can `SELECT` and `UPDATE` only where `id = auth.uid()`.
*   **Addresses:** Can perform full CRUD operations, but strictly limited to rows where `user_id = auth.uid()`.
*   **Carts & Cart Items:** Can access only their active cart.
*   **Orders & Payments:** Can `SELECT` historical orders where `user_id = auth.uid()`.
*   **Catalog (Products/Categories):** Granted universal `SELECT` access to items where `status = 'active'`.

### 2. Vendors (Multi-Tenant Isolation)
Vendor isolation prevents any cross-pollination of data between competing sellers. Access is dictated by the `vendor_members` junction table.

*   **Vendor Context:** A vendor employee can only access records associated with `vendor_id`s where they possess a valid `vendor_members` record linking them to that vendor.
*   **Products & Inventory:** `SELECT`, `UPDATE`, `INSERT` allowed only for products owned by their affiliated vendor.
*   **Orders:** Can `SELECT` and `UPDATE` (e.g., status changes) orders explicitly routed to their vendor ID.
*   **Never Trust the Client:** Policies **never** trust a `vendor_id` passed in the `WHERE` clause or JSON payload from the frontend. The database independently verifies membership using an `EXISTS` subquery against `vendor_members`.

### 3. Platform Admins
Admins require universal oversight for moderation and support.
*   **Access:** RLS policies explicitly grant access to all rows if the user's role in the `profiles` table is strictly set to `platform_admin`.

---

## ⚔️ RLS Attack Vectors & Testing

To ensure robust multi-tenancy, the architecture defends against the following simulated attack vectors:

*   **Tenant Hopping (Customer A → Customer B Data):** 
    *   *Attack:* User attempts to `GET /orders?user_id=eq.[CUSTOMER_B_ID]`.
    *   *Result:* Fails. RLS evaluates `user_id = auth.uid()` natively. Customer A receives 0 rows.
*   **Data Bleed (Vendor A → Vendor B Data):** 
    *   *Attack:* Vendor A attempts to `UPDATE inventory SET quantity=0 WHERE vendor_id=[VENDOR_B_ID]`.
    *   *Result:* Fails. The `EXISTS` subquery verifying Vendor A's membership in Vendor B fails, violating the `WITH CHECK` constraint of the UPDATE policy.
*   **Privilege Escalation (Vendor Employee → Admin Data):** 
    *   *Attack:* Vendor employee attempts to access the global `audit_logs` table.
    *   *Result:* Fails. No policy exists granting vendor employees read access to system-level logs.
*   **Unauthenticated Exploits (Anonymous → Private Data):** 
    *   *Attack:* Unauthenticated client attempts to query `profiles` or `carts`.
    *   *Result:* Fails. The `anon` role lacks policies to access these tables; returns empty data sets.

---

## 🧩 Complex Policy Example: Multi-Tenant Verification

To enforce vendor isolation on the `products` table, the following logic is utilized to ensure an employee can only modify their own products:

```sql
CREATE POLICY "Vendor employees can update their products" 
ON products
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM vendor_members 
        WHERE vendor_members.vendor_id = products.vendor_id 
        AND vendor_members.user_id = auth.uid()
    )
)
WITH CHECK (
    -- Ensures they cannot change the vendor_id of the product to a vendor they don't belong to
    EXISTS (
        SELECT 1 FROM vendor_members 
        WHERE vendor_members.vendor_id = products.vendor_id 
        AND vendor_members.user_id = auth.uid()
    )
);
```
