(function () {
    function initCookieBanner() {
        // Don't show if already accepted/rejected
        if (localStorage.getItem('cookie_consent')) return;

        const bannerHTML = `
            <div id="cookie-banner" class="cookie-banner">
                <div class="cookie-content">
                    <div class="cookie-header">
                        <i class="fas fa-cookie-bite"></i>
                        <h3>We care about your privacy</h3>
                    </div>
                    <p>
                        This website uses cookies that are needed for the site to work properly 
                        and to get data on how you interact with it. By clicking "Accept all", 
                        you agree to our use of cookies for a personalized experience as described 
                        in our <a href="privacy-policy">Cookie Policy</a>.
                    </p>
                    <div class="cookie-actions">
                        <button id="cookie-accept" class="btn-cookie-primary">Accept all</button>
                        <button id="cookie-reject" class="btn-cookie-secondary">Reject all</button>
                        <button id="cookie-settings-btn" class="cookie-settings-link" style="background:none; border:none; cursor:pointer;">Cookie settings</button>
                    </div>
                </div>

                <!-- Granular Settings Modal (Hidden by default) -->
                <div id="cookie-settings-panel" class="cookie-settings-panel">
                    <div class="settings-header">
                        <h4>Cookie Settings</h4>
                        <button id="close-cookie-settings" class="close-btn">&times;</button>
                    </div>
                    <div class="settings-body">
                        <div class="setting-item">
                            <div class="setting-info">
                                <strong>Strictly Necessary</strong>
                                <p>Essential for the website to function. Cannot be switched off.</p>
                            </div>
                            <div class="setting-toggle">
                                <label class="switch">
                                    <input type="checkbox" checked disabled>
                                    <span class="slider round"></span>
                                </label>
                            </div>
                        </div>
                        <div class="setting-item">
                            <div class="setting-info">
                                <strong>Analytics & Performance</strong>
                                <p>Help us understand how visitors interact with the site.</p>
                            </div>
                            <div class="setting-toggle">
                                <label class="switch">
                                    <input type="checkbox" id="cookies-analytics" checked>
                                    <span class="slider round"></span>
                                </label>
                            </div>
                        </div>
                        <div class="setting-item">
                            <div class="setting-info">
                                <strong>Marketing & Personalization</strong>
                                <p>Used to provide a more relevant experience and track ad effectiveness.</p>
                            </div>
                            <div class="setting-toggle">
                                <label class="switch">
                                    <input type="checkbox" id="cookies-marketing">
                                    <span class="slider round"></span>
                                </label>
                            </div>
                        </div>
                    </div>
                    <div class="settings-footer">
                        <button id="save-cookie-preferences" class="btn-cookie-primary">Save Preferences</button>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', bannerHTML);

        const banner = document.getElementById('cookie-banner');
        const settingsPanel = document.getElementById('cookie-settings-panel');
        const acceptBtn = document.getElementById('cookie-accept');
        const rejectBtn = document.getElementById('cookie-reject');
        const settingsBtn = document.getElementById('cookie-settings-btn');
        const closeSettingsBtn = document.getElementById('close-cookie-settings');
        const savePrefsBtn = document.getElementById('save-cookie-preferences');

        // Small delay for animation
        setTimeout(() => banner.classList.add('active'), 1000);

        acceptBtn.addEventListener('click', () => {
            saveConsent({
                all: true,
                analytics: true,
                marketing: true
            });
        });

        rejectBtn.addEventListener('click', () => {
            saveConsent({
                all: false,
                analytics: false,
                marketing: false
            });
        });

        settingsBtn.addEventListener('click', (e) => {
            e.preventDefault();
            settingsPanel.classList.toggle('active');
        });

        closeSettingsBtn.addEventListener('click', () => {
            settingsPanel.classList.remove('active');
        });

        savePrefsBtn.addEventListener('click', () => {
            saveConsent({
                all: false,
                analytics: document.getElementById('cookies-analytics').checked,
                marketing: document.getElementById('cookies-marketing').checked
            });
        });

        function saveConsent(prefs) {
            const consentData = {
                timestamp: new Date().toISOString(),
                ...prefs
            };
            localStorage.setItem('cookie_consent', JSON.stringify(consentData));

            // Trigger Google Consent Mode Update
            updateGtagConsent(prefs);

            hideBanner();
        }

        function updateGtagConsent(prefs) {
            if (typeof gtag !== 'function') return;

            gtag('consent', 'update', {
                'ad_storage': prefs.marketing ? 'granted' : 'denied',
                'ad_user_data': prefs.marketing ? 'granted' : 'denied',
                'ad_personalization': prefs.marketing ? 'granted' : 'denied',
                'analytics_storage': prefs.analytics ? 'granted' : 'denied'
            });
        }

        function hideBanner() {
            banner.classList.remove('active');
            setTimeout(() => banner.remove(), 400);
        }

        // Check for existing consent on load
        const savedConsent = localStorage.getItem('cookie_consent');
        if (savedConsent) {
            try {
                const prefs = JSON.parse(savedConsent);
                updateGtagConsent(prefs);
            } catch (e) {
                console.error('Error parsing saved consent:', e);
            }
        }
    }

    // Load when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initCookieBanner);
    } else {
        initCookieBanner();
    }
})();
