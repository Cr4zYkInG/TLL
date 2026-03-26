-- ============================================
-- ThinkLikeLaw: Read-Time Streak Validation
-- Ensures streaks are accurately reported even if 
-- the user hasn't studied today or yesterday.
-- ============================================

CREATE OR REPLACE FUNCTION public.get_active_user_metrics()
RETURNS jsonb AS $$
DECLARE
    v_user_id uuid;
    v_today date;
    v_metrics record;
    v_active_streak integer;
    v_study_time integer;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    v_today := CURRENT_DATE;

    SELECT last_study_date, streak, study_time, lifetime_study_time 
    INTO v_metrics
    FROM public.user_metrics
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('study_time', 0, 'lifetime_study_time', 0, 'streak', 0);
    END IF;

    -- If last_study_date is before yesterday, streak is actively broken
    IF v_metrics.last_study_date::date < v_today - INTERVAL '1 day' THEN
        v_active_streak := 0;
        
        -- Auto-heal the database row so it doesn't stay stale
        UPDATE public.user_metrics 
        SET streak = 0 
        WHERE user_id = v_user_id;
    ELSE
        v_active_streak := v_metrics.streak;
    END IF;

    -- Reset today's study time if it's a new day
    IF v_metrics.last_study_date::date < v_today THEN
        v_study_time := 0;
    ELSE
        v_study_time := v_metrics.study_time;
    END IF;

    RETURN jsonb_build_object(
        'study_time', v_study_time,
        'lifetime_study_time', v_metrics.lifetime_study_time,
        'streak', v_active_streak
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_active_user_metrics IS 'Returns user metrics with dynamic streak and daily time validation based on CURRENT_DATE.';
