'use strict';
(() => {
    const ui = window.AccessoryUI;
    const root = document.getElementById('accessories');
    const tooltip = document.getElementById('tooltip');
    const feedback = document.getElementById('feedback');
    const buttons = [...root.querySelectorAll('button')];
    let labels = {}, states = {}, busy = false, session = 0, hovered, feedbackTimer;

    function describe(button) {
        if (!button || root.hidden) { tooltip.hidden = true; return; }
        const id = button.dataset.action;
        const state = states[id];
        document.getElementById('tooltip-label').textContent = labels[id] || id;
        document.getElementById('tooltip-state').textContent = state
            ? (!state.available ? labels.unavailable : labels[state.active ? 'equip' : 'remove'])
            : '';
        tooltip.hidden = false;
    }

    function update(next) {
        states = next || {};
        for (const button of buttons) {
            const id = button.dataset.action;
            button.setAttribute('aria-label', labels[id] || id);
            button.setAttribute('aria-describedby', 'tooltip');
            if (states[id]) {
                button.setAttribute('aria-pressed', String(states[id].active === true));
                button.setAttribute('aria-disabled', String(states[id].available !== true));
            }
        }
        describe(hovered || (document.activeElement?.matches('button') ? document.activeElement : null));
    }

    function hide() {
        session++;
        root.hidden = true;
        busy = false;
        root.removeAttribute('aria-busy');
        tooltip.hidden = feedback.hidden = true;
        hovered = null;
        clearTimeout(feedbackTimer);
        document.activeElement?.blur();
    }

    function show(data) {
        session++;
        busy = false;
        root.removeAttribute('aria-busy');
        labels = data.labels || {};
        root.setAttribute('aria-label', labels.title || 'Accessories');
        document.documentElement.lang = data.locale || 'en';
        root.hidden = false;
        update(data.states);
    }

    function showError(message) {
        feedback.textContent = message;
        feedback.hidden = false;
        clearTimeout(feedbackTimer);
        feedbackTimer = setTimeout(() => { feedback.hidden = true; }, 3500);
    }

    async function close() {
        const currentSession = session;
        try {
            const response = await ui.request('close');
            if (response.ok && currentSession === session) hide();
        } catch { if (currentSession === session) showError(labels.disconnected); }
    }

    for (const button of buttons) {
        button.addEventListener('pointerenter', () => { hovered = button; describe(button); });
        button.addEventListener('pointerleave', () => { hovered = null; tooltip.hidden = true; });
        button.addEventListener('focus', () => describe(button));
        button.addEventListener('blur', () => { if (!hovered) tooltip.hidden = true; });
        button.addEventListener('click', async () => {
            if (busy || root.hidden || button.getAttribute('aria-disabled') === 'true') return;
            busy = true;
            root.setAttribute('aria-busy', 'true');
            const currentSession = session;
            try {
                const response = await ui.request('accessoryAction', { id: button.dataset.action });
                if (currentSession !== session) return;
                if (response.ok) update(response.data?.states);
                else showError(response.error || labels.disconnected);
            } catch { if (currentSession === session) showError(labels.disconnected); }
            finally {
                if (currentSession === session) { busy = false; root.removeAttribute('aria-busy'); }
            }
        });
    }

    document.addEventListener('keydown', event => {
        if (root.hidden) return;
        if (event.key === 'Escape') { event.preventDefault(); close(); return; }
        if (!['Tab', 'ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp', 'Home', 'End'].includes(event.key)) return;
        event.preventDefault();
        const current = buttons.indexOf(document.activeElement);
        const backwards = event.shiftKey || ['ArrowLeft', 'ArrowUp'].includes(event.key);
        const index = event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length - 1
            : current < 0 ? 0 : (current + (backwards ? -1 : 1) + buttons.length) % buttons.length;
        buttons[index].focus({ preventScroll: true });
    });
    root.addEventListener('click', event => { if (event.target === root) close(); });
    window.addEventListener('message', event => {
        const message = event.data;
        if (!message || typeof message !== 'object') return;
        if (message.action === 'accessories:open' && message.data) show(message.data);
        else if (message.action === 'accessories:close') hide();
        else if (message.action === 'accessories:state' && !root.hidden) update(message.data?.states);
    });
    ui.request('ready').catch(() => {});
    if (ui.preview) { document.body.classList.add('preview'); show(ui.demo); }
})();
