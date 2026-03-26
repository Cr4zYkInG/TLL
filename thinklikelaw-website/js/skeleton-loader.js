/**
 * Skeleton Loader Component
 * Reusable skeleton screens for AI loading states
 */

// CSS for skeleton loaders (add to any page that needs it)
const skeletonStyles = `
<style>
    .skeleton {
        background: linear-gradient(90deg, 
            rgba(255,255,255,0.03) 25%, 
            rgba(255,255,255,0.08) 50%, 
            rgba(255,255,255,0.03) 75%
        );
        background-size: 200% 100%;
        animation: skeleton-loading 1.5s ease-in-out infinite;
        border-radius: 8px;
    }

    @keyframes skeleton-loading {
        0% { background-position: 200% 0; }
        100% { background-position: -200% 0; }
    }

    .skeleton-text {
        height: 1rem;
        margin-bottom: 0.5rem;
        width: 100%;
    }

    .skeleton-text.short { width: 60%; }
    .skeleton-text.medium { width: 80%; }

    .skeleton-card {
        background: var(--surface-color);
        border: 1px solid var(--border-color);
        border-radius: 12px;
        padding: 1.5rem;
        min-height: 180px;
    }
</style>
`;

// HTML templates for different skeleton states
const skeletonTemplates = {
    lectureCard: `
        <div class="skeleton-card">
            <div class="skeleton skeleton-text short"></div>
            <div class="skeleton skeleton-text" style="height: 1.5rem; margin: 1rem 0;"></div>
            <div class="skeleton skeleton-text medium"></div>
            <div class="skeleton skeleton-text short" style="margin-top: auto;"></div>
        </div>
    `,

    textGeneration: `
        <div style="padding: 2rem;">
            <div class="skeleton skeleton-text"></div>
            <div class="skeleton skeleton-text medium"></div>
            <div class="skeleton skeleton-text short"></div>
            <div class="skeleton skeleton-text" style="margin-top: 1rem;"></div>
            <div class="skeleton skeleton-text medium"></div>
        </div>
    `
};

// Utility function to show skeleton loader
function showSkeletonLoader(containerId, templateType = 'textGeneration') {
    const container = document.getElementById(containerId);
    if (container) {
        container.innerHTML = skeletonTemplates[templateType];
    }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { skeletonStyles, skeletonTemplates, showSkeletonLoader };
}
