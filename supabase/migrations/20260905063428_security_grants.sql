-- ==============================================================================
-- SECURITY GRANTS & PERMISSIONS MIGRATION
-- Applies hard database-level restrictions and allowances
-- ==============================================================================

-- 1. Ensure Baseline Schema Access
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- 2. Grant CRUD allowances to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- 3. Grant Read-Only allowances to anonymous users (Public Storefront)
GRANT SELECT ON public.products TO anon;
GRANT SELECT ON public.product_variants TO anon;
GRANT SELECT ON public.categories TO anon;
GRANT SELECT ON public.product_images TO anon;
GRANT SELECT ON public.reviews TO anon;
GRANT SELECT ON public.vendors TO anon;

-- 4. HARD REVOKES (Defense in Depth)
-- Even if an RLS policy is misconfigured, these database-level revokes 
-- guarantee that users can NEVER delete sensitive financial or audit records.
REVOKE DELETE, TRUNCATE ON public.audit_logs FROM authenticated, anon;
REVOKE DELETE, TRUNCATE ON public.payments FROM authenticated, anon;
REVOKE DELETE, TRUNCATE ON public.orders FROM authenticated, anon;

-- 5. Service Role Override
-- The backend service role must have unrestricted access to bypass RLS for background jobs
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA public TO service_role;