/**
 * Retention Engine
 * Calculates spaced repetition data using a modified Ebbinghaus forgetting curve.
 */

const RetentionEngine = {
    // 100% Retention = 1.0
    // Decay constant base
    DECAY_BASE: 0.1,

    /**
     * Calculates the current retention score of a note based on when it was last reviewed
     * and how many times it has been reviewed.
     * @param {Object} lecture - The note/lecture object
     * @returns {Number} A percentage (0-100) representing estimated memory retention.
     */
    calculateRetention(lecture) {
        if (!lecture) return 0;

        const reviewCount = lecture.review_count || 0;
        const lastReviewedAt = lecture.last_reviewed_at || lecture.created;

        if (!lastReviewedAt) return 100; // If brand new and no date, assume 100%

        const now = new Date();
        const lastReviewDate = new Date(lastReviewedAt);

        // Time elapsed in days
        const elapsedMs = now - lastReviewDate;
        const elapsedDays = Math.max(0, elapsedMs / (1000 * 60 * 60 * 24));

        // If reviewed today, it's 100%
        if (elapsedDays < 0.5 && reviewCount > 0) return 100;

        // Ebbinghaus Formula Approximation: Retention = e^(-Elapsed / Strength)
        // Memory strength increases linearly/exponentially with review count
        // 0 reviews = decays fast (strength ~ 1 day)
        // 1 review = strength ~ 3 days
        // 3 reviews = strength ~ 14 days
        // 5 reviews = strength ~ 45 days

        const memoryStrength = 1 + Math.pow(reviewCount * 1.5, 1.8);

        const decay = Math.exp(-elapsedDays / memoryStrength);

        // Clamp between 0 and 100
        let score = Math.round(decay * 100);

        // Provide a floor to prevent it going literally to zero if they actually wrote the note
        return Math.max(10, Math.min(100, score));
    },

    /**
     * Calculates the average retention for a specific module.
     * @param {Array} lectures - Array of lecture objects belonging to the module
     * @returns {Number} Average percentage
     */
    getModuleAverage(lectures) {
        if (!lectures || lectures.length === 0) return 100;

        const total = lectures.reduce((sum, lec) => sum + this.calculateRetention(lec), 0);
        return Math.round(total / lectures.length);
    },

    /**
     * Recommends which lectures need reviewing right now (score < 70)
     * @param {Array} lectures - All user lectures
     * @returns {Array} Sorted array of lectures needing review (lowest score first)
     */
    getLecturesNeedingReview(lectures) {
        if (!lectures) return [];

        const mapped = lectures.map(l => ({
            ...l,
            current_retention: this.calculateRetention(l)
        }));

        return mapped
            .filter(l => l.current_retention < 75)
            .sort((a, b) => a.current_retention - b.current_retention);
    },

    /**
     * Formats the time until the next review is optimally needed
     */
    getNextReviewSuggestion(retentionScore) {
        if (retentionScore > 90) return "Looking good!";
        if (retentionScore > 75) return "Review soon";
        if (retentionScore > 50) return "Needs review";
        return "Critical review needed";
    },

    getCurveColor(score) {
        if (score >= 80) return '#4CAF50'; // Green
        if (score >= 60) return '#FFEB3B'; // Yellow
        if (score >= 40) return '#FF9800'; // Orange
        return '#F44336'; // Red
    }
};

if (typeof module !== 'undefined' && module.exports) {
    module.exports = RetentionEngine;
} else {
    window.RetentionEngine = RetentionEngine;
}
