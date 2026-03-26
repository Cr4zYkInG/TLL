-- Migration: Add A-Level Support & Unify Schema
-- Adds missing fields to profiles for A-Level students and admin tracking.

ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS student_level text DEFAULT 'llb',
ADD COLUMN IF NOT EXISTS llb_year text,
ADD COLUMN IF NOT EXISTS exam_board text,
ADD COLUMN IF NOT EXISTS school_urn text,
ADD COLUMN IF NOT EXISTS plan text DEFAULT 'free',
ADD COLUMN IF NOT EXISTS study_time_minutes integer DEFAULT 0;

-- Ensure last_active_at exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='last_active_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_active_at timestamptz DEFAULT now();
    END IF;
END $$;

COMMENT ON COLUMN public.profiles.student_level IS 'Can be "llb" or "alevel"';
COMMENT ON COLUMN public.profiles.exam_board IS 'Specific for A-Level: AQA, OCR, Eduqas';
COMMENT ON COLUMN public.profiles.school_urn IS 'Unique Reference Number for UK schools';
