-- Create app_waitlist table for iOS app beta waitlist
CREATE TABLE IF NOT EXISTS app_waitlist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    source VARCHAR(50) DEFAULT 'website', -- 'website', 'app_store', etc.
    notes TEXT
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_app_waitlist_email ON app_waitlist(email);
CREATE INDEX IF NOT EXISTS idx_app_waitlist_created_at ON app_waitlist(created_at);

-- Add comments
COMMENT ON TABLE app_waitlist IS 'Beta waitlist for ThinkLikeLaw iOS app';
COMMENT ON COLUMN app_waitlist.email IS 'User email address for notifications';
COMMENT ON COLUMN app_waitlist.created_at IS 'When user joined the waitlist';
COMMENT ON COLUMN app_waitlist.source IS 'Where user signed up from';
COMMENT ON COLUMN app_waitlist.notes IS 'Optional notes or additional info';