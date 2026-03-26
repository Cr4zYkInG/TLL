/**
 * Exam Test Tool Logic
 * Manages timed sessions, anti-cheat, and timing metrics
 */

class ExamTestTool {
    constructor() {
        this.startTime = 0;
        this.timerInterval = null;
        this.isActive = false;
        this.tabSwitches = 0;
        this.isTabSwitchingWarned = false;

        this.paragraphData = []; // [{start: timestamp, words: 0}]
        this.currentParagraphStart = 0;

        this.editor = document.getElementById('exam-editor');
        this.rubricText = "";
        this.init();
    }

    init() {
        document.getElementById('btn-start-exam').onclick = () => this.startExam();
        document.getElementById('btn-finish-early').onclick = () => this.confirmSubmit();

        // Anti-Cheat: Tab Switching
        document.addEventListener('visibilitychange', () => {
            if (this.isActive && document.visibilityState === 'hidden') {
                this.tabSwitches++;
                this.logSecurityEvent("Tab switch detected");
                if (typeof MascotBrain !== 'undefined') {
                    MascotBrain.warnSuspicious("I saw that! Tab switching is recorded and affects your retention score. Stay focused! 🕵️‍♂️");
                }
            }
        });

        // Anti-Cheat: Copy/Paste
        this.editor.addEventListener('paste', (e) => {
            e.preventDefault();
            this.logSecurityEvent("Paste blocked");
            if (typeof MascotBrain !== 'undefined') {
                MascotBrain.warnSuspicious("No copy-pasting allowed! Ben is watching... everything must be hand-typed. 🧐");
            }
        });

        // Timing Tracking
        this.editor.addEventListener('keydown', (e) => {
            if (!this.isActive) return;

            // Track first key of a paragraph
            if (this.currentParagraphStart === 0) {
                this.currentParagraphStart = Date.now();
            }

            // Paragraph detection (Enter)
            if (e.key === 'Enter') {
                this.recordParagraph();
            }
        });

        // Word Count
        this.editor.addEventListener('input', () => {
            const count = this.editor.innerText.trim().split(/\s+/).length;
            document.getElementById('word-count').innerText = `${count} words`;
        });

        // Board Label
        const board = localStorage.getItem('examBoard') || 'AQA';
        document.getElementById('board-label').innerText = `${board.toUpperCase()} Legal Assessment`;
    }

    startExam() {
        const cost = 250;
        if (!creditsManager.canAfford('examAttempt')) {
            creditsManager.showSubscriptionCTA();
            return;
        }

        this.isActive = true;
        this.startTime = Date.now();
        this.currentParagraphStart = Date.now();
        document.getElementById('exam-pre-overlay').style.display = 'none';

        if (typeof MascotBrain !== 'undefined') {
            MascotBrain.enterInvigilatorMode();
        }

        // Timer Loop
        this.timerInterval = setInterval(() => {
            const delta = Date.now() - this.startTime;
            const h = Math.floor(delta / 3600000).toString().padStart(2, '0');
            const m = Math.floor((delta % 3600000) / 60000).toString().padStart(2, '0');
            const s = Math.floor((delta % 60000) / 1000).toString().padStart(2, '0');
            document.getElementById('time-display').innerText = `${h}:${m}:${s}`;
        }, 1000);

        if (typeof MascotBrain !== 'undefined') {
            MascotBrain.speak("Exam clock is ticking! Remember: Accuracy > Speed. Let's see what you've retained! 🏛️", 8000);
        }
    }

    recordParagraph() {
        const now = Date.now();
        const duration = (now - this.currentParagraphStart) / 1000;
        const text = this.editor.innerText;
        const paragraphs = text.split('\n').filter(p => p.trim().length > 0);
        const lastP = paragraphs[paragraphs.length - 1] || "";

        this.paragraphData.push({
            index: this.paragraphData.length + 1,
            time: duration,
            wordCount: lastP.split(/\s+/).length
        });

        this.currentParagraphStart = now;
    }

    logSecurityEvent(msg) {
        console.warn(`EXAM SECURITY: ${msg}`);
        const status = document.getElementById('tracking-status');
        if (status) {
            status.innerHTML = `<i class="fas fa-triangle-exclamation" style="color:#FFFFFF"></i> ${msg}`;
            status.style.opacity = "1";
            setTimeout(() => {
                status.innerHTML = `<i class="fas fa-shield-halved"></i> Security Active`;
                status.style.opacity = "0.4";
            }, 3000);
        }
    }

    confirmSubmit() {
        if (confirm("Are you sure you're finished? This will deduct 250 credits and generate your ultra-accurate assessment.")) {
            this.finalSubmit();
        }
    }

    async finalSubmit() {
        this.isActive = false;
        clearInterval(this.timerInterval);

        // Final paragraph record
        this.recordParagraph();

        const overlay = document.getElementById('submission-overlay');
        overlay.style.display = 'flex';

        const text = this.editor.innerText;
        const board = localStorage.getItem('examBoard') || 'AQA';

        const metrics = {
            totalTime: (Date.now() - this.startTime) / 1000,
            tabSwitches: this.tabSwitches,
            paragraphs: this.paragraphData,
            avgTimePerParagraph: (this.paragraphData.reduce((acc, p) => acc + p.time, 0) / this.paragraphData.length).toFixed(1)
        };

        try {
            // 1. Deduct Credits first
            if (typeof creditsManager !== 'undefined') {
                try {
                    creditsManager.deduct('examAttempt');
                } catch (e) {
                    overlay.style.display = 'none';
                    return; // creditsManager handles the alert/CTA
                }
            }

            // 2. Generate Assessment (The Generator)
            const initialAssessment = await aiService.generateExamModeAssessment(text, metrics, board, this.rubricText);
            if (initialAssessment.error) throw new Error(initialAssessment.error);

            // -- DOUBLE LAYER: THE AUDIT PASS --
            const stepText = document.getElementById('submission-step');
            if (stepText) stepText.innerText = "Senior Examiner Audit in Progress...";

            const auditPrompt = `You are a Senior Chief Examiner at a top UK University. 
            I have an AI-generated marking report for a Law student's exam.
            Your task:
            1. AUDIT the report for any hallucinated cases, incorrect statutes, or logically flawed marking.
            2. Correct any obscure case names to standard leading names.
            3. Ensure the tone is professionally critical yet constructive.
            
            Initial Report:
            ${initialAssessment.text}
            
            Return the final, verified marking report.`;

            const result = await aiService.generateCompletion(auditPrompt, "You are a Senior Chief Academic Examiner. You provide 100% accurate, rigorous, and verified legal assessments.");

            // 3. Save to Cloud
            if (typeof CloudData !== 'undefined') {
                const saved = await CloudData.saveExamResult({
                    text: text,
                    board: board,
                    metrics: metrics,
                    feedback: result.text
                });
                if (!saved) {
                    console.warn('Exam saved locally but cloud storage failed.');
                }
            }

            overlay.style.display = 'none';
            this.showResults(result.text);

            if (typeof MascotBrain !== 'undefined') {
                MascotBrain.setState('happy');
                MascotBrain.speak("Assessment complete! You can download your report or head back to Chambers. Excellent work! ✨");
            }
        } catch (e) {
            console.error('Exam Assessment Error:', e);
            alert("Error generating assessment: " + e.message);
            overlay.style.display = 'none';
        }
    }

    showResults(markdown) {
        const resultView = document.getElementById('exam-result-view');
        const resultContent = document.getElementById('result-content');

        // Robust MD to HTML covering structured sections
        let html = markdown
            .replace(/^# (.*$)/gim, '<h1 class="serif" style="font-size: 2.5rem; margin-bottom: 1rem;">$1</h1>')
            .replace(/^## (.*$)/gim, '<h2 class="serif" style="color:var(--accent-color); margin-top: 2.5rem; margin-bottom: 1rem; border-bottom: 1px solid rgba(255,255,255,0.1); padding-bottom: 0.5rem;">$1</h2>')
            .replace(/^### (.*$)/gim, '<h3 class="serif" style="margin-top: 1.5rem; color: #EEE;">$1</h3>')
            .replace(/\*\*(.*?)\*\*/g, '<strong style="color:var(--accent-color);">$1</strong>')
            .replace(/^\d+\.\s(.*$)/gim, '<div style="margin-bottom: 1rem; padding-left: 1rem; border-left: 2px solid var(--accent-color);">$1</div>') // Highlight numbered lists
            .replace(/\n\n/g, '<br><br>')
            .replace(/\n/g, '<br>');

        resultContent.innerHTML = `
            <div id="assessment-report-content" class="analysis-block" style="padding:4rem; background: rgba(10, 10, 11, 0.95); border: 1px solid var(--border-color); border-radius:32px; color:#FFFFFF; line-height: 1.6; font-size: 1.1rem; box-shadow: 0 40px 100px rgba(0,0,0,0.5);">
                <div style="text-align: center; margin-bottom: 3rem;">
                    <img src="images/logo-icon-final.png" alt="ThinkLikeLaw" style="height: 50px; margin-bottom: 1rem;">
                    <p style="opacity: 0.5; text-transform: uppercase; letter-spacing: 2px; font-size: 0.8rem;">Official Assessment Report</p>
                </div>
                ${html}
                <div class="ai-warning-alert" style="margin-top: 3rem; padding: 1.25rem; background: rgba(255,193,7,0.05); border: 1px solid rgba(255,193,7,0.2); border-radius: 16px; display: flex; gap: 1rem; font-size: 0.95rem; color: rgba(255,255,255,0.7); text-align: left; border-left: 4px solid #FFC107;">
                    <i class="fas fa-triangle-exclamation" style="color:#FFC107; font-size: 1.2rem; margin-top: 0.2rem;"></i>
                    <div>
                        <strong style="color:#FFC107; display:block; margin-bottom: 0.25rem; text-transform: uppercase; font-size: 0.85rem; letter-spacing: 0.05em;">Verify Assessment Results</strong>
                        This report is AI-generated for educational guidance. While our engine is tuned for high legal accuracy, it may occasionally misinterpret specific nuances or hallucinate obscure case citations. Always consult your university feedback and textbook for definitive grading.
                    </div>
                </div>
                <div style="margin-top: 4rem; padding-top: 2rem; border-top: 1px solid rgba(255,255,255,0.1); text-align: center; opacity: 0.4; font-size: 0.9rem;">
                    <p>© ${new Date().getFullYear()} ThinkLikeLaw AI Invigilator. Verified High-Stakes Legal Assessment.</p>
                </div>
            </div>`;

        resultView.style.display = 'block';
        resultView.scrollIntoView({ behavior: 'smooth' });

        // Setup PDF Download
        document.getElementById('btn-download-pdf').onclick = () => this.downloadPDF();
    }

    async handleRubricUpload(file) {
        if (!file) return;
        const statusEl = document.getElementById('rubric-status');
        const uploadBox = document.querySelector('.rubric-upload-section');

        try {
            uploadBox.style.opacity = '0.5';
            uploadBox.style.pointerEvents = 'none';

            const btnText = uploadBox.querySelector('div:nth-child(2)');
            const originalText = btnText ? btnText.innerText : "University Marking Rubric (Optional)";
            if (btnText) btnText.innerText = "Reading Rubric... Please wait...";

            // Reusing extraction logic similar to lecture-notes.html
            let text = "";
            const fileType = file.type;

            console.log("Starting rubric extraction for:", file.name, fileType);

            if (fileType === 'application/pdf') {
                if (typeof pdfjsLib === 'undefined') throw new Error("PDF Library not loaded. Please refresh.");
                text = await this.extractTextFromPDF(file);
            } else if (fileType.startsWith('image/')) {
                if (typeof Tesseract === 'undefined') throw new Error("OCR Library not loaded. Please refresh.");
                text = await this.extractTextFromImage(file);
            } else {
                throw new Error("Unsupported file type: " + fileType);
            }

            if (!text || text.trim().length < 10) {
                throw new Error("Could not extract enough text from this rubric. Please try a different file.");
            }

            this.rubricText = text;
            if (statusEl) statusEl.style.display = 'block';
            if (btnText) btnText.innerText = originalText;

            if (typeof MascotBrain !== 'undefined') {
                MascotBrain.speak("University rubric loaded! I'll hold you to those exact standards. 🏛️", 5000);
            }
        } catch (e) {
            console.error("Rubric Upload Error:", e);
            alert("Error reading rubric: " + e.message);
            if (statusEl) statusEl.style.display = 'none';
        } finally {
            uploadBox.style.opacity = '1';
            uploadBox.style.pointerEvents = 'auto';
        }
    }

    async extractTextFromPDF(file) {
        const reader = new FileReader();
        return new Promise((resolve, reject) => {
            reader.onload = async () => {
                try {
                    const typedarray = new Uint8Array(reader.result);
                    const pdf = await pdfjsLib.getDocument(typedarray).promise;
                    let fullText = "";
                    for (let i = 1; i <= pdf.numPages; i++) {
                        const page = await pdf.getPage(i);
                        const content = await page.getTextContent();
                        fullText += content.items.map(item => item.str).join(' ') + "\n";
                    }
                    resolve(fullText);
                } catch (e) { reject(e); }
            };
            reader.readAsArrayBuffer(file);
        });
    }

    async extractTextFromImage(file) {
        return new Promise((resolve, reject) => {
            Tesseract.recognize(file, 'eng')
                .then(({ data: { text } }) => resolve(text))
                .catch(err => reject(err));
        });
    }

    async generateMarking() {
        // This would be called when submitting
        // Pass this.rubricText to the AI prompt
        const text = this.editor.innerText;
        const board = localStorage.getItem('examBoard') || 'AQA';

        const prompt = `Assess this law student exam answer based on ${board} standards. 
        ${this.rubricText ? `CRITICAL: Also adhere to the following UNIVERSITY RUBRIC CRITERIA provided by the student: \n\n${this.rubricText}` : ""}
        
        Provide a detailed report with:
        1. AO marks breakdown
        2. Strengths and Weaknesses
        3. A projected First/2:1/etc grade.
        
        Student Work:
        ${text}`;

        // ... call AI service ...
    }

    async downloadPDF() {
        const element = document.getElementById('assessment-report-content');
        if (!element) return;

        const board = localStorage.getItem('examBoard') || 'AQA';
        const timestamp = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });

        const opt = {
            margin: 0.5,
            filename: `ThinkLikeLaw_Assessment_${board.toUpperCase()}_${new Date().getTime()}.pdf`,
            image: { type: 'jpeg', quality: 0.98 },
            html2canvas: {
                scale: 2,
                backgroundColor: '#0A0A0B',
                useCORS: true,
                logging: false
            },
            jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' }
        };

        // Create a clone for PDF rendering to ensure perfect styling without affecting the UI
        const pdfWrapper = document.createElement('div');
        pdfWrapper.style.background = '#0A0A0B';
        pdfWrapper.style.color = '#FFFFFF';
        pdfWrapper.style.padding = '50px';
        pdfWrapper.style.width = '800px'; // Approx A4 width after margins
        pdfWrapper.style.fontFamily = "'Inter', sans-serif";

        pdfWrapper.innerHTML = `
            <div style="border-bottom: 2px solid var(--accent-color, #E1B382); padding-bottom: 20px; margin-bottom: 30px; display: flex; justify-content: space-between; align-items: flex-end;">
                <div>
                    <h1 style="font-family: 'Playfair Display', serif; color: #E1B382; margin: 0; font-size: 28px;">ThinkLikeLaw ASSESSMENT</h1>
                    <p style="opacity: 0.6; margin: 5px 0 0 0; font-size: 14px;">Academic Standard: ${board.toUpperCase()}</p>
                </div>
                <p style="opacity: 0.5; margin: 0; font-size: 12px;">Date Issued: ${timestamp}</p>
            </div>
            <div style="line-height: 1.7;">
                ${element.innerHTML}
            </div>
            <div style="margin-top: 50px; padding-top: 20px; border-top: 1px solid rgba(255,255,255,0.1); text-align: center; opacity: 0.4; font-size: 10px;">
                <p>This report was generated by the ThinkLikeLaw AI Invigilator. It is intended for academic revision purposes only.</p>
                <p>www.thinklikelaw.com</p>
            </div>
        `;

        // Temporarily append to body to ensure styles are computed, then remove after capture
        document.body.appendChild(pdfWrapper);

        try {
            await html2pdf().set(opt).from(pdfWrapper).save();
        } finally {
            document.body.removeChild(pdfWrapper);
        }
    }
}

// Global scope for HTML handlers
async function handleRubricUpload(input) {
    if (window.examTool) {
        await window.examTool.handleRubricUpload(input.files[0]);
    }
}

// Init
window.addEventListener('load', () => {
    window.examTool = new ExamTestTool();
});
