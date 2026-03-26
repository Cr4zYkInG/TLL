/**
 * MascotThesaurus.js
 * Handles the logic for Ben's interactive synonym and definition support.
 */

const MascotThesaurus = {
    isWaitingForSelection: false,
    currentWord: null,

    activate() {
        if (typeof MascotBrain === 'undefined') return;

        this.isWaitingForSelection = true;
        MascotBrain.setState('happy');
        MascotBrain.speak("Essay help? Highlight a word in your notes and I'll find some first-class synonyms or definitions! (5 credits)");

        // Listen for selection change in the document
        const onSelect = () => {
            const selection = window.getSelection().toString().trim();
            if (selection && selection.split(/\s+/).length === 1 && this.isWaitingForSelection) {
                this.isWaitingForSelection = false;
                document.removeEventListener('mouseup', onSelect);
                this.handleSelection(selection);
            }
        };

        document.addEventListener('mouseup', onSelect);

        // Timeout if no selection made
        setTimeout(() => {
            if (this.isWaitingForSelection) {
                this.isWaitingForSelection = false;
                document.removeEventListener('mouseup', onSelect);
                MascotBrain.speak("Maybe later! Keep up the good work.");
            }
        }, 15000);
    },

    async handleSelection(word) {
        this.currentWord = word;
        MascotBrain.speak(`Analyzing "${word}"...`);

        try {
            if (typeof creditsManager !== 'undefined' && !creditsManager.canAfford('mascotThesaurus')) {
                MascotBrain.speak("You need 5 credits for this! Check your balance.");
                return;
            }

            const results = await this.fetchSynonyms(word);

            // Deduct credits
            if (typeof creditsManager !== 'undefined') {
                creditsManager.deduct('mascotThesaurus');
            }

            this.showChoices(results);
        } catch (e) {
            MascotBrain.speak("I couldn't find anything for that word. Law is complex!");
        }
    },

    async fetchSynonyms(word) {
        if (typeof aiService === 'undefined') throw new Error("AI service unavailable");

        const prompt = `Provide 3-4 sophisticated legal synonyms or a concise legal definition for the word: "${word}". 
        Format as JSON with keys: "synonyms" (array) and "definition" (string).`;

        const response = await aiService.generateCompletion(prompt, "You are a legal thesaurus aiding a law student with academic writing.");

        try {
            // Extract JSON from response (handling potential markdown)
            const jsonStr = response.text.match(/\{.*\}/s)[0];
            return JSON.parse(jsonStr);
        } catch (e) {
            // Fallback if AI doesn't return clean JSON
            return { synonyms: ["consensus", "covenant", "accord"], definition: "A binding legal agreement." };
        }
    },

    showChoices(data) {
        let html = `<div style="font-weight: 600; margin-bottom: 8px;">"${this.currentWord}" insights:</div>`;

        if (data.synonyms && data.synonyms.length > 0) {
            html += `<div style="display:flex; flex-wrap:wrap; gap:5px; margin-bottom: 10px;">`;
            data.synonyms.forEach(s => {
                html += `<button onclick="MascotThesaurus.applyChange('${s}')" style="background:var(--accent-color); color:white; border:none; border-radius:15px; padding:4px 10px; font-size:11px; cursor:pointer;">${s}</button>`;
            });
            html += `</div>`;
        }

        if (data.definition) {
            html += `<div style="font-size: 10px; font-style: italic; opacity: 0.8; line-height:1.2;">Def: ${data.definition}</div>`;
        }

        MascotBrain.renderChoices(html);
    },

    applyChange(newWord) {
        if (typeof replaceSelectionInEditor === 'function') {
            replaceSelectionInEditor(newWord);
            MascotBrain.speak(`Swapped for "${newWord}"! Looks more academic.`);
        } else {
            MascotBrain.speak("I couldn't swap it automatically, but it's a great choice!");
        }

        setTimeout(() => MascotBrain.resetPosition(), 3000);
    }
};

window.MascotThesaurus = MascotThesaurus;
