-- ============================================
-- ThinkLikeLaw Cloud Migration
-- Creates all tables for user-specific data
-- ============================================

-- 1. user_modules — custom modules per user
CREATE TABLE IF NOT EXISTS public.user_modules (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    icon text DEFAULT 'fa-file-contract',
    description text DEFAULT '',
    archived boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. lectures — notes per user
CREATE TABLE IF NOT EXISTS public.lectures (
    id text NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    module_id text,
    title text DEFAULT 'Untitled Note',
    content text DEFAULT '',
    preview text DEFAULT '',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    PRIMARY KEY (id, user_id)
);

-- 3. user_metrics — study time and streaks
CREATE TABLE IF NOT EXISTS public.user_metrics (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    study_time real DEFAULT 0,
    today_time real DEFAULT 0,
    last_study_date text DEFAULT '',
    streak integer DEFAULT 1,
    leaderboard_rank integer DEFAULT 99
);

-- 4. user_credits — AI credits
CREATE TABLE IF NOT EXISTS public.user_credits (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    credits integer DEFAULT 1000,
    tier text DEFAULT 'free',
    last_reset timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.user_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lectures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_credits ENABLE ROW LEVEL SECURITY;

-- RLS Policies — Users can only CRUD their own rows
DO $$
BEGIN
  -- user_modules
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_modules' AND policyname = 'Users manage own modules') THEN
    CREATE POLICY "Users manage own modules" ON public.user_modules
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;

  -- lectures
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'lectures' AND policyname = 'Users manage own lectures') THEN
    CREATE POLICY "Users manage own lectures" ON public.lectures
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;

  -- user_metrics
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_metrics' AND policyname = 'Users manage own metrics') THEN
    CREATE POLICY "Users manage own metrics" ON public.user_metrics
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;

  -- user_credits
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_credits' AND policyname = 'Users manage own credits') THEN
    CREATE POLICY "Users manage own credits" ON public.user_credits
      FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;
