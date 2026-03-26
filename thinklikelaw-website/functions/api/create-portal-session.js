/**
 * Cloudflare Pages Function: POST /api/create-portal-session
 *
 * Opens the Stripe Customer Portal so subscribers can manage
 * or cancel their subscription.
 *
 * Body: { customerId: string }
 * Returns: { url: string }
 *
 * Secrets (Pages → Settings → Environment Variables):
 *   STRIPE_SECRET_KEY
 *   APP_URL
 */

function corsHeaders(origin) {
    return {
        'Access-Control-Allow-Origin': origin || '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
    };
}

function json(data, status = 200, origin = '*') {
    return new Response(JSON.stringify(data), {
        status,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(origin) },
    });
}

export async function onRequestOptions() {
    return new Response(null, { status: 204, headers: corsHeaders('*') });
}

export async function onRequestPost({ request, env }) {
    const origin = request.headers.get('Origin') || '*';

    try {
        const { customerId } = await request.json();
        if (!customerId) return json({ error: 'customerId is required' }, 400, origin);

        const APP_URL = env.APP_URL || 'https://www.thinklikelaw.com';

        const res = await fetch('https://api.stripe.com/v1/billing_portal/sessions', {
            method: 'POST',
            headers: {
                Authorization: `Bearer ${env.STRIPE_SECRET_KEY}`,
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
                customer: customerId,
                return_url: `${APP_URL}/dashboard.html`,
            }),
        });

        const session = await res.json();
        if (!res.ok) throw new Error(session.error?.message || `Stripe error ${res.status}`);

        return json({ url: session.url }, 200, origin);
    } catch (err) {
        console.error('[portal] Error:', err);
        return json({ error: err.message }, 500, origin);
    }
}
