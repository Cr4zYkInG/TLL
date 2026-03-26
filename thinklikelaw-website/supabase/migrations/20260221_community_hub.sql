-- Migration: Community Hub Features
-- Adds public sharing and upvote capabilities to notes and flashcards.

-- 1. Updates to Lectures (Notes)
ALTER TABLE public.lectures 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS upvotes INTEGER DEFAULT 0;

-- 2. Updates to Flashcards (Individual Cards - optional but good for Granular sharing)
ALTER TABLE public.flashcards 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS upvotes INTEGER DEFAULT 0;

-- 3. Updates to User Flashcards (Decks/Sets)
ALTER TABLE public.user_flashcards 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS upvotes INTEGER DEFAULT 0;

-- 4. RLS Policies for Public Access
-- Allow anyone (authenticated or not) to select public items
CREATE POLICY "Public items are viewable by everyone" 
ON public.lectures FOR SELECT 
USING (is_public = true);

CREATE POLICY "Public flashcards are viewable by everyone" 
ON public.flashcards FOR SELECT 
USING (is_public = true);

CREATE POLICY "Public decks are viewable by everyone" 
ON public.user_flashcards FOR SELECT 
USING (is_public = true);

-- 5. Indices for performance
CREATE INDEX IF NOT EXISTS idx_lectures_public ON public.lectures(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_flashcards_public ON public.flashcards(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_user_flashcards_public ON public.user_flashcards(is_public) WHERE is_public = true;

COMMENT ON COLUMN public.lectures.is_public IS 'Determines if the note is visible in the Community Hub';
COMMENT ON COLUMN public.lectures.upvotes IS 'Number of community upvotes for this note';
COMMENT ON COLUMN public.flashcards.is_public IS 'Determines if the flashcard is visible in the Community Hub';
COMMENT ON COLUMN public.user_flashcards.is_public IS 'Determines if the flashcard deck is visible in the Community Hub';
COMMENT ON COLUMN public.user_flashcards.upvotes IS 'Number of community upvotes for this deck';
