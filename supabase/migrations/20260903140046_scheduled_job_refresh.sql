-- ==============================================================================
-- SCHEDULED JOBS (Sections 18 & 37)
-- Automatically refresh the materialized view every night at 2:00 AM
-- ==============================================================================

-- 1. Enable the pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Schedule the background task
-- The time format '0 2 * * *' is standard CRON syntax meaning "2:00 AM every day"
SELECT cron.schedule(
    'refresh-vendor-sales-nightly',            -- Unique name for the job
    '0 2 * * *',                               -- When to run it
    $$ REFRESH MATERIALIZED VIEW CONCURRENTLY public.monthly_vendor_sales; $$  -- The command to run
);