-- Migration: Dual Leaderboards & Analytics

-- 1. Add lifetime_study_time tracking and last_study_reset to `user_metrics`
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='user_metrics' AND column_name='lifetime_study_time'
    ) THEN
        ALTER TABLE public.user_metrics ADD COLUMN lifetime_study_time INTEGER DEFAULT 0;
        
        -- Backfill lifetime with current study time (which currently represents all time studied)
        UPDATE public.user_metrics SET lifetime_study_time = study_time WHERE study_time > 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='user_metrics' AND column_name='last_study_reset'
    ) THEN
        ALTER TABLE public.user_metrics ADD COLUMN last_study_reset TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        -- Assume current date is their last reset for historical data transitioning
        UPDATE public.user_metrics SET last_study_reset = NOW();
    END IF;
END $$;
