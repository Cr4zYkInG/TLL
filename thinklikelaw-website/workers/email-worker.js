export default {
  async fetch(request, env) {
    // CORS headers to allow requests from your frontend
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    // Handle OPTIONS request for CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers: corsHeaders });
    }

    try {
      const body = await request.json();
      const { email, firstName, type, newsletterConsent } = body;

      if (!email) {
        return new Response("Email is required", { status: 400, headers: corsHeaders });
      }

      // Resend API Configuration
      const resendUrl = "https://api.resend.com/emails";
      const resendApiKey = env.RESEND_API_KEY;

      let subject = "Welcome to ThinkLikeLaw"; // Default subject
      let htmlContent = "";

      const baseStyles = `
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700&family=Inter:wght@400;500;600&display=swap');
        body { margin: 0; padding: 0; background-color: #050505; font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; -webkit-font-smoothing: antialiased; }
        .wrapper { width: 100%; background-color: #050505; padding: 40px 0; }
        .container { max-width: 600px; margin: 0 auto; background-color: #0F0F0F; border-radius: 16px; border: 1px solid #222; overflow: hidden; box-shadow: 0 10px 40px rgba(0,0,0,0.4); }
        .header { background: linear-gradient(180deg, #151515 0%, #0F0F0F 100%); padding: 40px; text-align: center; border-bottom: 1px solid #222; }
        .logo { height: 40px; width: auto; }
        .content { padding: 40px; color: #CCCCCC; line-height: 1.7; font-size: 16px; }
        .h1 { color: #FFFFFF; font-family: 'Playfair Display', serif; font-size: 32px; font-weight: 700; margin: 0 0 20px 0; letter-spacing: -0.5px; }
        .text { margin-bottom: 24px; color: #A0A0A0; }
        .highlight { color: #FFFFFF; font-weight: 600; }
        .feature-box { background: #1A1A1A; border: 1px solid #333; border-radius: 12px; padding: 20px; margin: 30px 0; }
        .feature-item { display: flex; align-items: center; margin-bottom: 12px; color: #DDD; font-size: 15px; }
        .feature-item:last-child { margin-bottom: 0; }
        .dot { height: 8px; width: 8px; background-color: #C5A059; border-radius: 50%; margin-right: 12px; display: inline-block; }
        .btn-container { text-align: center; margin-top: 35px; }
        .btn { display: inline-block; background: linear-gradient(135deg, #C5A059 0%, #AA8540 100%); color: #000000; padding: 16px 36px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; transition: opacity 0.2s; letter-spacing: 0.5px; box-shadow: 0 4px 15px rgba(197, 160, 89, 0.2); }
        .footer { background-color: #0A0A0A; padding: 30px; text-align: center; font-size: 13px; color: #555; border-top: 1px solid #1A1A1A; }
        .footer-link { color: #777; text-decoration: none; margin: 0 8px; }
      `;

      switch (type) {
        case 'subscribe':
          subject = "Membership Confirmed | ThinkLikeLaw";
          htmlContent = `
            <h1 class="h1">Welcome to the Inner Circle${firstName ? `, ${firstName}` : ''}.</h1>
            <p class="text">Your subscription is now active. You have unlocked the full arsenal of ThinkLikeLaw's AI-powered tools, designed to give you the edge in your legal studies.</p>
            
            <div class="feature-box">
              <div class="feature-item"><span class="dot"></span>Unlimited Case Summaries</div>
              <div class="feature-item"><span class="dot"></span>Advanced AI Essay Analysis</div>
              <div class="feature-item"><span class="dot"></span>Priority Feature Access</div>
              <div class="feature-item"><span class="dot"></span>Exclusive Study Resources</div>
            </div>

            <p class="text">You are now part of a community dedicated to mastering the art of legal reasoning. Make the most of it.</p>
            
            <div class="btn-container">
              <a href="https://www.thinklikelaw.com/dashboard.html" class="btn">Access Your Dashboard</a>
            </div>
          `;
          break;

        case 'upgrade': // Out of credits
          subject = "Credit Limit Reached | ThinkLikeLaw";
          htmlContent = `
            <h1 class="h1">Your Briefing Room is Paused.</h1>
            <p class="text">You have utilized all your monthly AI credits. To strictly maintain the quality of our service, access to AI tools is currently paused for your account.</p>
            
            <p class="text" style="color: #FFF;">Don't let your momentum stall.</p>
            <p class="text">Upgrade to Pro today for <span class="highlight">50,000 monthly credits</span> and unlimited access to all features.</p>
            
            <div class="btn-container">
              <a href="https://www.thinklikelaw.com/dashboard.html#upgrade" class="btn">Restore Full Access</a>
            </div>
          `;
          break;

        case 'welcome':
        default:
          htmlContent = `
            <h1 class="h1">Welcome to the Cohort${firstName ? `, ${firstName}` : ''}.</h1>
            <p class="text">You have successfully secured your place at ThinkLikeLaw. Your digital briefing room is now ready.</p>
            <p class="text">We have designed this platform to help you think like a lawyer, not just write like one. Here is what you can start with immediately:</p>
            
            <div class="feature-box">
              <div class="feature-item"><span class="dot"></span><strong>Contract Law:</strong> Offer, Acceptance, Consideration</div>
              <div class="feature-item"><span class="dot"></span><strong>Tort Law:</strong> Negligence, Duty of Care</div>
              <div class="feature-item"><span class="dot"></span><strong>Flashcards:</strong> Spaced Repetition System</div>
            </div>
            
            <div class="btn-container">
              <a href="https://www.thinklikelaw.com/login.html" class="btn">Enter The Portal</a>
            </div>
          `;
          break;
      }

      const emailData = {
        from: "ThinkLikeLaw <onboarding@thinklikelaw.com>",
        to: email,
        subject: subject,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>${baseStyles}</style>
          </head>
          <body>
            <div class="wrapper">
              <div class="container">
                <div class="header">
                   <!-- Logo Image -->
                   <img src="https://www.thinklikelaw.com/images/logo.png" alt="ThinkLikeLaw" class="logo" style="display: block; margin: 0 auto; max-height: 40px; border: 0; outline: none; text-decoration: none;">
                </div>
                <div class="content">
                  ${htmlContent}
                </div>
                <div class="footer">
                  <p>&copy; 2026 ThinkLikeLaw Ltd. All rights reserved.</p>
                  <p style="margin-top: 10px;">
                    <a href="https://www.thinklikelaw.com/privacy-policy.html" class="footer-link">Privacy</a> • 
                    <a href="https://www.thinklikelaw.com/terms.html" class="footer-link">Terms</a>
                  </p>
                </div>
              </div>
            </div>
          </body>
          </html>
        `,
      };

      const response = await fetch(resendUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${resendApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(emailData),
      });

      const data = await response.json();

      // NEW: Add to Resend Audience (Newsletter) if this is a welcome email AND user consented
      if (type === 'welcome' && newsletterConsent !== false && env.RESEND_AUDIENCE_ID) {
        try {
          await addContactToAudience(email, firstName, env);
        } catch (audError) {
          console.error("Audience add failed:", audError);
          // Don't fail the whole request if just the audience add fails
        }
      }

      return new Response(JSON.stringify(data), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });

    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
};

/**
 * Adds a contact to a Resend Audience
 */
async function addContactToAudience(email, firstName, env) {
  const audienceUrl = `https://api.resend.com/audiences/${env.RESEND_AUDIENCE_ID}/contacts`;

  const response = await fetch(audienceUrl, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: email,
      firstName: firstName || "",
      unsubscribed: false
    }),
  });

  if (!response.ok) {
    const errorData = await response.text();
    throw new Error(`Resend Audience API error: ${errorData}`);
  }

  return await response.json();
}
