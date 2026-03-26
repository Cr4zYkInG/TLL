-- ═══════════════════════════════════════════════════════════════
-- Reports Table & Avatar Storage
-- ═══════════════════════════════════════════════════════════════

-- 1. Reports table for community content moderation
CREATE TABLE IF NOT EXISTS reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    item_id text NOT NULL,
    item_type text NOT NULL CHECK (item_type IN ('note', 'flashcard', 'other')),
    reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    reason text NOT NULL,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
    reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- RLS for reports
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Users can create reports
CREATE POLICY "Users can create reports" ON reports
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = reported_by);

-- Users can view their own reports
CREATE POLICY "Users can view own reports" ON reports
    FOR SELECT TO authenticated
    USING (auth.uid() = reported_by);

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS idx_reports_item ON reports(item_id, item_type);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);

-- 2. Add avatar_url column to profiles
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS avatar_url text;

-- 3. Storage bucket for profile pictures
-- NOTE: Run this in Supabase Dashboard > Storage > Create Bucket:
--   Name: profile-pictures
--   Public: true
--   File size limit: 5MB
--   Allowed MIME types: image/png, image/jpeg, image/gif, image/webp
--
-- Storage policies (run in SQL Editor):
-- INSERT policy: authenticated users can upload to avatars/{user_id}.*
-- SELECT policy: public (anyone can read)
-- UPDATE policy: users can update their own avatar
-- DELETE policy: users can delete their own avatar

-- Storage policies via SQL (if storage policies table is available)
-- These may need to be created via the Dashboard UI instead

COMMENT ON TABLE reports IS 'Community content reports for moderation';
COMMENT ON COLUMN profiles.avatar_url IS 'Public URL of user profile picture from Supabase Storage';
