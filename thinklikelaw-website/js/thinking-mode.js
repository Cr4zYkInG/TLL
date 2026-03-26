/**
 * ThinkingManager
 * Manages the live "Thinking Mode" UI for ThinkLikeLaw.
 * Exclusive for Subscribers.
 */

class ThinkingManager {
    constructor() {
        this.isActive = false;
        this.container = null;
        this.steps = [];
        this.currentStepIndex = -1;
        this.isDeepThinking = localStorage.getItem('deepThinkingEnabled') === 'true';
    }

    init(parentElement) {
        if (!parentElement) return;
        this.parentElement = parentElement;
    }

    setDeepThinking(enabled) {
        this.isDeepThinking = enabled;
        localStorage.setItem('deepThinkingEnabled', enabled);
    }

    start(type = 'GENERAL') {
        const tier = localStorage.getItem('subscriptionTier') || 'free';
        if (tier !== 'subscriber' || !this.isDeepThinking) {
            this.isActive = false;
            return;
        }

        this.isActive = true;
        this.createContainer();
        
        const defaultSteps = this.getStepsForType(type);
        defaultSteps.forEach(step => this.addStep(step));
        
        this.nextStep();
    }

    getStepsForType(type) {
        switch(type) {
            case 'VERIFY_OSCOLA':
                return [
                    "Extracting NCN citations...",
                    "Searching National Archives (TNA)...",
                    "Cross-referencing official record...",
                    "Analyzing formatting compliance...",
                    "Benchmarking against academic standards...",
                    "Generating authoritative feedback..."
                ];
            case 'GENERATE_NOTES':
                return [
                    "Scanning case law database...",
                    "Extracting Ratio Decidendi...",
                    "Synthesizing legal principles...",
                    "Structuring IRAC components...",
                    "Optimizing for high-fidelity recall...",
                    "Polishing academic tone..."
                ];
            case 'EXAM_MARK':
                return [
                    "Analyzing assessment criteria...",
                    "Evaluating AO1/AO2/AO3 levels...",
                    "Detecting argumentative gaps...",
                    "Benchmarking against first-class standards...",
                    "Finalizing grade projection..."
                ];
            default:
                return [
                    "Analyzing query intent...",
                    "Consulting training data...",
                    "Grounding with legal sources...",
                    "Synthesizing response..."
                ];
        }
    }

    createContainer() {
        if (this.container) this.container.remove();

        this.container = document.createElement('div');
        this.container.className = 'thinking-container';
        this.container.innerHTML = `
            <div class="thinking-header">
                <div class="thinking-badge">
                    <div class="thinking-dot"></div>
                    <span>Deep Research Mode</span>
                </div>
                <div class="brain-pulse">🧠</div>
            </div>
            <ul class="thinking-steps"></ul>
        `;
        
        this.parentElement.appendChild(this.container);
        this.stepsList = this.container.querySelector('.thinking-steps');
    }

    addStep(label) {
        const stepId = this.steps.length;
        this.steps.push({ label, id: stepId, status: 'pending' });
        
        const li = document.createElement('li');
        li.className = 'thinking-step';
        li.id = `step-${stepId}`;
        li.innerHTML = `
            <div class="step-icon">
                <i class="fas fa-circle-notch fa-spin" style="display:none;"></i>
                <i class="fas fa-check" style="display:none;"></i>
                <span class="step-num">${stepId + 1}</span>
            </div>
            <span>${label}</span>
        `;
        this.stepsList.appendChild(li);
    }

    nextStep() {
        if (!this.isActive) return;

        // Complete previous step
        if (this.currentStepIndex >= 0) {
            const prev = this.steps[this.currentStepIndex];
            prev.status = 'completed';
            const el = document.getElementById(`step-${prev.id}`);
            if (el) {
                el.classList.remove('active');
                el.classList.add('completed');
                el.querySelector('.fa-check').style.display = 'block';
                el.querySelector('.step-num').style.display = 'none';
                el.querySelector('.fa-spin').style.display = 'none';
            }
        }

        this.currentStepIndex++;
        
        if (this.currentStepIndex < this.steps.length) {
            const current = this.steps[this.currentStepIndex];
            current.status = 'active';
            const el = document.getElementById(`step-${current.id}`);
            if (el) {
                el.classList.add('active');
                el.querySelector('.fa-spin').style.display = 'block';
                el.querySelector('.step-num').style.display = 'none';
            }

            // Auto-advance for simulation (real logic would call this based on actual worker events)
            const delay = 800 + Math.random() * 1200;
            setTimeout(() => this.nextStep(), delay);
        }
    }

    stop() {
        this.isActive = false;
        if (this.container) {
            this.container.style.opacity = '0';
            setTimeout(() => {
                if (this.container) this.container.remove();
                this.container = null;
                this.steps = [];
                this.currentStepIndex = -1;
            }, 500);
        }
    }

    createToggleUI(parentElement) {
        if (!parentElement) return;
        
        const tier = localStorage.getItem('subscriptionTier') || 'free';
        const isSubscriber = tier === 'subscriber';
        
        const wrapper = document.createElement('div');
        wrapper.className = 'mode-toggle-container';
        wrapper.innerHTML = `
            <span class="toggle-label">${isSubscriber ? 'Deep Thinking' : 'Fast Mode (Free)'}</span>
            <label class="switch">
                <input type="checkbox" id="thinking-mode-checkbox" 
                    ${this.isDeepThinking ? 'checked' : ''} 
                    ${!isSubscriber ? 'disabled' : ''}>
                <span class="slider"></span>
            </label>
            ${!isSubscriber ? '<i class="fas fa-crown" style="color: gold; font-size: 0.7rem;" title="Subscriber Feature"></i>' : ''}
        `;
        
        parentElement.prepend(wrapper);
        
        const checkbox = wrapper.querySelector('#thinking-mode-checkbox');
        if (checkbox) {
            checkbox.addEventListener('change', (e) => {
                this.setDeepThinking(e.target.checked);
            });
        }
    }
}

const thinkingManager = new ThinkingManager();
window.thinkingManager = thinkingManager;
