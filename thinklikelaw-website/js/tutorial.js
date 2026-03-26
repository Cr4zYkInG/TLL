/**
 * Onboarding Tutorial — Guided Walkthrough
 * Specialized for LLB and A-Level modes.
 * Only triggers once per user on Desktop.
 */

(function () {
    'use strict';

    const STORAGE_KEY = 'tutorialComplete';

    // 1. Mobile Check — Disable tutorial on small screens
    if (window.innerWidth <= 1024) return;

    // 2. Check if tutorial already done
    if (localStorage.getItem(STORAGE_KEY) === 'true') return;

    // 3. Mode Detection
    const level = localStorage.getItem('studentLevel') || 'llb';
    const isLLB = level === 'llb';

    const steps = isLLB ? [
        // LLB MODE STEPS
        {
            selector: '.btn-new-module',
            title: 'Organise Your LLB',
            text: 'Create modules for your core and elective subjects. Organise your year by "Contract Law", "Tort", or "Public Law".',
            position: 'bottom'
        },
        {
            selector: '.modules-grid',
            title: 'Curriculum Mastery',
            text: 'Your subjects appear here. We track your progress across the entire syllabus to ensure you are exam-ready.',
            position: 'bottom'
        },
        {
            selector: '[data-page="interpret"]',
            title: 'Interpret AI',
            text: 'Upload dense statutes or long judgments. Our AI simplifies the legalese into plain English in seconds.',
            position: 'right'
        },
        {
            selector: '[data-page="flashcards"]',
            title: 'Case Law Flashcards',
            text: 'Master the ratio decidendi and key principles using active recall. Spaced repetition ensures you never forget a case.',
            position: 'right'
        },
        {
            selector: '[data-page="essay-marking"]',
            title: 'High-Level Marking',
            text: 'Submit your problem or essay questions. Use our marking AI to check for IRAC structure and legal depth.',
            position: 'right'
        },
        {
            selector: '[data-page="oscola"]',
            title: 'OSCOLA citations',
            text: 'Generate perfect Oxford citations for your bibliography instantly. Never lose marks for a missing comma again!',
            position: 'right'
        },
        {
            selector: '.nav-item[href="news"]',
            title: 'Official News & Bills',
            text: 'Track enactments and bills directly from gov.uk. Use AI to interpret complex legislation for just 15 credits, and save articles to your library.',
            position: 'right'
        },
        {
            selector: '.nav-item[href="exam-test"]',
            title: 'Exam Simulator',
            text: 'Practice under timed conditions with our Exam Tool. It features anti-cheat and word-count tracking to mimic your real assessments.',
            position: 'right'
        },
        {
            selector: '#mascot-container',
            title: 'Ben, Your Study Buddy',
            text: 'Ben will notify you of your daily streaks and keep you motivated. Click him anytime for a legal pep talk!',
            position: 'top'
        }
    ] : [
        // A-LEVEL MODE STEPS
        {
            selector: '.btn-new-module',
            title: 'Start Your Revision',
            text: 'Create modules for "Criminal Law", "Tort Law", or "Human Rights". Perfect for keeping your A-Level notes tidy.',
            position: 'bottom'
        },
        {
            selector: '.modules-grid',
            title: 'Progress Tracking',
            text: 'See how much of the A-Level specification you have covered. Aim for 100% to secure that A*!',
            position: 'bottom'
        },
        {
            selector: '[data-page="interpret"]',
            title: 'Interpret AI',
            text: 'Struggling with a hard concept? Paste it here! Our AI breaks down complex laws into simple, easy-to-learn bits.',
            position: 'right'
        },
        {
            selector: '[data-page="flashcards"]',
            title: 'Flashcards',
            text: 'The best way to learn key case names and definitions. Speed run your revision before the big day!',
            position: 'right'
        },
        {
            selector: '[data-page="essay-marking"]',
            title: 'AO Marking',
            text: 'The AI will mark your practice essays based on official A-Level criteria (AO1, AO2, AO3). Know where you need to improve.',
            position: 'right'
        },
        {
            selector: '.nav-item[href="exam-test"]',
            title: 'Exam Practice',
            text: 'Simulate a real law exam. Practice writing under pressure and track your words per minute.',
            position: 'right'
        },
        {
            selector: '#mascot-container',
            title: 'Meet Ben!',
            text: 'Ben is here to help you ace your A-Levels. Keep your daily streak alive to make him happy and earn extra credits!',
            position: 'top'
        }
    ];

    let currentStep = 0;
    let overlay, tooltip, spotlight;

    function injectStyles() {
        const style = document.createElement('style');
        style.id = 'tutorial-styles';
        style.textContent = `
            .tutorial-overlay {
                position: fixed;
                inset: 0;
                z-index: 99998;
                pointer-events: auto;
                cursor: pointer;
            }
            .tutorial-spotlight {
                position: fixed;
                z-index: 99999;
                border-radius: 12px;
                box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.82);
                transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
                pointer-events: none;
                border: 2px solid rgba(255,255,255,0.2);
            }
            .tutorial-tooltip {
                position: fixed;
                z-index: 100000;
                background: #FFFFFF;
                color: #000000;
                border-radius: 20px;
                padding: 1.5rem;
                width: 320px;
                box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
                transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
                pointer-events: auto;
                font-family: 'Inter', sans-serif;
            }
            body.dark-mode .tutorial-tooltip {
                background: #111113;
                color: #FFFFFF;
                border: 1px solid rgba(255,255,255,0.1);
            }
            .tutorial-tooltip-arrow {
                position: absolute;
                width: 14px;
                height: 14px;
                background: inherit;
                transform: rotate(45deg);
                z-index: -1;
            }
            .tutorial-tooltip-arrow.arrow-left {
                left: -7px;
                top: 32px;
                box-shadow: -1px 1px 0 0 rgba(0,0,0,0.05);
            }
            .tutorial-tooltip-arrow.arrow-bottom {
                bottom: -7px;
                left: 50%;
                margin-left: -7px;
                transform: rotate(225deg);
            }
            .tutorial-step-badge {
                font-size: 0.65rem;
                font-weight: 800;
                text-transform: uppercase;
                letter-spacing: 0.1em;
                color: var(--text-secondary, #808080);
                margin-bottom: 0.5rem;
                display: block;
            }
            .tutorial-tooltip h3 {
                font-size: 1.15rem;
                font-weight: 700;
                margin: 0 0 0.5rem 0;
                letter-spacing: -0.01em;
            }
            .tutorial-tooltip p {
                font-size: 0.9rem;
                line-height: 1.5;
                color: var(--text-secondary, #666);
                margin: 0 0 1.25rem 0;
            }
            .tutorial-actions {
                display: flex;
                justify-content: space-between;
                align-items: center;
                gap: 1rem;
            }
            .tutorial-btn-skip {
                background: none;
                border: none;
                color: #999;
                font-size: 0.75rem;
                font-weight: 600;
                cursor: pointer;
                padding: 0.5rem 0;
                text-decoration: underline;
            }
            .tutorial-btn-next {
                background: #000;
                color: #fff;
                border: none;
                padding: 0.6rem 1.2rem;
                border-radius: 30px;
                font-size: 0.85rem;
                font-weight: 700;
                cursor: pointer;
                transition: transform 0.2s;
            }
            body.dark-mode .tutorial-btn-next {
                background: #fff;
                color: #000;
            }
            .tutorial-btn-next:hover { transform: scale(1.05); }
            
            .tutorial-progress {
                margin-top: 1rem;
                display: flex;
                gap: 4px;
            }
            .tutorial-progress-dot {
                height: 3px;
                background: rgba(0,0,0,0.1);
                flex: 1;
                border-radius: 2px;
            }
            body.dark-mode .tutorial-progress-dot {
                background: rgba(255,255,255,0.1);
            }
            .tutorial-progress-dot.active { background: #000; }
            body.dark-mode .tutorial-progress-dot.active { background: #fff; }
        `;
        document.head.appendChild(style);
    }

    function createElements() {
        overlay = document.createElement('div');
        overlay.className = 'tutorial-overlay';
        document.body.appendChild(overlay);

        spotlight = document.createElement('div');
        spotlight.className = 'tutorial-spotlight';
        document.body.appendChild(spotlight);

        tooltip = document.createElement('div');
        tooltip.className = 'tutorial-tooltip';
        document.body.appendChild(tooltip);

        overlay.addEventListener('click', () => {
            window._tutorialNext();
        });

        spotlight.addEventListener('click', () => {
            window._tutorialNext();
        });
        spotlight.style.pointerEvents = 'auto';
        spotlight.style.cursor = 'pointer';

        // Keyboard: Enter, Space, or Arrow Right to advance
        window._tutorialKeyHandler = (e) => {
            if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowRight') {
                e.preventDefault();
                window._tutorialNext();
            } else if (e.key === 'Escape') {
                window._tutorialSkip();
            }
        };
        document.addEventListener('keydown', window._tutorialKeyHandler);
    }

    function showStep(index) {
        const step = steps[index];
        const el = document.querySelector(step.selector);

        if (!el || (el.offsetParent === null)) {
            // Skip missing or hidden elements
            if (index < steps.length - 1) showStep(index + 1);
            else completeTutorial();
            return;
        }

        currentStep = index;
        
        // Scroll element into view so it's not off-screen
        el.scrollIntoView({ behavior: 'instant', block: 'center', inline: 'nearest' });
        
        // Small delay to ensure scroll has painted before measuring
        setTimeout(() => {
            const rect = el.getBoundingClientRect();
            const pad = 8;

            // Spotlight
            spotlight.style.top = (rect.top - pad) + 'px';
            spotlight.style.left = (rect.left - pad) + 'px';
            spotlight.style.width = (rect.width + pad * 2) + 'px';
            spotlight.style.height = (rect.height + pad * 2) + 'px';

            const dots = steps.map((_, i) => `<div class="tutorial-progress-dot ${i === index ? 'active' : ''}"></div>`).join('');

            const isLast = index === steps.length - 1;
            const arrowClass = step.position === 'right' ? 'arrow-left' : 'arrow-bottom';

            tooltip.innerHTML = `
                <div class="tutorial-tooltip-arrow ${arrowClass}"></div>
                <span class="tutorial-step-badge">Tutorial ${index + 1}/${steps.length}</span>
                <h3>${step.title}</h3>
                <p>${step.text}</p>
                <div class="tutorial-actions">
                    <button class="tutorial-btn-skip" onclick="window._tutorialSkip()">Skip</button>
                    <button class="tutorial-btn-next" onclick="window._tutorialNext()">
                        ${isLast ? 'Start Studying' : 'Next'}
                    </button>
                </div>
                <div class="tutorial-progress">${dots}</div>
            `;

            // Tooltip Positioning logic
            if (step.position === 'right') {
                tooltip.style.top = (rect.top) + 'px';
                tooltip.style.left = (rect.right + 25) + 'px';
                tooltip.style.bottom = 'auto';
            } else if (step.position === 'top') {
                tooltip.style.top = 'auto';
                tooltip.style.bottom = (window.innerHeight - rect.top + 20) + 'px';
                tooltip.style.left = (rect.left) + 'px';
            } else {
                tooltip.style.top = (rect.bottom + 20) + 'px';
                tooltip.style.left = (rect.left) + 'px';
                tooltip.style.bottom = 'auto';
            }

            // Viewport correction
            requestAnimationFrame(() => {
                const tRect = tooltip.getBoundingClientRect();
                if (tRect.right > window.innerWidth - 20) tooltip.style.left = (window.innerWidth - tRect.width - 20) + 'px';
                if (tRect.bottom > window.innerHeight - 20) {
                    tooltip.style.top = 'auto';
                    tooltip.style.bottom = '20px';
                }
            });
        }, 50);
    }

    function completeTutorial() {
        localStorage.setItem(STORAGE_KEY, 'true');
        cleanup();
    }

    function cleanup() {
        if (overlay) overlay.remove();
        if (spotlight) spotlight.remove();
        if (tooltip) tooltip.remove();
        const style = document.getElementById('tutorial-styles');
        if (style) style.remove();
        if (window._tutorialKeyHandler) {
            document.removeEventListener('keydown', window._tutorialKeyHandler);
            delete window._tutorialKeyHandler;
        }
        delete window._tutorialNext;
        delete window._tutorialSkip;
    }

    window._tutorialNext = () => currentStep < steps.length - 1 ? showStep(currentStep + 1) : completeTutorial();
    window._tutorialSkip = () => completeTutorial();

    function start() {
        const dashboardCheck = document.getElementById('modules-container');
        if (dashboardCheck) {
            setTimeout(() => {
                injectStyles();
                createElements();
                showStep(0);
            }, 1000);
        } else {
            setTimeout(start, 500);
        }
    }

    if (window.location.pathname.includes('dashboard.html')) {
        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
        else start();
    }
})();
