-- Migration: Contact Form and Newsletter Signup
-- Creates tables for storing contact messages and newsletter subscriptions.

-- 1. Contact Messages Table
CREATE TABLE IF NOT EXISTS public.contact_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    subject TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for Contact Messages
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can submit a contact message" ON public.contact_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Only admins can view contact messages" ON public.contact_messages FOR SELECT USING (false); -- Adjust this if you have admin roles

-- 2. Newsletter Subscribers Table
CREATE TABLE IF NOT EXISTS public.newsletter_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'active', -- active, unsubscribed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS for Newsletter Subscribers
ALTER TABLE public.newsletter_subscribers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can subscribe to the newsletter" ON public.newsletter_subscribers FOR INSERT WITH CHECK (true);
CREATE POLICY "Only admins can view subscribers" ON public.newsletter_subscribers FOR SELECT USING (false);

COMMENT ON TABLE public.contact_messages IS 'Storage for user inquiries from the landing page contact form.';
COMMENT ON TABLE public.newsletter_subscribers IS 'Storage for email addresses of users who join the newsletter.';
