# Deployment Instructions for ThinkLikeLaw

To fully enable your site at `www.thinklikelaw.com`, complete these verification steps:

## 1. Deploy Your Code

I have updated `package.json` with scripts to deploy your frontend and backend workers to Cloudflare.

**One-Command Deployment:**
```bash
npm run deploy:all
```
This will deploy:
1.  **Frontend** (HTML/JS) to Cloudflare Pages (`thinklikelaw` project)
2.  **Email Worker** to Cloudflare Workers
3.  **AI Worker** to Cloudflare Workers
4.  **Stripe Worker** to Cloudflare Workers

*Note: The first time you run this, you may need to log in via `npx wrangler login`.*

## 2. Configure Secrets (Critical)

Your workers need API keys to function. Set these in your Cloudflare Dashboard (Workers & Pages -> Variables) or use the CLI:

```bash
# Stripe Worker Secrets
npx wrangler secret put STRIPE_SECRET_KEY --config wrangler-stripe.toml
npx wrangler secret put STRIPE_WEBHOOK_SECRET --config wrangler-stripe.toml
npx wrangler secret put SUPABASE_URL --config wrangler-stripe.toml
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY --config wrangler-stripe.toml

# AI Worker Secrets
npx wrangler secret put MISTRAL_API_KEY --config wrangler-ai.toml
```

## 3. Configure External Services

### Supabase Auth (Google OAuth)
1.  Go to **Supabase Dashboard** -> **Authentication** -> **Providers** -> **Google** and enable it.
2.  Enter these credentials (provided by you):
    -   **Client ID**: `[YOUR_GOOGLE_CLIENT_ID]`
    -   **Client Secret**: `[YOUR_GOOGLE_CLIENT_SECRET]`
3.  Ensure the **Authorized Redirect URI** in your Google Cloud Console matches what Supabase gives you (usually `https://oxlpmgnytsvdjcibtdmb.supabase.co/auth/v1/callback`).

### Supabase URL Configuration
1.  Go to **Supabase Dashboard** -> **Authentication** -> **URL Configuration**.
2.  Set **Site URL** to: `https://www.thinklikelaw.com`
3.  Add these to **Redirect URLs**:
    -   `https://www.thinklikelaw.com/onboarding.html`
    -   `https://www.thinklikelaw.com/reset-password.html`
    -   `https://www.thinklikelaw.com/dashboard.html`

### Stripe
1.  In Stripe Dashboard, set the **Webhook Endpoint** to:
    `https://thinklikelaw-stripe.<your-subdomain>.workers.dev/api/webhook`
2.  Ensure **Success/Cancel URLs** in your product links default to `https://www.thinklikelaw.com/...`.

## 4. Final Verification
-   **Supabase Key**: I've preserved the API key in `js/supabase-client.js`. Ensure it is your active `anon` public key.
-   **DNS**: Ensure `www.thinklikelaw.com` points to your Cloudflare Pages project (configure this in the Cloudflare Dashboard under Pages -> Custom Domains).
