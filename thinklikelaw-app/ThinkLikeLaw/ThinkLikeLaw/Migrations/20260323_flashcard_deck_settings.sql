-- Migration: Add deck settings to user_flashcards for granular SRS configuration
-- Up

ALTER TABLE public.user_flashcards
ADD COLUMN IF NOT EXISTS learning_steps text[] DEFAULT '{"1","10"}',
ADD COLUMN IF NOT EXISTS graduating_interval integer DEFAULT 1,
ADD COLUMN IF NOT EXISTS easy_interval integer DEFAULT 4;

-- Ensure RLS allows the user to update these fields
-- existing RLS on user_flashcards allows full access where auth.uid() = user_id

-- Down

-- ALTER TABLE public.user_flashcards
-- DROP COLUMN IF EXISTS learning_steps,
-- DROP COLUMN IF EXISTS graduating_interval,
-- DROP COLUMN IF EXISTS easy_interval;
