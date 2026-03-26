-- OPTIMIZATION: Wrap auth functions in subqueries for results caching
-- Addresses Supabase Advisor Performance Warnings
-- In Postgres, auth.uid() is evaluated per row leading to O(N) execution time.
-- Wrapping it in a scalar subquery (SELECT auth.uid()) evaluates it once per query O(1).

-- 1. user_modules
DROP POLICY IF EXISTS "Users manage own modules" ON public.user_modules;
CREATE POLICY "Users manage own modules" ON public.user_modules 
  FOR ALL USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

-- 2. lectures
DROP POLICY IF EXISTS "Users manage own lectures" ON public.lectures;
CREATE POLICY "Users manage own lectures" ON public.lectures 
  FOR ALL USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

-- 3. user_metrics
DROP POLICY IF EXISTS "Users manage own metrics" ON public.user_metrics;
CREATE POLICY "Users manage own metrics" ON public.user_metrics 
  FOR ALL USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

-- 4. user_credits
DROP POLICY IF EXISTS "Users manage own credits" ON public.user_credits;
CREATE POLICY "Users manage own credits" ON public.user_credits 
  FOR ALL USING ((SELECT auth.uid()) = user_id) WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Admins can update user credits" ON public.user_credits;
CREATE POLICY "Admins can update user credits" ON public.user_credits 
  FOR ALL USING (((SELECT auth.jwt()) ->> 'email') = 'admin@thinklikelaw.com');

-- 5. promo_codes & user_redemptions (if they exist)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'user_redemptions') THEN
        DROP POLICY IF EXISTS "Users can view own redemptions" ON public.user_redemptions;
        CREATE POLICY "Users can view own redemptions" ON public.user_redemptions 
          FOR SELECT USING ((SELECT auth.uid()) = user_id);

        DROP POLICY IF EXISTS "Users can insert own redemptions" ON public.user_redemptions;
        CREATE POLICY "Users can insert own redemptions" ON public.user_redemptions 
          FOR INSERT WITH CHECK ((SELECT auth.uid()) = user_id);
    END IF;

    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'promo_codes') THEN
        DROP POLICY IF EXISTS "Admins can manage promo codes" ON public.promo_codes;
        CREATE POLICY "Admins can manage promo codes" ON public.promo_codes 
          FOR ALL USING (((SELECT auth.jwt()) ->> 'email') = 'admin@thinklikelaw.com');

        DROP POLICY IF EXISTS "Logged in users can update usage count" ON public.promo_codes;
        CREATE POLICY "Logged in users can update usage count" ON public.promo_codes 
          FOR UPDATE USING ((SELECT auth.role()) = 'authenticated');
    END IF;
END $$;

-- 6. profiles
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
CREATE POLICY "Users can insert their own profile." ON public.profiles 
  FOR INSERT WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Users can update their own profile." ON public.profiles;
CREATE POLICY "Users can update their own profile." ON public.profiles 
  FOR UPDATE USING ((SELECT auth.uid()) = id);

-- Cleanup redundant update policy on profiles to prevent multiple permissive UPDATEs warning
DROP POLICY IF EXISTS "Users can update their own activity" ON public.profiles;
