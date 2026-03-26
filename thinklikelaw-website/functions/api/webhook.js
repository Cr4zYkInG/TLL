/**
 * Cloudflare Pages Function: POST /api/webhook
 *
 * Handles Stripe webhook events fired by Payment Links.
 * Stores stripe_customer_id + tier in Supabase so the
 * "Manage Billing" button can open the Customer Portal.
 *
 * Events handled:
 *   checkout.session.completed   → save stripe_customer_id, set tier = 'subscriber'
 *   customer.subscription.deleted → set tier = 'free', clear customer id
 *
 * Secrets (Cloudflare Pages → Settings → Environment Variables):
 *   STRIPE_WEBHOOK_SECRET
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 */

// ─── HMAC-SHA256 Webhook Signature Verification ───────────────────────────────

async function verifyStripeSignature(payload, sigHeader, secret) {
    if (!sigHeader || !secret) throw new Error('Missing signature or secret');

    const timestamp = sigHeader.split(',').find(p => p.startsWith('t='))?.slice(2);
    const expectedSig = sigHeader.split(',').find(p => p.startsWith('v1='))?.slice(3);

    if (!timestamp || !expectedSig) throw new Error('Malformed Stripe-Signature header');

    // Reject webhooks older than 5 minutes
    if (Math.abs(Date.now() / 1000 - parseInt(timestamp, 10)) > 300) {
        throw new Error('Webhook timestamp too old');
    }

    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
        'raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
    );
    const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${payload}`));
    const computed = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');

    if (computed !== expectedSig) throw new Error('Stripe signature mismatch');
}

// ─── Supabase REST Helper ─────────────────────────────────────────────────────

async function sb(env, method, path, body = null) {
    const res = await fetch(`${env.SUPABASE_URL}/rest/v1${path}`, {
        method,
        headers: {
            apikey: env.SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
            Prefer: 'return=representation',
        },
        body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    if (!res.ok) {
        console.error(`Supabase ${method} ${path} → ${res.status}:`, text);
        throw new Error(`Supabase ${res.status}: ${text}`);
    }
    return text ? JSON.parse(text) : null;
}

// ─── Event Handlers ───────────────────────────────────────────────────────────

async function onCheckoutComplete(session, env) {
    const email = session.customer_details?.email || session.customer_email;
    const stripeCustomerId = session.customer;

    if (!email || !stripeCustomerId) {
        console.warn('[webhook] Missing email or customer on session', session.id);
        return;
    }

    // Find profile by email
    const profiles = await sb(env, 'GET',
        `/profiles?email=eq.${encodeURIComponent(email)}&select=id`);
    const userId = Array.isArray(profiles) && profiles[0]?.id;
    if (!userId) {
        console.warn('[webhook] No profile found for', email);
        return;
    }

    // Save stripe_customer_id and mark as subscriber
    await sb(env, 'PATCH', `/profiles?id=eq.${userId}`, {
        tier: 'subscriber',
        stripe_customer_id: stripeCustomerId,
        updated_at: new Date().toISOString(),
    });

    console.log(`[webhook] ✅ Saved stripe_customer_id for ${email}`);
}

async function onSubscriptionDeleted(subscription, env) {
    const stripeCustomerId = subscription.customer;

    const profiles = await sb(env, 'GET',
        `/profiles?stripe_customer_id=eq.${stripeCustomerId}&select=id`);
    const userId = Array.isArray(profiles) && profiles[0]?.id;
    if (!userId) return;

    await sb(env, 'PATCH', `/profiles?id=eq.${userId}`, {
        tier: 'free',
        updated_at: new Date().toISOString(),
    });

    console.log(`[webhook] ⬇️  Downgraded customer ${stripeCustomerId} to free`);
}

// ─── Handler ──────────────────────────────────────────────────────────────────

export async function onRequestOptions() {
    return new Response(null, { status: 204 });
}

export async function onRequestPost({ request, env }) {
    const body = await request.text();
    const sig = request.headers.get('stripe-signature');

    try {
        await verifyStripeSignature(body, sig, env.STRIPE_WEBHOOK_SECRET);
    } catch (err) {
        console.error('[webhook] Signature failed:', err.message);
        return new Response(JSON.stringify({ error: err.message }), {
            status: 400,
            headers: { 'Content-Type': 'application/json' },
        });
    }

    let event;
    try { event = JSON.parse(body); }
    catch { return new Response('Bad JSON', { status: 400 }); }

    console.log(`[webhook] 📬 ${event.type}`);

    try {
        switch (event.type) {
            case 'checkout.session.completed':
                await onCheckoutComplete(event.data.object, env);
                break;
            case 'customer.subscription.deleted':
                await onSubscriptionDeleted(event.data.object, env);
                break;
            default:
                // Ignore other events
                break;
        }
    } catch (err) {
        // Log but return 200 — don't let Stripe retry unnecessarily
        console.error(`[webhook] Handler error for ${event.type}:`, err);
    }

    return new Response(JSON.stringify({ received: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
    });
}
