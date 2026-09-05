-- ==============================================================================
-- SECTION 25: POSTGRESQL ROLES & GRANTS (roles_and_grants.sql)
-- Demonstrates: GRANT, REVOKE, and conceptual explanations of Supabase roles.
-- ==============================================================================

/*
================================================================================
EXPLANATION: SUPABASE DEFAULT ROLES
================================================================================
Supabase leverages PostgreSQL's native role-based access control (RBAC) to 
manage API access securely.

1. anon:
   - The role assumed when an API request lacks a valid JWT (not logged in).
   - Should have highly restricted read-only permissions.
   
2. authenticated:
   - The role assumed when an API request provides a valid Supabase Auth JWT.
   - Has baseline table access to perform CRUD, but is physically constrained 
     by Row Level Security (RLS) policies so users only see their own data.
     
3. service_role:
   - A highly privileged backend role that BBYPASSES RLS COMPLETELY.
   - Used exclusively in secure server environments (e.g., Edge Functions, cron jobs).
   - Must NEVER be exposed to the frontend or browser.

================================================================================
EXPLANATION: DATABASE PERMISSIONS vs. RLS POLICIES
================================================================================
- Database Permissions (GRANT/REVOKE): These are "Table-Level" rules. 
  They act as the outer gate. They dictate whether a role is fundamentally 
  allowed to perform an action (like SELECT or UPDATE) on a specific table. 
  If `authenticated` does not have SELECT permission on `public.orders`, the 
  request is rejected instantly.

- Row Level Security (RLS): These are "Row-Level" rules.
  Once the GRANT allows a user into the table, RLS acts as the inner filter. 
  It determines exactly WHICH rows they are allowed to interact with. 
  (e.g., "You are GRANTED permission to SELECT from orders, but your RLS 
  policy says you can ONLY see rows where user_id = auth.uid()").
*/

-- ==============================================================================
-- DEMONSTRATION: GRANT
-- ==============================================================================

-- 1. Schema Access
-- Roles must explicitly be granted usage on a schema before they can access its tables.
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- 2. Basic API Allowances
-- Allow authenticated users to perform standard CRUD operations on the carts table.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.carts TO authenticated;

-- Allow anonymous users to ONLY read the product catalog.
GRANT SELECT ON public.products TO anon;

-- 3. Sequence Allowances
-- If a table uses auto-incrementing integers (SERIAL) instead of UUIDs, 
-- the user needs permission to increment the sequence to insert a new row.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;


-- ==============================================================================
-- DEMONSTRATION: REVOKE
-- ==============================================================================

-- 1. Revoking Public Access
-- Business requirement change: Unauthenticated users are no longer allowed to 
-- see the vendor list. We revoke their table-level SELECT privilege entirely.
REVOKE SELECT ON public.vendors FROM anon;

-- 2. Defense in Depth (Hard Database Constraints)
-- Prevent authenticated users from ever deleting audit logs.
-- Even if an RLS policy was accidentally written to allow deletes, this REVOKE 
-- acts as a hard database-level barrier that makes the action impossible.
REVOKE DELETE, TRUNCATE ON public.audit_logs FROM authenticated;
REVOKE DELETE, TRUNCATE ON public.payments FROM authenticated;


-- ==============================================================================
-- DEMONSTRATION: ADMIN ALLOWANCES
-- ==============================================================================

-- Ensure the service_role has total, unrestricted control over the public schema
-- so backend webhook functions and scheduled jobs can execute without errors.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA public TO service_role;