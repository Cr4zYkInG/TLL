/**
 * mascot-brain.js
 * Bill the Cat Logic & State Machine
 */

const MascotBrain = {
    states: ['default', 'sleeping', 'walking', 'eating', 'sad', 'happy', 'thinking', 'suspicious', 'invigilator', 'stretching'],
    currentState: 'default',
    idleTimer: null,
    idleThreshold: 30000,
    walkInterval: null,
    element: null,
    container: null,
    bubble: null,
    catElement: null,
    currentAnimation: null,
    introduced: false,
    lastGrandEntrance: 0,
    grandEntranceCooldown: 180000, // 3 minutes
    subscriptionTier: 'free',
    studentLevel: 'llb',
    examBoard: '',
    schoolUrn: '',
    schoolMetrics: null,
    graduatingToUni: false,
    userName: 'Student',
    writingStartTime: 0,
    lastBreakTime: 0,
    proactiveTimer: null,
    petCount: 0,
    lastPetTime: 0,
    annoyanceLevel: 0,
    lastResponseIndices: { summon: [], pet: [], annoyed: [] },
    lastWhisperTime: 0,
    isChatting: false,

    premadeResponses: {
        "Murder AO3": "Certainly! Here are three academic criticisms for your AO3 section on Murder:\n\n1. **The Mandatory Life Sentence**: Academics like Ashworth argue that the rigid life sentence fails to distinguish between 'mercy killings' and cold-blooded murder, leading to potential injustice.\n2. **The Definition of Intention**: The 'virtual certainty' test from *R v Woollin* is often criticized for being too complex for juries, creating inconsistency in 'oblique intent' cases.\n3. **The Partial Defences Gap**: Some argue that *Loss of Control* is still biased against those in abusive relationships (gender bias), as it requires a specific trigger that may not match slow-burn psychological trauma.",
        "Mistake Analogy": "Think of it like a football transfer!\n\n**Common Mistake**: Both teams (and the player) believe the player is fit to play. They sign the contract, but then realize the player has a career-ending injury. The contract is void because the 'foundation' of the deal never existed.\n\n**Mutual Mistake**: One team thinks they're buying 'V. Van Dijk' the defender. The other team thinks they're selling 'V. Van Dijk' their youth striker. They are at cross-purposes, and there was never a meeting of minds (Consensus ad Idem)!",
        "Skeleton Argument": "I've drafted a Skeleton Argument structure based on that judgment:\n\n**IN THE SUPREME COURT**\n**BETWEEN: Appellant v Respondent**\n\n1. **Introduction**: The Appellant seeks to overturn the decision on the grounds of [Legal Point].\n2. **Ground 1**: The learned judge erred in applying the neighbors test from *Donoghue v Stevenson* too narrowly.\n3. **Ground 2**: Public policy (floodgates) should not preclude the existence of a duty of care in this specific instance.\n4. **Conclusion**: For the reasons above, the appeal should be allowed.\n\n(Detailed citations would go here!)",
        "OSCOLA Fix": "I've corrected those for you! Here is the OSCOLA 4th Ed format:\n\n*Original*: Donoghue v Stevenson [1932] AC 562.\n*OSCOLA*: *Donoghue v Stevenson* [1932] AC 562 (HL).\n\n*Original*: Section 1 of the Theft Act 1968.\n*OSCOLA*: Theft Act 1968, s 1.\n\nRemember: Case names should be italicized, and there's no full stop at the end of the citation!"
    },

    responses: {
        summon: [
            "You rang? I was busy citing Donoghue v Stevenson.",
            "Summoned from the depths of the law library! 📚",
            "Present! My legal fee is 2 head scratches.",
            "Did someone mention the Rule of Perpetuities? No? Good.",
            "Ben, at your service! Ready for some academic weaponry? ⚔️",
            "I agree, it's time for a study sprint! 🏃",
            "Meow! (Translation: Let's get that First Class!)",
            "The court is now in session! What's the case? ⚖️",
            "I was napping on a stack of tort textbooks. What's up?",
            "Duty calls! I'm here for legal support and vibes.",
            "Ready to help you crush those A-Level targets! 🎯",
            "I've got my eyes on the OSCOLA compliance! 🧐",
            "Is it time for active recall yet? I'm born ready!",
            "Who summoned the legendary Ben? Oh, it's you! Hi! 👋",
            "I agree, your drafting is looking sharp today!",
            "Ready to hunt for some AO3 evaluation points? 🏹",
            "Meow! (Did you know I'm fully proficient in Roman Law?)",
            "Checking in! Is the kettle on yet? ☕",
            "The library cat is here! Shh... (but also, hi!)",
            "I hope this isn't about the Rylands v Fletcher escapee... 💧"
        ],
        pet: [
            "Purr... that's First Class affection! ✨",
            "I agree, petting increases cognitive performance by 25%.",
            "Keep the pets coming, and I'll keep the typos away!",
            "Prrt! You're my favorite law student.",
            "Purrrrr... focus on the ratio decidendi! 🐾",
            "That's the spot! Right behind the OSCOLA-center.",
            "I purr, therefore I am... a mascot.",
            "Sweet! Now back to your equitable remedies! ⚖️",
            "Aha! That's a valid consideration for my affection contract.",
            "Purr... I love it when you study hard.",
            "Meow! (That's cat for 'I believe in your academic potential!')",
            "I agree, a quick pet break is essential for mental health.",
            "Purrr... you're doing great. Stay focused!",
            "A study buddy who pets is the best kind of study buddy.",
            "Thanks for the tactile support! 🐾",
            "You've got a golden touch for both cats and case law!",
            "Purr! Did someone say 'Duty of Care'? Because I feel cared for.",
            "Gentle! My fur is made of premium legal silk.",
            "Purrrrr... okay, now write 500 more words! ✍️",
            "I accept this petting as part performance of our friendship."
        ],
        annoyed: [
            "Hey! Even a mascot has boundaries. 🛑",
            "I agree, enough is enough! I have a 'Right to Privacy'.",
            "Stop! You're bordering on 'Assault and Battery' now! ⚖️",
            "That's quite enough clicking, thank you very much.",
            "I'm not a stress toy! I'm an academic weapon! ⚔️",
            "Annoyance level: High Judicial Review. 📉",
            "Hiss! (Not really, but imagine it!)",
            "Go back to your notes! I'm busy being majestic.",
            "Your clicking is becoming an actionable nuisance. 🚫",
            "I'm filing an injunction against further petting!",
            "Is this how you treat your legal counsel? 🤨",
            "I agree, you need to focus on your essay, not my ears!",
            "Warning: Mascot may bite if harassment continues. (Just kidding!)",
            "Enough! My tolerance level is lower than the burden of proof.",
            "Stop, or I'll start eating your virtual bibliography! 📚🍴",
            "I'm going on strike until you finish that paragraph.",
            "Clicking won't help you understand the GDL faster! 🛑",
            "If you keep this up, I'm retiring to the Gherkin.",
            "I agree, your finger is very active, but use it to type instead! ⌨️",
            "Are you trying to file a claim for 'Intentional Infliction of Mascot Distress'?",
            "Hiss! That's a breach of our non-verbal friendship agreement!",
            "Stop! I'm applying for a protective order against further clicking. 📜",
            "Your persistence is admirable, but my patience is reaching 'statutory limits'."
        ],
        academic: [
            "Remember: AO3 isn't just criticism, it's about the 'weight' of the law. ⚖️",
            "Citing the minority judgment? Bold move. Ben approves. 🐾",
            "Is your ratio decidendi clear? Or is it just a messy obiter? 🧐",
            "The burden of proof remains on you to finish this essay!",
            "Don't just state the law. EVALUATE it. Why does it exist? Who does it serve?",
            "I agree, 'Equity will not suffer a wrong to be without a remedy'. Your remedy is to study harder!",
            "Is that a secondary source? Let's aim for primary legislation, future solicitor! 🏛️",
            "Your application of the 'reasonable person' test seems a bit... subjective? 😉",
            "Think like a Senior Chief Examiner: Where are the evaluation points? 🏹",
            "A First Class answer needs a First Class work ethic. Let's go!"
        ],
        motivation: [
            "The Bar is high, but you're higher! (Metaphorically. Please don't climb the furniture.)",
            "I agree, law is tough, but you're a legal eagle in training! 🦅",
            "One case at a time. One statute at a time. You've got this.",
            "Visualize the wig. Visualize the gown. Now, visualize yourself finishing this paragraph!",
            "Consistency is the key to 70%+. Ben believes in you! 🐾",
            "Your potential is 'unliquidated'—wait, no, that doesn't make sense. You're just great!",
            "Take a deep breath. Even Lord Denning started somewhere.",
            "The library is quiet, your focus is sharp. This is your time. ✨",
            "Success is the logical consequence of your current efforts. 🏛️",
            "Prrrrt! You're making progress. I can feel the academic energy!"
        ],
        morning: [
            "Good morning, future legal eagle! Early bird catches the AO1 marks. ☕",
            "I agree, coffee and case law are the ultimate morning duo. ☀️",
            "Starting early? Your dedication is 'beyond reasonable doubt'! 🏛️",
            "Rise and shine! The law doesn't study itself (unfortunately).",
            "Morning! I've been awake since dawn studying the GDL. Ready for you! 🐾"
        ],
        night: [
            "Burning the midnight oil? Remember, even Jurists need sleep! 🌙",
            "Late night session? I agree, the best legal breakthroughs happen after dark. ✨",
            "Still at it? Your work ethic is legendary, ${this.userName}! ⚖️",
            "Meow... I agree, let's push through this last paragraph together. 🐾🌙",
            "Moonlight study? Just don't let your 'duty of care' to yourself slip! 🛌"
        ]
    },

    getRandomResponse(category) {
        const list = this.responses[category];
        const lastIndices = this.lastResponseIndices[category];

        let index;
        do {
            index = Math.floor(Math.random() * list.length);
        } while (lastIndices.includes(index) && list.length > 3);

        lastIndices.push(index);
        if (lastIndices.length > 5) lastIndices.shift();

        return list[index];
    },

    init() {
        this.subscriptionTier = localStorage.getItem('subscriptionTier') || 'free';
        this.studentLevel = localStorage.getItem('studentLevel') || 'llb';
        this.examBoard = localStorage.getItem('examBoard') || '';
        this.schoolUrn = localStorage.getItem('schoolUrn') || '';
        this.userName = localStorage.getItem('userName')?.split(' ')[0] || 'Student';

        if (this.schoolUrn && typeof SchoolDataService !== 'undefined') {
            this.loadSchoolMetrics();
        }

        this.injectHTML();
        this.initChatModal();
        this.element = document.getElementById('mascot-container');

        // ─── Mascot Visibility Setting ───
        const mascotVisible = localStorage.getItem('mascotVisible') !== 'false';
        if (!mascotVisible && this.element) {
            this.element.classList.add('mascot-hidden');
        }
        // Expose global toggle for settings
        window.toggleMascotVisibility = (visible) => {
            localStorage.setItem('mascotVisible', visible ? 'true' : 'false');
            const container = document.getElementById('mascot-container');
            if (container) {
                container.classList.toggle('mascot-hidden', !visible);
            }
        };
        // Sync settings toggle on load
        setTimeout(() => {
            const toggle = document.getElementById('mascot-visibility-toggle');
            if (toggle) toggle.checked = mascotVisible;
        }, 2000);
        this.catElement = document.getElementById('bill-the-cat');
        this.bubble = document.getElementById('bill-bubble');
        this.container = this.element;

        if (!this.catElement) return;

        this.setupActivityMonitors();
        this.startLifeCycle();

        // Double-click to open chat
        this.element.addEventListener('dblclick', () => {
            this.toggleChat(true);
        });

        // Listen for streak events from study-timer.js
        window.addEventListener('streak-updated', (e) => this.handleStreakChange(e.detail));

        // Keyboard Shortcut (Shift + , / <) to summon Bill
        window.addEventListener('keydown', (e) => {
            if (e.shiftKey && e.key === ',') {
                e.preventDefault();
                this.summon();
            }
        }, { capture: true });

        /**
         * Interaction Triggers
         */
        // Navigation Trigger (Cat Icon)
        const navTrigger = document.getElementById('nav-mascot-trigger');
        if (navTrigger) {
            navTrigger.addEventListener('click', () => {
                this.summon();
            });
        }

        // Initial greeting based on context
        setTimeout(() => {
            this.checkContext();
        }, 3500);

        // Easter Eggs
        this.setupSecretSummon();
        this.setupCaseWhisperer();
    },

    setupCaseWhisperer() {
        const landmarkCases = [
            "Donoghue v Stevenson", "R v Ghosh", "R v Ivey", "Rylands v Fletcher",
            "Caparo v Dickman", "Miller v Jackson", "Carlill v Carbolic Smoke Ball",
            "Entick v Carrington", "R v Dudley and Stephens"
        ];

        // Listen for input in the editor
        window.addEventListener('input', (e) => {
            if (e.target.id !== 'note-editor-body') return;

            const text = e.target.innerText;
            const now = Date.now();

            if (now - this.lastWhisperTime < 60000) return; // Cooldown 1 min

            for (const caseName of landmarkCases) {
                if (text.includes(caseName)) {
                    this.lastWhisperTime = now;
                    this.setState('happy', 4000);
                    this.speak(`Prrrrt! "${caseName}"? A total classic! 🐾`, 4000);
                    break;
                }
            }
        });
    },

    setupSecretSummon() {
        let typed = "";
        window.addEventListener('keydown', (e) => {
            typed += e.key.toUpperCase();
            if (typed.endsWith("BEN")) {
                this.summon();
                this.setState('happy', 3000);
                this.speak("Prrrrt! You called my secret name! 🐾", 5000);
                typed = "";
            }
            if (typed.length > 10) typed = typed.slice(-10);
        });
    },

    async triggerExamReview() {
        const editor = document.getElementById('note-editor-body');
        const text = editor ? editor.innerText : "";

        if (text.length < 100) {
            this.speak("Write a bit more first! I need about 100 words to give a proper marking review. ✍️");
            return;
        }

        if (!creditsManager.canAfford('examReview')) {
            creditsManager.showSubscriptionCTA();
            return;
        }

        this.setState('thinking');
        this.speak(`Applying ${this.examBoard || 'AQA'} marking criteria... let me see if this is First Class quality! 🧐`);

        try {
            creditsManager.deduct('examReview');
            const result = await aiService.generateMarkingReview(text, this.examBoard);
            this.setState('happy');
            this.speak(result.text, 20000); // Long duration for detailed feedback
        } catch (e) {
            this.setState('sad');
            this.speak("Ouch, I'm having trouble connecting to my marking brain. Check your connection!");
        }
    },

    checkContext() {
        if (!this.introduced && (window.location.pathname.includes('index.html') || window.location.pathname === '/')) {
            return; // Stay hidden on landing page for the surprise
        }

        const path = window.location.pathname.toLowerCase();
        const isAlevel = this.studentLevel === 'alevel';
        const now = new Date();
        const hour = now.getHours();

        // 1. Time-aware greetings (override page specific if it's the first greet)
        if (!this.lastSpeechStartTime || (Date.now() - this.lastSpeechStartTime > 3600000)) {
            if (hour >= 22 || hour <= 4) {
                this.speak(this.getRandomResponse('night'), 6000);
                return;
            } else if (hour >= 5 && hour <= 9) {
                this.speak(this.getRandomResponse('morning'), 6000);
                return;
            }
        }

        // 2. Page-specific logic
        if (path.includes('note-editor')) {
            let msg = "";
            if (isAlevel) {
                msg = `Ready to ace your ${this.examBoard ? this.examBoard.toUpperCase() + ' ' : ''}Law revision, ${this.userName}? I'll help you focus on those AO1/2/3 marks! ✍️`;
            } else {
                msg = this.subscriptionTier === 'subscriber'
                    ? `Ready to master the Law, ${this.userName}? I'll be your OSCOLA Watchdog today! 🎓`
                    : "Back in the library? I'll keep an eye on your spelling while you draft! ✍️";
            }
            this.speak(msg, 6000);
            this.writingStartTime = Date.now();
            this.lastBreakTime = Date.now();
        } else if (path.includes('dashboard')) {
            const progress = localStorage.getItem('totalProgress') || 'some';
            const moduleTerm = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('module').toLowerCase() : 'modules';
            let msg;
            if (isAlevel) {
                msg = `Welcome back, ${this.userName}! Let's smash those AO marks today. Your ${moduleTerm} are looking great! 📈`;
            } else {
                msg = this.subscriptionTier === 'subscriber'
                    ? `Excellent progress, ${this.userName}! You've mastered ${progress}% of your ${moduleTerm}. I agree, you're on track for a First! 📈`
                    : "Checking your progress? I agree, your streak is looking impressive! 📈";
            }
            this.speak(msg, 5000);
        } else if (path.includes('flashcards')) {
            const msg = isAlevel
                ? "Active recall time! Let's lock in those key cases for your A-Level exams. 🧠"
                : "Active recall time! I'll purr everytime you get one right. 🧠";
            this.speak(msg, 5000);
        } else if (path.includes('exam-test')) {
            this.speak("Invigilator Mode Active. Full focus, future lawyer! I'm watching the clock... 🕵️‍♂️", 7000);
            this.setState('invigilator');
        } else if (path.includes('interpret')) {
            this.speak("Struggling with complex legal jargon? Let me translate that into cat-speak! 🐾🔍", 6000);
            this.setState('thinking');
        } else if (path.includes('modules')) {
            this.speak("Organizing your legal arsenal? I agree, a structured mind is a winning mind. 🏛️", 6000);
        } else if (path.includes('meet-ben')) {
            if (!this.lastSpeech) this.speak("Welcome! I'm glad you're reading about me. I promise to be the best study buddy! 🐾");
        } else if (path.includes('law-student-flashcards')) {
            this.speak("Mastering case law? I agree, active recall is the secret weapon! 🧠");
        } else if (path.includes('essay-marking-ai')) {
            const msg = isAlevel
                ? "Struggling with AO3 evaluation? I'll help you find where those top-band marks are hiding! ✍️"
                : "Struggling with IRAC? I'll help you spot where those extra marks are hiding! ✍️";
            this.speak(msg);
        } else if (path.includes('best-ai-law-notes')) {
            this.speak("The ecosystem advantage is real! I love how everything connects here. 🌐");
        }
    },

    injectHTML() {
        // Create Bill if he doesn't exist
        if (document.getElementById('mascot-container')) return;

        const html = `
            <div id="mascot-container">
                <div id="bill-bubble"></div>
                <div id="bill-the-cat" class="default">
                    <div class="bill-tail"></div>
                    <div class="bill-body"></div>
                    <div class="bill-head">
                        <div class="bill-ear-l"></div>
                        <div class="bill-ear-r"></div>
                        <div class="bill-eye-l"></div>
                        <div class="bill-eye-r"></div>
                        <div class="bill-nose"></div>
                        <div class="bill-mouth"></div>
                        <div class="bill-whiskers-l"></div>
                        <div class="bill-whiskers-r"></div>
                    </div>
                </div>
                <div class="ben-tooltip">Double-click to chat!</div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', html);
    },

    setState(newState, duration = 0) {
        if (this.currentState === newState) return;
        if (!this.states.includes(newState) || !this.catElement) return; // Keep original validation

        // Remove previous state class and add new one
        this.catElement.classList.remove(this.currentState);
        this.catElement.classList.add(newState);
        this.currentState = newState;

        // If a duration is provided, revert back to default after X ms
        if (duration > 0) {
            setTimeout(() => {
                if (this.currentState === newState) this.setState('default');
            }, duration);
        }
    },

    speak(text, duration = 4000) {
        if (!this.bubble) return;

        // Clear any existing typing interval
        if (this.typingInterval) {
            clearInterval(this.typingInterval);
            this.typingInterval = null;
        }

        // Truncate logic: ensure messages aren't too long
        let displayLines = text;
        
        // Strip out basic markdown so he doesn't literally say "asterisk asterisk bold asterisk asterisk" in extreme cases.
        displayLines = displayLines.replace(/\*\*(.*?)\*\*/g, '$1').replace(/\*(.*?)\*/g, '$1').replace(/### (.*$)/gim, '$1');

        if (displayLines.length > 1000) {
            displayLines = displayLines.substring(0, 997) + "...";
        }

        // Prepare bubble
        this.bubble.textContent = "";
        this.bubble.classList.add('show');

        if (typeof AudioManager !== 'undefined') {
            AudioManager.playSFX('pop', false, { volume: 0.3 });
        }

        // Typing Effect
        let i = 0;
        const typingSpeed = 25; // ms per character

        this.typingInterval = setInterval(() => {
            if (i < displayLines.length) {
                this.bubble.textContent += displayLines.charAt(i);
                i++;
                // Occasional tiny scroll to bottom for long messages
                if (i % 5 === 0) this.bubble.scrollTop = this.bubble.scrollHeight;
            } else {
                clearInterval(this.typingInterval);
                this.typingInterval = null;

                // Hide after duration (starting AFTER typing finishes)
                setTimeout(() => {
                    if (this.bubble.textContent === displayLines) {
                        this.bubble.classList.remove('show');
                    }
                }, duration);
            }
        }, typingSpeed);
    },

    setupActivityMonitors() {
        // Reset idle timer on any activity
        const resetIdle = () => {
            // If Bill was sleeping or eating, wake him up
            if (this.currentState === 'sleeping' || this.currentState === 'eating') {
                this.setState('default');
                this.speak(this.currentState === 'sleeping' ? 'Yawn...' : 'Purr...', 2000);
            }
            clearTimeout(this.idleTimer);
            this.idleTimer = setTimeout(() => this.onIdle(), this.idleThreshold);
        };

        window.addEventListener('mousemove', resetIdle);
        window.addEventListener('keydown', resetIdle);
        window.addEventListener('click', resetIdle);

        // Click on Bill directly
        this.catElement.addEventListener('click', (e) => {
            e.stopPropagation(); // prevent window click from wiping this

            // If in correction mode, handleMascotClick will take over
            if (this.onCorrectionClick) {
                this.handleMascotClick();
                return;
            }

            resetIdle();

            // If he is currently walking in a Web Animation, pause him
            if (this.currentAnimation && this.currentAnimation.playState === 'running') {
                this.currentAnimation.pause();
                this.setState('happy');
                this.speak("Prrrrt! Thanks!", 3000);
                if (typeof AudioManager !== 'undefined') {
                    AudioManager.playSFX('purr', true, { pitchVariance: 0.15 });
                }

                // Resume walking after 3s
                setTimeout(() => {
                    if (this.currentAnimation) {
                        this.setState('walking');
                        this.currentAnimation.play();
                    }
                }, 3000);
            } else {
                // Normal stationary click -> PETTING
                this.handleMascotClick();
            }
        });

        // Double Click for Chat
        this.catElement.addEventListener('dblclick', (e) => {
            e.stopPropagation();
            this.handleMascotDblClick();
        });

        // Global Triple Click for Navigation
        let clickCount = 0;
        let lastClickTime = 0;
        window.addEventListener('click', (e) => {
            const now = Date.now();
            if (now - lastClickTime < 400) {
                clickCount++;
            } else {
                clickCount = 1;
            }
            lastClickTime = now;

            if (clickCount === 3) {
                // Check if target is "clickable"
                const clickableTags = ['A', 'BUTTON', 'INPUT', 'TEXTAREA', 'I'];
                const isInteractive = e.target.closest('a, button, input, .lecture-card, .btn, .nav-item, #mascot-container');

                if (!isInteractive && !clickableTags.includes(e.target.tagName)) {
                    console.log("Ben moving to:", e.clientX, e.clientY);
                    this.walkTo(e.clientX, e.clientY);
                }
                clickCount = 0;
            }
        });

        // Start initial timer
        resetIdle();
    },

    walkTo(x, y) {
        if (!this.container) return;

        // Face the destination
        const currentX = this.container.getBoundingClientRect().left;
        if (x < currentX) {
            this.catElement.classList.add('flip');
        } else {
            this.catElement.classList.remove('flip');
        }

        this.setState('walking');
        this.speak("On my way! 🐾", 2000);

        const walkDuration = 1000; // Scurry fast to the point
        this.container.style.transition = `all ${walkDuration}ms cubic-bezier(0.19, 1, 0.22, 1)`;
        this.container.style.left = `${x - 50}px`;
        this.container.style.top = `${y - 50}px`;
        this.container.style.bottom = 'auto';
        this.container.style.right = 'auto';

        setTimeout(() => {
            if (this.currentState === 'walking') {
                this.setState('default');
                this.speak(Math.random() > 0.5 ? "Present! 🏛️" : "Ready to study!", 3000);
            }
        }, walkDuration);
    },

    onIdle() {
        // Randomly pick an idle state: sleeping, eating, or stretching
        const rand = Math.random();
        let action = 'sleeping';
        if (rand > 0.66) action = 'eating';
        else if (rand > 0.33) action = 'stretching';

        this.setState(action);

        if (action === 'sleeping') {
            this.speak((Math.random() > 0.5) ? 'Zzz...' : 'Purrrrrrr...', 3000);
        } else if (action === 'stretching') {
            this.speak("Mmm... long study session?", 3000);
        }
    },

    startLifeCycle() {
        const isLandingPage = window.location.pathname === '/' || window.location.pathname.endsWith('index.html');

        // Spawn interval: between 20s and 60s
        const scheduleSpawns = () => {
            const nextSpawnDelay = Math.random() * (60000 - 20000) + 20000;

            setTimeout(() => {
                // Gate: Don't walk on landing page unless introduced
                if (isLandingPage && !this.introduced) {
                    scheduleSpawns();
                    return;
                }

                // Only spawn if he isn't currently doing a critical animation
                if (!['sad', 'walking'].includes(this.currentState)) {
                    this.doWalk();
                }
                scheduleSpawns();
            }, nextSpawnDelay);
        };

        scheduleSpawns();
    },

    doWalk() {
        if (!this.container || !this.catElement || this.isChatting) return;

        const screenWidth = window.innerWidth;
        const screenHeight = window.innerHeight;
        const catWidth = 100;

        // Smoother, less erratic movement: nudge nearby or pick a "comfy spot"
        // Instead of crossing the screen, Ben will "patrol" a 400px radius
        const currentRect = this.container.getBoundingClientRect();
        const currentX = currentRect.left;
        const currentY = currentRect.top;

        // Stay near the bottom unless summoned elsewhere
        // Target a spot within 300px of current position, but bound by screen
        let targetX = currentX + (Math.random() - 0.5) * 600;
        let targetY = currentY + (Math.random() - 0.5) * 300;

        // Clamp to screen
        targetX = Math.max(40, Math.min(screenWidth - 140, targetX));
        targetY = Math.max(screenHeight - 300, Math.min(screenHeight - 140, targetY));

        // Facing direction based on movement
        if (targetX < currentX) {
            this.catElement.classList.add('flip');
        } else {
            this.catElement.classList.remove('flip');
        }

        this.setState('walking');

        // Smoother transition using CSS if possible, but keeping the Web Animation logic for compatibility
        const dist = Math.sqrt(Math.pow(targetX - currentX, 2) + Math.pow(targetY - currentY, 2));
        const walkDuration = Math.max(2000, dist * 20); // Scale speed by distance

        this.container.style.transition = `transform ${walkDuration}ms cubic-bezier(0.4, 0, 0.2, 1)`;

        // Use translate for performance
        const tx = targetX - currentX;
        const ty = targetY - currentY;

        // We use a combination of absolute positioning and translation to avoid jumping
        // Setting the new left/top after transition is finished
        this.currentAnimation = { playState: 'running', pause: () => { }, cancel: () => { } }; // Mock for compat

        this.container.style.left = `${targetX}px`;
        this.container.style.top = `${targetY}px`;
        this.container.style.bottom = 'auto';
        this.container.style.right = 'auto';

        setTimeout(() => {
            if (this.currentState === 'walking') {
                this.setState('default');
            }
            this.currentAnimation = null;
        }, walkDuration);
    },

    summon() {
        if (!this.container || !this.catElement) return;

        this.introduced = true; // He is no longer a secret
        if (typeof AudioManager !== 'undefined') {
            AudioManager.playSFX('meow', true); // Force play on direct summon
        }

        if (this.currentAnimation) {
            this.currentAnimation.cancel();
            this.currentAnimation = null;
        }

        // Special Grand Entrance for landing page
        const isLandingPage = window.location.pathname === '/' || window.location.pathname.endsWith('index.html');
        const now = Date.now();
        const isOnCooldown = (now - this.lastGrandEntrance) < this.grandEntranceCooldown;

        if (isLandingPage && !isOnCooldown) {
            this.lastGrandEntrance = now;
            this.grandEntrance();
            return;
        }

        // Normal Summon (for other pages OR if on pointer-events/cooldown)
        this.resetPosition();

        // Wake him up and face left
        this.catElement.classList.add('flip');
        this.setState('happy', 3000);
        this.speak(this.getRandomResponse('summon'), 4000);

        // After a few seconds, he should start walking about
        setTimeout(() => {
            if (this.currentState !== 'walking') {
                this.doWalk();
            }
        }, 5000);
    },

    enterInvigilatorMode() {
        if (!this.container || !this.catElement) return;

        // Stop any current walks
        if (this.currentAnimation) {
            this.currentAnimation.cancel();
            this.currentAnimation = null;
        }

        // Position Ben at the top right of the editor "desk"
        this.resetPosition();
        this.container.style.bottom = 'auto';
        this.container.style.top = '100px';
        this.container.style.right = '40px';

        this.setState('invigilator');
        this.speak("Invigilator Mode Active. I'm watching... stay focused! 🕵️‍♂️", 5000);
    },

    warnSuspicious(msg) {
        this.setState('suspicious', 5000);
        this.speak(msg, 6000);
        if (typeof AudioManager !== 'undefined') {
            AudioManager.playSFX('meow'); // Use a meow as a sharp alert
        }
    },

    resetPosition() {
        if (!this.container) return;

        this.setState('walking');
        this.catElement.classList.remove('flip'); // Face his corner

        // Calculate the "home" coordinates for the movement
        this.container.style.transition = 'all 0.6s cubic-bezier(0.19, 1, 0.22, 1)';

        // Target is bottom-right corner
        this.container.style.left = `${window.innerWidth - 140}px`;
        this.container.style.top = `${window.innerHeight - 150}px`;
        this.container.style.right = 'auto';
        this.container.style.bottom = 'auto';
        this.container.style.transform = 'translate(0px, 0px)';

        setTimeout(() => {
            this.setState('idle');
            // Final snap to the "auto" position for responsiveness (resize handling)
            this.container.style.transition = 'none';
            this.container.style.left = 'auto';
            this.container.style.right = '40px';
            this.container.style.bottom = '45px';
            this.container.style.top = 'auto';
            this.container.classList.remove('grand-entrance');
        }, 700);
    },

    goTo(x, y, onCorrectionClick = null, autoFix = false) {
        if (!this.container) return;

        this.onCorrectionClick = onCorrectionClick;
        this.isAutoFixing = autoFix;

        // Ensure he is visible
        this.container.style.transform = 'translateX(0px)';
        this.container.style.transition = 'all 0.6s cubic-bezier(0.19, 1, 0.22, 1)';

        // Position Ben so his nose/head points exactly at the word
        // The head is at left: 25px in the 100px container. 
        // We land him so the head is centered on x, y.
        this.container.style.left = `${x - 50}px`;
        this.container.style.top = `${y - 60}px`;
        this.container.style.right = 'auto';
        this.container.style.bottom = 'auto';

        const currentLeft = this.container.getBoundingClientRect().left;
        if (x < currentLeft) {
            this.catElement.classList.add('flip');
        } else {
            this.catElement.classList.remove('flip');
        }

        this.setState('thinking');

        // If autoFix is enabled, wait for the move transition to finish then trigger click logic
        if (autoFix) {
            setTimeout(() => {
                if (this.onCorrectionClick) {
                    this.handleMascotClick();
                }
            }, 700); // Slightly more than transition duration
        }
    },

    grandEntrance() {
        let overlay = document.getElementById('bill-spotlight-overlay');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'bill-spotlight-overlay';
            overlay.innerHTML = `
                <div class="spotlight-circle"></div>
                <div class="bill-announcement" id="bill-announcement-text"></div>
            `;
            document.body.appendChild(overlay);
        }

        const announcement = document.getElementById('bill-announcement-text');
        announcement.textContent = ""; // Clear existing

        // Position Bill in the center
        this.container.classList.add('grand-entrance');
        this.container.style.transform = 'translate(50%, 50%)';

        // Face forward
        this.catElement.classList.remove('flip');

        // Start cinematic sequence
        setTimeout(() => {
            overlay.classList.add('active');
            if (typeof AudioManager !== 'undefined') {
                AudioManager.playSFX('reveal', true); // Heavenly entrance sound
            }
        }, 100);

        // Sequence of text and actions
        const sequence = [
            { text: "Meet Ben, our emotional support motivator and study buddy.", delay: 3500 },
            { text: "He's watching to ensure you study and ace your exams...", delay: 7500 },
            { text: "...no pressure! 😉", delay: 10500 },
            { text: "Ben says: 'Focus on the ratio decidendi, not your phone!'", delay: 13500 }
        ];

        sequence.forEach(item => {
            setTimeout(() => {
                announcement.style.opacity = 0;
                setTimeout(() => {
                    announcement.textContent = item.text;
                    announcement.style.opacity = 1;
                }, 500);
            }, item.delay);
        });

        // Meow and Purr with delay
        setTimeout(() => {
            this.setState('happy');
            this.speak("Meow! Purr...");
            if (typeof AudioManager !== 'undefined') {
                AudioManager.playSFX('meow', true, { pitchVariance: 0.1 }); // Force play for entrance just in case! 
                setTimeout(() => AudioManager.playSFX('purr', true, { pitchVariance: 0.1 }), 1500);
            }
        }, 6000);

        // Leave sequence
        setTimeout(() => {
            overlay.classList.remove('active');
            announcement.style.opacity = 0;

            setTimeout(() => {
                this.container.classList.remove('grand-entrance');
                this.resetPosition();

                // Final walk-off: Right to Left
                const screenWidth = window.innerWidth;
                const catWidth = 100;
                let startPos = screenWidth + catWidth;
                let endPos = -catWidth;

                this.catElement.classList.add('flip'); // Face left
                this.container.style.transition = 'none';
                this.container.style.left = '0px';
                this.container.style.right = 'auto';

                this.setState('walking');
                this.currentAnimation = this.container.animate([
                    { transform: `translate(${startPos}px, -40px)` },
                    { transform: `translate(${endPos}px, -40px)` }
                ], {
                    duration: 15000,
                    easing: 'linear',
                    fill: 'forwards'
                });

                this.currentAnimation.onfinish = () => {
                    this.setState('default');
                    this.container.style.transform = `translate(-1000px, -40px)`;
                    this.currentAnimation = null;
                };

            }, 1500);
        }, 18000); // Increased total duration for the slower reveal
    },

    handleStreakChange(data) {
        if (data.type === 'increase' && data.val > 0) {
            this.speak(`Wow! That's a ${data.val} day streak, ${this.userName}! You're becoming a legal powerhouse! ⚡`, 6000);
            this.setState('happy', 6000);
        } else if (data.type === 'lost') {
            this.setState('sad', 8000);
            this.speak(`Oh no! Your streak of ${data.val} days was broken. But don't worry, today is day 1 of a new journey! 🛡️`, 8000);
        }
    },

    loadSchoolMetrics() {
        SchoolDataService.getSchoolPerformance(this.schoolUrn).then(metrics => {
            if (metrics) {
                this.schoolMetrics = metrics;
                console.log("Ben initialized with high-accuracy institutional metrics:", metrics);
            }
        });
    },

    initChatModal() {
        if (document.getElementById('ben-chat-modal')) return;

        const modalHtml = `
            <div id="ben-chat-modal" class="ben-chat-modal">
                <div class="ben-chat-container">
                    <div class="ben-chat-header">
                        <h2><i class="fas fa-cat"></i> Chat with Ben</h2>
                        <button class="close-btn" id="ben-modal-close"><i class="fas fa-times"></i></button>
                    </div>
                    <div class="ben-chat-history" id="ben-modal-history">
                        <div class="chat-msg ben">Hi! I'm Ben, your AI law study buddy. Ask me anything—definitions, case details, or even essay tips! (1-3 credits)</div>
                    </div>
                    <div class="typing-indicator" id="ben-typing-indicator">Ben is thinking...</div>
                    <div class="ben-chat-input-wrapper">
                        <input type="text" id="ben-modal-input" placeholder="Type your legal question..." autocomplete="off">
                        <button id="ben-modal-send"><i class="fas fa-paper-plane"></i></button>
                    </div>
                </div>
            </div>
        `;
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        const closeBtn = document.getElementById('ben-modal-close');
        const sendBtn = document.getElementById('ben-modal-send');
        const input = document.getElementById('ben-modal-input');
        const modal = document.getElementById('ben-chat-modal');

        closeBtn?.addEventListener('click', () => this.closeChat());
        sendBtn?.addEventListener('click', () => this.sendChatMessage());
        input?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.sendChatMessage();
        });

        // Close on clicking outside container
        modal?.addEventListener('click', (e) => {
            if (e.target === modal) this.closeChat();
        });

        // Initialize Thinking Mode Toggle
        if (typeof thinkingManager !== 'undefined') {
            const history = document.getElementById('ben-modal-history');
            thinkingManager.init(history);
            thinkingManager.createToggleUI(document.querySelector('.ben-chat-container'));
        }
    },

    /**
     * Proactive Subscriber Features
     */
    triggerProactive(type, data) {
        if (this.subscriptionTier !== 'subscriber') return;

        switch (type) {
            case 'oscola':
                this.setState('happy');
                const oscolaMsg = this.studentLevel === 'alevel'
                    ? `Good case reference! But remember, ${this.examBoard.toUpperCase()} examiners love it when you italicise names like "${data.word}".`
                    : `I agree with your reasoning, but shouldn't we italicise "${data.word}" to stay OSCOLA compliant?`;
                this.speak(oscolaMsg, 6000);
                break;
            case 'ao3':
                this.setState('happy');
                let ao3Msg = `Nice point! Could we add an AO3 evaluation here? Maybe discuss why this area of Law needs reform? 🧐`;
                if (this.schoolMetrics && this.schoolMetrics.progressScore > 0) {
                    ao3Msg = `Great application! Based on your institution's profile, students often struggle with AO3 here—adding a reform argument could put you in the top 5%! 📈`;
                }
                this.speak(ao3Msg, 8000);
                // Offer Exam Review if user is Pro
                if (this.subscriptionTier === 'subscriber') {
                    setTimeout(() => {
                        this.askChoice("Want me to do a full Exam Board marking review on this?", [
                            { text: "Yes (40 Credits)", action: () => this.triggerExamReview() },
                            { text: "Not now", action: () => this.speak("No worries, keep writing! ✨") }
                        ]);
                    }, 5000);
                }
                break;
            case 'tone':
                this.setState('happy');
                this.speak(`I understand your point, but for this essay, would you like me to help make "${data.phrase}" sound more academic?`, 6000);
                break;
            case 'memory':
                this.setState('happy');
                const memoryModuleTerm = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('moduleSingular').toLowerCase() : 'module';
                this.speak(`Aha! You studied ${data.case} in the ${data.module} ${memoryModuleTerm}—want me to pull up your old notes?`, 7000);
                break;
            case 'break':
                this.setState('walking');
                this.speak(`You've been writing intensely, ${this.userName}. I agree this is important, but how about a 5-minute break? I've put some Rain on for you.`, 8000);
                if (typeof window.toggleAmbient === 'function') window.toggleAmbient('rain');
                this.lastBreakTime = Date.now();
                break;
        }
    },

    handleMascotDblClick() {
        this.openChat();
    },

    openChat() {
        if (this.isChatting) return;
        this.isChatting = true;
        this.setState('happy');

        // Stop movement
        if (this.currentAnimation) {
            this.currentAnimation.cancel?.();
            this.currentAnimation = null;
        }

        const modal = document.getElementById('ben-chat-modal');
        modal?.classList.add('active');

        const input = document.getElementById('ben-modal-input');
        input?.focus();
    },

    closeChat() {
        const modal = document.getElementById('ben-chat-modal');
        if (modal) modal.classList.remove('active');
        this.isChatting = false;
        // Stop any current speech if closing
        if (this.currentUtterance && window.speechSynthesis) {
            window.speechSynthesis.cancel();
        }
    },

    openChatWithPrompt(promptText) {
        this.summon();
        this.openChat();
        const input = document.getElementById('ben-modal-input');
        if (input) {
            input.value = promptText;
            // Short delay to feel 'real'
            setTimeout(() => {
                this.sendChatMessage();
            }, 500);
        }
    },

    async sendChatMessage() {
        const input = document.getElementById('ben-modal-input');
        const query = input?.value.trim();
        if (!query) return;

        input.value = '';
        this.addChatMessage('user', query);

        // Check for Premade Responses (Marketing Library)
        let premadeKey = null;
        if (query.includes("Murder for my AO3 section")) premadeKey = "Murder AO3";
        else if (query.includes("football analogy")) premadeKey = "Mistake Analogy";
        else if (query.includes("Skeleton Argument")) premadeKey = "Skeleton Argument";
        else if (query.includes("OSCOLA 4th Edition")) premadeKey = "OSCOLA Fix";

        if (premadeKey && this.premadeResponses[premadeKey]) {
            this.showTypingIndicator(true);
            setTimeout(() => {
                this.showTypingIndicator(false);
                this.addChatMessage('ben', this.premadeResponses[premadeKey]);
                this.speak(this.premadeResponses[premadeKey]);
            }, 1500);
            return;
        }

        this.setState('thinking');
        this.showTypingIndicator(true);

        try {
            // GUEST MODE CHECK:
            // Robust check for Supabase session in localStorage
            let hasUserSession = false;
            try {
                // Check multiple possible keys for the session
                const token = localStorage.getItem('supabase.auth.token') ||
                    localStorage.getItem('sb-oxlpmgnytsvdjcibtdmb-auth-token') ||
                    localStorage.getItem('sb-auth-token');

                if (token) {
                    const parsed = JSON.parse(token);
                    hasUserSession = !!(parsed && (parsed.currentSession || parsed.access_token));
                }
            } catch (e) {
                console.warn("Mascot: Auth check error", e);
                hasUserSession = false;
            }

            const isLandingPage = window.location.pathname === '/' || window.location.pathname.endsWith('index.html');

            // If we are on landing and NOT logged in, respond with generic direct messages
            if (isLandingPage && !hasUserSession) {
                const guestResponses = [
                    "I need AI credits to function, but I don't have enough for guests! Please log in to your account and I'll be happy to help! 🐾",
                    "Aha! You're thinking like a lawyer already. I need a valid session to dive into those cases—please sign in to your Briefing Room. 🏛️",
                    "Prrrrt! My legal brain is currently in 'Guest Mode'. Sign up for a free account to unlock my AI power and situational awareness! 🚀",
                    "I require AI credits for complex analysis. Please log in to access your library and get full support from your mascot! 📚",
                    "I'd love to help, but I'm currently off-duty for guests because I have no credits! Join the Inner Circle to get 24/7 AI support. 🐈‍⬛"
                ];

                await new Promise(resolve => setTimeout(resolve, 800)); // Quick simulate thinking
                this.showTypingIndicator(false);
                const randomResponse = guestResponses[Math.floor(Math.random() * guestResponses.length)];
                this.addChatMessage('ben', randomResponse);
                this.setState('happy');

                // Add a CTA button after the message
                setTimeout(() => {
                    this.addChatMessage('ben', "Ready to unlock my full brain? [Join Free Now](signup.html)");
                }, 400);
                return;
            }

            // Estimate complexity for members dynamically based on character count
            // Base cost: 10. Additional cost: 1 per 20 characters
            let cost = 10 + Math.floor(query.length / 20);

            if (cost >= 25) {
                const confirmed = confirm(`This complex request will cost ${cost} credits. Proceed?`);
                if (!confirmed) {
                    this.showTypingIndicator(false);
                    this.setState('default');
                    return;
                }
            }

            if (typeof creditsManager !== 'undefined' && !creditsManager.canAfford('noteAI', cost)) {
                this.showTypingIndicator(false);
                this.addChatMessage('ben', `I need ${cost} premium treats (credits) for that! 😿`);
                return;
            }

            if (typeof aiService === 'undefined') {
                throw new Error('AI Service not loaded');
            }

            if (typeof creditsManager !== 'undefined') {
                creditsManager.deduct('noteAI', cost);
            }

            // Load conversation history from sessionStorage (last 5 exchanges)
            let chatHistory = [];
            try {
                chatHistory = JSON.parse(sessionStorage.getItem('benChatHistory') || '[]');
            } catch (e) { chatHistory = []; }

            const pageContext = window.location.pathname.split('/').pop() || 'Dashboard';
            const isALevel = this.studentLevel === 'alevel';
            const studentContext = isALevel ? 'A-Level Student' : 'Undergraduate LLB Student';
            let extraFeatureContext = "";
            if (pageContext.toLowerCase().includes('news')) {
                extraFeatureContext = " The user is viewing official Gov.uk legal/parliamentary news. Remind them they can click on any news card, hit 'Interpret with AI' for 15 credits to get a perfect summary and timeline, and save articles using the star icon.";
            }

            // Build history context string
            const historyContext = chatHistory.length > 0
                ? `\n\nPrevious conversation (for context, respond naturally as a continuation):\n${chatHistory.map(h => `${h.role === 'user' ? 'Student' : 'Ben'}: ${h.text}`).join('\n')}`
                : '';

            const prompt = (query === 'SUMMON_PROMPT')
                ? `The user just clicked you on the "${pageContext}" page. You are Ben the Cat, their supportive law study buddy. Give a warm, funny, very brief 1-line greeting.`
                : (
                    `The user is on the "${pageContext}" page. They are a ${studentContext}.${extraFeatureContext} They ask: "${query}". Respond as Ben the Cat, their supportive and concise law study buddy. Keep it to 1-2 lines. Mention their current context (the page they are on) if it helps make the answer more relevant.${historyContext}`
                );

            // Trigger Thinking Mode if enabled
            if (typeof thinkingManager !== 'undefined' && thinkingManager.isDeepThinking && this.subscriptionTier === 'subscriber') {
                thinkingManager.start('GENERAL');
            }

            const response = await aiService.generateCompletion(
                prompt,
                "You are Ben, a supportive, concise, and law-savvy cat mascot for a UK law study platform. You help students with quick questions, study tips, and motivation. You are aware of which page the student is currently on and you use that to give more personalized advice. If there is conversation history, respond as a natural continuation of the conversation."
            );

            if (typeof thinkingManager !== 'undefined') thinkingManager.stop();

            this.showTypingIndicator(false);
            if (response.error) {
                this.addChatMessage('ben', "Ouch, my cat brain is fuzzy. Try again! Or just log in if you haven't yet. 🐾");
                this.setState('sad');
            } else {
                this.addChatMessage('ben', response.text);
                this.setState('happy');

                // Save to conversation history (keep last 5 exchanges = 10 messages)
                chatHistory.push({ role: 'user', text: query });
                chatHistory.push({ role: 'ben', text: response.text });
                if (chatHistory.length > 10) chatHistory = chatHistory.slice(-10);
                sessionStorage.setItem('benChatHistory', JSON.stringify(chatHistory));
            }

        } catch (e) {
            console.error("Mascot Chat Error:", e);
            this.showTypingIndicator(false);
            this.addChatMessage('ben', "Ouch, my cat brain is fuzzy. Try again! 🐾");
            this.setState('sad');
        }
    },

    addChatMessage(role, text) {
        const history = document.getElementById('ben-modal-history');
        if (!history) return;

        const div = document.createElement('div');
        div.className = `chat-msg ${role}`;
        
        // Ensure standard string
        let content = text || '';
        
        // Parse Markdown
        let htmlContent = content
            .replace(/### (.*?)$/gim, '<h3>$1</h3>')
            .replace(/## (.*?)$/gim, '<h2>$1</h2>')
            .replace(/# (.*?)$/gim, '<h1>$1</h1>')
            .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.*?)\*/g, '<em>$1</em>')
            .replace(/\n\n/g, '</p><p>')
            .replace(/\n/g, '<br>');

        div.innerHTML = `<p>${htmlContent}</p>`;
        
        history.appendChild(div);
        history.scrollTop = history.scrollHeight;
    },

    showTypingIndicator(show) {
        const indicator = document.getElementById('ben-typing-indicator');
        if (indicator) {
            if (show) indicator.classList.add('active');
            else indicator.classList.remove('active');
        }
    },

    /**
     * Renders HTML content directly into the bubble (for buttons/options)
     */
    renderChoices(html) {
        if (!this.bubble) return;
        this.bubble.innerHTML = html;
        this.bubble.classList.add('visible');

        // Ensure he stays happy while user chooses
        this.setState('happy');
    },

    handleMascotClick() {
        if (this.onCorrectionClick) {
            this.onCorrectionClick();
            this.onCorrectionClick = null;

            if (this.isAutoFixing) {
                this.speak("Fixing that for you! 😉");
                this.isAutoFixing = false;
            } else {
                this.speak("Fixed it for you! 😉");
            }

            this.setState('happy');

            // Go back to corner after a bit
            setTimeout(() => {
                this.resetPosition();
            }, 2000);
            return;
        }

        // Annoyance / Easter Egg Logic
        const now = Date.now();
        if (now - this.lastPetTime < 3000) {
            this.petCount++;
        } else {
            this.petCount = Math.max(0, this.petCount - 2); // Cool down slowly
        }
        this.lastPetTime = now;

        // Easter Egg: The Hungry Cat (5 quick clicks)
        if (this.petCount === 5) {
            this.setState('eating', 10000);
            this.speak("Nom nom nom... thanks for the virtual treats! 🐟", 6000);
            return;
        }

        if (this.petCount > 10) {
            this.setState('suspicious', 5000);
            this.speak(this.getRandomResponse('annoyed'), 5000);
            if (this.petCount > 15) this.petCount = 5; // Reset cap so user doesn't get stuck forever
        } else {
            // Default interaction: Petting
            this.setState('happy', 3000);
            this.speak(this.getRandomResponse('pet'), 4000);
            if (typeof AudioManager !== 'undefined') {
                AudioManager.playSFX('purr', true, { pitchVariance: 0.2 });
            }
        }
    },

    /**
     * Activity Feedback
     */
    handleActivity(type) {
        if (type === 'typing') {
            // If typing intensely, purr every now and then
            const now = Date.now();
            if (!this.lastPurrTime || (now - this.lastPurrTime > 15000)) {
                this.lastPurrTime = now;
                if (typeof AudioManager !== 'undefined') {
                    AudioManager.playSFX('purr', false, { pitchVariance: 0.15 });
                }
                // Subtle visual feedback
                if (this.currentState !== 'happy' && this.currentState !== 'walking') {
                    this.setState('happy', 2000);
                }
            }
        }
    }
};

document.addEventListener('DOMContentLoaded', () => {
    MascotBrain.init();
});
