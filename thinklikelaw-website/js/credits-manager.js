/**
 * Think Credits Manager
 * Manages AI credit usage with tier-based monthly limits
 */

class ThinkCreditsManager {
    constructor() {
        this.TIERS = {
            free: { limit: 1000, name: 'Free' },
            subscriber: { limit: 50000, name: 'Subscriber' }
        };

        this.COSTS = {
            interpret: 10,
            lectureNotes: 50,
            outline: 50,
            flashcards: 30,
            issueSpotter: 20,
            essayMarking: 40,
            examReview: 40,
            examAttempt: 250,
            oscolaAudit: 25,
            noteAI: 15,
            podcast: 40,
            mascotThesaurus: 5,
            // CRUD operations (create/edit notes/modules) are FREE and not listed here.
        };

        this.init();
    }

    init() {
        // Check if new month
        const lastReset = localStorage.getItem('creditsLastReset');
        const currentMonth = new Date().getMonth();
        const currentYear = new Date().getFullYear();
        const resetDate = lastReset ? new Date(lastReset) : null;

        if (!resetDate || resetDate.getMonth() !== currentMonth || resetDate.getFullYear() !== currentYear) {
            this.resetCredits();
        }

        // ─── Sync Logic ───
        this.syncWithCloud();
    }

    async syncWithCloud() {
        if (typeof CloudData === 'undefined') return;

        try {
            // 1. Get latest from cloud
            const cloud = await CloudData.getCredits();
            if (cloud) {
                const pending = parseInt(localStorage.getItem('pendingCreditsSynced') || '0');

                // Merge: User balance = Cloud Balance - Pending Local Deductions
                const mergedBalance = Math.max(0, cloud.credits - pending);

                localStorage.setItem('thinkCredits', mergedBalance);
                localStorage.setItem('subscriptionTier', cloud.tier);
                localStorage.setItem('billingCycle', cloud.billingCycle || 'monthly');

                this.updateUI();

                // 2. Clear pending if sync succeeded (CloudData.getCredits actually does a GET, so we still need to SEND the pending amount)
                if (pending > 0) {
                    await CloudData.deductCredits(pending);
                    localStorage.setItem('pendingCreditsSynced', '0');
                    console.log(`[Credits] Synced ${pending} pending credits to cloud.`);
                }
            }
        } catch (e) {
            console.warn('[Credits] Cloud sync postponed:', e.message);
        }
    }

    resetCredits() {
        const tier = this.getUserTier();
        localStorage.setItem('thinkCredits', this.TIERS[tier].limit);
        localStorage.setItem('creditsLastReset', new Date().toISOString());
        localStorage.setItem('pendingCreditsSynced', '0'); // Reset pending on month reset
    }

    getUserTier() {
        return localStorage.getItem('subscriptionTier') || 'free';
    }

    getCredits() {
        const credits = parseInt(localStorage.getItem('thinkCredits'));
        if (isNaN(credits)) {
            this.resetCredits();
            return this.getCredits();
        }
        return credits;
    }

    getLimit() {
        const tier = this.getUserTier();
        return this.TIERS[tier].limit;
    }

    canAfford(operation, overrideCost = null) {
        let cost = overrideCost !== null ? overrideCost : (this.COSTS[operation] || 0);
        
        // Multiplier for AI Plus
        if (localStorage.getItem('mistralLargeEnabled') === 'true' && this.getUserTier() === 'subscriber') {
            cost = cost * 3;
        }
        
        return this.getCredits() >= cost;
    }

    deduct(operation, overrideCost = null) {
        let cost = overrideCost !== null ? overrideCost : (this.COSTS[operation] || 0);

        // Multiplier for AI Plus
        if (localStorage.getItem('mistralLargeEnabled') === 'true' && this.getUserTier() === 'subscriber') {
            cost = cost * 3;
        }

        if (!this.canAfford(operation, cost)) {
            this.showSubscriptionCTA();
            throw new Error('Insufficient credits');
        }

        const current = this.getCredits();
        const newBalance = Math.max(0, current - cost);
        localStorage.setItem('thinkCredits', newBalance);

        // Track pending sync
        let pending = parseInt(localStorage.getItem('pendingCreditsSynced') || '0');
        localStorage.setItem('pendingCreditsSynced', pending + cost);

        // Sync deduction to cloud immediately (non-blocking)
        if (typeof CloudData !== 'undefined') {
            CloudData.deductCredits(cost).then(() => {
                // If successful, reduce pending
                let currentPending = parseInt(localStorage.getItem('pendingCreditsSynced') || '0');
                localStorage.setItem('pendingCreditsSynced', Math.max(0, currentPending - cost));
            }).catch(() => {
                console.warn('[Credits] Deduction failed to sync. Will retry on next load.');
            });
        }

        // Trigger UI update
        this.updateUI();

        return newBalance;
    }

    showSubscriptionCTA() {
        const tier = this.getUserTier();
        const message = tier === 'free'
            ? "You've reached your free monthly credit limit (1,000). Upgrade to Pro for 50,000 credits/month to continue using AI tools."
            : "You've reached your credit limit. Please top up your account to continue.";

        // Use the branded PaymentModal
        if (window.PaymentModal) {
            // Trigger an email nudge
            const userEmail = localStorage.getItem('userEmail');
            const firstName = localStorage.getItem('userName')?.split(' ')[0];
            if (userEmail) {
                try {
                    fetch('https://thinklikelaw-email.5dwvxmf5mn.workers.dev', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ email: userEmail, firstName: firstName, type: 'upgrade' })
                    });
                } catch (e) { console.warn('Failed to send upgrade nudge', e); }
            }

            alert(message);
            window.PaymentModal.open(() => {
                // On successful upgrade, refresh credits
                this.resetCredits();
                this.updateUI();
            });
        } else if (window.openSettingsModal && window.switchSettingsTab) {
            alert(message + "\n\nRedirecting to subscription settings...");
            window.switchSettingsTab('subscription');
            window.openSettingsModal();
        } else {
            alert(message);
        }
    }

    updateUI() {
        // ... (existing implementation)
        const credits = this.getCredits();
        const limit = this.getLimit();
        const percentage = (credits / limit) * 100;

        // Update all credit displays
        document.querySelectorAll('[data-credits-display]').forEach(el => {
            el.textContent = credits.toLocaleString();
        });

        // Update credit bars
        document.querySelectorAll('[data-credits-bar]').forEach(el => {
            el.style.width = `${percentage}%`;

            // Color coding
            if (percentage < 10) {
                el.style.background = '#ff4444';
            } else if (percentage < 25) {
                el.style.background = '#ffaa00';
            } else {
                el.style.background = 'var(--text-primary)';
            }
        });

        // Show subscription CTA if credits are 0
        if (credits <= 0) {
            // Optional: aggressive CTA? Maybe just styling red is enough for now, 
            // let the user trigger the action.
        }

        // Show Roll-over status
        const cycle = localStorage.getItem('billingCycle') || 'monthly';
        document.querySelectorAll('[data-roll-over-status]').forEach(el => {
            if (cycle === 'yearly') {
                el.textContent = 'Roll-over Active';
                el.style.display = 'inline-block';
            } else {
                el.style.display = 'none';
            }
        });
    }


    showLowCreditsWarning() {
        const warning = document.getElementById('low-credits-warning');
        if (warning && !warning.classList.contains('visible')) {
            warning.classList.add('visible');
            setTimeout(() => warning.classList.remove('visible'), 5000);
        }
    }

    // Static helper to get instance
    static getInstance() {
        if (!window._thinkCreditsManager) {
            window._thinkCreditsManager = new ThinkCreditsManager();
        }
        return window._thinkCreditsManager;
    }
}

// Initialize and export
const creditsManager = ThinkCreditsManager.getInstance();

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ThinkCreditsManager;
}
