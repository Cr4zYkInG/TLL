-- ============================================
-- ThinkLikeLaw: Tombstones & Atomic Metrics
-- Fixes sync resurrection and metric race conditions
-- ============================================

-- 1. Add is_deleted to user_modules
ALTER TABLE public.user_modules 
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

-- 2. Add is_deleted to lectures & deadlines
ALTER TABLE public.lectures 
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

ALTER TABLE public.deadlines 
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

ALTER TABLE public.user_flashcards 
ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

-- 3. Create Atomic Metrics RPC
-- Handles time addition, streak logic, and lifetime tracking in one transaction
CREATE OR REPLACE FUNCTION public.increment_study_metrics(p_minutes integer)
RETURNS jsonb AS $$
DECLARE
    v_user_id uuid;
    v_today text;
    v_last_date text;
    v_current_streak integer;
    v_new_streak integer;
    v_result jsonb;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    v_today := to_char(CURRENT_DATE, 'YYYY-MM-DD');

    -- Get current status
    SELECT last_study_date, streak INTO v_last_date, v_current_streak
    FROM public.user_metrics
    WHERE user_id = v_user_id;

    -- Handle streak logic
    IF v_last_date = v_today THEN
        v_new_streak := v_current_streak; -- Already studied today
    ELSIF v_last_date = to_char(CURRENT_DATE - INTERVAL '1 day', 'YYYY-MM-DD') THEN
        v_new_streak := v_current_streak + 1; -- Consecutive day
    ELSE
        v_new_streak := 1; -- Streak broken
    END IF;

    -- Update metrics
    INSERT INTO public.user_metrics (user_id, study_time, lifetime_study_time, last_study_date, streak)
    VALUES (v_user_id, p_minutes, p_minutes, v_today, 1)
    ON CONFLICT (user_id) DO UPDATE SET
        study_time = CASE 
            WHEN public.user_metrics.last_study_date = v_today THEN public.user_metrics.study_time + p_minutes
            ELSE p_minutes
        END,
        lifetime_study_time = public.user_metrics.lifetime_study_time + p_minutes,
        last_study_date = v_today,
        streak = v_new_streak;

    -- Return updated values for local UI sync
    SELECT jsonb_build_object(
        'study_time', study_time,
        'lifetime_study_time', lifetime_study_time,
        'streak', streak
    ) INTO v_result
    FROM public.user_metrics
    WHERE user_id = v_user_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.increment_study_metrics IS 'Atomically increments study time and updates streaks based on current date.';
