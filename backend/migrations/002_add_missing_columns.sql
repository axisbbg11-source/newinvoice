-- ════════════════════════════════════════════
-- BizDesk — Additional Schema Updates
-- Run this in Supabase SQL editor
-- ════════════════════════════════════════════

-- Add address column to users table (for PDF invoices)
ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT;

-- Update contracts table to match our model
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS pdf_url TEXT;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS contract_value TEXT;
ALTER TABLE contracts ADD COLUMN IF NOT EXISTS signed BOOLEAN DEFAULT FALSE;

-- Rename 'type' to 'contract_type' for clarity (if exists)
-- ALTER TABLE contracts RENAME COLUMN type TO contract_type;

-- ── Create table if not exists (for fresh install) ──
-- If contracts table doesn't exist at all:
CREATE TABLE IF NOT EXISTS contracts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  contract_type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  pdf_url TEXT,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ,
  contract_value TEXT,
  signed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on contracts if not already
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;

-- Create policy if not exists
DROP POLICY IF EXISTS "contracts_own" ON contracts;
CREATE POLICY "contracts_own" ON contracts FOR ALL USING (auth.uid() = user_id);

-- Create Storage bucket for contracts if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('bizdesk-files', 'bizdesk-files', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public access to files
CREATE POLICY "Public Access Files" ON storage.objects
FOR SELECT USING (bucket_id = 'bizdesk-files');

CREATE POLICY "Upload Files" ON storage.objects
FOR INSERT WITH CHECK (bucket_id = 'bizdesk-files');

CREATE POLICY "Update Files" ON storage.objects
FOR UPDATE USING (bucket_id = 'bizdesk-files');