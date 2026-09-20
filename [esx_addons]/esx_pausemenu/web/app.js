const app = document.getElementById('app');
const frame = document.getElementById('frame');
const modal = document.getElementById('modal');
const modalClose = document.getElementById('modalClose');
const modalTitle = document.getElementById('modalTitle');
const modalText = document.getElementById('modalText');
const modalActions = document.getElementById('modalActions');
const toast = document.getElementById('toast');
const playerCard = document.getElementById('playerCard');

const previewMode = new URLSearchParams(location.search).has('preview');
if (previewMode) document.body.classList.add('preview');

let state = {
    open: false,
    links: { discord: '', rules: '', store: '' },
    serverName: 'ESX LEGACY',
    selectedIndex: 0
};

const sideItems = [...document.querySelectorAll('.side-item')];
const interactiveActions = [...document.querySelectorAll('[data-action]')];
const topActions = [...document.querySelectorAll('[data-top-action]')];

function resizeFrame() {
    const scale = Math.min(window.innerWidth / 1536, window.innerHeight / 1024);
    document.documentElement.style.setProperty('--scale', String(scale));
}
window.addEventListener('resize', resizeFrame);
resizeFrame();

function setText(id, value) {
    const node = document.getElementById(id);
    if (node) node.textContent = value ?? '';
}

function setTheme(theme = {}) {
    const root = document.documentElement.style;
    root.setProperty('--brand', theme.primaryColor || theme.brandColor || '#FB9B04');
    root.setProperty('--darkest', theme.backgroundColor || theme.darkestColor || '#161616');
    root.setProperty('--dark', theme.secondaryColor || theme.darkColor || '#252525');
    root.setProperty('--mid', theme.accentColor || theme.midColor || '#383838');
    root.setProperty('--light', theme.lightColor || '#969696');
    root.setProperty('--lightest', theme.lightestColor || '#F2F2F2');

    const logoWrap = document.getElementById('brandLogoImageWrap');
    const logo = document.getElementById('brandLogoImage');
    const textWrap = document.getElementById('brandTextWrap');

    if (theme.logoUrl) {
        logo.src = theme.logoUrl;
        logoWrap.classList.remove('is-hidden');
        textWrap.classList.add('is-hidden');
        logo.onerror = () => {
            logoWrap.classList.add('is-hidden');
            textWrap.classList.remove('is-hidden');
        };
    } else {
        logoWrap.classList.add('is-hidden');
        textWrap.classList.remove('is-hidden');
    }
}

function money(value) {
    return '$ ' + new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(Number(value) || 0);
}

function formatPlaytime(seconds) {
    const total = Math.max(0, Number(seconds) || 0);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    return `${hours}h ${minutes}m`;
}

function initials(name = 'Player') {
    return String(name)
        .trim()
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map(part => part[0])
        .join('')
        .toUpperCase() || 'P';
}

function formatClock(clock = {}) {
    const hour = String(Number(clock.hour) || 0).padStart(2, '0');
    const minute = String(Number(clock.minute) || 0).padStart(2, '0');
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    const month = months[Math.max(0, Math.min(11, (Number(clock.month) || 1) - 1))];
    const day = String(Number(clock.day) || 1).padStart(2, '0');
    const year = Number(clock.year) || new Date().getFullYear();
    return { time: `${hour}:${minute}`, date: `${day} ${month} ${year}` };
}

function applyClock(clock) {
    const formatted = formatClock(clock);
    setText('timeText', formatted.time);
    setText('dateText', formatted.date);
}

function applyBrand(brand = {}) {
    setText('brandKicker', brand.kicker || 'FIVEM ROLEPLAY');
    setText('brandTagline', brand.tagline || 'ROLEPLAY BEYOND LIMITS');
    setText('cityTop', brand.city || 'Los Santos');
    setText('establishedText', brand.established || '2020');
    setText('communityLine', brand.communityLine || 'BUILT BY A COMMUNITY THAT CARES');
}

function applyData(payload = {}) {
    const player = payload.player || {};
    const location = payload.location || {};
    const cfg = payload.config || {};
    const brand = cfg.brand || {};

    setTheme(payload.theme || {});
    applyBrand(brand);
    applyClock(payload.clock || {});

    const name = player.name || 'Player';
    const job = player.job || player.role || 'Unemployed';
    const city = location.city || brand.city || 'Los Santos';
    const id = Number(player.id) || 0;
    const online = `${player.players ?? 0} / ${player.maxPlayers ?? 0}`;

    state.links = cfg.links || {};
    state.serverName = player.serverName || 'ESX LEGACY';

    setText('topName', name);
    setText('topRole', job);
    setText('playersText', online);
    setText('cityTop', city);
    setText('serverTop', String(brand.title || 'ESX LEGACY').toUpperCase());
    setText('heroName', name);
    setText('playerName', name);
    setText('playerMeta', `#${id} · ${job}`);
    setText('headId', `#${id}`);
    setText('bankValue', money(player.bank));
    setText('cashValue', money(player.cash));
    setText('playtimeValue', formatPlaytime(player.playTime));
}

function showMenu(payload) {
    applyData(payload);
    state.open = true;
    app.classList.remove('is-hidden');
    app.setAttribute('aria-hidden', 'false');
    selectSide(0);
}

function hideMenu() {
    state.open = false;
    hideModal();
    app.classList.add('is-hidden');
    app.setAttribute('aria-hidden', 'true');
}

async function nui(name, data = {}) {
    if (previewMode || typeof GetParentResourceName !== 'function') {
        if (name === 'openPeople') showToast('Preview: PEOPLE would open esx_scoreboard.');
        if (name === 'openMap') showToast('Preview: MAP would open the GTA pause map.');
        if (name === 'openSettings') showToast('Preview: SETTINGS would open the native pause menu.');
        if (name === 'leaveServer') showToast('Preview: disconnect requested.');
        if (name === 'close' || name === 'resume') showToast('Preview: close requested.');
        return { ok: true };
    }

    try {
        const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        return await response.json();
    } catch (error) {
        showToast('NUI callback failed.');
        return { ok: false, error: String(error) };
    }
}

function openUrl(key) {
    const url = state.links?.[key];
    if (!url) {
        showToast(`${key.toUpperCase()} link is not configured.`);
        return;
    }

    if (previewMode) {
        showToast(`Preview: ${url}`);
        return;
    }

    if (typeof window.invokeNative === 'function') {
        window.invokeNative('openUrl', url);
    } else {
        window.open(url, '_blank', 'noopener,noreferrer');
    }
}

function showToast(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(showToast.timer);
    showToast.timer = setTimeout(() => toast.classList.remove('show'), 2200);
}

function hideModal() {
    modal.classList.add('is-hidden');
    modalActions.innerHTML = '';
}

function addModalButton(label, action, primary = false) {
    const btn = document.createElement('button');
    btn.textContent = label;
    if (primary) btn.classList.add('primary');
    btn.addEventListener('click', action);
    modalActions.appendChild(btn);
}

function showServerInfo() {
    modalTitle.textContent = 'SERVER INFO';
    modalText.textContent = `${state.serverName} · Use the shortcuts below for rules, Discord and the server store.`;
    modalActions.innerHTML = '';
    addModalButton('RULES', () => openUrl('rules'));
    addModalButton('DISCORD', () => openUrl('discord'));
    addModalButton('STORE', () => openUrl('store'));
    modal.classList.remove('is-hidden');
}

function showLeaveConfirm() {
    modalTitle.textContent = 'LEAVE SERVER';
    modalText.textContent = 'Are you sure you want to disconnect from the server?';
    modalActions.innerHTML = '';
    addModalButton('CANCEL', hideModal);
    addModalButton('LEAVE', async () => {
        hideModal();
        await nui('leaveServer');
    }, true);
    modal.classList.remove('is-hidden');
}

function focusCharacter() {
    playerCard.classList.remove('flash');
    void playerCard.offsetWidth;
    playerCard.classList.add('flash');
}

async function action(name) {
    switch (name) {
        case 'resume':
            await nui('resume');
            if (previewMode) return;
            break;
        case 'map':
            await nui('openMap');
            break;
        case 'character':
            focusCharacter();
            break;
        case 'settings':
            await nui('openSettings');
            break;
        case 'server-info':
            showServerInfo();
            break;
        case 'store':
        case 'rules':
        case 'discord':
            openUrl(name);
            break;
        case 'people': {
            const response = await nui('openPeople');
            if (response && response.ok === false) showToast(response.error || 'Scoreboard unavailable.');
            break;
        }
        case 'leave':
            showLeaveConfirm();
            break;
    }
}

function selectSide(index) {
    state.selectedIndex = (index + sideItems.length) % sideItems.length;
    sideItems.forEach((item, i) => item.classList.toggle('is-selected', i === state.selectedIndex));
}

sideItems.forEach((item, index) => {
    item.addEventListener('mouseenter', () => selectSide(index));
    item.addEventListener('click', () => action(item.dataset.action));
});
interactiveActions.filter(el => !el.classList.contains('side-item')).forEach(el => el.addEventListener('click', () => action(el.dataset.action)));
topActions.forEach(el => el.addEventListener('click', () => action(el.dataset.topAction)));
modalClose.addEventListener('click', hideModal);
modal.addEventListener('click', (e) => { if (e.target === modal) hideModal(); });

window.addEventListener('keydown', async (event) => {
    if (!state.open) return;

    if (!modal.classList.contains('is-hidden')) {
        if (event.key === 'Escape') hideModal();
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        await nui('close');
        if (!previewMode) hideMenu();
        return;
    }

    if (event.key === 'ArrowDown' || event.key === 'ArrowRight') {
        event.preventDefault();
        selectSide(state.selectedIndex + 1);
    } else if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') {
        event.preventDefault();
        selectSide(state.selectedIndex - 1);
    } else if (event.key === 'Enter') {
        event.preventDefault();
        sideItems[state.selectedIndex]?.click();
    }
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.type === 'open') showMenu(message.data || {});
    if (message.type === 'close') hideMenu();
    if (message.type === 'clock') applyClock(message.data || {});
});

const demoData = {
    theme: {
        primaryColor: '#FB9B04', backgroundColor: '#161616', secondaryColor: '#252525', accentColor: '#383838',
        brandColor: '#FB9B04', darkestColor: '#161616', darkColor: '#252525', midColor: '#383838', lightColor: '#969696', lightestColor: '#F2F2F2'
    },
    config: {
        brand: { kicker: 'FIVEM ROLEPLAY', tagline: 'ROLEPLAY BEYOND LIMITS', city: 'Los Santos', established: '2020', communityLine: 'BUILT BY A COMMUNITY THAT CARES' },
        links: { discord: 'https://discord.gg/esx-framework', rules: 'https://esx-framework.org/', store: 'https://store.example.com' }
    },
    player: { id: 152, name: 'Rwixy', role: 'Unemployed', bank: 125460, cash: 3250, job: 'Unemployed', playTime: 45360, players: 231, maxPlayers: 1024, serverName: 'ESX LEGACY' },
    location: { city: 'Los Santos', zone: 'Downtown Vinewood', street: 'Power Street' },
    clock: { hour: 18, minute: 42, day: 19, month: 9, year: 2026 }
};

if (previewMode) showMenu(demoData);
