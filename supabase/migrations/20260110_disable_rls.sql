-- ============================================
-- Disable Row Level Security for Development
-- Migration: 20260110_disable_rls.sql
--
-- This migration disables RLS on all tables for development purposes.
-- RLS should be re-enabled in production.
-- ============================================

-- Disable RLS on all tables
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