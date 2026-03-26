// Landing Page Logic (index.html)
// Auth functions are in js/supabase-client.js — do NOT duplicate here.

// --- Global Loading Screen ---
(function () {
    // Inject global loader before page finishes loading
    if (document.readyState === 'loading') {
        const loader = document.createElement('div');
        loader.id = 'global-loader';
        loader.innerHTML = '<img src="images/logo-icon-final.png" alt="Loading...">';
        document.documentElement.appendChild(loader);

        window.addEventListener('load', () => {
            loader.classList.add('fade-out');
            setTimeout(() => {
                if (loader.parentNode) loader.remove();
            }, 600);
        });
    }
})();

// Typewriter Effect (Reusable, with generation-token cancellation)
// Each element gets a generation counter; old loops self-terminate.
const _twGen = {};   // generation counter per element ID
const _twTmr = {};   // active timer per element ID

function initTypewriter(elementId, phrases, options = {}) {
    const el = document.getElementById(elementId);
    if (!el) return;

    // Bump generation — any older loop for this element will stop itself
    if (_twTmr[elementId]) clearTimeout(_twTmr[elementId]);
    const gen = (_twGen[elementId] = (_twGen[elementId] || 0) + 1);

    let pi = 0;   // phrase index
    let ci = 0;   // char index
    let del = false;

    // Voice Narration
    const canSpeak = options.speak && 'speechSynthesis' in window;
    let lastSpoken = -1;

    function speak(text) {
        if (!canSpeak) return;
        window.speechSynthesis.cancel();
        const u = new SpeechSynthesisUtterance(text);
        const voices = window.speechSynthesis.getVoices();
        const v = voices.find(v => v.name.includes('Daniel') || v.name.includes('Google UK English Male'))
            || voices.find(v => v.name.includes('Alex'))
            || voices.find(v => v.name.includes('Male'))
            || voices[0];
        if (v) u.voice = v;
        u.rate = 0.9; u.pitch = 0.95; u.volume = 0.8;
        window.speechSynthesis.speak(u);
    }

    function tick() {
        // ABORT if a newer instance was started for this element
        if (gen !== _twGen[elementId]) return;

        if (pi >= phrases.length) pi = 0;
        const phrase = phrases[pi];

        if (del) {
            ci--;
            el.textContent = phrase.substring(0, ci);
        } else {
            ci++;
            el.textContent = phrase.substring(0, ci);
            if (ci === 1 && pi !== lastSpoken && window.isAudioEnabled) {
                speak(phrase);
                lastSpoken = pi;
            }
        }

        let speed = del ? 30 : 80;
        if (!del && ci === phrase.length) { del = true; speed = 2000; }
        else if (del && ci === 0) { del = false; pi++; speed = 500; }

        _twTmr[elementId] = setTimeout(tick, speed);
    }

    if (canSpeak) {
        window.speechSynthesis.getVoices();
        if (window.speechSynthesis.onvoiceschanged !== undefined)
            window.speechSynthesis.onvoiceschanged = window.speechSynthesis.getVoices;
    }

    tick();
}

// Initialize on Load
document.addEventListener('DOMContentLoaded', () => {

    // 1. Reveal Body (Fix for blank page)
    requestAnimationFrame(() => {
        document.body.classList.add('loaded');
    });

    // 2. Initialize Typewriters (Check if element exists)
    // Skip if mode toggle exists — initModeToggle() will handle it
    const hasModeTgl = document.getElementById('mode-toggle');

    // Hero Typewriter (Top)
    if (document.getElementById('hero-typewriter') && !hasModeTgl) {
        initTypewriter('hero-typewriter', [
            'Master Your Law Degree.',
            'Optimise Your Notes.',
            'Ace Your Exams.',
            'Spot Legal Issues.',
            'Think Like A Lawyer.'
        ], { speak: true });
    }

    // Audio Enable Logic (Browser standard: speech needs a gesture)
    window.isAudioEnabled = false;
    const audioToggle = document.getElementById('audio-narration-btn');

    if (audioToggle) {
        audioToggle.addEventListener('click', () => {
            window.isAudioEnabled = !window.isAudioEnabled;
            audioToggle.classList.toggle('active');
            const icon = audioToggle.querySelector('i');
            if (icon) {
                icon.className = window.isAudioEnabled ? 'fas fa-volume-up' : 'fas fa-volume-mute';
            }

            // If just enabled, speak the current phrase immediately
            if (window.isAudioEnabled) {
                // Try to find the hero typewriter and trigger speech
                const heroText = document.getElementById('hero-typewriter')?.textContent;
                if (heroText && 'speechSynthesis' in window) {
                    const utterance = new SpeechSynthesisUtterance(heroText);
                    window.speechSynthesis.speak(utterance);
                }
            } else {
                window.speechSynthesis.cancel();
            }
        });
    }

    // Problem/Solution Typewriter (Bottom)
    if (document.getElementById('typewriter') && !hasModeTgl) {
        initTypewriter('typewriter', [
            'Summarise Case Law',
            'Generate Flashcards',
            'Spot Legal Issues',
            'Mark Your Essays',
            'Ace Your Exams'
        ]);
    }

    // 3. Theme Toggle Logic
    const toggleBtns = document.querySelectorAll('#theme-toggle, #lp-theme-toggle, .theme-toggle-btn, #theme-toggle-bar');

    function setTheme(theme) {
        const isDark = theme === 'dark';
        
        // Add transition class for smooth switching, then remove after animation
        document.body.classList.add('theme-transitioning');
        setTimeout(() => document.body.classList.remove('theme-transitioning'), 400);

        if (isDark) {
            document.body.classList.add('dark-mode');
            localStorage.setItem('theme', 'dark');
        } else {
            document.body.classList.remove('dark-mode');
            localStorage.setItem('theme', 'light');
        }

        // Update all theme toggle icons (lucide-based)
        document.querySelectorAll('#lp-theme-toggle i[data-lucide], #theme-toggle i[data-lucide]').forEach(icon => {
            icon.setAttribute('data-lucide', isDark ? 'sun' : 'moon');
        });
        // Also update FontAwesome-based icons (sidebar dashboard)
        document.querySelectorAll('#theme-toggle i.fas, #theme-icon').forEach(icon => {
            icon.className = isDark ? 'fas fa-sun' : 'fas fa-moon';
        });
        // Re-render lucide icons after attribute change
        if (typeof lucide !== 'undefined') lucide.createIcons();

        // Update Dashboard Specifics (Sidebar)
        const themeText = document.getElementById('theme-text');
        if (themeText) themeText.textContent = isDark ? 'Dark Mode' : 'Light Mode (Modern)';

        const themeSwitch = document.getElementById('theme-switch');
        if (themeSwitch) {
            if (isDark) themeSwitch.classList.add('active');
            else themeSwitch.classList.remove('active');
        }

        // Update Logos
        if (typeof window.updateLogos === 'function') {
            window.updateLogos(isDark);
        }
    }

    // Global toggle function (can be called by onclick="toggleTheme()")
    window.toggleTheme = function (event) {
        if (event) event.stopPropagation();
        const isDark = document.body.classList.contains('dark-mode');
        setTheme(isDark ? 'light' : 'dark');
    };

    // Check local storage or system preference
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
        setTheme(savedTheme);
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        setTheme('dark');
    }

    // Add listeners to all detected toggle buttons
    toggleBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            window.toggleTheme(e);
        });
    });

    // Global function to update logos based on theme
    window.updateLogos = function (isDarkMode) {
        const textLogoSrc = isDarkMode ? 'images/logo-text-final.png' : 'images/logo-text-dark.png';
        const iconLogoSrc = isDarkMode ? 'images/logo-icon-final.png' : 'images/logo-icon-dark.png';

        // Update Text & Icon Logos across the site
        document.querySelectorAll('.sidebar-logo img, .lp-nav-logo img, .auth-logo img, .footer-logo-img, .logo img').forEach(img => {
            const src = img.getAttribute('src') || '';
            const isIcon = src.includes('icon') || (img.alt && img.alt.toLowerCase().includes('icon'));

            if (isIcon) {
                img.src = iconLogoSrc;
            } else {
                img.src = textLogoSrc;
            }
        });
    };

    // Initialize Logos
    updateLogos(document.body.classList.contains('dark-mode'));

    // 3.5 Update Dynamic Stats (Not Lying anymore!)
    updatePlatformStats();

    // 4. Smooth Scroll
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // 6. Navbar + Banner Scroll Effect
    const lpNav = document.querySelector('.lp-nav');
    const banner = document.querySelector('.early-access-banner');
    const bannerH = parseInt(getComputedStyle(document.body).getPropertyValue('--banner-h'), 10) || 36;

    // Scroll-direction tracking (mirrors Theme Inspiration Header.js)
    let prevScrollY = 0;

    const updateNav = () => {
        if (!lpNav) return;
        const scrollY = window.scrollY;
        const navHeight = lpNav.offsetHeight + 200;

        if (scrollY >= bannerH) {
            // Banner fully scrolled out — nav goes full-width at top:0
            if (banner) {
                banner.style.transform = `translateY(-${bannerH}px)`;
                banner.style.opacity = '0';
                banner.style.pointerEvents = 'none';
            }
            lpNav.classList.add('scrolled');
            lpNav.style.top = '';  // CSS handles top:0 in .scrolled

            // Hide-on-scroll-down / show-on-scroll-up (Theme Inspiration pattern)
            if (scrollY > navHeight) {
                if (scrollY > prevScrollY) {
                    // Scrolling down — hide nav
                    lpNav.classList.add('unpinned');
                } else {
                    // Scrolling up — show nav
                    lpNav.classList.remove('unpinned');
                }
            } else {
                lpNav.classList.remove('unpinned');
            }
        } else {
            // Banner sliding — nav pill tracks right below banner
            if (banner) {
                banner.style.transform = `translateY(-${scrollY}px)`;
                banner.style.opacity = '';
                banner.style.pointerEvents = '';
            }
            lpNav.classList.remove('scrolled');
            lpNav.classList.remove('unpinned');
            lpNav.style.top = `${bannerH - scrollY}px`;
        }

        prevScrollY = scrollY;

        // Scroll Progress Bar
        const height = document.documentElement.scrollHeight - window.innerHeight;
        const progress = (scrollY / height) * 100;
        const progressBar = document.getElementById('progress-bar');
        if (progressBar) progressBar.style.width = progress + '%';
    };

    window.addEventListener('scroll', updateNav, { passive: true });
    updateNav(); // Run once on load

    // 7. Try Prompt Gallery Logic
    document.querySelectorAll('.btn-prompt-try').forEach(btn => {
        btn.addEventListener('click', () => {
            const promptText = btn.parentElement.querySelector('.prompt-text')?.textContent;
            if (promptText && typeof MascotBrain !== 'undefined') {
                const cleanPrompt = promptText.replace(/^"|"$/g, '');
                MascotBrain.openChatWithPrompt(cleanPrompt);
            }
        });
    });

    // 8. Mobile Menu Toggle
    const mobileMenuBtn = document.getElementById('mobile-menu-toggle');
    const navLinks = document.querySelector('.lp-nav-links');

    if (mobileMenuBtn && navLinks) {
        mobileMenuBtn.addEventListener('click', () => {
            const isActive = navLinks.classList.toggle('active');
            
            // Toggle icons
            const menuIcon = mobileMenuBtn.querySelector('.menu-icon');
            const closeIcon = mobileMenuBtn.querySelector('.close-icon');
            
            if (menuIcon && closeIcon) {
                menuIcon.style.display = isActive ? 'none' : 'block';
                closeIcon.style.display = isActive ? 'block' : 'none';
            }
        });

        // Close menu on link click
        navLinks.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                navLinks.classList.remove('active');
                const menuIcon = mobileMenuBtn.querySelector('.menu-icon');
                const closeIcon = mobileMenuBtn.querySelector('.close-icon');
                if (menuIcon) menuIcon.style.display = 'block';
                if (closeIcon) closeIcon.style.display = 'none';
            });
        });
    }
});

// 9. Premium Reveal Animations
const revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const el = entry.target;
            
            if (el.classList.contains('stagger-1')) el.style.transitionDelay = '0.1s';
            if (el.classList.contains('stagger-2')) el.style.transitionDelay = '0.2s';
            if (el.classList.contains('stagger-3')) el.style.transitionDelay = '0.3s';
            if (el.classList.contains('stagger-4')) el.style.transitionDelay = '0.4s';
            
            el.classList.add('reveal-active');
            revealObserver.unobserve(el);
        }
    });
}, { 
    threshold: 0.1, // Lower threshold for mobile
    rootMargin: '0px 0px -20px 0px' // Tighter margin for faster reveal
});

// Helper to reveal all if needed (Safety fallback for iOS)
window.forceRevealAll = function() {
    document.querySelectorAll('.reveal').forEach(el => {
        el.classList.add('reveal-active');
    });
};

// Check for slow reveal on mobile
if (window.innerWidth < 768) {
    // If after 3 seconds sections aren't revealed, force them (safety)
    setTimeout(() => {
        document.querySelectorAll('.reveal:not(.reveal-active)').forEach((el, i) => {
            if (i < 3) el.classList.add('reveal-active'); // Just top ones
        });
    }, 3000);
}

document.querySelectorAll('.reveal').forEach(el => {
    // Initial state is handled in landing.css to prevent FOUC where possible,
    // but we can enforce it here if needed.
    revealObserver.observe(el);
});

// FAQ Accordion Logic
document.addEventListener('DOMContentLoaded', () => {
    const faqItems = document.querySelectorAll('.faq-accordion-item');
    
    faqItems.forEach(item => {
        const header = item.querySelector('.faq-accordion-header');
        if (!header) return;
        
        header.addEventListener('click', () => {
            const isActive = item.classList.contains('active');
            
            // Close all
            faqItems.forEach(faq => {
                faq.classList.remove('active');
                const content = faq.querySelector('.faq-accordion-content');
                if (content) content.style.maxHeight = null;
            });
            
            // Open clicked if it wasn't active
            if (!isActive) {
                item.classList.add('active');
                const content = item.querySelector('.faq-accordion-content');
                if (content) content.style.maxHeight = content.scrollHeight + "px";
            }
        });
    });
});
