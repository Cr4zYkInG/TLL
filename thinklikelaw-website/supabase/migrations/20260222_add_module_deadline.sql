-- Migration: Add exam_deadline to user_modules
-- Supports tracking module-specific exam dates.

ALTER TABLE public.user_modules 
ADD COLUMN IF NOT EXISTS exam_deadline timestamptz;

COMMENT ON COLUMN public.user_modules.exam_deadline IS 'Optional date for the module exam to show countdowns';
