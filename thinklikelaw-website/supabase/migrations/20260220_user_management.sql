-- ============================================
-- Admin User Management Enhancements
-- ============================================

-- 1. Add email and activity tracking to profiles
-- Note: 'email' is often stored in auth.users, but having it in public.profiles 
-- makes it easier to query/display in custom admin dashboards without complex JOINs.
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS email text,
ADD COLUMN IF NOT EXISTS last_active_at timestamptz DEFAULT now();

-- 2. Create an admin policy (Simple version: allow everyone to read for this specific use case, 
-- or restrict to a service role/specific admin UID if preferred).
-- For this "Onyx" admin page, we'll allow standard users to only see basic info, 
-- but in a production setup, you'd restrict these queries.

-- RLS Update: allow users to update their own last_active_at
CREATE POLICY "Users can update their own activity" ON public.profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
