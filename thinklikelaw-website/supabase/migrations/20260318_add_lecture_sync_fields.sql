-- Migration: Add missing sync fields to lectures
-- Adds columns required for full parity between iOS App and Website

ALTER TABLE public.lectures 
ADD COLUMN IF NOT EXISTS drawing_data TEXT,
ADD COLUMN IF NOT EXISTS paper_style TEXT DEFAULT 'blank',
ADD COLUMN IF NOT EXISTS paper_color TEXT DEFAULT 'white',
ADD COLUMN IF NOT EXISTS audio_url TEXT,
ADD COLUMN IF NOT EXISTS pdf_data TEXT,
ADD COLUMN IF NOT EXISTS attachment_url TEXT,
ADD COLUMN IF NOT EXISTS ai_history JSONB DEFAULT '[]'::jsonb;

-- Ensure RLS policies still apply (they should as they are table-level)

COMMENT ON COLUMN public.lectures.drawing_data IS 'Base64 encoded PencilKit drawing data from iOS app';
COMMENT ON COLUMN public.lectures.paper_style IS 'Visual style of the note paper (e.g., blank, lined, grid)';
COMMENT ON COLUMN public.lectures.paper_color IS 'Background color of the note paper';
COMMENT ON COLUMN public.lectures.audio_url IS 'URL to recorded lecture audio in Supabase Storage';
COMMENT ON COLUMN public.lectures.pdf_data IS 'Base64 encoded PDF version of the note';
COMMENT ON COLUMN public.lectures.attachment_url IS 'URL to any additional file attachment';
COMMENT ON COLUMN public.lectures.ai_history IS 'JSON array of AI chat messages related to this note';
