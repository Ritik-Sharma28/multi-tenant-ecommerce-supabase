# Concurrency & Race Conditions

## 📌 Concurrency Challenge

In high-traffic e-commerce environments (e.g., flash sales, Black Friday), multiple customers may attempt to purchase the same limited-stock item simultaneously. 

If the database is not configured to handle concurrency, **Race Conditions** occur. 

### The Race Condition Scenario
*   **Initial State:** Inventory = 1
*   **Time 1:** Customer A queries stock (Reads 1).
*   **Time 2:** Customer B queries stock (Reads 1).
*   **Time 3:** Customer A buys 1. System calculates `1 - 1 = 0`. Writes 0 to DB.
*   **Time 4:** Customer B buys 1. System calculates `1 - 1 = 0`. Writes 0 to DB.

**Disastrous Result:** The system sold the same single item twice. 

---

## 🔒 Concurrency Controls: Row-Level Locking

To prevent race conditions, the platform utilizes PostgreSQL's native pessimistic concurrency controls, specifically **Row-Level Locking**.

During the `create_order()` RPC transaction, before the system calculates stock or applies changes, it issues a specific command:

```sql
SELECT quantity 
FROM inventory 
WHERE variant_id = 'XYZ' 
FOR UPDATE;
```

### How `FOR UPDATE` Solves the Race Condition

1.  **Customer A** executes the transaction. The database reaches the `SELECT ... FOR UPDATE` statement.
2.  PostgreSQL places an exclusive **row-level lock** on the specific inventory row for variant 'XYZ'.
3.  **Customer B** executes their transaction milliseconds later. The database reaches the `SELECT ... FOR UPDATE` statement for the same variant.
4.  Because Customer A holds the lock, **Customer B's transaction halts and waits**. It is physically blocked from reading or writing that row.
5.  Customer A's transaction completes, updating the inventory from 1 to 0, and releases the lock.
6.  Customer B's transaction resumes, acquires the lock, and reads the *freshly updated* stock level (0).
7.  Customer B's validation logic sees stock is 0, and cleanly aborts their transaction.

**Result:** No double-spending. No negative inventory.

---

## ⚙️ Transaction Isolation Levels

PostgreSQL defaults to the `Read Committed` isolation level. 

*   **Read Committed (Default):** A transaction only sees data committed before the query began. It will *never* see uncommitted "dirty" data from other pending transactions.
*   **In combination with `FOR UPDATE`:** This default level is perfectly sufficient for the checkout flow. When Customer B's transaction wakes up after waiting for Customer A's lock, the `Read Committed` rule forces it to re-evaluate the row, ensuring it sees the new '0' inventory value.

---

## ☠️ Deadlocks & Lock Ordering

While row-level locks solve race conditions, they introduce a new risk: **Deadlocks**.

### The Deadlock Scenario
*   Customer A buys Product 1, then Product 2. (Locks Row 1, wants to Lock Row 2).
*   Customer B buys Product 2, then Product 1. (Locks Row 2, wants to Lock Row 1).
*   Both transactions freeze indefinitely, waiting for the other to release the lock. PostgreSQL will eventually kill one transaction to break the stalemate.

### Deadlock Prevention Strategy
To prevent deadlocks from occurring during checkout, the `create_order()` RPC enforces strict **Lock Ordering**.

Before executing the `SELECT ... FOR UPDATE`, the application sorts the requested `variant_id`s in a consistent, deterministic order (e.g., alphabetically or numerically by UUID). 

*   Customer A wants Product 1 and Product 2. Sorted: `[1, 2]`.
*   Customer B wants Product 2 and Product 1. Sorted: `[1, 2]`.

Because all transactions always attempt to acquire locks in the exact same sequence, deadlocks are mathematically impossible. Customer B will simply wait for Customer A to finish locking and updating both rows.
