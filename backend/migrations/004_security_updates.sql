-- ════════════════════════════════════════════
-- BizDesk — Security Updates
-- Run this in Supabase SQL Editor
-- ════════════════════════════════════════════

-- ── Audit Logs ────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  table_name TEXT,
  record_id TEXT,
  details JSONB DEFAULT '{}',
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own audit logs
CREATE POLICY "audit_logs_own" ON audit_logs FOR ALL USING (auth.uid() = user_id);

-- ── Secure Storage ────────────────────────────
-- Delete old public policies first
DROP POLICY IF EXISTS "Public Access Files" ON storage.objects;
DROP POLICY IF EXISTS "Upload Files" ON storage.objects;
DROP POLICY IF EXISTS "Update Files" ON storage.objects;

-- Create signed URL-only access policy
-- Users can only access their own files (files must be prefixed with user_id/)
CREATE POLICY "Secure File Access" ON storage.objects FOR ALL
  USING (
    bucket_id = 'bizdesk-files'
    AND (
      (bucket_id = 'bizdesk-files' AND (name LIKE user_id || '/%'))
      OR
      (bucket_id = 'bizdesk-files' AND auth.role() = 'service_role')
    )
  );

-- Allow authenticated users to upload files (auto-prefixed with user_id)
CREATE POLICY "Secure Upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'bizdesk-files'
    AND name LIKE (auth.uid() || '/%')
  );

-- Allow authenticated users to delete their own files
CREATE POLICY "Secure Delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'bizdesk-files'
    AND name LIKE (auth.uid() || '/%')
  );

-- ── Add indexes for audit logs ─────────────────
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

-- ── Session Management ─────────────────────────
-- This function checks if user session is valid
CREATE OR REPLACE FUNCTION check_user_session(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  session_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO session_count
  FROM auth.sessions
  WHERE user_id = check_user_session.user_id
    AND expires_at > NOW();

  RETURN session_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── Secure User Data Access ────────────────────
-- Users can only read their own profile
CREATE OR REPLACE FUNCTION get_user_profile(user_id UUID)
RETURNS TABLE(id UUID, name TEXT, email TEXT, phone TEXT, business_name TEXT, plan TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.name, u.email, u.phone, u.business_name, u.plan
  FROM users u
  WHERE u.id = user_id
    AND (u.id = auth.uid() OR auth.role() = 'service_role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Done!
SELECT 'Security updates applied successfully!' as message;