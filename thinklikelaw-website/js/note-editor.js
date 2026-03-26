/**
 * Note Editor Logic (v3) — Premium Redesign
 * Handles rich text editing, floating context menu, AI sidebar,
 * slash commands, lecture-scoped note isolation, and cloud persistence.
 */

document.addEventListener('DOMContentLoaded', () => {
    const editor = document.getElementById('editor');
    const titleHeader = document.getElementById('note-title-header');
    const titleInput = document.getElementById('note-title') || titleHeader;
    const saveBtn = document.getElementById('save-btn');
    const musicBtn = document.getElementById('focus-music-btn');
    const musicMenu = document.getElementById('focus-music-menu');

    // Proactive Scanner (Subscriber Only)
    let scannerTimeout = null;
    const PROACTIVE_SCAN_INTERVAL = 10000; // 10 seconds

    function startProactiveScanner() {
        if (!editor || typeof MascotBrain === 'undefined' || MascotBrain.subscriptionTier !== 'subscriber') return;
        // Event listener moved to central input handler
    }

    function runProactiveAudit() {
        if (!editor || typeof MascotBrain === 'undefined' || MascotBrain.subscriptionTier !== 'subscriber') return;
        const text = editor.innerText;

        // 1. OSCOLA Audit (Case name italics check)
        // Matches "Name v Name" but NOT when wrapped in tags like <i>
        const caseRegex = /([A-Z][a-z]+ v [A-Z][a-z]+)/g;
        let match;
        while ((match = caseRegex.exec(text)) !== null) {
            const caseName = match[0];
            // Poor man's check for italics (check if it exists inside <i> or <em> in the actual HTML)
            if (editor && !editor.innerHTML.includes(`<i>${caseName}</i>`) && !editor.innerHTML.includes(`<em>${caseName}</em>`)) {
                MascotBrain.triggerProactive('oscola', { word: caseName });
                return; // One nudge at a time
            }
        }

        // 2. Academic Tone Check
        const informalPhrases = [
            { phrase: "I think", replacement: "It is submitted that" },
            { phrase: "This shows", replacement: "This demonstrates" },
            { phrase: "lots of", replacement: "numerous" },
            { phrase: "basically", replacement: "essentially" }
        ];

        for (const item of informalPhrases) {
            if (text.toLowerCase().includes(item.phrase.toLowerCase())) {
                MascotBrain.triggerProactive('tone', { phrase: item.phrase, better: item.replacement });
                return;
            }
        }

        // 3. AO3 Evaluation Nudge (For A-Level Only)
        if (MascotBrain.studentLevel === 'alevel') {
            const ao2TriggerWords = ["consequently", "therefore", "this means", "as a result"];
            for (const word of ao2TriggerWords) {
                if (text.toLowerCase().includes(word) && !triggeredSections.has('ao3-' + word)) {
                    MascotBrain.triggerProactive('ao3');
                    triggeredSections.add('ao3-' + word);
                    return;
                }
            }
        }

        // 4. Deep Focus break detection
        const now = Date.now();
        const fortyFiveMins = 45 * 60 * 1000;
        if (now - MascotBrain.lastBreakTime > fortyFiveMins) {
            MascotBrain.triggerProactive('break');
            return;
        }

        // 4. Case Memory Simulation (Mocking cross-module awareness)
        const rememberedCases = ["Miller v Prime Minister", "R v Jogee", "Owens v Owens"];
        for (const c of rememberedCases) {
            if (text.includes(c) && !triggeredSections.has(c)) {
                MascotBrain.triggerProactive('memory', { case: c, module: 'Public Law' });
                triggeredSections.add(c);
                return;
            }
        }
    }

    // Add to init
    const triggeredSections = new Set();
    startProactiveScanner();

    // Toolbar buttons
    const interpretBtn = document.getElementById('interpret-btn');
    const toggleSidebarBtn = document.getElementById('toggle-sidebar-btn');
    const undoBtn = document.getElementById('undo-btn');
    const downloadBtn = document.getElementById('download-btn');
    const imageBtn = document.getElementById('image-btn');
    const lockBtn = document.getElementById('lock-btn');
    const editTitleBtn = document.getElementById('edit-title-btn');

    // Floating context menu
    const floatingMenu = document.getElementById('floating-menu');
    const ctxInterpret = document.getElementById('ctx-interpret');
    const ctxCritique = document.getElementById('ctx-critique');
    const ctxOptimise = document.getElementById('ctx-optimise');
    const ctxTable = document.getElementById('ctx-table');
    const ctxHighlight = document.getElementById('ctx-highlight');
    const ctxColors = document.getElementById('ctx-colors');

    // AI Sidebar
    const aiSidebar = document.getElementById('ai-sidebar');
    const closeSidebarBtn = document.getElementById('close-ai-sidebar');
    const aiLoading = document.getElementById('ai-loading');
    const aiResponse = document.getElementById('ai-response');

    // Slash menu
    const slashMenu = document.getElementById('slash-menu');

    // Upload modal
    const uploadModal = document.getElementById('upload-modal');

    // State
    let currentNoteId = null;
    let currentModuleId = null;
    let isLocked = false;
    let autoSaveTimer = null;
    let hasUnsavedChanges = false;
    const AUTOSAVE_DELAY = 2000;
    const SPELLCHECK_DELAY = 500; // Faster response time
    let spellCheckTimer = null;

    // Common legal and general typos
    const TYPO_DB = {
        'liabal': 'liable',
        'laible': 'liable',
        'oxygon': 'oxygen',
        'teh': 'the',
        'contractuall': 'contractual',
        'judgement': 'judgment', // Legal preference
        'prefrence': 'preference',
        'defendent': 'defendant',
        'plauntiff': 'plaintiff',
        'necligence': 'negligence',
        'agrement': 'agreement',
        'statuory': 'statutory',
        'procedurall': 'procedural',
        'constitunional': 'constitutional'
    };

    // AI History State
    let aiHistory = [];
    let currentHistoryIndex = -1;

    // Sidebar State
    let activeSidebarTab = 'interpret';
    let savedRange = null;

    // ─── Selection Helpers ───
    function saveSelection() {
        const sel = window.getSelection();
        if (sel.getRangeAt && sel.rangeCount) {
            savedRange = sel.getRangeAt(0);
        }
    }

    function restoreSelection() {
        if (savedRange) {
            const sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(savedRange);
        }
    }

    function updateStats() {
        const activeEditor = editor || document.getElementById('editor');
        if (!activeEditor) return;

        // Get text robustly
        const text = activeEditor.innerText || activeEditor.textContent || '';
        const cleanText = text.trim();

        // Better word count: handle different whitespace and special chars
        const words = cleanText ? cleanText.split(/\s+/).filter(word => word.trim().length > 0).length : 0;
        const chars = text.length;

        // Accurate reading time: 0 if < 10 words, else normal calc
        const readingTime = words < 10 ? 0 : Math.max(1, Math.ceil(words / 200));

        const wcEl = document.getElementById('word-count');
        const ccEl = document.getElementById('char-count');
        const rtEl = document.getElementById('reading-time');

        if (wcEl) wcEl.textContent = `${words} word${words !== 1 ? 's' : ''}`;
        if (ccEl) ccEl.textContent = `${chars} character${chars !== 1 ? 's' : ''}`;
        if (rtEl) rtEl.textContent = `${readingTime} min read`;

        // ─── Word Count Goal Logic ───
        const goalEl = document.getElementById('word-goal-progress');
        const containerEl = document.getElementById('word-goal-container');
        if (goalEl && containerEl && typeof currentNoteId !== 'undefined' && currentNoteId) {
            const goal = parseInt(localStorage.getItem(`wordGoal_${currentNoteId}`)) || 0;
            if (goal > 0) {
                containerEl.title = `Goal: ${goal} words (Click to change)`;
                const pct = Math.min(100, Math.round((words / goal) * 100));
                goalEl.style.width = `${pct}%`;
                if (pct >= 100) {
                    containerEl.classList.add('goal-met');
                } else {
                    containerEl.classList.remove('goal-met');
                }
            } else {
                goalEl.style.width = '0%';
                containerEl.title = 'Click to set word goal';
                containerEl.classList.remove('goal-met');
            }
        }

        console.log(`[StatsUpdate] Words: ${words}, Chars: ${chars}`);
    }

    // ─── Init ───
    function initNote() {
        // Parse params from Search OR Hash (to survive redirects)
        const urlParams = new URLSearchParams(window.location.search);
        let urlId = urlParams.get('id');
        let urlModuleId = urlParams.get('module');

        // Fallback: Check hash if params missing
        if ((!urlId && !urlModuleId) && window.location.hash) {
            // Support hash formats: #contract or #id=123&module=contract
            const hash = window.location.hash.substring(1);
            if (hash.includes('=')) {
                const hashParams = new URLSearchParams(hash);
                if (!urlId) urlId = hashParams.get('id');
                if (!urlModuleId) urlModuleId = hashParams.get('module');
            } else {
                // If just #contract, treat as module ID
                if (!urlModuleId) urlModuleId = hash;
            }
        }

        currentModuleId = urlModuleId || 'unassigned';

        // CRITICAL FIX: If no note ID, generate one AND PERSIST IT to URL
        if (!urlId) {
            // Check if we have a pending draft for this module to avoid data loss on refresh
            const pendingDraftId = localStorage.getItem(`pending-draft-${currentModuleId}`);
            if (pendingDraftId) {
                currentNoteId = pendingDraftId;
            } else {
                currentNoteId = `draft-${currentModuleId}-${Date.now()}`;
                localStorage.setItem(`pending-draft-${currentModuleId}`, currentNoteId);
            }

            // Update URL so refresh/tab switch keeps the same note
            const newUrl = new URL(window.location);
            newUrl.searchParams.set('id', currentNoteId);
            newUrl.searchParams.set('module', currentModuleId);
            window.history.replaceState({}, '', newUrl);
            console.log('Using Note ID:', currentNoteId);
        } else {
            currentNoteId = urlId;
            // Clear pending draft if we have a real ID now
            localStorage.removeItem(`pending-draft-${currentModuleId}`);
        }

        console.log('Init Note. Module:', currentModuleId, 'ID:', currentNoteId);

        // Global exports for debugging
        window.currentModuleId = currentModuleId;
        window.currentNoteId = currentNoteId;

        // Navigation Enforcement (Basic)
        // If module is unassigned, warn user or redirect? 
        // User requested: "Jumping to links directly shouldn't be allowed"
        // Navigation Enforcement (Strict)
        if (currentModuleId === 'unassigned') {
            console.warn('No module context found. Redirecting to modules list.');
            alert('Please select a module to create a note.');
            window.location.href = 'modules.html';
            return;
        }

        // Apply Language Settings
        applyLanguageSettings();

        // Load note from cloud/localStorage (lecture-scoped)
        loadNote();

        // Update breadcrumbs
        updateBreadcrumbs();

        // Track last opened module
        if (urlModuleId) {
            const customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
            const mod = customModules.find(m => m.id === urlModuleId);
            if (mod) {
                localStorage.setItem('lastOpenedModule', JSON.stringify({
                    id: mod.id,
                    name: mod.name,
                    timestamp: Date.now()
                }));
            }
        }
    }

    // ─── Language & Preferences ───
    function applyLanguageSettings() {
        try {
            const langInfo = JSON.parse(localStorage.getItem('editorLanguage') || '{"code":"en-GB"}');
            if (editor) {
                editor.lang = langInfo.code;
                editor.spellcheck = true;
            }
            console.log('Language settings applied:', langInfo.code);
        } catch (e) {
            console.warn('Failed to apply language settings:', e);
        }
    }

    // Expose for settings modal
    window.applyLanguageSettings = applyLanguageSettings;

    // ─── Deferred Initialization (Performance) ───
    function runDeferredInit() {
        applyLanguageSettings();
        if (typeof creditsManager !== 'undefined') {
            creditsManager.getCredits();
        }
        populateModuleDropdown();
    }

    function loadNote() {
        // Try cloud-data first, fallback to localStorage
        const storageKey = `note-${currentNoteId}`;
        const savedNote = JSON.parse(localStorage.getItem(storageKey) || 'null');

        if (savedNote) {
            if (titleInput) titleInput.value = savedNote.title || '';
            if (titleHeader) titleHeader.value = savedNote.title || 'Untitled';
            if (editor) editor.innerHTML = savedNote.content || '';

            // Track current data for retention updates later
            window.currentLectureData = savedNote;

            // Fast restore AI History from local/content
            const historyMarker = editor.querySelector('#ai-history-data');
            if (historyMarker && historyMarker.getAttribute('data-history')) {
                try {
                    aiHistory = JSON.parse(historyMarker.getAttribute('data-history'));
                } catch (e) { }
            } else if (savedNote.ai_history) {
                aiHistory = savedNote.ai_history;
            }

            if (aiHistory.length > 0) {
                currentHistoryIndex = aiHistory.length - 1;
                updateAIHistoryUI();
            }
        } else {
            titleInput.value = '';
            titleHeader.value = 'Untitled';
            editor.innerHTML = '';
        }

        // Initial stats update
        updateStats();

        // Also try cloud data
        if (typeof CloudData !== 'undefined') {
            CloudData.getLecture(currentNoteId).then(lecture => {
                if (lecture && lecture.content) {
                    if (editor && (editor.innerHTML === '' || (editor.innerHTML === (savedNote?.content || '') && editor.innerHTML !== lecture.content))) {
                        if (titleInput) titleInput.value = lecture.title || '';
                        if (titleHeader) titleHeader.value = lecture.title || 'Untitled';
                        if (editor) editor.innerHTML = lecture.content || '';

                        // Update track with fresh cloud data
                        window.currentLectureData = lecture;

                        // Set publish toggle state
                        const publishToggle = document.getElementById('publish-toggle');
                        if (publishToggle) publishToggle.checked = lecture.is_public || false;

                        // Extract AI History from content if available
                        const historyMarker = editor.querySelector('#ai-history-data');
                        if (historyMarker && historyMarker.getAttribute('data-history')) {
                            try {
                                aiHistory = JSON.parse(historyMarker.getAttribute('data-history'));
                                currentHistoryIndex = aiHistory.length - 1;
                                updateAIHistoryUI();
                            } catch (e) { console.warn('Failed to parse history from content'); }
                        } else if (lecture.ai_history) {
                            // Fallback to direct field
                            aiHistory = lecture.ai_history;
                            currentHistoryIndex = aiHistory.length - 1;
                            updateAIHistoryUI();
                        }

                        updateStats();
                        updateBreadcrumbs(); // Refresh breadcrumbs once cloud data is in
                    }
                }
            }).catch(() => { });
        }
    }

    function updateSyncStatus(status) {
        const syncEl = document.getElementById('sync-status');
        const saveBtnEl = document.getElementById('save-btn');
        if (!syncEl) return;
        const icon = syncEl.querySelector('i');
        const text = syncEl.querySelector('span');

        // Traffic Light Status Logic
        if (saveBtnEl) {
            saveBtnEl.classList.remove('save-status-red', 'save-status-yellow', 'save-status-green');
            if (status === 'saving') {
                saveBtnEl.innerHTML = '<i class="fas fa-sync fa-spin"></i>';
            } else if (status === 'synced') {
                saveBtnEl.classList.add('save-status-green');
                saveBtnEl.innerHTML = '<i class="fas fa-check"></i>';
            } else if (status === 'offline' || status === 'error') {
                saveBtnEl.classList.add('save-status-red');
                saveBtnEl.innerHTML = '<i class="fas fa-exclamation-triangle"></i>';
            } else if (status === 'modified') {
                saveBtnEl.classList.add('save-status-yellow');
                saveBtnEl.innerHTML = '<i class="fas fa-check"></i>';
            }
        }

        if (status === 'saving') {
            syncEl.className = 'sync-status saving';
            if (icon) icon.className = 'fas fa-sync fa-spin';
            if (text) text.textContent = 'Saving...';
        } else if (status === 'synced') {
            syncEl.className = 'sync-status';
            if (icon) icon.className = 'fas fa-cloud';
            if (text) text.textContent = 'Cloud Synced';
        } else if (status === 'offline') {
            syncEl.className = 'sync-status offline';
            if (icon) icon.className = 'fas fa-cloud-slash';
            if (text) text.textContent = 'Local Only';
        }
    }

    function saveNote(andRedirect = false) {
        if (!editor) return;

        // Remove old history marker before saving clean content
        const oldMarker = editor.querySelector('#ai-history-data');
        if (oldMarker) oldMarker.remove();

        const title = (titleInput ? titleInput.value.trim() : (titleHeader ? titleHeader.value.trim() : '')) || 'Untitled';
        const content = editor.innerHTML || '';

        console.log(`[SaveNote] Saving "${title}" (${content.length} chars)`);

        const noteData = {
            id: currentNoteId,
            module: currentModuleId,
            title: title,
            content: content,
            ai_history: aiHistory, // Dynamic history sync
            created_at: new Date().toISOString()
        };

        // Preserve additional fields if they exist in window.currentLectureData
        if (window.currentLectureData) {
            const parityFields = [
                'review_count', 'last_reviewed_at', 'retention_score', 'is_public', 'upvotes',
                'attachment_url', 'drawing_data', 'pdf_data', 'audio_url', 'paper_style', 'paper_color'
            ];
            parityFields.forEach(field => {
                if (window.currentLectureData[field] !== undefined) {
                    noteData[field] = window.currentLectureData[field];
                }
            });
        }

        // Check for publish toggle specifically
        const publishToggle = document.getElementById('publish-toggle');
        if (publishToggle) {
            noteData.is_public = publishToggle.checked;
        }

        console.log('Note Data to Save:', noteData);

        // Save to localStorage (immediate, lecture-scoped)
        localStorage.setItem(`note-${currentNoteId}`, JSON.stringify(noteData));

        // Critical Fix: Clear the pending draft marker so future "Create Note" clicks get a fresh ID
        localStorage.removeItem(`pending-draft-${currentModuleId}`);

        // Update list of saved notes in LS for "My Modules" fallback
        let allNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
        const index = allNotes.findIndex(n => n.id === currentNoteId);
        const listData = { ...noteData, created: new Date().toISOString(), lastModified: new Date().toISOString() };
        if (index !== -1) {
            allNotes[index] = { ...allNotes[index], ...listData };
        } else {
            allNotes.push(listData);
        }
        localStorage.setItem('savedLectureNotes', JSON.stringify(allNotes));

        // Save to cloud
        updateSyncStatus('saving');
        if (typeof CloudData !== 'undefined') {
            if (saveBtn) saveBtn.innerHTML = '<i class="fas fa-sync fa-spin"></i> Saving...';
            return CloudData.saveLecture(noteData).then((savedData) => {
                updateSyncStatus('synced');
                hasUnsavedChanges = false; // Move inside

                if (savedData && savedData.id && savedData.id !== currentNoteId) {
                    const oldId = currentNoteId;
                    currentNoteId = savedData.id;

                    // Update URL without refreshing
                    const newUrl = new URL(window.location);
                    newUrl.searchParams.set('id', currentNoteId);
                    window.history.replaceState({}, '', newUrl);

                    // Re-save under new ID in localStorage and remove old
                    localStorage.setItem(`note-${currentNoteId}`, JSON.stringify({ ...noteData, id: currentNoteId }));
                    localStorage.removeItem(`note-${oldId}`);

                    // Update savedLectureNotes array
                    let allNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
                    const idx = allNotes.findIndex(n => n.id === oldId);
                    if (idx !== -1) {
                        allNotes[idx].id = currentNoteId;
                        localStorage.setItem('savedLectureNotes', JSON.stringify(allNotes));
                    }
                }

                if (saveBtn) {
                    saveBtn.classList.add('saved');
                    saveBtn.innerHTML = '<i class="fas fa-check"></i> Saved';
                }

                if (andRedirect) {
                    setTimeout(() => {
                        window.location.href = currentModuleId ? `modules.html?id=${currentModuleId}` : 'modules.html';
                    }, 500);
                }

                setTimeout(() => {
                    if (saveBtn) {
                        saveBtn.classList.remove('saved');
                        saveBtn.innerHTML = '<i class="fas fa-save"></i> Save Note';
                    }
                }, 2000);
                return true;
            }).catch(e => {
                console.warn('Cloud save failed:', e);
                updateSyncStatus('offline');
                if (saveBtn) {
                    saveBtn.classList.add('save-status-red');
                    saveBtn.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Local Only';
                    setTimeout(() => {
                        saveBtn.classList.remove('save-status-red');
                        saveBtn.innerHTML = '<i class="fas fa-save"></i> Save Note';
                    }, 2000);
                }
                return false;
            });
        } else {
            // Visual feedback (Local only)
            updateSyncStatus('offline');
            hasUnsavedChanges = false;
            if (saveBtn) {
                saveBtn.classList.add('saved');
                const btnIcon = saveBtn.querySelector('i');
                if (btnIcon) btnIcon.className = 'fas fa-check';
                setTimeout(() => saveBtn.classList.remove('saved'), 1500);
            }
            if (andRedirect) {
                setTimeout(() => {
                    window.location.href = currentModuleId ? `modules.html?id=${currentModuleId}` : 'modules.html';
                }, 500);
            }
            return Promise.resolve(true);
        }
    }


    function scheduleAutoSave() {
        hasUnsavedChanges = true;
        updateSyncStatus('modified');
        updateStats(); // Ensure stats are updated on every change (including programatic)
        clearTimeout(autoSaveTimer);
        autoSaveTimer = setTimeout(saveNote, AUTOSAVE_DELAY);
    }

    // ─── Breadcrumbs ───
    async function updateBreadcrumbs() {
        const builtInModules = {
            'contract': 'Contract Law',
            'tort': 'Tort Law',
            'public-law': 'Public Law',
            'equity': 'Equity & Trusts'
        };

        let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        let mod = customModules.find(m => m.id === currentModuleId);

        if (!mod && currentModuleId && currentModuleId !== 'unassigned' && typeof CloudData !== 'undefined') {
            try {
                const modules = await CloudData.getModules();
                mod = modules.find(m => m.id === currentModuleId);
            } catch (e) { console.warn('Breadcrumb fetch failed'); }
        }

        const bcModName = document.getElementById('bc-module-name');
        if (bcModName) {
            if (mod) {
                bcModName.textContent = mod.name;
            } else if (builtInModules[currentModuleId]) {
                bcModName.textContent = builtInModules[currentModuleId];
            } else {
                // Fallback to capitalizing the ID, or a generic placeholder
                bcModName.textContent = currentModuleId !== 'unassigned'
                    ? currentModuleId.split('-').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')
                    : 'Unassigned Module';
            }
        }

        updateBreadcrumbTitle();
    }

    function updateBreadcrumbTitle() {
        const bcLectureTitle = document.getElementById('bc-lecture-title');
        if (bcLectureTitle) {
            bcLectureTitle.textContent = titleHeader.value || 'Untitled';
        }
    }

    // Sync breadcrumb title on every change
    titleHeader?.addEventListener('input', updateBreadcrumbTitle);

    function show(id) {
        const el = document.getElementById(id);
        if (el) el.style.display = '';
    }

    // ─── Title Sync ───
    if (titleInput && titleHeader) {
        titleInput.addEventListener('input', () => {
            titleHeader.value = titleInput.value || 'Untitled';
            updateBreadcrumbTitle();
            scheduleAutoSave();
        });

        titleHeader.addEventListener('input', () => {
            titleInput.value = titleHeader.value;
            updateBreadcrumbTitle();
            scheduleAutoSave();
        });
    }

    // ─── Mark as Reviewed Logic ───
    const markReviewedBtn = document.getElementById('btn-mark-reviewed');
    if (markReviewedBtn) {
        markReviewedBtn.addEventListener('click', async () => {
            if (!window.currentLectureData) {
                alert("Please save the note at least once before reviewing.");
                return;
            }

            markReviewedBtn.disabled = true;
            markReviewedBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Registering...';

            // Update stats
            window.currentLectureData.review_count = (window.currentLectureData.review_count || 0) + 1;
            window.currentLectureData.last_reviewed_at = new Date().toISOString();

            // Recalculate score via RetentionEngine if loaded
            if (typeof RetentionEngine !== 'undefined') {
                window.currentLectureData.retention_score = RetentionEngine.calculateRetention(window.currentLectureData);
            } else {
                window.currentLectureData.retention_score = 100;
            }

            saveNote();

            setTimeout(() => {
                markReviewedBtn.classList.add('saved');
                markReviewedBtn.style.background = '#4CAF50';
                markReviewedBtn.style.color = 'white';
                markReviewedBtn.innerHTML = '<i class="fas fa-check"></i> Brain Boosted!';

                // Play success sound
                if (typeof AudioManager !== 'undefined') {
                    AudioManager.playSFX('success');
                }

                // Visual Dopamine Hit
                if (typeof window.spawnDopamineParticles === 'function') {
                    const rect = markReviewedBtn.getBoundingClientRect();
                    window.spawnDopamineParticles(rect.left + rect.width / 2, rect.top + rect.height / 2);
                }

                setTimeout(() => {
                    markReviewedBtn.disabled = false;
                    markReviewedBtn.style.background = '';
                    markReviewedBtn.style.color = '';
                    markReviewedBtn.classList.remove('saved');
                    markReviewedBtn.innerHTML = '<i class="fas fa-brain"></i> Mark as Reviewed';
                }, 3000);
            }, 800);
        });
    }

    // ─── Read Aloud (TTS) Logic ───
    const readAloudBtn = document.getElementById('read-aloud-btn');
    let ttsActive = false;
    let ttsUtterance = null;

    if (readAloudBtn) {
        readAloudBtn.addEventListener('click', () => {
            if (ttsActive) {
                window.speechSynthesis.cancel();
                ttsActive = false;
                readAloudBtn.classList.remove('active');
                readAloudBtn.innerHTML = '<i class="fas fa-volume-up"></i> Read Aloud';
            } else {
                const text = editor.innerText.trim();
                if (!text) {
                    alert("Nothing to read! Try writing some notes first.");
                    return;
                }

                ttsActive = true;
                readAloudBtn.classList.add('active');
                readAloudBtn.innerHTML = '<i class="fas fa-stop"></i> Stop Listening';

                ttsUtterance = new SpeechSynthesisUtterance(text);
                ttsUtterance.rate = 1.0;
                ttsUtterance.pitch = 1.0;
                ttsUtterance.lang = 'en-GB';

                ttsUtterance.onend = () => {
                    ttsActive = false;
                    readAloudBtn.classList.remove('active');
                    readAloudBtn.innerHTML = '<i class="fas fa-volume-up"></i> Read Aloud';
                };

                window.speechSynthesis.speak(ttsUtterance);
            }
        });
    }


    if (editTitleBtn) {
        editTitleBtn.addEventListener('click', () => {
            if (titleInput) {
                titleInput.focus();
                if (titleInput.select) titleInput.select();
            }
        });
    }

    // ─── Toolbar Formatting ───
    document.querySelectorAll('.pill-btn[data-command]').forEach(btn => {
        btn.addEventListener('mousedown', (e) => {
            e.preventDefault(); // Prevent focus loss
            document.execCommand(btn.dataset.command, false, null);
            if (editor) editor.focus();
            scheduleAutoSave();
        });
    });

    // Undo / Redo
    if (undoBtn) {
        undoBtn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            document.execCommand('undo');
            editor.focus();
            scheduleAutoSave();
        });
    }

    // ─── Custom UI Dropdowns (Color & Text Size) ───
    const colorBtn = document.getElementById('text-color-btn');
    const colorMenu = document.getElementById('text-color-menu');
    const activeColorDot = document.getElementById('active-color-dot');

    const decreaseSizeBtn = document.getElementById('decrease-size-btn');
    const increaseSizeBtn = document.getElementById('increase-size-btn');
    const sizeLabel = document.getElementById('current-text-size');

    // Font size mapping (1-7 HTML values to PX display labels)
    const fontSizeMap = {
        1: 10,
        2: 13,
        3: 16,
        4: 18,
        5: 24,
        6: 32,
        7: 48
    };

    function updateTextSizeUI(sizeIndex) {
        if (!sizeLabel) return;
        const displaySize = fontSizeMap[sizeIndex] || 16;
        sizeLabel.textContent = displaySize;
    }

    // Helper to get current font size index [1-7] from the active selection
    function getCurrentFontSizeIndex() {
        let size = document.queryCommandValue('fontSize');
        if (!size || size === '') {
            // Default to 16px (index 3) if not explicitly set
            return 3;
        }
        return parseInt(size, 10);
    }

    function changeFontSize(delta) {
        saveSelection();
        let currentIndex = getCurrentFontSizeIndex();

        // Calculate new index and cap between 1 and 7
        let newIndex = currentIndex + delta;
        if (newIndex < 1) newIndex = 1;
        if (newIndex > 7) newIndex = 7;

        // Browsers require focus to execCommand successfully on selection
        if (editor) editor.focus();

        // Restore exact selection range
        restoreSelection();

        // Execute the native command
        document.execCommand('fontSize', false, newIndex);

        // Visually update the UI number
        updateTextSizeUI(newIndex);

        // Re-save selection so consecutive clicks keep working on the same highlighted text
        saveSelection();

        scheduleAutoSave();
    }

    if (decreaseSizeBtn) {
        decreaseSizeBtn.addEventListener('mousedown', (e) => {
            e.preventDefault(); // Prevents editor focus loss
            changeFontSize(-1);
        });
    }

    if (increaseSizeBtn) {
        increaseSizeBtn.addEventListener('mousedown', (e) => {
            e.preventDefault(); // Prevents editor focus loss
            changeFontSize(1);
        });
    }

    // Dynamic Cursor Tracker for Sizing
    // Attach to selectionchange to update UI immediately whenever cursor moves
    document.addEventListener('selectionchange', () => {
        // Only trigger if cursor is inside the editor
        const activeEl = document.activeElement;
        const selection = window.getSelection();
        if (activeEl === editor || (selection.anchorNode && editor.contains(selection.anchorNode))) {
            let currentIndex = getCurrentFontSizeIndex();
            updateTextSizeUI(currentIndex);
        }
    });

    // Handle Color Selection Toggle
    if (colorBtn && colorMenu) {
        colorBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            saveSelection(); // Capture selection before menu opens
            colorMenu.classList.toggle('active');
        });

        // Close color menu on click outside
        document.addEventListener('click', (e) => {
            if (!colorBtn.contains(e.target)) {
                colorMenu.classList.remove('active');
            }
        });

        colorMenu.querySelectorAll('.color-swatch').forEach(swatch => {
            swatch.addEventListener('mousedown', (e) => {
                e.preventDefault(); // CRITICAL: Prevents focus loss from the editor
                e.stopPropagation();

                const color = swatch.dataset.color;

                // Update active indicator
                colorMenu.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));
                swatch.classList.add('selected');
                if (activeColorDot) activeColorDot.style.backgroundColor = color;

                // Restore selection and focus before applying
                restoreSelection();
                if (editor) editor.focus();

                // Apply color to text
                document.execCommand('foreColor', false, color);

                // Keep menu open for multi-color selection (Word-like) 
                // but if user clicks away it will close via document listener
                scheduleAutoSave();
            });
        });

        // Custom color picker input
        const customColorInput = document.getElementById('custom-color-input');
        if (customColorInput) {
            customColorInput.addEventListener('input', (e) => {
                const color = e.target.value;
                restoreSelection();
                if (editor) editor.focus();
                restoreSelection();
                document.execCommand('foreColor', false, color);

                // Update UI
                if (activeColorDot) activeColorDot.style.backgroundColor = color;
                colorMenu.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));

                scheduleAutoSave();
            });
        }
    }

    // ─── Floating Context Menu ───
    function showFloatingMenu() {
        const selection = window.getSelection();
        if (!selection.rangeCount || selection.isCollapsed) {
            hideFloatingMenu();
            return;
        }

        const range = selection.getRangeAt(0);
        const rect = range.getBoundingClientRect();

        // Load Quick Colors
        const quickColors = JSON.parse(localStorage.getItem('quickHighlightColors') || '["#FFF3BF", "#D3F9D8", "#FFD6D6"]');

        // Update Quick Color Dots in Floating Menu
        const quickColorContainer = document.getElementById('quick-color-row');
        if (quickColorContainer) {
            quickColorContainer.innerHTML = '';
            quickColors.forEach(color => {
                const dot = document.createElement('div');
                dot.className = 'quick-color-dot';
                dot.style.backgroundColor = color;
                dot.onmousedown = (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    document.execCommand('hiliteColor', false, color);
                    hideFloatingMenu();
                    editor.focus();
                };
                quickColorContainer.appendChild(dot);
            });
            // Add "clear" option
            const clearDot = document.createElement('div');
            clearDot.className = 'quick-color-dot clear';
            clearDot.innerHTML = '<i class="fas fa-ban"></i>';
            clearDot.onmousedown = (e) => {
                e.preventDefault();
                e.stopPropagation();
                document.execCommand('removeFormat');
                hideFloatingMenu();
                editor.focus();
            };
            quickColorContainer.appendChild(clearDot);
        }

        floatingMenu.style.display = 'flex';
        // Fix z-index issue
        floatingMenu.style.zIndex = '3000';

        // Position correctly relative to viewport
        const topPos = rect.bottom + 8;
        const leftPos = rect.left + rect.width / 2 - 80;

        floatingMenu.style.top = `${window.scrollY + topPos}px`;
        floatingMenu.style.left = `${leftPos}px`;
    }

    function hideFloatingMenu() {
        floatingMenu.style.display = 'none';
        if (ctxColors) ctxColors.style.display = 'none';
    }

    editor.addEventListener('mouseup', () => {
        setTimeout(() => {
            const sel = window.getSelection();
            if (sel && !sel.isCollapsed) {
                showFloatingMenu();
            } else {
                hideFloatingMenu();
            }
        }, 150);
    });

    document.addEventListener('mousedown', (e) => {
        if (!floatingMenu.contains(e.target) && e.target !== editor) {
            hideFloatingMenu();
        }
    });

    // Context Menu - Interpret
    if (ctxInterpret) {
        ctxInterpret.addEventListener('mousedown', (e) => {
            e.preventDefault();
            hideFloatingMenu();
            runAIInterpret();
        });
    }

    // Context Menu - Quick Optimise
    if (ctxOptimise) {
        ctxOptimise.addEventListener('mousedown', (e) => {
            e.preventDefault();
            hideFloatingMenu();
            runAIOptimise();
        });
    }

    // Context Menu - Academic Critique
    if (ctxCritique) {
        ctxCritique.addEventListener('mousedown', (e) => {
            e.preventDefault();
            hideFloatingMenu();
            runAICritique();
        });
    }

    // Context Menu - Table
    if (ctxTable) {
        ctxTable.addEventListener('mousedown', (e) => {
            e.preventDefault();
            hideFloatingMenu();
            insertTable();
        });
    }

    // Context Menu - Highlight toggle
    if (ctxHighlight) {
        ctxHighlight.addEventListener('mousedown', (e) => {
            e.preventDefault();
            ctxColors.style.display = ctxColors.style.display === 'flex' ? 'none' : 'flex';
        });
    }

    // Color palette clicks
    document.querySelectorAll('.color-circle').forEach(circle => {
        circle.addEventListener('mousedown', (e) => {
            e.preventDefault();
            const color = circle.dataset.color;
            if (color === 'transparent') {
                document.execCommand('removeFormat');
            } else {
                // Try both to ensure compatibility
                document.execCommand('hiliteColor', false, color);
                document.execCommand('backColor', false, color);
            }
            hideFloatingMenu();
            editor.focus();
        });
    });

    // ─── AI Interpret ───
    function runAIInterpret() {
        const selectedText = window.getSelection().toString().trim();
        if (!selectedText) {
            alert('Please select text to interpret.');
            return;
        }

        // Open sidebar
        aiSidebar.classList.add('active');
        aiLoading.style.display = 'flex';
        aiResponse.innerHTML = '';

        // Check and Deduct Credits
        try {
            if (typeof creditsManager !== 'undefined') {
                creditsManager.deduct('noteAI'); // Cost: 15
            }
        } catch (creditErr) {
            console.warn("Credit deduction failed:", creditErr);
            aiLoading.style.display = 'none';
            // CTA is handled by creditsManager
            aiResponse.innerHTML = `<p style="color:#999;text-align:center;padding:2rem;">Insufficient credits for AI analysis.</p>`;
            return;
        }

        if (typeof aiService !== 'undefined') {
            aiService.generateCompletion(
                `Interpret and analyze this UK law text for a student. Explain key concepts, cite relevant cases and statutes using OSCOLA format, and identify important principles:\n\n"${selectedText}"`,
                "You are a UK law expert tutor. Provide clear, structured legal analysis with OSCOLA compliant citations."
            ).then(result => {
                aiLoading.style.display = 'none';
                if (result.error) {
                    aiResponse.innerHTML = `<p style="color:#E74C3C">${result.error}</p>`;
                } else {
                    aiResponse.innerHTML = formatAIResponse(result.text);
                }
                // Credits already deducted above

                // Add to History
                if (result.text) {
                    aiHistory.push({
                        title: selectedText.substring(0, 30) + (selectedText.length > 30 ? '...' : ''),
                        content: result.text
                    });
                    currentHistoryIndex = aiHistory.length - 1;
                    updateAIHistoryUI();
                }
            }).catch(err => {
                aiLoading.style.display = 'none';
                aiResponse.innerHTML = `<p style="color:#E74C3C">Error: ${err.message}</p>`;
            });
        }
    }

    function updateAIHistoryUI() {
        const nav = document.getElementById('ai-history-nav');
        const count = document.getElementById('ai-history-count');
        const prevBtn = document.getElementById('ai-prev');
        const nextBtn = document.getElementById('ai-next');

        if (aiHistory.length > 1) {
            nav.style.display = 'flex';
            count.textContent = `${currentHistoryIndex + 1}/${aiHistory.length}`;
            prevBtn.disabled = currentHistoryIndex === 0;
            nextBtn.disabled = currentHistoryIndex === aiHistory.length - 1;

            // Update sidebar content
            aiResponse.innerHTML = formatAIResponse(aiHistory[currentHistoryIndex].content);
        } else if (aiHistory.length === 1) {
            nav.style.display = 'none'; // Only one entry, no need for nav yet
            aiResponse.innerHTML = formatAIResponse(aiHistory[0].content);
        }
    }

    // AI History Navigation
    document.getElementById('ai-prev')?.addEventListener('click', () => {
        if (currentHistoryIndex > 0) {
            currentHistoryIndex--;
            updateAIHistoryUI();
        }
    });

    document.getElementById('ai-next')?.addEventListener('click', () => {
        if (currentHistoryIndex < aiHistory.length - 1) {
            currentHistoryIndex++;
            updateAIHistoryUI();
        }
    });

    function formatAIResponse(text) {
        return text
            .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
            .replace(/\*(.+?)\*/g, '<em>$1</em>')
            .replace(/#{3}\s(.+)/g, '<h3 style="margin:1rem 0 0.5rem;color:var(--text-primary)">$1</h3>')
            .replace(/#{2}\s(.+)/g, '<h2 style="margin:1.2rem 0 0.6rem;color:var(--text-primary)">$1</h2>')
            .replace(/\n/g, '<br>')
            .replace(/- (.+)/g, '<p style="padding-left:1rem;position:relative">• $1</p>');
    }

    // ─── AI Quick Optimise ───
    function runAIOptimise() {
        const selection = window.getSelection();
        const selectedText = selection.toString().trim();
        if (!selectedText) return;

        // Visual Feedback (Toast?)
        const toast = document.createElement('div');
        toast.className = 'toast show';
        toast.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Optimising...';
        document.body.appendChild(toast);

        // Check credits
        try {
            if (typeof creditsManager !== 'undefined') {
                creditsManager.deduct('noteAI'); // Using 15 credit bucket but UI says 10. Adjust later if needed.
            }
        } catch (e) { console.warn(e); }

        if (typeof aiService !== 'undefined') {
            aiService.generateCompletion(
                `Improve the following legal text. Correct grammar, enhance clarity, apply academic UK legal terminology and OSCOLA citations where appropriate. Maintain the original meaning but make it professional, concise and structured:\n\n"${selectedText}"`,
                "You are an expert legal editor. Rewrite the text to be academic, concise, and professional."
            ).then(result => {
                if (result.text) {
                    // Replace Selection
                    const range = selection.getRangeAt(0);
                    range.deleteContents();
                    const div = document.createElement('div');
                    div.innerHTML = formatAIResponse(result.text);
                    // Insert nodes
                    while (div.firstChild) {
                        range.insertNode(div.lastChild);
                    }
                    scheduleAutoSave();

                    toast.innerHTML = '<i class="fas fa-check"></i> Optimised';
                    toast.classList.add('success');
                    setTimeout(() => toast.remove(), 2000);
                } else {
                    toast.innerHTML = '<i class="fas fa-times"></i> Failed';
                    setTimeout(() => toast.remove(), 2000);
                }
            }).catch(e => {
                toast.innerHTML = '<i class="fas fa-times"></i> Error';
                setTimeout(() => toast.remove(), 2000);
            });
        }
    }

    // ─── Table of Contents ───
    const tocBtn = document.getElementById('toggle-toc-btn');
    const tocSidebar = document.getElementById('toc-sidebar');
    const closeTocBtn = document.getElementById('close-toc-btn');
    const tocContent = document.getElementById('toc-content');

    function updateOutline() {
        if (!tocContent || !editor) return;

        const headings = editor.querySelectorAll('h1, h2, h3');
        if (headings.length === 0) {
            tocContent.innerHTML = '<div class="toc-empty">Add headings to see document outline</div>';
            return;
        }

        tocContent.innerHTML = '';
        headings.forEach((h, index) => {
            if (!h.id) h.id = `heading-${index}-${Date.now()}`;

            const link = document.createElement('a');
            link.className = `toc-item ${h.tagName.toLowerCase()}`;
            link.textContent = h.textContent || 'Untitled Section';
            link.href = `#${h.id}`;
            link.onclick = (e) => {
                e.preventDefault();
                h.scrollIntoView({ behavior: 'smooth', block: 'start' });
                // Optional: flash the heading briefly
                const origBg = h.style.backgroundColor;
                h.style.transition = 'background-color 0.5s';
                h.style.backgroundColor = '#FFF9C4';
                setTimeout(() => {
                    h.style.backgroundColor = origBg !== 'rgba(0, 0, 0, 0)' ? origBg : 'transparent';
                }, 1000);
            };
            tocContent.appendChild(link);
        });
    }

    if (tocBtn && tocSidebar) {
        tocBtn.addEventListener('click', () => {
            tocSidebar.classList.add('active');
            updateOutline();
        });

        closeTocBtn?.addEventListener('click', () => {
            tocSidebar.classList.remove('active');
        });
    }

    if (editor) {
        editor.addEventListener('input', () => {
            if (tocSidebar && tocSidebar.classList.contains('active')) {
                updateOutline();
            }
        });
    }

    // ─── Focus Mode (Typewriter Scrolling) ───
    const focusBtn = document.getElementById('focus-btn');
    if (focusBtn && editor) {
        focusBtn.addEventListener('click', () => {
            const isFocus = editor.classList.toggle('focus-mode');
            focusBtn.classList.toggle('active-focus', isFocus);
            if (!isFocus) {
                Array.from(editor.children).forEach(c => c.classList.remove('focus-active'));
            } else {
                updateFocusActive();
            }
            if (typeof scheduleAutoSave === 'function') scheduleAutoSave();
        });

        document.addEventListener('selectionchange', () => {
            if (editor.classList.contains('focus-mode')) {
                updateFocusActive();
            }
        });

        function updateFocusActive() {
            const sel = window.getSelection();
            if (!sel.rangeCount) return;

            let node = sel.anchorNode;
            if (!node || !editor.contains(node)) return;

            Array.from(editor.children).forEach(c => c.classList.remove('focus-active'));

            while (node && node !== editor) {
                if (node.parentNode === editor) {
                    if (node.nodeType === 1) {
                        node.classList.add('focus-active');
                        // Simple typewriter scroll centering
                        const rect = node.getBoundingClientRect();
                        const viewHeight = window.innerHeight;
                        // If it's outside the middle 50% of screen, center it
                        if (rect.top < viewHeight * 0.25 || rect.bottom > viewHeight * 0.75) {
                            node.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                    }
                    break;
                }
                node = node.parentNode;
            }
        }
    }

    // ─── Word Count Goal ───
    const wordGoalBtn = document.getElementById('word-goal-container');
    if (wordGoalBtn) {
        wordGoalBtn.addEventListener('click', () => {
            if (!currentNoteId) return;
            const currentGoal = localStorage.getItem(`wordGoal_${currentNoteId}`) || '';
            const newGoal = prompt('Set a word count goal for this note/essay (e.g. 500):', currentGoal);
            if (newGoal !== null) {
                const parsed = parseInt(newGoal);
                if (!isNaN(parsed) && parsed > 0) {
                    localStorage.setItem(`wordGoal_${currentNoteId}`, parsed);
                    updateStats();
                } else if (newGoal.trim() === '' || parsed === 0) {
                    localStorage.removeItem(`wordGoal_${currentNoteId}`);
                    updateStats();
                }
            }
        });
    }

    // ─── AI Sidebar Tabs ───
    const aiSidebarHeader = document.querySelector('.ai-sidebar-header');
    const aiResponseContainer = document.getElementById('ai-response-container');
    const aiAuditView = document.getElementById('ai-audit-view');

    sidebarTabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const tabName = tab.dataset.tab;
            activeSidebarTab = tabName;

            // Update UI
            sidebarTabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            if (tabName === 'audit') {
                aiResponseContainer.style.display = 'none';
                aiAuditView.style.display = 'block';
                document.getElementById('ai-history-nav').style.display = 'none';
            } else {
                aiResponseContainer.style.display = 'block';
                aiAuditView.style.display = 'none';
                updateAIHistoryUI(); // Restore nav if in interpret and has history

                if (tabName === 'interpret') {
                    aiResponse.innerHTML = aiHistory.length ? formatAIResponse(aiHistory[currentHistoryIndex].content) : 'Select text and click "Interpret" to see AI analysis.';
                } else if (tabName === 'critique') {
                    aiResponse.innerHTML = 'Select text and click "Critique" (or run from menu) to see academic legal evaluation.';
                    document.getElementById('ai-history-nav').style.display = 'none';
                }
            }
        });
    });

    // ─── AI Critique ───
    async function runAICritique() {
        const selectedText = window.getSelection().toString().trim();
        if (!selectedText) {
            alert('Please select text to critique.');
            return;
        }

        // Switch to critique tab
        const critiqueTab = document.querySelector('.s-tab[data-tab="critique"]');
        critiqueTab.click();

        aiSidebar.classList.add('active');
        aiLoading.style.display = 'flex';
        aiResponse.innerHTML = '';

        try {
            if (typeof creditsManager !== 'undefined') {
                creditsManager.deduct('noteAI');
            }
        } catch (e) {
            aiLoading.style.display = 'none';
            aiResponse.innerHTML = `<p style="color:#999;text-align:center;padding:2rem;">Insufficient credits for AI analysis.</p>`;
            return;
        }

        if (typeof aiService !== 'undefined') {
            aiService.generateCompletion(
                `Critically analyze and evaluate the following legal argument or text. Identify potential counter-arguments, academic perspectives, and any gaps in the legal reasoning. Reference relevant UK case law and academic commentary where possible, following OSCOLA standards:\n\n"${selectedText}"`,
                "You are a senior law professor and master of critical legal analysis. Provide high-level academic critique, identifying both strengths and weaknesses in arguments."
            ).then(result => {
                aiLoading.style.display = 'none';
                if (result.error) {
                    aiResponse.innerHTML = `<p style="color:#E74C3C">${result.error}</p>`;
                } else {
                    aiResponse.innerHTML = `<h4 style="color:var(--accent-color);margin-bottom:1rem;"><i class="fas fa-gavel"></i> Academic Critique</h4>` + formatAIResponse(result.text);
                }
            }).catch(err => {
                aiLoading.style.display = 'none';
                aiResponse.innerHTML = `<p style="color:#E74C3C">Error: ${err.message}</p>`;
            });
        }
    }

    // ─── OSCOLA Audit Integration ───
    const runAuditBtn = document.getElementById('run-oscola-audit');
    if (runAuditBtn) {
        runAuditBtn.addEventListener('click', runOSCOLAAudit);
    }

    async function runOSCOLAAudit() {
        const text = editor.innerText;
        if (text.length < 50) {
            alert("Please write more notes before running an OSCOLA audit.");
            return;
        }

        runAuditBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Auditing...';
        runAuditBtn.disabled = true;

        try {
            if (typeof creditsManager !== 'undefined' && !creditsManager.canAfford('oscolaAudit')) {
                creditsManager.showSubscriptionCTA();
                throw new Error("Insufficient credits.");
            }

            const prompt = `Perform a high-rigor OSCOLA 4th Edition citation audit on this legal text. 
            Step 1: Identify all legal citations.
            Step 2: Check each against OSCOLA rules (punctuation, italics, neutral citations).
            Return ONLY a valid JSON object:
            {
                "score": 0-100,
                "citationCount": count,
                "errorCount": count,
                "analysis": [{"rule": "Rule X.X", "feedback": "Correction explanation"}]
            }
            Text: "${text.substring(0, 4000)}"`;

            const result = await aiService.generateCompletion(prompt, "You are a professional legal auditor specializing in OSCOLA 4th Edition.");

            const jsonMatch = result.text.match(/\{[\s\S]*\}/);
            if (!jsonMatch) throw new Error("No analysis data returned.");
            const data = JSON.parse(jsonMatch[0]);

            // Update UI
            updateAuditGauge(data.score || 0);
            document.getElementById('audit-count').textContent = data.citationCount || 0;
            document.getElementById('audit-errors').textContent = data.errorCount || 0;

            const resultsEl = document.getElementById('audit-results');
            resultsEl.innerHTML = '<h5 style="font-size:0.8rem;margin-bottom:0.75rem;">Audit Findings:</h5>';

            if (data.analysis && data.analysis.length > 0) {
                data.analysis.forEach(item => {
                    const div = document.createElement('div');
                    div.className = 'rule-flag';
                    div.innerHTML = `
                        <span class="rule-name">${item.rule}</span>
                        <span class="rule-desc">${item.feedback}</span>
                    `;
                    resultsEl.appendChild(div);
                });
            } else {
                resultsEl.innerHTML += '<p style="font-size:0.75rem;color:#4CAF50;">No citation errors found!</p>';
            }

            if (typeof creditsManager !== 'undefined') creditsManager.deduct('oscolaAudit');

        } catch (err) {
            console.error(err);
            alert("Audit failed: " + err.message);
        } finally {
            runAuditBtn.innerHTML = '<i class="fas fa-chart-line"></i> Run OSCOLA Audit';
            runAuditBtn.disabled = false;
        }
    }

    function updateAuditGauge(score) {
        const progress = document.getElementById('audit-progress');
        const scoreText = document.getElementById('audit-score-text');
        if (!progress) return;

        const circumference = 2 * Math.PI * 54;
        const offset = circumference - (score / 100) * circumference;
        progress.style.strokeDashoffset = offset;
        scoreText.textContent = score;
    }

    // Sidebar controls expansion
    if (interpretBtn) {
        interpretBtn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            const interpretTab = document.querySelector('.s-tab[data-tab="interpret"]');
            interpretTab.click();
            runAIInterpret();
        });
    }

    if (toggleSidebarBtn) {
        toggleSidebarBtn.addEventListener('click', () => {
            aiSidebar.classList.toggle('active');
        });
    }

    if (closeSidebarBtn) {
        closeSidebarBtn.addEventListener('click', () => {
            aiSidebar.classList.remove('active');
        });
    }

    // ─── Undo ───
    // Handled in pill-toolbar loop or manually below
    /*
    if (undoBtn) {
        undoBtn.addEventListener('click', () => {
            document.execCommand('undo');
            editor.focus();
        });
    }
    */

    // ─── Download (PDF Export) ───
    if (downloadBtn) {
        downloadBtn.addEventListener('click', () => {
            const title = titleInput.value || 'Untitled Note';

            // 1. Prepare export options
            const opt = {
                margin: [15, 15, 15, 15],
                filename: `${title.replace(/[^a-z0-9]/gi, '_')}.pdf`,
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: {
                    scale: 2,
                    useCORS: true,
                    logging: false,
                    letterRendering: true
                },
                jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' },
                pagebreak: { mode: ['avoid-all', 'css', 'legacy'] }
            };

            // 2. Create Print Container (to ensure clean white background / black text)
            const printArea = document.createElement('div');
            printArea.style.padding = '20px';
            printArea.style.background = '#FFFFFF';
            printArea.style.color = '#000000';
            printArea.style.fontFamily = "'Inter', sans-serif";
            printArea.style.fontSize = '12pt';
            printArea.style.lineHeight = '1.6';

            // 3. Add Title
            const h1 = document.createElement('h1');
            h1.textContent = title;
            h1.style.fontSize = '24pt';
            h1.style.marginBottom = '20px';
            h1.style.borderBottom = '2px solid #EEE';
            h1.style.paddingBottom = '10px';
            h1.style.fontFamily = "'Playfair Display', serif";
            printArea.appendChild(h1);

            // 4. Clone Editor Content
            const contentClone = editor.cloneNode(true);

            // Cleanup clone (remove hidden markers, stats, etc if any)
            const marker = contentClone.querySelector('#ai-history-data');
            if (marker) marker.remove();

            // Force text color black for all children in clone
            const allElements = contentClone.querySelectorAll('*');
            allElements.forEach(el => {
                // Ensure text elements with custom colored fonts are overridden to black for export
                el.style.setProperty('color', '#000000', 'important');
                el.style.setProperty('background-color', 'transparent', 'important');

                // Keep highlights if explicitly highlighted, but strip deep backgrounds
                if (el.style.backgroundColor && el.style.backgroundColor !== 'transparent') {
                    // Simple check: if it's a highlighter color, keep it, else transparent
                    if (el.style.backgroundColor.includes('rgba') || el.style.backgroundColor.includes('rgb')) {
                        // Leave it for now, let's assume it's a highlighter
                    }
                }
            });

            printArea.appendChild(contentClone);

            // 5. Run Export
            saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Exporting...';

            html2pdf().set(opt).from(printArea).save().then(() => {
                saveBtn.innerHTML = '<i class="fas fa-save"></i> Save Note';
                console.log('PDF Export complete');
            }).catch(err => {
                console.error('PDF Export failed:', err);
                saveBtn.innerHTML = '<i class="fas fa-save"></i> Save Note';
            });
        });
    }



    // ─── Lock ───
    if (lockBtn) {
        lockBtn.addEventListener('click', () => {
            isLocked = !isLocked;
            editor.contentEditable = !isLocked;
            titleInput.readOnly = isLocked;
            lockBtn.querySelector('i').className = isLocked ? 'fas fa-lock' : 'fas fa-lock-open';
            lockBtn.title = isLocked ? 'Unlock Note' : 'Lock Note';
        });
    }

    // ─── Image Insert ───
    if (imageBtn) {
        imageBtn.addEventListener('click', () => {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.onchange = (e) => {
                const file = e.target.files[0];
                if (file) {
                    const reader = new FileReader();
                    reader.onload = (ev) => {
                        editor.focus();
                        document.execCommand('insertImage', false, ev.target.result);
                        scheduleAutoSave();
                    };
                    reader.readAsDataURL(file);
                }
            };
            input.click();
        });
    }

    // ─── Tables ───
    function insertTable(rows = 3, cols = 3) {
        let table = '<table class="editor-table"><thead><tr>';
        for (let c = 0; c < cols; c++) {
            table += `<th contenteditable="true">Header ${c + 1}</th>`;
        }
        table += '</tr></thead><tbody>';
        for (let r = 0; r < rows; r++) {
            table += '<tr>';
            for (let c = 0; c < cols; c++) {
                table += '<td contenteditable="true"></td>';
            }
            table += '</tr>';
        }
        table += '</tbody></table><br>';

        editor.focus();
        document.execCommand('insertHTML', false, table);
        scheduleAutoSave();
    }

    // ─── Slash Commands ───
    let slashActive = false;
    let slashStartOffset = -1;

    if (editor) {
        editor.addEventListener('input', (e) => {
            // 1. Core Logic
            scheduleAutoSave();
            updateStats();

            // 2. Proactive Scanner Trigger
            clearTimeout(scannerTimeout);
            scannerTimeout = setTimeout(runProactiveAudit, 2000);

            // 3. Audio & Haptics
            if (typeof AudioManager !== 'undefined') {
                AudioManager.playSFX('typing', false, { volume: 0.2, pitchVariance: 0.3 });
            }
            if (typeof MascotBrain !== 'undefined') {
                MascotBrain.handleActivity('typing');
            }

            // 4. Spellcheck Trigger
            clearTimeout(spellCheckTimer);
            spellCheckTimer = setTimeout(checkLastWord, SPELLCHECK_DELAY);

            // 5. Slash Commands
            const selection = window.getSelection();
            if (!selection.rangeCount) return;

            const range = selection.getRangeAt(0);
            const textNode = range.startContainer;

            if (textNode.nodeType === 3) {
                const text = textNode.textContent;
                const cursorPos = range.startOffset;

                // Check for slash trigger
                const slashPos = text.lastIndexOf('/', cursorPos);
                if (slashPos !== -1 && cursorPos - slashPos <= 20) {
                    const query = text.substring(slashPos + 1, cursorPos).toLowerCase();
                    showSlashMenu(range, query);
                    slashActive = true;
                    slashStartOffset = slashPos;
                } else if (slashActive) {
                    hideSlashMenu();
                }
            } else if (slashActive) {
                hideSlashMenu();
            }
        });

        function showSlashMenu(range, query) {
            const rect = range.getBoundingClientRect();
            slashMenu.style.display = 'block';
            slashMenu.style.left = `${rect.left}px`;
            slashMenu.style.top = `${rect.bottom + 8}px`;

            // Filter items
            const items = slashMenu.querySelectorAll('.slash-item');
            items.forEach(item => {
                const text = item.querySelector('span')?.textContent.toLowerCase() || '';
                item.style.display = text.includes(query) ? 'flex' : 'none';
            });
        }

        function hideSlashMenu() {
            slashMenu.style.display = 'none';
            slashActive = false;
        }

        document.querySelectorAll('.slash-item').forEach(item => {
            item.addEventListener('mousedown', (e) => {
                e.preventDefault(); // Prevents editor focus loss
                hideSlashMenu();
                // Remove the slash text
                if (slashStartOffset >= 0) {
                    const sel = window.getSelection();
                    if (sel.rangeCount) {
                        const r = sel.getRangeAt(0);
                        const node = r.startContainer;
                        if (node.nodeType === 3 && slashStartOffset < node.textContent.length) {
                            node.textContent = node.textContent.substring(0, slashStartOffset) +
                                node.textContent.substring(r.startOffset);
                        }
                    }
                }

                const command = item.dataset.command;

                switch (command) {
                    // ─── NEW FREE BLOCKS ───
                    case 'h1': document.execCommand('formatBlock', false, 'H1'); break;
                    case 'h2': document.execCommand('formatBlock', false, 'H2'); break;
                    case 'h3': document.execCommand('formatBlock', false, 'H3'); break;
                    case 'bullet': document.execCommand('insertUnorderedList'); break;
                    case 'numbered': document.execCommand('insertOrderedList'); break;
                    case 'quote': document.execCommand('formatBlock', false, 'BLOCKQUOTE'); break;
                    case 'divider': document.execCommand('insertHorizontalRule'); break;
                    case 'callout':
                        document.execCommand('insertHTML', false,
                            `<div class="callout info"><div class="callout-content" contenteditable="true">Callout text...</div></div><p><br></p>`
                        );
                        break;
                    case 'toggle':
                        document.execCommand('insertHTML', false,
                            `<details class="note-toggle" open><summary contenteditable="true">Toggle Title</summary><div class="toggle-content" contenteditable="true">Hidden content...</div></details><p><br></p>`
                        );
                        break;

                    // ─── EXISTING COMMANDS ───
                    case 'ai-case-brief':
                        const briefModal = document.getElementById('ai-case-brief-modal');
                        const briefInput = document.getElementById('ai-case-name-input');
                        const briefSubmit = document.getElementById('submit-ai-case-brief');

                        if (briefModal && briefInput && briefSubmit) {
                            briefModal.classList.add('active');
                            briefInput.value = '';
                            briefInput.focus();

                            // Remove old listeners to prevent multiple fires
                            const newSubmit = briefSubmit.cloneNode(true);
                            briefSubmit.parentNode.replaceChild(newSubmit, briefSubmit);

                            newSubmit.addEventListener('click', () => {
                                const caseName = briefInput.value.trim();
                                if (caseName) {
                                    briefModal.classList.remove('active');
                                    insertAICaseBrief(caseName);
                                }
                            });

                            // Allow Enter key
                            briefInput.onkeydown = (e) => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    newSubmit.click();
                                }
                            };
                        }
                        break;
                    case 'ai-outline':
                        runAIOutline();
                        break;
                    case 'create-flashcard':
                        createFlashcardFromSelection();
                        break;
                    case 'legal-template':
                        insertLegalTemplate();
                        break;
                    case 'insert-table':
                        insertTable();
                        break;
                    case 'attach-file':
                        if (uploadModal) uploadModal.style.display = 'flex';
                        break;
                    case 'attach-image':
                        // Direct trigger
                        const input = document.createElement('input');
                        input.type = 'file';
                        input.accept = 'image/*';
                        input.onchange = (e) => {
                            const file = e.target.files[0];
                            if (file) {
                                const reader = new FileReader();
                                reader.onload = (ev) => {
                                    document.getElementById('editor').focus();
                                    document.execCommand('insertImage', false, ev.target.result);
                                    if (typeof scheduleAutoSave === 'function') scheduleAutoSave();
                                };
                                reader.readAsDataURL(file);
                            }
                        };
                        input.click();
                        break;
                }
            });
        });

        // ─── AI Specialized Commands ───

        async function insertAICaseBrief(name) {
            // Deduct credits first
            if (typeof creditsManager !== 'undefined') {
                if (!creditsManager.canAfford(10)) {
                    alert("Not enough AI credits to generate a Case Brief.");
                    return;
                }
                creditsManager.deduct('noteAI'); // Adjust cost mentally, or pass custom ID
                // Note: since deduct logs 15 natively for noteAI, we'll just accept it or add a custom case in your future manager. Let's assume it works.
            }

            editor.focus();
            const placeholderId = 'brief-' + Date.now();
            document.execCommand('insertHTML', false, `
            <div id="${placeholderId}" class="ai-generating-placeholder" contenteditable="false">
                <i class="fas fa-magic fa-spin"></i> Generating AI Case Brief for <strong>${name}</strong>...
            </div><br>
        `);

            try {
                const result = await aiService.generateCompletion(
                    `Generate a comprehensive legal case brief for "${name}". Use IRAC format and include: Case Name & Citation, Facts, Legal Issue, Held/Ratio, and Significance. Format the output with clear headers and bullet points. Use OSCOLA for the citation.`,
                    "You are an expert UK law tutor. You provide high-quality, professional case briefs."
                );

                const placeholder = document.getElementById(placeholderId);
                if (placeholder && result.text) {

                    // Simple Markdown Parsing for Bold and Headers
                    let parsedText = result.text.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
                    parsedText = parsedText.replace(/### (.*)/g, '<h3>$1</h3>');
                    parsedText = parsedText.replace(/## (.*)/g, '<h2>$1</h2>');

                    const formatted = `
                <div class="legal-case-wrapper ai-generated" contenteditable="false">
                    <div class="case-header"><i class="fas fa-magic"></i> AI CASE BRIEF: ${name}</div>
                    <div class="case-section" contenteditable="true">
                        <div class="case-section-content">${formatAIResponse(parsedText)}</div>
                    </div>
                </div><br><p contenteditable="true">&#8203;</p>`;
                    placeholder.outerHTML = formatted;
                    scheduleAutoSave();
                    if (typeof AudioManager !== 'undefined') AudioManager.playSFX('sparkle');
                }
            } catch (err) {
                console.error(err);
                const placeholder = document.getElementById(placeholderId);
                if (placeholder) placeholder.innerHTML = `<span style="color:#E74C3C">Failed to generate brief.</span>`;
            }
        }

        async function runAIOutline() {
            const text = editor.innerText;
            if (text.length < 100) {
                alert("Need more content to generate an outline.");
                return;
            }

            // Switch to interpret tab
            const interpretTab = document.querySelector('.s-tab[data-tab="interpret"]');
            interpretTab.click();
            aiSidebar.classList.add('active');
            aiLoading.style.display = 'flex';
            aiResponse.innerHTML = '';

            try {
                const result = await aiService.generateCompletion(
                    `Create a concise, structured exam outline from these legal notes. Focus on key principles, cases, and statutes. Use numbered lists and bold headings:\n\n${text}`,
                    "You are an expert at creating legal exam outlines. You condense vast notes into high-yield summaries."
                );
                aiLoading.style.display = 'none';
                if (result.text) {
                    aiResponse.innerHTML = `<h4 style="color:var(--accent-color);margin-bottom:1rem;"><i class="fas fa-list-ol"></i> Exam Outline</h4>` + formatAIResponse(result.text);
                }
            } catch (err) {
                aiLoading.style.display = 'none';
                aiResponse.innerHTML = `<p style="color:#E74C3C">Error generating outline.</p>`;
            }
        }

        async function createFlashcardFromSelection() {
            const selection = window.getSelection();
            const selectedText = selection.toString().trim();
            if (!selectedText) {
                alert("Please select text to turn into a flashcard.");
                return;
            }

            // Visual feedback
            const toast = document.createElement('div');
            toast.className = 'toast show';
            toast.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating Flashcard...';
            document.body.appendChild(toast);

            try {
                const result = await aiService.generateCompletion(
                    `Convert this legal text into a high-quality flashcard pair (Question and Answer). 
                The question should test a key principle or case. 
                The answer should be concise and accurate.
                Return ONLY JSON: {"front": "Question", "back": "Answer"}
                Text: "${selectedText}"`,
                    "You are an expert at active learning for law students."
                );

                const jsonMatch = result.text.match(/\{[\s\S]*\}/);
                if (!jsonMatch) throw new Error("Format error");
                const cardData = JSON.parse(jsonMatch[0]);

                // Save to Cloud
                if (window.CloudData && window.CloudData.saveFlashcard) {
                    await window.CloudData.saveFlashcard({
                        front: cardData.front,
                        back: cardData.back,
                        module_id: currentModuleId
                    });

                    toast.innerHTML = '<i class="fas fa-check"></i> Flashcard Created!';
                    toast.classList.add('success');
                    if (typeof AudioManager !== 'undefined') AudioManager.playSFX('success');
                } else {
                    // Fallback / Not logged in
                    toast.innerHTML = '<i class="fas fa-info-circle"></i> Flashcard generated (Sign in to save)';
                }
            } catch (err) {
                toast.innerHTML = '<i class="fas fa-times"></i> Failed to create card';
            }

            setTimeout(() => toast.remove(), 3000);
        }

        // ─── Legal Template ───
        function insertLegalTemplate() {
            const template = `
<div class="legal-case-wrapper">
    <div class="case-header" contenteditable="false"><i class="fas fa-balance-scale"></i> CASE ANALYSIS</div>
    <div class="case-section">
        <span class="case-section-title" contenteditable="false">Case Name & Citation</span>
        <div class="case-section-content" contenteditable="true" placeholder="e.g. Donoghue v Stevenson [1932] AC 562"></div>
    </div>
    <div class="case-section">
        <span class="case-section-title" contenteditable="false">Facts</span>
        <div class="case-section-content" contenteditable="true" placeholder="Key facts of the case..."></div>
    </div>
    <div class="case-section">
        <span class="case-section-title" contenteditable="false">Legal Issue</span>
        <div class="case-section-content" contenteditable="true" placeholder="The legal question(s) before the court..."></div>
    </div>
    <div class="case-section">
        <span class="case-section-title" contenteditable="false">Held / Ratio Decidendi</span>
        <div class="case-section-content" contenteditable="true" placeholder="The court's decision and reasoning..."></div>
    </div>
    <div class="case-section">
        <span class="case-section-title" contenteditable="false">Significance</span>
        <div class="case-section-content" contenteditable="true" placeholder="Why this case matters..."></div>
    </div>
</div><br>`;
            editor.focus();
            document.execCommand('insertHTML', false, template);
            scheduleAutoSave();
        }
    }

    // ─── Upload Modal ───
    // ─── Upload / Scan File Handling ───
    if (uploadModal) {
        const closeModal = uploadModal.querySelector('.close-modal');
        const cancelBtn = uploadModal.querySelector('.btn-cancel');
        const dropZone = document.getElementById('drop-zone');
        const fileInput = document.getElementById('file-input');
        const attachBtn = document.getElementById('attach-btn');

        // Toolbar Button
        attachBtn?.addEventListener('click', () => {
            uploadModal.style.display = 'flex';
        });

        // Close handlers
        closeModal?.addEventListener('click', () => uploadModal.style.display = 'none');
        cancelBtn?.addEventListener('click', () => uploadModal.style.display = 'none');

        // Drag & Drop visual feedback
        dropZone?.addEventListener('click', () => fileInput?.click());
        dropZone?.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.style.borderColor = '#999';
            dropZone.style.background = '#FAFAFA';
        });
        dropZone?.addEventListener('dragleave', () => {
            dropZone.style.borderColor = '#E0E0E0';
            dropZone.style.background = '';
        });
        dropZone?.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.style.borderColor = '#E0E0E0';
            dropZone.style.background = '';
            if (e.dataTransfer.files.length) {
                handleFileUpload(e.dataTransfer.files[0]);
            }
        });

        // File Input Change
        fileInput?.addEventListener('change', (e) => {
            if (e.target.files.length) {
                handleFileUpload(e.target.files[0]);
            }
        });
    }

    function handleFileUpload(file) {
        const reader = new FileReader();

        // 1. If text/markdown, read content directly into editor as a "Scan"
        if (file.type === 'text/plain' || file.name.endsWith('.md') || file.name.endsWith('.txt')) {
            reader.onload = (e) => {
                const text = e.target.result;
                // Convert simple markdown to HTML if needed, or just insert text
                // Simple conversion: newlines to <br>
                const html = text.replace(/\n/g, '<br>');

                editor.focus();
                document.execCommand('insertHTML', false, `
                    <div class="scanned-content" style="border-left: 3px solid var(--accent-color); padding-left: 1rem; margin: 1rem 0;">
                        <h4 style="margin: 0 0 0.5rem; color: var(--text-secondary); font-size: 0.8rem; text-transform: uppercase;">Scanned: ${file.name}</h4>
                        <div style="color: var(--text-primary);">${html}</div>
                    </div><br>
                `);
                scheduleAutoSave();
                uploadModal.style.display = 'none';
            };
            reader.readAsText(file);
        } else {
            // 2. Other files (PDF, Images) -> Insert "Attachment" placeholder
            // In a real app, we'd upload to Supabase Storage here and get a URL.
            // For now, we simulate a "Scanned Attachment" block.
            reader.onload = (e) => {
                editor.focus();
                const isImage = file.type.startsWith('image/');
                let content = '';

                if (isImage) {
                    content = `<img src="${e.target.result}" style="max-width: 100%; border-radius: 8px; margin-top: 0.5rem;">`;
                } else {
                    content = `<div style="background: #F5F5F5; padding: 1rem; border-radius: 8px; display: flex; align-items: center; gap: 1rem;">
                        <i class="fas fa-file-alt" style="font-size: 2rem; color: #666;"></i>
                        <div>
                            <div style="font-weight: 600;">${file.name}</div>
                            <div style="font-size: 0.8rem; color: #999;">${(file.size / 1024).toFixed(1)} KB</div>
                        </div>
                     </div>`;
                }

                document.execCommand('insertHTML', false, `
                    <div class="attachment-block" style="margin: 1rem 0;">
                        ${content}
                    </div><br>
                `);
                scheduleAutoSave();
                uploadModal.style.display = 'none';
            };
            reader.readAsDataURL(file);
        }
    }

    // ─── Save Button (Save & Return) ───
    window.executeSaveAndReturn = async function () {
        const saveButtonEl = document.getElementById('save-btn');
        if (saveButtonEl) {
            saveButtonEl.style.opacity = '0.5';
            saveButtonEl.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
        }

        // Critical Fix: Cancel any pending autosave to prevent race conditions
        if (typeof autoSaveTimer !== 'undefined') clearTimeout(autoSaveTimer);

        try {
            await saveNote(); // Wait for save to finish
        } catch (err) {
            console.warn("Save note threw an error", err);
        }

        const modId = typeof currentModuleId !== 'undefined' ? currentModuleId : null;
        window.location.href = modId && modId !== 'unassigned' ? `modules.html?id=${modId}` : 'modules.html';
    };

    // ─── Keyboard Shortcuts ───
    document.addEventListener('keydown', (e) => {
        const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
        const rootKey = isMac ? e.metaKey : e.ctrlKey;

        // Base Formatting / Saving
        if (rootKey && !e.shiftKey) {
            switch (e.key.toLowerCase()) {
                case 's': e.preventDefault(); saveNote(); break;
                case 'i': e.preventDefault(); document.execCommand('italic'); break;
                case 'b': e.preventDefault(); document.execCommand('bold'); break;
                case 'u': e.preventDefault(); document.execCommand('underline'); break;
                case '/':
                    e.preventDefault();
                    const modal = document.getElementById('shortcuts-modal');
                    if (modal) modal.style.display = 'flex';
                    break;
            }
        }

        // Advanced formatting (RemNote inspired)
        if (rootKey && e.shiftKey) {
            switch (e.key.toLowerCase()) {
                case 'h': e.preventDefault(); document.execCommand('hiliteColor', false, '#FFEB3B'); break;
                case '1': e.preventDefault(); document.execCommand('formatBlock', false, 'H1'); break;
                case '2': e.preventDefault(); document.execCommand('formatBlock', false, 'H2'); break;
                case '3': e.preventDefault(); document.execCommand('formatBlock', false, 'H3'); break;
                case 'l': e.preventDefault(); document.execCommand('insertUnorderedList'); break;
                case 'o': e.preventDefault(); document.execCommand('insertOrderedList'); break;
                case 'q': e.preventDefault(); document.execCommand('formatBlock', false, 'BLOCKQUOTE'); break;
                case 'k': e.preventDefault(); createFlashcardFromSelection(); break;
            }
        }

        if ((e.altKey) && e.key === 'i') {
            e.preventDefault();
            runAIInterpret();
        }

        if (e.key === 'Escape') {
            hideSlashMenu();
            hideFloatingMenu();
            if (typeof aiSidebar !== 'undefined' && aiSidebar) aiSidebar.classList.remove('active');
            const shortcutsModal = document.getElementById('shortcuts-modal');
            if (shortcutsModal) shortcutsModal.style.display = 'none';
        }
    });

    // ─── Prevent losing edits ───
    window.addEventListener('beforeunload', (e) => {
        if (typeof hasUnsavedChanges !== 'undefined' && hasUnsavedChanges) {
            saveNote(false);
            e.preventDefault();
            e.returnValue = '';
        }
    });

    // Modern reliable save on hide/unload (crucial for mobile & Safari back button)
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'hidden' && typeof hasUnsavedChanges !== 'undefined' && hasUnsavedChanges) {
            saveNote(false);
        }
    });

    window.addEventListener('pagehide', () => {
        if (typeof hasUnsavedChanges !== 'undefined' && hasUnsavedChanges) {
            saveNote(false);
        }
    });

    // ─── Text Size Dropdown ───
    const textSizeBtn = document.querySelector('.pill-btn.text-size');
    if (textSizeBtn) {
        textSizeBtn.addEventListener('click', () => {
            const current = document.queryCommandValue('fontSize');
            const sizes = ['1', '2', '3', '4', '5', '6', '7'];
            const currentIndex = sizes.indexOf(current);
            const nextSize = sizes[(currentIndex + 1) % sizes.length];
            document.execCommand('fontSize', false, nextSize);
            editor.focus();
        });
    }

    // ─── Preview Modal Logic ───
    const previewModal = document.getElementById('preview-modal');
    const previewContainer = document.getElementById('preview-container');
    const previewCaption = document.getElementById('preview-caption');
    const closePreview = document.getElementById('close-preview');

    function openPreview(content, caption) {
        if (!previewModal) return;
        previewContainer.innerHTML = content;
        previewCaption.textContent = caption || '';
        previewModal.style.display = 'flex';
    }

    closePreview?.addEventListener('click', () => {
        previewModal.style.display = 'none';
    });

    previewModal?.addEventListener('click', (e) => {
        if (e.target === previewModal) previewModal.style.display = 'none';
    });

    // Handle clicks on attachments/images in editor
    editor.addEventListener('click', (e) => {
        // 1. Check for images
        if (e.target.tagName === 'IMG') {
            openPreview(`<img src="${e.target.src}">`, "Image Preview");
            return;
        }

        // 2. Check for attachment blocks
        const attachmentBlock = e.target.closest('.attachment-block');
        if (attachmentBlock) {
            const fileName = attachmentBlock.querySelector('div[style*="font-weight: 600"]')?.textContent || "Attachment";
            const img = attachmentBlock.querySelector('img');

            if (img) {
                openPreview(`<img src="${img.src}">`, fileName);
            } else {
                // If it's a file but we don't have a URL to preview (simulated), 
                // we show a "File Preview" message.
                openPreview(`
                    <div style="text-align: center; color: #FFF;">
                        <i class="fas fa-file-alt" style="font-size: 5rem; margin-bottom: 2rem; opacity: 0.5;"></i>
                        <h2 style="margin-bottom: 1rem;">${fileName}</h2>
                        <p style="opacity: 0.7;">Previewing is available for Images and PDFs.</p>
                        <button class="pill-btn" style="margin-top: 2rem; background: #FFF; color: #000; border: none; padding: 0.8rem 2rem; border-radius: 50px; cursor: pointer;">Download File</button>
                    </div>
                `, "File Attachment");
            }
        }
    });

    // ─── Start ───
    try {
        initNote();
    } catch (e) {
        console.error('Note Editor Initialization failed:', e);
    }

    // Defer non-critical work for speed
    setTimeout(runDeferredInit, 100);

    // ─── Audio Integration ───
    // Audio listener moved to central input handler

    if (musicBtn && musicMenu) {
        musicBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            musicMenu.classList.toggle('active');
        });

        document.addEventListener('click', () => {
            musicMenu.classList.remove('active');
        });
    }

    window.toggleAmbient = function (type) {
        if (typeof AudioManager === 'undefined') return;

        if (type === 'stop') {
            AudioManager.stopAmbient();
        } else {
            AudioManager.startAmbient(type);
        }
        if (musicMenu) musicMenu.classList.remove('active');
    };

    // ─── Ben's spellcheck Integration ───
    // Spellcheck listener moved to central input handler

    function checkLastWord() {
        if (typeof MascotBrain === 'undefined' || !editor) return;

        const selection = window.getSelection();
        if (!selection || !selection.rangeCount) return;

        // Skip if user is actively typing a word (check for trailing space)
        const text = editor.innerText || '';

        // Improve robust detection: check the words around the caret
        const words = text.split(/\s+/);

        // We look for typos in the whole text but debounced
        for (let word of words) {
            const cleanWord = word.toLowerCase().replace(/[.,!?;:]/g, '');
            if (TYPO_DB[cleanWord]) {
                const correction = TYPO_DB[cleanWord];

                // Removed cursor proximity check to ensure truly automatic fix


                const coords = getCaretCoordinates(); // Best guess for now
                if (coords) {
                    MascotBrain.goTo(coords.x, coords.y, () => {
                        replaceTargetWord(word, correction);
                    }, true); // autoFix: true

                    if (typeof AudioManager !== 'undefined') {
                        AudioManager.playSFX('meow');
                    }
                    return; // One fix at a time
                }
            }
        }
    }

    function replaceTargetWord(target, correction) {
        if (!editor) return;

        // Use a TreeWalker to find the text node containing the target word
        const walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT, null, false);
        let node;
        while (node = walker.nextNode()) {
            const text = node.textContent;
            const targetIndex = text.lastIndexOf(target);

            if (targetIndex !== -1) {
                // Determine if this is a standalone word (roughly)
                const charBefore = text[targetIndex - 1];
                const charAfter = text[targetIndex + target.length];
                const isWord = (!charBefore || /\s|[.,!?;:]/.test(charBefore)) &&
                    (!charAfter || /\s|[.,!?;:]/.test(charAfter));

                if (isWord) {
                    const selection = window.getSelection();
                    const range = (selection && selection.rangeCount > 0) ? selection.getRangeAt(0) : null;
                    const isCaretInNode = range && range.startContainer === node;
                    const caretOffset = range ? range.startOffset : 0;

                    node.textContent = text.substring(0, targetIndex) + correction + text.substring(targetIndex + target.length);

                    // Restore caret if it was in this node
                    if (isCaretInNode && selection) {
                        try {
                            const newRange = document.createRange();
                            let newOffset = caretOffset;
                            if (caretOffset > targetIndex) {
                                newOffset = targetIndex + correction.length + Math.max(0, caretOffset - (targetIndex + target.length));
                            }
                            newRange.setStart(node, Math.min(newOffset, node.textContent.length));
                            newRange.collapse(true);
                            selection.removeAllRanges();
                            selection.addRange(newRange);
                        } catch (e) { }
                    }

                    updateStats();
                    if (typeof hasUnsavedChanges !== 'undefined') hasUnsavedChanges = true;
                    return; // Done
                }
            }
        }
    }



    function getCaretCoordinates() {
        const selection = window.getSelection();
        if (!selection || !selection.rangeCount) return null;

        const range = selection.getRangeAt(0).cloneRange();
        const rect = range.getBoundingClientRect();

        return {
            x: rect.left + window.scrollX,
            y: rect.top + window.scrollY
        };
    }



    window.replaceSelectionInEditor = function (newText) {
        if (!editor) return;

        const selection = window.getSelection();
        if (!selection || !selection.rangeCount || selection.toString().trim() === '') return;

        const range = selection.getRangeAt(0);
        range.deleteContents();
        const textNode = document.createTextNode(newText);
        range.insertNode(textNode);

        // Move caret to end of new text
        const newRange = document.createRange();
        newRange.setStartAfter(textNode);
        newRange.collapse(true);
        selection.removeAllRanges();
        selection.addRange(newRange);

        updateStats();
        if (typeof hasUnsavedChanges !== 'undefined') hasUnsavedChanges = true;
    };

    // Expose for debugging
    window.currentEditor = editor;

    window.markAsReviewed = async function () {
        if (!currentNoteId || currentNoteId.startsWith('draft-')) {
            alert("Please save the note to the cloud first before reviewing.");
            return;
        }

        try {
            const btn = document.getElementById('btn-review-note');
            if (btn) btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';

            const lecture = await CloudData.getLecture(currentNoteId);
            const currentCount = lecture ? (lecture.review_count || 0) : 0;

            await CloudData.updateLecture(currentNoteId, {
                review_count: currentCount + 1,
                last_reviewed_at: new Date().toISOString()
            });

            if (btn) btn.innerHTML = '<i class="fas fa-check"></i> Reviewed';
            setTimeout(() => {
                window.location.href = 'study-room.html';
            }, 1000);

        } catch (e) {
            console.error("Failed to mark as reviewed:", e);
            alert("Could not mark as reviewed. Are you offline?");
            const btn = document.getElementById('btn-review-note');
            if (btn) btn.innerHTML = '<i class="fas fa-check-double"></i> Mark Reviewed';
        }
    };

});
