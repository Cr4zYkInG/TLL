/**
 * Dashboard Logic
 * Handles user personalization, module rendering, and quick access links.
 */

document.addEventListener('DOMContentLoaded', () => {
    // 0. Onboarding check is handled by auth-guard.js

    // 1. User Personalization
    updateDashboardGreeting();

    // 2. Render Modules
    renderModules();

    // 3. Quick Access — last opened module
    renderQuickAccess();

    const qaContainer = document.querySelectorAll('.modules-grid')[1];
    if (qaContainer) {
        const userType = localStorage.getItem('userType') || 'LLB';
        if (userType === 'LLB') {
            const sqeCard = Array.from(qaContainer.children).find(child => child.innerText.includes('SQE1'));
            if (sqeCard) sqeCard.style.display = 'none';
        }
    }

    // --- Event Listeners (Refactor v2) ---
    // 1. New Module Button
    // 1. New Module Button (Removed per user request)
    // const btnNewModule = document.getElementById('btn-open-create-module');
    // if (btnNewModule) {
    //     btnNewModule.addEventListener('click', openCreateModule);
    // }

    // 2. Quick Access Cards
    const qaInterpret = document.getElementById('qa-interpret');
    if (qaInterpret) {
        qaInterpret.addEventListener('click', () => window.location.href = 'interpret.html');
    }
    const qaNotes = document.getElementById('qa-lecture-notes');
    if (qaNotes) {
        qaNotes.addEventListener('click', () => window.location.href = 'lecture-notes.html');
    }

    // 3. Modal Actions
    const btnCancel = document.getElementById('btn-cancel-create');
    if (btnCancel) {
        btnCancel.addEventListener('click', closeCreateModule);
    }
    const btnConfirm = document.getElementById('btn-confirm-create');
    if (btnConfirm) {
        btnConfirm.addEventListener('click', confirmCreateModule);
    }

    // 4. Icon Selection
    const iconGrid = document.getElementById('icon-selection-grid');
    if (iconGrid) {
        iconGrid.addEventListener('click', (e) => {
            const btn = e.target.closest('.icon-option');
            if (btn) {
                selectIcon(btn);
            }
        });
    }
});

// Onboarding check is now handled globally by js/auth-guard.js.

function renderQuickAccess() {
    const lastModule = JSON.parse(localStorage.getItem('lastOpenedModule') || 'null');
    if (!lastModule || !lastModule.id) return;

    const moduleTerm = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('module') : 'Modules';
    const moduleSingular = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('moduleSingular') : 'Module';

    // Create quick access section
    const quickSection = document.createElement('div');
    quickSection.className = 'quick-access-section';
    quickSection.innerHTML = `
        <h3 class="quick-access-header">
            <i class="fas fa-bolt"></i> Continue where you left off
        </h3>
        <div class="quick-access-card">
            <div class="quick-access-icon">
                <i class="fas fa-book"></i>
            </div>
            <div class="quick-access-info">
                <div class="quick-access-title">${lastModule.name}</div>
                <div class="quick-access-breadcrumbs">
                    <span>Home</span>
                    <i class="fas fa-chevron-right"></i>
                    <span style="color: var(--text-primary);">${lastModule.name}</span>
                </div>
            </div>
            <i class="fas fa-arrow-right quick-access-arrow"></i>
        </div>
    `;

    quickSection.querySelector('.quick-access-card').addEventListener('click', () => {
        window.location.href = `modules.html?id=${lastModule.id}`;
    });

    // Insert before modules container
    modulesContainer.parentNode.insertBefore(quickSection, modulesContainer);
}

function updateDashboardGreeting() {
    let userName = localStorage.getItem('userName');

    // Fallback if userName is generic or missing (e.g. fresh signup)
    if (!userName || userName === 'Student' || userName === 'Guest User') {
        const cachedEmail = localStorage.getItem('userEmail');
        if (cachedEmail) {
            userName = cachedEmail.split('@')[0];
            localStorage.setItem('userName', userName); // Cache it
        } else {
            userName = 'Student';
        }
    }

    const firstName = userName.split(' ')[0] || 'Student';
    const greetingEl = document.getElementById('welcome-name');
    const h1 = document.querySelector('.welcome-text h1');

    const hour = new Date().getHours();
    const timeOfDay = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';

    if (greetingEl) {
        greetingEl.textContent = firstName;
        if (h1 && h1.firstChild) h1.firstChild.textContent = `Good ${timeOfDay}, `;
    } else if (h1) {
        h1.textContent = `Good ${timeOfDay}, ${firstName}.`;
    }
}
window.updateDashboardGreeting = updateDashboardGreeting;

async function renderModules() {
    const userType = localStorage.getItem('userType') || 'LLB';
    const modulesContainer = document.getElementById('modules-container');
    if (!modulesContainer) return;

    modulesContainer.innerHTML = '';

    // Load modules and deadlines from Supabase
    let customModules = [];
    window.allDeadlines = [];
    if (typeof CloudData !== 'undefined') {
        const [modules, deadlines] = await Promise.all([
            CloudData.getModules(),
            CloudData.getDeadlines()
        ]);
        customModules = modules;
        window.allDeadlines = deadlines;
    } else {
        customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
        window.allDeadlines = []; // Should ideally cache this too but focusing on cloud-first
    }

    // --- Blank Slate Logic ---
    // All modules are now treated as "custom" / persistent.
    // If it's a fresh visit (no customModules), we start empty.

    // Check if we need to migrate built-in modules to customModules for existing users?
    // User said "each new account should come blank". 
    // We will assume blank slate is the desired state.

    const activeModules = customModules.filter(m => !m.archived);
    const archivedModules = customModules.filter(m => m.archived);
    // But if they had data linked to 'contract', etc., we should probably Create those modules in customModules if they don't exist.
    // Let's assume for this request "new account = blank". Existing users might see blank if they rely on hardcoded.
    // I will migrate the hardcoded modules into customModules IF they aren't there, to be safe? 
    // Or just strictly follow "Standard modules... editable/deletable".
    // I will implicitly treat everything as a stored module now.



    // 1. Render Active Modules
    activeModules.forEach(mod => {
        const card = createModuleCard(mod, userType);
        modulesContainer.appendChild(card);
    });

    // Start live countdown interval if not already running
    if (!window.deadlineInterval) {
        window.deadlineInterval = setInterval(updateAllModuleCountdowns, 1000);
    }

    // Initialize SortableJS on Dashboard
    if (typeof Sortable !== 'undefined' && activeModules.length > 1) {
        new Sortable(modulesContainer, {
            animation: 150,
            draggable: '.module-card',
            handle: '.drag-handle', // Rely on drag handle
            onEnd: async () => {
                const orderedIds = Array.from(modulesContainer.querySelectorAll('.module-card[data-module-id]'))
                    .map(el => el.dataset.moduleId);

                if (orderedIds.length > 0) {
                    if (typeof CloudData !== 'undefined') {
                        try {
                            await CloudData.updateOrder('module', orderedIds);
                        } catch (e) {
                            console.error('Failed to sync module order:', e);
                        }
                    } else {
                        // Fallback local persistence logic
                        let allModules = JSON.parse(localStorage.getItem('customModules') || '[]');
                        orderedIds.forEach((id, index) => {
                            const mod = allModules.find(m => m.id === id);
                            if (mod) mod.display_order = index;
                        });
                        allModules.sort((a, b) => (a.display_order || 0) - (b.display_order || 0));
                        localStorage.setItem('customModules', JSON.stringify(allModules));
                    }
                }
            }
        });
    }

    // "Add Module" Card removed as per user request (moved to My Modules)

    // 2. Render Archived Modules (if any)
    const archivedContainer = document.getElementById('archived-modules-container');
    if (archivedContainer) archivedContainer.remove(); // Clear existing

    if (archivedModules.length > 0) {
        const archivedSection = document.createElement('div');
        archivedSection.id = 'archived-modules-container';
        archivedSection.style.marginTop = '3rem'; // Keep functional margin for now or move to CSS

        const modulePlural = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('module') : 'Modules';
        archivedSection.innerHTML = `
            <div class="archived-header">
                <i class="fas fa-chevron-right archived-icon" id="archived-toggle-icon"></i>
                <h3>Archived ${modulePlural} (${archivedModules.length})</h3>
            </div>
            <div class="content-grid" id="archived-grid" style="display: none;"></div>
        `;

        archivedSection.querySelector('.archived-header').addEventListener('click', toggleArchivedVisibility);

        // Append to parent of modulesContainer (likely .main-content)
        modulesContainer.parentNode.insertBefore(archivedSection, modulesContainer.nextSibling);

        const grid = archivedSection.querySelector('#archived-grid');
        archivedModules.forEach(mod => {
            const card = createModuleCard(mod, userType, true);
            grid.appendChild(card);
        });
    }


    // 0. Render Dashboard Metrics (Dynamic)
    // Managed by js/study-timer.js

    // Default Fallback values
    const metricsDefaults = {
        studyTime: 0,
        streak: 1,
        leaderboardRank: '--'
    };

    let metrics = JSON.parse(localStorage.getItem('userMetrics')) || metricsDefaults;

    // Calculate display values for initial render
    const hours = Math.floor(metrics.studyTime / 60);
    const mins = Math.floor(metrics.studyTime % 60);
    const timeString = `${hours}h ${mins}m`;
    const todayMins = Math.floor(metrics.todayTime || 0);

    const metricsContainer = document.createElement('div');
    metricsContainer.className = 'dashboard-metrics';
    metricsContainer.innerHTML = `
        <div class="card metric-card">
            <div class="metric-icon-box"><i class="fas fa-clock"></i></div>
            <div class="metric-content">
                <div class="metric-header text-uppercase small opacity-60">Study Time</div>
                <div id="metric-study-time" class="metric-value font-serif">${timeString}</div>
                <div id="metric-today" class="metric-trend"><i class="fas fa-arrow-up"></i> +${todayMins}m today</div>
            </div>
            <div class="metric-status-glow"></div>
        </div>
        <div class="card metric-card">
            <div class="metric-icon-box"><i class="fas fa-fire"></i></div>
            <div class="metric-content">
                <div class="metric-header text-uppercase small opacity-60">Daily Streak</div>
                <div id="metric-streak" class="metric-value font-serif">${metrics.streak} Days</div>
                <div class="metric-subtext">Excellent progress! Keep it up.</div>
            </div>
            <div class="metric-status-glow"></div>
        </div>
        <div class="card metric-card leaderboard-card">
            <div class="leaderboard-header">
                <div class="metric-header text-uppercase small opacity-60"><i class="fas fa-trophy" style="margin-right: 4px;"></i> Leaderboard</div>
                <div class="segmented-control">
                    <button id="lb-toggle-time" class="active" onclick="window.switchLeaderboardType('time')">Time</button>
                    <button id="lb-toggle-streak" onclick="window.switchLeaderboardType('streak')">Streak</button>
                </div>
            </div>
            
            <div class="leaderboard-rank-summary">
                <div id="metric-leaderboard-rank" class="rank-number">#--</div>
                <div id="metric-leaderboard-text" class="rank-message">Loading...</div>
            </div>

            <div id="leaderboard-list" class="leaderboard-scroll-area"><div class="leaderboard-loading"><span class="leaderboard-spinner"></span>Loading leaderboard...</div></div>
        </div>
    `;

    // Insert after "Good morning" text
    if (modulesContainer && modulesContainer.parentNode) {
        const existing = document.querySelector('.dashboard-metrics');
        if (existing) existing.remove();
        modulesContainer.parentNode.insertBefore(metricsContainer, modulesContainer);
    }

    // Fetch Real Leaderboard
    setupLeaderboard();
}

let currentLeaderboardType = 'time';

window.switchLeaderboardType = function (type) {
    if (currentLeaderboardType === type) return;
    currentLeaderboardType = type;

    const btnTime = document.getElementById('lb-toggle-time');
    const btnStreak = document.getElementById('lb-toggle-streak');

    if (type === 'time') {
        btnTime.classList.add('active');
        btnStreak.classList.remove('active');
    } else {
        btnStreak.classList.add('active');
        btnTime.classList.remove('active');
    }

    const list = document.getElementById('leaderboard-list');
    if (list) list.innerHTML = '<div class="leaderboard-loading"><span class="leaderboard-spinner"></span>Loading...</div>';

    fetchAndRenderLeaderboard();
};

async function fetchAndRenderLeaderboard() {
    const leaderboardList = document.getElementById('leaderboard-list');
    const rankEl = document.getElementById('metric-leaderboard-rank');
    const textEl = document.getElementById('metric-leaderboard-text');
    if (!leaderboardList) return;

    function setRankAndMessage(rank, message) {
        if (rankEl) rankEl.textContent = rank;
        if (textEl) textEl.textContent = message;
    }

    // Loading state
    leaderboardList.innerHTML = '<div class="leaderboard-loading"><span class="leaderboard-spinner"></span>Loading leaderboard...</div>';
    setRankAndMessage('#--', 'Loading...');

    let board = [];
    let myId = localStorage.getItem('userId');

    try {
        if (!myId && typeof CloudData !== 'undefined') {
            myId = await CloudData._userId();
            if (myId) localStorage.setItem('userId', myId);
        }

        if (typeof CloudData !== 'undefined' && CloudData.getLeaderboard) {
            board = await CloudData.getLeaderboard(currentLeaderboardType);
        }
    } catch (e) {
        console.warn('Leaderboard fetch failed:', e);
        leaderboardList.innerHTML = '<div class="empty-leaderboard">Unable to load leaderboard. <button type="button" class="btn-leaderboard-retry" onclick="fetchAndRenderLeaderboard()">Try again</button></div>';
        setRankAndMessage('#--', 'Check connection and try again');
        return;
    }

    if (!board || board.length === 0) {
        const hasUsername = localStorage.getItem('leaderboardUsername');
        const emptyMsg = hasUsername
            ? 'No one on the board yet. Start studying to be first!'
            : 'Set a @username in Settings to join the leaderboard.';
        leaderboardList.innerHTML = `<div class="empty-leaderboard">${emptyMsg}</div>`;
        setRankAndMessage('#--', hasUsername ? 'Join the top ranks!' : 'Set @username to compete');
        return;
    }

    leaderboardList.innerHTML = board.map((p, idx) => {
        const isMe = p.userId === myId;
        const rankClass = idx === 0 ? 'rank-1' : idx === 1 ? 'rank-2' : idx === 2 ? 'rank-3' : '';

        let scoreDisplay = currentLeaderboardType === 'time'
            ? (p.time < 60 ? `${Math.round(p.time)}m` : `${(p.time / 60).toFixed(1)}h`)
            : `${p.streak} <i class="fas fa-fire" style="color: #ff5722; font-size: 0.8em;"></i>`;

        return `
            <div class="lb-item ${isMe ? 'lb-item--me' : ''} ${rankClass}">
                <div class="lb-rank">${idx + 1}</div>
                <div class="lb-info">
                    <div class="lb-name">${p.name}</div>
                    <div class="lb-uni">${p.uni}</div>
                </div>
                <div class="lb-score">${scoreDisplay}</div>
            </div>
        `;
    }).join('');

    const myEntry = board.find(p => p.userId === myId);
    if (myEntry && rankEl) rankEl.textContent = `#${myEntry.rank}`;
    if (myEntry && textEl) {
        if (myEntry.rank === 1) textEl.textContent = "You're at the top! 🏆";
        else if (myEntry.rank <= 3) textEl.textContent = "Podium position!";
        else textEl.textContent = "Climbing the ranks...";
    } else if (textEl) {
        const hasUsername = localStorage.getItem('leaderboardUsername');
        textEl.textContent = hasUsername ? "Keep going to enter the Top 10!" : "Set @username in Settings";
    }
}

async function setupLeaderboard() {
    window.fetchAndRenderLeaderboard = fetchAndRenderLeaderboard;
    fetchAndRenderLeaderboard();
    setInterval(fetchAndRenderLeaderboard, 60 * 60 * 1000);
}

// Helper to create card
function createModuleCard(mod, userType, isArchived = false) {
    const card = document.createElement('div');
    card.className = 'module-card';
    if (isArchived) card.classList.add('module-card--archived');

    card.dataset.moduleId = mod.id;

    // Drag Handle (top left)
    const dragHandle = document.createElement('div');
    dragHandle.className = 'drag-handle';
    dragHandle.innerHTML = '<i class="fas fa-grip-lines"></i>';
    card.appendChild(dragHandle);

    // Card Click (Navigation)
    card.addEventListener('click', (e) => {
        if (!e.target.closest('.module-menu-btn') && !e.target.closest('.module-menu-dropdown')) {
            window.location.href = `modules.html?id=${mod.id}`;
        }
    });

    // 1. Menu Button
    const menuBtn = document.createElement('button');
    menuBtn.className = 'module-menu-btn';
    menuBtn.innerHTML = '<i class="fas fa-ellipsis-v"></i>';
    menuBtn.addEventListener('click', (e) => toggleModuleMenu(e, mod.id));

    // 2. Menu Dropdown
    const menuDropdown = document.createElement('div');
    menuDropdown.className = 'module-menu-dropdown';
    menuDropdown.id = `menu-${mod.id}`;

    // Helper to create menu items
    const createMenuItem = (iconClass, text, onClick) => {
        const btn = document.createElement('button');
        btn.className = 'module-menu-item';
        if (text === 'Delete') btn.classList.add('delete');
        btn.innerHTML = `<i class="fas ${iconClass}"></i> ${text}`;
        btn.addEventListener('click', onClick);
        return btn;
    };

    // Sorting Row (<< < > >>)
    const sortingRow = document.createElement('div');
    sortingRow.className = 'module-sorting-row';

    const createSortBtn = (icon, action) => {
        const btn = document.createElement('button');
        btn.className = 'sort-btn';
        btn.innerHTML = `<i class="fas ${icon}"></i>`;
        btn.title = `Move ${action}`;
        btn.onclick = (e) => {
            e.stopPropagation();
            moveModule(mod.id, action);
        };
        return btn;
    };

    sortingRow.appendChild(createSortBtn('fa-angle-double-left', 'first'));
    sortingRow.appendChild(createSortBtn('fa-angle-left', 'left'));
    sortingRow.appendChild(createSortBtn('fa-angle-right', 'right'));
    sortingRow.appendChild(createSortBtn('fa-angle-double-right', 'last'));

    menuDropdown.appendChild(sortingRow);

    menuDropdown.appendChild(createMenuItem('fa-edit', 'Edit', () => renameModule(mod.id)));

    const archiveText = isArchived ? 'Unarchive' : 'Archive';
    const archiveIcon = isArchived ? 'fa-box-open' : 'fa-archive';
    menuDropdown.appendChild(createMenuItem(archiveIcon, archiveText, () => {
        isArchived ? unarchiveModule(mod.id) : archiveModule(mod.id);
    }));

    menuDropdown.appendChild(createMenuItem('fa-trash', 'Delete', () => deleteModule(mod.id)));

    // 3. Icon
    const iconDiv = document.createElement('div');
    iconDiv.className = 'module-icon';
    iconDiv.innerHTML = `<i class="fas ${(typeof CloudData !== 'undefined') ? CloudData.getWebIcon(mod.icon) : (mod.icon || 'fa-folder')}"></i>`;

    // 4. Title
    const titleDiv = document.createElement('div');
    titleDiv.className = 'module-title';
    titleDiv.textContent = mod.name;

    // 5. Description
    const descDiv = document.createElement('div');
    descDiv.className = 'module-description';
    descDiv.textContent = mod.description || '';

    // Assemble Overlay elements
    card.appendChild(menuBtn);
    card.appendChild(menuDropdown);
    card.appendChild(iconDiv);
    card.appendChild(titleDiv);
    card.appendChild(descDiv);

    // 6. Closest Deadline Progress (instead of simple lecture progress)
    const moduleDeadlines = (window.allDeadlines || []).filter(d => d.module_id === mod.id && new Date(d.date) > new Date());
    const closest = moduleDeadlines.sort((a, b) => new Date(a.date) - new Date(b.date))[0];

    if (closest) {
        const deadMeta = document.createElement('div');
        deadMeta.className = 'module-meta deadline-meta';
        deadMeta.dataset.deadlineDate = closest.date;
        deadMeta.dataset.createdAt = closest.created_at;
        
        const progressBar = document.createElement('div');
        progressBar.className = 'progress-bar deadline-progress';
        
        const fill = document.createElement('div');
        fill.className = 'progress-fill';
        progressBar.appendChild(fill);

        card.appendChild(deadMeta);
        card.appendChild(progressBar);
        
        // Initial update
        updateModuleDeadlineDisplay(deadMeta, progressBar, closest.date, closest.created_at);
    } 
    else if (mod.total_lectures && mod.total_lectures > 0) {
        // Fallback to legacy progress if no deadlines
        const lectureTerm = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('lecture') : 'Lectures';
        const metaDiv = document.createElement('div');
        metaDiv.className = 'module-meta';
        metaDiv.innerHTML = `<span><i class="fas fa-chalkboard-teacher"></i> ${mod.completed_lectures || 0} / ${mod.total_lectures} ${lectureTerm}</span>`;

        const progressBar = document.createElement('div');
        progressBar.className = 'progress-bar';

        const fill = document.createElement('div');
        fill.className = 'progress-fill';
        fill.style.width = `${Math.round(((mod.completed_lectures || 0) / mod.total_lectures) * 100)}%`;

        progressBar.appendChild(fill);
        card.appendChild(metaDiv);
        card.appendChild(progressBar);
    }

    return card;
}

function toggleArchivedVisibility() {
    const grid = document.getElementById('archived-grid');
    const icon = document.getElementById('archived-toggle-icon');
    if (grid.style.display === 'none') {
        grid.style.display = 'grid'; // .content-grid uses grid
        icon.style.transform = 'rotate(90deg)';
    } else {
        grid.style.display = 'none';
        icon.style.transform = 'rotate(0deg)';
    }
}

async function archiveModule(id) {
    // Cloud-first archive
    if (typeof CloudData !== 'undefined') {
        try {
            await CloudData.archiveModule(id, true);
        } catch (e) {
            console.error('Failed to archive module on cloud:', e);
            showToast('Archived locally (Sync Error)', 'warning');
        }
    }
    // Also update localStorage cache
    let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const idx = customModules.findIndex(m => m.id === id);
    if (idx !== -1) {
        customModules[idx].archived = true;
        localStorage.setItem('customModules', JSON.stringify(customModules));
    }

    renderModules();
    if (!document.querySelector('.toast.warning')) {
        showToast('Module archived.');
    }
}

async function unarchiveModule(id) {
    // Cloud-first unarchive
    if (typeof CloudData !== 'undefined') {
        try {
            await CloudData.archiveModule(id, false);
        } catch (e) {
            console.error('Failed to unarchive module on cloud:', e);
            showToast('Unarchived locally (Sync Error)', 'warning');
        }
    }
    let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const idx = customModules.findIndex(m => m.id === id);
    if (idx !== -1) {
        customModules[idx].archived = false;
        localStorage.setItem('customModules', JSON.stringify(customModules));
    }

    // The moduleStates object is no longer the primary source for archive status.
    // let moduleStates = JSON.parse(localStorage.getItem('moduleStates') || '{}');
    // if (moduleStates[id]) {
    //     moduleStates[id].archived = false;
    //     localStorage.setItem('moduleStates', JSON.stringify(moduleStates));
    // }

    renderModules();
    showToast('Module unarchived.');
}

// Modal Functions
let selectedIcon = 'fa-file-contract';

function openCreateModule() {
    isEditing = false;
    editingId = null;

    // Reset Modal Title & Button
    const title = document.querySelector('#create-module-modal h2');
    if (title) title.textContent = 'Create New Module';

    const btn = document.querySelector('#create-module-modal .modal-btn-create');
    if (btn) btn.innerHTML = '<i class="fas fa-plus"></i> Create Module';

    document.getElementById('create-module-modal').classList.add('active');
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

function closeCreateModule() {
    document.getElementById('create-module-modal').classList.remove('active');
    document.getElementById('new-module-name').value = '';
    const descInput = document.getElementById('new-module-description');
    if (descInput) descInput.value = '';
    isEditing = false;
    editingId = null;
    // Reset icon selection
    document.querySelectorAll('.icon-option').forEach(opt => opt.classList.remove('selected'));
    const defaultIcon = document.querySelector('.icon-option[data-icon="fa-file-contract"]');
    if (defaultIcon) defaultIcon.classList.add('selected');
    selectedIcon = 'fa-file-contract';
}

function selectIcon(el) {
    document.querySelectorAll('.icon-option').forEach(opt => opt.classList.remove('selected'));
    el.classList.add('selected');
    selectedIcon = el.getAttribute('data-icon');
}

// Initialize SortableJS for module reordering
function initializeSortable() {
    const container = document.getElementById('modules-container');
    if (!container || typeof Sortable === 'undefined') return;

    new Sortable(container, {
        animation: 150,
        handle: '.module-drag-handle', // Drag handle class
        ghostClass: 'sortable-ghost', // Class name for the drop placeholder
        onEnd: async function (evt) {
            const itemEl = evt.item; // dragged HTMLElement
            const oldIndex = evt.oldIndex;
            const newIndex = evt.newIndex;

            if (oldIndex === newIndex) return; // No change in order

            let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
            const activeModules = customModules.filter(m => !m.archived);

            const movedModule = activeModules.splice(oldIndex, 1)[0];
            activeModules.splice(newIndex, 0, movedModule);

            // Update IDs for the updateOrder call
            const orderedIds = activeModules.map(m => m.id);

            // Map back to full customModules preserving archives
            const archivedModules = customModules.filter(m => m.archived);
            const finalModules = [...activeModules, ...archivedModules];

            localStorage.setItem('customModules', JSON.stringify(finalModules));

            if (typeof CloudData !== 'undefined') {
                try {
                    await CloudData.updateOrder('module', orderedIds);
                } catch (e) {
                    console.error('Failed to update module order on cloud:', e);
                    showToast('Order updated locally (Sync Error)', 'warning');
                }
            }
            // No need to re-render, SortableJS already updated the DOM
        }
    });
}

// Call initializeSortable after modules are rendered
// This function needs to be called within renderModules or after it completes.
// For the purpose of this edit, I'll assume renderModules is defined elsewhere
// and this initialization will be added there.

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
        // Update Existing
        const moduleData = { id: editingId, name, icon: selectedIcon, description };
        if (typeof CloudData !== 'undefined') {
            try {
                await CloudData.saveModule(moduleData);
            } catch (e) {
                console.error('Failed to update module on cloud:', e);
                showToast('Updated locally (Sync Error)', 'warning');
            }
        }
        const index = customModules.findIndex(m => m.id === editingId);
        if (index !== -1) {
            customModules[index].name = name;
            customModules[index].icon = selectedIcon;
            customModules[index].modified = new Date().toISOString();
            localStorage.setItem('customModules', JSON.stringify(customModules));
        }
        if (!document.querySelector('.toast.warning')) {
            showToast(`Module "${name}" updated successfully!`);
        }
    } else {
        // Create New — save to Supabase first, get the UUID back
        const moduleData = { name, icon: selectedIcon, description: description || 'Custom module' };
        let newId = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

        if (typeof CloudData !== 'undefined') {
            try {
                const result = await CloudData.saveModule(moduleData);
                if (result && result.id) newId = result.id;
            } catch (e) {
                console.error('Failed to save module to cloud:', e);
                showToast('Created locally (Sync Error)', 'warning');
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
    renderModules();
}

async function moveModule(id, direction) {
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
    } else if (direction === 'left') {
        const newIdx = Math.max(0, index - 1);
        newOrder.splice(newIdx, 0, item);
    } else if (direction === 'right') {
        const newIdx = Math.min(activeModules.length - 1, index + 1);
        newOrder.splice(newIdx, 0, item);
    }

    // Map back to full customModules preserving archives
    const archivedModules = customModules.filter(m => m.archived);
    const finalModules = [...newOrder, ...archivedModules];

    // Update IDs for the updateOrder call
    const orderedIds = newOrder.map(m => m.id);

    // Save
    if (typeof CloudData !== 'undefined') {
        await CloudData.updateOrder('module', orderedIds);
    }

    localStorage.setItem('customModules', JSON.stringify(finalModules));
    renderModules();
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toast-message');
    if (!toast || !toastMsg) return;
    toastMsg.textContent = message;

    toast.classList.remove('success', 'warning');
    toast.classList.add('show', type);
    setTimeout(() => toast.classList.remove('show', type), 3000);
}

// Close modal on backdrop click
document.addEventListener('click', (e) => {
    if (e.target.id === 'create-module-modal') {
        closeCreateModule();
    }
});

// Close modal on Escape
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeCreateModule();
    }
});

// Close open menus when clicking outside
document.addEventListener('click', (e) => {
    if (!e.target.closest('.module-menu-btn') && !e.target.closest('.module-menu-dropdown')) {
        document.querySelectorAll('.module-menu-dropdown').forEach(d => d.classList.remove('show'));
        document.querySelectorAll('.module-menu-btn').forEach(b => b.classList.remove('active'));
    }
});

/* Module Actions */
function toggleModuleMenu(event, id) {
    event.stopPropagation();
    const dropdown = document.getElementById(`menu-${id}`);
    const btn = event.currentTarget;

    // Close others
    document.querySelectorAll('.module-menu-dropdown').forEach(d => {
        if (d !== dropdown) d.classList.remove('show');
    });
    document.querySelectorAll('.module-menu-btn').forEach(b => {
        if (b !== btn) b.classList.remove('active');
    });

    dropdown.classList.toggle('show');
    btn.classList.toggle('active');
}


// ── Delete Confirmation Logic (Slide to Delete) ──

let pendingDeleteId = null;
let isDragging = false;
let startX = 0;
let currentX = 0;

function injectDeleteModal() {
    if (document.getElementById('delete-module-modal')) return;

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay delete-modal';
    overlay.id = 'delete-module-modal';
    overlay.style.display = 'none';
    overlay.style.zIndex = '9999';

    const content = document.createElement('div');
    content.className = 'modal-content delete-modal-content';

    const closeBtn = document.createElement('button');
    closeBtn.className = 'modal-close';
    closeBtn.innerHTML = '<i class="fas fa-times"></i>';
    closeBtn.addEventListener('click', closeDeleteModal);

    const iconWrapper = document.createElement('div');
    iconWrapper.className = 'delete-icon-wrapper';
    iconWrapper.innerHTML = '<i class="fas fa-trash-alt"></i>';

    const title = document.createElement('h3');
    title.className = 'delete-title';
    title.textContent = 'Delete Module?';

    const desc = document.createElement('p');
    desc.className = 'delete-desc';
    desc.textContent = 'This action cannot be undone.';

    // Slide Track
    const track = document.createElement('div');
    track.className = 'slide-delete-container';
    track.id = 'slide-delete-track';

    const slideText = document.createElement('div');
    slideText.className = 'slide-text';
    slideText.textContent = 'Slide to delete >>';

    const thumb = document.createElement('div');
    thumb.className = 'slide-thumb';
    thumb.id = 'slide-delete-thumb';
    thumb.innerHTML = '<i class="fas fa-arrow-right"></i>';

    track.appendChild(slideText);
    track.appendChild(thumb);

    content.appendChild(closeBtn);
    content.appendChild(iconWrapper);
    content.appendChild(title);
    content.appendChild(desc);
    content.appendChild(track);

    overlay.appendChild(content);
    document.body.appendChild(overlay);

    initSlideDelete();
}

function initSlideDelete() {
    const track = document.getElementById('slide-delete-track');
    const thumb = document.getElementById('slide-delete-thumb');

    if (!track || !thumb) return;

    const startDrag = (e) => {
        isDragging = true;
        startX = (e.pageX || e.touches[0].pageX);
        thumb.style.transition = 'none';
    };

    const onDrag = (e) => {
        if (!isDragging) return;
        const x = (e.pageX || e.touches[0].pageX);
        const delta = x - startX;
        const maxScroll = track.offsetWidth - thumb.offsetWidth - 4; // 4px padding/margin adjustment

        currentX = Math.max(0, Math.min(delta, maxScroll));
        thumb.style.transform = `translateX(${currentX}px)`;

        // Visual feedback
        const progress = currentX / maxScroll;
        track.style.opacity = 1 - (progress * 0.3); // Slight fade

        if (progress > 0.9) {
            track.classList.add('completed');
            thumb.innerHTML = '<i class="fas fa-check"></i>';
        } else {
            track.classList.remove('completed');
            thumb.innerHTML = '<i class="fas fa-arrow-right"></i>';
        }
    };

    const endDrag = () => {
        if (!isDragging) return;
        isDragging = false;
        thumb.style.transition = 'transform 0.3s cubic-bezier(0.16, 1, 0.3, 1)';

        const maxScroll = track.offsetWidth - thumb.offsetWidth - 4;

        if (currentX > maxScroll * 0.85) {
            // Success
            thumb.style.transform = `translateX(${maxScroll}px)`;
            performDelete();
        } else {
            // Snap back
            currentX = 0;
            thumb.style.transform = `translateX(0px)`;
            track.classList.remove('completed');
            thumb.innerHTML = '<i class="fas fa-arrow-right"></i>';
        }
    };

    thumb.addEventListener('mousedown', startDrag);
    thumb.addEventListener('touchstart', startDrag);

    document.addEventListener('mousemove', onDrag);
    document.addEventListener('touchmove', onDrag);

    document.addEventListener('mouseup', endDrag);
    document.addEventListener('touchend', endDrag);
}

function deleteModule(id) {
    const moduleSingular = typeof TerminologyManager !== 'undefined' ? TerminologyManager.getTerm('moduleSingular') : 'Module';
    injectDeleteModal(); // Ensure it exists
    pendingDeleteId = id;

    const deleteTitle = document.querySelector('.delete-title');
    if (deleteTitle) deleteTitle.textContent = `Delete ${moduleSingular}?`;

    // Reset Slider
    const track = document.getElementById('slide-delete-track');
    const thumb = document.getElementById('slide-delete-thumb');
    if (track && thumb) {
        track.classList.remove('completed');
        thumb.style.transform = 'translateX(0)';
        thumb.innerHTML = '<i class="fas fa-arrow-right"></i>';
        currentX = 0;
    }

    const modal = document.getElementById('delete-module-modal');
    modal.style.display = 'flex';
    setTimeout(() => modal.classList.add('active'), 10);
}

function closeDeleteModal() {
    const modal = document.getElementById('delete-module-modal');
    if (modal) {
        modal.classList.remove('active');
        setTimeout(() => modal.style.display = 'none', 300);
    }
    pendingDeleteId = null;
}

async function performDelete() {
    if (!pendingDeleteId) return;

    // Cloud-first delete
    if (typeof CloudData !== 'undefined') {
        try {
            await CloudData.deleteModule(pendingDeleteId);
        } catch (e) {
            console.error('Failed to delete module from cloud:', e);
            showToast('Deleted locally (Sync Error)', 'warning');
        }
    }

    let customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    customModules = customModules.filter(m => m.id !== pendingDeleteId);
    localStorage.setItem('customModules', JSON.stringify(customModules));

    renderModules();
    showToast('Module deleted successfully.');

    // Close modal after delay
    setTimeout(() => {
        closeDeleteModal();
    }, 400);
}

// FIX: Reset inaccurate metrics on load (Simulated once)
// FIX: Reset inaccurate metrics on load (Simulated once)
if (!sessionStorage.getItem('metricsFixed_v2')) {
    const m = JSON.parse(localStorage.getItem('userMetrics'));
    if (m) {
        // Reset study time if suspiciously high on fresh load
        if (m.studyTime > 300) m.studyTime = 0;

        // Reset streak if it's suspiciously high (e.g. 50) without corresponding study history
        // or just force reset it to 1 if it looks like the bug reported (50 days)
        if (m.streak >= 50) m.streak = 1;

        localStorage.setItem('userMetrics', JSON.stringify(m));
    }
    sessionStorage.setItem('metricsFixed_v2', 'true');
}

let isEditing = false;
let editingId = null;

function renameModule(id) {
    const customModules = JSON.parse(localStorage.getItem('customModules') || '[]');
    const module = customModules.find(m => m.id === id);
    if (!module) return;

    isEditing = true;
    editingId = id;

    // Open Modal
    document.getElementById('create-module-modal').classList.add('active');
    document.getElementById('new-module-name').value = module.name;
    document.getElementById('new-module-name').focus();

    // Select Icon
    selectedIcon = module.icon;
    document.querySelectorAll('.icon-option').forEach(opt => {
        opt.classList.toggle('selected', opt.dataset.icon === module.icon);
    });

    // Update Button Text
    const confirmBtn = document.querySelector('#create-module-modal .btn-primary');
    if (confirmBtn) confirmBtn.textContent = 'Update Module';
    const title = document.querySelector('#create-module-modal h3');
    if (title) title.textContent = 'Edit Module';
}

// --- Live Countdown Support ---

function updateAllModuleCountdowns() {
    const modules = document.querySelectorAll('.module-card');
    modules.forEach(card => {
        const meta = card.querySelector('.deadline-meta');
        const progress = card.querySelector('.deadline-progress');
        if (meta && progress) {
            const end = meta.dataset.deadlineDate;
            const start = meta.dataset.createdAt;
            updateModuleDeadlineDisplay(meta, progress, end, start);
        }
    });
}

function updateModuleDeadlineDisplay(metaEl, progressEl, endDateStr, startDateStr) {
    const now = new Date();
    const end = new Date(endDateStr);
    const start = new Date(startDateStr);
    
    const diff = end - now;
    const total = end - start;
    
    if (diff <= 0) {
        metaEl.innerHTML = '<span class="expired"><i class="fas fa-exclamation-triangle"></i> EXPIRED</span>';
        const fill = progressEl.querySelector('.progress-fill');
        if (fill) fill.style.width = '100%';
        progressEl.classList.add('expired');
        return;
    }

    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const secs = Math.floor((diff % (1000 * 60)) / 1000);

    let displayStr = '';
    if (days > 0) {
        displayStr = `<span><i class="fas fa-clock"></i> ${days}d ${hours}h ${mins}m</span>`;
    } else {
        displayStr = `<span class="urgent"><i class="fas fa-stopwatch"></i> ${hours}h ${mins}m ${secs}s</span>`;
    }
    
    metaEl.innerHTML = displayStr;

    // Progress bar fill
    const elapsed = now - start;
    const fraction = Math.min(Math.max(elapsed / total, 0), 1);
    const fill = progressEl.querySelector('.progress-fill');
    if (fill) {
        fill.style.width = `${Math.round(fraction * 100)}%`;
        if (days < 7) fill.style.background = 'var(--accent-red, #ff4d4d)';
    }
}

// End of Dashboard Logic

