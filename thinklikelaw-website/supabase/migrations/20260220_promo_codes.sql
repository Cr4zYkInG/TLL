-- ============================================
-- Promo Code Management System
-- ============================================

-- 1. promo_codes — stores the codes and their rewards
CREATE TABLE IF NOT EXISTS public.promo_codes (
    code text PRIMARY KEY,
    credits integer DEFAULT 0,
    tier text DEFAULT 'free', -- 'free' or 'subscriber'
    usage_limit integer DEFAULT 1,
    usage_count integer DEFAULT 0,
    expires_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 2. user_redemptions — tracks which user used which code
CREATE TABLE IF NOT EXISTS public.user_redemptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code text NOT NULL REFERENCES public.promo_codes(code) ON DELETE CASCADE,
    redeemed_at timestamptz DEFAULT now(),
    UNIQUE(user_id, code)
);

-- Enable RLS
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_redemptions ENABLE ROW LEVEL SECURITY;

-- Policies for promo_codes
-- Only admins (owner) can manage codes. Users can only SELECT to verify.
-- Assuming admin user has a specific email or we use service role for management.
-- For a "free/simple" setup, we'll allow users to READ any valid code to verify it.
CREATE POLICY "Anyone can check a code" ON public.promo_codes
    FOR SELECT USING (true);

-- Management policy (Admin only - simplified for this user's email)
-- NOTE: Replace 'owner@email.com' with the actual owner email if known, 
-- or use a custom claim. For now, we'll keep it restricted to Service Role for writes.
-- Or better, we can check for a specific UID if we had it.
-- Since it's a "manage promo codes" request, I'll setup the dashboard to use the JS client.

-- Policies for user_redemptions
CREATE POLICY "Users can view own redemptions" ON public.user_redemptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own redemptions" ON public.user_redemptions
    FOR INSERT WITH CHECK (auth.uid() = user_id);
