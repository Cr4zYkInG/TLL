-- ============================================
-- ThinkLikeLaw Missing Tables Sync
-- Ensures all functional tables exist in Supabase
-- ============================================

-- 1. user_flashcards — Decks/Sets of cards
CREATE TABLE IF NOT EXISTS public.user_flashcards (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    topic text NOT NULL,
    cards jsonb DEFAULT '[]'::jsonb,
    is_public boolean DEFAULT false,
    upvotes integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. user_essays — Essay marking results
CREATE TABLE IF NOT EXISTS public.user_essays (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    question text DEFAULT '',
    essay_text text DEFAULT '',
    module text DEFAULT '',
    grade text DEFAULT '',
    feedback jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 3. user_exams — Automated exam results
CREATE TABLE IF NOT EXISTS public.user_exams (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exam_text text DEFAULT '',
    board text DEFAULT '',
    metrics jsonb DEFAULT '{}'::jsonb,
    feedback jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 4. user_issue_spotter — AI Scenario analysis
CREATE TABLE IF NOT EXISTS public.user_issue_spotter (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    scenario_text text DEFAULT '',
    issues jsonb DEFAULT '[]'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 5. user_interpretations — Statutory interpretation
CREATE TABLE IF NOT EXISTS public.user_interpretations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    scenario_text text DEFAULT '',
    issues jsonb DEFAULT '[]'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 6. user_oscola_audits — Citation audits
CREATE TABLE IF NOT EXISTS public.user_oscola_audits (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content_text text DEFAULT '',
    audits jsonb DEFAULT '[]'::jsonb,
    score integer DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_essays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_issue_spotter ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_interpretations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_oscola_audits ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies (Owner only)
-- Note: is_public policies for flashcards/lectures are already in community_hub.sql
-- We add them here just in case they are missing for these specific tables.

DO $$
BEGIN
    -- Flashcards
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_flashcards' AND policyname = 'Owner can manage decks') THEN
        CREATE POLICY "Owner can manage decks" ON public.user_flashcards FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- Essays
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_essays' AND policyname = 'Owner can manage essays') THEN
        CREATE POLICY "Owner can manage essays" ON public.user_essays FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- Exams
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_exams' AND policyname = 'Owner can manage exams') THEN
        CREATE POLICY "Owner can manage exams" ON public.user_exams FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- Issue Spotter
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_issue_spotter' AND policyname = 'Owner can manage issues') THEN
        CREATE POLICY "Owner can manage issues" ON public.user_issue_spotter FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- Interpretations
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_interpretations' AND policyname = 'Owner can manage interpretations') THEN
        CREATE POLICY "Owner can manage interpretations" ON public.user_interpretations FOR ALL USING (auth.uid() = user_id);
    END IF;

    -- OSCOLA Audits
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_oscola_audits' AND policyname = 'Owner can manage audits') THEN
        CREATE POLICY "Owner can manage audits" ON public.user_oscola_audits FOR ALL USING (auth.uid() = user_id);
    END IF;
END $$;
