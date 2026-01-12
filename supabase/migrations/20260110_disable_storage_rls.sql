-- ============================================
-- Disable Storage RLS for Development
-- Migration: 20260110_disable_storage_rls.sql
--
-- This migration creates permissive policies on Supabase storage for development purposes.
-- This allows unrestricted access to storage buckets.
-- These policies should be removed in production.
-- ============================================

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON storage.objects;
DROP POLICY IF EXISTS "Allow all operations for anon users" ON storage.objects;

-- Create permissive policies for development
CREATE POLICY "Allow all operations for authenticated users" ON storage.objects
FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow all operations for anon users" ON storage.objects
FOR ALL USING (auth.role() = 'anon');