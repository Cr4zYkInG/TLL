-- Migration: Leaderboard Public View Permissions
-- Fixes problem where users could only see their own metrics, breaking the global leaderboard.

DO $$
BEGIN
    -- 1. Create a public SELECT policy for user_metrics
    -- This is safe because names and universities are controlled via the profiles table (which respects anonymity)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_metrics' AND policyname = 'Public metrics are viewable byeveryone') THEN
        CREATE POLICY "Public metrics are viewable by everyone" ON public.user_metrics
            FOR SELECT USING (true);
    END IF;

    -- 2. Ensure profiles table has public select policy (should already exist per schema.sql)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Public profiles are viewable by everyone.') THEN
        CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles 
            FOR SELECT USING (true);
    END IF;
END $$;
