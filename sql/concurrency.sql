-- ==============================================================================
-- SECTION 13: CONCURRENCY & LOCKS (concurrency.sql)
-- Requirement: Handle simultaneous purchases preventing double-selling. Explain 
-- locks, isolation, race conditions, deadlocks, and lock ordering[cite: 4].
-- ==============================================================================

/*
================================================================================
CONCURRENCY CONCEPT EXPLANATIONS[cite: 4]
================================================================================
1. Race Conditions: 
   Occur when two operations attempt to read and update the same data simultaneously.
   Without locks, Customer A and Customer B both read "Inventory = 1". Both subtract 
   1 in memory, and both update the database to "Inventory = 0". The system just 
   sold 2 items when only 1 existed.

2. Row-Level Locking (SELECT ... FOR UPDATE):
   The solution to race conditions. When Customer A reads the inventory row using 
   `FOR UPDATE`, PostgreSQL places an exclusive lock on that specific row. Customer B's 
   transaction physically pauses and waits in a queue until Customer A commits or rolls back.

3. Transaction Isolation:
   PostgreSQL defaults to "Read Committed". A transaction only sees data committed 
   before the transaction began. By using `FOR UPDATE`, we force the transaction to 
   re-read the most up-to-date committed value of the row right before applying updates, 
   ensuring strict consistency.

4. Deadlocks:
   Occur when Transaction A locks Row 1 and waits for Row 2, while Transaction B 
   locks Row 2 and waits for Row 1. Both wait forever. PostgreSQL detects this and 
   aborts one transaction.

5. Lock Ordering:
   The prevention for deadlocks. If an order contains multiple items, the system MUST 
   sort the item IDs before acquiring locks. If all transactions always lock Row 1 
   before Row 2, a deadlock is mathematically impossible.
================================================================================
*/

-- ==============================================================================
-- DEMONSTRATION: SIMULATED CONCURRENT SESSIONS
-- Requirement: Inventory = 1. Customer A buys 1. Customer B buys 1.
-- ==============================================================================

-- To actually test this, open TWO separate SQL Editor tabs in Supabase.

-- ------------------------------------------------------------------------------
-- SETUP (Run in Tab 1)
-- ------------------------------------------------------------------------------
-- Create a dummy product with exactly 1 inventory
/*
INSERT INTO public.inventory (variant_id, quantity) 
VALUES ('11111111-1111-1111-1111-111111111111', 1);
*/

-- ------------------------------------------------------------------------------
-- SESSION A: Customer A (Run in Tab 1)
-- ------------------------------------------------------------------------------
/*
BEGIN;

-- 1. Customer A acquires the lock. (Succeeds instantly)
SELECT quantity FROM public.inventory 
WHERE variant_id = '11111111-1111-1111-1111-111111111111' 
FOR UPDATE;

-- DO NOT COMMIT YET. Switch to Tab 2.
*/

-- ------------------------------------------------------------------------------
-- SESSION B: Customer B (Run in Tab 2)
-- ------------------------------------------------------------------------------
/*
BEGIN;

-- 1. Customer B attempts to acquire the lock.
-- THIS QUERY WILL HANG. The loading spinner will run infinitely because 
-- PostgreSQL is forcing Session B to wait for Session A to finish.
SELECT quantity FROM public.inventory 
WHERE variant_id = '11111111-1111-1111-1111-111111111111' 
FOR UPDATE;
*/

-- ------------------------------------------------------------------------------
-- RESOLUTION (Run in Tab 1)
-- ------------------------------------------------------------------------------
/*
-- Back in Tab 1, Customer A completes the purchase
UPDATE public.inventory 
SET quantity = quantity - 1 
WHERE variant_id = '11111111-1111-1111-1111-111111111111';

COMMIT;

-- THE MOMENT YOU HIT COMMIT IN TAB 1:
-- Tab 2 instantly un-hangs and completes its SELECT query. 
-- However, because of the strict lock, Tab 2 now sees `quantity = 0`.
-- Application logic in Session B will now see 0, throw an "Out of Stock" error,
-- and ROLLBACK, perfectly preventing the double-sale.
*/