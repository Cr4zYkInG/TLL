-- ============================================
-- Admin RLS Policies Enhancement
-- ============================================

-- Issue: The promo_codes table had row-level security enabled but only allowed SELECT operations.
-- This prevented administrators from creating or deleting promo codes from the dashboard, 
-- causing silent failures or Postgres RLS violation errors when trying to use the tools.

-- 1. Add insert/delete/update policies for promo codes explicitly for the app's owners
CREATE POLICY "Admins can manage promo codes" ON public.promo_codes
    FOR ALL USING (
        auth.jwt() ->> 'email' = 'admin@thinklikelaw.com'
    )
    WITH CHECK (
        auth.jwt() ->> 'email' = 'admin@thinklikelaw.com'
    );

-- 2. Verify admin abilities for profiles (if not already handled by service role)
-- User management relies on querying the profiles and user_credits tables. 
-- Ensure admins can read all profiles. The existing policy allows public viewing, so this is covered.
-- "Public profiles are viewable by everyone." on public.profiles for select using (true);

-- Ensure admins can update user_credits
CREATE POLICY "Admins can update user credits" ON public.user_credits
    FOR UPDATE USING (
        auth.jwt() ->> 'email' = 'admin@thinklikelaw.com'
    )
    WITH CHECK (
        auth.jwt() ->> 'email' = 'admin@thinklikelaw.com'
    );
