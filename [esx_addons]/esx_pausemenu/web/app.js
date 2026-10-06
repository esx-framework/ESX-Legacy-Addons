const app = document.getElementById('app');
const frame = document.getElementById('frame');
const modal = document.getElementById('modal');
const modalClose = document.getElementById('modalClose');
const modalTitle = document.getElementById('modalTitle');
const modalText = document.getElementById('modalText');
const modalActions = document.getElementById('modalActions');
const toast = document.getElementById('toast');
const newsList = document.getElementById('newsList');
let previousFocus = null;

const previewMode = new URLSearchParams(location.search).has('preview');
if (previewMode) document.body.classList.add('preview');

let state = {
    open: false,
    links: { discord: '', rules: '', store: '' },
    serverName: 'ESX LEGACY',
    selectedIndex: 0,
    text: {}
};

const defaultText = {
    ui_play: 'Play', ui_settings: 'Settings', ui_news: 'News', ui_exit: 'Exit',
    ui_menu: 'Pause menu', ui_overview: 'Server overview', ui_online: 'Players online', ui_ping: 'Connection',
    ui_resume_hint: 'Back to the city', ui_nav_label: 'Pause menu navigation',
    ui_welcome_back: 'Welcome back,', ui_hero_title: 'Los Santos\nis waiting.',
    ui_hero_subtitle: 'Take a breath. The city will be here.', ui_city_photo: 'Los Santos skyline at sunset in GTA V',
    ui_your_character: 'Your character', ui_citizen: 'Character details', ui_bank: 'Bank balance', ui_cash: 'Cash',
    ui_gender: 'Gender', ui_gender_male: 'Male', ui_gender_female: 'Female', ui_not_available: 'Not available',
    ui_playtime: 'Time played', ui_job: 'Occupation', ui_map: 'City map', ui_open_map: 'Open map',
    ui_map_alt: 'GTA V map in black and white', ui_explore_map: 'Explore the map',
    ui_community: 'Community', ui_discord_join: 'Join the community', ui_discord_action: 'Join',
    ui_discord_description: 'News, events and support on Discord.',
    ui_rules_title: 'Good stories start with respect.',
    ui_rules_description: 'Take a moment to read the rules. Make the city better for everyone.',
    ui_rules_hint: 'Read the rules', ui_since: 'SINCE', ui_close: 'Close', ui_navigate: 'Navigate', ui_select: 'Select',
    ui_news_intro: 'The latest from your community, in one place.',
    ui_news_empty: 'No news has been published yet. Visit Discord to see what the community is up to.',
    ui_server_logo: 'Server logo', ui_people: 'Players',
    ui_discord: 'DISCORD',
    ui_rules: 'RULES',
    ui_store: 'STORE',
    ui_server_info: 'SERVER INFO',
    ui_leave_server: 'LEAVE SERVER',
    ui_player: 'Player',
    ui_unemployed: 'Unemployed',
    ui_playtime_format: '{hours}h {minutes}m',
    ui_months: 'JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC',
    ui_server_info_text: '{server} · Use the shortcuts below for rules, Discord and the server store.',
    ui_leave_confirm: 'Are you sure you want to disconnect from the server?',
    ui_cancel: 'CANCEL',
    ui_leave: 'LEAVE',
    ui_link_missing: '{link} link is not configured.',
    ui_callback_failed: 'NUI callback failed.',
    ui_scoreboard_unavailable: 'Scoreboard unavailable.'
};

function t(key, values = {}) {
    const text = typeof state.text[key] === 'string' ? state.text[key] : defaultText[key] ?? key;
    return text.replace(/\{(\w+)\}/g, (match, name) => values[name] ?? match);
}

function applyLocale(locale, language) {
    state.text = locale && typeof locale === 'object' ? locale : {};
    document.documentElement.lang = typeof language === 'string' ? language : 'en';
    document.querySelectorAll('[data-text]').forEach(node => {
        const text = t(node.dataset.text);
        if (node.dataset.text === 'ui_hero_title') {
            const lines = text.split('\n');
            node.replaceChildren(document.createTextNode(lines.shift()));
            lines.forEach(line => {
                const emphasis = document.createElement('span');
                emphasis.className = 'hero-title-end';
                emphasis.textContent = line;
                node.append(document.createElement('br'), emphasis);
            });
        } else {
            node.textContent = text;
        }
    });
    document.querySelectorAll('[data-label]').forEach(node => node.setAttribute('aria-label', t(node.dataset.label)));
    document.querySelectorAll('[data-alt]').forEach(node => node.setAttribute('alt', t(node.dataset.alt)));
}

const sideItems = [...document.querySelectorAll('.side-item')];
const interactiveActions = [...document.querySelectorAll('[data-action]')];

function resizeFrame() {
    const scale = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
    document.documentElement.style.setProperty('--scale', String(scale));
}
window.addEventListener('resize', resizeFrame);
resizeFrame();

function setText(id, value) {
    const node = document.getElementById(id);
    if (node) node.textContent = value ?? '';
}

function setMetric(id, value, unit) {
    const node = document.getElementById(id);
    const detail = document.createElement('small');
    detail.textContent = unit;
    node.replaceChildren(document.createTextNode(String(value)), detail);
}

function setTheme(theme = {}) {
    const root = document.documentElement.style;
    root.setProperty('--brand', theme.primaryColor || theme.brandColor || '#FB9B04');
    root.setProperty('--darkest', theme.backgroundColor || theme.darkestColor || '#161616');
    root.setProperty('--dark', theme.secondaryColor || theme.darkColor || '#252525');
    root.setProperty('--mid', theme.accentColor || theme.midColor || '#383838');
    root.setProperty('--light', theme.lightColor || '#969696');
    root.setProperty('--lightest', theme.lightestColor || '#F2F2F2');

    const logo = document.getElementById('brandLogoImage');
    logo.onerror = () => { logo.onerror = null; logo.src = 'assets/esx-logo.png'; };
    logo.src = theme.logoUrl || 'assets/esx-logo.png';
}

function money(value) {
    return '$' + new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 }).format(Number(value) || 0);
}

function formatPlaytime(seconds) {
    const total = Math.max(0, Number(seconds) || 0);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    return t('ui_playtime_format', { hours, minutes });
}

function initials(name = t('ui_player')) {
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
    const months = t('ui_months').split(',');
    const month = months[Math.max(0, Math.min(11, (Number(clock.month) || 1) - 1))] ?? '';
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
    setText('establishedText', brand.established || '2015');
    setText('communityLine', brand.communityLine || 'BUILT BY A COMMUNITY THAT CARES');
}

function applyData(payload = {}) {
    const player = payload.player || {};
    const location = payload.location || {};
    const cfg = payload.config || {};
    const brand = cfg.brand || {};

    applyLocale(cfg.locale, cfg.language);
    setTheme(payload.theme || {});
    applyBrand(brand);
    applyClock(payload.clock || {});

    const name = player.name || t('ui_player');
    const job = player.job || player.role || t('ui_unemployed');
    const city = location.city || brand.city || 'Los Santos';
    const id = Number(player.id) || 0;

    state.links = cfg.links || {};
    state.serverName = player.serverName || 'ESX LEGACY';
    state.news = Array.isArray(cfg.news) ? cfg.news.slice(0, 20) : [];

    setText('topName', name);
    setText('topId', `#${id}`);
    setText('topAvatar', initials(name));
    setMetric('playersText', player.players ?? 0, `/ ${player.maxPlayers ?? 0}`);
    if (Number.isFinite(Number(player.ping))) {
        setMetric('pingText', Math.max(0, Math.round(Number(player.ping))), 'ms');
    } else {
        setText('pingText', '—');
    }
    setText('cityTop', city);
    setText('serverTop', String(brand.title || 'ESX LEGACY').toUpperCase());
    setText('heroName', name);
    const characterName = player.characterName || name;
    setText('playerName', characterName);
    document.getElementById('playerName').title = characterName;
    setText('jobValue', job);
    document.getElementById('jobValue').title = job;
    setText('genderValue', player.sex === 'm' ? t('ui_gender_male') : player.sex === 'f' ? t('ui_gender_female') : t('ui_not_available'));
    setText('locationText', location.street || location.zone || city);
    setText('bankValue', money(player.bank));
    setText('cashValue', money(player.cash));
    setText('playtimeValue', formatPlaytime(player.playTime));
}

function showMenu(payload) {
    applyData(payload);
    state.open = true;
    app.classList.remove('is-hidden');
    app.setAttribute('aria-hidden', 'false');
    app.inert = false;
    selectSide(0);
}

function hideMenu() {
    state.open = false;
    hideModal();
    app.classList.add('is-hidden');
    app.setAttribute('aria-hidden', 'true');
    app.inert = true;
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
        showToast(t('ui_callback_failed'));
        return { ok: false, error: String(error) };
    }
}

function openUrl(key) {
    const url = state.links?.[key];
    if (!url) {
        showToast(t('ui_link_missing', { link: t(`ui_${key}`) }));
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
    newsList.replaceChildren();
    [...frame.children].filter(node => node !== modal && node !== toast).forEach(node => { node.inert = false; });
    if (state.open && previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
    previousFocus = null;
}

function openModal(icon = 'i-rules') {
    previousFocus = document.activeElement;
    document.getElementById('modalIcon').className = `modal-icon icon ${icon}`;
    [...frame.children].filter(node => node !== modal && node !== toast).forEach(node => { node.inert = true; });
    modal.classList.remove('is-hidden');
    modalClose.focus({ preventScroll: true });
}

function showNews() {
    modalTitle.textContent = t('ui_news');
    modalText.textContent = t(state.news.length ? 'ui_news_intro' : 'ui_news_empty');
    modalActions.replaceChildren();
    newsList.replaceChildren();
    state.news.forEach(entry => {
        if (!entry || typeof entry.title !== 'string') return;
        const article = document.createElement('article');
        article.className = 'news-entry';
        const date = document.createElement('time');
        date.textContent = typeof entry.date === 'string' ? entry.date : '';
        const title = document.createElement('h3');
        title.textContent = entry.title;
        const body = document.createElement('p');
        body.textContent = typeof entry.body === 'string' ? entry.body : '';
        article.append(date, title, body);
        newsList.appendChild(article);
    });
    addModalButton(t('ui_discord'), () => openUrl('discord'), true);
    if (state.links.store) addModalButton(t('ui_store'), () => openUrl('store'));
    openModal();
}

function addModalButton(label, action, primary = false) {
    const btn = document.createElement('button');
    btn.textContent = label;
    if (primary) btn.classList.add('primary');
    btn.addEventListener('click', action);
    modalActions.appendChild(btn);
}

function showLeaveConfirm() {
    modalTitle.textContent = t('ui_leave_server');
    modalText.textContent = t('ui_leave_confirm');
    modalActions.innerHTML = '';
    newsList.replaceChildren();
    addModalButton(t('ui_cancel'), hideModal);
    addModalButton(t('ui_leave'), async () => {
        hideModal();
        await nui('leaveServer');
    }, true);
    openModal('i-logout');
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
        case 'settings':
            await nui('openSettings');
            break;
        case 'news':
            showNews();
            break;
        case 'store':
        case 'rules':
        case 'discord':
            openUrl(name);
            break;
        case 'people': {
            const response = await nui('openPeople');
            if (response && response.ok === false) showToast(response.error || t('ui_scoreboard_unavailable'));
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
    item.addEventListener('focus', () => selectSide(index));
    item.addEventListener('click', () => action(item.dataset.action));
});
interactiveActions.filter(el => !el.classList.contains('side-item')).forEach(el => el.addEventListener('click', () => action(el.dataset.action)));
modalClose.addEventListener('click', hideModal);
modal.addEventListener('click', (e) => { if (e.target === modal) hideModal(); });

window.addEventListener('keydown', async (event) => {
    if (!state.open) return;

    if (!modal.classList.contains('is-hidden')) {
        if (event.key === 'Escape') { event.preventDefault(); hideModal(); }
        if (event.key === 'Tab') {
            const buttons = [...modal.querySelectorAll('button')];
            const index = buttons.indexOf(document.activeElement);
            event.preventDefault();
            buttons[(index + (event.shiftKey ? -1 : 1) + buttons.length) % buttons.length]?.focus();
        }
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        await nui('close');
        if (!previewMode) hideMenu();
        return;
    }

    if (['ArrowDown', 'ArrowRight', 'ArrowUp', 'ArrowLeft'].includes(event.key)) {
        event.preventDefault();
        const current = interactiveActions.includes(document.activeElement) ? document.activeElement : sideItems[state.selectedIndex];
        const box = current.getBoundingClientRect();
        const cx = box.x + box.width / 2, cy = box.y + box.height / 2;
        const horizontal = event.key === 'ArrowLeft' || event.key === 'ArrowRight';
        const sign = event.key === 'ArrowDown' || event.key === 'ArrowRight' ? 1 : -1;
        const candidates = interactiveActions.filter(node => node !== current).map(node => {
            const rect = node.getBoundingClientRect();
            const dx = rect.x + rect.width / 2 - cx, dy = rect.y + rect.height / 2 - cy;
            return { node, distance: horizontal ? dx : dy, offset: Math.abs(horizontal ? dy : dx) };
        }).filter(candidate => candidate.distance * sign > 1);
        candidates.sort((a, b) => (Math.abs(a.distance) + a.offset * 3) - (Math.abs(b.distance) + b.offset * 3));
        candidates[0]?.node.focus({ preventScroll: true });
    } else if (event.key === 'Enter' && !document.activeElement?.matches('button')) {
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
        brand: { kicker: 'FIVEM ROLEPLAY', tagline: 'ROLEPLAY BEYOND LIMITS', city: 'Los Santos', established: '2015', communityLine: 'BUILT BY A COMMUNITY THAT CARES' },
        links: { discord: 'https://discord.gg/esx-framework', rules: 'https://esx-framework.org/', store: '' }
    },
    player: { id: 152, name: 'Rwixy', characterName: 'Daniel Moreno', sex: 'm', ping: 38, bank: 125460, cash: 3250, job: 'Mecánico · Jefe de taller', playTime: 45360, players: 231, maxPlayers: 1024, serverName: 'ESX LEGACY' },
    location: { city: 'Los Santos', zone: 'Downtown Vinewood', street: 'Power Street' },
    clock: { hour: 18, minute: 42, day: 27, month: 9, year: 2026 }
};

function browserLanguage() {
    const requested = new URLSearchParams(location.search).get('lang');
    return (requested || navigator.languages?.[0] || navigator.language || 'en').toLowerCase().split(/[-_]/)[0];
}

async function startPreview() {
    let catalog = {};
    try {
        const response = await fetch('locales.json?v=2');
        if (response.ok) catalog = await response.json();
    } catch (_) {
        // The English defaults also allow an offline file preview.
    }
    const detected = browserLanguage();
    const language = catalog[detected] ? detected : 'en';
    demoData.config.language = language;
    demoData.config.locale = catalog[language] || {};
    demoData.player.job = language === 'es' ? 'Mecánico · Jefe de taller' : 'Mechanic';
    showMenu(demoData);
}

if (previewMode) startPreview();
