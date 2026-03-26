// Settings, Promo Codes & Upgrade Logic

// 1. Promo Code System

async function redeemPromoCode() {
    const input = document.getElementById('settings-promo-input');
    const msg = document.getElementById('promo-message');
    if (!input || !msg) return;

    const code = input.value.trim().toUpperCase();

    // Reset state
    msg.style.display = 'block';
    msg.style.color = 'var(--text-secondary)';
    msg.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Verifying...';
    input.style.borderColor = 'var(--border-color)';

    if (!code) {
        msg.textContent = 'Please enter a code.';
        return;
    }

    try {
        if (typeof CloudData === 'undefined') throw new Error('Cloud storage unavailable.');

        const result = await CloudData.redeemPromoCode(code);

        // Success State
        msg.style.color = '#4CAF50';
        input.style.borderColor = '#4CAF50';

        let successMsg = 'Code applied successfully!';
        if (result.credits) successMsg = `Success! Added ${result.credits.toLocaleString()} credits to your account.`;
        if (result.tier === 'subscriber') successMsg = `Success! You are now a Pro Subscriber.`;

        msg.innerHTML = `<i class="fas fa-check-circle"></i> ${successMsg}`;

        // Refresh local displays if they exist
        if (typeof creditsManager !== 'undefined') {
            creditsManager.init(); // Refresh credits and tier
        }

        // Optional: clear input on success
        input.value = '';

    } catch (error) {
        msg.style.color = '#ff5555';
        msg.innerHTML = `<i class="fas fa-times-circle"></i> ${error.message}`;
        input.style.borderColor = '#ff5555';
    }
}


// 2. Settings Subscription Logic

const PLAN_TIERS = {
    monthly: [
        { key: 'monthly_499', label: 'Starter', price: '£4.99', period: '/mo', credits: '10,000', popular: false },
        { key: 'monthly_799', label: 'Student', price: '£7.99', period: '/mo', credits: '25,000', popular: true },
        { key: 'monthly_1499', label: 'Pro', price: '£14.99', period: '/mo', credits: '50,000', popular: false },
        { key: 'monthly_1999', label: 'Elite', price: '£19.99', period: '/mo', credits: '100,000', popular: false },
        { key: 'monthly_2999', label: 'Legend', price: '£29.99', period: '/mo', credits: 'Unlimited', popular: false },
    ],
    annual: [
        { key: 'yearly_5000', label: 'Starter', price: '£50', period: '/yr', credits: '10,000', popular: false, saving: 'Save £10' },
        { key: 'yearly_8000', label: 'Student', price: '£80', period: '/yr', credits: '25,000', popular: true, saving: 'Save £16' },
        { key: 'yearly_15000', label: 'Pro', price: '£150', period: '/yr', credits: '50,000', popular: false, saving: 'Save £30' },
        { key: 'yearly_20000', label: 'Elite', price: '£200', period: '/yr', credits: '100,000', popular: false, saving: 'Save £40' },
        { key: 'yearly_30000', label: 'Legend', price: '£300', period: '/yr', credits: 'Unlimited', popular: false, saving: 'Save £60' },
    ]
};

let settingsPlan = 'monthly';
let selectedPlanKey = 'monthly_799';

function switchSettingsPlan(plan) {
    settingsPlan = plan;
    const monthlyBtn = document.getElementById('billing-monthly');
    const annualBtn = document.getElementById('billing-annual');

    if (monthlyBtn) monthlyBtn.classList.toggle('active', plan === 'monthly');
    if (annualBtn) annualBtn.classList.toggle('active', plan === 'annual');

    // Also update the selected key to same tier if possible
    const oldTier = selectedPlanKey.split('_')[1];
    const tiers = PLAN_TIERS[plan];
    const match = tiers.find(t => t.key.includes(oldTier)) || tiers[1];
    selectedPlanKey = match.key;

    renderPlanCards();
}

function renderPlanCards() {
    const grid = document.getElementById('plan-cards-grid');
    if (!grid) return;

    const tiers = PLAN_TIERS[settingsPlan];
    grid.innerHTML = tiers.map(tier => `
        <button class="plan-card ${tier.key === selectedPlanKey ? 'selected' : ''}" onclick="selectPlanCard('${tier.key}')">
            ${tier.popular ? '<span class="pc-popular">Popular</span>' : ''}
            <span class="pc-name">${tier.label}</span>
            <span class="pc-price">${tier.price}</span>
            <span class="pc-period">${tier.period}</span>
            <span class="pc-credits"><i class="fas fa-bolt" style="color:#F5A623; font-size:0.75em;"></i> ${tier.credits} credits</span>
            ${tier.saving ? `<span style="font-size:0.75rem; color:#4CAF50; font-weight:700;">${tier.saving}</span>` : ''}
        </button>
    `).join('');

    updateSubCTA();
}

function selectPlanCard(key) {
    selectedPlanKey = key;
    renderPlanCards();
}

function updateSubCTA() {
    // Find the sub CTA button if it exists separately. The subscribe button is injected inside the tab.
    const btn = document.getElementById('settings-subscribe-btn');
    if (!btn) return;
    const allTiers = [...PLAN_TIERS.monthly, ...PLAN_TIERS.annual];
    const tier = allTiers.find(t => t.key === selectedPlanKey);
    if (tier) btn.innerHTML = `Subscribe — ${tier.price} ${tier.period} <i class="fas fa-arrow-right"></i>`;
}

async function populateCurrentPlanBanner() {
    const nameEl = document.getElementById('cpb-name');
    const creditsEl = document.getElementById('cpb-credits-val');
    if (!nameEl || !creditsEl) return;

    try {
        if (typeof creditsManager !== 'undefined') {
            credits = creditsManager.getCredits();
            tier = creditsManager.getUserTier();
        } else if (typeof CloudData !== 'undefined') {
            const data = await CloudData.getCredits();
            if (data) {
                credits = data.credits;
                tier = data.tier;
            }
        }

        const tierLabel = tier === 'free' ? 'Free Plan' :
            tier === 'subscriber' ? 'Pro Subscriber' : tier;
        nameEl.textContent = tierLabel;
        creditsEl.textContent = credits.toLocaleString();

        // Highlight icon if pro
        const icon = document.querySelector('.cpb-icon');
        if (icon) icon.style.color = tier === 'free' ? '#999' : '#4CAF50';

        // Show manage billing section only for subscribers
        const manageBillingSection = document.getElementById('manage-billing-section');
        if (manageBillingSection) {
            manageBillingSection.style.display = tier === 'subscriber' ? 'block' : 'none';
        }
    } catch (e) {
        console.warn('Could not load current plan:', e);
    }
}

/**
 * Opens the Stripe Customer Portal so the subscriber can manage
 * payment methods, view invoices, or cancel their subscription.
 */
async function openBillingPortal() {
    const btn = document.getElementById('manage-billing-btn');
    if (btn) {
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Opening...';
        btn.disabled = true;
    }

    try {
        // Get stripe_customer_id from Supabase profile
        let customerId = localStorage.getItem('stripeCustomerId');

        if (!customerId && typeof CloudData !== 'undefined') {
            const profile = await CloudData.getProfile();
            customerId = profile?.stripe_customer_id;
            if (customerId) localStorage.setItem('stripeCustomerId', customerId);
        }

        if (!customerId) {
            // Fallback to the hosted portal login link provided by the user
            window.open('https://billing.stripe.com/p/login/cNi7sLg8h8EJ6MB0LvfjG00', '_blank');
            return;
        }

        const res = await fetch('/api/create-portal-session', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ customerId }),
        });

        const data = await res.json();
        if (data.error) throw new Error(data.error);
        if (data.url) window.location.href = data.url;

    } catch (err) {
        console.error('[BillingPortal]', err);
        alert('Could not open billing portal. Please try again or contact support@thinklikelaw.com.');
    } finally {
        if (btn) {
            btn.innerHTML = '<i class="fas fa-arrow-up-right-from-square"></i> Manage Billing';
            btn.disabled = false;
        }
    }
}

window.openBillingPortal = openBillingPortal;

function processSettingsSubscription() {
    if (typeof PaymentModal === 'undefined' || !PaymentModal.links) {
        alert('Payment system initializing... please try again in a moment.');
        return;
    }

    const url = PaymentModal.links[selectedPlanKey];
    if (url) {
        const btn = document.getElementById('settings-subscribe-btn');
        if (btn) {
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Redirecting...';
            btn.disabled = true;
        }
        setTimeout(() => window.location.href = url, 600);
    } else {
        // Fallback: guess a nearby key
        alert('This plan link is not yet configured. Please contact support or try another plan.');
    }
}

// Legacy stubs for backward compat (safe to leave)
function updateSettingsPrice() { }

// Expose globals
window.switchSettingsPlan = switchSettingsPlan;
window.updateSettingsPrice = updateSettingsPrice;
window.processSettingsSubscription = processSettingsSubscription;
window.selectPlanCard = selectPlanCard;
window.renderPlanCards = renderPlanCards;
window.populateCurrentPlanBanner = populateCurrentPlanBanner;
window.redeemPromoCode = redeemPromoCode;


// 3. Profile Management (Server-Side Sync)

// 3. Profile Management (CloudData Sync)

async function saveSettings() {
    const btn = document.querySelector('#settings-tab-account .btn-primary');
    const originalText = btn.textContent;

    // Gather Data
    const fullName = document.getElementById('settings-name').value.trim();
    const lawSchool = document.getElementById('settings-school').value.trim();
    const gradYear = document.getElementById('settings-year').value.trim();
    const leaderboardName = document.getElementById('settings-leaderboard-name').value.trim();
    const isAnonymous = document.getElementById('settings-is-anonymous').checked;

    if (!fullName) {
        alert('Please enter your full name.');
        return;
    }

    // Validation for Leaderboard Name
    if (leaderboardName) {
        // Strip @ prefix if user typed it
        const cleanName = leaderboardName.replace(/^@/, '');

        if (cleanName.length < 4) {
            alert('Leaderboard username must be at least 4 characters.');
            return;
        }

        if (!/^[a-zA-Z0-9_]+$/.test(cleanName)) {
            alert('Username can only contain letters, numbers, and underscores.');
            return;
        }

        // Update the input to show clean name
        document.getElementById('settings-leaderboard-name').value = cleanName;
    }

    if (leaderboardName && typeof BadWordFilter !== 'undefined') {
        const validation = BadWordFilter.validateUsername(leaderboardName.replace(/^@/, ''));
        if (!validation.valid) {
            alert(validation.message);
            return;
        }
    }

    // UI Feedback
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
    btn.disabled = true;

    // A. Optimistic Update (Local Storage & UI)
    try {
        const [first, ...last] = fullName.split(' ');
        const statusVal = document.getElementById('settings-status').value;
        const studentLevel = statusVal.startsWith('alevel') ? 'alevel' : 'llb';

        const updates = {
            first_name: first,
            last_name: last.join(' '),
            email: document.getElementById('settings-email').value,
            university: lawSchool,
            target_year: gradYear,
            current_status: statusVal,
            student_level: studentLevel,
            leaderboard_username: leaderboardName ? leaderboardName.replace(/^@/, '') : '',
            is_anonymous: isAnonymous
        };

        // Update Local Storage immediately
        localStorage.setItem('userName', fullName);
        localStorage.setItem('userUniversity', lawSchool);
        localStorage.setItem('studentLevel', statusVal.startsWith('alevel') ? 'alevel' : 'llb');
        localStorage.setItem('userTargetYear', gradYear);
        localStorage.setItem('examBoard', document.getElementById('settings-board').value);
        localStorage.setItem('userStatus', statusVal);
        localStorage.setItem('leaderboardUsername', updates.leaderboard_username);
        localStorage.setItem('isAnonymous', isAnonymous);
        if (fullName && lawSchool) {
            localStorage.setItem('onboardingCompleted', 'true');
        }

        // Update Sidebar Name immediately
        const sidebarName = document.getElementById('user-name');
        if (sidebarName) sidebarName.textContent = fullName;

        // Update Dashboard Greeting
        if (typeof updateDashboardGreeting === 'function') {
            updateDashboardGreeting();
        }

        // B. Cloud Update
        if (typeof CloudData !== 'undefined') {
            // We don't await here to block UI? Actually we should to show "Saved" vs "Saved (Local)"
            const saved = await CloudData.saveProfile(updates);
            if (!saved) throw new Error('Cloud save failed (offline/error)');
        }

        // Success State
        btn.innerHTML = '<i class="fas fa-check"></i> Saved';
        btn.style.background = '#4CAF50';
        btn.style.borderColor = '#4CAF50';

        setTimeout(() => {
            btn.textContent = originalText;
            btn.disabled = false;
            btn.style.background = '';
            btn.style.borderColor = '';
        }, 2000);

    } catch (error) {
        console.warn('Settings saved locally, but cloud sync failed:', error);

        // Treat as "Saved (Local)" success
        btn.innerHTML = '<i class="fas fa-check"></i> Saved (Local)';
        btn.style.background = '#FF9800'; // Orange for warning/local
        btn.style.borderColor = '#FF9800';

        setTimeout(() => {
            btn.textContent = originalText;
            btn.disabled = false;
            btn.style.background = '';
            btn.style.borderColor = '';
        }, 2000);
    }
}

// 4. Missing Data Check & UI Toggle
function toggleSettingsBoard(status) {
    const boardGroup = document.getElementById('settings-board-group');
    if (boardGroup) {
        boardGroup.style.display = status.startsWith('alevel') ? 'block' : 'none';
    }
}

// Populate Form on Load
async function loadSettingsData() {
    // 1. Fetch Email from Auth
    try {
        if (typeof getSupabaseClient === 'function') {
            const client = await getSupabaseClient();
            const { data: { user } } = await client.auth.getUser();
            if (user) {
                const emailInput = document.getElementById('settings-email');
                if (emailInput) {
                    emailInput.value = user.email;
                    localStorage.setItem('userEmail', user.email);
                }
            }
        }
    } catch (e) { console.warn('Email sync failed'); }

    // 2. Fetch Profile from CloudData (or LS)
    const name = localStorage.getItem('userName');
    const school = localStorage.getItem('userUniversity');
    const status = localStorage.getItem('userStatus') || 'llb';
    const board = localStorage.getItem('examBoard') || 'aqa';

    if (name) document.getElementById('settings-name').value = name;
    if (school) document.getElementById('settings-school').value = school;
    if (status) {
        document.getElementById('settings-status').value = status;
        toggleSettingsBoard(status);
    }
    if (board) document.getElementById('settings-board').value = board;

    // Show/Hide A-Level Transition Section
    const transitionSection = document.getElementById('settings-alevel-transition');
    if (transitionSection) {
        const level = localStorage.getItem('studentLevel') || 'llb';
        transitionSection.style.display = (level === 'alevel') ? 'block' : 'none';
    }

    // 3. Attempt background refresh from Cloud
    if (typeof CloudData !== 'undefined') {
        const data = await CloudData.getProfile();
        if (data) {
            const fName = [data.first_name, data.last_name].filter(Boolean).join(' ');
            document.getElementById('settings-name').value = fName || '';
            document.getElementById('settings-school').value = data.university || '';
            document.getElementById('settings-year').value = data.target_year || '';
            if (data.student_status || data.current_status) {
                document.getElementById('settings-status').value = data.student_status || data.current_status || 'llb-student';
                toggleSettingsBoard(data.student_status || data.current_status || 'llb-student');
            }
            document.getElementById('settings-leaderboard-name').value = data.leaderboard_username || '';
            document.getElementById('settings-is-anonymous').checked = !!data.is_anonymous;

            if (data.current_status) {
                document.getElementById('settings-status').value = data.current_status;
                toggleSettingsBoard(data.current_status);
            }
            if (data.exam_board) document.getElementById('settings-board').value = data.exam_board;

            // Sync LS
            if (fName) localStorage.setItem('userName', fName);
            if (data.university) localStorage.setItem('userUniversity', data.university);
            const gradYear = data.target_year;
            if (gradYear) localStorage.setItem('userTargetYear', gradYear);
            const status = data.student_status || data.current_status;
            if (status) localStorage.setItem('userStatus', status);
            if (data.student_level) localStorage.setItem('studentLevel', data.student_level);
            if (data.avatar_url) {
                localStorage.setItem('userAvatarUrl', data.avatar_url);
                updateAvatarUI(data.avatar_url);
            }
            if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);
            if (data.current_status) localStorage.setItem('userStatus', data.current_status);
        }
    }

    // Sync Mistral Toggle
    const mistralEnabled = localStorage.getItem('mistralLargeEnabled') === 'true';
    const mistralToggle = document.getElementById('mistral-large-toggle');
    const mistralWarning = document.getElementById('mistral-warning');
    if (mistralToggle) mistralToggle.checked = mistralEnabled;
    if (mistralWarning) mistralWarning.style.display = mistralEnabled ? 'block' : 'none';
}

// Hook into modal open
const originalOpenSettings = window.openSettingsModal;
window.openSettingsModal = function () {
    if (originalOpenSettings) originalOpenSettings();
    loadSettingsData(); // Refresh data
    // Sync Audio Preferences
    if (typeof AudioManager !== 'undefined') {
        const s = AudioManager.settings;
        const masterT = document.getElementById('audio-master-toggle');
        const mascotT = document.getElementById('audio-mascot-toggle');
        const typingT = document.getElementById('audio-typing-toggle');
        const musicT = document.getElementById('audio-music-toggle');
        const sfxV = document.getElementById('audio-sfx-volume');

        if (masterT) masterT.checked = s.masterEnabled;
        if (mascotT) mascotT.checked = s.mascotEnabled;
        if (typingT) typingT.checked = s.typingEnabled;
        if (musicT) musicT.checked = s.musicEnabled;
        if (sfxV) sfxV.value = s.sfxVolume;
    }
}

function updateAudioPref(key, val) {
    if (typeof AudioManager !== 'undefined') {
        const update = {};
        update[key] = val;
        AudioManager.updateSettings(update);
    }
}

async function startUniTransition() {
    if (!confirm("Are you ready to transition to Law at University? This will move your account to LLB Mode and clear your A-Level school data.")) return;

    const btn = document.querySelector('#settings-alevel-transition .btn-primary');
    const originalText = btn.innerHTML;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Transitioning...';
    btn.disabled = true;

    try {
        const updates = {
            student_level: 'llb',
            exam_board: '',
            school_urn: ''
        };

        // Update Local Storage
        localStorage.setItem('studentLevel', 'llb');
        localStorage.removeItem('examBoard');
        localStorage.removeItem('schoolUrn');

        // Update Cloud
        if (typeof CloudData !== 'undefined') {
            await CloudData.saveProfile(updates);
        }

        // Trigger Mascot Congratulation
        if (typeof MascotBrain !== 'undefined') {
            MascotBrain.studentLevel = 'llb'; // Sync brain immediately
            MascotBrain.speak("CONGRATULATIONS on graduating to Uni! 🎓 I've updated my brain to 'University Mode'. Let's master that LLB together!", 10000);
            MascotBrain.setState('happy');
        }

        // Success State
        btn.innerHTML = '<i class="fas fa-check"></i> Welcome to LLB!';
        setTimeout(() => {
            location.reload(); // Reload to refresh all UI contexts
        }, 3000);

    } catch (e) {
        alert("Transition failed. Please try again.");
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
}

function checkProfileCompleteness() {
    const name = localStorage.getItem('userName');
    const school = localStorage.getItem('userUniversity');

    if (!name || name === 'Guest User' || !school) {
        // Subtle delay or check on specific pages
        const isDashboard = window.location.pathname.includes('dashboard');
        if (isDashboard) {
            setTimeout(() => {
                if (confirm("Your profile is incomplete! 🎓 Let's add your name and school so I can personalize your learning experience and track your progress correctly.\n\nOpen settings now?")) {
                    openSettingsModal();
                }
            }, 2000);
        }
    }
}

// Auto-check on load if on dashboard
if (window.location.pathname.includes('dashboard')) {
    document.addEventListener('DOMContentLoaded', checkProfileCompleteness);
}

window.checkProfileCompleteness = checkProfileCompleteness;

window.toggleSettingsBoard = toggleSettingsBoard;
window.updateAudioPref = updateAudioPref;
window.saveSettings = saveSettings;
window.startUniTransition = startUniTransition;

// Mistral Large Intelligence Toggle
function toggleMistralLarge(enabled) {
    const tier = localStorage.getItem('subscriptionTier') || 'free';
    const warning = document.getElementById('mistral-warning');
    const checkbox = document.getElementById('mistral-large-toggle');

    if (tier !== 'subscriber') {
        alert("AI Plus is an elite feature for subscribers only. 🎓 Upgrade your plan to unlock smarter and more detailed legal reasoning!");
        if (checkbox) checkbox.checked = false;
        if (warning) warning.style.display = 'none';
        return;
    }

    localStorage.setItem('mistralLargeEnabled', enabled);
    if (warning) warning.style.display = enabled ? 'block' : 'none';

    // Notify Mascot if active
    if (enabled && typeof MascotBrain !== 'undefined') {
        MascotBrain.speak("AI Plus ACTIVATED! 🧠 Just a heads up, my big brain uses about 3x more treats (credits), but I'll be much sharper and more detailed with complex law!");
    }
}

// Global exposure
window.toggleMistralLarge = toggleMistralLarge;

// ─── Profile Picture Upload ───

async function handleAvatarUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    const tier = localStorage.getItem('subscriptionTier') || 'free';
    const isSubscriber = tier !== 'free';
    const isGif = file.type === 'image/gif';

    // Validate file type
    const allowed = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
    if (!allowed.includes(file.type)) {
        alert('Please upload a PNG, JPG, GIF, or WebP image.');
        return;
    }

    // Validate animated GIF (subscriber only)
    if (isGif && !isSubscriber) {
        alert('Animated GIF avatars are available for subscribers only. Please upload a PNG or JPG (max 2MB).');
        return;
    }

    // Validate file size
    const maxSize = (isGif && isSubscriber) ? 5 * 1024 * 1024 : 2 * 1024 * 1024;
    const maxLabel = (isGif && isSubscriber) ? '5MB' : '2MB';
    if (file.size > maxSize) {
        alert(`File is too large. Maximum size is ${maxLabel}.`);
        return;
    }

    // Visual feedback
    const avatarEl = document.getElementById('settings-avatar');
    const initialsEl = document.getElementById('settings-avatar-initials');
    const imgEl = document.getElementById('settings-avatar-img');
    if (initialsEl) initialsEl.style.display = 'none';

    // Show local preview immediately
    const localURL = URL.createObjectURL(file);
    if (imgEl) {
        imgEl.src = localURL;
        imgEl.style.display = 'block';
    }

    try {
        if (typeof getSupabaseClient !== 'function') throw new Error('Supabase not available');
        const client = await getSupabaseClient();
        const { data: { user } } = await client.auth.getUser();
        if (!user) throw new Error('Not logged in');

        const filePath = `avatars/${user.id}.jpg`;

        // Upload to Supabase Storage
        const { error: uploadError } = await client.storage
            .from('profile-pictures')
            .upload(filePath, file, {
                upsert: true,
                contentType: file.type
            });

        if (uploadError) throw uploadError;

        // Get public URL
        const { data: urlData } = client.storage
            .from('profile-pictures')
            .getPublicUrl(filePath);

        const publicUrl = urlData.publicUrl + '?t=' + Date.now(); // Cache bust

        // Save to profile
        if (typeof CloudData !== 'undefined') {
            await CloudData.saveProfile({ avatar_url: publicUrl });
        }

        // Cache locally
        localStorage.setItem('userAvatarUrl', publicUrl);

        // Update all avatar instances
        updateAvatarUI(publicUrl);

        console.log('Profile picture uploaded:', publicUrl);
    } catch (e) {
        console.warn('Avatar upload failed (using local preview):', e.message);
        // Still keep local preview visible
        localStorage.setItem('userAvatarUrl', localURL);
    }
}

function updateAvatarUI(url) {
    if (!url) return;

    // Settings avatar
    const settingsImg = document.getElementById('settings-avatar-img');
    const settingsInitials = document.getElementById('settings-avatar-initials');
    if (settingsImg) {
        settingsImg.src = url;
        settingsImg.style.display = 'block';
    }
    if (settingsInitials) settingsInitials.style.display = 'none';

    // Sidebar avatar
    const sidebarAvatar = document.querySelector('.profile-avatar');
    if (sidebarAvatar) {
        let img = sidebarAvatar.querySelector('img');
        if (!img) {
            img = document.createElement('img');
            img.style.cssText = 'width:100%;height:100%;object-fit:cover;border-radius:50%;';
            sidebarAvatar.innerHTML = '';
            sidebarAvatar.appendChild(img);
        }
        img.src = url;
    }
}

function loadAvatar() {
    const cached = localStorage.getItem('userAvatarUrl');
    if (cached) {
        updateAvatarUI(cached);
    }

    // Also init initials from name
    const name = localStorage.getItem('userName') || '';
    const initials = name.split(' ').map(n => n.charAt(0).toUpperCase()).join('').substring(0, 2) || '??';
    const initialsEl = document.getElementById('settings-avatar-initials');
    if (initialsEl && !cached) initialsEl.textContent = initials;
}

// Load avatar on settings open
const _origOpenSettings2 = window.openSettingsModal;
window.openSettingsModal = function () {
    if (_origOpenSettings2) _origOpenSettings2();
    loadAvatar();
};

// Load avatar on page load for sidebar
document.addEventListener('DOMContentLoaded', () => {
    const cached = localStorage.getItem('userAvatarUrl');
    if (cached) updateAvatarUI(cached);
});

async function deleteAccount() {
    if (!confirm("⚠️ PERMANENT ACCOUNT DELETION\n\nAre you sure you want to permanently delete your account? This will erase all your modules, notes, flashcards, and study history. This action CANNOT be undone.")) {
        return;
    }

    const secondConfirm = prompt("To confirm deletion, please type 'DELETE' in the box below:");
    if (secondConfirm !== 'DELETE') {
        alert("Deletion cancelled. The confirmation text did not match.");
        return;
    }

    const btn = document.querySelector('#settings-tab-account .btn-danger-outline'); // We'll add this class to the button
    if (btn) {
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Erasing...';
        btn.disabled = true;
    }

    try {
        if (typeof CloudData === 'undefined') throw new Error('Cloud storage unavailable.');
        
        await CloudData.deleteUserAccount();
        
        // Success: Redirect to landing or login
        alert("Your account and all associated data have been permanently deleted. You will now be redirected.");
        window.location.href = 'index.html';
    } catch (error) {
        alert("Failed to delete account: " + error.message);
        if (btn) {
            btn.innerHTML = 'Delete Account';
            btn.disabled = false;
        }
    }
}

window.deleteAccount = deleteAccount;
window.handleAvatarUpload = handleAvatarUpload;
window.loadAvatar = loadAvatar;
