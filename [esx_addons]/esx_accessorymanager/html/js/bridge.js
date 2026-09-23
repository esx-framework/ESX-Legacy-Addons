'use strict';
(() => {
    const ui = window.AccessoryUI;
    const inGame = typeof GetParentResourceName === 'function';

    ui.preview = !inGame && new URLSearchParams(location.search).get('preview') === '1';

    ui.request = async (endpoint, data = {}) => {
        if (!inGame) {
            if (!ui.preview) return { ok: false };
            if (endpoint === 'accessoryAction') {
                await new Promise(resolve => setTimeout(resolve, 80));
                if (data.id === 'reset') Object.values(ui.demo.states).forEach(state => { state.active = false; });
                else if (ui.demo.states[data.id]?.available) ui.demo.states[data.id].active = !ui.demo.states[data.id].active;
                return { ok: true, data: { states: structuredClone(ui.demo.states) } };
            }
            return { ok: true };
        }

        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 5000);

        try {
            const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
                method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data), signal: controller.signal
            });

            if (!response.ok) throw new Error('NUI request failed');
            
            return await response.json();
        } finally { clearTimeout(timeout); }
    };

    ui.demo = {
        locale: 'en',
        labels: {
            title: 'Accessories', watches: 'Watch', glasses: 'Glasses', mask: 'Mask', chain: 'Necklace',
            ears: 'Earrings', pants: 'Pants', shoes: 'Shoes', torso: 'Top', helmet: 'Hat', bags: 'Bag',
            tshirt: 'T-shirt', bracelets: 'Bracelet', bproof: 'Vest', reset: 'Restore outfit',
            repairProps: 'Fix accessories', repairHair: 'Fix hair', equip: 'Put on', remove: 'Take off',
            unavailable: 'No accessory available',
            disconnected: 'The game did not respond. Try again.'
        },
        states: Object.assign(
            Object.fromEntries(ui.catalog.map(item => [item.id, { active: false, available: true }])),
            { repairHair: { active: false, available: true } }
        )
    };
})();
