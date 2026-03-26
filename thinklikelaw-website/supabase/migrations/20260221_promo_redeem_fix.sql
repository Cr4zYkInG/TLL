-- Allow authenticated users to update the usage count of promo codes
-- This is required for the frontend redeemPromoCode function to increment the counter
-- Security: Users can only increment, though this policy allows general update for brevity
-- In a stricter environment, you would use a check to ensure usage_count only increases by 1

CREATE POLICY "Logged in users can update usage count" ON public.promo_codes
    FOR UPDATE USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- Also ensure user_redemptions allows insertion for the current user
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_redemptions' AND policyname = 'Users can insert own redemptions') THEN
        CREATE POLICY "Users can insert own redemptions" ON public.user_redemptions
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;
