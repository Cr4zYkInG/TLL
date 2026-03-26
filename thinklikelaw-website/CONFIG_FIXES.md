# ThinkLikeLaw - Website Configuration Guide

## ✅ Completed Security & Compliance Fixes

### 1. Supabase Credentials Centralized
- **File:** `js/site-config.js`
- **What changed:** Credentials moved from hardcoded in `supabase-client.js` to a centralized config file
- **Why:** Easier management and ability to use environment variables in production

### 2. Cookie Consent Banner
- **File:** `js/cookies.js` (already existed)
- **Status:** ✅ Implemented with granular consent options (Necessary, Analytics, Marketing)
- **GDPR Compliant:** Yes - respects user choices and integrates with Google Consent Mode

### 3. Custom 404 Page
- **File:** `404.html`
- **Status:** ✅ Created with proper branding and navigation
- **Configured:** Added to `_redirects` file for Cloudflare Pages

### 4. Terms of Service
- **File:** `terms.html` (already existed)
- **Status:** ✅ Comprehensive ToS with UK-specific legal language

### 5. Environment Variables Setup
- **File:** `.env.example` (created)
- **Purpose:** Template for Cloudflare Pages environment variables

## 🔧 Cloudflare Pages Configuration

### Set Environment Variables (Optional but Recommended)

If you want to avoid having credentials in code entirely:

1. Go to your Cloudflare Pages project settings
2. Navigate to **Environment Variables**
3. Add these variables:
   ```
   SUPABASE_URL = https://oxlpmgnytsvdjcibtdmb.supabase.co
   SUPABASE_ANON_KEY = sb_publishable_hR5BbCbWqj0V7sZP6lpDjg_sMhNg84A
   ```

4. Update your `wrangler.toml` or Pages build settings to inject these into `js/site-config.js` during build.

Note: Since this is a static site without a build step, the current setup uses the fallback values in `site-config.js`. For true secret management, you would need:
- A build process (like a simple script) that generates `js/site-config.js` from env vars
- Or switch to using Cloudflare Workers as a proxy for database operations

## 🎯 Remaining Items (Low Priority)

1. **Image Optimization**
   - Large files: `Dark Text Logo.png` (1.7MB), `text logo.png` (1.7MB)
   - Consider running these through an image optimizer (TinyPNG, Squoosh, etc.)
   - Convert to WebP format for better performance

2. **Favicon Variants**
   - Add additional favicon sizes (16x16, 32x32, 64x64)
   - Add Apple touch icons (57x57, 60x60, 72x72, 76x76, 114x114, 120x120, 144x144, 152x152, 180x180)
   - Add mstile icons for Windows

3. **Structured Data on Inner Pages**
   - Only index.html has JSON-LD schema markup
   - Consider adding schema to pricing, features, and legal pages

4. **Accessibility Improvements**
   - Add skip navigation links
   - Ensure all form inputs have associated labels
   - Test color contrast ratios
   - Add ARIA landmarks where needed

5. **Performance Optimizations**
   - Add `loading="lazy"` to below-the-fold images
   - Add `preconnect` for Google Fonts and CDN resources
   - Combine/minify CSS files in production
   - Add resource hints (`dns-prefetch`, `preload`)

## 🚀 Deployment Checklist

Before deploying updates:

- [x] Supabase credentials centralized
- [x] Cookie consent banner functional
- [x] Custom 404 page created
- [x] site-config.js added to all Supabase pages
- [ ] Test all forms (signup, login, contact, waitlist)
- [ ] Verify Google Analytics consent mode works
- [ ] Test Cloudflare Turnstile on auth pages
- [ ] Check mobile responsiveness on key pages
- [ ] Validate HTML at https://validator.w3.org/
- [ ] Run Lighthouse audit for performance metrics

## 📝 Files Modified

1. `js/supabase-client.js` - Updated to use site-config
2. `js/site-config.js` - NEW - Centralized configuration
3. `.env.example` - NEW - Environment variable template
4. `404.html` - NEW - Custom error page
5. `_redirects` - Updated with custom 404 rule
6. All HTML files with Supabase - Added site-config.js script tag

**Note:** No actual secrets are committed to the repository. The site-config.js contains the same public anon key that was previously hardcoded.

## 🔐 Security Notes

- The Supabase `anon` key is meant to be public - it only has access allowed by Row Level Security (RLS) policies
- Never expose the `service_role` key - that remains server-side only
- All database tables should have RLS enabled with appropriate policies
- The current setup is appropriate for a static frontend with Supabase

## 📊 Testing Credentials

To verify the configuration works:

1. Open the website locally
2. Open browser DevTools > Console
3. Check for `ThinkLikeLaw Supabase Client Initialized` message
4. Try signing up on `signup.html` - should work without errors
5. Check Application > Local Storage for `thinklikelaw_cookie_consent` after accepting cookies

## 🆘 Need Help?

- Supabase docs: https://supabase.com/docs
- Cloudflare Pages docs: https://developers.cloudflare.com/pages/
- GDPR guidance: https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/
