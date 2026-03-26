/**
 * AI Service for ThinkLikeLaw
 * Routes all AI requests through the Cloudflare Worker proxy.
 * No API keys are stored client-side.
 */

class AIService {
    constructor() {
        this.provider = 'mistral';

        // Always use production Cloudflare Worker — it's deployed remotely
        this.proxyUrl = 'https://thinklikelaw-ai.5dwvxmf5mn.workers.dev';
    }

    /**
     * Get the current Supabase session token for auth
     */
    async getAuthToken() {
        try {
            if (typeof getCurrentSession === 'function') {
                const session = await getCurrentSession();
                return session?.access_token || null;
            }
        } catch (e) {
            console.warn('AIService: Could not get auth token');
        }
        return null;
    }

    /**
     * Get current user context (module, lecture, tier) for enriched AI responses
     */
    getContext() {
        const urlParams = new URLSearchParams(window.location.search);
        const moduleId = urlParams.get('module');
        const lectureId = urlParams.get('id');

        // Try to resolve module name from localStorage
        let moduleName = null;
        if (moduleId) {
            const customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
            const mod = customModules.find(m => m.id === moduleId);
            moduleName = mod?.name || moduleId;
        }

        // Try to resolve lecture title
        let lectureTitle = null;
        if (lectureId) {
            const note = JSON.parse(localStorage.getItem(`note-${lectureId}`) || 'null');
            lectureTitle = note?.title || null;
        }

        return {
            moduleName,
            lectureTitle,
            userTier: localStorage.getItem('subscriptionTier') || 'free',
            studentLevel: localStorage.getItem('studentLevel') || 'llb'
        };
    }

    async generateCompletion(prompt, systemRole = "You are a helpful legal assistant for UK law students.", type = 'CHAT', searchResults = null) {
        try {
            const token = await this.getAuthToken();
            const context = this.getContext();
            const useAIPlus = localStorage.getItem('mistralLargeEnabled') === 'true';

            const headers = {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            };

            if (token) {
                headers['Authorization'] = `Bearer ${token}`;
            }

            const response = await fetch(this.proxyUrl, {
                method: 'POST',
                headers,
                body: JSON.stringify({
                    prompt,
                    systemRole,
                    context,
                    type,
                    searchResults,
                    useAIPlus
                })
            });

            if (!response.ok) {
                const errText = await response.text();
                try {
                    const errJson = JSON.parse(errText);
                    console.error('AI Service Error (JSON):', errJson);
                    throw new Error(errJson.error || `AI Request Failed: ${response.status}`);
                } catch (e) {
                    console.error('AI Service Error (Text):', errText);
                    throw new Error(`AI Request Failed: ${response.status} ${response.statusText}`);
                }
            }

            const data = await response.json();
            return data;
        } catch (error) {
            console.error('AI Service Error:', error);
            this.showErrorNotification(error.message);
            throw error;
        }
    }

    /**
     * Specialized Search & Verify Logic
     * Injects web-scraped results to override hallucinations
     */
    async generateVerifiedNotes(text, searchData = []) {
        return this.generateCompletion(
            `Generate First-Class EXHAUSTIVE LLB lecture notes. Use the provided search data to ensure 100% accuracy for recent changes:\n\n${text}`,
            "Academic Professor notes with real-time verification.",
            'GENERATE_NOTES',
            searchData
        );
    }

    /**
     * Graceful error UI panel (replaces raw alert())
     */
    showErrorPanel(message) {
        // Remove existing error panel if present
        const existing = document.getElementById('ai-error-panel');
        if (existing) existing.remove();

        const panel = document.createElement('div');
        panel.id = 'ai-error-panel';
        panel.style.cssText = 'position:fixed;bottom:2rem;right:2rem;max-width:400px;padding:1.5rem 2rem;background:rgba(255,60,60,0.1);border:1px solid rgba(255,60,60,0.3);border-radius:16px;color:#ff6b6b;font-family:Inter,sans-serif;font-size:0.95rem;z-index:99999;backdrop-filter:blur(20px);animation:slideUp 0.4s ease;box-shadow:0 20px 60px rgba(0,0,0,0.3);';
        panel.innerHTML = `<div style="display:flex;align-items:center;gap:0.75rem;"><i class="fas fa-exclamation-triangle" style="font-size:1.3rem;"></i><div><strong>AI Service Issue</strong><br><span style="opacity:0.8;font-size:0.9rem;">${message}</span></div><button onclick="this.parentElement.parentElement.remove()" style="margin-left:auto;background:none;border:none;color:#ff6b6b;font-size:1.2rem;cursor:pointer;">&times;</button></div>`;
        document.body.appendChild(panel);
        setTimeout(() => panel.remove(), 8000);
    }

    async generateSummary(text) {
        const level = localStorage.getItem('studentLevel') || 'llb';
        if (level === 'alevel') {
            return this.generateCompletion(
                `Summarise the following case/legal text for an A-Level Law student.\n\nText:\n${text}`,
                "A-Level Law logic.",
                'SUMMARY'
            );
        }
        return this.generateCompletion(
            `Summarise this legal text using IRAC and OSCOLA. No hallucinations:\n\n${text}`,
            "LLB Case Summariser.",
            'SUMMARY'
        );
    }

    async generateLectureNotes(text) {
        return this.generateCompletion(
            `Generate First-Class LLB lecture notes for this text:\n\n${text}`,
            "Academic Professor notes.",
            'GENERATE_NOTES'
        );
    }

    /**
     * Ultra-Accurate Exam Mode Assessment
     * Processes text + timing metrics + paragraph data
     */
    async generateExamModeAssessment(text, metrics, board = 'AQA', rubricText = "") {
        const level = localStorage.getItem('studentLevel') || 'llb';
        const isALevel = level === 'alevel';

        const gradingSystem = isALevel
            ? `Use A-Level grading: provide a Level (1-4) and percentage. Break down Assessment Objectives: AO1 (Knowledge & Understanding), AO2 (Application), AO3 (Analysis & Evaluation). Each AO should have a separate score out of its maximum marks.`
            : `Use UK University grading: provide a precise percentage and classification (First-Class/2:1/2:2/Third/Fail). Break down: Legal Knowledge, IRAC Application, Case Law Authority, Critical Analysis.`;

        return this.generateCompletion(
            `Conduct an ULTRA-ACCURATE, professional-grade exam marking for this Law answer. 
            Exam Board: ${board}
            Student Level: ${isALevel ? 'A-Level Law' : 'LLB (Undergraduate Degree)'}
            ${rubricText ? `UNIVERSITY RUBRIC CRITERIA (ADHERE TO THIS): \n\n${rubricText}\n\n` : ""}
            User Text: ${text}
            
            Timing Data: ${JSON.stringify(metrics)}
            
            STRICT OUTPUT FORMAT (MANDATORY):
            1. **OVERALL SCORE & GRADE**: ${gradingSystem}
            2. **WHAT WENT WRONG**: Identify specific legal gaps.
            3. **IMPROVEMENT BLUEPRINT**: Practical steps.
            4. **REVISION ROADMAP**: Modules, cases, or statutes.
            5. **BEN'S ANALYTICS**: Timing data judgment.
            
            Strict Pedagogy: 
            - DO NOT provide direct corrections.
            - PROVIDE NON-DIRECT CLUES.`,
            "Chief Examiner Mode.",
            'MARK_EXAM'
        );
    }

    async generateDeepAnalysis(text, outputType = 'analysis') {
        let prompt = "";
        let systemRole = "You are a master of UK Law. You extract deep meaning from complex judgments.";

        if (outputType === 'timeline') {
            prompt = `Create an interactive Mermaid.js timeline for the following case/legal text. 
            Provide the output as a valid Mermaid timeline diagram. 
            Focus on chronologically ordering the facts and legal proceedings.
            Use the following format:
            \`\`\`mermaid
            timeline
                title [Case Name] Timeline
                Section [Year/Date] : [Event]
            \`\`\`
            Text: ${text}`;
            systemRole = "You are a legal visual architect. You convert complex case facts into clear Mermaid.js timeline syntax.";
        } else if (outputType === 'map') {
            prompt = `Create a Mermaid.js relationship map (flowchart) for the characters/parties and legal issues in this text.
            Show the flow of liability, duty, or relationships.
            Use the following format:
            \`\`\`mermaid
            graph TD
                A[Party A] -->|Legal Link| B[Party B]
            \`\`\`
            Text: ${text}`;
            systemRole = "You are a legal visual architect. You map out complex party relationships and legal duties using Mermaid.js syntax.";
        } else {
            prompt = `Perform a deep IRAC analysis of the following legal text. 
            Identify every hidden nuance, every ratio, and every obiter dicta.
            Highlight the Ratio Decidendi clearly.
            Text: ${text}`;
        }

        return this.generateCompletion(prompt, systemRole);
    }
}

const aiService = new AIService();
