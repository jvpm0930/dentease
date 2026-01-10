---
description: How to run Supabase SQL migrations
---

# Running Supabase SQL Migrations

## Prerequisites
1. Supabase CLI installed (`npx supabase --version` to check)
2. Project linked to your Supabase instance

## Steps to Run a Migration

### Option 1: Via Supabase Dashboard (Recommended for Remote)
1. Open your Supabase Dashboard: https://supabase.com/dashboard/project/qotjgevjzmnqvmgaarod
2. Go to **SQL Editor** tab
3. Copy the contents of the migration file (e.g., `supabase/migrations/011_fix_messaging_comprehensive.sql`)
4. Paste into SQL Editor and click **Run**

### Option 2: Via Supabase CLI (Requires Docker for local dev)
```bash
# Push migrations to remote database
// turbo
npx supabase db push --linked
```

### Option 3: Using psql directly
```bash
# Connect to your database and run SQL
psql "postgresql://postgres.[project-ref]:[password]@aws-0-[region].pooler.supabase.com:5432/postgres" -f supabase/migrations/011_fix_messaging_comprehensive.sql
```

## Verify Migration Success
After running the migration, verify it by checking:

1. **Tables exist:**
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('conversations', 'conversation_participants', 'messages');
```

2. **Triggers exist:**
```sql
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name IN ('on_new_message_increment_unread', 'trigger_notify_on_new_message');
```

3. **Functions exist:**
```sql
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('increment_unread_count', 'mark_conversation_read', 'create_direct_conversation');
```

## Troubleshooting
- If you get permission errors, check RLS policies
- If realtime updates don't work, ensure tables are added to `supabase_realtime` publication
- For FCM notifications, ensure `system_notifications` table exists and has proper triggers
