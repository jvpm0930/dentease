# DentEase FCM Push Notification System

## 📱 Overview

This document describes the comprehensive FCM (Firebase Cloud Messaging) push notification system for DentEase. The system enables real-time push notifications that work even when the app is closed.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DENTEASE DATABASE                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│   │ messages │    │ bookings │    │ clinics  │    │  bills   │    │
│   └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘    │
│        │               │               │               │           │
│   ┌────▼───────────────▼───────────────▼───────────────▼────┐     │
│   │              DATABASE TRIGGERS                          │     │
│   │  • fn_notify_new_message                                │     │
│   │  • fn_notify_new_booking                                │     │
│   │  • fn_notify_booking_status_change                      │     │
│   │  • fn_notify_clinic_status_change                       │     │
│   │  • fn_notify_bill_created                               │     │
│   └────────────────────────┬────────────────────────────────┘     │
│                            │                                       │
│                            ▼                                       │
│   ┌─────────────────────────────────────────────────────────┐     │
│   │              system_notifications TABLE                 │     │
│   │  (Queued notifications with push_status='pending')      │     │
│   └─────────────────────────┬───────────────────────────────┘     │
│                             │                                      │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      SUPABASE EDGE FUNCTIONS                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌────────────────────────────────────────────────────────┐       │
│   │              fcm_processor (CRON)                       │       │
│   │  • Runs every minute via pg_cron                        │       │
│   │  • Fetches pending notifications                        │       │
│   │  • Sends FCM to user tokens or topics                   │       │
│   │  • Updates push_status to 'sent' or 'failed'            │       │
│   └────────────────────────┬───────────────────────────────┘       │
│                            │                                        │
│                            │ Also available:                        │
│                            │                                        │
│   ┌────────────────────────▼───────────────────────────────┐       │
│   │              push_notifications (HTTP)                  │       │
│   │  • Direct notification sender                           │       │
│   │  • Can be called via Database Webhooks                  │       │
│   │  • Handles all event types                              │       │
│   └────────────────────────────────────────────────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FIREBASE CLOUD MESSAGING                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│   │   Patient   │    │   Dentist   │    │    Staff    │            │
│   │  FCM Token  │    │  FCM Token  │    │  FCM Token  │            │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘            │
│          │                  │                  │                    │
│          ▼                  ▼                  ▼                    │
│   ┌────────────────────────────────────────────────────┐           │
│   │                 FCM Topic: admin_alerts             │           │
│   │                 (For admin notifications)           │           │
│   └────────────────────────────────────────────────────┘           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────────────────────────────────────────────────┐      │
│   │                  FCMService                              │      │
│   │  • Initializes Firebase Messaging                        │      │
│   │  • Requests notification permissions                     │      │
│   │  • Saves FCM token to user's table                       │      │
│   │  • Handles foreground/background notifications           │      │
│   │  • Subscribes admins to admin_alerts topic               │      │
│   └─────────────────────────────────────────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 📋 Notification Events

| Event | Trigger | Recipients | Priority |
|-------|---------|------------|----------|
| **New Message** | `messages` INSERT | All conversation participants (except sender) | High |
| **New Booking** | `bookings` INSERT (status='pending') | Clinic dentists + staff | High |
| **Booking Approved** | `bookings` UPDATE (status→'approved') | Patient | High |
| **Booking Rejected** | `bookings` UPDATE (status→'rejected') | Patient | High |
| **Booking Cancelled** | `bookings` UPDATE (status→'cancelled') | Patient | High |
| **Booking Completed** | `bookings` UPDATE (status→'completed') | Patient | Normal |
| **New Clinic Registration** | `clinics` INSERT (status='pending') | All admins (via topic) | High |
| **Clinic Approved** | `clinics` UPDATE (status→'approved') | Clinic dentists | High |
| **Clinic Rejected** | `clinics` UPDATE (status→'rejected') | Clinic dentists | High |
| **Clinic Resubmission** | `clinics` UPDATE (rejected→pending) | Clinic dentists | Normal |
| **Bill Created** | `bills` INSERT | Patient | Normal |

## 🚀 Deployment Steps

### 1. Run the SQL Migration

Apply the migration to create triggers and helper functions:

```bash
# Using Supabase CLI
supabase db push

# Or run the SQL directly in Supabase Dashboard → SQL Editor
```

### 2. Deploy Edge Functions

```bash
cd supabase

# Deploy the FCM processor (for cron-based processing)
supabase functions deploy fcm_processor

# Deploy the push_notifications function (for webhook/direct calls)
supabase functions deploy push_notifications
```

### 3. Set Up CRON Job (pg_cron)

In Supabase Dashboard → SQL Editor, run:

```sql
-- Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule fcm_processor to run every minute
SELECT cron.schedule(
  'fcm-processor',              -- job name
  '* * * * *',                  -- every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/fcm_processor',
    headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY", "Content-Type": "application/json"}'::jsonb,
    body := '{"batch_size": 50}'::jsonb
  ) AS request_id;
  $$
);
```

Replace:
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_SERVICE_ROLE_KEY` with your service role key

### 4. Alternative: Database Webhooks

Instead of pg_cron, you can use Database Webhooks:

1. Go to **Database → Webhooks** in Supabase Dashboard
2. Create webhooks for each table:

| Webhook Name | Table | Events | URL |
|-------------|-------|--------|-----|
| notify_messages | messages | INSERT | `https://[ref].supabase.co/functions/v1/push_notifications` |
| notify_bookings | bookings | INSERT, UPDATE | `https://[ref].supabase.co/functions/v1/push_notifications` |
| notify_clinics | clinics | INSERT, UPDATE | `https://[ref].supabase.co/functions/v1/push_notifications` |
| notify_bills | bills | INSERT | `https://[ref].supabase.co/functions/v1/push_notifications` |

Headers for all webhooks:
```json
{
  "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY",
  "Content-Type": "application/json"
}
```

## 📱 Flutter Integration

The FCMService in the app handles:

### Initialization (in `main.dart`)
```dart
await FCMService.initialize();
```

### Saving User Token (after login)
```dart
// For patients
await FCMService.saveUserToken(
  userId: patientId,
  tableName: 'patients',
  idColumn: 'patient_id',
);

// For dentists
await FCMService.saveUserToken(
  userId: dentistId,
  tableName: 'dentists',
  idColumn: 'dentist_id',
);

// For staff
await FCMService.saveUserToken(
  userId: staffId,
  tableName: 'staffs',
  idColumn: 'staff_id',
);
```

### Admin Topic Subscription (for admins)
```dart
// Subscribe
await FCMService.subscribeAdminToTopic();

// Unsubscribe (on logout)
await FCMService.unsubscribeAdminFromTopic();
```

## 🔑 Firebase Setup

1. **Firebase Console → Project Settings → Service Accounts**
2. Generate new private key
3. Save as `service-account.json` in:
   - `supabase/functions/process_notifications/service-account.json`
   - (Other functions import from this location)

## 📊 Monitoring & Debugging

### Check pending notifications
```sql
SELECT * FROM system_notifications 
WHERE push_status = 'pending' 
ORDER BY created_at DESC 
LIMIT 50;
```

### Check sent notifications
```sql
SELECT * FROM system_notifications 
WHERE push_status = 'sent' 
ORDER BY sent_at DESC 
LIMIT 50;
```

### Check failed notifications
```sql
SELECT * FROM system_notifications 
WHERE push_status = 'failed' 
ORDER BY created_at DESC 
LIMIT 50;
```

### Edge Function Logs
```bash
supabase functions logs fcm_processor --tail
supabase functions logs push_notifications --tail
```

## 🔧 Troubleshooting

### Notifications not being sent
1. Check if FCM token exists for the user in their table
2. Check `system_notifications` for `push_status` values
3. Check Edge Function logs for errors
4. Verify Firebase service account is correctly configured

### CRON job not running
1. Verify pg_cron and pg_net extensions are enabled
2. Check if the job is scheduled: `SELECT * FROM cron.job;`
3. Check job run history: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`

### FCM Token issues
1. Ensure app has notification permissions
2. Check if token is being saved after login
3. Verify token format (should be a long string starting with letters)

## 📁 File Structure

```
supabase/
├── functions/
│   ├── fcm_processor/
│   │   └── index.ts          # CRON-based notification processor
│   ├── push_notifications/
│   │   └── index.ts          # Webhook/direct notification handler
│   ├── notify_users/
│   │   └── index.ts          # Legacy message notifier
│   ├── notify_dentist/
│   │   └── index.ts          # Legacy booking notifier
│   └── process_notifications/
│       ├── index.ts          # Legacy processor
│       └── service-account.json  # Firebase credentials
├── migrations/
│   └── 20260106_fcm_push_notifications.sql
└── config.toml

lib/
├── logic/
│   └── fcm_service.dart      # Flutter FCM handling
└── services/
    ├── notification_service.dart
    └── unified_notification_service.dart
```

## ✅ Testing

### Test notification manually
```bash
curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/push_notifications' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "event_type": "general",
    "recipient_id": "USER_UUID",
    "recipient_role": "patient",
    "title": "Test Notification",
    "body": "This is a test notification from DentEase!"
  }'
```

### Test CRON processor
```bash
curl -X POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/fcm_processor' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"batch_size": 10}'
```
