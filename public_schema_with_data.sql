

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."add_dentist_availability"("p_dentist_id" "uuid", "p_date" "date", "p_start_time" time without time zone, "p_end_time" time without time zone, "p_break_start_time" time without time zone DEFAULT NULL::time without time zone, "p_break_end_time" time without time zone DEFAULT NULL::time without time zone, "p_max_appointments" integer DEFAULT 10, "p_notes" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_clinic_id UUID;
    v_availability_id UUID;
BEGIN
    -- Get clinic_id for the dentist
    SELECT clinic_id INTO v_clinic_id
    FROM dentists 
    WHERE dentist_id = p_dentist_id;
    
    IF v_clinic_id IS NULL THEN
        RAISE EXCEPTION 'Dentist not found or not associated with clinic';
    END IF;
    
    -- Insert availability
    INSERT INTO dentist_availability (
        dentist_id, clinic_id, date, start_time, end_time,
        break_start_time, break_end_time, max_appointments, notes
    ) VALUES (
        p_dentist_id, v_clinic_id, p_date, p_start_time, p_end_time,
        p_break_start_time, p_break_end_time, p_max_appointments, p_notes
    ) RETURNING availability_id INTO v_availability_id;
    
    RETURN v_availability_id;
END;
$$;


ALTER FUNCTION "public"."add_dentist_availability"("p_dentist_id" "uuid", "p_date" "date", "p_start_time" time without time zone, "p_end_time" time without time zone, "p_break_start_time" time without time zone, "p_break_end_time" time without time zone, "p_max_appointments" integer, "p_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."approve_appointment"("p_booking_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE bookings
    SET status = 'approved', updated_at = NOW()
    WHERE booking_id = p_booking_id;

    IF FOUND THEN
        v_result := jsonb_build_object('success', true, 'message', 'Appointment approved');
    ELSE
        v_result := jsonb_build_object('success', false, 'error', 'Booking not found');
    END IF;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."approve_appointment"("p_booking_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_email_exists"("email_to_check" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    email_exists BOOLEAN := FALSE;
BEGIN
    -- Check if email exists in patients table
    SELECT EXISTS(
        SELECT 1 FROM patients WHERE email = email_to_check
    ) INTO email_exists;
    
    RETURN email_exists;
END;
$$;


ALTER FUNCTION "public"."check_email_exists"("email_to_check" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_appointment"("p_booking_id" "uuid", "p_completion_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE bookings
    SET 
        status = 'completed',
        completed_at = NOW(),
        completion_notes = p_completion_notes,
        updated_at = NOW()
    WHERE booking_id = p_booking_id;

    IF FOUND THEN
        v_result := jsonb_build_object('success', true, 'message', 'Appointment completed');
    ELSE
        v_result := jsonb_build_object('success', false, 'error', 'Booking not found');
    END IF;

    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."complete_appointment"("p_booking_id" "uuid", "p_completion_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_direct_conversation"("p_user1_id" "uuid", "p_user1_role" "text", "p_user1_name" "text", "p_user2_id" "uuid", "p_user2_role" "text", "p_user2_name" "text", "p_clinic_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_conversation_id UUID;
    v_existing_id UUID;
BEGIN
    -- Check if conversation exists
    SELECT c.conversation_id INTO v_existing_id
    FROM conversations c
    WHERE c.type = 'direct'
    AND EXISTS (
        SELECT 1 FROM conversation_participants cp1 
        WHERE cp1.conversation_id = c.conversation_id 
        AND cp1.user_id = p_user1_id
        AND cp1.is_active = TRUE
    )
    AND EXISTS (
        SELECT 1 FROM conversation_participants cp2 
        WHERE cp2.conversation_id = c.conversation_id 
        AND cp2.user_id = p_user2_id
        AND cp2.is_active = TRUE
    );
    
    IF v_existing_id IS NOT NULL THEN
        RETURN v_existing_id;
    END IF;
    
    -- Create new conversation
    v_conversation_id := gen_random_uuid();
    INSERT INTO conversations (conversation_id, type, clinic_id, created_at, last_message_at)
    VALUES (v_conversation_id, 'direct', p_clinic_id, NOW(), NOW());
    
    -- Add participants
    INSERT INTO conversation_participants (conversation_id, user_id, role, display_name, unread_count, is_active)
    VALUES 
        (v_conversation_id, p_user1_id, p_user1_role, p_user1_name, 0, TRUE),
        (v_conversation_id, p_user2_id, p_user2_role, p_user2_name, 0, TRUE);
    
    RETURN v_conversation_id;
END;
$$;


ALTER FUNCTION "public"."create_direct_conversation"("p_user1_id" "uuid", "p_user1_role" "text", "p_user1_name" "text", "p_user2_id" "uuid", "p_user2_role" "text", "p_user2_name" "text", "p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_patient_profile"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Insert into profiles table when patient is created
    INSERT INTO profiles (id, email, role)
    VALUES (NEW.patient_id, NEW.email, 'patient')
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = EXCLUDED.role;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_patient_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clinic_services_with_pricing"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_detail" "text", "service_description" "text", "base_price" numeric, "service_price" numeric, "discount_percentage" numeric, "final_price" numeric, "duration_minutes" integer, "service_category" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.service_id,
        s.service_name,
        s.service_detail,
        s.service_description,
        s.base_price,
        COALESCE(s.service_price,s.base_price,0),
        COALESCE(s.discount_percentage,0),
        COALESCE(s.final_price,s.base_price,0),
        s.duration_minutes,
        s.service_category,
        s.is_active
    FROM services s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_clinic_services_with_pricing"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clinic_staff"("p_clinic_id" "uuid") RETURNS TABLE("staff_id" "uuid", "id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "profile_url" "text", "job_position" "text", "role" "text", "is_on_leave" boolean, "is_available" boolean, "status" "text", "working_hours" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.staff_id,
        s.id,
        s.firstname,
        s.lastname,
        s.email,
        s.phone,
        s.profile_url,
        s.position AS job_position,
        s.role,
        COALESCE(s.is_on_leave,false),
        COALESCE(s.is_available,true),
        COALESCE(s.status,'active'),
        COALESCE(s.working_hours,'{"start":"09:00","end":"17:00"}'::jsonb)
    FROM staffs s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_clinic_staff"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_clinic_status"("p_clinic_id" "uuid") RETURNS TABLE("clinic_id" "uuid", "status" "text", "rejection_reason" "text", "clinic_name" "text", "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    -- Force a fresh read from the database (no caching)
    RETURN QUERY
    SELECT 
        c.clinic_id,
        c.status,
        c.rejection_reason,
        c.clinic_name,
        c.updated_at
    FROM clinics c
    WHERE c.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_clinic_status"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_complete"("p_user_id" "uuid") RETURNS TABLE("dentist_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "specialization" "text", "qualification" "text", "role" "text", "status" "text", "fcm_token" "text", "is_available" boolean, "consultation_fee" numeric, "bio" "text", "clinic_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.dentist_id,
        COALESCE(d.firstname, '') as firstname,
        COALESCE(d.lastname, '') as lastname,
        COALESCE(d.email, '') as email,
        COALESCE(d.phone, '') as phone,
        COALESCE(d.specialization, '') as specialization,
        COALESCE(d.qualification, '') as qualification,
        COALESCE(d.role, 'dentist') as role,
        COALESCE(d.status, 'pending') as status,
        COALESCE(d.fcm_token, '') as fcm_token,
        COALESCE(d.is_available, true) as is_available,
        COALESCE(d.consultation_fee, 0) as consultation_fee,
        COALESCE(d.bio, '') as bio,
        d.clinic_id
    FROM dentists d
    WHERE d.id = p_user_id OR d.dentist_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_dentist_complete"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_dashboard"("p_dentist_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_clinic_id UUID;
    v_result JSONB;
    v_today_appointments INTEGER;
    v_pending_appointments INTEGER;
    v_completed_today INTEGER;
    v_total_patients INTEGER;
    v_total_appointments INTEGER;
    v_approved_appointments INTEGER;
    v_rejected_appointments INTEGER;
    v_cancelled_appointments INTEGER;
    v_week_completed INTEGER;
    v_month_completed INTEGER;
BEGIN
    -- Get dentist's clinic (check both id and dentist_id)
    SELECT clinic_id INTO v_clinic_id
    FROM dentists 
    WHERE id = p_dentist_id OR dentist_id = p_dentist_id;
    
    IF v_clinic_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Dentist not found or not associated with clinic');
    END IF;
    
    -- Get today's appointments (approved + completed)
    SELECT COUNT(*) INTO v_today_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND DATE(date) = CURRENT_DATE
    AND status IN ('approved', 'completed');
    
    -- Get pending appointments
    SELECT COUNT(*) INTO v_pending_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'pending';
    
    -- Get approved appointments
    SELECT COUNT(*) INTO v_approved_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'approved';
    
    -- Get completed today
    SELECT COUNT(*) INTO v_completed_today
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND DATE(completed_at) = CURRENT_DATE
    AND status = 'completed';
    
    -- Get completed this week
    SELECT COUNT(*) INTO v_week_completed
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'completed'
    AND completed_at >= date_trunc('week', CURRENT_DATE);
    
    -- Get completed this month
    SELECT COUNT(*) INTO v_month_completed
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'completed'
    AND completed_at >= date_trunc('month', CURRENT_DATE);
    
    -- Get rejected appointments
    SELECT COUNT(*) INTO v_rejected_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'rejected';
    
    -- Get cancelled appointments
    SELECT COUNT(*) INTO v_cancelled_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id 
    AND status = 'cancelled';
    
    -- Get total appointments
    SELECT COUNT(*) INTO v_total_appointments
    FROM bookings 
    WHERE clinic_id = v_clinic_id;
    
    -- Get total unique patients
    SELECT COUNT(DISTINCT patient_id) INTO v_total_patients
    FROM bookings 
    WHERE clinic_id = v_clinic_id
    AND patient_id IS NOT NULL;
    
    v_result := jsonb_build_object(
        'success', true,
        'clinic_id', v_clinic_id,
        'today_appointments', v_today_appointments,
        'pending_appointments', v_pending_appointments,
        'approved_appointments', v_approved_appointments,
        'completed_today', v_completed_today,
        'completed_this_week', v_week_completed,
        'completed_this_month', v_month_completed,
        'rejected_appointments', v_rejected_appointments,
        'cancelled_appointments', v_cancelled_appointments,
        'total_appointments', v_total_appointments,
        'total_patients', v_total_patients
    );
    
    RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_dentist_dashboard"("p_dentist_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_data"("p_user_id" "uuid") RETURNS TABLE("dentist_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "specialization" "text", "qualification" "text", "role" "text", "status" "text", "fcm_token" "text", "is_available" boolean, "consultation_fee" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.dentist_id,
        COALESCE(d.firstname, '') as firstname,
        COALESCE(d.lastname, '') as lastname,
        COALESCE(d.email, '') as email,
        COALESCE(d.phone, '') as phone,
        COALESCE(d.specialization, '') as specialization,
        COALESCE(d.qualification, '') as qualification,
        COALESCE(d.role, 'dentist') as role,
        COALESCE(d.status, 'pending') as status,
        COALESCE(d.fcm_token, '') as fcm_token,
        COALESCE(d.is_available, true) as is_available,
        COALESCE(d.consultation_fee, 0) as consultation_fee
    FROM dentists d
    WHERE d.id = p_user_id OR d.dentist_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_dentist_data"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_profile"("p_user_id" "uuid") RETURNS TABLE("dentist_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "profile_url" "text", "specialization" "text", "qualification" "text", "experience_years" integer, "status" "text", "clinic_id" "uuid", "clinic_name" "text", "clinic_status" "text", "role" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.dentist_id,
        d.firstname,
        d.lastname,
        d.email,
        d.phone,
        d.profile_url,
        d.specialization,
        d.qualification,
        d.experience_years,
        d.status,
        d.clinic_id,
        c.clinic_name,
        c.status as clinic_status,
        d.role
    FROM dentists d
    LEFT JOIN clinics c ON c.clinic_id = d.clinic_id
    WHERE d.id = p_user_id OR d.dentist_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_dentist_profile"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_safe"("p_user_id" "uuid") RETURNS TABLE("dentist_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "specialization" "text", "qualification" "text", "role" "text", "status" "text", "fcm_token" "text", "is_available" boolean, "consultation_fee" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.dentist_id,
        COALESCE(d.firstname, '') as firstname,
        COALESCE(d.lastname, '') as lastname,
        COALESCE(d.email, '') as email,
        COALESCE(d.phone, '') as phone,
        COALESCE(d.specialization, '') as specialization,
        COALESCE(d.qualification, '') as qualification,
        COALESCE(d.role, 'dentist') as role,
        COALESCE(d.status, 'pending') as status,
        COALESCE(d.fcm_token, '') as fcm_token,
        COALESCE(d.is_available, true) as is_available,
        COALESCE(d.consultation_fee, 0) as consultation_fee
    FROM dentists d
    WHERE d.id = p_user_id OR d.dentist_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_dentist_safe"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_schedule"("p_dentist_id" "uuid") RETURNS TABLE("availability_id" "uuid", "date" "date", "start_time" time without time zone, "end_time" time without time zone, "is_available" boolean, "break_start_time" time without time zone, "break_end_time" time without time zone, "max_appointments" integer, "notes" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        da.availability_id,
        da.date,
        da.start_time,
        da.end_time,
        da.is_available,
        da.break_start_time,
        da.break_end_time,
        da.max_appointments,
        da.notes
    FROM dentist_availability da
    WHERE da.dentist_id = p_dentist_id
    AND da.date >= CURRENT_DATE
    ORDER BY da.date, da.start_time;
END;
$$;


ALTER FUNCTION "public"."get_dentist_schedule"("p_dentist_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dentist_with_token"("p_user_id" "uuid") RETURNS TABLE("dentist_id" "uuid", "id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "profile_url" "text", "specialization" "text", "qualification" "text", "experience_years" integer, "status" "text", "role" "text", "fcm_token" "text", "is_available" boolean, "consultation_fee" numeric, "clinic_id" "uuid")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        d.dentist_id,
        d.id,
        d.firstname,
        d.lastname,
        d.email,
        d.phone,
        d.profile_url,
        d.specialization,
        d.qualification,
        d.experience_years,
        d.status,
        d.role,
        d.fcm_token,
        COALESCE(d.is_available,true),
        d.consultation_fee,
        d.clinic_id
    FROM dentists d
    WHERE d.id = p_user_id OR d.dentist_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."get_dentist_with_token"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_diseases"() RETURNS TABLE("disease_id" "uuid", "disease_name" "text", "category" "text", "description" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.disease_id,
        d.disease_name,
        COALESCE(d.category, 'common') as category,
        COALESCE(d.description, '') as description
    FROM diseases d
    WHERE d.is_active = true
    ORDER BY 
        CASE WHEN d.disease_name = 'None' THEN 1 ELSE 0 END,
        d.category,
        d.disease_name;
END;
$$;


ALTER FUNCTION "public"."get_diseases"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_services_complete"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_description" "text", "service_price" numeric, "max_price" numeric, "min_price" numeric, "final_price" numeric, "discount_percentage" numeric, "duration_minutes" integer, "is_active" boolean, "status" "text", "approval_status" "text", "service_category" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.service_id,
        COALESCE(s.service_name, '') as service_name,
        COALESCE(s.service_description, s.service_detail, '') as service_description,
        COALESCE(s.service_price, s.base_price, 0) as service_price,
        COALESCE(s.max_price, s.base_price, 0) as max_price,
        COALESCE(s.min_price, s.base_price, 0) as min_price,
        COALESCE(s.final_price, s.base_price, 0) as final_price,
        COALESCE(s.discount_percentage, 0) as discount_percentage,
        COALESCE(s.duration_minutes, 30) as duration_minutes,
        COALESCE(s.is_active, true) as is_active,
        COALESCE(s.status, 'active') as status,
        COALESCE(s.approval_status, 'approved') as approval_status,
        COALESCE(s.service_category, 'General') as service_category
    FROM services s
    WHERE s.clinic_id = p_clinic_id
    AND COALESCE(s.status, 'active') = 'active'
    ORDER BY s.service_name;
END;
$$;


ALTER FUNCTION "public"."get_services_complete"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_services_data"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_description" "text", "service_price" numeric, "max_price" numeric, "min_price" numeric, "final_price" numeric, "discount_percentage" numeric, "duration_minutes" integer, "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.service_id,
        COALESCE(s.service_name, '') as service_name,
        COALESCE(s.service_description, '') as service_description,
        COALESCE(s.service_price, s.base_price, 0) as service_price,
        COALESCE(s.max_price, s.base_price, 0) as max_price,
        COALESCE(s.min_price, s.base_price, 0) as min_price,
        COALESCE(s.final_price, s.base_price, 0) as final_price,
        COALESCE(s.discount_percentage, 0) as discount_percentage,
        COALESCE(s.duration_minutes, 30) as duration_minutes,
        COALESCE(s.is_active, true) as is_active
    FROM services s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_services_data"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_services_safe"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_description" "text", "service_price" numeric, "max_price" numeric, "min_price" numeric, "final_price" numeric, "discount_percentage" numeric, "duration_minutes" integer, "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.service_id,
        COALESCE(s.service_name, '') as service_name,
        COALESCE(s.service_description, '') as service_description,
        COALESCE(s.service_price, s.base_price, 0) as service_price,
        COALESCE(s.max_price, s.base_price, 0) as max_price,
        COALESCE(s.min_price, s.base_price, 0) as min_price,
        COALESCE(s.final_price, s.base_price, 0) as final_price,
        COALESCE(s.discount_percentage, 0) as discount_percentage,
        COALESCE(s.duration_minutes, 30) as duration_minutes,
        COALESCE(s.is_active, true) as is_active
    FROM services s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_services_safe"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_services_with_pricing"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_description" "text", "base_price" numeric, "service_price" numeric, "max_price" numeric, "min_price" numeric, "final_price" numeric, "discount_percentage" numeric, "price_range" "text", "pricing_type" "text", "service_category" "text", "duration_minutes" integer, "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.service_id,
        COALESCE(s.service_name, '') as service_name,
        COALESCE(s.service_description, s.service_detail, '') as service_description,
        COALESCE(s.base_price, 0) as base_price,
        COALESCE(s.service_price, s.base_price, 0) as service_price,
        COALESCE(s.max_price, s.base_price, 0) as max_price,
        COALESCE(s.min_price, s.base_price, 0) as min_price,
        COALESCE(s.final_price, s.base_price, 0) as final_price,
        COALESCE(s.discount_percentage, 0) as discount_percentage,
        COALESCE(s.price_range, '₹0') as price_range,
        COALESCE(s.pricing_type, 'fixed') as pricing_type,
        COALESCE(s.service_category, 'General') as service_category,
        COALESCE(s.duration_minutes, 30) as duration_minutes,
        COALESCE(s.is_active, true) as is_active
    FROM services s
    WHERE s.clinic_id = p_clinic_id
    ORDER BY s.service_name;
END;
$$;


ALTER FUNCTION "public"."get_services_with_pricing"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_services_with_status"("p_clinic_id" "uuid") RETURNS TABLE("service_id" "uuid", "service_name" "text", "service_description" "text", "service_price" numeric, "max_price" numeric, "min_price" numeric, "final_price" numeric, "discount_percentage" numeric, "duration_minutes" integer, "is_active" boolean, "status" "text", "approval_status" "text", "visibility" "text", "service_category" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.service_id,
        COALESCE(s.service_name, '') as service_name,
        COALESCE(s.service_description, s.service_detail, '') as service_description,
        COALESCE(s.service_price, s.base_price, 0) as service_price,
        COALESCE(s.max_price, s.base_price, 0) as max_price,
        COALESCE(s.min_price, s.base_price, 0) as min_price,
        COALESCE(s.final_price, s.base_price, 0) as final_price,
        COALESCE(s.discount_percentage, 0) as discount_percentage,
        COALESCE(s.duration_minutes, 30) as duration_minutes,
        COALESCE(s.is_active, true) as is_active,
        COALESCE(s.status, 'active') as status,
        COALESCE(s.approval_status, 'approved') as approval_status,
        COALESCE(s.visibility, 'public') as visibility,
        COALESCE(s.service_category, 'General') as service_category
    FROM services s
    WHERE s.clinic_id = p_clinic_id
    AND s.status = 'active'
    AND s.approval_status = 'approved'
    ORDER BY s.sort_order, s.service_name;
END;
$$;


ALTER FUNCTION "public"."get_services_with_status"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_staff_complete"("p_clinic_id" "uuid") RETURNS TABLE("staff_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "staff_position" "text", "is_on_leave" boolean, "is_available" boolean, "staff_status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.staff_id,
        COALESCE(s.firstname, '') as firstname,
        COALESCE(s.lastname, '') as lastname,
        COALESCE(s.email, '') as email,
        COALESCE(s.phone, '') as phone,
        COALESCE(s."position", '') as staff_position,
        COALESCE(s.is_on_leave, false) as is_on_leave,
        COALESCE(s.is_available, true) as is_available,
        COALESCE(s.staff_status, 'active') as staff_status
    FROM staffs s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_staff_complete"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_staff_data"("p_clinic_id" "uuid") RETURNS TABLE("staff_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "staff_position" "text", "is_on_leave" boolean, "is_available" boolean, "staff_status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.staff_id,
        COALESCE(s.firstname, '') as firstname,
        COALESCE(s.lastname, '') as lastname,
        COALESCE(s.email, '') as email,
        COALESCE(s.phone, '') as phone,
        COALESCE(s."position", '') as staff_position,
        COALESCE(s.is_on_leave, false) as is_on_leave,
        COALESCE(s.is_available, true) as is_available,
        COALESCE(s.staff_status, 'active') as staff_status
    FROM staffs s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_staff_data"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_staff_safe"("p_clinic_id" "uuid") RETURNS TABLE("staff_id" "uuid", "firstname" "text", "lastname" "text", "email" "text", "phone" "text", "staff_position" "text", "is_on_leave" boolean, "is_available" boolean, "status" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.staff_id,
        COALESCE(s.firstname, '') as firstname,
        COALESCE(s.lastname, '') as lastname,
        COALESCE(s.email, '') as email,
        COALESCE(s.phone, '') as phone,
        COALESCE(s.position, '') as staff_position,
        COALESCE(s.is_on_leave, false) as is_on_leave,
        COALESCE(s.is_available, true) as is_available,
        COALESCE(s.status, 'active') as status
    FROM staffs s
    WHERE s.clinic_id = p_clinic_id;
END;
$$;


ALTER FUNCTION "public"."get_staff_safe"("p_clinic_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") RETURNS TABLE("conversation_id" "uuid", "type" "text", "title" "text", "last_message_preview" "text", "last_message_at" timestamp with time zone, "unread_count" integer, "participants" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.conversation_id,
        c.type,
        c.title,
        c.last_message_preview,
        c.last_message_at,
        COALESCE(cp_me.unread_count, 0) as unread_count,
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'user_id', cp_others.user_id,
                    'role', cp_others.role,
                    'display_name', cp_others.display_name
                )
            )
            FROM conversation_participants cp_others
            WHERE cp_others.conversation_id = c.conversation_id
            AND cp_others.user_id != p_user_id
            AND cp_others.is_active = TRUE
        ) as participants
    FROM conversations c
    JOIN conversation_participants cp_me ON cp_me.conversation_id = c.conversation_id
    WHERE cp_me.user_id = p_user_id
    AND cp_me.is_active = TRUE
    ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$;


ALTER FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_clinic_resubmission"("p_clinic_id" "uuid", "p_address" "text" DEFAULT NULL::"text", "p_latitude" double precision DEFAULT NULL::double precision, "p_longitude" double precision DEFAULT NULL::double precision, "p_license_url" "text" DEFAULT NULL::"text", "p_permit_url" "text" DEFAULT NULL::"text", "p_office_url" "text" DEFAULT NULL::"text", "p_profile_url" "text" DEFAULT NULL::"text", "p_frontal_image_url" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_current_status TEXT;
    v_result JSONB;
BEGIN
    -- Get current status
    SELECT status INTO v_current_status 
    FROM clinics 
    WHERE clinic_id = p_clinic_id;
    
    IF v_current_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Clinic not found');
    END IF;
    
    -- Only allow resubmission if currently rejected
    IF v_current_status != 'rejected' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Can only resubmit rejected applications',
            'current_status', v_current_status
        );
    END IF;
    
    -- Update clinic with new data and reset status
    UPDATE clinics 
    SET 
        status = 'pending',
        rejection_reason = NULL,
        address = COALESCE(p_address, address),
        latitude = COALESCE(p_latitude, latitude),
        longitude = COALESCE(p_longitude, longitude),
        license_url = COALESCE(p_license_url, license_url),
        permit_url = COALESCE(p_permit_url, permit_url),
        office_url = COALESCE(p_office_url, office_url),
        profile_url = COALESCE(p_profile_url, profile_url),
        frontal_image_url = COALESCE(p_frontal_image_url, frontal_image_url),
        updated_at = NOW()
    WHERE clinic_id = p_clinic_id;
    
    -- Log the resubmission
    INSERT INTO notification_queue (type, recipient_id, payload, processed)
    VALUES (
        'clinic_resubmission',
        p_clinic_id,
        jsonb_build_object(
            'clinic_id', p_clinic_id,
            'message', 'Clinic has resubmitted their application for review',
            'timestamp', NOW()
        ),
        false
    );
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Application resubmitted successfully',
        'new_status', 'pending'
    );
END;
$$;


ALTER FUNCTION "public"."handle_clinic_resubmission"("p_clinic_id" "uuid", "p_address" "text", "p_latitude" double precision, "p_longitude" double precision, "p_license_url" "text", "p_permit_url" "text", "p_office_url" "text", "p_profile_url" "text", "p_frontal_image_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_unread_count"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF NEW.conversation_id IS NOT NULL THEN
        -- Increment unread count for participants except sender
        UPDATE conversation_participants
        SET unread_count = unread_count + 1
        WHERE conversation_id = NEW.conversation_id
          AND user_id != NEW.sender_id
          AND is_active = TRUE;
        
        -- Update conversation last message
        UPDATE conversations
        SET 
            last_message_preview = LEFT(COALESCE(NEW.content, NEW.message, ''), 100),
            last_message_at = COALESCE(NEW.created_at, NEW.timestamp, NOW()),
            updated_at = NOW()
        WHERE conversation_id = NEW.conversation_id;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."increment_unread_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_conversation_read"("p_conversation_id" "uuid", "p_user_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    UPDATE conversation_participants
    SET 
        unread_count = 0,
        last_read_at = NOW()
    WHERE conversation_id = p_conversation_id
      AND user_id = p_user_id;
END;
$$;


ALTER FUNCTION "public"."mark_conversation_read"("p_conversation_id" "uuid", "p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_on_new_message"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_recipient RECORD;
    v_sender_name TEXT;
BEGIN
    v_sender_name := COALESCE(NEW.sender_name, 'Someone');

    IF NEW.conversation_id IS NOT NULL THEN
        FOR v_recipient IN 
            SELECT cp.user_id, cp.role
            FROM conversation_participants cp
            WHERE cp.conversation_id = NEW.conversation_id
            AND cp.user_id != NEW.sender_id
            AND cp.is_active = TRUE
        LOOP
            BEGIN
                INSERT INTO system_notifications (
                    recipient_id,
                    recipient_role,
                    event_type,
                    title,
                    body,
                    related_entity_id,
                    related_entity_type,
                    metadata
                ) VALUES (
                    v_recipient.user_id,
                    v_recipient.role,
                    'chat_message',
                    'Message from ' || v_sender_name,
                    LEFT(COALESCE(NEW.content, NEW.message, ''), 100),
                    COALESCE(NEW.message_id, NEW.id),
                    'message',
                    jsonb_build_object(
                        'conversation_id', NEW.conversation_id,
                        'sender_id', NEW.sender_id,
                        'sender_name', v_sender_name
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                NULL; -- Ignore errors
            END;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_on_new_message"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admins" (
    "admin_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid",
    "firstname" "text",
    "lastname" "text",
    "email" "text",
    "phone" "text",
    "profile_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "fcm_token" "text"
);


ALTER TABLE "public"."admins" OWNER TO "postgres";


COMMENT ON TABLE "public"."admins" IS 'Admin users for system support and management';



COMMENT ON COLUMN "public"."admins"."admin_id" IS 'UUID matching auth.users.id for admin user';



COMMENT ON COLUMN "public"."admins"."firstname" IS 'Admin first name';



COMMENT ON COLUMN "public"."admins"."lastname" IS 'Admin last name';



COMMENT ON COLUMN "public"."admins"."email" IS 'Admin email address';



CREATE TABLE IF NOT EXISTS "public"."bills" (
    "bill_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "booking_id" "uuid",
    "patient_id" "uuid",
    "clinic_id" "uuid",
    "treatment_fee" numeric(10,2) DEFAULT 0,
    "additional_fees" numeric(10,2) DEFAULT 0,
    "total_amount" numeric(10,2) NOT NULL,
    "payment_status" "text" DEFAULT 'pending'::"text",
    "image_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "service_id" "uuid",
    "service_name" "text",
    "service_price" numeric DEFAULT 0,
    "medicine_fee" numeric DEFAULT 0,
    "doctor_fee" "text",
    "recieved_money" numeric DEFAULT 0,
    "bill_change" numeric DEFAULT 0,
    "payment_mode" "text" DEFAULT 'Cash'::"text",
    CONSTRAINT "bills_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."bills" OWNER TO "postgres";


COMMENT ON COLUMN "public"."bills"."service_id" IS 'Reference to the service provided';



COMMENT ON COLUMN "public"."bills"."service_name" IS 'Name of the service provided';



COMMENT ON COLUMN "public"."bills"."service_price" IS 'Price of the main service';



COMMENT ON COLUMN "public"."bills"."medicine_fee" IS 'Additional fees for medicines or extra services';



COMMENT ON COLUMN "public"."bills"."doctor_fee" IS 'Additional details about medicines, anesthesia, etc.';



COMMENT ON COLUMN "public"."bills"."recieved_money" IS 'Amount of money received from patient';



COMMENT ON COLUMN "public"."bills"."bill_change" IS 'Change amount returned to patient';



COMMENT ON COLUMN "public"."bills"."payment_mode" IS 'Method of payment (Cash, GCash, etc.)';



CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "booking_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "patient_id" "uuid",
    "clinic_id" "uuid",
    "dentist_id" "uuid",
    "service_id" "uuid",
    "date" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'pending'::"text",
    "completed_at" timestamp with time zone,
    "completion_notes" "text",
    "rejection_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "appointment_type" "text" DEFAULT 'consultation'::"text",
    "estimated_duration" integer DEFAULT 30,
    "payment_status" "text" DEFAULT 'pending'::"text",
    "emergency_booking" boolean DEFAULT false,
    "reminder_sent" boolean DEFAULT false,
    "confirmation_sent" boolean DEFAULT false,
    "rating" integer,
    "feedback" "text",
    "start_time" "text",
    "end_time" "text",
    CONSTRAINT "bookings_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5))),
    CONSTRAINT "bookings_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'completed'::"text", 'rejected'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."clinic_appointment_stats" AS
 SELECT "bookings"."clinic_id",
    "count"(*) FILTER (WHERE ("bookings"."status" = 'pending'::"text")) AS "pending_count",
    "count"(*) FILTER (WHERE ("bookings"."status" = 'approved'::"text")) AS "approved_count",
    "count"(*) FILTER (WHERE ("bookings"."status" = 'completed'::"text")) AS "completed_count",
    "count"(*) FILTER (WHERE ("bookings"."status" = 'rejected'::"text")) AS "rejected_count",
    "count"(*) FILTER (WHERE ("bookings"."status" = 'cancelled'::"text")) AS "cancelled_count",
    "count"(*) FILTER (WHERE (("bookings"."status" = 'approved'::"text") AND ("date"("bookings"."date") = CURRENT_DATE))) AS "todays_appointments",
    "count"(*) FILTER (WHERE (("bookings"."status" = 'completed'::"text") AND ("date"("bookings"."completed_at") = CURRENT_DATE))) AS "todays_completed",
    "count"(*) FILTER (WHERE (("bookings"."status" = 'completed'::"text") AND ("bookings"."completed_at" >= "date_trunc"('week'::"text", (CURRENT_DATE)::timestamp with time zone)))) AS "week_completed",
    "count"(*) FILTER (WHERE (("bookings"."status" = 'completed'::"text") AND ("bookings"."completed_at" >= "date_trunc"('month'::"text", (CURRENT_DATE)::timestamp with time zone)))) AS "month_completed"
   FROM "public"."bookings"
  GROUP BY "bookings"."clinic_id";


ALTER TABLE "public"."clinic_appointment_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clinics" (
    "clinic_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid",
    "clinic_name" "text" NOT NULL,
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "phone" "text",
    "email" "text",
    "info" "text",
    "office_url" "text",
    "frontal_image_url" "text",
    "latitude" double precision,
    "longitude" double precision,
    "is_approved" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "profile_url" "text",
    "license_url" "text",
    "permit_url" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "rejection_reason" "text",
    "owner_id" "uuid",
    "has_staff" boolean DEFAULT true,
    "is_featured" boolean DEFAULT false,
    "note" "text",
    "admin_notes" "text",
    CONSTRAINT "check_rejection_reason" CHECK ((("status" <> 'rejected'::"text") OR (("status" = 'rejected'::"text") AND ("rejection_reason" IS NOT NULL) AND ("rejection_reason" <> ''::"text"))))
);


ALTER TABLE "public"."clinics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clinics_sched" (
    "sched_id" integer NOT NULL,
    "clinic_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "start_time" integer NOT NULL,
    "end_time" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "schedule_pattern" "text" DEFAULT 'Standard'::"text"
);


ALTER TABLE "public"."clinics_sched" OWNER TO "postgres";


COMMENT ON COLUMN "public"."clinics_sched"."schedule_pattern" IS 'The schedule pattern type: Standard, Pinoy Hustler, Mall Clinic, Half-Day Sat, or Custom. Used to determine time slot intervals.';



CREATE SEQUENCE IF NOT EXISTS "public"."clinics_sched_sched_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."clinics_sched_sched_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."clinics_sched_sched_id_seq" OWNED BY "public"."clinics_sched"."sched_id";



CREATE TABLE IF NOT EXISTS "public"."conversation_participants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "display_name" "text",
    "last_read_at" timestamp with time zone DEFAULT "now"(),
    "unread_count" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "joined_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."conversation_participants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "conversation_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" "text" DEFAULT 'direct'::"text" NOT NULL,
    "clinic_id" "uuid",
    "title" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "last_message_preview" "text",
    "last_message_at" timestamp with time zone
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dentist_availability" (
    "availability_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dentist_id" "uuid" NOT NULL,
    "clinic_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "is_available" boolean DEFAULT true,
    "break_start_time" time without time zone,
    "break_end_time" time without time zone,
    "max_appointments" integer DEFAULT 10,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."dentist_availability" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."dentists" (
    "dentist_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid",
    "clinic_id" "uuid",
    "firstname" "text",
    "lastname" "text",
    "email" "text",
    "phone" "text",
    "profile_url" "text",
    "specialization" "text",
    "qualification" "text",
    "experience_years" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "password" "text",
    "role" "text",
    "status" "text" DEFAULT 'pending'::"text",
    "is_active" boolean DEFAULT true,
    "verification_status" "text" DEFAULT 'pending'::"text",
    "fcm_token" "text",
    "is_available" boolean DEFAULT true,
    "working_hours" "jsonb" DEFAULT '{"end": "17:00", "start": "09:00"}'::"jsonb",
    "consultation_fee" numeric(10,2),
    "license_number" "text",
    "license_expiry" "date",
    "is_verified" boolean DEFAULT false,
    "verification_date" timestamp with time zone,
    "bio" "text",
    "languages_spoken" "text"[],
    "education" "jsonb",
    "certifications" "jsonb",
    "awards" "jsonb",
    "social_media" "jsonb",
    "emergency_contact" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "date_of_birth" "date",
    "gender" "text",
    "blood_group" "text",
    "marital_status" "text",
    "dentist_address" "text",
    "dentist_city" "text",
    "dentist_state" "text",
    "dentist_pincode" "text",
    CONSTRAINT "dentists_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'suspended'::"text"]))),
    CONSTRAINT "dentists_verification_status_check" CHECK (("verification_status" = ANY (ARRAY['pending'::"text", 'verified'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."dentists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."diseases" (
    "disease_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "disease_name" "text" NOT NULL,
    "disease_code" "text",
    "description" "text",
    "category" "text" DEFAULT 'common'::"text",
    "severity" "text" DEFAULT 'mild'::"text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "diseases_name_not_empty" CHECK ((("disease_name" IS NOT NULL) AND ("disease_name" <> ''::"text")))
);


ALTER TABLE "public"."diseases" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."disease" AS
 SELECT "diseases"."disease_id",
    "diseases"."disease_name",
    "diseases"."category",
    "diseases"."description",
    "diseases"."is_active"
   FROM "public"."diseases";


ALTER TABLE "public"."disease" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fcm_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "token" "text" NOT NULL,
    "device_type" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fcm_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."feedbacks" (
    "feedback_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "clinic_id" "uuid",
    "patient_id" "uuid",
    "dentist_id" "uuid",
    "rating" integer,
    "feedback" "text",
    "feedback_type" "text" DEFAULT 'general'::"text",
    "is_anonymous" boolean DEFAULT false,
    "is_approved" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "feedbacks_rating_check" CHECK ((("rating" >= 1) AND ("rating" <= 5)))
);


ALTER TABLE "public"."feedbacks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "message_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid" DEFAULT "gen_random_uuid"(),
    "sender_id" "uuid" NOT NULL,
    "receiver_id" "uuid",
    "message" "text",
    "timestamp" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone,
    "is_read" boolean DEFAULT false,
    "conversation_id" "uuid",
    "sender_role" "text",
    "sender_name" "text",
    "content" "text",
    "message_type" "text" DEFAULT 'text'::"text",
    "attachment_url" "text",
    "is_deleted" boolean DEFAULT false
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "type" "text" NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "payload" "jsonb" NOT NULL,
    "processed" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notification_queue" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."patients" (
    "patient_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid",
    "firstname" "text",
    "lastname" "text",
    "email" "text",
    "phone" "text",
    "profile_url" "text",
    "date_of_birth" "date",
    "gender" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "medical_history" "text",
    "allergies" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "role" "text" DEFAULT 'patient'::"text",
    "age" integer,
    "password" "text",
    "fcm_token" "text"
);


ALTER TABLE "public"."patients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'dentist'::"text", 'staff'::"text", 'patient'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."services" (
    "service_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "clinic_id" "uuid",
    "service_name" "text" NOT NULL,
    "service_detail" "text",
    "service_description" "text",
    "base_price" numeric(10,2),
    "duration_minutes" integer,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "service_price" numeric(10,2),
    "discount_percentage" numeric(5,2) DEFAULT 0,
    "final_price" numeric(10,2),
    "service_category" "text",
    "service_tags" "text"[],
    "service_image_url" "text",
    "is_emergency_service" boolean DEFAULT false,
    "requires_appointment" boolean DEFAULT true,
    "max_advance_booking_days" integer DEFAULT 30,
    "max_price" numeric(10,2),
    "min_price" numeric(10,2),
    "price_range" "text",
    "pricing_type" "text" DEFAULT 'fixed'::"text",
    "status" "text" DEFAULT 'active'::"text",
    "approval_status" "text" DEFAULT 'approved'::"text",
    "visibility" "text" DEFAULT 'public'::"text",
    "priority" integer DEFAULT 1,
    "sort_order" integer DEFAULT 0,
    "disease_id" "uuid",
    "medical_tags" "text"[],
    CONSTRAINT "services_approval_status_check" CHECK (("approval_status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"]))),
    CONSTRAINT "services_discount_check" CHECK ((("discount_percentage" >= (0)::numeric) AND ("discount_percentage" <= (100)::numeric))),
    CONSTRAINT "services_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text", 'deleted'::"text"]))),
    CONSTRAINT "services_visibility_check" CHECK (("visibility" = ANY (ARRAY['public'::"text", 'private'::"text", 'hidden'::"text"])))
);


ALTER TABLE "public"."services" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."services_complete_view" AS
 SELECT "services"."service_id",
    "services"."clinic_id",
    "services"."service_name",
    "services"."service_detail",
    "services"."service_description",
    COALESCE("services"."base_price", (0)::numeric) AS "base_price",
    COALESCE("services"."service_price", "services"."base_price", (0)::numeric) AS "service_price",
    COALESCE("services"."max_price", "services"."base_price", (0)::numeric) AS "max_price",
    COALESCE("services"."min_price", "services"."base_price", (0)::numeric) AS "min_price",
    COALESCE("services"."final_price", "services"."base_price", (0)::numeric) AS "final_price",
    COALESCE("services"."discount_percentage", (0)::numeric) AS "discount_percentage",
    COALESCE("services"."price_range", '₹0'::"text") AS "price_range",
    COALESCE("services"."pricing_type", 'fixed'::"text") AS "pricing_type",
    COALESCE("services"."service_category", 'General'::"text") AS "service_category",
    "services"."duration_minutes",
    "services"."is_active",
    "services"."created_at",
    "services"."updated_at"
   FROM "public"."services";


ALTER TABLE "public"."services_complete_view" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staffs" (
    "staff_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "id" "uuid",
    "clinic_id" "uuid",
    "dentist_id" "uuid",
    "firstname" "text",
    "lastname" "text",
    "email" "text",
    "phone" "text",
    "profile_url" "text",
    "position" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "role" "text" DEFAULT 'staff'::"text",
    "is_on_leave" boolean DEFAULT false,
    "leave_start_date" "date",
    "leave_end_date" "date",
    "leave_reason" "text",
    "is_available" boolean DEFAULT true,
    "working_hours" "jsonb" DEFAULT '{"end": "17:00", "start": "09:00"}'::"jsonb",
    "specialization" "text",
    "qualification" "text",
    "salary" numeric(10,2),
    "hire_date" "date" DEFAULT CURRENT_DATE,
    "emergency_contact" "text",
    "address" "text",
    "city" "text",
    "state" "text",
    "pincode" "text",
    "date_of_birth" "date",
    "gender" "text",
    "status" "text" DEFAULT 'active'::"text",
    "staff_status" "text" DEFAULT 'active'::"text",
    "password" "text",
    "fcm_token" "text",
    CONSTRAINT "staffs_gender_check" CHECK (("gender" = ANY (ARRAY['male'::"text", 'female'::"text", 'other'::"text", 'prefer_not_to_say'::"text"]))),
    CONSTRAINT "staffs_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'suspended'::"text", 'terminated'::"text"])))
);


ALTER TABLE "public"."staffs" OWNER TO "postgres";


COMMENT ON COLUMN "public"."staffs"."email" IS 'Staff email address';



COMMENT ON COLUMN "public"."staffs"."phone" IS 'Staff phone number';



COMMENT ON COLUMN "public"."staffs"."profile_url" IS 'URL of staff profile image';



COMMENT ON COLUMN "public"."staffs"."fcm_token" IS 'Firebase Cloud Messaging token for push notifications';



CREATE TABLE IF NOT EXISTS "public"."supports" (
    "support_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "dentist_id" "uuid",
    "clinic_id" "uuid",
    "subject" "text" NOT NULL,
    "message" "text" NOT NULL,
    "status" "text" DEFAULT 'open'::"text",
    "priority" "text" DEFAULT 'medium'::"text",
    "admin_response" "text",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "supports_priority_check" CHECK (("priority" = ANY (ARRAY['low'::"text", 'medium'::"text", 'high'::"text", 'urgent'::"text"]))),
    CONSTRAINT "supports_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'in_progress'::"text", 'resolved'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."supports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."system_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "recipient_id" "uuid" NOT NULL,
    "recipient_role" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text",
    "related_entity_id" "uuid",
    "related_entity_type" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "priority" "text" DEFAULT 'normal'::"text",
    "push_status" "text" DEFAULT 'pending'::"text",
    "escalation_reason" "text",
    "is_read" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "read_at" timestamp with time zone,
    "sent_at" timestamp with time zone
);


ALTER TABLE "public"."system_notifications" OWNER TO "postgres";


ALTER TABLE ONLY "public"."clinics_sched" ALTER COLUMN "sched_id" SET DEFAULT "nextval"('"public"."clinics_sched_sched_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."admins"
    ADD CONSTRAINT "admins_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."admins"
    ADD CONSTRAINT "admins_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."admins"
    ADD CONSTRAINT "admins_pkey" PRIMARY KEY ("admin_id");



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_booking_id_key" UNIQUE ("booking_id");



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_pkey" PRIMARY KEY ("bill_id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("booking_id");



ALTER TABLE ONLY "public"."clinics"
    ADD CONSTRAINT "clinics_pkey" PRIMARY KEY ("clinic_id");



ALTER TABLE ONLY "public"."clinics_sched"
    ADD CONSTRAINT "clinics_sched_pkey" PRIMARY KEY ("sched_id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_conversation_id_user_id_key" UNIQUE ("conversation_id", "user_id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("conversation_id");



ALTER TABLE ONLY "public"."dentist_availability"
    ADD CONSTRAINT "dentist_availability_dentist_id_date_start_time_key" UNIQUE ("dentist_id", "date", "start_time");



ALTER TABLE ONLY "public"."dentist_availability"
    ADD CONSTRAINT "dentist_availability_pkey" PRIMARY KEY ("availability_id");



ALTER TABLE ONLY "public"."dentists"
    ADD CONSTRAINT "dentists_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."dentists"
    ADD CONSTRAINT "dentists_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."dentists"
    ADD CONSTRAINT "dentists_pkey" PRIMARY KEY ("dentist_id");



ALTER TABLE ONLY "public"."diseases"
    ADD CONSTRAINT "diseases_disease_name_key" UNIQUE ("disease_name");



ALTER TABLE ONLY "public"."diseases"
    ADD CONSTRAINT "diseases_pkey" PRIMARY KEY ("disease_id");



ALTER TABLE ONLY "public"."fcm_tokens"
    ADD CONSTRAINT "fcm_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fcm_tokens"
    ADD CONSTRAINT "fcm_tokens_user_id_token_key" UNIQUE ("user_id", "token");



ALTER TABLE ONLY "public"."feedbacks"
    ADD CONSTRAINT "feedbacks_pkey" PRIMARY KEY ("feedback_id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("message_id");



ALTER TABLE ONLY "public"."notification_queue"
    ADD CONSTRAINT "notification_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_pkey" PRIMARY KEY ("patient_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."services"
    ADD CONSTRAINT "services_pkey" PRIMARY KEY ("service_id");



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_id_key" UNIQUE ("id");



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_pkey" PRIMARY KEY ("staff_id");



ALTER TABLE ONLY "public"."supports"
    ADD CONSTRAINT "supports_pkey" PRIMARY KEY ("support_id");



ALTER TABLE ONLY "public"."system_notifications"
    ADD CONSTRAINT "system_notifications_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_bills_booking" ON "public"."bills" USING "btree" ("booking_id");



CREATE INDEX "idx_bills_clinic" ON "public"."bills" USING "btree" ("clinic_id");



CREATE INDEX "idx_bills_patient" ON "public"."bills" USING "btree" ("patient_id");



CREATE INDEX "idx_bookings_clinic" ON "public"."bookings" USING "btree" ("clinic_id");



CREATE INDEX "idx_bookings_clinic_status" ON "public"."bookings" USING "btree" ("clinic_id", "status");



CREATE INDEX "idx_bookings_date" ON "public"."bookings" USING "btree" ("date");



CREATE INDEX "idx_bookings_dentist" ON "public"."bookings" USING "btree" ("dentist_id");



CREATE INDEX "idx_bookings_dentist_date" ON "public"."bookings" USING "btree" ("dentist_id", "date");



CREATE INDEX "idx_bookings_patient" ON "public"."bookings" USING "btree" ("patient_id");



CREATE INDEX "idx_bookings_status" ON "public"."bookings" USING "btree" ("status");



CREATE INDEX "idx_clinics_approved" ON "public"."clinics" USING "btree" ("is_approved");



CREATE INDEX "idx_clinics_location" ON "public"."clinics" USING "btree" ("latitude", "longitude");



CREATE INDEX "idx_clinics_status_rejection" ON "public"."clinics" USING "btree" ("status", "rejection_reason") WHERE ("status" = 'rejected'::"text");



CREATE INDEX "idx_clinics_status_updated" ON "public"."clinics" USING "btree" ("status", "updated_at" DESC);



CREATE INDEX "idx_clinics_user_id" ON "public"."clinics" USING "btree" ("id");



CREATE INDEX "idx_conversations_clinic" ON "public"."conversations" USING "btree" ("clinic_id");



CREATE INDEX "idx_conversations_last_message" ON "public"."conversations" USING "btree" ("last_message_at" DESC);



CREATE INDEX "idx_dentists_auth_uid" ON "public"."dentists" USING "btree" ("id");



CREATE INDEX "idx_dentists_clinic" ON "public"."dentists" USING "btree" ("clinic_id");



CREATE INDEX "idx_dentists_clinic_status" ON "public"."dentists" USING "btree" ("clinic_id", "status");



CREATE INDEX "idx_dentists_fcm_token" ON "public"."dentists" USING "btree" ("fcm_token");



CREATE INDEX "idx_dentists_is_available" ON "public"."dentists" USING "btree" ("is_available");



CREATE INDEX "idx_dentists_user_id" ON "public"."dentists" USING "btree" ("id");



CREATE INDEX "idx_diseases_active" ON "public"."diseases" USING "btree" ("is_active");



CREATE INDEX "idx_diseases_category" ON "public"."diseases" USING "btree" ("category");



CREATE INDEX "idx_diseases_name" ON "public"."diseases" USING "btree" ("disease_name");



CREATE INDEX "idx_feedbacks_clinic_id" ON "public"."feedbacks" USING "btree" ("clinic_id");



CREATE INDEX "idx_feedbacks_created_at" ON "public"."feedbacks" USING "btree" ("created_at");



CREATE INDEX "idx_feedbacks_dentist_id" ON "public"."feedbacks" USING "btree" ("dentist_id");



CREATE INDEX "idx_feedbacks_is_approved" ON "public"."feedbacks" USING "btree" ("is_approved");



CREATE INDEX "idx_feedbacks_patient_id" ON "public"."feedbacks" USING "btree" ("patient_id");



CREATE INDEX "idx_feedbacks_rating" ON "public"."feedbacks" USING "btree" ("rating");



CREATE INDEX "idx_messages_conversation" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "idx_messages_receiver" ON "public"."messages" USING "btree" ("receiver_id");



CREATE INDEX "idx_messages_sender" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "idx_messages_timestamp" ON "public"."messages" USING "btree" ("timestamp" DESC);



CREATE INDEX "idx_notification_queue_created_at" ON "public"."notification_queue" USING "btree" ("created_at");



CREATE INDEX "idx_notification_queue_processed" ON "public"."notification_queue" USING "btree" ("processed");



CREATE INDEX "idx_notification_queue_recipient" ON "public"."notification_queue" USING "btree" ("recipient_id");



CREATE INDEX "idx_notification_queue_type" ON "public"."notification_queue" USING "btree" ("type");



CREATE INDEX "idx_notifications_created" ON "public"."system_notifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_notifications_read" ON "public"."system_notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_recipient" ON "public"."system_notifications" USING "btree" ("recipient_id");



CREATE INDEX "idx_participants_conversation" ON "public"."conversation_participants" USING "btree" ("conversation_id");



CREATE INDEX "idx_participants_unread" ON "public"."conversation_participants" USING "btree" ("user_id", "unread_count") WHERE ("unread_count" > 0);



CREATE INDEX "idx_participants_user" ON "public"."conversation_participants" USING "btree" ("user_id");



CREATE INDEX "idx_patients_user_id" ON "public"."patients" USING "btree" ("id");



CREATE INDEX "idx_profiles_email" ON "public"."profiles" USING "btree" ("email");



CREATE INDEX "idx_profiles_role" ON "public"."profiles" USING "btree" ("role");



CREATE INDEX "idx_services_active" ON "public"."services" USING "btree" ("is_active");



CREATE INDEX "idx_services_approval_status" ON "public"."services" USING "btree" ("approval_status");



CREATE INDEX "idx_services_clinic" ON "public"."services" USING "btree" ("clinic_id");



CREATE INDEX "idx_services_max_price" ON "public"."services" USING "btree" ("max_price");



CREATE INDEX "idx_services_min_price" ON "public"."services" USING "btree" ("min_price");



CREATE INDEX "idx_services_price" ON "public"."services" USING "btree" ("service_price");



CREATE INDEX "idx_services_pricing_type" ON "public"."services" USING "btree" ("pricing_type");



CREATE INDEX "idx_services_service_price" ON "public"."services" USING "btree" ("service_price");



CREATE INDEX "idx_services_sort_order" ON "public"."services" USING "btree" ("sort_order");



CREATE INDEX "idx_services_status" ON "public"."services" USING "btree" ("status");



CREATE INDEX "idx_services_visibility" ON "public"."services" USING "btree" ("visibility");



CREATE INDEX "idx_staffs_clinic" ON "public"."staffs" USING "btree" ("clinic_id");



CREATE INDEX "idx_staffs_dentist" ON "public"."staffs" USING "btree" ("dentist_id");



CREATE INDEX "idx_staffs_is_available" ON "public"."staffs" USING "btree" ("is_available");



CREATE INDEX "idx_staffs_is_on_leave" ON "public"."staffs" USING "btree" ("is_on_leave");



CREATE INDEX "idx_staffs_user_id" ON "public"."staffs" USING "btree" ("id");



CREATE INDEX "idx_supports_dentist" ON "public"."supports" USING "btree" ("dentist_id");



CREATE INDEX "idx_supports_status" ON "public"."supports" USING "btree" ("status");



CREATE INDEX "idx_system_notifications_recipient" ON "public"."system_notifications" USING "btree" ("recipient_id", "is_read");



CREATE OR REPLACE TRIGGER "on_new_message_increment_unread" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."increment_unread_count"();



CREATE OR REPLACE TRIGGER "patient_profile_trigger" AFTER INSERT ON "public"."patients" FOR EACH ROW EXECUTE FUNCTION "public"."create_patient_profile"();



CREATE OR REPLACE TRIGGER "trigger_notify_on_new_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."notify_on_new_message"();



CREATE OR REPLACE TRIGGER "update_admins_updated_at" BEFORE UPDATE ON "public"."admins" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_bills_updated_at" BEFORE UPDATE ON "public"."bills" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_bookings_updated_at" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_clinics_updated_at" BEFORE UPDATE ON "public"."clinics" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_conversations_updated_at" BEFORE UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_dentists_updated_at" BEFORE UPDATE ON "public"."dentists" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_feedbacks_updated_at" BEFORE UPDATE ON "public"."feedbacks" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_messages_updated_at" BEFORE UPDATE ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_notification_queue_updated_at" BEFORE UPDATE ON "public"."notification_queue" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_patients_updated_at" BEFORE UPDATE ON "public"."patients" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_profiles_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_services_updated_at" BEFORE UPDATE ON "public"."services" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_staffs_updated_at" BEFORE UPDATE ON "public"."staffs" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_supports_updated_at" BEFORE UPDATE ON "public"."supports" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."admins"
    ADD CONSTRAINT "admins_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "public"."bookings"("booking_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("patient_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_dentist_id_fkey" FOREIGN KEY ("dentist_id") REFERENCES "public"."dentists"("dentist_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("patient_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."services"("service_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."clinics"
    ADD CONSTRAINT "clinics_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clinics_sched"
    ADD CONSTRAINT "clinics_sched_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id");



ALTER TABLE ONLY "public"."conversation_participants"
    ADD CONSTRAINT "conversation_participants_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("conversation_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dentist_availability"
    ADD CONSTRAINT "dentist_availability_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id");



ALTER TABLE ONLY "public"."dentist_availability"
    ADD CONSTRAINT "dentist_availability_dentist_id_fkey" FOREIGN KEY ("dentist_id") REFERENCES "public"."dentists"("dentist_id");



ALTER TABLE ONLY "public"."dentists"
    ADD CONSTRAINT "dentists_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."dentists"
    ADD CONSTRAINT "dentists_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fcm_tokens"
    ADD CONSTRAINT "fcm_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedbacks"
    ADD CONSTRAINT "feedbacks_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feedbacks"
    ADD CONSTRAINT "feedbacks_dentist_id_fkey" FOREIGN KEY ("dentist_id") REFERENCES "public"."dentists"("dentist_id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."feedbacks"
    ADD CONSTRAINT "feedbacks_patient_id_fkey" FOREIGN KEY ("patient_id") REFERENCES "public"."patients"("patient_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."patients"
    ADD CONSTRAINT "patients_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."services"
    ADD CONSTRAINT "services_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."services"
    ADD CONSTRAINT "services_disease_id_fkey" FOREIGN KEY ("disease_id") REFERENCES "public"."diseases"("disease_id");



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_dentist_id_fkey" FOREIGN KEY ("dentist_id") REFERENCES "public"."dentists"("dentist_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staffs"
    ADD CONSTRAINT "staffs_id_fkey" FOREIGN KEY ("id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."supports"
    ADD CONSTRAINT "supports_clinic_id_fkey" FOREIGN KEY ("clinic_id") REFERENCES "public"."clinics"("clinic_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."supports"
    ADD CONSTRAINT "supports_dentist_id_fkey" FOREIGN KEY ("dentist_id") REFERENCES "public"."dentists"("dentist_id") ON DELETE CASCADE;



CREATE POLICY "Admin patient access" ON "public"."patients" FOR SELECT USING (("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")));



CREATE POLICY "Admin staff access" ON "public"."staffs" FOR SELECT USING (("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")));



CREATE POLICY "Admin update patients" ON "public"."patients" FOR UPDATE USING (("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")));



CREATE POLICY "Admins can delete clinics" ON "public"."clinics" FOR DELETE USING ((("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Admins can insert clinics" ON "public"."clinics" FOR INSERT WITH CHECK ((("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR true));



CREATE POLICY "Admins can update clinics" ON "public"."clinics" FOR UPDATE USING ((("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Admins can update dentists" ON "public"."dentists" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR ("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins"))));



CREATE POLICY "Admins can update feedback" ON "public"."feedbacks" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Admins can update notifications" ON "public"."notification_queue" FOR UPDATE USING (("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")));



CREATE POLICY "Admins can update their record" ON "public"."admins" FOR UPDATE USING (("admin_id" = "auth"."uid"()));



CREATE POLICY "Admins can view admins" ON "public"."admins" FOR SELECT USING (("admin_id" = "auth"."uid"()));



CREATE POLICY "Admins can view all admins" ON "public"."admins" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Admins can view all availability" ON "public"."dentist_availability" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Admins can view all bills" ON "public"."bills" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Admins can view all bookings" ON "public"."bookings" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Admins can view all clinics" ON "public"."clinics" FOR SELECT USING ((("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Admins can view all dentists" ON "public"."dentists" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR ("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins"))));



CREATE POLICY "Admins can view all feedback" ON "public"."feedbacks" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Admins can view all notifications" ON "public"."notification_queue" FOR SELECT USING (("auth"."uid"() IN ( SELECT "admins"."admin_id"
   FROM "public"."admins")));



CREATE POLICY "Admins can view all schedules" ON "public"."clinics_sched" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))));



CREATE POLICY "Admins can view all services" ON "public"."services" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Admins can view all supports" ON "public"."supports" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text")))) OR (EXISTS ( SELECT 1
   FROM "public"."admins"
  WHERE ("admins"."admin_id" = "auth"."uid"())))));



CREATE POLICY "Allow admin access" ON "public"."admins" TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated manage schedules" ON "public"."clinics_sched" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated read schedules" ON "public"."clinics_sched" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to insert bills" ON "public"."bills" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to insert conversation_participants" ON "public"."conversation_participants" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to insert conversations" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to insert messages" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK (true);



CREATE POLICY "Allow authenticated users to read bills" ON "public"."bills" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read clinics" ON "public"."clinics" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read conversation_participants" ON "public"."conversation_participants" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read conversations" ON "public"."conversations" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read messages" ON "public"."messages" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow authenticated users to read schedules" ON "public"."clinics_sched" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated users to update bills" ON "public"."bills" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to update conversation_participants" ON "public"."conversation_participants" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to update conversations" ON "public"."conversations" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated users to update messages" ON "public"."messages" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Allow dentists manage bookings" ON "public"."bookings" USING (("auth"."uid"() IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."clinic_id" = "bookings"."clinic_id"))));



CREATE POLICY "Allow dentists to manage clinic schedules" ON "public"."clinics_sched" USING (("auth"."uid"() IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."clinic_id" = "clinics_sched"."clinic_id"))));



CREATE POLICY "Allow patients create bookings" ON "public"."bookings" FOR INSERT WITH CHECK (("auth"."uid"() = "patient_id"));



CREATE POLICY "Allow patients read own bookings" ON "public"."bookings" FOR SELECT USING (("auth"."uid"() = "patient_id"));



CREATE POLICY "Allow patients update own bookings" ON "public"."bookings" FOR UPDATE USING (("auth"."uid"() = "patient_id"));



CREATE POLICY "Allow staff to read own data" ON "public"."staffs" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow staff to update own data" ON "public"."staffs" FOR UPDATE TO "authenticated" USING (true) WITH CHECK (true);



CREATE POLICY "Anyone can insert notifications" ON "public"."notification_queue" FOR INSERT WITH CHECK (true);



CREATE POLICY "Anyone can insert profiles" ON "public"."profiles" FOR INSERT WITH CHECK (true);



CREATE POLICY "Anyone can view active services" ON "public"."services" FOR SELECT USING (("is_active" = true));



CREATE POLICY "Clinics can create bills" ON "public"."bills" FOR INSERT WITH CHECK ((("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "staffs"."clinic_id"
   FROM "public"."staffs"
  WHERE ("staffs"."id" = "auth"."uid"())))));



CREATE POLICY "Clinics can update bookings" ON "public"."bookings" FOR UPDATE USING ((("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "staffs"."clinic_id"
   FROM "public"."staffs"
  WHERE ("staffs"."id" = "auth"."uid"())))));



CREATE POLICY "Clinics can view their dentists" ON "public"."dentists" FOR SELECT USING (("clinic_id" IN ( SELECT "clinics"."clinic_id"
   FROM "public"."clinics"
  WHERE (("clinics"."owner_id" = "auth"."uid"()) OR ("clinics"."id" = "auth"."uid"())))));



CREATE POLICY "Clinics can view their feedback" ON "public"."feedbacks" FOR SELECT USING (("clinic_id" IN ( SELECT "clinics"."clinic_id"
   FROM "public"."clinics"
  WHERE ("clinics"."owner_id" = "auth"."uid"()))));



CREATE POLICY "Dentists and admins can view supports" ON "public"."supports" FOR SELECT USING ((("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM "public"."profiles"
  WHERE (("profiles"."id" = "auth"."uid"()) AND ("profiles"."role" = 'admin'::"text"))))));



CREATE POLICY "Dentists can create supports" ON "public"."supports" FOR INSERT WITH CHECK (("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))));



CREATE POLICY "Dentists can manage clinic schedules" ON "public"."clinics_sched" USING (("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))));



CREATE POLICY "Dentists can manage clinic services" ON "public"."services" USING (("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))));



CREATE POLICY "Dentists can manage own availability" ON "public"."dentist_availability" USING (("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))));



CREATE POLICY "Dentists can update own record" ON "public"."dentists" FOR UPDATE USING ((("id" = "auth"."uid"()) OR ("dentist_id" = "auth"."uid"())));



CREATE POLICY "Dentists can view clinic bookings" ON "public"."bookings" FOR SELECT USING ((("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))) OR ("dentist_id" = "auth"."uid"()) OR ("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"())))));



CREATE POLICY "Dentists can view clinic schedules" ON "public"."clinics_sched" FOR SELECT USING (("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))));



CREATE POLICY "Dentists can view clinic services" ON "public"."services" FOR SELECT USING ((("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))) OR ("is_active" = true)));



CREATE POLICY "Dentists can view clinic staff" ON "public"."staffs" FOR SELECT USING ((("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))) OR ("dentist_id" = "auth"."uid"()) OR ("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"())))));



CREATE POLICY "Dentists can view own availability" ON "public"."dentist_availability" FOR SELECT USING (("dentist_id" IN ( SELECT "dentists"."dentist_id"
   FROM "public"."dentists"
  WHERE (("dentists"."id" = "auth"."uid"()) OR ("dentists"."dentist_id" = "auth"."uid"())))));



CREATE POLICY "Dentists can view own record" ON "public"."dentists" FOR SELECT USING ((("id" = "auth"."uid"()) OR ("dentist_id" = "auth"."uid"())));



CREATE POLICY "Dentists can view their feedback" ON "public"."feedbacks" FOR SELECT USING (("dentist_id" = "auth"."uid"()));



CREATE POLICY "Owner clinic update" ON "public"."clinics" FOR UPDATE USING (("owner_id" = "auth"."uid"()));



CREATE POLICY "Patients can create bookings" ON "public"."bookings" FOR INSERT WITH CHECK (("patient_id" IN ( SELECT "patients"."patient_id"
   FROM "public"."patients"
  WHERE ("patients"."id" = "auth"."uid"()))));



CREATE POLICY "Patients can insert their own feedback" ON "public"."feedbacks" FOR INSERT WITH CHECK (("patient_id" = "auth"."uid"()));



CREATE POLICY "Patients can update their own feedback" ON "public"."feedbacks" FOR UPDATE USING ((("patient_id" = "auth"."uid"()) AND ("is_approved" = false)));



CREATE POLICY "Patients can view their own feedback" ON "public"."feedbacks" FOR SELECT USING (("patient_id" = "auth"."uid"()));



CREATE POLICY "Patients own record access" ON "public"."patients" USING (("patient_id" = "auth"."uid"()));



CREATE POLICY "Public can view approved feedback" ON "public"."feedbacks" FOR SELECT USING (("is_approved" = true));



CREATE POLICY "Public clinic access" ON "public"."clinics" FOR SELECT USING (true);



CREATE POLICY "Public clinic insert" ON "public"."clinics" FOR INSERT WITH CHECK (true);



CREATE POLICY "Public dentist insert" ON "public"."dentists" FOR INSERT WITH CHECK (true);



CREATE POLICY "Public patient insert" ON "public"."patients" FOR INSERT WITH CHECK (true);



CREATE POLICY "Public staff insert" ON "public"."staffs" FOR INSERT WITH CHECK (true);



CREATE POLICY "Staff own record access" ON "public"."staffs" USING (("staff_id" = "auth"."uid"()));



CREATE POLICY "Users can create conversations" ON "public"."conversations" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users can join conversations" ON "public"."conversation_participants" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users can manage their tokens" ON "public"."fcm_tokens" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can send messages" ON "public"."messages" FOR INSERT WITH CHECK (("sender_id" = "auth"."uid"()));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



CREATE POLICY "Users can update their notifications" ON "public"."system_notifications" FOR UPDATE USING (("recipient_id" = "auth"."uid"()));



CREATE POLICY "Users can update their own messages" ON "public"."messages" FOR UPDATE USING (("sender_id" = "auth"."uid"()));



CREATE POLICY "Users can update their participation" ON "public"."conversation_participants" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view messages in their conversations" ON "public"."messages" FOR SELECT USING ((("conversation_id" IN ( SELECT "conversation_participants"."conversation_id"
   FROM "public"."conversation_participants"
  WHERE ("conversation_participants"."user_id" = "auth"."uid"()))) OR ("sender_id" = "auth"."uid"()) OR ("receiver_id" = "auth"."uid"())));



CREATE POLICY "Users can view own participant record" ON "public"."conversation_participants" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT USING (("id" = "auth"."uid"()));



CREATE POLICY "Users can view their conversations" ON "public"."conversations" FOR SELECT USING (("conversation_id" IN ( SELECT "cp"."conversation_id"
   FROM "public"."conversation_participants" "cp"
  WHERE ("cp"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their notifications" ON "public"."system_notifications" FOR SELECT USING (("recipient_id" = "auth"."uid"()));



CREATE POLICY "Users can view their related bills" ON "public"."bills" FOR SELECT USING ((("patient_id" IN ( SELECT "patients"."patient_id"
   FROM "public"."patients"
  WHERE ("patients"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "staffs"."clinic_id"
   FROM "public"."staffs"
  WHERE ("staffs"."id" = "auth"."uid"())))));



CREATE POLICY "Users can view their related bookings" ON "public"."bookings" FOR SELECT USING ((("patient_id" IN ( SELECT "patients"."patient_id"
   FROM "public"."patients"
  WHERE ("patients"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "dentists"."clinic_id"
   FROM "public"."dentists"
  WHERE ("dentists"."id" = "auth"."uid"()))) OR ("clinic_id" IN ( SELECT "staffs"."clinic_id"
   FROM "public"."staffs"
  WHERE ("staffs"."id" = "auth"."uid"())))));



ALTER TABLE "public"."admins" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bills" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversation_participants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "conversations_policy" ON "public"."conversations" USING (true);



ALTER TABLE "public"."dentist_availability" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fcm_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedbacks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "messages_policy" ON "public"."messages" USING (true);



ALTER TABLE "public"."notification_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_policy" ON "public"."system_notifications" USING (true);



CREATE POLICY "participants_policy" ON "public"."conversation_participants" USING (true);



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."staffs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."supports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."system_notifications" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."add_dentist_availability"("p_dentist_id" "uuid", "p_date" "date", "p_start_time" time without time zone, "p_end_time" time without time zone, "p_break_start_time" time without time zone, "p_break_end_time" time without time zone, "p_max_appointments" integer, "p_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_dentist_availability"("p_dentist_id" "uuid", "p_date" "date", "p_start_time" time without time zone, "p_end_time" time without time zone, "p_break_start_time" time without time zone, "p_break_end_time" time without time zone, "p_max_appointments" integer, "p_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_dentist_availability"("p_dentist_id" "uuid", "p_date" "date", "p_start_time" time without time zone, "p_end_time" time without time zone, "p_break_start_time" time without time zone, "p_break_end_time" time without time zone, "p_max_appointments" integer, "p_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_appointment"("p_booking_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_appointment"("p_booking_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_appointment"("p_booking_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_email_exists"("email_to_check" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."check_email_exists"("email_to_check" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_email_exists"("email_to_check" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_appointment"("p_booking_id" "uuid", "p_completion_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_appointment"("p_booking_id" "uuid", "p_completion_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_appointment"("p_booking_id" "uuid", "p_completion_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_user1_id" "uuid", "p_user1_role" "text", "p_user1_name" "text", "p_user2_id" "uuid", "p_user2_role" "text", "p_user2_name" "text", "p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_user1_id" "uuid", "p_user1_role" "text", "p_user1_name" "text", "p_user2_id" "uuid", "p_user2_role" "text", "p_user2_name" "text", "p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_direct_conversation"("p_user1_id" "uuid", "p_user1_role" "text", "p_user1_name" "text", "p_user2_id" "uuid", "p_user2_role" "text", "p_user2_name" "text", "p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_patient_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."create_patient_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_patient_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clinic_services_with_pricing"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clinic_services_with_pricing"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clinic_services_with_pricing"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clinic_staff"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clinic_staff"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clinic_staff"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_clinic_status"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_clinic_status"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_clinic_status"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_complete"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_complete"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_complete"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_dashboard"("p_dentist_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_dashboard"("p_dentist_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_dashboard"("p_dentist_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_data"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_data"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_data"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_profile"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_safe"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_safe"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_safe"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_schedule"("p_dentist_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_schedule"("p_dentist_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_schedule"("p_dentist_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dentist_with_token"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dentist_with_token"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dentist_with_token"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_diseases"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_diseases"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_diseases"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_services_complete"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_services_complete"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_services_complete"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_services_data"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_services_data"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_services_data"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_services_safe"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_services_safe"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_services_safe"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_services_with_pricing"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_services_with_pricing"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_services_with_pricing"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_services_with_status"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_services_with_status"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_services_with_status"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_staff_complete"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_staff_complete"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_staff_complete"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_staff_data"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_staff_data"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_staff_data"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_staff_safe"("p_clinic_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_staff_safe"("p_clinic_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_staff_safe"("p_clinic_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_conversations"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_clinic_resubmission"("p_clinic_id" "uuid", "p_address" "text", "p_latitude" double precision, "p_longitude" double precision, "p_license_url" "text", "p_permit_url" "text", "p_office_url" "text", "p_profile_url" "text", "p_frontal_image_url" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."handle_clinic_resubmission"("p_clinic_id" "uuid", "p_address" "text", "p_latitude" double precision, "p_longitude" double precision, "p_license_url" "text", "p_permit_url" "text", "p_office_url" "text", "p_profile_url" "text", "p_frontal_image_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_clinic_resubmission"("p_clinic_id" "uuid", "p_address" "text", "p_latitude" double precision, "p_longitude" double precision, "p_license_url" "text", "p_permit_url" "text", "p_office_url" "text", "p_profile_url" "text", "p_frontal_image_url" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_unread_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_unread_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_unread_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation_id" "uuid", "p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation_id" "uuid", "p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_conversation_read"("p_conversation_id" "uuid", "p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_on_new_message"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON TABLE "public"."admins" TO "anon";
GRANT ALL ON TABLE "public"."admins" TO "authenticated";
GRANT ALL ON TABLE "public"."admins" TO "service_role";



GRANT ALL ON TABLE "public"."bills" TO "anon";
GRANT ALL ON TABLE "public"."bills" TO "authenticated";
GRANT ALL ON TABLE "public"."bills" TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT ALL ON TABLE "public"."clinic_appointment_stats" TO "anon";
GRANT ALL ON TABLE "public"."clinic_appointment_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."clinic_appointment_stats" TO "service_role";



GRANT ALL ON TABLE "public"."clinics" TO "anon";
GRANT ALL ON TABLE "public"."clinics" TO "authenticated";
GRANT ALL ON TABLE "public"."clinics" TO "service_role";



GRANT ALL ON TABLE "public"."clinics_sched" TO "anon";
GRANT ALL ON TABLE "public"."clinics_sched" TO "authenticated";
GRANT ALL ON TABLE "public"."clinics_sched" TO "service_role";



GRANT ALL ON SEQUENCE "public"."clinics_sched_sched_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."clinics_sched_sched_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."clinics_sched_sched_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."conversation_participants" TO "anon";
GRANT ALL ON TABLE "public"."conversation_participants" TO "authenticated";
GRANT ALL ON TABLE "public"."conversation_participants" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."dentist_availability" TO "anon";
GRANT ALL ON TABLE "public"."dentist_availability" TO "authenticated";
GRANT ALL ON TABLE "public"."dentist_availability" TO "service_role";



GRANT ALL ON TABLE "public"."dentists" TO "anon";
GRANT ALL ON TABLE "public"."dentists" TO "authenticated";
GRANT ALL ON TABLE "public"."dentists" TO "service_role";



GRANT ALL ON TABLE "public"."diseases" TO "anon";
GRANT ALL ON TABLE "public"."diseases" TO "authenticated";
GRANT ALL ON TABLE "public"."diseases" TO "service_role";



GRANT ALL ON TABLE "public"."disease" TO "anon";
GRANT ALL ON TABLE "public"."disease" TO "authenticated";
GRANT ALL ON TABLE "public"."disease" TO "service_role";



GRANT ALL ON TABLE "public"."fcm_tokens" TO "anon";
GRANT ALL ON TABLE "public"."fcm_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."fcm_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."feedbacks" TO "anon";
GRANT ALL ON TABLE "public"."feedbacks" TO "authenticated";
GRANT ALL ON TABLE "public"."feedbacks" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notification_queue" TO "anon";
GRANT ALL ON TABLE "public"."notification_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_queue" TO "service_role";



GRANT ALL ON TABLE "public"."patients" TO "anon";
GRANT ALL ON TABLE "public"."patients" TO "authenticated";
GRANT ALL ON TABLE "public"."patients" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."services" TO "anon";
GRANT ALL ON TABLE "public"."services" TO "authenticated";
GRANT ALL ON TABLE "public"."services" TO "service_role";



GRANT ALL ON TABLE "public"."services_complete_view" TO "anon";
GRANT ALL ON TABLE "public"."services_complete_view" TO "authenticated";
GRANT ALL ON TABLE "public"."services_complete_view" TO "service_role";



GRANT ALL ON TABLE "public"."staffs" TO "anon";
GRANT ALL ON TABLE "public"."staffs" TO "authenticated";
GRANT ALL ON TABLE "public"."staffs" TO "service_role";



GRANT ALL ON TABLE "public"."supports" TO "anon";
GRANT ALL ON TABLE "public"."supports" TO "authenticated";
GRANT ALL ON TABLE "public"."supports" TO "service_role";



GRANT ALL ON TABLE "public"."system_notifications" TO "anon";
GRANT ALL ON TABLE "public"."system_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."system_notifications" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






