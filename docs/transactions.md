# Transactions & The Checkout Flow

## 📌 Transactions Overview

In a multi-tenant e-commerce system, financial operations such as checkout cannot be executed as a series of isolated API calls. If the network drops halfway through, the system could charge a customer without reserving inventory, or reserve inventory without creating an order.

To guarantee system integrity, the entire checkout process is wrapped in a **Strict Atomic Transaction** using a PostgreSQL RPC (Remote Procedure Call). 

---

## ⚛️ The Atomic Order Creation Process

The `create_order()` function executes entirely within the database. It enforces the ACID properties (Atomicity, Consistency, Isolation, Durability). 

If **any** single step fails (e.g., inventory runs out, or a coupon is invalid), the database triggers a `ROLLBACK`. No partial data is saved, leaving the database in its exact state prior to the transaction attempt.

### 🔄 The 14-Step Transaction Flow

1.  **Validate Customer:** Ensure the `auth.uid()` corresponds to a valid, active profile and that the requested shipping address belongs to them.
2.  **Validate Product:** Verify that the requested product IDs exist, belong to the correct vendor, and have an `active` status.
3.  **Validate Inventory:** Check if the requested quantities exist in the `inventory` table.
4.  **Lock Inventory:** Execute `SELECT ... FOR UPDATE` on the specific inventory rows. This applies a row-level lock, blocking any other concurrent checkout processes from modifying this exact variant's stock until the current transaction completes.
5.  **Reserve Inventory:** Update the `reserved_quantity` to temporarily hold the items while calculating financials.
6.  **Calculate Subtotal:** Dynamically sum the `base_price` of all requested variants.
7.  **Validate Coupon:** If a coupon code is provided, verify it exists, belongs to the correct vendor, is active, hasn't expired, hasn't exceeded its `usage_limit`, and that the cart meets the `minimum_order_amount`.
8.  **Calculate Discount:** Apply the coupon mathematics (percentage or flat reduction) to the subtotal.
9.  **Calculate Tax:** Apply localized tax rates to the post-discount subtotal.
10. **Calculate Shipping:** Apply shipping fees based on vendor rules or flat rates.
11. **Create Order:** `INSERT` the master record into the `orders` table, generating the final total and capturing the `shipping_address_id`.
12. **Create Order Items:** `INSERT` individual records into `order_items`. *Crucial:* The current product price is hardcopied into the `unit_price` column to permanently record what the user paid, protecting historical data from future price changes.
13. **Create Payment:** Generate a `payments` record linked to the order in a 'pending' state, awaiting external gateway confirmation.
14. **Commit:** The transaction completes successfully. Locks are released, and the changes become visible to the rest of the database.

---

## 🚫 Failure Handling & Testing

The transaction architecture is designed to fail safely.

### Simulated Failure Scenarios
*   **Negative Inventory Validation:** If a customer attempts to buy 5 items, but only 3 remain, Step 3 triggers an exception. The transaction aborts immediately. **Verification:** No partial order is created; inventory remains untouched.
*   **Duplicate Coupon Validation:** If two users attempt to use the last remaining redemption of a coupon simultaneously, the first transaction acquires the lock and increments the usage. The second transaction, waiting on the lock, reads the updated usage count, sees the limit is reached, and aborts. **Verification:** The coupon is only used once; the second order fails cleanly.
*   **Payment Failure Mid-Stream:** If an artificial failure is forced at Step 13 (e.g., simulating a database constraint error), the transaction rolls back. **Verification:** The reserved inventory is released; no ghost orders remain in the system.
