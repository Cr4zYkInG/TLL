-- Enable UUIDs
create extension if not exists "uuid-ossp";

-- Profiles table (extends auth.users)
create table public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  first_name text,
  last_name text,
  email text,
  university text,
  student_level text default 'llb',
  llb_year text,
  exam_board text,
  school_urn text,
  target_year text,
  current_status text,
  avatar_url text,
  plan text default 'free',
  study_time_minutes integer default 0,
  leaderboard_username text,
  is_anonymous boolean default false,
  last_active_at timestamp with time zone default timezone('utc'::text, now()),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- RLS for Profiles
alter table public.profiles enable row level security;
create policy "Public profiles are viewable by everyone." on public.profiles for select using (true);
create policy "Users can insert their own profile." on public.profiles for insert with check (auth.uid() = id);
create policy "Users can update their own profile." on public.profiles for update using (auth.uid() = id);

-- Modules (e.g., Contract Law, Tort Law)
create table public.modules (
  id uuid default uuid_generate_v4() primary key,
  title text not null,
  description text,
  icon text, -- font awesome class
  is_core boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- User Modules (Progress tracking)
create table public.user_modules (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  module_id uuid references public.modules(id) on delete cascade not null,
  progress integer default 0,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(user_id, module_id)
);

alter table public.user_modules enable row level security;
create policy "Users can view own modules" on public.user_modules for select using (auth.uid() = user_id);
create policy "Users can update own modules" on public.user_modules for update using (auth.uid() = user_id);
create policy "Users can insert own modules" on public.user_modules for insert with check (auth.uid() = user_id);

-- Flashcards
create table public.flashcards (
  id uuid default uuid_generate_v4() primary key,
  module_id uuid references public.modules(id) on delete cascade,
  front text not null,
  back text not null,
  user_id uuid references public.profiles(id) on delete cascade, -- if null, it's a system card
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.flashcards enable row level security;
create policy "Read public cards" on public.flashcards for select using (user_id is null or auth.uid() = user_id);
create policy "Users create cards" on public.flashcards for insert with check (auth.uid() = user_id);
create policy "Users update own cards" on public.flashcards for update using (auth.uid() = user_id);

-- Insert Seed Data (Core Modules)
insert into public.modules (title, icon, is_core) values
('Contract Law', 'fa-file-contract', true),
('Tort Law', 'fa-scale-unbalanced-flip', true),
('Public Law', 'fa-landmark', true),
('Equity & Trusts', 'fa-hand-holding-dollar', true),
('Criminal Law', 'fa-gavel', true),
('Land Law', 'fa-house-chimney', true),
('EU Law', 'fa-globe-europe', true);
