export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const stripe = require('stripe')(env.STRIPE_SECRET_KEY);

        // 1. Create Checkout Session
        if (url.pathname === '/api/create-checkout-session' && request.method === 'POST') {
            try {
                const { priceId, customerEmail } = await request.json();

                const session = await stripe.checkout.sessions.create({
                    customer_email: customerEmail,
                    payment_method_types: ['card'],
                    line_items: [{ price: priceId, quantity: 1 }],
                    mode: 'subscription',
                    success_url: `${env.APP_URL}/dashboard.html?session_id={CHECKOUT_SESSION_ID}`,
                    cancel_url: `${env.APP_URL}/index.html#pricing`,
                    allow_promotion_codes: true,
                    billing_address_collection: 'required',
                });

                return new Response(JSON.stringify({ id: session.id }), {
                    status: 200,
                    headers: { 'Content-Type': 'application/json' }
                });
            } catch (err) {
                return new Response(JSON.stringify({ error: err.message }), { status: 500 });
            }
        }

        // 2. Create Portal Session (Manage Subscription)
        if (url.pathname === '/api/create-portal-session' && request.method === 'POST') {
            try {
                const { customerId } = await request.json();
                const portalSession = await stripe.billingPortal.sessions.create({
                    customer: customerId,
                    return_url: `${env.APP_URL}/dashboard.html`,
                });

                return new Response(JSON.stringify({ url: portalSession.url }), {
                    status: 200,
                    headers: { 'Content-Type': 'application/json' }
                });
            } catch (err) {
                return new Response(JSON.stringify({ error: err.message }), { status: 500 });
            }
        }

        // 3. Webhook Handling (Secure)
        if (url.pathname === '/api/webhook' && request.method === 'POST') {
            const signature = request.headers.get('stripe-signature');
            const body = await request.text();

            try {
                const event = stripe.webhooks.constructEvent(
                    body,
                    signature,
                    env.STRIPE_WEBHOOK_SECRET
                );

                // Handle specific events
                switch (event.type) {
                    case 'checkout.session.completed':
                        const session = event.data.object;
                        await updateSupabaseProfile(session.customer_email, 'subscriber', session.customer, env);
                        break;
                    case 'customer.subscription.deleted':
                        const subscription = event.data.object;
                        // Get user by stripe customer ID and downgrade
                        await downgradeSupabaseProfile(subscription.customer, env);
                        break;
                    case 'customer.subscription.updated':
                        const subUpdated = event.data.object;
                        if (subUpdated.status === 'active') {
                            // Potentially update tier/cycle if changed
                        }
                        break;
                }

                return new Response(JSON.stringify({ received: true }), { status: 200 });
            } catch (err) {
                return new Response(JSON.stringify({ error: err.message }), { status: 400 });
            }
        }

        return new Response('Not Found', { status: 404 });
    }
};

// Helper to update Supabase via Service Role (Securely)
async function updateSupabaseProfile(email, tier, stripeId, env) {
    const { createClient } = require('@supabase/supabase-js');
    const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

    // 1. Update Profile
    await supabase
        .from('profiles')
        .update({
            tier: tier,
            stripe_customer_id: stripeId
        })
        .eq('email', email);

    // 2. Update Credits
    // Try to find the user ID from the profile first
    const { data: profile } = await supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .single();

    if (profile) {
        // We set to subscriber and attempt to detect cycle if possible (default monthly)
        // In a real setup, we'd check the Price ID from the session to set 'yearly' vs 'monthly'
        await supabase
            .from('user_credits')
            .upsert({
                user_id: profile.id,
                tier: tier,
                // billing_cycle would be set here if we had price mapping
                last_reset: new Date().toISOString()
            }, { onConflict: 'user_id' });
    }
}

async function downgradeSupabaseProfile(stripeId, env) {
    const { createClient } = require('@supabase/supabase-js');
    const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

    // 1. Update Profile
    const { data: profile } = await supabase
        .from('profiles')
        .update({ tier: 'free' })
        .eq('stripe_customer_id', stripeId)
        .select('id')
        .single();

    // 2. Update Credits
    if (profile) {
        await supabase
            .from('user_credits')
            .update({
                tier: 'free',
                billing_cycle: 'monthly'
            })
            .eq('user_id', profile.id);
    }
}
