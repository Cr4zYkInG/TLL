-- Add missing columns to lectures table to support AI history and spaced repetition

ALTER TABLE IF EXISTS public.lectures
ADD COLUMN IF NOT EXISTS ai_history jsonb DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_reviewed_at timestamptz DEFAULT now(),
ADD COLUMN IF NOT EXISTS retention_score numeric DEFAULT 100.0;
