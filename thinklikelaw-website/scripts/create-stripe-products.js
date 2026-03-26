const https = require('https');
const fs = require('fs');

const SECRET_KEY = process.env.STRIPE_SECRET_KEY || 'sk_test_placeholder'; // Use environment variable for security

// Helper to make Stripe API requests
function stripeRequest(method, path, data) {
    return new Promise((resolve, reject) => {
        const postData = new URLSearchParams(data).toString();
        const options = {
            hostname: 'api.stripe.com',
            port: 443,
            path: '/v1' + path,
            method: method,
            headers: {
                'Authorization': `Bearer ${SECRET_KEY}`,
                'Content-Type': 'application/x-www-form-urlencoded',
            }
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(body);
                    if (json.error) reject(json.error);
                    else resolve(json);
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', (e) => reject(e));
        if (data) req.write(postData);
        req.end();
    });
}

async function main() {
    console.log('Creating Stripe Products...');

    // 1. Create Product
    let productId;
    try {
        const product = await stripeRequest('POST', '/products', {
            name: 'ThinkLikeLaw Pro',
            description: 'Unlock AI tools, study organisation, and essay marking.',
            // images: ['https://thinklikelaw.com/images/logo.png'] // Optional
        });
        productId = product.id;
        console.log('Product Created:', productId);
    } catch (e) {
        console.error('Error creating product:', e.message);
        // Try to find existing? For now, fail or assume manual fix if key is restricted.
        return;
    }

    // 2. Define Tiers
    const tiers = [
        { name: 'Starter', month: 499, year: 5000 },  // 4.99 / 50.00
        { name: 'Standard', month: 999, year: 10000 }, // 9.99 / 100.00
        { name: 'Pro', month: 1499, year: 15000 },     // 14.99 / 150.00
        { name: 'Elite', month: 1999, year: 20000 },   // 19.99 / 200.00
        { name: 'Master', month: 2499, year: 25000 },  // 24.99 / 250.00
        { name: 'Legend', month: 2999, year: 30000 },  // 29.99 / 300.00
    ];

    const links = {};

    for (const tier of tiers) {
        console.log(`Processing Tier: ${tier.name}`);

        // MONTHLY
        try {
            const price = await stripeRequest('POST', '/prices', {
                product: productId,
                unit_amount: tier.month,
                currency: 'gbp',
                'recurring[interval]': 'month'
            });

            const link = await stripeRequest('POST', '/payment_links', {
                'line_items[0][price]': price.id,
                'line_items[0][quantity]': 1,
                'allow_promotion_codes': true,
                'after_completion[type]': 'redirect',
                'after_completion[redirect][url]': 'https://thinklikelaw.com/dashboard.html?upgrade=success'
            });

            links[`monthly_${tier.month}`] = link.url;
            console.log(`  -> Monthly Link: ${link.url}`);

        } catch (e) {
            console.error(`  -> Error Monthly: ${e.message}`);
        }

        // YEARLY
        try {
            const price = await stripeRequest('POST', '/prices', {
                product: productId,
                unit_amount: tier.year,
                currency: 'gbp',
                'recurring[interval]': 'year'
            });

            const link = await stripeRequest('POST', '/payment_links', {
                'line_items[0][price]': price.id,
                'line_items[0][quantity]': 1,
                'allow_promotion_codes': true,
                'after_completion[type]': 'redirect',
                'after_completion[redirect][url]': 'https://thinklikelaw.com/dashboard.html?upgrade=success'
            });

            links[`yearly_${tier.year}`] = link.url;
            console.log(`  -> Yearly Link: ${link.url}`);

        } catch (e) {
            console.error(`  -> Error Yearly: ${e.message}`);
        }
    }

    // Save to file
    fs.writeFileSync('js/stripe_links.json', JSON.stringify(links, null, 2));
    console.log('Saved links to js/stripe_links.json');
}

main();
