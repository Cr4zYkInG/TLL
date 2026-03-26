-- Migration: Add is_shared to user_modules
-- Supports sharing modules with other users via links.

ALTER TABLE public.user_modules 
ADD COLUMN IF NOT EXISTS is_shared boolean DEFAULT false;

COMMENT ON COLUMN public.user_modules.is_shared IS 'Whether this module is public/shared via a link';
