-- Migration: Final Profile Schema Alignment
-- Ensures JS fields match database columns exactly for full cloud sync.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS graduation_year text,
ADD COLUMN IF NOT EXISTS student_status text;

-- Migration: Copy values if old columns exist (for backward compatibility)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='target_year') THEN
        UPDATE public.profiles SET graduation_year = target_year WHERE graduation_year IS NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='current_status') THEN
        UPDATE public.profiles SET student_status = current_status WHERE student_status IS NULL;
    END IF;
END $$;

COMMENT ON COLUMN public.profiles.graduation_year IS 'The year the student expects to qualify/graduate (mapped from target_year)';
COMMENT ON COLUMN public.profiles.student_status IS 'The specific academic stage (e.g., alevel_yr12, llb, sqe1)';
