-- ============================================
-- Re-enable RLS on All Tables for Production
-- Migration: 20260110_reenable_rls.sql
--
-- This migration re-enables Row Level Security on all tables
-- to restore production security and functionality.
-- ============================================

ALTER TABLE "public"."admins" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."bills" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."clinics" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."clinics_sched" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversation_participants" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."dentist_availability" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."dentists" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."diseases" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."fcm_tokens" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."feedbacks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notification_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."patients" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."services" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."staffs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."supports" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."system_notifications" ENABLE ROW LEVEL SECURITY;