/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2022-2026 ESX Framework
 *
 * Browser mock for testing esx_animations NUI outside of FiveM.
 * Include this BEFORE app.js in a test HTML file.
 *
 * Usage: Start a local server (e.g., `npx serve html`) and visit
 *        http://localhost:3000/test/index.html
 */
window.GetParentResourceName = function() { return 'esx_animations' };

const mockCategories = [
    {
        name: 'festives',
        label: 'Festives',
        items: [
            { name: 'Smoking', label: 'Smoking', type: 'scenario', anim: 'WORLD_HUMAN_SMOKING', icon: 'PlaySquare' },
            { name: 'Playing', label: 'Playing an instrument', type: 'anim', lib: 'anim@mp_player_intcelebrationmale@dj', anim: 'dj', icon: 'Play' },
            { name: 'Drinking', label: 'Drinking', type: 'scenario', anim: 'WORLD_HUMAN_DRINKING', icon: 'PlaySquare' },
            { name: 'Party', label: 'Partying', type: 'scenario', anim: 'WORLD_HUMAN_PARTYING', icon: 'PlaySquare' },
            { name: 'Air Guitar', label: 'Playing air guitar', type: 'anim', lib: 'anim@mp_player_intcelebrationmale@air_guitar', anim: 'air_guitar', icon: 'Play' }
        ]
    },
    {
        name: 'greetings',
        label: 'Greetings',
        items: [
            { name: 'Hello', label: 'Hello', type: 'anim', lib: 'gestures@m@standing@casual', anim: 'gesture_hello', icon: 'Play' },
            { name: 'Handshake', label: 'Handshake', type: 'anim', lib: 'mp_common', anim: 'givetake1_a', icon: 'Play' },
            { name: 'Handshaking', label: 'Handshaking', type: 'anim', lib: 'mp_ped_interaction', anim: 'handshake_guy_a', icon: 'Play' },
            { name: 'Hug', label: 'Hug', type: 'anim', lib: 'mp_ped_interaction', anim: 'hugs_guy_a', icon: 'Play' },
            { name: 'Salute', label: 'Salute', type: 'anim', lib: 'mp_player_int_uppersalute', anim: 'mp_player_int_salute', icon: 'Play' }
        ]
    },
    {
        name: 'work',
        label: 'Job',
        items: [
            { name: 'Fishing', label: 'Fishing', type: 'scenario', anim: 'world_human_stand_fishing', icon: 'PlaySquare' },
            { name: 'Police', label: 'Police: Investigate', type: 'anim', lib: 'amb@code_human_police_investigate@idle_b', anim: 'idle_f', icon: 'Play' },
            { name: 'Radio', label: 'Police: Radio chatter', type: 'anim', lib: 'random@arrests', anim: 'generic_radio_chatter', icon: 'Play' }
        ]
    },
    {
        name: 'humors',
        label: 'Fun',
        items: [
            { name: 'Cheering', label: 'Cheering', type: 'scenario', anim: 'WORLD_HUMAN_CHEERING', icon: 'PlaySquare' },
            { name: 'Point', label: 'Pointing finger', type: 'anim', lib: 'gestures@m@standing@casual', anim: 'gesture_point', icon: 'Play' },
            { name: 'Facepalm', label: 'Facepalm', type: 'anim', lib: 'anim@mp_player_intcelebrationmale@face_palm', anim: 'face_palm', icon: 'Play' }
        ]
    },
    {
        name: 'sports',
        label: 'Sports',
        items: [
            { name: 'Flex', label: 'Show muscles', type: 'anim', lib: 'amb@world_human_muscle_flex@arms_at_side@base', anim: 'base', icon: 'Play' },
            { name: 'Lift', label: 'Weight lifting', type: 'anim', lib: 'amb@world_human_muscle_free_weights@male@barbell@base', anim: 'base', icon: 'Play' },
            { name: 'Pushups', label: 'Push ups', type: 'anim', lib: 'amb@world_human_push_ups@male@base', anim: 'base', icon: 'Play' }
        ]
    },
    {
        name: 'misc',
        label: 'Divers',
        items: [
            { name: 'Coffee', label: 'Drinking coffee', type: 'anim', lib: 'amb@world_human_aa_coffee@idle_a', anim: 'idle_a', icon: 'Play' },
            { name: 'Lean', label: 'Leaning on wall', type: 'scenario', anim: 'world_human_leaning', icon: 'PlaySquare' },
            { name: 'Sunbathe', label: 'Sun bathing', type: 'scenario', anim: 'WORLD_HUMAN_SUNBATHE', icon: 'PlaySquare' }
        ]
    },
    {
        name: 'attitudem',
        label: 'Walking Styles',
        items: [
            { name: 'Confident', label: 'Confident', type: 'attitude', lib: 'move_m@confident', anim: 'move_m@confident', icon: 'PersonStanding' },
            { name: 'Business', label: 'Business', type: 'attitude', lib: 'move_m@business@a', anim: 'move_m@business@a', icon: 'PersonStanding' },
            { name: 'Brave', label: 'Brave', type: 'attitude', lib: 'move_m@brave@a', anim: 'move_m@brave@a', icon: 'PersonStanding' },
            { name: 'Casual', label: 'Casual', type: 'attitude', lib: 'move_m@casual@a', anim: 'move_m@casual@a', icon: 'PersonStanding' },
            { name: 'Hurry', label: 'Hurry', type: 'attitude', lib: 'move_m@hurry@a', anim: 'move_m@hurry@a', icon: 'PersonStanding' }
        ]
    },
    {
        name: 'porn',
        label: 'NSFW',
        items: [
            { name: 'Stripper', label: 'Stripping', type: 'anim', lib: 'mini@strip_club@lap_dance@ld_girl_a_song_a_p1', anim: 'ld_girl_a_song_a_p1_f', icon: 'Play' }
        ]
    }
];

const mockLocale = {
    language: 'en',
    title: 'Animations',
    subtitle: 'Choose an animation',
    categoryPlaceholder: 'Select a category',
    search: 'Search animations',
    searchPlaceholder: 'Search animations',
    noResults: 'No matching animations.',
    close: 'Close',
    stop: 'Stop Animation',
    idle: 'Select an animation',
    playing: 'Playing',
    requestFailed: 'Action failed. Please try again.'
};

const mockTheme = {
    primaryColor: '#FB9B04',
    secondaryColor: '#252525',
    backgroundColor: '#161616',
    accentColor: '#383838'
};

window.AnimationsTest = {
    _handlers: {},

    on(event, handler) {
        this._handlers[event] = this._handlers[event] || [];
        this._handlers[event].push(handler);
    },

    emit(event, data) {
        (this._handlers[event] || []).forEach(fn => fn(data));
    },

    sendOpen() {
        window.postMessage({
            source: 'AnimationsTest',
            data: {
                action: 'open',
                categories: mockCategories,
                locale: mockLocale,
                theme: mockTheme
            }
        }, '*');
    },

    sendClose() {
        window.postMessage({
            source: 'AnimationsTest',
            data: { action: 'close' }
        }, '*');
    },

    sendState(playing, activeItem, currentCategory) {
        window.postMessage({
            source: 'AnimationsTest',
            data: {
                action: 'state',
                playing: playing,
                activeItem: activeItem,
                currentCategory: currentCategory
            }
        }, '*');
    }
};

// Intercept fetch calls to simulate NUICallback responses
window.originalFetch = window.fetch;
window.fetch = function(url, options) {
    const urlStr = String(url);

    if (urlStr.includes('esx_animations/')) {
        const action = urlStr.split('/').pop();
        return Promise.resolve({
            ok: true,
            json: async () => {
                if (action === 'ready') return { theme: mockTheme };
                if (action === 'play') return { ok: true, data: null };
                if (action === 'stop') return { ok: true, data: null };
                if (action === 'category') return { ok: true, data: null };
                if (action === 'close') return { ok: true, data: null };
                return { ok: true, data: null };
            }
        });
    }

    return window.originalFetch(url, options);
};

// Bridge window.postMessage (from AnimationsTest) to the message event listener in app.js
window.addEventListener('message', (event) => {
    // Only forward messages from our test harness
    if (event.data && event.data.source === 'AnimationsTest') {
        // The app.js listens for { data: { action: ... } }
        // window.postMessage sends event.data = { source, data }
        // We need to forward just the data payload
        window.dispatchEvent(new MessageEvent('message', {
            data: event.data.data
        }));
        event.stopPropagation();
    }
});

// Auto-open the UI after scripts load
setTimeout(() => {
    if (window.AnimationsTest) {
        AnimationsTest.sendOpen();
    }
}, 300);
