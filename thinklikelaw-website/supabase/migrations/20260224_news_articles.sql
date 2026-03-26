-- Migration: Add News Articles Table for Backend Aggregator
-- This table stores fetched news from NewsData, UK Legislation, and UK Parliament

CREATE TABLE IF NOT EXISTS public.news_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE,
    source TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('General', 'Legal', 'Parliamentary')),
    snippet TEXT,
    image_url TEXT,
    published_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast queries by frontend
CREATE INDEX IF NOT EXISTS idx_news_articles_category ON public.news_articles (category);
CREATE INDEX IF NOT EXISTS idx_news_articles_published_at ON public.news_articles (published_at DESC);

-- RLS: Only Service Role can Insert/Update/Delete. Authenticated users can only SELECT.
ALTER TABLE public.news_articles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to news"
    ON public.news_articles FOR SELECT
    USING (true); -- Public or Authenticated can view news
