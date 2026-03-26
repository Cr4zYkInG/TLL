/**
 * Modules Page Logic
 * Renders lecture cards, action menus, and handles navigation.
 */

let arrangeMode = false;

function toggleArrangeMode() {
    arrangeMode = !arrangeMode;
    const btn = document.getElementById('arrange-mode-btn');
    const grids = document.querySelectorAll('.content-grid');

    if (arrangeMode) {
        btn.classList.add('btn-primary');
        btn.innerHTML = '<i class="fas fa-check"></i> <span>Done Arranging</span>';
        grids.forEach(g => g.classList.add('arrange-mode'));
        if (typeof MascotBrain !== 'undefined') {
            MascotBrain.speak("Arrange mode active! Drag the handles to reorder your ${typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('modulePlural').toLowerCase() : 'modules'} and lectures. 🏗️");
        }
    } else {
        btn.classList.remove('btn-primary');
        btn.innerHTML = '<i class="fas fa-arrows-alt"></i> <span>Arrange Mode</span>';
        grids.forEach(g => g.classList.remove('arrange-mode'));
        showModuleToast('Order saved! ✨');
    }
}

window.toggleArrangeMode = toggleArrangeMode;

// Tab Switching Logic
function switchModuleTab(tabName) {
    // Update Tabs
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.textContent.toLowerCase().replace(' ', '-') === tabName ||
            (btn.textContent === 'Lectures' && tabName === 'lectures') ||
            (btn.textContent === 'Study Room' && tabName === 'study-room') ||
            (btn.textContent === 'Sources' && tabName === 'sources') ||
            (btn.textContent === 'Settings' && tabName === 'settings')) {
            btn.classList.add('active');
        }
    });

    // Update Content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.style.display = 'none';
        content.classList.remove('active');
    });

    const target = document.getElementById(`tab-${tabName}`);
    if (target) {
        target.style.display = 'block';
        setTimeout(() => target.classList.add('active'), 10);

        // Populate settings if switching to that tab
        if (tabName === 'settings' && typeof window.currentModuleData !== 'undefined') {
            populateModuleSettings(window.currentModuleData);
        }
    }
}

// Global scope for HTML access
window.switchModuleTab = switchModuleTab;

// Handle browser back button cache (BFCache)
window.addEventListener('pageshow', (e) => {
    if (e.persisted) {
        window.location.reload();
    }
});

document.addEventListener('DOMContentLoaded', async () => {
    // 1. Auth Guard (Redirect if not logged in)
    if (typeof requireAuth === 'function') {
        const session = await requireAuth();
        if (!session) return; // Redirect handled by requireAuth
    } else {
        // Fallback for immediate protection if Supabase not ready
        if (!localStorage.getItem('userName')) {
            window.location.href = 'login.html';
            return;
        }
    }

    // ... existing initialization ...


    // Parse Module ID from URL (Query or Hash)
    const urlParams = new URLSearchParams(window.location.search);
    let moduleId = urlParams.get('id');
    const ownerId = urlParams.get('owner');
    const sharedName = urlParams.get('name');

    // Fallback: Check hash if query param is missing (e.g. server redirect stripped it)
    if (!moduleId && window.location.hash) {
        moduleId = window.location.hash.substring(1); // remove #
    }

    // --- SHARED MODULE DETECTION ---
    if (moduleId && ownerId && sharedName) {
        handleSharedModuleInvitation(moduleId, ownerId, sharedName);
    }

    if (!moduleId) {
        // RENDER ALL MODULES LIST VIEW
        console.log('No Module ID. Rendering All Modules List.');
        renderModuleList();

        // Listen for hash changes to navigate between modules
        window.addEventListener('hashchange', () => {
            window.location.reload();
        }, { once: true });

        // We still need the global click listener for the action menus!
        _attachActionMenuListener();

        return;
    }

    // Load modules data (built-in + custom) and deadlines
    let customModules = [];
    window.allDeadlines = [];
    if (typeof CloudData !== 'undefined') {
        try {
            const [modules, deadlines] = await Promise.all([
                CloudData.getModules(),
                CloudData.getDeadlines()
            ]);
            customModules = modules;
            window.allDeadlines = deadlines;
            localStorage.setItem('customModules', JSON.stringify(customModules));
        } catch (e) {
            console.warn('Failed to fetch cloud data on init:', e);
            customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        }
    } else {
        customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    }

    console.log('Loading Module ID:', moduleId);

    let currentModule;
    if (builtInModules[moduleId]) {
        currentModule = builtInModules[moduleId];

        // 1. Load local notes first (Offline support & Immediate render)
        const savedNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
        console.log('Loaded savedNotes from LS:', savedNotes.length, savedNotes);
        const localLectures = savedNotes.filter(n => n.module === moduleId).map(n => ({
            id: n.id,
            title: n.title,
            time: getRelativeTime(n.created),
            created: n.created,
            modified: n.created_at || n.created,
            source: 'local'
        }));
        console.log('Filtered localLectures for', moduleId, ':', localLectures);
        currentModule.lectures = localLectures;

        // 2. Fetch from Cloud and Merge (Cloud-first)
        if (typeof CloudData !== 'undefined') {
            CloudData.getLectures(moduleId).then(lectures => {
                if (lectures.length > 0) {
                    const grid = document.getElementById('lecture-grid');

                    // Merge: Cloud notes take precedence. Keep local-only notes.
                    const cloudLectures = lectures.map(l => ({
                        id: l.id,
                        title: l.title,
                        time: getRelativeTime(l.lastModified || l.created),
                        created: l.created,
                        is_public: l.is_public,
                        source: 'cloud'
                    }));

                    // Combine arrays, preferring cloud version if ID matches
                    const merged = [...cloudLectures];
                    localLectures.forEach(local => {
                        if (!merged.find(c => c.id === local.id)) {
                            merged.push(local);
                        }
                    });

                    // Sort by most recent
                    merged.sort((a, b) => new Date(b.created) - new Date(a.created));

                    currentModule.lectures = merged;
                    if (grid) _renderLectureGrid(grid, currentModule, moduleId);
                }
            }).catch(err => console.warn('Cloud fetch failed, using local notes only', err));
        }
    } else if (customModule) {
        // Load saved lecture notes — cloud-first, fallback localStorage
        let moduleLectures = [];
        const savedNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
        moduleLectures = savedNotes.filter(n => n.module === moduleId).map(n => ({
            id: n.id,
            title: n.title,
            time: getRelativeTime(n.created),
            created: n.created,
            modified: n.created
        }));
        currentModule = { name: customModule.name, lectures: moduleLectures };

        // Async: try cloud data for this module
        if (typeof CloudData !== 'undefined') {
            CloudData.getLectures(moduleId).then(lectures => {
                if (lectures.length > 0) {
                    const cloudLectures = lectures.map(l => ({
                        id: l.id,
                        title: l.title,
                        time: getRelativeTime(l.lastModified || l.created),
                        created: l.created,
                        is_public: l.is_public,
                        source: 'cloud'
                    }));

                    // Combine arrays, preferring cloud version if ID matches
                    const merged = [...cloudLectures];
                    moduleLectures.forEach(local => {
                        if (!merged.find(c => c.id === local.id)) {
                            merged.push(local);
                        }
                    });

                    // Sort by most recent
                    merged.sort((a, b) => new Date(b.created) - new Date(a.created));

                    currentModule.lectures = merged;
                    const grid = document.getElementById('lecture-grid');
                    if (grid) _renderLectureGrid(grid, currentModule, moduleId);
                }
            }).catch(() => { });
        }
    } else {
        currentModule = { name: 'Unknown Module', lectures: [] };
    }

    // Update Breadcrumbs & Header for Detail View
    // Show: Home > My Modules > [Module Name]
    document.getElementById('breadcrumb-module-name').textContent = currentModule.name;
    document.getElementById('module-title').textContent = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('lecture') : 'Lectures';

    // Track last opened module for dashboard quick access
    window.currentModuleData = { id: moduleId, ...currentModule }; // Expose for settings
    localStorage.setItem('lastOpenedModule', JSON.stringify({
        id: moduleId,
        name: currentModule.name,
        timestamp: Date.now()
    }));

    // Render Grid (Lectures)
    const grid = document.getElementById('lecture-grid');
    if (grid) {
        grid.innerHTML = '';

        if (currentModule.lectures.length === 0) {
            // Empty state
            const emptyState = document.createElement('div');
            emptyState.style.cssText = 'grid-column: 1/-1; text-align: center; padding: 4rem; color: var(--text-secondary); border: 1px dashed var(--border-color); border-radius: 12px;';
            emptyState.innerHTML = `
                <i class="fas fa-book-open" style="font-size: 3rem; margin-bottom: 1rem; opacity: 0.5;"></i>
                <h3>No ${typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('lecture').toLowerCase() : 'lectures'} yet</h3>
                <p>Create your first note to get started.</p>
            `;
            grid.appendChild(emptyState);
        }

        currentModule.lectures.forEach(lecture => {
            const card = document.createElement('div');
            card.className = 'lecture-card';
            card.setAttribute('data-lecture-id', lecture.id);
            card.innerHTML = `
                <div class="card-badge">${typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('lectureSingular').toUpperCase() : 'LECTURE'}</div>
                <h3 class="card-title">${lecture.title}</h3>
                <div class="card-footer">
                    <span class="card-time">${lecture.time}</span>
                    <div class="card-menu-wrapper">
                        <i class="fas fa-ellipsis-h card-menu" data-id="${lecture.id}"></i>
                        <div class="lecture-action-menu" id="menu-${lecture.id}" style="display: none;">
                            <button data-action="summarise" data-id="${lecture.id}"><i class="fas fa-file-alt"></i> Summarise</button>
                            <button data-action="edit" data-id="${lecture.id}"><i class="fas fa-edit"></i> Edit</button>
                            <button data-action="publish" data-id="${lecture.id}" data-public="${lecture.is_public || false}"><i class="fas ${lecture.is_public ? 'fa-eye-slash' : 'fa-globe'}"></i> ${lecture.is_public ? 'Unpublish' : 'Publish to Community Hub'}</button>
                            <button data-action="copy-link" data-id="${lecture.id}"><i class="fas fa-link"></i> Copy Link</button>
                            <button data-action="delete" data-id="${lecture.id}" class="danger"><i class="fas fa-trash"></i> Delete</button>
                        </div>
                    </div>
                </div>
            `;

            // Click card (not menu) to view
            card.addEventListener('click', (e) => {
                // If we are in the middle of a delete confirmation, don't trigger navigation
                if (card.classList.contains('confirming-delete')) return;

                if (!e.target.closest('.card-menu-wrapper')) {
                    // Navigate to note editor with specific lecture ID and module ID
                    window.location.href = `note-editor.html?id=${lecture.id}&module=${moduleId}`;
                }
            });

            grid.appendChild(card);
        });

        // "Create Note" Card
        const addCard = document.createElement('div');
        addCard.className = 'create-card';
        // Create new note with module context
        addCard.onclick = () => window.location.href = `note-editor.html?module=${moduleId}`;
        addCard.innerHTML = `<i class="fas fa-plus"></i>`;
        grid.appendChild(addCard);
    }

    // Wire header "Create Note" button
    // Wire header "Create Note" button
    const createNoteBtn = document.getElementById('create-note-btn');
    if (createNoteBtn) {
        // Remove old listeners to prevent duplicates if re-running
        const newBtn = createNoteBtn.cloneNode(true);
        createNoteBtn.parentNode.replaceChild(newBtn, createNoteBtn);

        newBtn.addEventListener('click', () => {
            const params = new URLSearchParams(window.location.search);
            let currentId = params.get('id');

            // Fallback: Check hash if query param is missing (consistent with init logic)
            if (!currentId && window.location.hash) {
                currentId = window.location.hash.substring(1); // remove #
            }

            console.log('Create Note Clicked. Dynamic Module ID:', currentId);

            if (currentId) {
                window.location.href = `note-editor.html?module=${currentId}`;
            } else {
                window.location.href = `note-editor.html`;
            }
        });
    }

    _attachActionMenuListener();

    // --- Module Settings Listeners ---
    const btnSaveSettings = document.getElementById('btn-save-module-settings');
    if (btnSaveSettings) {
        btnSaveSettings.addEventListener('click', saveModuleSettings);
    }

    const btnShare = document.getElementById('btn-share-module');
    if (btnShare) {
        btnShare.addEventListener('click', async () => {
            const uid = await CloudData._userId();
            const name = window.currentModuleData ? window.currentModuleData.name : 'Shared Module';
            const shareUrl = `${window.location.origin}/modules.html?id=${moduleId}&owner=${uid}&name=${encodeURIComponent(name)}`;
            
            navigator.clipboard.writeText(shareUrl).then(() => {
                showModuleToast('Collaborative invite link copied! 🔗');
                if (typeof MascotBrain !== 'undefined') {
                    MascotBrain.speak("Universal invite link copied! Send this to a fellow scholar to study together. 🎓");
                }
            });
        });
    }

    const btnArchive = document.getElementById('btn-archive-module');
    if (btnArchive) {
        btnArchive.addEventListener('click', () => archiveModuleSpecific(moduleId));
    }

    const btnDelete = document.getElementById('btn-delete-module');
    if (btnDelete) {
        btnDelete.addEventListener('click', () => deleteModuleSpecific(moduleId));
    }
});

// Extracted Global Click Listener for Action Menus
let _actionMenuAttached = false;
function _attachActionMenuListener() {
    if (_actionMenuAttached) return;
    _actionMenuAttached = true;

    document.addEventListener('click', (e) => {
        const menuTrigger = e.target.closest('.card-menu');
        const actionBtn = e.target.closest('.lecture-action-menu button');

        if (menuTrigger) {
            e.stopPropagation();
            const id = menuTrigger.dataset.id;
            const menu = document.getElementById(`menu-${id}`);
            const card = menuTrigger.closest('.lecture-card');

            if (!menu) return; // Failsafe if menu doesn't exist

            // Close all other menus and remove active classes
            document.querySelectorAll('.lecture-action-menu').forEach(m => {
                if (m.id !== `menu-${id}`) {
                    m.style.display = 'none';
                    const otherCard = m.closest('.lecture-card');
                    if (otherCard) otherCard.classList.remove('menu-active');
                }
            });

            const isOpening = menu.style.display === 'none' || menu.style.display === '';
            menu.style.display = isOpening ? 'block' : 'none';
            if (card) {
                if (isOpening) card.classList.add('menu-active');
                else card.classList.remove('menu-active');
            }
        } else if (actionBtn) {
            e.stopPropagation();
            const action = actionBtn.dataset.action;
            const id = actionBtn.dataset.id;

            // Optional: retrieve moduleId if available from current url context
            const urlParams = new URLSearchParams(window.location.search);
            const moduleId = urlParams.get('id') || urlParams.get('module') || window.location.hash.substring(1) || null;

            // Remove active class when action taken
            const card = actionBtn.closest('.lecture-card');
            if (card) card.classList.remove('menu-active');

            // Close menu visually immediately
            const menu = actionBtn.closest('.lecture-action-menu');
            if (menu) menu.style.display = 'none';

            handleLectureAction(action, id, moduleId, actionBtn);
        } else {
            // Close all menus and remove active classes when clicking elsewhere
            document.querySelectorAll('.lecture-action-menu').forEach(m => {
                m.style.display = 'none';
                const card = m.closest('.lecture-card');
                if (card) card.classList.remove('menu-active');
            });
        }
    });
}

// --- LIST VIEW LOGIC ---
function renderModuleList() {
    // 1. Update Header UI for "All Modules" (list view)
    const breadcrumbName = document.getElementById('breadcrumb-module-name');
    const breadcrumbSep = document.getElementById('breadcrumb-separator');
    if (breadcrumbName) breadcrumbName.style.display = 'none';
    if (breadcrumbSep) breadcrumbSep.style.display = 'none';

    const pageTitle = typeof TerminologyManager !== 'undefined' ? `My ${TerminologyManager.getTerm('module')}` : 'My Modules';

    document.getElementById('module-title').textContent = pageTitle;
    const headerActions = document.querySelector('.header-actions');
    if (headerActions) headerActions.style.display = 'none';
    const editIcon = document.querySelector('.edit-icon');
    if (editIcon) editIcon.style.display = 'none';

    // 2. Fetch Modules — localStorage first (instant), then cloud overlay
    const localModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const grid = document.getElementById('lecture-grid');
    if (!grid) return;

    // Render from localStorage immediately
    _renderModuleGrid(grid, localModules);

    // 3. Cloud-first overlay: if CloudData is available, fetch and re-render
    if (typeof CloudData !== 'undefined') {
        CloudData.getModules().then(cloudModules => {
            // Cloud is authoritative (already filtered is_deleted=false).
            // Do NOT keep local-only modules — they may have been deleted on another platform.
            // Only fall back to local if cloud returns nothing (e.g. offline fallback already handled in CloudData).
            if (cloudModules && cloudModules.length >= 0) {
                localStorage.setItem('customModules', JSON.stringify(cloudModules));
                _renderModuleGrid(grid, cloudModules);
            }
        }).catch(() => { /* offline — localStorage rendering is already done */ });
    }
}

// Helper: render the module list grid
function _renderModuleGrid(grid, modules) {
    grid.innerHTML = '';

    const active = modules.filter(m => !m.archived);
    const archived = modules.filter(m => m.archived);

    // Render Active modules
    active.forEach(mod => {
        grid.appendChild(createModuleListCard(mod));
    });

    // "Create New Module" card
    const addCard = document.createElement('div');
    addCard.className = 'lecture-card';
    addCard.style.cssText = 'border:1px dashed var(--border-color);justify-content:center;align-items:center;cursor:pointer;color:var(--text-secondary);';
    addCard.addEventListener('click', openCreateModule);
    addCard.innerHTML = `
        <div style="font-size: 2rem; color: var(--accent-color); margin-bottom: 0.5rem;"><i class="fas fa-plus"></i></div>
        <div style="font-weight: 600;">Create New ${typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('moduleSingular') : 'Module'}</div>
    `;
    grid.appendChild(addCard);

    // Archived section
    if (archived.length > 0) {
        const separator = document.createElement('h3');
        separator.textContent = 'Archived';
        separator.style.cssText = 'grid-column:1/-1;margin-top:2rem;color:var(--text-secondary);';
        grid.appendChild(separator);

        archived.forEach(mod => {
            const card = createModuleListCard(mod);
            card.style.opacity = '0.7';
            grid.appendChild(card);
        });
    }

    // Initialize Drag and Drop for Modules
    if (typeof Sortable !== 'undefined' && active.length > 1) {
        new Sortable(grid, {
            animation: 150,
            draggable: '.lecture-card:not([onclick*="openCreateModule"])', // Correctly target module cards
            onEnd: async () => {
                const orderedIds = Array.from(grid.querySelectorAll('.lecture-card[data-module-id]'))
                    .map(el => el.dataset.moduleId);
                if (orderedIds.length > 0) {
                    await CloudData.updateOrder('module', orderedIds);
                }
            }
        });
    }
}

function createModuleListCard(mod) {
    const card = document.createElement('div');
    card.className = 'lecture-card';
    card.style.cursor = 'pointer';

    // Progress: use finalTestScore if set, otherwise calculate from lectures
    const progress = typeof mod.finalTestScore === 'number'
        ? mod.finalTestScore
        : (mod.total_lectures > 0
            ? Math.round((mod.completed_lectures / mod.total_lectures) * 100)
            : 0);

    card.innerHTML = `
        <div class="drag-handle"><i class="fas fa-grip-lines"></i></div>
        <div style="font-size: 2rem; color: var(--accent-color); margin-bottom: 1rem;">
            <i class="fas ${(typeof CloudData !== 'undefined') ? CloudData.getWebIcon(mod.icon) : (mod.icon || 'fa-book')}"></i>
        </div>
        <h3 class="card-title">${mod.name}</h3>
        <p style="color: var(--text-secondary); font-size: 0.9rem; margin-bottom: 1rem;">${mod.description || 'Custom module'}</p>
        
        <div style="margin-top: auto; width: 100%; display: flex; justify-content: space-between; align-items: flex-end;">
            <div style="flex: 1; margin-right: 1.5rem;">
                <div style="display: flex; justify-content: space-between; font-size: 0.8rem; margin-bottom: 0.5rem;">
                    <span>Progress</span>
                    <span>${progress}%</span>
                </div>
                <div style="background: rgba(255,255,255,0.1); height: 4px; border-radius: 2px;">
                    <div style="background: var(--accent-color); height: 100%; width: ${progress}%; border-radius: 2px; transition: width 0.3s;"></div>
                </div>
            </div>
            <div class="card-menu-wrapper">
                <i class="fas fa-ellipsis-h card-menu" data-id="mod-${mod.id}"></i>
                <div class="lecture-action-menu module-menu-dropdown" id="menu-mod-${mod.id}" style="display: none;">
                    <div class="module-sorting-row">
                        <button data-action="move-module" data-id="${mod.id}" data-dir="first" class="sort-btn module-menu-item" style="padding: 0.5rem; justify-content: center;" title="Move First"><i class="fas fa-angle-double-left"></i></button>
                        <button data-action="move-module" data-id="${mod.id}" data-dir="left" class="sort-btn module-menu-item" style="padding: 0.5rem; justify-content: center;" title="Move Left"><i class="fas fa-angle-left"></i></button>
                        <button data-action="move-module" data-id="${mod.id}" data-dir="right" class="sort-btn module-menu-item" style="padding: 0.5rem; justify-content: center;" title="Move Right"><i class="fas fa-angle-right"></i></button>
                        <button data-action="move-module" data-id="${mod.id}" data-dir="last" class="sort-btn module-menu-item" style="padding: 0.5rem; justify-content: center;" title="Move Last"><i class="fas fa-angle-double-right"></i></button>
                    </div>
                    <button data-action="share-module" data-id="${mod.id}" data-name="${mod.name}" class="module-menu-item"><i class="fas fa-share-alt"></i> Share</button>
                    <button data-action="edit-module" data-id="${mod.id}" class="module-menu-item"><i class="fas fa-edit"></i> Edit</button>
                    <button data-action="archive-module" data-id="${mod.id}" class="module-menu-item"><i class="fas fa-archive"></i> ${mod.archived ? 'Unarchive' : 'Archive'}</button>
                    <button data-action="delete-module" data-id="${mod.id}" class="module-menu-item delete danger"><i class="fas fa-trash"></i> Delete</button>
                </div>
            </div>
        </div>
    `;

    card.addEventListener('click', (e) => {
        if (e.target.closest('.card-menu-wrapper')) return;
        window.location.href = `modules.html?id=${mod.id}`;
    });

    card.dataset.moduleId = mod.id; // Added for sorting
    return card;
}


// Handle lecture actions
function handleLectureAction(action, lectureId, moduleId, actionBtn) {
    switch (action) {
        case 'summarise':
            // Navigate to interpret page with context
            window.location.href = `interpret.html?lecture=${lectureId}&module=${moduleId}`;
            break;

        case 'edit':
            window.location.href = `note-editor.html?id=lecture-${lectureId}&module=${moduleId}`;
            break;

        case 'copy-link':
            const link = `${window.location.origin}/note-editor?id=lecture-${lectureId}&module=${moduleId}`;
            navigator.clipboard.writeText(link).then(() => {
                showModuleToast('Link copied to clipboard!');
            });
            break;

        case 'publish':
            const isCurrentlyPublic = actionBtn.dataset.public === 'true';
            handleLecturePublish(lectureId, !isCurrentlyPublic, actionBtn);
            break;

        case 'move':
            showMoveModal(lectureId);
            break;
        case 'delete':
            showDeleteConfirm(lectureId);
            break;

        // Module-specific actions:
        case 'edit-module':
            openCreateModuleForEdit(lectureId);
            break;
        case 'archive-module':
            archiveModuleSpecific(lectureId);
            break;
        case 'delete-module':
            deleteModuleSpecific(lectureId);
            break;
        case 'move-module':
            moveModuleList(lectureId, actionBtn.dataset.dir);
            break;
        case 'share-module':
            const modName = actionBtn.dataset.name || 'Shared Module';
            handleModuleShare(lectureId, modName);
            break;
    }
}

function openCreateModuleForEdit(id) {
    const customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const module = customModules.find(m => m.id === id);
    if (!module) return;

    isEditing = true;
    editingId = id;

    const title = document.querySelector('#create-module-modal h2');
    if (title) title.textContent = 'Edit Module';

    const btn = document.querySelector('#create-module-modal .modal-btn-create');
    if (btn) btn.innerHTML = '<i class="fas fa-save"></i> Update Module';

    const modal = document.getElementById('create-module-modal');
    if (modal) {
        modal.classList.add('active');
        document.getElementById('new-module-name').value = module.name;
        const descInput = document.getElementById('new-module-description');
        if (descInput) descInput.value = module.description || '';
        document.getElementById('new-module-name').focus();

        selectedIcon = module.icon || 'fa-file-contract';
        document.querySelectorAll('.icon-option').forEach(opt => {
            if (opt.dataset.icon === selectedIcon) opt.classList.add('selected');
            else opt.classList.remove('selected');
        });
    }
}

async function moveModuleList(id, direction) {
    let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const activeModules = customModules.filter(m => !m.archived);
    const index = activeModules.findIndex(m => m.id === id);
    if (index === -1) return;

    const newOrder = [...activeModules];
    const item = newOrder.splice(index, 1)[0];

    if (direction === 'first') {
        newOrder.unshift(item);
    } else if (direction === 'last') {
        newOrder.push(item);
    } else if (direction === 'left' || direction === 'up') {
        const newIdx = Math.max(0, index - 1);
        newOrder.splice(newIdx, 0, item);
    } else if (direction === 'right' || direction === 'down') {
        const newIdx = Math.min(activeModules.length - 1, index + 1);
        newOrder.splice(newIdx, 0, item);
    }

    const archivedModules = customModules.filter(m => m.archived);
    const finalModules = [...newOrder, ...archivedModules];
    const orderedIds = newOrder.map(m => m.id);

    if (typeof CloudData !== 'undefined') {
        try { await CloudData.updateOrder('module', orderedIds); } catch (e) { }
    }

    localStorage.setItem('customModules', JSON.stringify(finalModules));
    renderModuleList();
}

async function handleLecturePublish(id, makePublic, btn) {
    if (typeof CloudData === 'undefined') return;

    try {
        btn.disabled = true;
        btn.innerHTML = `<i class="fas fa-spinner fa-spin"></i> ${makePublic ? 'Publishing...' : 'Unpublishing...'}`;

        await CloudData.makePublic(id, 'note', makePublic);

        showModuleToast(makePublic ? 'Published to Community Hub! 🌍' : 'Removed from Community Hub');

        // Update button state visually
        btn.dataset.public = makePublic;
        btn.innerHTML = `<i class="fas ${makePublic ? 'fa-eye-slash' : 'fa-globe'}"></i> ${makePublic ? 'Unpublish' : 'Publish to Community Hub'}`;

        if (typeof MascotBrain !== 'undefined' && makePublic) {
            MascotBrain.speak("Awesome! Your note is now globally visible in the Community Hub! 🌍");
        }
    } catch (e) {
        showModuleToast("Failed to update privacy: " + e.message, 'warning');
        // Restore button text
        const isPublic = btn.dataset.public === 'true';
        btn.innerHTML = `<i class="fas ${isPublic ? 'fa-eye-slash' : 'fa-globe'}"></i> ${isPublic ? 'Unpublish' : 'Publish to Community Hub'}`;
    } finally {
        btn.disabled = false;
    }
}

async function handleModuleShare(id, name) {
    const uid = await CloudData._userId();
    const shareUrl = `${window.location.origin}/modules.html?id=${id}&owner=${uid}&name=${encodeURIComponent(name)}`;
    
    navigator.clipboard.writeText(shareUrl).then(() => {
        showModuleToast('Collaborative invite link copied! 🔗');
        if (typeof MascotBrain !== 'undefined') {
            MascotBrain.speak(`Universal invite link for '${name}' copied! 🎓`);
        }
    });
}

// Delete confirmation (inline, not browser confirm)
function showDeleteConfirm(lectureId) {
    const card = document.querySelector(`[data-lecture-id="${lectureId}"]`);
    if (!card) return;

    // Replace card content with confirmation
    card.classList.add('confirming-delete');
    const originalHTML = card.innerHTML;
    card.innerHTML = `
        <div style="text-align: center; padding: 1rem;" onclick="event.stopPropagation()">
            <i class="fas fa-exclamation-triangle" style="font-size: 1.5rem; color: #ff5555; margin-bottom: 0.75rem;"></i>
            <p style="margin-bottom: 1rem; font-weight: 500;">Delete this ${typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('lectureSingular').toLowerCase() : 'lecture'}?</p>
            <div style="display: flex; gap: 0.5rem; justify-content: center;">
                <button onclick="event.stopPropagation(); cancelDelete(this, '${lectureId}')" style="padding: 0.5rem 1rem; background: transparent; border: 1px solid var(--border-color); color: var(--text-primary); border-radius: 6px; cursor: pointer;">Cancel</button>
                <button onclick="event.stopPropagation(); confirmDelete('${lectureId}')" style="padding: 0.5rem 1rem; background: #ff5555; border: none; color: white; border-radius: 6px; cursor: pointer;">Delete</button>
            </div>
        </div>
    `;
    card.dataset.originalHtml = originalHTML;
}

function cancelDelete(btn, lectureId) {
    const card = document.querySelector(`[data-lecture-id="${lectureId}"]`);
    if (card && card.dataset.originalHtml) {
        card.innerHTML = card.dataset.originalHtml;
        card.classList.remove('confirming-delete');
    }
}

async function showMoveModal(lectureId) {
    // 1. Fetch modules
    let modules = [];
    if (typeof CloudData !== 'undefined') {
        modules = await CloudData.getModules();
    } else {
        modules = JSON.parse(localStorage.getItem('customModules') || '[]');
    }

    // 2. Create Modal HTML if doesn't exist
    let modal = document.getElementById('move-lecture-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'move-lecture-modal';
        modal.className = 'modal-overlay';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 400px;">
                <div class="modal-header">
                    <h2>Move Note</h2>
                    <button class="modal-close" onclick="document.getElementById('move-lecture-modal').classList.remove('active')">&times;</button>
                </div>
                <div class="modal-body">
                    <p style="margin-bottom: 1rem; color: var(--text-secondary); font-size: 0.9rem;">Select a module to move this note to:</p>
                    <div id="module-move-list" style="display: flex; flex-direction: column; gap: 0.5rem; max-height: 300px; overflow-y: auto;">
                        <!-- Modules injected here -->
                    </div>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    }

    // 3. Populate Module List
    const list = document.getElementById('module-move-list');
    list.innerHTML = '';

    modules.forEach(mod => {
        const btn = document.createElement('button');
        btn.style.cssText = 'display: flex; align-items: center; gap: 1rem; width: 100%; padding: 0.75rem 1rem; background: var(--bg-color); border: 1px solid var(--border-color); border-radius: 8px; color: var(--text-primary); cursor: pointer; text-align: left; transition: all 0.2s ease;';
        btn.innerHTML = `<i class="fas ${(typeof CloudData !== 'undefined') ? CloudData.getWebIcon(mod.icon) : (mod.icon || 'fa-file-contract')}"></i> <span>${mod.name}</span>`;

        btn.onmouseover = () => btn.style.borderColor = 'var(--accent-color)';
        btn.onmouseout = () => btn.style.borderColor = 'var(--border-color)';

        btn.onclick = async () => {
            btn.disabled = true;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Moving...';
            try {
                if (typeof CloudData !== 'undefined') {
                    await CloudData.updateLecture(lectureId, { module_id: mod.id });
                }

                // Update Local Storage too
                let allNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
                const noteIdx = allNotes.findIndex(n => n.id === lectureId);
                if (noteIdx !== -1) {
                    allNotes[noteIdx].module_id = mod.id;
                    localStorage.setItem('savedLectureNotes', JSON.stringify(allNotes));
                }

                showModuleToast('Note moved successfully');
                modal.classList.remove('active');

                // Refresh the current view
                const urlParams = new URLSearchParams(window.location.search);
                const currentModuleId = urlParams.get('module');
                if (currentModuleId) {
                    // We are in a module view, so removing from current grid makes sense
                    const card = document.querySelector(`[data-lecture-id="${lectureId}"]`);
                    if (card) {
                        card.style.transform = 'scale(0.9)';
                        card.style.opacity = '0';
                        setTimeout(() => card.remove(), 300);
                    }
                }
            } catch (e) {
                console.error('Failed to move note:', e);
                showModuleToast('Failed to move note', 'warning');
            }
        };
        list.appendChild(btn);
    });

    modal.classList.add('active');
}

function confirmDelete(lectureId) {
    const card = document.querySelector(`[data-lecture-id="${lectureId}"]`);
    if (card) {
        card.style.transform = 'scale(0.9)';
        card.style.opacity = '0';
        card.style.transition = 'all 0.3s ease';
        setTimeout(() => card.remove(), 300);

        // Cloud-first delete
        if (typeof CloudData !== 'undefined') {
            CloudData.deleteLecture(lectureId).then(() => {
                showModuleToast('Lecture deleted from cloud');
            }).catch(err => {
                console.error('Failed to delete from cloud:', err);
                showModuleToast('Deleted locally (Sync Failed)', 'warning');
                // Optional: we could restore the card here if we wanted strict consistency
            });
        }

        // Remove from localStorage
        let allNotes = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
        allNotes = allNotes.filter(n => n.id !== lectureId);
        localStorage.setItem('savedLectureNotes', JSON.stringify(allNotes));

        // Also remove the note content itself
        localStorage.removeItem(`note-${lectureId}`);

        showModuleToast('Lecture deleted');
    }
}

// Toast notification for modules page
function showModuleToast(message, type = 'success') {
    let toast = document.getElementById('module-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'module-toast';
        toast.style.cssText = 'position: fixed; bottom: 2rem; right: 2rem; background: var(--surface-color); border: 1px solid var(--border-color); border-radius: 12px; padding: 1rem 1.5rem; display: flex; align-items: center; gap: 0.75rem; box-shadow: 0 4px 12px rgba(0,0,0,0.5); z-index: 3000; transform: translateY(100px); opacity: 0; transition: all 0.3s ease;';
        document.body.appendChild(toast);
    }
    const iconClass = type === 'warning' ? 'fa-exclamation-triangle' : 'fa-check-circle';
    const iconColor = type === 'warning' ? '#ffaa00' : '#4CAF50';

    toast.innerHTML = `<i class="fas ${iconClass}" style="color: ${iconColor};"></i> <span>${message}</span>`;
    toast.style.transform = 'translateY(0)';
    toast.style.opacity = '1';
    setTimeout(() => {
        toast.style.transform = 'translateY(100px)';
        toast.style.opacity = '0';
    }, 3000);
}

// Relative time helper
function getRelativeTime(isoString) {
    const now = new Date();
    const date = new Date(isoString);
    const diffMs = now - date;
    const minutes = Math.floor(diffMs / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (minutes < 1) return 'just now';
    if (minutes < 60) return `${minutes} min ago`;
    if (hours < 24) return `${hours} hours ago`;
    if (days < 7) return `${days} days ago`;
    return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

// Re-render lecture grid helper (used by async cloud data loading)
function _renderLectureGrid(grid, currentModule, moduleId) {
    grid.innerHTML = '';

    if (!currentModule.lectures || currentModule.lectures.length === 0) {
        const emptyState = document.createElement('div');
        emptyState.style.cssText = 'grid-column: 1/-1; text-align: center; padding: 4rem; color: var(--text-secondary); border: 1px dashed var(--border-color); border-radius: 12px;';
        emptyState.innerHTML = `
            <i class="fas fa-book-open" style="font-size: 3rem; margin-bottom: 1rem; opacity: 0.5;"></i>
            <h3>No lectures yet</h3>
            <p>Create your first note to get started.</p>
        `;
        grid.appendChild(emptyState);
    }

    // Sort again just in case (newest first)
    const sortedLectures = [...(currentModule.lectures || [])].sort((a, b) => new Date(b.created || 0) - new Date(a.created || 0));

    sortedLectures.forEach(lecture => {
        const card = document.createElement('div');
        card.className = 'lecture-card';
        card.setAttribute('data-lecture-id', lecture.id);
        card.innerHTML = `
            <div class="card-badge">LECTURE</div>
            <div class="drag-handle"><i class="fas fa-grip-lines"></i></div>
            <h3 class="card-title">${lecture.title}</h3>
            <div class="card-footer">
                <span class="card-time">${lecture.time}</span>
                <div class="card-menu-wrapper">
                    <i class="fas fa-ellipsis-h card-menu" data-id="${lecture.id}"></i>
                    <div class="lecture-action-menu" id="menu-${lecture.id}" style="display: none;">
                        <button data-action="summarise" data-id="${lecture.id}"><i class="fas fa-file-alt"></i> Summarise</button>
                        <button data-action="edit" data-id="${lecture.id}"><i class="fas fa-edit"></i> Edit</button>
                        <button data-action="publish" data-id="${lecture.id}" data-public="${lecture.is_public || false}"><i class="fas ${lecture.is_public ? 'fa-eye-slash' : 'fa-globe'}"></i> ${lecture.is_public ? 'Unpublish' : 'Publish to Community Hub'}</button>
                        <button data-action="copy-link" data-id="${lecture.id}"><i class="fas fa-link"></i> Copy Link</button>
                        <button data-action="move" data-id="${lecture.id}"><i class="fas fa-arrows-alt"></i> Move to Module</button>
                        <button data-action="delete" data-id="${lecture.id}" class="danger"><i class="fas fa-trash"></i> Delete</button>
                    </div>
                </div>
            </div>
        `;

        card.addEventListener('click', (e) => {
            if (card.classList.contains('confirming-delete')) return;

            if (!e.target.closest('.card-menu-wrapper')) {
                window.location.href = `note-editor.html?id=${lecture.id}&module=${moduleId}`;
            }
        });

        grid.appendChild(card);
    });

    // "Create Note" Card
    const addCard = document.createElement('div');
    addCard.className = 'create-card';
    addCard.onclick = () => window.location.href = `note-editor.html?module=${moduleId}`;
    addCard.innerHTML = `<i class="fas fa-plus"></i>`;
    grid.appendChild(addCard);

    // Initialize Drag and Drop for Lectures
    if (typeof Sortable !== 'undefined' && currentModule.lectures.length > 1) {
        new Sortable(grid, {
            animation: 150,
            draggable: '.lecture-card',
            filter: '.create-card', // Don't drag the create-card
            onEnd: async () => {
                const orderedIds = Array.from(grid.querySelectorAll('.lecture-card'))
                    .map(el => el.dataset.lectureId);
                if (orderedIds.length > 0) {
                    await CloudData.updateOrder('lecture', orderedIds);
                }
            }
        });
    }
}

// ─── Create Module Modal Logic (Ported from Dashboard) ───
let selectedIcon = 'fa-file-contract';
let isEditing = false; // Simplified for now (only create)
let editingId = null;

function openCreateModule() {
    isEditing = false;
    editingId = null;

    // Reset Modal Title & Button
    const title = document.querySelector('#create-module-modal h2');
    if (title) title.textContent = 'Create New Module';

    const btn = document.querySelector('#create-module-modal .modal-btn-create');
    if (btn) btn.innerHTML = '<i class="fas fa-plus"></i> Create Module';

    const modal = document.getElementById('create-module-modal');
    if (modal) {
        modal.classList.add('active');
        document.getElementById('new-module-name').value = '';
        const descInput = document.getElementById('new-module-description');
        if (descInput) descInput.value = '';
        document.getElementById('new-module-name').focus();

        // Reset icon
        document.querySelectorAll('.icon-option').forEach(opt => opt.classList.remove('selected'));
        const defaultIcon = document.querySelector('.icon-option[data-icon="fa-file-contract"]');
        if (defaultIcon) defaultIcon.classList.add('selected');
        selectedIcon = 'fa-file-contract';
    }
}

function closeCreateModule() {
    const modal = document.getElementById('create-module-modal');
    if (modal) modal.classList.remove('active');
}

function selectIcon(el) {
    document.querySelectorAll('.icon-option').forEach(opt => opt.classList.remove('selected'));
    el.classList.add('selected');
    selectedIcon = el.dataset.icon;
}

async function confirmCreateModule() {
    const nameInput = document.getElementById('new-module-name');
    const descInput = document.getElementById('new-module-description');
    const name = nameInput.value.trim();
    const description = descInput ? descInput.value.trim() : '';

    if (!name) {
        nameInput.style.borderColor = '#ff5555';
        nameInput.placeholder = 'Please enter a module name';
        return;
    }

    let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');

    if (isEditing && editingId) {
        const moduleData = { id: editingId, name, icon: selectedIcon, description };
        if (typeof CloudData !== 'undefined') {
            try {
                await CloudData.saveModule(moduleData);
            } catch (e) { }
        }
        const index = customModules.findIndex(m => m.id === editingId);
        if (index !== -1) {
            customModules[index] = { ...customModules[index], name, icon: selectedIcon, description };
            localStorage.setItem('customModules', JSON.stringify(customModules));
        }
        if (!document.querySelector('.toast.warning')) {
            showToast(`Module "${name}" updated successfully!`);
        }
    } else {
        const moduleData = { name, icon: selectedIcon, description: description || 'Custom module' };
        let newId = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

        if (typeof CloudData !== 'undefined') {
            try {
                const result = await CloudData.saveModule(moduleData);
                if (result && result.id) newId = result.id;
            } catch (e) {
                console.error('Failed to save module to cloud:', e);
                showToast('Module created locally only (Sync Error)', 'warning');
            }
        }

        customModules.push({
            id: newId,
            name: name,
            icon: selectedIcon,
            description: description || 'Custom module',
            total_lectures: 0,
            completed_lectures: 0,
            created: new Date().toISOString()
        });
        localStorage.setItem('customModules', JSON.stringify(customModules));

        if (!document.querySelector('.toast.warning')) {
            showToast(`Module "${name}" created successfully!`);
        }
    }

    // Close modal
    closeCreateModule();

    // Re-render modules
    renderModuleList();
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('module-toast-create');
    const toastMsg = document.getElementById('toast-message-create');
    if (!toast || !toastMsg) return;
    toastMsg.textContent = message;

    toast.classList.remove('success', 'warning');
    toast.classList.add('show', type);
    setTimeout(() => toast.classList.remove('show', type), 3000);
}

// Event Listeners for Create Module
document.addEventListener('DOMContentLoaded', () => {
    // Icon selection
    const iconGrid = document.getElementById('icon-selection-grid');
    if (iconGrid) {
        iconGrid.addEventListener('click', (e) => {
            const btn = e.target.closest('.icon-option');
            if (btn) selectIcon(btn);
        });
    }

    // Cancel / Confirm
    const btnCancel = document.getElementById('btn-cancel-create');
    if (btnCancel) btnCancel.addEventListener('click', closeCreateModule);

    const btnConfirm = document.getElementById('btn-confirm-create');
    if (btnConfirm) btnConfirm.addEventListener('click', confirmCreateModule);

    // Close on backdrop
    const modalOverlay = document.getElementById('create-module-modal');
    if (modalOverlay) {
        modalOverlay.addEventListener('click', (e) => {
            if (e.target === modalOverlay) closeCreateModule();
        });
    }
});

// --- Module Settings Support Functions ---
function populateModuleSettings(module) {
    const nameInput = document.getElementById('settings-module-name');
    const descInput = document.getElementById('settings-module-description');
    const deadlineInput = document.getElementById('settings-module-deadline');
    const iconDisplay = document.getElementById('settings-module-icon-display');

    if (nameInput) nameInput.value = module.name || '';
    if (descInput) descInput.value = module.description || '';
    const stEl = document.getElementById('settings-module-shared');
    if (stEl) stEl.checked = module.is_shared || false;

    // Find the closest upcoming deadline for this module from window.allDeadlines
    let deadline = null;
    if (window.allDeadlines && window.allDeadlines.length > 0) {
        const modDeadlines = window.allDeadlines.filter(d => d.module_id === module.id && new Date(d.date) > new Date());
        if (modDeadlines.length > 0) {
            deadline = modDeadlines.sort((a, b) => new Date(a.date) - new Date(b.date))[0].date;
        }
    }
    
    // Fallback to legacy exam_deadline if no new deadlines found
    if (!deadline) {
        deadline = module.exam_deadline;
    }

    if (deadlineInput && deadline) {
        // Format to YYYY-MM-DD for input[type=date]
        deadlineInput.value = new Date(deadline).toISOString().split('T')[0];
        updateDeadlineCountdown(deadline);
    } else if (deadlineInput) {
        deadlineInput.value = '';
        const countdown = document.getElementById('deadline-countdown');
        if (countdown) countdown.textContent = '';
    }

    if (iconDisplay && module.icon) {
        iconDisplay.innerHTML = `<i class="fas ${module.icon}"></i>`;
    }

    // Listener for deadline change to update countdown live
    if (deadlineInput) {
        deadlineInput.onchange = (e) => updateDeadlineCountdown(e.target.value);
    }
}

function updateDeadlineCountdown(dateStr) {
    const countdown = document.getElementById('deadline-countdown');
    if (!countdown || !dateStr) return;

    if (!window.detailDeadlineInterval) {
        window.detailDeadlineInterval = setInterval(() => updateDeadlineCountdown(dateStr), 1000);
    }

    const deadline = new Date(dateStr);
    const now = new Date();
    const diff = deadline - now;

    if (diff < 0) {
        countdown.innerHTML = '<i class="fas fa-exclamation-triangle"></i> Passed';
        countdown.style.color = '#ff5555';
        if (window.detailDeadlineInterval) clearInterval(window.detailDeadlineInterval);
    } else {
        const days = Math.floor(diff / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        const secs = Math.floor((diff % (1000 * 60)) / 1000);

        if (days > 0) {
            countdown.textContent = `${days}d ${hours}h ${mins}m until exam`;
        } else {
            countdown.innerHTML = `<span style="color:#ff4d4d">${hours}h ${mins}m ${secs}s until exam</span>`;
        }
        countdown.style.color = 'var(--accent-color)';
    }
}

async function saveModuleSettings() {
    const btn = document.getElementById('btn-save-module-settings');
    const name = document.getElementById('settings-module-name').value.trim();
    const description = document.getElementById('settings-module-description').value.trim();
    const deadline = document.getElementById('settings-module-deadline').value;

    if (!name) {
        showModuleToast('Module name cannot be empty', 'warning');
        return;
    }

    const moduleId = window.currentModuleData.id;
    btn.disabled = true;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';

    const updates = {
        id: moduleId,
        name: name,
        description: description,
        is_shared: document.getElementById('settings-module-shared').checked,
        exam_deadline: deadline ? new Date(deadline).toISOString() : null,
        icon: window.currentModuleData.icon || 'fa-book'
    };

    try {
        if (typeof CloudData !== 'undefined') {
            await CloudData.saveModule(updates);
        }

        // Update local cache
        let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        const idx = customModules.findIndex(m => m.id === moduleId);
        if (idx !== -1) {
            customModules[idx] = { ...customModules[idx], ...updates };
            localStorage.setItem('customModules', JSON.stringify(customModules));
        }

        // Update Breadcrumbs & Header
        document.getElementById('breadcrumb-module-name').textContent = name;
        window.currentModuleData.name = name;
        window.currentModuleData.description = description;
        window.currentModuleData.is_shared = updates.is_shared;
        window.currentModuleData.exam_deadline = updates.exam_deadline;

        showModuleToast('Settings saved successfully!');

        // Switch back to lectures after short delay? User might want to stay.
        // Let's stay on current tab.
    } catch (e) {
        console.error('Failed to save settings:', e);
        showModuleToast('Failed to save settings to cloud', 'warning');
    } finally {
        btn.disabled = false;
        btn.textContent = 'Save Changes';
    }
}

async function archiveModuleSpecific(id) {
    if (!confirm('Are you sure you want to archive this module? It will be moved to the Archived section on your dashboard.')) return;

    try {
        if (typeof CloudData !== 'undefined') {
            await CloudData.archiveModule(id, true);
        }
        let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        const idx = customModules.findIndex(m => m.id === id);
        if (idx !== -1) {
            customModules[idx].archived = true;
            localStorage.setItem('customModules', JSON.stringify(customModules));
        }

        const urlParams = new URLSearchParams(window.location.search);
        let currentModuleId = urlParams.get('id') || (window.location.hash ? window.location.hash.substring(1) : null);

        if (currentModuleId === id) {
            showModuleToast('Module archived. Redirecting...');
            setTimeout(() => window.location.href = 'dashboard.html', 1500);
        } else {
            showModuleToast('Module archived successfully.');
            renderModuleList();
        }
    } catch (e) {
        showModuleToast('Archive failed', 'warning');
    }
}

async function deleteModuleSpecific(id) {
    if (!confirm('PERMANENT ACTION: Are you sure you want to delete this module and ALL its notes? This cannot be undone.')) return;

    try {
        if (typeof CloudData !== 'undefined') {
            await CloudData.deleteModule(id);
        }
        let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        customModules = customModules.filter(m => m.id !== id);
        localStorage.setItem('customModules', JSON.stringify(customModules));

        const urlParams = new URLSearchParams(window.location.search);
        let currentModuleId = urlParams.get('id') || (window.location.hash ? window.location.hash.substring(1) : null);

        if (currentModuleId === id) {
            showModuleToast('Module deleted. Redirecting...');
            setTimeout(() => window.location.href = 'dashboard.html', 1500);
        } else {
            showModuleToast('Module deleted successfully.');
            renderModuleList();
        }
    } catch (e) {
        showModuleToast('Delete failed', 'warning');
    }
}

// Expose open function globally just in case
window.openCreateModule = openCreateModule;

/**
 * Handle Shared Module Invitation (Cross-User Import)
 */
async function handleSharedModuleInvitation(moduleId, ownerId, sharedName) {
    if (typeof MascotBrain !== 'undefined') {
        MascotBrain.speak(`Academic Discovery! 🎓 You've been invited to join the chambers for '${sharedName}'. Do you wish to import these notes into your research?`);
    }

    // Show a custom confirmation dialog
    const confirm = await showModalConfirm(
        'Module Invitation',
        `Join '${sharedName}' and sync its shared notes to your chambers?`,
        'Join Chamber',
        'Decline'
    );

    if (confirm) {
        showModuleToast(`Entering '${sharedName}'...`, 'info');
        try {
            // 1. Fetch Shared Lectures
            const sharedLectures = await CloudData.fetchLecturesForSharing(moduleId, ownerId);
            
            // 2. Create the Local/Cloud Module for current user
            const newModule = await CloudData.saveModule({
                id: moduleId,
                name: sharedName,
                icon: 'fa-book-reader',
                description: 'Shared by a fellow scholar'
            });

            // 3. Save all lectures to current user's account
            for (const lec of sharedLectures) {
                await CloudData.saveLecture({
                    id: lec.id,
                    module: moduleId,
                    title: lec.title,
                    content: lec.content,
                    review_count: lec.review_count,
                    retention_score: lec.retention_score
                });
            }

            showModuleToast('Import successful! ✨');
            if (typeof MascotBrain !== 'undefined') {
                MascotBrain.speak("Welcome to the shared chambers. Collaborative study is much more effective! 🤓");
            }
            
            // Refresh the page or the list
            setTimeout(() => {
                window.location.href = `modules.html?id=${moduleId}`;
            }, 1000);

        } catch (e) {
            console.error('Import failed:', e);
            showModuleToast('Failed to join chamber: ' + e.message, 'warning');
        }
    } else {
        // Clear the URL params without refreshing
        const url = new URL(window.location);
        url.searchParams.delete('owner');
        url.searchParams.delete('name');
        window.history.pushState({}, '', url);
    }
}

async function showModalConfirm(title, message, confirmText, cancelText) {
    return new Promise((resolve) => {
        const modal = document.createElement('div');
        modal.className = 'modal-overlay active';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 400px; text-align: center;">
                <div class="modal-header">
                    <h2>${title}</h2>
                </div>
                <div class="modal-body" style="padding: 2rem 0;">
                    <i class="fas fa-university" style="font-size: 3rem; color: var(--accent-color); margin-bottom: 1rem; opacity: 0.8;"></i>
                    <p style="font-size: 1.1rem; line-height: 1.5;">${message}</p>
                </div>
                <div class="modal-footer" style="display: flex; gap: 1rem; border: none;">
                    <button class="modal-btn-cancel" style="flex: 1;">${cancelText}</button>
                    <button class="modal-btn-create btn-primary" style="flex: 1;">${confirmText}</button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        modal.querySelector('.modal-btn-cancel').onclick = () => {
            modal.remove();
            resolve(false);
        };
        modal.querySelector('.modal-btn-create').onclick = () => {
            modal.remove();
            resolve(true);
        };
    });
}
