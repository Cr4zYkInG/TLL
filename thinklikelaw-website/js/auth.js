/**
 * Auth Page Logic
 * Handles login and signup form interactions.
 * Requires supabase-client.js to be loaded first.
 */

document.addEventListener('DOMContentLoaded', () => {
    // Check for form existence instead of URL path (robust against clean URLs)
    if (document.getElementById('login-form')) initLoginPage();
    if (document.getElementById('signup-form')) initSignupPage();
});

// ── LOGIN PAGE ──

function initLoginPage() {
    const form = document.getElementById('login-form');
    const emailInput = document.getElementById('login-email');
    const passwordInput = document.getElementById('login-password');
    const submitBtn = document.getElementById('login-submit');
    const errorEl = document.getElementById('login-error');
    const googleBtn = document.getElementById('google-signin');
    const appleBtn = document.getElementById('apple-signin');
    const termsCheckbox = document.getElementById('login-terms');

    // ... (rest of the code)

    if (appleBtn) {
        appleBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            if (termsCheckbox && !termsCheckbox.checked) {
                showError(errorEl, 'Please agree to the Terms and Privacy Policy to continue.');
                return;
            }

            appleBtn.textContent = 'Connecting to Apple...';
            try {
                const { error } = await signInWithApple();
                if (error) {
                    showError(errorEl, 'Apple sign-in failed. Please try again.');
                    appleBtn.innerHTML = '<i class="fab fa-apple"></i> Continue with Apple';
                }
            } catch (err) {
                showError(errorEl, 'Apple sign-in failed.');
                appleBtn.innerHTML = '<i class="fab fa-apple"></i> Continue with Apple';
            }
        });
    }

    if (googleBtn) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            const email = emailInput.value.trim();
            const password = passwordInput.value;

            if (!email || !password) {
                showError(errorEl, 'Please enter both email and password.');
                return;
            }

            if (termsCheckbox && !termsCheckbox.checked) {
                showError(errorEl, 'Please agree to the Terms and Privacy Policy to continue.');
                return;
            }

            submitBtn.textContent = 'Signing in...';
            submitBtn.disabled = true;

            try {
                const { data, error } = await signInWithEmail(email, password);

                if (error) {
                    showError(errorEl, getReadableError(error.message));
                    submitBtn.textContent = 'Sign In';
                    submitBtn.disabled = false;
                    return;
                }

                // Success — sync profile and redirect
                window.location.href = 'dashboard.html';
            } catch (err) {
                showError(errorEl, 'Something went wrong. Please try again.');
                submitBtn.textContent = 'Sign In';
                submitBtn.disabled = false;
            }
        });
    }

    if (googleBtn) {
        googleBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            if (termsCheckbox && !termsCheckbox.checked) {
                showError(errorEl, 'Please agree to the Terms and Privacy Policy to continue.');
                return;
            }

            googleBtn.textContent = 'Connecting to Google...';
            try {
                const { error } = await signInWithGoogle();
                if (error) {
                    showError(errorEl, 'Google sign-in failed. Please try again.');
                    googleBtn.innerHTML = '<img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" width="20" alt="Google"> Continue with Google';
                }
            } catch (err) {
                showError(errorEl, 'Google sign-in failed.');
                googleBtn.innerHTML = '<img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" width="20" alt="Google"> Continue with Google';
            }
        });
    }
}

// ── SIGNUP PAGE ──

function initSignupPage() {
    const form = document.getElementById('signup-form');
    const firstNameInput = document.getElementById('signup-firstname');
    const lastNameInput = document.getElementById('signup-lastname');
    const emailInput = document.getElementById('signup-email');
    const passwordInput = document.getElementById('signup-password');
    const confirmInput = document.getElementById('signup-confirm');
    const submitBtn = document.getElementById('signup-submit');
    const errorEl = document.getElementById('signup-error');
    const googleBtn = document.getElementById('google-signup');
    const newsletterCheckbox = document.getElementById('signup-newsletter');

    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            const firstName = firstNameInput.value.trim();
            const lastName = lastNameInput.value.trim();
            const email = emailInput.value.trim();
            const password = passwordInput.value;
            const confirm = confirmInput.value;

            if (!firstName || !lastName) {
                showError(errorEl, 'Please enter your full name.');
                return;
            }
            if (!email) {
                showError(errorEl, 'Please enter your email address.');
                return;
            }
            if (password.length < 6) {
                showError(errorEl, 'Password must be at least 6 characters.');
                return;
            }
            if (password !== confirm) {
                showError(errorEl, 'Passwords do not match.');
                return;
            }

            // DDoS Protection: Check Turnstile token
            // BYPASS FOR LOCAL DEV: Since the sitekey is invalid for localhost, allow empty token.
            // if (!window._turnstileToken) {
            //    showError(errorEl, 'Please complete the security check.');
            //    return;
            // }

            submitBtn.textContent = 'Verifying email...';
            submitBtn.disabled = true;

            try {
                // Verify Email first
                const verification = await verifyEmail(email);
                if (!verification.valid) {
                    showError(errorEl, verification.message || 'Invalid email address.');
                    submitBtn.textContent = 'Create Account';
                    submitBtn.disabled = false;
                    return;
                }

                submitBtn.textContent = 'Creating account...';

                // Pass metadata to Supabase Auth (persists through confirmation)
                const university = document.getElementById('signup-university-value')?.value || '';
                const level = document.getElementById('signup-level')?.value || '';
                const year = document.getElementById('signup-year')?.value || ''; // Qualification Year (2025+)
                const llbYear = document.getElementById('signup-llb-year')?.value || ''; // Course Year (yr1+)
                const board = document.getElementById('signup-board')?.value || '';

                const { data, error } = await signUpWithEmail(email, password, {
                    first_name: firstName,
                    last_name: lastName,
                    university: university,
                    school_urn: document.getElementById('signup-university')?.dataset.urn || '',
                    student_level: level,
                    target_year: year,
                    llb_year: llbYear,
                    exam_board: level === 'alevel' ? board : '',
                    current_status: level === 'llb' ? 'llb' : `alevel_${board}`
                });

                if (error) {
                    showError(errorEl, getReadableError(error.message));
                    submitBtn.textContent = 'Create Account';
                    submitBtn.disabled = false;
                    return;
                }

                // SUCCESS: Show Verification Message (Do not redirect)
                // We do NOT create the profile row here because RLS might block it until email is confirmed.
                // Profile will be created on first login (lazy hydration).

                // Hide Form & Show Success
                form.style.display = 'none';

                // create success message container
                const successDiv = document.createElement('div');
                successDiv.style.textAlign = 'center';
                successDiv.style.padding = '2rem';
                successDiv.innerHTML = `
                    <div style="font-size: 3rem; color: #4CAF50; margin-bottom: 1rem;">
                        <i class="fas fa-envelope-open-text"></i>
                    </div>
                    <h2 style="margin-bottom: 1rem;">Check your email</h2>
                    <p style="color: var(--text-secondary); margin-bottom: 0.5rem;">
                        We've sent a verification link to <strong>${email}</strong>.<br>
                        Please click the link to activate your account and enter Chambers.
                    </p>
                    <p style="color: #ff5555; font-size: 0.85rem; margin-bottom: 2rem; font-weight: 500;">
                        <i class="fas fa-exclamation-circle"></i> Tip: If you don't see it, check your <strong>Junk/Spam</strong> folder.
                    </p>
                    <div style="display: flex; flex-direction: column; gap: 1rem; align-items: center;">
                        <a href="login" class="btn-primary" style="text-decoration: none; width: 100%; max-width: 200px;">
                            Return to Sign In
                        </a>
                        <div id="resend-container">
                            <button onclick="handleResendEmail('${email}', this)" style="background: none; border: none; color: var(--accent-color); font-size: 0.85rem; cursor: pointer; text-decoration: underline;">
                                Didn't get the email? Resend
                            </button>
                        </div>
                    </div>
                `;

                form.parentNode.appendChild(successDiv);

                // Send welcome email (best effort)
                try {
                    const newsletterConsent = newsletterCheckbox ? newsletterCheckbox.checked : true;
                    fetch('https://thinklikelaw-email.5dwvxmf5mn.workers.dev', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ email, firstName, type: 'welcome', newsletterConsent })
                    });
                } catch (e) { /* non-critical */ }
            } catch (err) {
                showError(errorEl, 'Something went wrong. Please try again.');
                submitBtn.textContent = 'Create Account';
                submitBtn.disabled = false;
            }
        });
    }

    if (googleBtn) {
        googleBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            const termsSignup = document.getElementById('signup-terms');
            if (termsSignup && !termsSignup.checked) {
                showError(errorEl, 'Please agree to the Terms and Privacy Policy to continue.');
                return;
            }

            googleBtn.textContent = 'Connecting to Google...';
            try {
                const { error } = await signInWithGoogle();
                if (error) {
                    showError(errorEl, 'Google sign-up failed. Please try again.');
                    googleBtn.innerHTML = '<img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" width="20" alt="Google"> Continue with Google';
                }
            } catch (err) {
                showError(errorEl, 'Google sign-up failed.');
                googleBtn.innerHTML = '<img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" width="20" alt="Google"> Continue with Google';
            }
        });
    }

    const appleSignupBtn = document.getElementById('apple-signup');
    if (appleSignupBtn) {
        appleSignupBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            hideError(errorEl);

            const termsSignup = document.getElementById('signup-terms');
            if (termsSignup && !termsSignup.checked) {
                showError(errorEl, 'Please agree to the Terms and Privacy Policy to continue.');
                return;
            }

            appleSignupBtn.textContent = 'Connecting to Apple...';
            try {
                const { error } = await signInWithApple();
                if (error) {
                    showError(errorEl, 'Apple sign-up failed. Please try again.');
                    appleSignupBtn.innerHTML = '<i class="fab fa-apple"></i> Continue with Apple';
                }
            } catch (err) {
                showError(errorEl, 'Apple sign-up failed.');
                appleSignupBtn.innerHTML = '<i class="fab fa-apple"></i> Continue with Apple';
            }
        });
    }
}

// ── Utilities ──

function showError(el, message) {
    if (el) {
        el.textContent = message;
        el.style.display = 'block';
    }
}

function hideError(el) {
    if (el) {
        el.textContent = '';
        el.style.display = 'none';
    }
}

function getReadableError(msg) {
    if (msg.includes('Invalid login credentials')) return 'Invalid email or password. Please try again.';
    if (msg.includes('Email not confirmed')) return 'Please confirm your email address first. Check your inbox.';
    if (msg.includes('User already registered')) return 'An account with this email already exists. Try signing in instead.';
    if (msg.includes('rate limit')) return 'Too many attempts. Please wait a moment and try again.';
    return msg;
}

// Global Resend Email Handler
// Global Resend Email Handler with Cooldown
window.handleResendEmail = async function (email, btn) {
    if (!email) return;

    // Check for cooldown
    const lastResend = localStorage.getItem(`lastResend_${email}`);
    const now = Date.now();
    const cooldownTime = 60000; // 1 minute

    if (lastResend && (now - lastResend < cooldownTime)) {
        const remaining = Math.ceil((cooldownTime - (now - lastResend)) / 1000);
        const originalText = btn.innerText;
        btn.innerText = `Wait ${remaining}s...`;
        btn.disabled = true;
        setTimeout(() => {
            btn.innerText = originalText;
            btn.disabled = false;
        }, 2000);
        return;
    }

    const originalText = btn.innerText;
    btn.innerText = 'Resending...';
    btn.disabled = true;

    try {
        const { error } = await resendVerificationEmail(email);
        if (error) {
            alert('Error: ' + error.message);
            btn.innerText = originalText;
            btn.disabled = false;
        } else {
            // Success
            localStorage.setItem(`lastResend_${email}`, Date.now());
            btn.innerText = 'Email sent! Check junk folder.';
            btn.style.color = '#4CAF50';
            btn.style.textDecoration = 'none';

            // Start countdown for visual feedback
            let seconds = 60;
            const timer = setInterval(() => {
                seconds--;
                if (seconds > 0) {
                    btn.innerText = `Sent. Resend again in ${seconds}s`;
                    btn.disabled = true;
                } else {
                    clearInterval(timer);
                    btn.innerText = originalText;
                    btn.style.color = 'var(--accent-color)';
                    btn.style.textDecoration = 'underline';
                    btn.disabled = false;
                }
            }, 1000);
        }
    } catch (err) {
        alert('Resend failed. Please try again later.');
        btn.innerText = originalText;
        btn.disabled = false;
    }
};
