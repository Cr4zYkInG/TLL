-- Migration: Special Promo Codes & Rolling Credits Support

-- 1. Add `tier_expires_at` to `user_credits` if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='user_credits' AND column_name='tier_expires_at'
    ) THEN
        ALTER TABLE public.user_credits ADD COLUMN tier_expires_at TIMESTAMP WITH TIME ZONE NULL;
    END IF;
END $$;

-- 2. Add `duration_days` to `promo_codes` if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='promo_codes' AND column_name='duration_days'
    ) THEN
        ALTER TABLE public.promo_codes ADD COLUMN duration_days INTEGER NULL;
    END IF;
END $$;

-- 3. Insert 'REFILL' Promo Code
-- Adds 1000 credits, unlimited global uses, but normally limited to 1 use per user by the app logic
INSERT INTO public.promo_codes (code, description, credits, tier, usage_limit, usage_count)
VALUES (
    'REFILL', 
    'Adds 1000 credits to user balance', 
    1000, 
    'free', 
    999999, 
    0
)
ON CONFLICT (code) DO UPDATE 
SET credits = 1000, description = 'Adds 1000 credits to user balance';

-- 4. Insert 'BETATRIAL' Promo Code
-- Grants Subscriber status for 7 days
INSERT INTO public.promo_codes (code, description, credits, tier, duration_days, usage_limit, usage_count)
VALUES (
    'BETATRIAL', 
    'Grants 7 days of Pro subscriber tier', 
    0, 
    'subscriber', 
    7, 
    999999, 
    0
)
ON CONFLICT (code) DO UPDATE 
SET tier = 'subscriber', duration_days = 7, description = 'Grants 7 days of Pro subscriber tier';
