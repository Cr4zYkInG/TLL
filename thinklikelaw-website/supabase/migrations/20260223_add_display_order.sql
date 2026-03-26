-- Add display_order to modules and lectures
ALTER TABLE public.user_modules ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;
ALTER TABLE public.lectures ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

-- Update indexes for performance if needed
CREATE INDEX IF NOT EXISTS idx_user_modules_order ON public.user_modules (user_id, display_order);
CREATE INDEX IF NOT EXISTS idx_lectures_order ON public.lectures (user_id, module_id, display_order);
