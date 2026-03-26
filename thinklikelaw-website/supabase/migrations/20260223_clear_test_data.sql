-- Clear all test modules and lectures for the current user
-- Run this in your Supabase SQL editor before going live

-- 1. Delete all lectures (notes) for all users (test data cleanup)
DELETE FROM lectures;

-- 2. Delete all modules for all users (test data cleanup)
DELETE FROM modules;

-- 3. Optionally reset review/retention counts
-- (Already gone since lectures are deleted)

-- 4. Clear flashcard sets if needed
-- DELETE FROM user_flashcards;

-- Note: profiles, credits, and other user data are preserved.
