-- ============================================
-- FCM Push Notifications - CRON Setup
-- Run this AFTER deploying the edge functions
-- 
-- This sets up pg_cron to automatically process
-- pending FCM notifications every minute
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Grant usage to postgres role
GRANT USAGE ON SCHEMA cron TO postgres;

-- ============================================
-- SCHEDULE: FCM Processor (every minute)
-- ============================================

-- First, unschedule if exists (to avoid duplicates)
SELECT cron.unschedule('fcm-processor') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'fcm-processor'
);

-- Schedule the FCM processor to run every minute
-- Replace YOUR_PROJECT_REF and YOUR_SERVICE_ROLE_KEY with actual values
SELECT cron.schedule(
    'fcm-processor',              -- Job name
    '* * * * *',                  -- Every minute
    $$
    SELECT net.http_post(
        url := 'https://qotjgevjzmnqvmgaarod.supabase.co/functions/v1/fcm_processor',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFvdGpnZXZqem1ucXZtZ2Fhcm9kIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczODIyNDUxMiwiZXhwIjoyMDUzODAwNTEyfQ.j8h5GEdTrpcLdtulCQJVrpQVSa9zWVGbwdudNb9Cyms',
            'Content-Type', 'application/json'
        ),
        body := '{"batch_size": 50}'::jsonb
    ) AS request_id;
    $$
);

-- ============================================
-- VERIFY: Check scheduled jobs
-- ============================================

-- View all scheduled cron jobs
SELECT jobid, schedule, command, active 
FROM cron.job 
WHERE jobname = 'fcm-processor';

-- ============================================
-- OPTIONAL: View job run history
-- ============================================

-- Check recent job runs (useful for debugging)
-- SELECT * FROM cron.job_run_details 
-- ORDER BY start_time DESC 
-- LIMIT 20;

-- ============================================
-- CLEANUP (if needed)
-- ============================================

-- To disable the cron job:
-- UPDATE cron.job SET active = false WHERE jobname = 'fcm-processor';

-- To completely remove the cron job:
-- SELECT cron.unschedule('fcm-processor');

-- ============================================
-- NOTES
-- ============================================
-- 
-- 1. Replace YOUR_PROJECT_REF with your actual Supabase project reference
--    (found in Project Settings → General)
-- 
-- 2. Replace YOUR_SERVICE_ROLE_KEY with your service role key
--    (found in Project Settings → API → service_role secret)
--
-- 3. The cron job runs every minute, which means:
--    - Max latency of ~1 minute for push notifications
--    - Processes up to 50 notifications per run
--
-- 4. For higher throughput, you can:
--    - Increase batch_size (max recommended: 100)
--    - Run more frequently (e.g., every 30 seconds using pg_cron v1.5+)
--
-- 5. Monitor the system_notifications table:
--    - push_status = 'pending' → waiting to be processed
--    - push_status = 'sent' → successfully sent via FCM
--    - push_status = 'skipped' → user has no FCM token
--    - push_status = 'failed' → FCM send failed
--
