-- ============================================
-- COMPLETE RLS CLEANUP FOR DEVELOPMENT
-- Migration: 20260111_complete_rls_cleanup.sql
--
-- This migration fixes ALL RLS issues:
-- 1. Removes all conflicting storage policies
-- 2. Creates ONE simple permissive storage policy
-- 3. Disables RLS on all app tables
-- 4. Ensures login, messaging, and uploads all work
--
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================

-- ============================================
-- STEP 1: CLEAN UP ALL STORAGE POLICIES
-- This removes all 21+ conflicting policies
-- ============================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects;', r.policyname);
  END LOOP;
END $$;

-- ============================================
-- STEP 2: CREATE ONE SIMPLE STORAGE POLICY
-- This allows ALL operations for development
-- IMPORTANT: Uses both USING and WITH CHECK
-- ============================================
CREATE POLICY "dev_storage_allow_all"
ON storage.objects
FOR ALL
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 3: CLEAN UP ALL MESSAGE TABLE POLICIES
-- ============================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname
    FROM pg_policies
    WHERE tablename = 'messages'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON messages;', r.policyname);
  END LOOP;
END $$;

-- ============================================
-- STEP 4: CLEAN UP CONVERSATION POLICIES
-- ============================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname
    FROM pg_policies
    WHERE tablename = 'conversations'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON conversations;', r.policyname);
  END LOOP;
END $$;

-- ============================================
-- STEP 5: CLEAN UP CONVERSATION PARTICIPANTS POLICIES
-- ============================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN (
    SELECT policyname
    FROM pg_policies
    WHERE tablename = 'conversation_participants'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON conversation_participants;', r.policyname);
  END LOOP;
END $$;

-- ============================================
-- STEP 6: DISABLE RLS ON ALL APP TABLES
-- This ensures NO RLS blocking on ANY operation
-- ============================================
ALTER TABLE "public"."admins" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."bills" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."bookings" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."clinics" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."clinics_sched" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversation_participants" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversations" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."dentist_availability" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."dentists" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."diseases" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."fcm_tokens" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."feedbacks" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."messages" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_queue" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."patients" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."services" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."staffs" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."supports" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."system_notifications" DISABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 7: VERIFICATION QUERIES
-- Run these after the migration to confirm success
-- ============================================

-- Check storage policies (should show ONLY 1: dev_storage_allow_all)
-- SELECT policyname, cmd FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects';

-- Check message policies (should show 0)
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'messages';

-- Check RLS status on tables (should all show false)
-- SELECT relname, relrowsecurity FROM pg_class WHERE relname IN ('admins', 'messages', 'conversations', 'patients', 'dentists', 'staffs', 'clinics');

-- ============================================
-- DONE! Your app should now work:
-- ✅ Login works
-- ✅ Messages send
-- ✅ Image uploads work
-- ✅ All CRUD operations work
-- ============================================
