/**
 * Global Utilities for ThinkLikeLaw
 */

const BadWordFilter = {
    // Curated list of prohibited terms (expanded as needed)
    prohibited: [
        'abuse', 'admin', 'administrator', 'anal', 'anus', 'ass', 'bastard', 'bitch', 'boob', 'cock', 'cum', 'cunt',
        'dick', 'dildo', 'dyke', 'fag', 'fuck', 'goddamn', 'hell', 'homo', 'jerk', 'kike', 'nigger', 'orgasm', 'penis',
        'piss', 'pussy', 'queer', 'rape', 'retard', 'scrotum', 'sex', 'shit', 'slut', 'spastic', 'twat', 'vagina', 'whore'
    ],

    /**
     * Checks if a string contains any prohibited terms
     */
    isSafe(text) {
        if (!text) return true;
        const clean = text.toLowerCase().trim();
        return !this.prohibited.some(word => clean.includes(word));
    },

    /**
     * Validates a leaderboard username
     * - Must be 3-15 characters
     * - Alphanumeric and spaces only
     * - No bad words
     */
    validateUsername(username) {
        if (!username) return { valid: false, message: "Username cannot be empty." };
        if (username.length < 3) return { valid: false, message: "Minimum 3 characters required." };
        if (username.length > 15) return { valid: false, message: "Maximum 15 characters allowed." };

        const regex = /^[a-zA-Z0-0\s]+$/;
        if (!regex.test(username)) {
            return { valid: false, message: "Only letters, numbers, and spaces are allowed." };
        }

        if (!this.isSafe(username)) {
            return { valid: false, message: "This username is not allowed. Please choose another." };
        }

        return { valid: true };
    }
};

const TerminologyManager = {
    terms: {
        alevel: {
            module: 'Classes',
            moduleSingular: 'Class',
            lecture: 'Topics',
            lectureSingular: 'Topic'
        },
        llb: {
            module: 'Modules',
            moduleSingular: 'Module',
            lecture: 'Lectures',
            lectureSingular: 'Lecture'
        }
    },

    init() {
        const studentLevel = localStorage.getItem('studentLevel') || 'llb';
        const levelTerms = this.terms[studentLevel] || this.terms.llb;

        // Replace plural modules
        document.querySelectorAll('[data-term-module]').forEach(el => {
            // Use regex to replace only the text "Modules" but keep icons
            el.innerHTML = el.innerHTML.replace(/Modules/ig, levelTerms.module);
            if (el.innerHTML.toLowerCase().includes('chambers') && studentLevel === 'alevel') {
                el.innerHTML = el.innerHTML.replace(/Chambers/ig, "My Classes");
            }
        });

        // Replace singular modules
        document.querySelectorAll('[data-term-module-singular]').forEach(el => {
            el.innerHTML = el.innerHTML.replace(/Module/ig, levelTerms.moduleSingular);
        });

        // Replace plural lectures
        document.querySelectorAll('[data-term-lecture]').forEach(el => {
            el.innerHTML = el.innerHTML.replace(/Lectures/ig, levelTerms.lecture)
                .replace(/Lecture Notes/ig, `${levelTerms.lectureSingular} Notes`);
        });

        // Replace singular lectures
        document.querySelectorAll('[data-term-lecture-singular]').forEach(el => {
            el.innerHTML = el.innerHTML.replace(/Lecture/ig, levelTerms.lectureSingular)
                .replace(/Note/ig, levelTerms.lectureSingular);
        });
    },

    getTerm(type) {
        const studentLevel = localStorage.getItem('studentLevel') || 'llb';
        return this.terms[studentLevel]?.[type] || this.terms.llb[type];
    },

    translate(text) {
        const studentLevel = localStorage.getItem('studentLevel') || 'llb';
        if (studentLevel !== 'alevel') return text;

        return text.replace(/Modules/g, 'Classes')
            .replace(/Module/g, 'Class')
            .replace(/Lectures/g, 'Topics')
            .replace(/Lecture/g, 'Topic');
    }
};

document.addEventListener('DOMContentLoaded', () => {
    TerminologyManager.init();
});

// Global Particle Spawner (Visual Dopamine Hit)
window.spawnDopamineParticles = function (x, y) {
    for (let i = 0; i < 30; i++) {
        const p = document.createElement('div');
        p.className = 'dopamine-particle';
        document.body.appendChild(p);

        const angle = Math.random() * Math.PI * 2;
        const velocity = 40 + Math.random() * 60;
        const tx = Math.cos(angle) * velocity;
        const ty = Math.sin(angle) * velocity - 40; // slight upward bias

        const colors = ['#FFD700', '#4CAF50', '#00BCD4', '#FF4081', '#9C27B0'];
        p.style.left = x + 'px';
        p.style.top = y + 'px';
        p.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];

        p.animate([
            { transform: 'translate(0,0) scale(1)', opacity: 1 },
            { transform: `translate(${tx}px, ${ty}px) scale(0)`, opacity: 0 }
        ], {
            duration: 600 + Math.random() * 400,
            easing: 'cubic-bezier(0.25, 0.46, 0.45, 0.94)'
        }).onfinish = () => p.remove();
    }
};

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { BadWordFilter, TerminologyManager };
}
