/**
 * Site Configuration
 * 
 * For Cloudflare Pages deployment, set these as environment variables in the Pages dashboard.
 * For local development, you can edit this file directly (but don't commit the actual values).
 */

// Check if Cloudflare Pages environment variables are available
// In Cloudflare Pages, env vars are injected at build time if you have a build step
// Since this is a static site, we'll check for a global injected by a build process
const CONFIG = (() => {
  // Check for Cloudflare Pages injected environment variables
  if (typeof window !== 'undefined' && window.__ENV__) {
    return window.__ENV__;
  }
  
  // Fallback to hardcoded values for local development
  // These should match your Cloudflare Pages environment variables
  return {
    supabase: {
      url: 'https://oxlpmgnytsvdjcibtdmb.supabase.co',
      anonKey: 'sb_publishable_hR5BbCbWqj0V7sZP6lpDjg_sMhNg84A'
    }
  };
})();

// Export to global scope for other scripts
if (typeof window !== 'undefined') {
  window.SITE_CONFIG = CONFIG;
}
