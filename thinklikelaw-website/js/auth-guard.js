/**
 * Auth Guard
 * Protects pages from unauthorized access and manages onboarding redirects.
 * Usage: Include this script in the <head> of all protected pages.
 */
(async function () {
    const path = window.location.pathname;
    // Handle clean URLs (e.g. /dashboard rather than /dashboard.html)
    let pageName = path.substring(path.lastIndexOf('/') + 1);
    if (!pageName || pageName === '/') pageName = 'index.html';
    if (!pageName.includes('.')) pageName += '.html';

    // Whitelist of public pages (no auth required to VIEW)
    const publicPages = [
        'login.html',
        'signup.html',
        'index.html',
        'onboarding.html',
        'tutorial.html',
        'terms.html',
        'privacy-policy.html',
        'contact.html'
    ];
    // SESSION CHECK
    const checkSession = async () => {
        try {
            // Wait for Supabase Client Helper to be available (if loaded async)
            let retries = 0;
            const maxRetries = 20; // 1 second total
            while (typeof getSupabaseClient !== 'function' && retries < maxRetries) {
                await new Promise(r => setTimeout(r, 50));
                retries++;
            }

            if (typeof getSupabaseClient !== 'function') {
                console.error('AuthGuard: getSupabaseClient still not defined after retries. Scripts missing?');
                return;
            }

            const client = await getSupabaseClient();
            if (!client) {
                console.error('AuthGuard: Supabase client failed to initialize.');
                return;
            }

            const { data: { session } } = await client.auth.getSession();

            // ── NO SESSION ──
            if (!session) {
                // If on a protected page, redirect to login
                if (!publicPages.includes(pageName)) {
                    console.log('AuthGuard: Protected page. Redirecting to login.');
                    sessionStorage.setItem('redirect_after_login', window.location.href);
                    window.location.href = 'login.html';
                }
                return;
            }

            // ── HAS SESSION ──
            console.log('AuthGuard: Session valid.', session.user.email);

            // A. If on landing, login/signup but logged in, go to dashboard
            if (pageName === 'index.html' || pageName === 'login.html' || pageName === 'signup.html') {
                console.log('AuthGuard: Logged in. Redirecting to dashboard.');
                window.location.href = 'dashboard.html';
                return;
            }

            // B. --- ONBOARDING & PROFILE CHECK ---
            const onboardingDone = localStorage.getItem('onboardingCompleted');
            let profileData = null;
            let isNewProfile = false;

            if (onboardingDone !== 'true') {
                // Fetch profile to see if it's actually done (e.g. first login on this device)
                if (typeof getUserProfile === 'function') {
                    const result = await getUserProfile();
                    profileData = result?.data;
                    isNewProfile = result?.isNewProfile || false;
                }
            }

            // A profile is complete if they've finished onboarding locally 
            // OR if they have a university set in the DB
            // OR if they are an EXISTING user (not a new profile hydrated in this session).
            // This prevents forcing old users who logged in before the onboarding feature was added.
            const isProfileComplete = onboardingDone === 'true' ||
                (profileData && profileData.university) ||
                (profileData && !isNewProfile) ||
                (profileData && profileData.first_name && profileData.first_name !== 'Student');

            if (isProfileComplete) {
                // Persistent Sync: Ensure flag is in LS if we found it in DB
                if (onboardingDone !== 'true') {
                    console.log('AuthGuard: Updating local onboarding flag.');
                    localStorage.setItem('onboardingCompleted', 'true');
                    // Existing user hydrating their session -> Skip tutorial automatically
                    localStorage.setItem('tutorialComplete', 'true');
                    if (profileData && profileData.university) localStorage.setItem('userUniversity', profileData.university);
                }

                // If they are on onboarding.html but ARE complete, redirect AWAY to Dashboard
                if (pageName === 'onboarding.html') {
                    console.log('AuthGuard: Profile complete. Redirecting away from onboarding.');
                    window.location.href = 'dashboard.html';
                }
            } else {
                // Profile NOT complete.
                // If they are NOT on onboarding.html/tutorial.html, redirect TO onboarding
                if (pageName !== 'onboarding.html' && pageName !== 'tutorial.html') {
                    console.log('AuthGuard: Profile incomplete. Redirecting to onboarding.');
                    window.location.href = 'onboarding.html';
                }
            }

        } catch (err) {
            console.error('AuthGuard: Error during session check:', err);
        }
    };

    // Run check
    checkSession();

})();
