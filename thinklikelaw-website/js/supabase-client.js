/**
 * Supabase Client — Single Source of Truth
 * All pages should include this file for database access.
 *
 * Credentials are loaded from js/site-config.js which should be included BEFORE this script.
 * For Cloudflare Pages, set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.
 */

let SUPABASE_URL, SUPABASE_KEY;

// Initialize config - will be set by site-config.js
if (typeof window !== 'undefined' && window.SITE_CONFIG && window.SITE_CONFIG.supabase) {
  SUPABASE_URL = window.SITE_CONFIG.supabase.url;
  SUPABASE_KEY = window.SITE_CONFIG.supabase.anonKey;
} else {
  // Fallback - should never happen if site-config.js is loaded first
  console.error('Site config not loaded! Make sure js/site-config.js is included before supabase-client.js');
  SUPABASE_URL = 'https://oxlpmgnytsvdjcibtdmb.supabase.co';
  SUPABASE_KEY = 'sb_publishable_hR5BbCbWqj0V7sZP6lpDjg_sMhNg84A';
}

let sb_client = null;
let _supabaseReady = null;

// Returns a promise that resolves when the client is ready
function getSupabaseClient() {
    if (sb_client) return Promise.resolve(sb_client);
    if (_supabaseReady) return _supabaseReady;

    _supabaseReady = new Promise((resolve) => {
        function tryInit() {
            if (typeof supabase !== 'undefined' && supabase.createClient) {
                sb_client = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
                window.supabase = sb_client; // Expose as global instance for other scripts
                console.log('ThinkLikeLaw Supabase Client Initialized');
                resolve(sb_client);
            } else {
                // Inject CDN if missing
                if (!document.querySelector('script[src*="supabase"]')) {
                    const script = document.createElement('script');
                    script.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';
                    script.onload = () => {
                        sb_client = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
                        window.supabase = sb_client; // Expose as global instance
                        console.log('ThinkLikeLaw Supabase Client Initialized (CDN)');
                        resolve(sb_client);
                    };
                    document.head.appendChild(script);
                } else {
                    setTimeout(tryInit, 50);
                }
            }
        }
        tryInit();
    });

    return _supabaseReady;
}

// ── Auth Helpers ──

async function signInWithEmail(email, password) {
    const client = await getSupabaseClient();
    return client.auth.signInWithPassword({ email, password });
}

async function signUpWithEmail(email, password, metadata = {}) {
    const client = await getSupabaseClient();
    return client.auth.signUp({
        email,
        password,
        options: {
            data: metadata
        }
    });
}

async function signInWithGoogle() {
    const client = await getSupabaseClient();
    return client.auth.signInWithOAuth({
        provider: 'google',
        options: {
            redirectTo: window.location.origin + '/dashboard.html'
        }
    });
}

async function signInWithApple() {
    const client = await getSupabaseClient();
    return client.auth.signInWithOAuth({
        provider: 'apple',
        options: {
            redirectTo: window.location.origin + '/dashboard.html'
        }
    });
}

async function resendVerificationEmail(email) {
    const client = await getSupabaseClient();
    return client.auth.resend({
        type: 'signup',
        email: email
    });
}

async function signOut() {
    const client = await getSupabaseClient();
    clearUserCache();
    return client.auth.signOut();
}

/**
 * Wipes all user-specific data from localStorage to prevent privacy leaks
 * between different accounts on the same browser.
 */
function clearUserCache() {
    console.log('Security Wipe: Clearing user cache...');
    const keysToRemove = [
        'userName', 'userEmail', 'userTier', 'subscriptionTier', 'userUniversity',
        'studentLevel', 'llbYear', 'examBoard',
        'thinkCredits', 'creditsLastReset', 'lastOpenedModule', 'customModules',
        'userMetrics', 'savedLectureNotes', 'quickHighlightColors', 'editorLanguage',
        'lastOpenedNote', 'flashcardHistory', 'onboardingCompleted', 'tour_completed'
    ];

    keysToRemove.forEach(key => localStorage.removeItem(key));

    // Also remove any dynamic note content
    for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && (key.startsWith('note-') || key.startsWith('lastResend_'))) {
            localStorage.removeItem(key);
            i--; // Adjust index after removal
        }
    }
}

// ── Session Helpers ──

async function getCurrentSession() {
    const client = await getSupabaseClient();
    const { data: { session } } = await client.auth.getSession();
    return session;
}

async function getCurrentUser() {
    const client = await getSupabaseClient();
    const { data: { user } } = await client.auth.getUser();
    return user;
}

// ── Profile Helpers ──



/**
 * Enhanced Profile Getter with Lazy Hydration
 * If profile doesn't exist (e.g. first login after email confirmation),
 * it creates it using metadata stored in the Auth user object.
 */
async function getUserProfile() {
    const user = await getCurrentUser();
    if (!user) return null;

    const client = await getSupabaseClient();
    let { data, error } = await client
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

    // Sync to localStorage if found
    if (data) {
        localStorage.setItem('userName', [data.first_name, data.last_name].filter(Boolean).join(' '));
        if (data.plan) localStorage.setItem('userTier', data.plan);
        if (data.student_level) localStorage.setItem('studentLevel', data.student_level);
        if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);

        if (data.current_status) localStorage.setItem('userStatus', data.current_status);

        if (data.llb_year) localStorage.setItem('llbYear', data.llb_year);
        if (data.exam_board) localStorage.setItem('examBoard', data.exam_board);
        if (data.school_urn) localStorage.setItem('schoolUrn', data.school_urn);
        if (data.university) {
            localStorage.setItem('onboardingCompleted', 'true');
            localStorage.setItem('userUniversity', data.university);
        }
    }

    let isNewProfile = false;
    // Lazy Hydration: If profile missing, create it from Auth Metadata or Email
    if (!data) {
        isNewProfile = true;
        console.log('Profile missing or empty. Attempting hydration...');

        const metadata = user.user_metadata || {};
        const emailPrefix = user.email ? user.email.split('@')[0] : 'Student';

        const newProfile = {
            id: user.id,
            first_name: metadata.first_name || emailPrefix,
            last_name: metadata.last_name || '',
            university: metadata.university || '',
            target_year: metadata.target_year || metadata.graduation_year || '',
            current_status: metadata.current_status || metadata.student_status || metadata.student_level || 'llb',
            student_level: metadata.student_level || 'llb',
            llb_year: metadata.llb_year || '',
            exam_board: metadata.exam_board || '',
            school_urn: metadata.school_urn || '',
            email: user.email // Keep email for fallback
        };

        const { data: createdProfile, error: createError } = await client
            .from('profiles')
            .upsert(newProfile)
            .select('id, first_name, last_name, university, target_year, current_status, student_level, leaderboard_username, is_anonymous, created_at')
            .single();

        if (createdProfile) {
            console.log('Profile hydrated successfully.');
            data = createdProfile;
            error = null;
            // Sync immediately
            localStorage.setItem('userName', [data.first_name, data.last_name].filter(Boolean).join(' '));
            localStorage.setItem('userTier', data.plan || 'free');
            if (data.student_level) localStorage.setItem('studentLevel', data.student_level);
            if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);
            else if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);

            if (data.student_status) localStorage.setItem('userStatus', data.student_status);
            else if (data.current_status) localStorage.setItem('userStatus', data.current_status);
            if (data.llb_year) localStorage.setItem('llbYear', data.llb_year);
            if (data.exam_board) localStorage.setItem('examBoard', data.exam_board);
            if (data.school_urn) localStorage.setItem('schoolUrn', data.school_urn);
            if (data.university) {
                localStorage.setItem('onboardingCompleted', 'true');
                localStorage.setItem('userUniversity', data.university);
            }
        } else {
            console.error('Failed to hydrate profile:', createError);
        }
    }

    return { data, error, user, isNewProfile };
}

async function upsertProfile(userId, profileData) {
    const client = await getSupabaseClient();
    return client
        .from('profiles')
        .upsert({ id: userId, ...profileData }, { onConflict: 'id' })
        .select('id');
}

// ── Module Helpers ──

async function getModules() {
    const client = await getSupabaseClient();
    return client.from('modules').select('*');
}

async function getUserModules(userId) {
    const client = await getSupabaseClient();
    return client
        .from('user_modules')
        .select('*, module:modules(*)')
        .eq('user_id', userId);
}

// ── Auth Guard (for protected pages) ──

async function requireAuth() {
    const session = await getCurrentSession();
    if (!session) {
        window.location.href = 'login.html';
        return null;
    }
    return session;
}

// ── Auth State Listener ──

async function onAuthStateChange(callback) {
    const client = await getSupabaseClient();
    client.auth.onAuthStateChange(async (event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
            const lastUid = localStorage.getItem('last_user_id');
            if (lastUid && lastUid !== session.user.id) {
                console.log('User change detected. Clearing stale data.');
                clearUserCache();
            }
            localStorage.setItem('last_user_id', session.user.id);
        }
        if (event === 'SIGNED_OUT') {
            clearUserCache();
            localStorage.removeItem('last_user_id');
        }
        if (callback) callback(event, session);
    });
}

// ── Leaderboard & Study Time (New) ──

async function updateUserStudyTime(minutesToAdd) {
    try {
        const client = await getSupabaseClient();
        const { data, error } = await client.rpc('increment_study_metrics', { p_minutes: minutesToAdd });

        if (error) throw error;
        
        // Sync updated metrics to localStorage
        if (data) {
            const metrics = JSON.parse(localStorage.getItem('userMetrics') || '{}');
            metrics.studyTime = data.study_time;
            metrics.lifetimeStudyTime = data.lifetime_study_time;
            metrics.streak = data.streak;
            localStorage.setItem('userMetrics', JSON.stringify(metrics));
        }

        console.log('Supabase: Study metrics updated via RPC', data);
    } catch (e) {
        console.warn('Supabase: Could not update study time via RPC', e);
    }
}

async function getLeaderboard() {
    try {
        const client = await getSupabaseClient();
        const { data, error } = await client
            .from('profiles')
            .select('id, first_name, last_name, university')
            .limit(10);

        if (error) throw error;
        return data || [];
    } catch (e) {
        console.warn('Supabase: Could not fetch leaderboard', e);
        return [];
    }
}

// ── Email Verification (Verifalia) ──

async function verifyEmail(email) {
    console.log(`[Verifalia] verifying email: ${email}`);
    // Placeholder logic
    // In production: call your backend which calls Verifalia
    // const response = await fetch('/api/verify-email', { method: 'POST', body: JSON.stringify({ email }) });

    // For now, simulate API call
    return new Promise(resolve => {
        setTimeout(() => {
            // Mock validation
            const isValid = email.includes('@') && email.includes('.');
            resolve({
                valid: isValid,
                classification: isValid ? 'Deliverable' : 'Undeliverable',
                message: isValid ? 'Email is valid' : 'Invalid email format'
            });
        }, 800);
    });
}

// Sync user profile to localStorage for sidebar display
async function syncProfileToLocalStorage() {
    try {
        const result = await getUserProfile();
        if (result && result.user) {
            localStorage.setItem('userEmail', result.user.email);
        }
        if (result && result.data) {
            const profile = result.data;
            let fullName = [profile.first_name, profile.last_name].filter(Boolean).join(' ');

            // Fallback to email prefix if name is truly missing
            if (!fullName && result.user) {
                fullName = result.user.email.split('@')[0];
            }

            if (fullName) localStorage.setItem('userName', fullName);

            // Mark as onboarded if essential profile data exists
            if (profile.university || profile.target_year || profile.current_status || profile.student_level) {
                localStorage.setItem('onboardingCompleted', 'true');
                if (profile.university) localStorage.setItem('userUniversity', profile.university);

                const gradYear = profile.target_year;
                if (gradYear) localStorage.setItem('userTargetYear', gradYear);

                const status = profile.student_status || profile.current_status;
                if (status) {
                    localStorage.setItem('userStatus', status);
                    localStorage.setItem('userType', status.toUpperCase());
                }

                if (profile.student_level) localStorage.setItem('studentLevel', profile.student_level);
                if (profile.llb_year) localStorage.setItem('llbYear', profile.llb_year);
                if (profile.exam_board) localStorage.setItem('examBoard', profile.exam_board);
                if (profile.school_urn) localStorage.setItem('schoolUrn', profile.school_urn);
            }

            // Ping activity for admin tracking
            if (typeof CloudData !== 'undefined') {
                CloudData.updateActiveStatus().catch(() => { });
            }
        }
    } catch (e) {
        console.warn('Could not sync profile:', e);
    }
}

// Note: Lecture and Module CRUD functions have been moved to js/cloud-data.js for centralized error handling and sync logic.
