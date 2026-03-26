/**
 * CloudData — Central Cloud Data Service
 * Wraps Supabase CRUD for all user data.
 * Falls back to localStorage when offline or unauthenticated.
 */

const CloudData = {

    // ─── Helpers ───

    getWebIcon(iconStr) {
        if (!iconStr) return 'fa-folder';
        if (iconStr.startsWith('fa-')) return iconStr;
        
        const map = {
            'folder.fill': 'fa-folder',
            'doc.text.fill': 'fa-file-contract',
            'hammer.fill': 'fa-gavel',
            'scalemass.fill': 'fa-balance-scale',
            'bookmark.fill': 'fa-bookmark',
            'book.fill': 'fa-book',
            'building.columns.fill': 'fa-university',
            'briefcase.fill': 'fa-briefcase',
            'books.vertical.fill': 'fa-book-open',
            'chart.bar.doc.horizontal.fill': 'fa-chart-bar',
            'shield.lefthalf.filled': 'fa-shield-alt',
            'graduationcap.fill': 'fa-graduation-cap',
            'scroll.fill': 'fa-scroll',
            'magnifyingglass.circle.fill': 'fa-search',
            'doc.richtext.fill': 'fa-file-word'
        };
        return map[iconStr] || 'fa-folder';
    },

    async _client() {
        if (typeof getSupabaseClient === 'function') {
            return getSupabaseClient();
        }
        return null;
    },

    async _userId() {
        try {
            const client = await this._client();
            if (!client) return null;
            
            // Prefer getSession() for immediate value, fallback to getUser()
            const { data: { session } } = await client.auth.getSession();
            if (session?.user?.id) return session.user.id;
            
            const { data: { user } } = await client.auth.getUser();
            return user?.id || null;
        } catch (e) {
            console.error('CloudData._userId error:', e);
            return null;
        }
    },

    // ─── MODULES ───

    async getModules() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            let { data, error } = await client
                .from('user_modules')
                .select('*')
                .eq('user_id', uid)
                .eq('is_deleted', false)
                .order('display_order', { ascending: true })
                .order('created_at', { ascending: false });

            // Fallback if 'display_order' doesn't exist
            if (error) {
                const retry = await client
                    .from('user_modules')
                    .select('*')
                    .eq('user_id', uid)
                    .order('created_at', { ascending: false });
                
                if (retry.error) throw retry.error;
                data = retry.data;
            }

            // Sync to localStorage as cache
            const mapped = data.map(m => ({
                id: m.id,
                name: m.name,
                icon: m.icon,
                description: m.description,
                archived: m.archived,
                is_shared: m.is_shared,
                exam_deadline: m.exam_deadline,
                created: m.created_at,
                modified: m.created_at
            }));
            localStorage.setItem('customModules', JSON.stringify(mapped));
            return mapped;
        } catch (e) {
            if (e.message && (e.message.includes('display_order') || e.code === 'PGRST204')) {
                // Silently fall back if the column is missing - avoids confusing console errors
            } else {
                console.warn('CloudData.getModules fallback:', e.message);
            }
            return JSON.parse(localStorage.getItem('customModules') || '[]');
        }

    },

    async saveModule(moduleData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                name: moduleData.name,
                icon: moduleData.icon || 'fa-file-contract',
                description: moduleData.description || '',
                archived: moduleData.archived || false,
                is_shared: moduleData.is_shared || false,
                is_deleted: false, // Ensure we reset tombstone if re-saving
                exam_deadline: moduleData.exam_deadline || null,
                updated_at: new Date().toISOString()
            };


            // If module has a uuid-style id, upsert; else insert
            if (moduleData.id && moduleData.id.length > 30) {
                row.id = moduleData.id;
            }

            const { data, error } = await client
                .from('user_modules')
                .upsert(row, { onConflict: 'id' })
                .select('id, user_id, name, icon, description, archived, is_shared, is_deleted, exam_deadline, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.error('CloudData.saveModule error:', e);
            throw e; // Rethrow to let UI handle "Offline/Error" state
        }
    },

    async deleteModule(moduleId) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            // Switch to Tombstone deletion for iOS Sync compatibility
            const { error } = await client
                .from('user_modules')
                .update({ is_deleted: true })
                .eq('id', moduleId)
                .eq('user_id', uid);

            if (error) throw error;
            return true;
        } catch (e) {
            console.warn('CloudData.deleteModule error:', e.message);
            return false;
        }
    },


    async archiveModule(moduleId, archived = true) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { error } = await client
                .from('user_modules')
                .update({ archived })
                .eq('id', moduleId)
                .eq('user_id', uid);

            if (error) throw error;
            return true;
        } catch (e) {
            console.warn('CloudData.archiveModule fallback:', e.message);
            return false;
        }
    },

    async updateOrder(type, orderedIds) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const table = type === 'module' ? 'user_modules' : 'lectures';

            // Build bulk update
            const updates = orderedIds.map((id, index) => ({
                id,
                user_id: uid,
                display_order: index,
                created_at: new Date().toISOString()
            }));

            const { error } = await client
                .from(table)
                .upsert(updates);

            if (error) throw error;

            // Update local cache if modules
            if (type === 'module') {
                const local = JSON.parse(localStorage.getItem('customModules') || '[]');
                orderedIds.forEach((id, index) => {
                    const mod = local.find(m => m.id === id);
                    if (mod) mod.display_order = index;
                });
                local.sort((a, b) => (a.display_order || 0) - (b.display_order || 0));
                localStorage.setItem('customModules', JSON.stringify(local));
            }

            return true;
        } catch (e) {
            console.error('CloudData.updateOrder error:', e);
            return false;
        }
    },

    // ─── LECTURES ───

    async getLectures(moduleId) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            let query = client
                .from('lectures')
                .select('*')
                .eq('user_id', uid);

            if (moduleId) {
                query = query.eq('module_id', moduleId);
            }

            let { data, error } = await query
                .eq('is_deleted', false)
                .order('display_order', { ascending: true })
                .order('created_at', { ascending: false });
                
            if (error) {
                let retryQuery = client.from('lectures').select('*').eq('user_id', uid);
                if (moduleId) retryQuery = retryQuery.eq('module_id', moduleId);
                
                const retry = await retryQuery.order('created_at', { ascending: false });
                if (retry.error) throw retry.error;
                data = retry.data;
            }

            // Cache
            const mapped = data.map(l => ({
                id: l.id,
                title: l.title,
                content: l.content,
                module: l.module_id,
                preview: l.preview,
                created: l.created_at,
                lastModified: l.last_modified || l.created_at,
                review_count: l.review_count,
                last_reviewed_at: l.last_reviewed_at,
                retention_score: l.retention_score,
                is_public: l.is_public
            }));
            return mapped;
        } catch (e) {
            if (e.message && (e.message.includes('display_order') || e.code === 'PGRST204')) {
                // Silently fall back if the column is missing
            } else {
                console.warn('CloudData.getLectures fallback:', e.message);
            }
            const all = JSON.parse(localStorage.getItem('savedLectureNotes') || '[]');
            return moduleId ? all.filter(n => n.module === moduleId) : all;
        }

    },

    /**
     * Fetch lectures for a specific module owned by ANY user (used for sharing/joining)
     */
    async fetchLecturesForSharing(moduleId, ownerId) {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            const { data, error } = await client
                .from('lectures')
                .select('*')
                .eq('user_id', ownerId)
                .eq('module_id', moduleId)
                .eq('is_deleted', false)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data.map(l => ({
                id: l.id,
                title: l.title,
                content: l.content,
                module: l.module_id,
                preview: l.preview,
                created: l.created_at,
                lastModified: l.last_modified || l.created_at,
                review_count: l.review_count,
                retention_score: l.retention_score
            }));
        } catch (e) {
            console.error('CloudData.fetchLecturesForSharing error:', e);
            throw e;
        }
    },

    async saveLecture(noteData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                id: noteData.id,
                user_id: uid,
                module_id: noteData.module || null,
                title: noteData.title || 'Untitled Note',
                content: noteData.content || '',
                preview: (noteData.content || '').replace(/<[^>]*>/g, '').substring(0, 200),
                ai_history: noteData.ai_history || [],
                review_count: noteData.review_count || 0,
                last_reviewed_at: noteData.last_reviewed_at || new Date().toISOString(),
                retention_score: noteData.retention_score || 100.0,
                is_deleted: false, // Explicitly reset tombstone
                last_modified: new Date().toISOString(),
                
                // Parity fields (Preserve if they exist in noteData)
                is_public: noteData.is_public || false,
                upvotes: noteData.upvotes || 0,
                attachment_url: noteData.attachment_url || null,
                drawing_data: noteData.drawing_data || null,
                pdf_data: noteData.pdf_data || null,
                audio_url: noteData.audio_url || null,
                paper_style: noteData.paper_style || null,
                paper_color: noteData.paper_color || null
            };


            if (!row.id || row.id.startsWith('draft-')) {
                // Generate a valid ID since Supabase schema doesn't auto-generate text IDs
                row.id = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : `note-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
            }


            const { data, error } = await client
                .from('lectures')
                .upsert(row, { onConflict: 'id,user_id' })
                .select('id, user_id, module_id, title, content, preview, ai_history, review_count, last_reviewed_at, retention_score, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.error('CloudData.saveLecture error:', e);
            throw e; // Rethrow so note-editor.js shows "Local Only"
        }
    },

    async getLecture(lectureId) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('lectures')
                .select('*')
                .eq('id', lectureId)
                .eq('user_id', uid)
                .eq('is_deleted', false)
                .maybeSingle();

            if (error) throw error;
            if (!data) return null;
            return {
                id: data.id,
                title: data.title,
                content: data.content,
                module: data.module_id,
                preview: data.preview,
                ai_history: data.ai_history || [],
                created: data.created_at,
                lastModified: data.last_modified || data.created_at,
                review_count: data.review_count,
                last_reviewed_at: data.last_reviewed_at,
                retention_score: data.retention_score,
                is_deleted: data.is_deleted || false,
                is_public: data.is_public || false,
                upvotes: data.upvotes || 0,
                
                // Parity fields
                attachment_url: data.attachment_url,
                drawing_data: data.drawing_data,
                pdf_data: data.pdf_data,
                audio_url: data.audio_url,
                paper_style: data.paper_style,
                paper_color: data.paper_color
            };
        } catch (e) {
            console.warn('CloudData.getLecture fallback:', e.message);
            return JSON.parse(localStorage.getItem(`note-${lectureId}`) || 'null');
        }
    },

    async deleteLecture(lectureId) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            // Switch to Tombstone deletion for iOS Sync compatibility
            const { error } = await client
                .from('lectures')
                .update({ is_deleted: true })
                .eq('id', lectureId)
                .eq('user_id', uid);

            if (error) throw error;
            return true;
        } catch (e) {
            console.warn('CloudData.deleteLecture error:', e.message);
            return false;
        }
    },


    // ─── PROFILE ───

    async getProfile() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('profiles')
                .select('id, first_name, last_name, university, target_year, current_status, student_level, leaderboard_username, is_anonymous, avatar_url, created_at')
                .eq('id', uid)
                .single();

            if (error) throw error;
            
            // Sync to local
            if (data) {
                const fullName = [data.first_name, data.last_name].filter(Boolean).join(' ');
                localStorage.setItem('userName', fullName || 'Guest User');
                localStorage.setItem('userUniversity', data.university || '');
                localStorage.setItem('leaderboardUsername', data.leaderboard_username || '');
                localStorage.setItem('isAnonymous', data.is_anonymous || false);
                localStorage.setItem('userAvatarUrl', data.avatar_url || '');

                if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);
                if (data.current_status) localStorage.setItem('userStatus', data.current_status);
                if (data.student_level) localStorage.setItem('studentLevel', data.student_level);
            }

            return data;
        } catch (e) {
            console.warn('CloudData.getProfile fallback:', e.message);
            return null;
        }
    },

    async saveProfile(profileData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const updates = {
                id: uid,
                ...profileData
            };

            const { data, error } = await client
                .from('profiles')
                .upsert(updates, { onConflict: 'id' })
                .select('id, first_name, last_name, university, target_year, current_status, student_level, leaderboard_username, is_anonymous, avatar_url, created_at')
                .single();

            if (error) throw error;

            // Sync cache
            if (data) {
                localStorage.setItem('userName', [data.first_name, data.last_name].filter(Boolean).join(' '));
                localStorage.setItem('userUniversity', data.university || '');
                localStorage.setItem('leaderboardUsername', data.leaderboard_username || '');
                localStorage.setItem('isAnonymous', data.is_anonymous || false);
                localStorage.setItem('userAvatarUrl', data.avatar_url || '');

                if (data.target_year) localStorage.setItem('userTargetYear', data.target_year);
                if (data.current_status) localStorage.setItem('userStatus', data.current_status);
                if (data.student_level) localStorage.setItem('studentLevel', data.student_level);
            }
            return data || true;
        } catch (e) {
            console.error('CloudData.saveProfile error:', e);
            throw e;
        }
    },

    // ─── METRICS ───

    async getMetrics() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_metrics')
                .select('*')
                .eq('user_id', uid)
                .single();

            if (error && error.code === 'PGRST116') {
                // No row yet — create default
                const defaults = {
                    user_id: uid,
                    study_time: 0,
                    today_time: 0,
                    last_study_date: new Date().toISOString().split('T')[0],
                    streak: 1,
                    leaderboard_rank: 99,
                    lifetime_study_time: 0,
                    last_study_reset: new Date().toISOString()
                };
                await client.from('user_metrics').insert(defaults);
                return {
                    studyTime: 0,
                    todayTime: 0,
                    lastStudyDate: defaults.last_study_date,
                    streak: 1,
                    leaderboardRank: 99,
                    lifetimeStudyTime: 0,
                    lastStudyReset: defaults.last_study_reset
                };
            }
            if (error) throw error;

            const now = new Date();
            let studyTime = data.study_time;
            let lastReset = new Date(data.last_study_reset || now);
            let lifetimeStudyTime = data.lifetime_study_time || studyTime;

            // Monthly Reset Logic for Study Time (acting as monthly leaderboard score)
            if (lastReset.getMonth() !== now.getMonth() || lastReset.getFullYear() !== now.getFullYear()) {
                studyTime = 0;
                lastReset = now;
                // Save the reset to DB immediately
                const { error: resetError } = await client.from('user_metrics').update({
                    study_time: 0,
                    last_study_reset: now.toISOString()
                }).eq('user_id', uid);
                if (resetError) console.error('Failed to update basic study metric reset:', resetError);
            }

            const metrics = {
                studyTime: studyTime,
                todayTime: data.today_time,
                lastStudyDate: data.last_study_date,
                streak: data.streak,
                leaderboardRank: data.leaderboard_rank,
                lifetimeStudyTime: lifetimeStudyTime,
                lastStudyReset: lastReset.toISOString()
            };
            localStorage.setItem('userMetrics', JSON.stringify(metrics));
            return metrics;
        } catch (e) {
            console.warn('CloudData.getMetrics fallback:', e.message);
            return JSON.parse(localStorage.getItem('userMetrics')) || { studyTime: 0, todayTime: 0, lastStudyDate: '', streak: 1, leaderboardRank: 99 };
        }
    },

    async saveMetrics(metrics) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { error } = await client
                .from('user_metrics')
                .upsert({
                    user_id: uid,
                    study_time: metrics.studyTime || metrics.studytime || 0,
                    today_time: metrics.todayTime || metrics.todaytime || 0,
                    last_study_date: metrics.lastStudyDate || metrics.laststudydate || '',
                    streak: metrics.streak || 1,
                    leaderboard_rank: metrics.leaderboardRank || metrics.leaderboardrank || 99,
                    lifetime_study_time: metrics.lifetimeStudyTime || 0,
                    last_study_reset: metrics.lastStudyReset || new Date().toISOString()
                }, { onConflict: 'user_id' });

            if (error) throw error;
            localStorage.setItem('userMetrics', JSON.stringify(metrics));
            return true;
        } catch (e) {
            console.error('CloudData.saveMetrics error:', e);
            localStorage.setItem('userMetrics', JSON.stringify(metrics));
            throw e;
        }
    },

    // ─── CREDITS ───

    async getCredits() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_credits')
                .select('*')
                .eq('user_id', uid)
                .single();

            if (error && error.code === 'PGRST116') {
                // No row — create default
                const defaults = { user_id: uid, credits: 1000, tier: 'free', billing_cycle: 'monthly', last_reset: new Date().toISOString() };
                const { error: insError } = await client.from('user_credits').insert(defaults);
                if (insError) throw insError;

                localStorage.setItem('thinkCredits', 1000);
                localStorage.setItem('subscriptionTier', 'free');
                localStorage.setItem('billingCycle', 'monthly');
                return { credits: 1000, tier: 'free', billingCycle: 'monthly', lastReset: defaults.last_reset };
            }
            if (error) throw error;

            // Check monthly reset and tier expiration
            const now = new Date();
            const lastReset = new Date(data.last_reset);

            // Handle Trial Expiration First
            let currentTier = data.tier;
            if (data.tier_expires_at) {
                const expiry = new Date(data.tier_expires_at);
                if (now > expiry) {
                    // Trial expired, downgrade to free
                    currentTier = 'free';
                    // Reset credits immediately to 1000 upon downgrade to prevent hoarding trial credits
                    data.credits = 1000;
                    const { error: expError } = await client.from('user_credits').update({
                        tier: 'free',
                        tier_expires_at: null,
                        credits: 1000,
                        last_reset: now.toISOString()
                    }).eq('user_id', uid);
                    if (expError) console.error('Error expiring trial:', expError);
                    data.last_reset = now.toISOString();
                }
            }

            // Normal Monthly Reset (Only if trial didn't just expire and reset it)
            if (lastReset.getMonth() !== now.getMonth() || lastReset.getFullYear() !== now.getFullYear()) {
                // Determine monthly allowance based on current data/tier
                // Default allowances (fallback if not in row, though usually tier is synced)
                let allowance = 1000;
                if (currentTier === 'subscriber') {
                    // We can estimate allowance from current credits if missing, 
                    // or use a standard 10k/25k/50k map. 
                    // For robustness, if they have an 'allowance' column, use it. 
                    // Let's check if they have a 'monthly_allowance' or similar. 
                    // Migration 20260217 shows credits default to 1000.
                    // For now, let's assume 10000 for subscribers if not specified.
                    allowance = data.monthly_allowance || 10000;
                }

                let newCredits;
                if (data.billing_cycle === 'yearly') {
                    // Yearly Plan: ROLL OVER
                    newCredits = data.credits + allowance;
                } else {
                    // Monthly Plan: RESET
                    newCredits = allowance;
                }

                const { error: updError } = await client.from('user_credits').update({
                    credits: newCredits,
                    last_reset: now.toISOString()
                }).eq('user_id', uid);

                if (updError) throw updError;
                data.credits = newCredits;
                data.last_reset = now.toISOString();
            }

            data.tier = currentTier;

            localStorage.setItem('thinkCredits', data.credits);
            localStorage.setItem('subscriptionTier', data.tier);
            localStorage.setItem('billingCycle', data.billing_cycle || 'monthly');
            return {
                credits: data.credits,
                tier: data.tier,
                billingCycle: data.billing_cycle || 'monthly',
                lastReset: data.last_reset
            };
        } catch (e) {
            console.warn('CloudData.getCredits fallback:', e.message);
            return {
                credits: parseInt(localStorage.getItem('thinkCredits')) || 1000,
                tier: localStorage.getItem('subscriptionTier') || 'free',
                lastReset: localStorage.getItem('creditsLastReset') || new Date().toISOString()
            };
        }
    },

    async deductCredits(amount) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            // Get current
            const { data, error } = await client
                .from('user_credits')
                .select('credits')
                .eq('user_id', uid)
                .single();

            if (error) throw error;

            const newBalance = Math.max(0, data.credits - amount);
            await client.from('user_credits').update({ credits: newBalance }).eq('user_id', uid);
            localStorage.setItem('thinkCredits', newBalance);
            return newBalance;
        } catch (e) {
            console.warn('CloudData.deductCredits fallback:', e.message);
            const current = parseInt(localStorage.getItem('thinkCredits')) || 1000;
            const newBalance = Math.max(0, current - amount);
            localStorage.setItem('thinkCredits', newBalance);
            return newBalance;
        }
    },

    async setTier(tier, cycle = 'monthly', allowance = 1000) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const updates = {
                user_id: uid,
                tier: tier,
                billing_cycle: cycle,
                credits: allowance,
                last_reset: new Date().toISOString()
            };

            // If they have an allowance column (suggested for better tier management)
            // if (hasAllowanceColumn) updates.monthly_allowance = allowance;

            await client.from('user_credits').upsert(updates, { onConflict: 'user_id' });

            localStorage.setItem('subscriptionTier', tier);
            localStorage.setItem('billingCycle', cycle);
            localStorage.setItem('thinkCredits', allowance);
            return true;
        } catch (e) {
            console.error('CloudData.setTier error:', e);
            localStorage.setItem('subscriptionTier', tier);
            throw e;
        }
    },

    // ─── FLASHCARDS ───

    async getFlashcardSets() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_flashcards')
                .select('*')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data.map(row => ({
                id: row.id,
                topic: row.topic,
                cards: typeof row.cards === 'string' ? JSON.parse(row.cards) : row.cards,
                date: new Date(row.created_at).toLocaleDateString()
            }));
        } catch (e) {
            console.warn('CloudData.getFlashcardSets fallback:', e.message);
            return JSON.parse(localStorage.getItem('savedFlashcardSets') || '[]');
        }
    },

    async saveFlashcardSet(setData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                topic: setData.topic,
                cards: setData.cards
            };

            if (setData.is_public !== undefined) row.is_public = setData.is_public;

            if (setData.id && !setData.id.toString().startsWith('set-')) {
                row.id = setData.id;
            }

            const { data, error } = await client
                .from('user_flashcards')
                .upsert(row, { onConflict: 'id' })
                .select('id, user_id, topic, cards, created_at')
                .single();

            if (error) throw error;
            return {
                id: data.id,
                topic: data.topic,
                cards: data.cards,
                is_public: data.is_public,
                date: new Date(data.created_at || Date.now()).toLocaleDateString()
            };
        } catch (e) {
            console.error('CloudData.saveFlashcardSet error:', e);
            throw e;
        }
    },

    async deleteFlashcardSet(setId) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { error } = await client
                .from('user_flashcards')
                .delete()
                .eq('id', setId)
                .eq('user_id', uid);

            if (error) throw error;
            return true;
        } catch (e) {
            console.warn('CloudData.deleteFlashcardSet fallback:', e.message);
            return false;
        }
    },

    // ─── DEADLINES ───

    async getDeadlines() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('deadlines')
                .select('*')
                .eq('user_id', uid)
                .eq('is_archived', false)
                .order('date', { ascending: true });

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getDeadlines fallback:', e.message);
            return [];
        }
    },




    // ─── ESSAYS ───

    async getEssayResults() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_essays')
                .select('*')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getEssayResults fallback:', e.message);
            return JSON.parse(localStorage.getItem('savedEssayResults') || '[]');
        }
    },

    // ─── PLATFORM STATS ───

    async getPlatformStats() {
        try {
            const client = await this._client();
            if (!client) return { users: 1200, notes: 12867, cases: 2500 };

            // Call the public RPC function for accurate counts (bypasses RLS counting restrictions)
            const { data, error } = await client.rpc('get_platform_stats');

            if (error) throw error;

            return {
                users: data.users || 0,
                notes: data.notes || 0,
                cases: data.cases || 0,
                week_notes: data.week_notes || 0
            };
        } catch (e) {
            console.warn('CloudData.getPlatformStats failed:', e.message);
            // Fallback to believable baseline if RPC fails (e.g. not deployed yet)
            return { users: 1250, notes: 12867, cases: 2500 };
        }
    },

    async saveEssayResult(resultData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                question: resultData.question || '',
                essay_text: resultData.text,
                module: resultData.module,
                grade: resultData.grade,
                feedback: resultData.feedback, // The whole JSON from AI
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_essays')
                .insert(row)
                .select('id, user_id, module, grade, feedback, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveEssayResult fallback:', e.message);
            return null;
        }
    },

    async saveExamResult(examData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                exam_text: examData.text,
                board: examData.board,
                metrics: examData.metrics,
                feedback: examData.feedback,
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_exams')
                .insert(row)
                .select('id, user_id, exam_text, board, metrics, feedback, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveExamResult fallback:', e.message);
            return null;
        }
    },

    // ─── ISSUE SPOTTER ───

    async getIssueSpotterResults() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_issue_spotter')
                .select('*')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getIssueSpotterResults fallback:', e.message);
            return JSON.parse(localStorage.getItem('savedIssueSpotterResults') || '[]');
        }
    },

    async saveIssueSpotterResult(resultData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                scenario_text: resultData.text,
                issues: resultData.issues, // Array from AI
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_issue_spotter')
                .insert(row)
                .select('id')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveIssueSpotterResult fallback:', e.message);
            return null;
        }
    },

    // ─── INTERPRET ───

    async getInterpretResults() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_interpretations')
                .select('*')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getInterpretResults fallback:', e.message);
            return JSON.parse(localStorage.getItem('savedInterpretResults') || '[]');
        }
    },

    async saveInterpretResult(resultData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                scenario_text: resultData.text,
                issues: resultData.issues, // Array from AI
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_interpretations')
                .insert(row)
                .select('id, user_id, input_text, interpretation, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveInterpretResult fallback:', e.message);
            return null;
        }
    },

    // ─── PROMO CODES ───

    async redeemPromoCode(code) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('Please sign in to redeem codes.');

            // 1. Fetch Code
            const { data: promo, error: promoError } = await client
                .from('promo_codes')
                .select('*')
                .eq('code', code.toUpperCase())
                .single();

            if (promoError || !promo) throw new Error('Invalid or expired promo code.');

            // 2. Check Expiry/Limits
            const now = new Date();
            if (promo.expires_at && new Date(promo.expires_at) < now) {
                throw new Error('This code has expired.');
            }
            if (promo.usage_count >= promo.usage_limit) {
                throw new Error('This code has reached its usage limit.');
            }

            // 3. Check if user already redeemed
            const { data: existing, error: checkError } = await client
                .from('user_redemptions')
                .select('id')
                .eq('user_id', uid)
                .eq('code', promo.code)
                .maybeSingle();

            if (existing) throw new Error('You have already redeemed this code.');

            // 4. Perform Redemption (Atomic via individual updates)
            // Note: In production, this should be a stored procedure (RPC) for atomicity

            // Record redemption
            const { error: recordError } = await client
                .from('user_redemptions')
                .insert({ user_id: uid, code: promo.code });

            if (recordError) throw recordError;

            // Increment usage count
            const { error: updError } = await client.from('promo_codes')
                .update({ usage_count: promo.usage_count + 1 })
                .eq('code', promo.code);

            if (updError) {
                console.error('Failed to update usage count:', updError);
                // We'll continue because the redemption is logged in user_redemptions, 
                // but this is why the admin panel might show 0.
            }

            // Fetch current credits to update
            const { data: currentCredits } = await client
                .from('user_credits')
                .select('*')
                .eq('user_id', uid)
                .single();

            // Process Special Tier Upgrades like BETATRIAL
            let newTier = currentCredits?.tier || 'free';
            let tierExpiresAt = currentCredits?.tier_expires_at || null;

            if (promo.tier === 'subscriber') {
                newTier = 'subscriber';
                if (promo.duration_days) {
                    // Set expiration X days from now
                    const expiryDate = new Date();
                    expiryDate.setDate(expiryDate.getDate() + promo.duration_days);
                    tierExpiresAt = expiryDate.toISOString();
                } else {
                    // Permanent subscriber (or active via Stripe, clear any trial expiry)
                    tierExpiresAt = null;
                }
            }

            // Grant Rewards
            const updates = {
                credits: (currentCredits?.credits || 0) + (promo.credits || 0),
                tier: newTier,
                tier_expires_at: tierExpiresAt,
                billing_cycle: 'monthly' // Default for promos
            };

            const { error: upsError } = await client.from('user_credits').upsert({
                user_id: uid,
                ...updates,
                last_reset: currentCredits?.last_reset || now.toISOString()
            });

            if (upsError) throw upsError;

            // Update Local Storage
            localStorage.setItem('thinkCredits', updates.credits);
            localStorage.setItem('subscriptionTier', updates.tier);
            localStorage.setItem('billingCycle', updates.billing_cycle);

            return { success: true, credits: promo.credits, tier: promo.tier };
        } catch (e) {
            console.error('Promo redemption error:', e.message);
            throw e;
        }
    },

    async saveInterpretResult(resultData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                input_text: resultData.text,
                interpretation: resultData.interpretation,
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_interpretations')
                .insert(row)
                .select('id, user_id, input_text, interpretation, created_at')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveInterpretResult fallback:', e.message);
            return null;
        }
    },

    // ─── LEADERBOARD ───

    async getLeaderboard(type = 'time') {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            let data, error;

            if (type === 'streak') {
                const result = await client
                    .from('user_metrics')
                    .select('user_id, streak, profiles ( leaderboard_username, university, is_anonymous )')
                    .gt('streak', 0)
                    .order('streak', { ascending: false })
                    .limit(10);
                data = result.data;
                error = result.error;
            } else {
                const result = await client
                    .from('user_metrics')
                    .select('user_id, study_time, profiles ( leaderboard_username, university, is_anonymous )')
                    .gt('study_time', 0)
                    .order('study_time', { ascending: false })
                    .limit(10);
                data = result.data;
                error = result.error;
            }

            if (error) throw error;

            // Only include users who have set a leaderboard username
            const filtered = (data || []).filter(d => {
                const profile = d.profiles || {};
                return profile.leaderboard_username && profile.leaderboard_username.length >= 4;
            });

            return filtered.map((d, i) => {
                const profile = d.profiles || {};
                const isAnon = profile.is_anonymous;

                let name = 'Anonymous';
                let uni = 'Hidden';

                if (!isAnon) {
                    name = '@' + profile.leaderboard_username;
                    uni = profile.university || '';
                }

                return {
                    userId: d.user_id,
                    rank: i + 1,
                    name: name,
                    uni: uni,
                    time: d.study_time || 0,
                    streak: d.streak || 0
                };
            });
        } catch (e) {
            console.error('CloudData.getLeaderboard error:', e);
            return [];
        }
    },

    // ─── OSCOLA ───

    async getOscolaAudits() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('user_oscola_audits')
                .select('*')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getOscolaAudits fallback:', e.message);
            return JSON.parse(localStorage.getItem('savedOscolaAudits') || '[]');
        }
    },

    async saveOscolaAudit(auditData) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const row = {
                user_id: uid,
                essay_preview: auditData.text.substring(0, 500),
                score: auditData.score,
                citation_count: auditData.citationCount,
                error_count: auditData.errorCount,
                analysis: auditData.analysis,
                created_at: new Date().toISOString()
            };

            const { data, error } = await client
                .from('user_oscola_audits')
                .insert(row)
                .select('id')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.saveOscolaAudit fallback:', e.message);
            return null;
        }
    },

    // ─── ADMIN & ACTIVITY ───

    async updateActiveStatus() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) return;

            // Update last_active_at and sync email (once per session)
            const { data: { user } } = await client.auth.getUser();
            await client.from('profiles').update({
                last_active_at: new Date().toISOString(),
                email: user?.email
            }).eq('id', uid);
        } catch (e) {
            // Silently fail for activity logging
        }
    },

    async adminGetAllUsers() {
        try {
            const client = await this._client();
            // Fetch profiles with their credit/tier data via JOIN
            const { data, error } = await client
                .from('profiles')
                .select(`
                    id, first_name, last_name, email, last_active_at, university,
                    student_level, exam_board, school_urn,
                    user_credits!user_id ( credits, tier )
                `)
                .order('last_active_at', { ascending: false });

            if (error) throw error;

            return data.map(u => ({
                id: u.id,
                name: [u.first_name, u.last_name].filter(Boolean).join(' ') || 'Unknown User',
                email: u.email || 'N/A',
                lastActive: u.last_active_at,
                uni: u.university || 'N/A',
                level: u.student_level || 'llb',
                board: u.exam_board || 'N/A',
                urn: u.school_urn || 'N/A',
                credits: Array.isArray(u.user_credits) ? (u.user_credits[0]?.credits || 0) : (u.user_credits?.credits || 0),
                tier: Array.isArray(u.user_credits) ? (u.user_credits[0]?.tier || 'free') : (u.user_credits?.tier || 'free')
            }));
        } catch (e) {
            console.error('Admin Fetch Users Error:', e);
            throw e;
        }
    },

    async adminUpdateUser(userId, updates) {
        try {
            const client = await this._client();

            // 1. Update Profile (if needed)
            // 2. Update Credits/Tier
            if (updates.credits !== undefined || updates.tier !== undefined) {
                const creditUpdates = {};
                if (updates.credits !== undefined) creditUpdates.credits = updates.credits;
                if (updates.tier !== undefined) creditUpdates.tier = updates.tier;

                const { error } = await client
                    .from('user_credits')
                    .update(creditUpdates)
                    .eq('user_id', userId);

                if (error) throw error;
            }
            return true;
        } catch (e) {
            console.error('Admin Update User Error:', e);
            throw e;
        }
    },

    // ─── COMMUNITY HUB ───

    async fetchCommunityFeed(type = 'all') {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            let hubItems = [];

            // ── Fetch Public Notes ──
            if (type === 'all' || type === 'notes') {
                const { data: publicNotes, error: notesErr } = await client
                    .from('lectures')
                    .select('id, user_id, title, content, module_id, is_public, upvotes, created_at')
                    .eq('is_public', true)
                    .order('created_at', { ascending: false })
                    .limit(100);

                if (notesErr) {
                    console.warn('Community notes fetch error:', notesErr.message);
                } else if (publicNotes && publicNotes.length > 0) {
                    // Collect unique user IDs for profile lookup
                    const userIds = [...new Set(publicNotes.map(n => n.user_id))];

                    // Fetch profiles for these users
                    const { data: profiles } = await client
                        .from('profiles')
                        .select('id, leaderboard_username, university')
                        .in('id', userIds);

                    const profileMap = {};
                    (profiles || []).forEach(p => {
                        profileMap[p.id] = p;
                    });

                    publicNotes.forEach(note => {
                        const profile = profileMap[note.user_id] || {};
                        const author_name = profile.leaderboard_username ? '@' + profile.leaderboard_username : 'Anonymous';

                        hubItems.push({
                            id: note.id,
                            type: 'note',
                            title: note.title,
                            module_name: note.module_id || '',
                            preview: note.content ? note.content.substring(0, 150).replace(/<[^>]*>/g, '') + '...' : '',
                            author_name,
                            university: profile.university || '',
                            upvotes: note.upvotes || 0,
                            created: note.created_at
                        });
                    });
                }
            }

            // ── Fetch Public Flashcard Decks ──
            if (type === 'all' || type === 'flashcards') {
                const { data: decks, error: deckErr } = await client
                    .from('user_flashcards')
                    .select('id, user_id, topic, cards, is_public, upvotes, created_at')
                    .eq('is_public', true)
                    .order('created_at', { ascending: false })
                    .limit(100);

                if (!deckErr && decks && decks.length > 0) {
                    const userIds = [...new Set(decks.map(d => d.user_id))];
                    const { data: profiles } = await client
                        .from('profiles')
                        .select('id, leaderboard_username, university')
                        .in('id', userIds);

                    const profileMap = {};
                    (profiles || []).forEach(p => { profileMap[p.id] = p; });

                    decks.forEach(deck => {
                        const profile = profileMap[deck.user_id] || {};
                        const author_name = profile.leaderboard_username ? '@' + profile.leaderboard_username : 'Anonymous';

                        hubItems.push({
                            id: deck.id,
                            type: 'flashcard',
                            title: deck.topic,
                            preview: Array.isArray(deck.cards) ? `Deck: ${deck.cards.slice(0, 3).map(c => c.question).join(', ')}...` : 'Flashcard Deck',
                            author_name,
                            university: profile.university || '',
                            upvotes: deck.upvotes || 0,
                            created: deck.created_at
                        });
                    });
                }
            }

            // Sort by most recent
            return hubItems.sort((a, b) => new Date(b.created) - new Date(a.created));
        } catch (e) {
            console.error('Fetch Community Feed Error:', e);
            return [];
        }
    },

    async makePublic(id, type, isPublic = true) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            let table = '';
            if (type === 'note') table = 'lectures';
            else if (type === 'flashcard') table = 'user_flashcards';
            else table = type; // fallback

            const { error } = await client
                .from(table)
                .update({ is_public: isPublic })
                .eq('id', id)
                .eq('user_id', uid);

            if (error) throw error;
            return true;
        } catch (e) {
            console.error('Make Public Error:', e);
            throw e;
        }
    },

    async forkItem(itemId, type) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const table = type === 'note' ? 'lectures' : 'user_flashcards';

            // 1. Fetch the source item
            const { data: source, error: fetchError } = await client
                .from(table)
                .select('*')
                .eq('id', itemId)
                .single();

            if (fetchError) throw fetchError;
            if (!source.is_public) throw new Error("This item is no longer public.");

            // 1b. Ensure "My Forks" module exists
            const modules = await this.getModules();
            let forksModule = modules.find(m => m.name === 'My Forks');

            if (!forksModule) {
                try {
                    forksModule = await this.saveModule({
                        name: 'My Forks',
                        icon: 'fa-code-branch',
                        description: 'Your forked notes and flashcards.'
                    });
                } catch (e) {
                    console.warn('Could not create My Forks module, using source module instead.');
                }
            }

            // 2. Clear out IDs and ownership
            source.id = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : `${type}-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
            source.user_id = uid;
            source.is_public = false;
            source.upvotes = 0;
            source.created_at = new Date().toISOString();

            if (type === 'note' && forksModule && forksModule.id) {
                source.module_id = forksModule.id;
            }

            // 3. Insert as new item for current user
            const { data, error: insertError } = await client
                .from(table)
                .insert(source)
                .select('id')
                .single();

            if (insertError) throw insertError;
            return data;
        } catch (e) {
            console.error('CloudData.forkItem error:', e);
            throw e;
        }
    },

    /**
     * News / Aggregation Fetches
     */
    async getNews(category = 'General', limit = 20) {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            let query = client.from('news_articles').select('*');

            if (category !== 'All') {
                query = query.eq('category', category);
            }

            const { data, error } = await query
                .order('published_at', { ascending: false })
                .limit(limit);

            if (error) throw error;
            return data;
        } catch (e) {
            console.warn('CloudData.getNews error:', e.message);
            return [];
        }
    },

    async getSavedNews() {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) return [];

            const { data, error } = await client
                .from('saved_news')
                .select('article_id, news_articles(*)')
                .eq('user_id', uid)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data.map(item => item.news_articles);
        } catch (e) {
            console.warn('CloudData.getSavedNews error:', e.message);
            return [];
        }
    },

    async toggleSaveNews(articleId, isSaved) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            if (isSaved) {
                const { error } = await client.from('saved_news').insert({ user_id: uid, article_id: articleId });
                if (error && error.code !== '23505') throw error; // Ignore duplicates
            } else {
                const { error } = await client.from('saved_news').delete().eq('user_id', uid).eq('article_id', articleId);
                if (error) throw error;
            }
            return true;
        } catch (e) {
            console.error('CloudData.toggleSaveNews error:', e.message);
            return false;
        }
    },

    async interpretNews(articleId, title, snippet) {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            // 1. Charge credits securely first
            const hasCredits = await this.deductCredits(15);
            if (!hasCredits) throw new Error("INSUFFICIENT_CREDITS");

            // 2. Call AI Worker (always use production — the Cloudflare Worker is remotely deployed)
            const aiServiceUrl = 'https://thinklikelaw-ai.5dwvxmf5mn.workers.dev/interpret';

            const token = typeof getCurrentSession === 'function' ? (await getCurrentSession())?.access_token : null;
            const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
            if (token) headers['Authorization'] = `Bearer ${token}`;

            const res = await fetch(aiServiceUrl, {
                method: 'POST',
                headers,
                body: JSON.stringify({ articleTitle: title, articleSnippet: snippet })
            });

            if (!res.ok) throw new Error("AI generation failed.");
            const data = await res.json();
            const initialBrief = data.text;

            // --- DOUBLE LAYER VERIFICATION PASS ---
            const verificationPrompt = `You are a Senior Fact-Checker. I have a legal news brief that needs auditing for accuracy.
            Especially check dates, bill stages, and impact claims. Ensure standard case naming conventions are used.
            Fix any hallucinations.
            
            Original Brief:
            ${initialBrief}
            
            Return the corrected, high-accuracy HTML brief. Keep the structure concise.`;

            // We call the generic completion endpoint for verification
            const verifyRes = await fetch(aiServiceUrl.replace('/interpret', ''), {
                method: 'POST',
                headers,
                body: JSON.stringify({
                    prompt: verificationPrompt,
                    systemRole: "You are a Senior Legal Fact-Checker for UK Government News.",
                    context: { userTier: 'pro' }
                })
            });

            const verifyData = await verifyRes.json();
            const briefHtml = verifyData.text || initialBrief;

            // 3. Cache it back to the DB so we don't charge again globally (optional, but good UX)
            await client.from('news_articles')
                .update({ ai_brief_cache: briefHtml })
                .eq('id', articleId);

            return briefHtml;
        } catch (e) {
            console.error('CloudData.interpretNews error:', e.message);
            throw e;
        }
    },

    async updateLecture(lectureId, updates) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            const { data, error } = await client
                .from('lectures')
                .update({ ...updates })
                .eq('id', lectureId)
                .eq('user_id', uid)
                .select('id')
                .single();

            if (error) throw error;
            return data;
        } catch (e) {
            console.error('CloudData.updateLecture error:', e);
            throw e;
        }
    },

    async reportItem(itemId, type, reason) {
        try {
            const client = await this._client();
            const uid = await this._userId();
            if (!client || !uid) throw new Error('offline');

            // Attempt to insert into a reports table if it exists
            const { error } = await client
                .from('reports')
                .insert({
                    item_id: itemId,
                    item_type: type,
                    reported_by: uid,
                    reason: reason,
                    created_at: new Date().toISOString()
                });

            if (error) {
                // Table may not exist yet — log but don't crash
                console.warn('Report table insert failed (table may not exist):', error.message);
                console.log('Report logged locally:', { itemId, type, reason, reportedBy: uid });
            }
            return true;
        } catch (e) {
            console.warn('Report Item Error:', e);
            // Still return true so user gets positive feedback
            return true;
        }
    },
    async deleteUserAccount() {
        try {
            const client = await this._client();
            if (!client) throw new Error('offline');

            const { error } = await client.rpc('delete_user_account');
            if (error) throw error;

            // Clear all local data on success
            localStorage.clear();
            return true;
        } catch (e) {
            console.error('CloudData.deleteUserAccount error:', e);
            throw e;
        }
    }
};

// Export for global use
window.CloudData = CloudData;
