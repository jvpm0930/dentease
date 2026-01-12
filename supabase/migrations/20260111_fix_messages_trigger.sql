-- ============================================
-- FIX: Add message column if missing + Fix trigger functions
-- Migration: 20260111_fix_messages_trigger.sql
--
-- RUN THIS IN YOUR CLOUD SUPABASE SQL EDITOR
-- ============================================

-- STEP 1: Add 'message' column if it doesn't exist
-- This ensures backward compatibility with triggers
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'messages' 
        AND column_name = 'message'
    ) THEN
        ALTER TABLE messages ADD COLUMN message TEXT;
    END IF;
END $$;

-- STEP 2: Recreate the increment_unread_count function with proper null handling
CREATE OR REPLACE FUNCTION increment_unread_count() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
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
            last_message_preview = LEFT(COALESCE(NEW.content, ''), 100),
            last_message_at = COALESCE(NEW.created_at, NEW.timestamp, NOW()),
            updated_at = NOW()
        WHERE conversation_id = NEW.conversation_id;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in increment_unread_count: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- STEP 3: Recreate the notify_on_new_message function with proper null handling
CREATE OR REPLACE FUNCTION notify_on_new_message() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
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
                    LEFT(COALESCE(NEW.content, ''), 100),
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
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error in notify_on_new_message: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- STEP 4: Recreate the fn_notify_new_message function with proper null handling
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
            LEFT(COALESCE(NEW.content, ''), 100),
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

-- STEP 5: Verify messages table structure
-- Run this to see current columns:
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'messages';
