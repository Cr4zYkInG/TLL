-- Migration: Add billing_cycle to user_credits
-- Supports credit roll-over for yearly plans.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='user_credits' AND column_name='billing_cycle'
    ) THEN
        ALTER TABLE public.user_credits ADD COLUMN billing_cycle text DEFAULT 'monthly';
    END IF;
END $$;
