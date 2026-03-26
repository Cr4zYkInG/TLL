-- ============================================
-- ThinkLikeLaw: Secure Account Deletion RPC
-- Erases all user data across all tables and deletes the auth user record.
-- ============================================

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    -- 1. Wipe all related data in public tables
    -- Note: Foreign keys should ideally be ON DELETE CASCADE, 
    -- but we perform explicit deletes for safety.
    
    DELETE FROM public.user_metrics WHERE user_id = v_user_id;
    DELETE FROM public.lectures WHERE user_id = v_user_id;
    DELETE FROM public.deadlines WHERE user_id = v_user_id;
    DELETE FROM public.user_modules WHERE user_id = v_user_id;
    DELETE FROM public.user_flashcards WHERE user_id = v_user_id;
    DELETE FROM public.flashcard_results WHERE user_id = v_user_id;
    DELETE FROM public.saved_news WHERE user_id = v_user_id;
    DELETE FROM public.chat_messages WHERE user_id = v_user_id;
    DELETE FROM public.profiles WHERE id = v_user_id;

    -- 2. Delete the user from auth.users (Requires SECURITY DEFINER + service role or specific bypass)
    -- Since we use SECURITY DEFINER, this function runs with the privileges of the creator (usually postgres/service_role)
    DELETE FROM auth.users WHERE id = v_user_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.delete_user_account IS 'Permanently erases all user records and deletes the authentication profile.';
