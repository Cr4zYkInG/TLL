-- Allow all authenticated users to view metrics for the leaderboard
CREATE POLICY "Anyone can view metrics for leaderboard"
ON public.user_metrics
FOR SELECT
TO authenticated
USING (true);
