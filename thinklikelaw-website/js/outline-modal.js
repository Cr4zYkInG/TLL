/**
 * Outline Modal Component
 * Handles the "Outline Notes" modal for selecting and generating outlines
 */

// Initialize modal functionality
function initOutlineModal() {
    const modal = document.getElementById('outline-modal');
    const openBtn = document.querySelector('[data-action="open-outline"]');
    const closeBtn = document.querySelector('[data-action="close-outline"]');
    const cancelBtn = document.querySelector('[data-action="cancel-outline"]');
    const generateBtn = document.querySelector('[data-action="generate-outline"]');
    const deselectBtn = document.querySelector('[data-action="deselect-all"]');
    const checkboxes = document.querySelectorAll('.lecture-checkbox');

    let selectedLectures = [];

    // Open modal
    if (openBtn) {
        openBtn.addEventListener('click', () => {
            modal.classList.add('active');
            updateSelectedCount();
        });
    }

    // Close modal
    function closeModal() {
        modal.classList.remove('active');
    }

    if (closeBtn) closeBtn.addEventListener('click', closeModal);
    if (cancelBtn) cancelBtn.addEventListener('click', closeModal);

    // Click outside to close
    modal?.addEventListener('click', (e) => {
        if (e.target === modal) closeModal();
    });

    // Checkbox selection
    checkboxes.forEach(checkbox => {
        checkbox.addEventListener('change', (e) => {
            const lectureId = e.target.dataset.lectureId;
            if (e.target.checked) {
                selectedLectures.push(lectureId);
            } else {
                selectedLectures = selectedLectures.filter(id => id !== lectureId);
            }
            updateSelectedCount();
        });
    });

    // Deselect all
    deselectBtn?.addEventListener('click', () => {
        checkboxes.forEach(cb => cb.checked = false);
        selectedLectures = [];
        updateSelectedCount();
    });

    // Update counter
    function updateSelectedCount() {
        const counter = document.getElementById('selected-count');
        if (counter) {
            counter.textContent = `${selectedLectures.length} of ${checkboxes.length} selected`;
        }

        // Update button text
        if (generateBtn) {
            generateBtn.innerHTML = `<i class="fas fa-magic"></i> Generate Outline (${selectedLectures.length})`;
            generateBtn.disabled = selectedLectures.length === 0;
        }
    }

    // Generate outline (placeholder)
    generateBtn?.addEventListener('click', async () => {
        if (selectedLectures.length === 0) return;

        closeModal();

        // Show skeleton loader
        const outputPanel = document.getElementById('output-panel');
        if (outputPanel) {
            outputPanel.innerHTML = `
                <div style="padding: 2rem;">
                    <h3 style="margin-bottom: 1rem;">Generating Outline...</h3>
                    <div class="skeleton skeleton-text"></div>
                    <div class="skeleton skeleton-text medium"></div>
                    <div class="skeleton skeleton-text short"></div>
                    <div class="skeleton skeleton-text" style="margin-top: 1rem;"></div>
                    <div class="skeleton skeleton-text medium"></div>
                    <div class="skeleton skeleton-text"></div>
                    <div class="skeleton skeleton-text short"></div>
                </div>
            `;
        }

        // Simulate AI generation (replace with actual AI call)
        await new Promise(resolve => setTimeout(resolve, 3000));

        if (outputPanel) {
            outputPanel.innerHTML = `
                <h2 style="margin-bottom: 1.5rem;">Study Outline</h2>
                <div style="color: var(--text-secondary); line-height: 1.8;">
                    <h3 style="color: var(--text-primary); margin-top: 1.5rem;">I. Key Concepts</h3>
                    <ul style="margin-left: 1.5rem;">
                        <li>Concept 1: Brief definition</li>
                        <li>Concept 2: Brief definition</li>
                    </ul>
                    
                    <h3 style="color: var(--text-primary); margin-top: 1.5rem;">II. Case Law</h3>
                    <ul style="margin-left: 1.5rem;">
                        <li><strong>Case Name v. Case Name</strong> - Key holding</li>
                    </ul>
                    
                    <p style="margin-top: 2rem; font-style: italic; opacity: 0.7;">
                        Generated from ${selectedLectures.length} lecture(s)
                    </p>
                </div>
            `;
        }
    });
}

// Auto-initialize if DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initOutlineModal);
} else {
    initOutlineModal();
}
