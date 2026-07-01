-- Remove foreign key constraint from users table
-- This allows creating users without needing them in auth.users first
-- Run in Supabase SQL Editor

ALTER TABLE users DROP CONSTRAINT users_id_fkey;

-- Now create the test user
INSERT INTO users (id, name, email, business_name, plan)
VALUES ('00000000-0000-0000-0000-000000000001', 'Test User', 'test@bizdesk.app', 'Test Business', 'pro')
ON CONFLICT (id) DO UPDATE SET
  name = 'Test User',
  email = 'test@bizdesk.app',
  business_name = 'Test Business',
  plan = 'pro';