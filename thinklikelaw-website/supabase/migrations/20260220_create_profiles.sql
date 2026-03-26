-- Migration: Create Profiles Table
-- This table was missing from the database, causing failures in leaderboard and user tracking.

DO $$
BEGIN
    -- 1. Create Profiles table
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        CREATE TABLE public.profiles (
            id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL PRIMARY KEY,
            first_name text,
            last_name text,
            university text,
            target_year text,
            current_status text,
            avatar_url text,
            leaderboard_username text,
            is_anonymous boolean DEFAULT false,
            email text,
            last_active_at timestamptz DEFAULT now(),
            created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
        );
    END IF;

    -- 2. Enable RLS
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    -- 3. Create Policies
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Public profiles are viewable by everyone.') THEN
        CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can insert their own profile.') THEN
        CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can update their own profile.') THEN
        CREATE POLICY "Users can update their own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Users can update their own activity') THEN
        CREATE POLICY "Users can update their own activity" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
    END IF;
END $$;
