
// Branded Payment Modal — ThinkLikeLaw
// Premium upgrade experience with branding and plan comparison

const PaymentModal = {
    // Stripe Payment Links
    links: {
        'monthly_499': 'https://buy.stripe.com/28EeVd6xH5sx5Ix0LvfjG01',
        'monthly_799': 'https://buy.stripe.com/cNi7sLg8h8EJ6MB0LvfjG00',
        'monthly_1499': 'https://buy.stripe.com/eVq5kDcW53kp2wl8dXfjG02',
        'monthly_1999': 'https://buy.stripe.com/4gM5kD7BL4otdaZdyhfjG03',
        'monthly_2999': 'https://buy.stripe.com/cNi14n2hrdZ39YNdyhfjG04',
        'yearly_5000': 'https://buy.stripe.com/6oU4gz5tDbQV4Et9i1fjG05',
        'yearly_8000': 'https://buy.stripe.com/cNieVd09j1chef379TfjG06',
        'yearly_15000': 'https://buy.stripe.com/dRm9AT1dn1ch2wlam5fjG07',
        'yearly_20000': 'https://buy.stripe.com/9B6eVd7BLdZ31sh1PzfjG08',
        'yearly_30000': 'https://buy.stripe.com/8x2fZh2hr08d7QF65PfjG09'
    },

    currentPlan: 'monthly',
    currentTier: '999', // Default to Standard (~£10)

    inject() {
        if (document.getElementById('payment-modal')) return;

        const modalHTML = `
        <div class="modal-overlay" id="payment-modal" style="z-index: 6000;">
            <div style="
                background: #0A0A0A;
                border: 1px solid rgba(255,255,255,0.08);
                border-radius: 20px;
                max-width: 560px; /* Increased Max Width */
                width: 92%;
                padding: 0;
                overflow: hidden;
                box-shadow: 0 30px 80px rgba(0,0,0,0.6);
                position: relative;
            ">
                <!-- Close -->
                <button onclick="PaymentModal.close()" style="
                    position: absolute; top: 1.5rem; right: 1.5rem;
                    background: none; border: none; color: #666;
                    font-size: 1.2rem; cursor: pointer; z-index: 2;
                    padding: 0.5rem; border-radius: 6px; transition: all 0.2s;
                " onmouseover="this.style.color='#FFF'" onmouseout="this.style.color='#666'">
                    <i class="fas fa-times"></i>
                </button>

                <!-- Header -->
                <div style="
                    padding: 3.5rem 3rem 2rem; /* Increased Padding */
                    text-align: center;
                    border-bottom: 1px solid rgba(255,255,255,0.06);
                ">
                    <img src="images/logo.png" alt="ThinkLikeLaw" style="height: 48px; margin-bottom: 1.5rem; opacity: 0.9;">
                    <h2 style="
                        font-family: 'Playfair Display', Georgia, serif;
                        font-size: 2rem; /* Larger Font */
                        font-weight: 600;
                        color: #FFF;
                        margin-bottom: 0.75rem;
                    ">Join the Inner Circle</h2>
                    <p style="color: #999; font-size: 1.05rem; line-height: 1.7; max-width: 80%; margin: 0 auto;">
                        Choose a contribution level that suits you.<br>All tiers unlock full access to ThinkLikeLaw Pro.
                    </p>
                </div>

                <!-- Plan Toggle -->
                <div style="padding: 1.5rem 2.5rem 0;">
                    <div id="plan-toggle" style="
                        display: flex; background: rgba(255,255,255,0.04);
                        border-radius: 10px; padding: 4px; margin-bottom: 1.5rem;
                        border: 1px solid rgba(255,255,255,0.06);
                    ">
                        <button data-plan="monthly" class="plan-toggle-btn active" style="
                            flex: 1; padding: 0.6rem; border: none; border-radius: 8px;
                            background: rgba(255,255,255,0.08); color: #FFF;
                            font-weight: 600; font-size: 0.85rem; cursor: pointer;
                            transition: all 0.3s;
                        ">Monthly</button>
                        <button data-plan="annual" class="plan-toggle-btn" style="
                            flex: 1; padding: 0.6rem; border: none; border-radius: 8px;
                            background: transparent; color: #888;
                            font-weight: 600; font-size: 0.85rem; cursor: pointer;
                            transition: all 0.3s;
                        ">Annual <span style="color:#4CAF50;font-size:0.75rem;margin-left:4px">2 Months Free</span></button>
                    </div>

                    <!-- Slider Section -->
                    <div style="margin-bottom: 2rem;">
                        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem">
                            <label style="color:#AAA;font-size:0.9rem">Your Contribution:</label>
                            <div id="price-display" style="font-size:1.5rem;font-weight:700;color:#FFF">£9.99<span style="font-size:0.9rem;color:#666;font-weight:400">/mo</span></div>
                        </div>
                        
                        <input type="range" id="pricing-slider" min="0" max="5" value="1" step="1" style="
                            width: 100%; -webkit-appearance: none; background: rgba(255,255,255,0.1);
                            height: 6px; border-radius: 3px; outline: none; margin-bottom: 0.5rem; cursor: pointer;
                        ">
                        <div style="display:flex;justify-content:space-between;color:#555;font-size:0.75rem;padding:0 2px">
                            <span>Starter</span>
                            <span>Standard</span>
                            <span>Pro</span>
                            <span>Elite</span>
                            <span>Master</span>
                            <span>Legend</span>
                        </div>
                    </div>

                    <!-- Features -->
                    <div style="margin-bottom: 1.5rem;">
                        <div style="display:flex;align-items:center;gap:0.65rem;padding:0.55rem 0;color:#CCC;font-size:0.9rem;border-bottom:1px solid rgba(255,255,255,0.04);">
                            <i class="fas fa-check" style="color:#4CAF50;font-size:0.75rem;width:16px"></i>
                            Full Module Access — unlimited modules & lectures
                        </div>
                        <div style="display:flex;align-items:center;gap:0.65rem;padding:0.55rem 0;color:#CCC;font-size:0.9rem;border-bottom:1px solid rgba(255,255,255,0.04);">
                            <i class="fas fa-check" style="color:#4CAF50;font-size:0.75rem;width:16px"></i>
                            All AI Tools Unlocked — Interpret, Essays, Flashcards
                        </div>
                        <div style="display:flex;align-items:center;gap:0.65rem;padding:0.55rem 0;color:#CCC;font-size:0.9rem;border-bottom:1px solid rgba(255,255,255,0.04);">
                            <i class="fas fa-bolt" style="color:#F5A623;font-size:0.75rem;width:16px"></i>
                            <span id="credits-display">10,000 AI Credits / month</span>
                        </div>
                        <div style="display:flex;align-items:center;gap:0.65rem;padding:0.55rem 0;color:#CCC;font-size:0.9rem;border-bottom:1px solid rgba(255,255,255,0.04); display: none;" id="rollover-benefit">
                            <i class="fas fa-sync" style="color:#2196F3;font-size:0.75rem;width:16px"></i>
                            <span style="color:#FFF;font-weight:600">Yearly Benefit:</span> Monthly credits roll over if unused
                        </div>
                        <div style="display:flex;align-items:center;gap:0.65rem;padding:0.55rem 0;color:#CCC;font-size:0.9rem;">
                            <i class="fas fa-heart" style="color:#E91E63;font-size:0.75rem;width:16px"></i>
                            Support Independent Education
                        </div>
                    </div>
                </div>

                <!-- Submit Action -->
                <div style="padding: 0 2.5rem 2rem;">
                    <button id="pm-submit" onclick="PaymentModal.process()" style="
                        width: 100%; padding: 0.9rem; background: #FFF; color: #000;
                        border: none; border-radius: 10px; font-weight: 700;
                        font-size: 0.95rem; cursor: pointer; transition: all 0.3s;
                        display: flex; align-items: center; justify-content: center; gap: 0.5rem;
                    " onmouseover="this.style.transform='translateY(-1px)';this.style.boxShadow='0 8px 25px rgba(255,255,255,0.15)'"
                       onmouseout="this.style.transform='';this.style.boxShadow=''">
                        Subscribe Now
                    </button>

                    <div style="text-align:center;margin-top:1rem;display:flex;align-items:center;justify-content:center;gap:0.5rem;color:#555;font-size:0.78rem">
                        <i class="fas fa-lock"></i>
                        Processed securely by Stripe · Cancel anytime
                    </div>
                </div>
            </div>
        </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHTML);

        // Event Listeners
        this.attachListeners();
    },

    attachListeners() {
        // Toggle Plan
        document.querySelectorAll('.plan-toggle-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchPlan(e.target.dataset.plan || e.target.parentElement.dataset.plan);
            });
        });

        // Slider
        const slider = document.getElementById('pricing-slider');
        if (slider) {
            slider.addEventListener('input', (e) => {
                this.updatePrice(parseInt(e.target.value));
            });
        }
    },

    switchPlan(plan) {
        this.currentPlan = plan;

        // Update UI Tabs
        document.querySelectorAll('.plan-toggle-btn').forEach(btn => {
            btn.classList.remove('active');
            btn.style.background = 'transparent';
            btn.style.color = '#888';
        });

        const activeBtn = document.querySelector(`.plan-toggle-btn[data-plan="${plan}"]`);
        if (activeBtn) {
            activeBtn.classList.add('active');
            activeBtn.style.background = 'rgba(255,255,255,0.08)';
            activeBtn.style.color = '#FFF';
        }

        // Trigger update to refresh price display
        const slider = document.getElementById('pricing-slider');
        this.updatePrice(parseInt(slider.value));
    },

    updatePrice(sliderValue) {
        const tiers = [
            { val: 499, label: '£4.99' },
            { val: 999, label: '£9.99' },
            { val: 1499, label: '£14.99' },
            { val: 1999, label: '£19.99' },
            { val: 2499, label: '£24.99' },
            { val: 2999, label: '£29.99' }
        ];

        const tier = tiers[sliderValue];
        this.currentTier = tier.val;

        // Calculate display price based on Plan (Monthly/Annual)
        const displayLabel = document.getElementById('price-display');
        const creditsLabel = document.getElementById('credits-display');

        if (this.currentPlan === 'monthly') {
            displayLabel.innerHTML = `${tier.label}<span style="font-size:0.9rem;color:#666;font-weight:400">/mo</span>`;
        } else {
            // Approx 10x for yearly
            const yearPrice = (tier.val * 10 / 100).toFixed(2); // e.g. 49.90 -> 50 approx logic from script was exact
            // Let's use the exact map from script logic: 5000, 10000 etc.
            // Script used: 5000, 10000, 15000, 20000, 25000, 30000
            // Display: £50.00, £100.00 etc
            const yearDisplay = (tier.val * 10 / 100 + 0.10).toFixed(0); // Hacky approximation visually or just mapping?
            // Better mapping:
            const yearMap = ['£50', '£100', '£150', '£200', '£250', '£300'];
            displayLabel.innerHTML = `${yearMap[sliderValue]}<span style="font-size:0.9rem;color:#666;font-weight:400">/yr</span>`;
        }

        // Update Credits/Perks based on value?
        const credits = [10000, 25000, 50000, 100000, 'Unlimited', 'Unlimited'];
        creditsLabel.textContent = `${credits[sliderValue].toLocaleString()} AI Credits / month`;

        // Toggle Rollover Benefit Display
        const rollover = document.getElementById('rollover-benefit');
        if (rollover) {
            rollover.style.display = (this.currentPlan === 'annual') ? 'flex' : 'none';
        }
    },

    open(onSuccess) {
        this.inject();
        this.onSuccess = onSuccess;
        const modal = document.getElementById('payment-modal');
        modal.style.display = 'flex';
        modal.style.alignItems = 'center';
        modal.style.justifyContent = 'center';
        setTimeout(() => modal.classList.add('active'), 10);
    },

    close() {
        const modal = document.getElementById('payment-modal');
        if (modal) {
            modal.classList.remove('active');
            setTimeout(() => modal.style.display = 'none', 300);
        }
    },

    process() {
        const btn = document.getElementById('pm-submit');
        const originalContent = btn.innerHTML;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Redirecting to Stripe...';
        btn.disabled = true;
        btn.style.opacity = '0.7';

        // Construct Key
        // keys in map: monthly_499, yearly_5000
        let key = '';
        if (this.currentPlan === 'monthly') {
            key = `monthly_${this.currentTier}`;
        } else {
            // Tier is 499 -> 5000, 999 -> 10000. 
            // Formula: tier * 10 approx? 
            // Script logic: 499->5000 (+1?). 
            // Let's retry mapping exactly to array index
            // Tiers array indices 0-5 match the script Tiers
            const yearValues = [5000, 10000, 15000, 20000, 25000, 30000];
            // Recover index from currentTier logic? Or just store index.
            // Let's store index in currentPriceIndex
            const slider = document.getElementById('pricing-slider');
            const idx = parseInt(slider.value);
            key = `yearly_${yearValues[idx]}`;
        }

        const url = this.links[key];

        if (url) {
            // Redirect
            setTimeout(() => {
                window.location.href = url;
            }, 800);
        } else {
            alert('Error: Payment link not found for this tier.');
            btn.innerHTML = originalContent;
            btn.disabled = false;
        }
    }
};

window.PaymentModal = PaymentModal;
