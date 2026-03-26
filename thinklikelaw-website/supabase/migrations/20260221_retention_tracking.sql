-- Migration: Add Learning Curve Retention Tracking
-- Augments the `lectures` table to track spaced repetition metrics.

ALTER TABLE public.lectures 
ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_reviewed_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS retention_score real DEFAULT 100.0;

COMMENT ON COLUMN public.lectures.review_count IS 'Number of times the student has successfully reviewed the note';
COMMENT ON COLUMN public.lectures.last_reviewed_at IS 'Timestamp of the most recent review';
COMMENT ON COLUMN public.lectures.retention_score IS 'Cached retention percentage based on the last calculation';
