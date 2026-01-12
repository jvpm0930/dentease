-- ============================================
-- Re-disable RLS on Messaging Tables
-- Migration: 20260110_redisable_messaging_rls.sql
--
-- This migration ensures RLS is disabled on messaging-related tables
-- in case they were re-enabled manually.
-- ============================================

ALTER TABLE "public"."messages" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversations" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversation_participants" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."system_notifications" DISABLE ROW LEVEL SECURITY;