/**
 * AudioManager.js
 * Central hub for handling SFX and Ambient Focus Music.
 * Supports category-based volume and opt-in toggles.
 */

const AudioManager = {
    settings: {
        masterEnabled: false,
        mascotEnabled: true,
        typingEnabled: false,
        musicEnabled: false,
        sfxVolume: 0.5,
        musicVolume: 0.2
    },

    assets: {
        sfx: {
            meow: 'https://www.myinstants.com/media/sounds/cat-meow.mp3', // Cute, realistic meow
            purr: 'https://www.myinstants.com/media/sounds/cat-purr.mp3', // Placeholder: Purr
            typing: [
                'https://www.myinstants.com/media/sounds/keyboard-typing.mp3', // Fallbacks
                'https://www.myinstants.com/media/sounds/mech-keyboard-1.mp3',
                'https://www.myinstants.com/media/sounds/typewriter-key-1.mp3'
            ],
            reveal: 'https://www.myinstants.com/media/sounds/choir-ahhh.mp3', // Heavenly reveal choir
            tick: 'https://www.myinstants.com/media/sounds/mouse-click.mp3', // UI tick
            thump: 'https://www.myinstants.com/media/sounds/drum-hit.mp3', // UI thump
            pop: 'https://www.myinstants.com/media/sounds/pop-sound-effect.mp3', // Bubble pop
            swell: 'https://www.myinstants.com/media/sounds/deep-whoosh.mp3', // Deep work ambient swell
            success: 'https://www.myinstants.com/media/sounds/success-bell.mp3' // Success sound
        },
        ambient: {
            lofi: 'https://stream.zeno.fm/0r0xa792kwzuv', // Example: Lofi Radio Stream or loop
            brown: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3', // Placeholder: Brown Noise
            rain: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3' // Placeholder: Rain
        }
    },

    activeAmbient: null,

    init() {
        this.loadSettings();

        // Setup global UI Micro-interactions
        document.addEventListener('mouseover', (e) => {
            if (!this.settings.masterEnabled) return;
            const target = e.target.closest('button, a, .clickable, .slash-item, .pill-btn, .nav-item');
            if (target) {
                if (!target.dataset.hovered) {
                    target.dataset.hovered = 'true';
                    this.playSFX('tick', false, { volume: 0.1, pitchVariance: 0.2 });

                    target.addEventListener('mouseleave', () => {
                        target.dataset.hovered = '';
                    }, { once: true });
                }
            }
        });

        document.addEventListener('mousedown', (e) => {
            if (!this.settings.masterEnabled) return;
            if (e.target.closest('button, a, .clickable, .slash-item, .pill-btn, .nav-item')) {
                this.playSFX('thump', false, { volume: 0.2, pitchVariance: 0.1 });
            }
        });
    },

    loadSettings() {
        const saved = localStorage.getItem('tll_audio_settings');
        if (saved) {
            this.settings = { ...this.settings, ...JSON.parse(saved) };
        }
    },

    saveSettings() {
        localStorage.setItem('tll_audio_settings', JSON.stringify(this.settings));
    },

    playSFX(id, force = false, options = {}) {
        if (!this.settings.masterEnabled && !force) return;

        // Specific category checks
        if (id === 'meow' || id === 'purr') {
            if (!this.settings.mascotEnabled) return;
        }
        if (id === 'typing') {
            if (!this.settings.typingEnabled) return;
        }

        let url = this.assets.sfx[id];
        // Handle randomizer arrays
        if (Array.isArray(url)) {
            url = url[Math.floor(Math.random() * url.length)];
        }
        if (!url) return;

        const audio = new Audio(url);
        // Apply volume (override via options if provided)
        audio.volume = options.volume !== undefined ? options.volume : this.settings.sfxVolume;

        // Apply pitch variance if requested (great for mechanical keyboards)
        if (options.pitchVariance) {
            audio.playbackRate = 1.0 + (Math.random() * options.pitchVariance - (options.pitchVariance / 2));
            audio.preservesPitch = false;
        }

        audio.play().catch(e => console.warn('Audio play blocked:', e));
    },

    startAmbient(id) {
        // Forcefully enable music if user specifically clicks a track
        this.settings.masterEnabled = true;
        this.settings.musicEnabled = true;

        this.stopAmbient();

        const url = this.assets.ambient[id];
        if (!url) return;

        this.activeAmbient = new Audio(url);
        this.activeAmbient.loop = true;
        this.activeAmbient.volume = this.settings.musicVolume;
        this.activeAmbient.play().catch(e => console.warn('Ambient play blocked:', e));
    },

    stopAmbient() {
        if (this.activeAmbient) {
            this.activeAmbient.pause();
            this.activeAmbient = null;
        }
    },

    updateSettings(newSettings) {
        this.settings = { ...this.settings, ...newSettings };
        this.saveSettings();

        // Adjust active ambient volume if playing
        if (this.activeAmbient) {
            this.activeAmbient.volume = this.settings.musicVolume;
            if (!this.settings.musicEnabled || !this.settings.masterEnabled) {
                this.stopAmbient();
            }
        }
    }
};

// Initialize
AudioManager.init();
window.AudioManager = AudioManager;
