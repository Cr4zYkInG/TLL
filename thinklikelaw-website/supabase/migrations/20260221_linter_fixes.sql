-- Supabase Security Linter Fixes

-- 1. Enable RLS on modules (was missing entirely)
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;

-- 2. Add strictly checked policies for modules
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'modules' AND policyname = 'Anyone can view modules') THEN
        CREATE POLICY "Anyone can view modules" ON public.modules
            FOR SELECT USING (true);
    END IF;
    
    -- Admins only can modify content (Fallback if needed)
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'modules' AND policyname = 'Admins can completely manage modules') THEN
        CREATE POLICY "Admins can completely manage modules" ON public.modules
            FOR ALL USING (auth.jwt() ->> 'email' = 'admin@thinklikelaw.com')
            WITH CHECK (auth.jwt() ->> 'email' = 'admin@thinklikelaw.com');
    END IF;
END $$;

-- 3. Restrict public profile viewing slightly (often flagged if it's purely USING true without checks)
-- This avoids warnings about completely open profiles if you only want authenticated users to see other profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DO $$
BEGIN
    CREATE POLICY "Authenticated users can see profiles" ON public.profiles
        FOR SELECT USING (auth.role() = 'authenticated');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 4. Secure flashcards (prevent anonymous insert)
DROP POLICY IF EXISTS "Users create cards" ON public.flashcards;
DO $$
BEGIN
    CREATE POLICY "Users create cards securely" ON public.flashcards
        FOR INSERT WITH CHECK (auth.uid() = user_id AND auth.role() = 'authenticated');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Notes:
-- Supabase will often throw 'Security Advisor Warnings' dynamically.
-- The most common 17 warnings usually stem from a combination of:
-- A) Tables lacking RLS entirely (like modules previously).
-- B) Policies missing the precise "auth.role() = 'authenticated'" check.
-- C) Using trigger functions with 'security definer' without setting search_path.
