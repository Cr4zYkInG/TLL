-- Migration: Link User Metrics to Profiles
-- This enables PostgREST to join user_metrics with profiles for the leaderboard.

DO $$
BEGIN
    -- 1. Add Foreign Key from user_metrics(user_id) to profiles(id)
    -- Both already reference auth.users(id), but PostgREST needs a public schema link to join them.
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'fk_user_metrics_profiles'
    ) THEN
        ALTER TABLE public.user_metrics
        ADD CONSTRAINT fk_user_metrics_profiles
        FOREIGN KEY (user_id) REFERENCES public.profiles(id)
        ON DELETE CASCADE;
    END IF;

    -- 2. Ensure study_time_minutes in profiles is kept in sync (optional but good for performance)
    -- We'll rely on the join for now as it's more accurate for streak/time toggle.
END $$;
