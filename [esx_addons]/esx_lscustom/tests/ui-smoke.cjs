// Run with Playwright available and CHROME_PATH set when using an existing browser.
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const { pathToFileURL } = require('node:url');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');

async function run() {
  const browser = await chromium.launch({ headless: true, executablePath: process.env.CHROME_PATH || undefined });
  const output = process.env.UI_ARTIFACT_DIR || path.join(__dirname, 'artifacts');
  fs.mkdirSync(output, { recursive: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    const errors = [];
    const calls = [];
    page.on('pageerror', (error) => errors.push(error.message));
    const stats = { speed: { value: 68 }, accel: { value: 43, delta: 12 }, brake: { value: 57 }, handling: { value: 81 } };
    const option = (label, modNum, price, extra = {}) => ({ label, action: 'mod', menuKey: 'modEngine', modType: 'modEngine', modNum, price, ...extra });
    const menus = {
      main: { id: 'main', title: 'LS CUSTOMS', elements: [
        { label: 'Performance', value: 'upgrades', action: 'menu' }, { label: 'Appearance', value: 'cosmetics', action: 'menu' },
        { label: 'Checkout cart', value: 'cartCheckout', action: 'checkout' }
      ] },
      upgrades: { id: 'upgrades', title: 'Performance', parent: 'main', elements: [
        { label: 'Engine', value: 'modEngine', action: 'menu' }, { label: 'Brakes', value: 'modBrakes', action: 'menu' },
        { label: 'Transmission', value: 'modTransmission', action: 'menu' }, { label: 'Suspension', value: 'modSuspension', action: 'menu' },
        { label: 'Turbo', value: 'modTurbo', action: 'menu' }, { label: 'Armor', value: 'modArmor', action: 'menu' }
      ] },
      cosmetics: { id: 'cosmetics', title: 'Appearance', parent: 'main', elements: [
        { label: 'Paint', value: 'primaryRespray', action: 'menu' }, { label: 'Bodywork', value: 'bodyparts', action: 'menu' },
        { label: 'Wheels', value: 'wheels', action: 'menu' }, { label: 'Lights', value: 'modXenon', action: 'menu' }
      ] },
      modEngine: { id: 'modEngine', title: 'Engine', parent: 'upgrades', elements: [
        option('Stock engine', -1, 0, { installed: true }), option('EMS upgrade / Level 1', 0, 2500),
        option('EMS upgrade / Level 2', 1, 5000), option('EMS upgrade / Level 3', 2, 8500), option('EMS upgrade / Level 4', 3, 12500)
      ] }
    };
    let cart = [];
    let current = menus.main;
    let rejectNext = false;
    const send = (data) => page.evaluate((message) => window.dispatchEvent(new MessageEvent('message', { data: message })), data);
    const update = () => send({ action: 'state', menu: current, cart, total: cart.reduce((n, item) => n + item.price, 0), stats });
    await page.route('https://esx_lscustom/**', async (route) => {
      const action = new URL(route.request().url()).pathname.slice(1);
      const data = route.request().postDataJSON();
      calls.push({ action, data });
      if (rejectNext) { rejectNext = false; await route.abort(); return; }
      await route.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}', headers: { 'access-control-allow-origin': '*' } });
      if (action === 'openMenu') { current = menus[data.value] || current; await update(); }
      if (action === 'addToCart') { cart = [...cart.filter((item) => item.modType !== data.modType), data]; await update(); }
      if (action === 'clearCart') { cart = []; await update(); }
      if (action === 'camera') await send({ action: 'cameraState', view: data.value });
      if (action === 'close') await send({ action: 'close' });
    });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../html/index.html')).href);
    await page.evaluate(() => document.fonts.ready);
    assert(await page.locator('#app').isHidden());
    await send({ action: 'open', subtitle: 'SULTAN RS', menu: current, cart, total: 0, stats, features: { camera: true, stats: true } });
    await page.getByRole('button', { name: 'Performance', exact: true }).first().click();
    await page.getByRole('button', { name: 'Engine', exact: true }).click();
    await page.getByRole('button', { name: /Level 2/ }).click();
    await page.getByRole('button', { name: /Level 3/ }).hover();
    assert.equal(await page.locator('#selectionName').textContent(), 'EMS upgrade / Level 2');
    await page.getByRole('button', { name: 'Add to cart', exact: true }).click();
    await page.waitForFunction(() => document.getElementById('cartBadge').textContent === '1');
    assert.equal(calls.filter((call) => call.action === 'addToCart').at(-1).data.modNum, 1);
    assert.equal(await page.locator('#addBtn').isDisabled(), true);
    await page.locator('#cartToggle').click();
    assert(await page.locator('#cartPanel').isVisible());
    assert.equal(await page.locator('#cartTotal').textContent(), '$5,000');
    assert.equal(calls.filter((call) => call.action === 'checkout').length, 0);
    await page.keyboard.press('Escape');
    assert(await page.locator('#cartPanel').isHidden());
    const navCount = calls.filter((call) => call.action === 'openMenu').length;
    await page.locator('#searchInput').fill('Level 4');
    assert.equal(await page.locator('.option-row').count(), 1);
    await page.keyboard.press('Backspace');
    assert.equal(calls.filter((call) => call.action === 'openMenu').length, navCount);
    await page.locator('#searchInput').fill('not-a-modification');
    assert.equal(await page.locator('.list-empty').textContent(), 'No matching options.');
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.option-row').count(), 5);
    await page.locator('#gridViewBtn').click();
    assert.equal(await page.locator('.option-grid.tiles').count(), 1);
    await page.locator('#listViewBtn').click();
    for (const camera of ['front', 'back', 'left', 'right', 'top', 'rotateLeft', 'rotateRight', 'zoomIn', 'zoomOut', 'free', 'default']) {
      await page.locator(`[data-camera="${camera}"]`).click();
    }
    await page.waitForFunction(() => document.querySelector('[data-camera="default"]').getAttribute('aria-pressed') === 'true');
    assert.equal(calls.filter((call) => call.action === 'camera').length, 11);
    assert(await page.locator('.esx-logo').evaluate((node) => node.complete && node.naturalWidth > 0));
    assert.equal(await page.locator('[data-icon]').evaluateAll((nodes) => nodes.filter((node) => !node.querySelector('svg')).length), 0);

    await page.locator('#cartToggle').click();
    for (const [width, height] of [[1920, 1080], [1280, 720], [1024, 768], [800, 600], [390, 844], [360, 640]]) {
      await page.setViewportSize({ width, height });
      await page.waitForTimeout(200);
      const layout = await page.evaluate(() => {
        const box = (selector) => {
          const r = document.querySelector(selector).getBoundingClientRect();
          return { x: r.x, y: r.y, right: r.right, bottom: r.bottom, width: r.width, height: r.height };
        };
        return { shell: box('.lsc-shell'), camera: box('#cameraDock'), cart: box('#cartPanel'), toggle: box('#cartToggle'), footer: box('.panel-footer'), pageWidth: document.documentElement.scrollWidth };
      });
      for (const [name, rect] of Object.entries(layout).filter(([name]) => name !== 'pageWidth')) {
        assert(rect.x >= 0 && rect.y >= 0 && rect.right <= width + 1 && rect.bottom <= height + 1, `${name} outside ${width}x${height}: ${JSON.stringify(rect)}`);
      }
      assert(layout.camera.right < layout.toggle.x, 'Camera overlaps cart button');
      assert(layout.cart.bottom < layout.camera.y, 'Cart overlaps camera controls');
      assert(layout.footer.bottom <= layout.shell.bottom, 'Footer outside panel');
      assert.equal(layout.pageWidth, width);
      await page.screenshot({ path: path.join(output, `workshop-${width}x${height}.png`), omitBackground: true });
    }
    await page.setViewportSize({ width: 1280, height: 720 });
    const longLabel = 'Carbon reinforced competition package with extended aerodynamic components';
    await send({ action: 'state', cart: Array.from({ length: 35 }, (_, index) => ({ label: `${longLabel} ${index}`, price: 1234567, modType: 'modSpoilers' })), total: 43209845 });
    assert(await page.locator('#cartList').evaluate((node) => node.scrollHeight > node.clientHeight));
    assert(await page.locator('.cart-footer').evaluate((node) => node.getBoundingClientRect().bottom < window.innerHeight));
    assert.equal(await page.locator('.cart-item span').evaluateAll((nodes) => nodes.filter((node) => node.scrollWidth > node.clientWidth + 1).length), 0);
    await update();
    await page.locator('#clearBtn').click();
    await page.waitForFunction(() => document.getElementById('payBtn').disabled);
    assert.equal(await page.locator('.cart-empty').count(), 1);
    assert(await page.locator('#cartBadge').isHidden());
    await send({ action: 'state', locale: { language: 'es', search: 'Buscar opciones', selection: 'Selección', addToCart: 'Añadir al carrito', inCart: 'En el carrito', list: 'Lista', grid: 'Cuadrícula' } });
    assert.equal(await page.locator('#searchInput').getAttribute('placeholder'), 'Buscar opciones');
    assert.equal(await page.locator('#selectionLabel').textContent(), 'Selección');
    assert.equal(await page.locator('html').getAttribute('lang'), 'es');
    await page.locator('#cartCloseBtn').click();
    rejectNext = true;
    await page.locator('[data-camera="front"]').click();
    await page.locator('#toast.error').waitFor({ state: 'visible' });
    await page.locator('#closeBtn').click();
    await page.locator('#app').waitFor({ state: 'hidden' });
    const closedCalls = calls.length;
    await page.keyboard.press('Escape');
    await page.waitForTimeout(50);
    assert.equal(calls.length, closedCalls);
    assert.deepEqual(errors, []);
    console.log(JSON.stringify({ passed: true, viewports: 6, cameraActions: 11, calls: calls.length, screenshots: output }));
  } finally { await browser.close(); }
}
run().catch((error) => { console.error(error); process.exitCode = 1; });
