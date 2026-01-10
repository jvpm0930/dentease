-- ============================================
-- FCM Push Notifications - Database Setup
-- Migration: 20260106_fcm_push_notifications.sql
-- 
-- This migration sets up:
-- 1. Enhanced notification triggers for all events
-- 2. Helper functions for queueing notifications
-- 3. Webhook configuration notes
-- ============================================

-- ============================================
-- 1. DROP EXISTING TRIGGERS (if any)
-- ============================================

DROP TRIGGER IF EXISTS trigger_notify_on_new_message ON messages;
DROP TRIGGER IF EXISTS trigger_notify_on_new_booking ON bookings;
DROP TRIGGER IF EXISTS trigger_notify_on_booking_status_change ON bookings;
DROP TRIGGER IF EXISTS trigger_notify_on_clinic_status_change ON clinics;
DROP TRIGGER IF EXISTS trigger_notify_on_new_clinic ON clinics;
DROP TRIGGER IF EXISTS trigger_notify_on_bill_created ON bills;

-- ============================================
-- 2. FUNCTION: Queue notification to system_notifications
-- This creates in-app notifications that the app can read
-- ============================================

CREATE OR REPLACE FUNCTION queue_push_notification(
    p_recipient_id UUID,
    p_recipient_role TEXT,
    p_event_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_related_entity_id UUID DEFAULT NULL,
    p_related_entity_type TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::JSONB,
    p_priority TEXT DEFAULT 'normal'
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification_id UUID;
BEGIN
    INSERT INTO system_notifications (
        recipient_id,
        recipient_role,
        event_type,
        title,
        body,
        related_entity_id,
        related_entity_type,
        metadata,
        priority,
        push_status,
        is_read,
        created_at
    ) VALUES (
        p_recipient_id,
        p_recipient_role,
        p_event_type,
        p_title,
        p_body,
        p_related_entity_id,
        p_related_entity_type,
        p_metadata,
        p_priority,
        'pending',
        false,
        NOW()
    )
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION queue_push_notification IS 'Helper function to queue push notifications to the system_notifications table';

-- ============================================
-- 3. FUNCTION: Notify on new message
-- Triggered when a new message is inserted
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_participant RECORD;
    v_sender_name TEXT;
BEGIN
    -- Get sender name
    v_sender_name := COALESCE(NEW.sender_name, 'Someone');
    
    -- Loop through all participants except sender
    FOR v_participant IN 
        SELECT user_id, role, display_name
        FROM conversation_participants
        WHERE conversation_id = NEW.conversation_id
          AND user_id != NEW.sender_id
          AND is_active = TRUE
    LOOP
        -- Queue notification for each participant
        PERFORM queue_push_notification(
            v_participant.user_id,
            v_participant.role,
            'chat_message',
            'Message from ' || v_sender_name,
            LEFT(COALESCE(NEW.content, NEW.message, ''), 100),
            NEW.conversation_id,
            'conversation',
            jsonb_build_object(
                'sender_id', NEW.sender_id,
                'sender_role', NEW.sender_role,
                'message_id', NEW.message_id
            ),
            'high'
        );
    END LOOP;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log error but don't fail the insert
    RAISE WARNING 'Error in fn_notify_new_message: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for new messages
CREATE TRIGGER trigger_notify_on_new_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION fn_notify_new_message();

COMMENT ON TRIGGER trigger_notify_on_new_message ON messages IS 'Triggers push notification when a new message is inserted';

-- ============================================
-- 4. FUNCTION: Notify on new booking
-- Triggered when a new booking is inserted
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_new_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_patient_name TEXT;
    v_service_name TEXT;
    v_dentist RECORD;
    v_staff RECORD;
BEGIN
    -- Only process pending bookings
    IF NEW.status != 'pending' THEN
        RETURN NEW;
    END IF;
    
    -- Get patient name
    SELECT COALESCE(firstname || ' ' || lastname, 'A patient')
    INTO v_patient_name
    FROM patients
    WHERE patient_id = NEW.patient_id;
    
    -- Get service name
    IF NEW.service_id IS NOT NULL THEN
        SELECT COALESCE(service_name, 'a service')
        INTO v_service_name
        FROM services
        WHERE service_id = NEW.service_id;
    ELSE
        v_service_name := 'a service';
    END IF;
    
    -- Notify all dentists in the clinic
    FOR v_dentist IN 
        SELECT dentist_id
        FROM dentists
        WHERE clinic_id = NEW.clinic_id
    LOOP
        PERFORM queue_push_notification(
            v_dentist.dentist_id,
            'dentist',
            'new_booking',
            '🦷 New Appointment Request',
            v_patient_name || ' has booked ' || v_service_name,
            NEW.booking_id,
            'booking',
            jsonb_build_object(
                'patient_id', NEW.patient_id,
                'clinic_id', NEW.clinic_id,
                'service_id', NEW.service_id,
                'date', NEW.date
            ),
            'high'
        );
    END LOOP;
    
    -- Notify all staff in the clinic (not on leave)
    FOR v_staff IN 
        SELECT staff_id
        FROM staffs
        WHERE clinic_id = NEW.clinic_id
          AND COALESCE(is_on_leave, false) = false
    LOOP
        PERFORM queue_push_notification(
            v_staff.staff_id,
            'staff',
            'new_booking',
            '📅 New Appointment Request',
            v_patient_name || ' has booked ' || v_service_name,
            NEW.booking_id,
            'booking',
            jsonb_build_object(
                'patient_id', NEW.patient_id,
                'clinic_id', NEW.clinic_id
            ),
            'normal'
        );
    END LOOP;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in fn_notify_new_booking: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for new bookings
CREATE TRIGGER trigger_notify_on_new_booking
    AFTER INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION fn_notify_new_booking();

COMMENT ON TRIGGER trigger_notify_on_new_booking ON bookings IS 'Triggers push notification to dentists/staff when a new booking is created';

-- ============================================
-- 5. FUNCTION: Notify on booking status change
-- Triggered when a booking status is updated
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_booking_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clinic_name TEXT;
    v_title TEXT;
    v_body TEXT;
    v_event_type TEXT;
BEGIN
    -- Only process if status changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Get clinic name
    SELECT COALESCE(clinic_name, 'The clinic')
    INTO v_clinic_name
    FROM clinics
    WHERE clinic_id = NEW.clinic_id;
    
    -- Determine notification content based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_title := '✅ Appointment Confirmed!';
            v_body := v_clinic_name || ' has approved your appointment';
            v_event_type := 'booking_approved';
        WHEN 'rejected' THEN
            v_title := '❌ Appointment Declined';
            v_body := v_clinic_name || ' was unable to accommodate your appointment';
            v_event_type := 'booking_rejected';
        WHEN 'cancelled' THEN
            v_title := '🚫 Appointment Cancelled';
            v_body := 'Your appointment at ' || v_clinic_name || ' has been cancelled';
            v_event_type := 'booking_cancelled';
        WHEN 'completed' THEN
            v_title := '✨ Appointment Completed';
            v_body := 'Thank you for visiting ' || v_clinic_name || '!';
            v_event_type := 'booking_completed';
        ELSE
            -- Unknown status, don't notify
            RETURN NEW;
    END CASE;
    
    -- Queue notification for patient
    IF NEW.patient_id IS NOT NULL THEN
        PERFORM queue_push_notification(
            NEW.patient_id,
            'patient',
            v_event_type,
            v_title,
            v_body,
            NEW.booking_id,
            'booking',
            jsonb_build_object(
                'clinic_id', NEW.clinic_id,
                'old_status', OLD.status,
                'new_status', NEW.status
            ),
            'high'
        );
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in fn_notify_booking_status_change: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for booking status changes
CREATE TRIGGER trigger_notify_on_booking_status_change
    AFTER UPDATE ON bookings
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_notify_booking_status_change();

COMMENT ON TRIGGER trigger_notify_on_booking_status_change ON bookings IS 'Triggers push notification to patient when booking status changes';

-- ============================================
-- 6. FUNCTION: Notify on new clinic registration
-- Triggered when a new clinic is inserted (notify admin)
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_new_clinic()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin RECORD;
BEGIN
    -- Only process pending clinics
    IF NEW.status != 'pending' THEN
        RETURN NEW;
    END IF;
    
    -- Notify all admins
    FOR v_admin IN 
        SELECT admin_id FROM admins
    LOOP
        PERFORM queue_push_notification(
            v_admin.admin_id,
            'admin',
            'clinic_registered',
            '🏥 New Clinic Registration',
            NEW.clinic_name || ' has applied to join DentEase',
            NEW.clinic_id,
            'clinic',
            jsonb_build_object(
                'clinic_name', NEW.clinic_name,
                'address', NEW.address
            ),
            'high'
        );
    END LOOP;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in fn_notify_new_clinic: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for new clinic registrations
CREATE TRIGGER trigger_notify_on_new_clinic
    AFTER INSERT ON clinics
    FOR EACH ROW
    EXECUTE FUNCTION fn_notify_new_clinic();

COMMENT ON TRIGGER trigger_notify_on_new_clinic ON clinics IS 'Triggers push notification to admins when a new clinic registers';

-- ============================================
-- 7. FUNCTION: Notify on clinic status change
-- Triggered when clinic approval status changes
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_clinic_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dentist RECORD;
    v_title TEXT;
    v_body TEXT;
    v_event_type TEXT;
BEGIN
    -- Only process if status changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Determine notification content based on new status
    CASE NEW.status
        WHEN 'approved' THEN
            v_title := '🎉 Clinic Approved!';
            v_body := 'Congratulations! ' || NEW.clinic_name || ' is now live on DentEase!';
            v_event_type := 'clinic_approved';
        WHEN 'rejected' THEN
            v_title := '❌ Clinic Application Declined';
            v_body := 'Your application for ' || NEW.clinic_name || ' was declined. Reason: ' || 
                      LEFT(COALESCE(NEW.rejection_reason, 'Please review requirements'), 80);
            v_event_type := 'clinic_rejected';
        WHEN 'pending' THEN
            IF OLD.status = 'rejected' THEN
                v_title := '📝 Application Resubmitted';
                v_body := 'Your application for ' || NEW.clinic_name || ' has been resubmitted for review';
                v_event_type := 'clinic_resubmission';
            ELSE
                -- Status changed to pending from something else, don't notify
                RETURN NEW;
            END IF;
        ELSE
            -- Unknown status, don't notify
            RETURN NEW;
    END CASE;
    
    -- Notify all dentists of this clinic
    FOR v_dentist IN 
        SELECT dentist_id
        FROM dentists
        WHERE clinic_id = NEW.clinic_id
    LOOP
        PERFORM queue_push_notification(
            v_dentist.dentist_id,
            'dentist',
            v_event_type,
            v_title,
            v_body,
            NEW.clinic_id,
            'clinic',
            jsonb_build_object(
                'old_status', OLD.status,
                'new_status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            ),
            'high'
        );
    END LOOP;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in fn_notify_clinic_status_change: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for clinic status changes
CREATE TRIGGER trigger_notify_on_clinic_status_change
    AFTER UPDATE ON clinics
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION fn_notify_clinic_status_change();

COMMENT ON TRIGGER trigger_notify_on_clinic_status_change ON clinics IS 'Triggers push notification to dentists when clinic status changes';

-- ============================================
-- 8. FUNCTION: Notify on bill created
-- Triggered when a new bill is created
-- ============================================

CREATE OR REPLACE FUNCTION fn_notify_bill_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clinic_name TEXT;
    v_formatted_amount TEXT;
BEGIN
    -- Get clinic name
    SELECT COALESCE(clinic_name, 'The clinic')
    INTO v_clinic_name
    FROM clinics
    WHERE clinic_id = NEW.clinic_id;
    
    -- Format amount (Philippine Peso)
    v_formatted_amount := '₱' || TO_CHAR(COALESCE(NEW.total_amount, 0), 'FM999,999,999.00');
    
    -- Queue notification for patient
    IF NEW.patient_id IS NOT NULL THEN
        PERFORM queue_push_notification(
            NEW.patient_id,
            'patient',
            'bill_created',
            '💳 Billing Summary',
            'Your bill from ' || v_clinic_name || ' is ready: ' || v_formatted_amount,
            NEW.bill_id,
            'bill',
            jsonb_build_object(
                'clinic_id', NEW.clinic_id,
                'booking_id', NEW.booking_id,
                'total_amount', NEW.total_amount
            ),
            'normal'
        );
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in fn_notify_bill_created: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger for bill creation
CREATE TRIGGER trigger_notify_on_bill_created
    AFTER INSERT ON bills
    FOR EACH ROW
    EXECUTE FUNCTION fn_notify_bill_created();

COMMENT ON TRIGGER trigger_notify_on_bill_created ON bills IS 'Triggers push notification to patient when a bill is created';

-- ============================================
-- 9. INDEX for efficient notification queries
-- ============================================

-- Index for fetching unread notifications by recipient
CREATE INDEX IF NOT EXISTS idx_system_notifications_recipient_unread 
ON system_notifications (recipient_id, is_read, created_at DESC)
WHERE is_read = FALSE;

-- Index for push status processing
CREATE INDEX IF NOT EXISTS idx_system_notifications_push_status 
ON system_notifications (push_status, created_at)
WHERE push_status = 'pending';

-- ============================================
-- 10. GRANT PERMISSIONS
-- ============================================

-- Grant execute permission on the helper function
GRANT EXECUTE ON FUNCTION queue_push_notification TO authenticated;
GRANT EXECUTE ON FUNCTION queue_push_notification TO service_role;

-- ============================================
-- WEBHOOK SETUP NOTES
-- ============================================
-- 
-- After running this migration, you need to create Database Webhooks in
-- the Supabase Dashboard to call the 'push_notifications' Edge Function:
--
-- 1. Go to Database > Webhooks in Supabase Dashboard
-- 2. Create the following webhooks:
--
-- WEBHOOK 1: Messages Webhook
--   - Table: messages
--   - Events: INSERT
--   - URL: {{SUPABASE_URL}}/functions/v1/push_notifications
--   - Headers: 
--     Authorization: Bearer {{SUPABASE_SERVICE_ROLE_KEY}}
--     Content-Type: application/json
--
-- WEBHOOK 2: Bookings Webhook
--   - Table: bookings
--   - Events: INSERT, UPDATE
--   - URL: {{SUPABASE_URL}}/functions/v1/push_notifications
--   - Headers: (same as above)
--
-- WEBHOOK 3: Clinics Webhook
--   - Table: clinics
--   - Events: INSERT, UPDATE
--   - URL: {{SUPABASE_URL}}/functions/v1/push_notifications
--   - Headers: (same as above)
--
-- WEBHOOK 4: Bills Webhook
--   - Table: bills
--   - Events: INSERT
--   - URL: {{SUPABASE_URL}}/functions/v1/push_notifications
--   - Headers: (same as above)
--
-- Alternatively, you can use pg_net extension to call HTTP endpoints
-- directly from PostgreSQL triggers (requires pg_net to be enabled).
-- ============================================
