-- ============================================
-- ThinkLikeLaw: Career Gamification Metrics
-- Adds total_xp for Ultra-Elite career progression
-- ============================================

ALTER TABLE public.user_metrics 
ADD COLUMN IF NOT EXISTS total_xp integer DEFAULT 0;
