-- Add new columns to news_articles table
ALTER TABLE public.news_articles
ADD COLUMN IF NOT EXISTS industry_tag TEXT,
ADD COLUMN IF NOT EXISTS ai_brief_cache TEXT;

-- Create saved_news table for user bookmarks
CREATE TABLE IF NOT EXISTS public.saved_news (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES public.news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, article_id)
);

-- Enable RLS on saved_news
ALTER TABLE public.saved_news ENABLE ROW LEVEL SECURITY;

-- Create policies for saved_news
CREATE POLICY "Users can view their own saved news"
    ON public.saved_news FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own saved news"
    ON public.saved_news FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own saved news"
    ON public.saved_news FOR DELETE
    USING (auth.uid() = user_id);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_saved_news_user_id ON public.saved_news(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_news_article_id ON public.saved_news(article_id);
