/**
 * Global Sidebar Loader
 * Loads the sidebar component on all pages and manages state.
 * Uses Supabase profile data when available, localStorage as fallback.
 */

(function () {
    // Load sidebar HTML
    async function loadSidebar() {
        try {
            const response = await fetch('components/sidebar.html');
            const html = await response.text();

            // Insert at the beginning of body
            document.body.insertAdjacentHTML('afterbegin', html);

            // Insert Mobile Toggle
            const mobileToggle = `
                <button class="mobile-nav-toggle" id="mobile-sidebar-toggle">
                    <i class="fas fa-bars"></i>
                </button>
                <div class="sidebar-overlay" id="sidebar-overlay"></div>
            `;
            document.body.insertAdjacentHTML('afterbegin', mobileToggle);

            // Initialize after loading
            initSidebar();

            // Re-apply terminology alignment in case sidebar was loaded after DOMContentLoaded
            if (typeof TerminologyManager !== 'undefined') {
                TerminologyManager.init();
            }
        } catch (error) {
            console.error('Failed to load sidebar:', error);
        }
    }

    // Initialize sidebar functionality
    function initSidebar() {
        const sidebar = document.getElementById('app-sidebar');
        const toggle = document.getElementById('sidebar-toggle');

        // Get saved state
        const isMinimized = localStorage.getItem('sidebarMinimized') === 'true';

        // Apply saved state
        if (isMinimized) {
            sidebar?.classList.add('minimized');
            document.body.classList.add('sidebar-minimized');
        }

        // Toggle functionality
        toggle?.addEventListener('click', () => {
            const isCurrentlyMinimized = sidebar?.classList.toggle('minimized');
            document.body.classList.toggle('sidebar-minimized');

            // Save state
            localStorage.setItem('sidebarMinimized', isCurrentlyMinimized);

            // Update icon
            const icon = toggle.querySelector('i');
            if (icon) {
                icon.className = isCurrentlyMinimized ? 'fas fa-chevron-right' : 'fas fa-chevron-left';
            }
        });

        // Mobile Toggle Listener
        const mobileBtn = document.getElementById('mobile-sidebar-toggle');
        const overlay = document.getElementById('sidebar-overlay');

        const toggleMobile = () => {
            sidebar?.classList.toggle('mobile-active');
            overlay?.classList.toggle('active');
        };

        mobileBtn?.addEventListener('click', toggleMobile);
        overlay?.addEventListener('click', toggleMobile);

        // Auto-close on nav click (mobile only)
        const navLinks = document.querySelectorAll('#app-sidebar .nav-item');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                if (window.innerWidth <= 768) {
                    toggleMobile();
                }
            });
        });

        // Highlight active page based on URL
        const currentPage = window.location.pathname.split('/').pop().replace('.html', '') || 'index';
        const navItems = document.querySelectorAll('#app-sidebar .nav-item[data-page]');

        navItems.forEach(item => {
            const page = item.getAttribute('data-page');
            if (page === currentPage) {
                item.classList.add('active');
            }
        });

        // Load user profile data
        loadUserProfile();

        // Load credits display
        loadCreditsDisplay();

        // Ensure correct logo for current theme
        if (typeof window.updateLogos === 'function') {
            window.updateLogos(document.body.classList.contains('dark-mode'));
        }

        // Sync tool visibility based on student level
        syncToolVisibility();
    }

    // Hide/Show tools based on user level (LLB vs A-Level)
    function syncToolVisibility() {
        const level = localStorage.getItem('studentLevel') || 'llb';
        const isLLB = level === 'llb';

        // 1. Sidebar Item
        const examTestNav = document.querySelector('.nav-item[href="exam-test.html"]');
        if (examTestNav) {
            examTestNav.style.display = 'flex';
        }

        // 2. Dashboard Item
        const examTestCard = document.getElementById('qa-exam-test');
        if (examTestCard) {
            examTestCard.style.display = 'flex';
        }
    }

    // Load user profile information — tries Supabase first, falls back to localStorage
    async function loadUserProfile() {
        const nameEl = document.getElementById('user-name');
        const tierEl = document.getElementById('user-tier');

        // 1. Immediate display from localStorage (fast)
        const cachedName = localStorage.getItem('userName');
        const cachedTier = localStorage.getItem('subscriptionTier') || 'free';
        const cachedEmail = localStorage.getItem('userEmail');

        if (nameEl) {
            if (cachedName && cachedName !== 'Guest User') {
                nameEl.textContent = cachedName;
            } else if (cachedEmail) {
                nameEl.textContent = cachedEmail.split('@')[0];
            } else {
                nameEl.textContent = 'Guest User';
            }
        }

        if (tierEl) tierEl.textContent = cachedTier === 'subscriber' ? 'Subscriber' : 'Free Tier';

        // Student Level Tag
        const level = localStorage.getItem('studentLevel') || 'llb';
        const levelTag = document.getElementById('user-level-tag');
        if (levelTag) {
            levelTag.textContent = level === 'llb' ? 'LLB' : 'A-Level';
            levelTag.className = `level-tag ${level}`;
            levelTag.style.display = 'inline-block';
        }

        // 2. Then try to refresh from Supabase (async, non-blocking)
        try {
            if (typeof getUserProfile === 'function') {
                const result = await getUserProfile();
                if (result && result.data) {
                    const profile = result.data;
                    let fullName = [profile.first_name, profile.last_name].filter(Boolean).join(' ');

                    // Fallback to email if name is missing
                    if (!fullName && result.user?.email) {
                        fullName = result.user.email.split('@')[0];
                    }

                    if (fullName && nameEl) {
                        nameEl.textContent = fullName;
                        localStorage.setItem('userName', fullName);
                    }
                    if (profile.university) {
                        localStorage.setItem('userUniversity', profile.university);
                    }
                }
            }
        } catch (e) {
            console.warn('Sidebar: Could not fetch profile from Supabase');
        }
    }

    // Load credits display
    function loadCreditsDisplay() {
        if (typeof creditsManager !== 'undefined') {
            creditsManager.updateUI();

            // Update tier label in sidebar
            const tierLabel = document.getElementById('credits-tier-label');
            if (tierLabel) {
                const tier = localStorage.getItem('subscriptionTier') || 'free';
                tierLabel.textContent = tier === 'subscriber' ? 'Pro Plan' : 'Free Plan';
            }
        }
    }

    // Load Settings Modal
    async function loadSettingsModal() {
        try {
            const response = await fetch('components/settings-modal.html');
            const html = await response.text();
            document.body.insertAdjacentHTML('beforeend', html);
        } catch (error) {
            console.error('Failed to load settings modal:', error);
        }
    }

    // Load Mascot Globally
    function loadMascotGlobally() {
        // CSS
        if (!document.querySelector('link[href="mascot.css"]')) {
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = 'mascot.css';
            document.head.appendChild(link);
        }
        if (!document.querySelector('link[href="css/thinking-mode.css"]')) {
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = 'css/thinking-mode.css';
            document.head.appendChild(link);
        }
        // JS
        if (!document.querySelector('script[src="js/mascot-brain.js"]')) {
            const script = document.createElement('script');
            script.src = 'js/mascot-brain.js';
            document.body.appendChild(script);
        }
        if (!document.querySelector('script[src="js/thinking-mode.js"]')) {
            const script = document.createElement('script');
            script.src = 'js/thinking-mode.js';
            document.body.appendChild(script);
        }
    }

    // Auto-load when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            loadSidebar();
            loadSettingsModal();
            loadMascotGlobally();
            initPageTransitions();
        });
    } else {
        loadSidebar();
        loadSettingsModal();
        loadMascotGlobally();
        initPageTransitions();
    }

    // Listen for auth changes to refresh profile
    if (typeof onAuthStateChange === 'function') {
        onAuthStateChange(async (event, session) => {
            if (event === 'SIGNED_IN' || event === 'USER_UPDATED' || event === 'TOKEN_REFRESHED') {
                await loadUserProfile();
                loadCreditsDisplay(); // Refresh credits too!
                if (typeof updateDashboardGreeting === 'function') updateDashboardGreeting();
            }
        });
    }
})();

// Settings Modal Logic
function openSettingsModal() {
    const modal = document.getElementById('settings-modal');
    if (modal) {
        modal.style.display = 'flex';
        // Small delay for transition
        setTimeout(() => modal.classList.add('active'), 10);
    }
}

function closeSettingsModal(e) {
    // If e is present, it's a click event. Close only if clicking overlay or close button
    const modal = document.getElementById('settings-modal');
    if (modal) {
        modal.classList.remove('active');
        setTimeout(() => modal.style.display = 'none', 300);
    }
}

function switchSettingsTab(tabName) {
    document.querySelectorAll('.settings-nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('onclick').includes(tabName)) item.classList.add('active');
    });

    document.querySelectorAll('.settings-tab').forEach(tab => {
        tab.classList.remove('active');
    });

    document.getElementById(`settings-tab-${tabName}`).classList.add('active');

    // Subscription tab — render plan cards & banner
    if (tabName === 'subscription') {
        if (typeof renderPlanCards === 'function') renderPlanCards();
        if (typeof populateCurrentPlanBanner === 'function') populateCurrentPlanBanner();
    }
}

window.openSettingsModal = openSettingsModal;
window.closeSettingsModal = closeSettingsModal;
window.switchSettingsTab = switchSettingsTab;


function initPageTransitions() {
    // Fade In
    setTimeout(() => {
        document.body.classList.add('loaded');
    }, 10);

    // Handle Links for Fade Out
    document.addEventListener('click', (e) => {
        const link = e.target.closest('a');
        if (!link) return;

        const href = link.getAttribute('href');
        // Ignore internal links, target=_blank, or js calls
        if (!href || href.startsWith('#') || href.startsWith('javascript') || link.target === '_blank') return;

        e.preventDefault();
        document.body.classList.remove('loaded');

        setTimeout(() => {
            window.location.href = href;
        }, 50);
    });
}

// Global sign out handler (used by sidebar nav)
async function handleSignOut(e) {
    if (e) e.preventDefault();
    try {
        if (typeof signOut === 'function') {
            await signOut();
        }
        // Explicitly clear specific user keys, but KEEP preferences like 'tutorialComplete' and 'theme'
        localStorage.removeItem('userName');
        localStorage.removeItem('userTier');
        localStorage.removeItem('subscriptionTier');
        localStorage.removeItem('userUniversity');
        localStorage.removeItem('userEmail');
        // Do NOT remove 'tutorialComplete'
        window.location.href = 'login.html';
    } catch (err) {
        console.error('Sign out error:', err);
        window.location.href = 'login.html';
    }
}


// Toggle profile dropdown menu
function toggleProfileDropdown(event) {
    event.stopPropagation();
    const dropdown = document.getElementById('profile-dropdown');
    dropdown?.classList.toggle('show');
}

// Note: toggleTheme is now handled globally by main.js



// Close dropdown when clicking outside
document.addEventListener('click', (e) => {
    const dropdown = document.getElementById('profile-dropdown');
    const profileInfo = document.querySelector('.profile-compact-info');

    if (dropdown && !profileInfo?.contains(e.target)) {
        dropdown.classList.remove('show');
    }
});

// ─── Settings Logic ───
const AVAILABLE_COLORS = [
    { name: 'Yellow', code: '#FFF3BF', class: 'bg-yellow' },
    { name: 'Green', code: '#D3F9D8', class: 'bg-green' },
    { name: 'Red', code: '#FFD6D6', class: 'bg-red' },
    { name: 'Grey', code: '#CFD8DC', class: 'bg-grey' },
    { name: 'Orange', code: '#FFE0B2', class: 'bg-orange' },
    { name: 'Purple', code: '#E8D5F5', class: 'bg-purple' },
    { name: 'Teal', code: '#C3FAE8', class: 'bg-teal' },
    { name: 'Pink', code: '#FCC2D7', class: 'bg-pink' }
];

const navItems = [
    { id: 'nav-dashboard', icon: 'fa-house', label: 'Chambers', href: 'dashboard' },
    { id: 'nav-modules', icon: 'fa-folder-tree', label: 'My Modules', href: 'modules' },
    { id: 'nav-news', icon: 'fa-newspaper', label: 'Daily Brief', href: 'news' },
    { id: 'nav-community', icon: 'fa-users', label: 'Community Hub', href: 'community' },
    { id: 'nav-leaderboard', icon: 'fa-trophy', label: 'Leaderboard', href: 'leaderboard' },
    { id: 'nav-settings', icon: 'fa-gear', label: 'Settings', href: 'settings' }
];

let selectedColors = [];

function initSettings() {
    // Load saved colors or default to first 3
    const saved = JSON.parse(localStorage.getItem('quickHighlightColors') || 'null');
    if (saved) {
        selectedColors = saved;
    } else {
        selectedColors = AVAILABLE_COLORS.slice(0, 3).map(c => c.code);
    }

    // Load saved language
    const langInfo = JSON.parse(localStorage.getItem('editorLanguage') || '{"code":"en-GB"}');
    const langSelect = document.getElementById('editor-language-select');
    if (langSelect) {
        langSelect.value = langInfo.code;
    }

    renderColorSelection();
}

function renderColorSelection() {
    const grid = document.getElementById('quick-color-grid');
    if (!grid) return;

    grid.innerHTML = '';

    AVAILABLE_COLORS.forEach(color => {
        const el = document.createElement('div');
        el.className = 'color-option ' + (selectedColors.includes(color.code) ? 'selected' : '');
        el.style.backgroundColor = color.code;
        el.title = color.name;
        el.innerHTML = '<i class="fas fa-check"></i>';

        el.onclick = () => toggleColorOption(color.code);

        grid.appendChild(el);
    });
}

function toggleColorOption(code) {
    if (selectedColors.includes(code)) {
        if (selectedColors.length > 1) {
            selectedColors = selectedColors.filter(c => c !== code);
        }
    } else {
        if (selectedColors.length < 3) {
            selectedColors.push(code);
        } else {
            selectedColors.shift();
            selectedColors.push(code);
        }
    }
    renderColorSelection();
}

function saveLanguagePreference() {
    const langSelect = document.getElementById('editor-language-select');
    if (langSelect) {
        const langCode = langSelect.value;
        const langName = langSelect.options[langSelect.selectedIndex].text;
        const langData = { code: langCode, name: langName };
        localStorage.setItem('editorLanguage', JSON.stringify(langData));

        // Return for chaining if needed
        return langData;
    }
    return null;
}

function saveEditorPreferences() {
    // Save Colors
    localStorage.setItem('quickHighlightColors', JSON.stringify(selectedColors));

    // Save Language
    saveLanguagePreference();

    const btn = document.querySelector('#settings-tab-editor .btn-primary');
    if (btn) {
        const originalText = btn.innerText;
        btn.innerHTML = '<i class="fas fa-check"></i> Saved';
        setTimeout(() => btn.innerText = originalText, 1500);
    }

    // Refresh editor settings if on that page
    if (window.applyLanguageSettings) {
        window.applyLanguageSettings();
    }
}

// Expose new functions
window.toggleColorOption = toggleColorOption;
window.saveEditorPreferences = saveEditorPreferences;
window.saveLanguagePreference = saveLanguagePreference;

// Hook into openSettingsModal to init
const originalOpen = window.openSettingsModal;
window.openSettingsModal = function () {
    originalOpen();
    initSettings();
};
