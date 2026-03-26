
/**
 * Study Timer & Streak Manager
 * Tracks real-time active study sessions (tab focus) and manages streaks.
 */

const StudyManager = {
    timerInterval: null,
    saveInterval: 30000, // Save every 30s
    startTime: null,

    // Initialize
    init() {
        this.loadMetrics();
        this.setupVisibilityListeners();
        this.updateStreak();
        this.startTimer();

        // Update UI every minute
        setInterval(() => this.updateUI(), 60000);
    },

    loadMetrics() {
        const defaults = {
            studyTime: 0, // Total minutes (resets monthly)
            todayTime: 0, // Minutes today
            lastStudyDate: new Date().toISOString().split('T')[0],
            streak: 1,
            leaderboardRank: 42,
            lifetimeStudyTime: 0
        };
        const stored = JSON.parse(localStorage.getItem('userMetrics'));
        this.metrics = stored || defaults;

        // Reset 'todayTime' if date changed
        const today = new Date().toISOString().split('T')[0];
        if (this.metrics.lastStudyDate !== today) {
            this.metrics.todayTime = 0;
        }

        // Try loading from Supabase (async, non-blocking)
        if (typeof CloudData !== 'undefined') {
            CloudData.getMetrics().then(cloudMetrics => {
                if (cloudMetrics && cloudMetrics.studyTime > 0) {
                    // Merge: keep the higher values
                    this.metrics.studyTime = Math.max(this.metrics.studyTime, cloudMetrics.studyTime);
                    this.metrics.streak = Math.max(this.metrics.streak, cloudMetrics.streak);
                    this.metrics.lifetimeStudyTime = Math.max(this.metrics.lifetimeStudyTime || 0, cloudMetrics.lifetimeStudyTime || 0);
                    this.metrics.leaderboardRank = cloudMetrics.leaderboardRank || this.metrics.leaderboardRank;
                    this.updateUI();
                }
            }).catch(() => { });
        }
    },

    saveMetrics() {
        localStorage.setItem('userMetrics', JSON.stringify(this.metrics));
        // Sync to Supabase (non-blocking)
        if (typeof CloudData !== 'undefined') {
            CloudData.saveMetrics(this.metrics).catch(() => { });
        }
        this.updateUI(); // Reflect changes
    },

    setupVisibilityListeners() {
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.stopTimer();
            } else {
                this.startTimer();
            }
        });

        window.addEventListener('beforeunload', () => this.stopTimer());
    },

    startTimer() {
        if (this.timerInterval) return;
        this.startTime = Date.now();
        console.log('Study timer started.');

        this.timerInterval = setInterval(() => {
            const now = Date.now();
            const elapsed = now - this.startTime;

            // Add elapsed time (in minutes)
            const minutes = elapsed / 60000;

            if (minutes >= 0.1) { // Update locally every ~6 seconds
                this.metrics.studyTime += minutes;
                this.metrics.todayTime += minutes;
                this.startTime = now; // Reset checkpoint
                this.saveMetrics();
            }

            // Sync with Server every ~1 minute (when accumulated > 0.9)
            if (this.metrics.unsynced_minutes >= 1) {
                if (typeof updateUserStudyTime === 'function') {
                    updateUserStudyTime(this.metrics.unsynced_minutes); // Fire and forget
                    this.metrics.unsynced_minutes = 0;
                }
            } else {
                // Accumulate for sync
                this.metrics.unsynced_minutes = (this.metrics.unsynced_minutes || 0) + minutes;
            }

        }, 10000); // Check every 10s
    },

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;

            // Save remaining time
            const now = Date.now();
            const elapsed = now - this.startTime;
            const minutes = elapsed / 60000;
            this.metrics.studyTime += minutes;
            this.metrics.todayTime += minutes;

            // Track lifetime purely for their own internal/account stats
            this.metrics.lifetimeStudyTime = (this.metrics.lifetimeStudyTime || 0) + minutes;

            this.saveMetrics();
            console.log('Study timer paused.');
        }
    },

    updateStreak() {
        const today = new Date().toISOString().split('T')[0];
        const lastDate = this.metrics.lastStudyDate || today;

        if (lastDate !== today) {
            const d1 = new Date(lastDate);
            const d2 = new Date(today);
            const diffTime = Math.abs(d2 - d1);
            const dateDiff = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            if (dateDiff === 1) {
                // Next day — increment streak
                this.metrics.streak += 1;
                this.saveMetrics();

                // Notify Mascot
                window.dispatchEvent(new CustomEvent('streak-updated', {
                    detail: { type: 'increase', val: this.metrics.streak }
                }));
            } else if (dateDiff > 1) {
                // Streak broken (missed at least one full day)
                const preBreakStreak = this.metrics.streak;
                this.metrics.streak = 1; // Reset to 1 for the new day
                this.saveMetrics();

                if (preBreakStreak > 1) {
                    // Notify Mascot of broken streak
                    window.dispatchEvent(new CustomEvent('streak-updated', {
                        detail: { type: 'lost', val: preBreakStreak }
                    }));
                }
            }

            this.metrics.lastStudyDate = today;
            this.saveMetrics();
        } else {
            // Even if same day, if its somehow 0 due to an error, set to 1
            if (!this.metrics.streak || this.metrics.streak < 1) {
                this.metrics.streak = 1;
                this.saveMetrics();
            }
        }
    },

    updateUI() {
        // Find elements
        const timeEl = document.getElementById('metric-study-time');
        const todayEl = document.getElementById('metric-today');
        const streakEl = document.getElementById('metric-streak');

        if (!timeEl || !streakEl) return;

        // Format Time
        const totalMin = Math.floor(this.metrics.studyTime);
        const hours = Math.floor(totalMin / 60);
        const mins = totalMin % 60;

        const todayMin = Math.floor(this.metrics.todayTime);

        timeEl.textContent = `${hours}h ${mins}m`;
        if (todayEl) todayEl.innerHTML = `<i class="fas fa-arrow-up"></i> +${todayMin}m today`;

        streakEl.textContent = `${this.metrics.streak} Days`;
    }
};

// Start automatically
document.addEventListener('DOMContentLoaded', () => {
    StudyManager.init();
});
