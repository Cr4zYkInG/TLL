# ThinkLikeLaw Architecture & Deployment Guide

## 🏗️ Architecture: "Serverless SaaS"

You asked if "plain HTML" is fine for a complex SaaS. **Yes, absolutely!** In fact, this is how modern, high-scale applications (like Vercel, Netlify, and Cloudflare apps) are built.

Your app uses a **Headless Architecture**:

1.  **Frontend (The Face)**:
    *   **Files**: HTML, CSS, JS in `public_html`.
    *   **Role**: Renders the UI instantly. No slow server rendering.
    *   **Hosting**: Can be anywhere (cPanel, AWS S3, Cloudflare Pages).
    *   **Why**: Extremely fast, cheap, and secure.

2.  **Backend (The Brains) - `workers/`**:
    *   **Logic**: AI processing, Stripe Webhooks, Email dispatch.
    *   **Technology**: Cloudflare Workers (Edge Functions).
    *   **Role**: Runs your "complex" logic on thousands of servers worldwide, instead of one slow server.
    *   **Why**: Infinite scaling. If 100,000 students sign up tomorrow, it won't crash.

3.  **Database (The Memory) - Supabase**:
    *   **Data**: User profiles, notes, flashcards.
    *   **Auth**: Secure login/signup system.

---

## 🚀 Deployment Steps

### 1. Backend (The "Brains")
You must deploy your logic to the cloud so your frontend APIs work.

```bash
npm run deploy:all
```

**After running this, you must:**
1.  Copy the URL for the **AI Worker** (e.g., `https://thinklikelaw-ai.your-name.workers.dev`).
2.  Update `js/ai-service.js` with this new URL.
3.  Copy the URL for the **Stripe Worker** (e.g., `https://thinklikelaw-stripe.your-name.workers.dev`).
4.  Add this to your Stripe Dashboard Webhooks (pointing to `/api/webhook`).

### 2. Frontend (The "Face")
Upload the contents of `public_html_upload/` to your web host's `public_html` folder.

1.  Drag & Drop all files from `public_html_upload`.
2.  Your site is live! Use the `js/` files to talk to your Backend APIs.
