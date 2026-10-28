const { test, expect } = require('@playwright/test');
const base = process.env.SITE_BASEURL ?? '/codigospostales';
const mapPath = `${base}/visor/mapa/`;

test('loads areas, finds a CP and restores a shared view', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await expect(page.locator('#postal-map canvas')).toBeVisible();
  await page.getByRole('searchbox', { name: 'Código postal', exact: true }).fill('28013');
  await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
  await expect(page.locator('#postal-code-status')).toHaveText('CP 28013: área estimada seleccionada.');
  await expect(page.locator('#postal-prefix')).toHaveValue('28');
  await expect(page).toHaveURL(/cp=28013/);
  await page.reload();
  await expect(page.locator('#postal-code-status')).toHaveText('CP 28013: área estimada seleccionada.');
  await expect(page.locator('#postal-prefix')).toHaveValue('28');
  expect(errors).toEqual([]);
});

test('explains that a missing area does not mean a CP does not exist', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await page.locator('#postal-code').fill('08000');
  await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
  await expect(page.locator('#postal-code-status')).toContainText('no está en las áreas publicadas');
});

test('retains the previous areas when a prefix download fails', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await page.route('**/cp-28.geojson', route => route.fulfill({ status: 503, body: '' }));
  await page.locator('#postal-prefix').selectOption('28');
  await expect(page.locator('#map-status')).toContainText('Se mantiene el dominio 08xxx');
  await expect(page.locator('#postal-prefix')).toHaveValue('08');
  await expect(page.locator('#map-loading')).toBeHidden();
  await expect(page.locator('#postal-map')).toHaveAttribute('aria-busy', 'false');
});

test('shares the view without the searched address or marker', async ({ page }) => {
  await page.route('**/geocoder/candidates?*', route => route.fulfill({
    json: [{ address: 'CALLE MAYOR 1, Madrid', postalCode: '28013', lat: 40.415, lng: -3.707 }]
  }));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await page.getByRole('searchbox', { name: 'Dirección', exact: true }).fill('Calle Mayor 1, Madrid');
  await page.getByRole('button', { name: 'Buscar', exact: true }).click();
  await page.getByRole('button', { name: 'CALLE MAYOR 1, Madrid · 28013', exact: true }).click();
  await expect(page.locator('#address-status')).toContainText('Dirección localizada.');
  await page.getByRole('button', { name: 'Compartir vista', exact: true }).click();
  await expect(page.locator('#share-url')).toHaveValue(/#prefix=28&lat=[^&]+&lng=[^&]+&zoom=16$/);
  await page.reload();
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready');
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await expect(page.getByRole('searchbox', { name: 'Dirección', exact: true })).toHaveValue('');
});

test('shows the map early on mobile and keeps controls within the viewport', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${base}/visor/`);
  const frame = page.locator('iframe.postal-map-frame');
  await expect(frame).toBeVisible();
  expect((await frame.boundingBox()).y).toBeLessThan(600);
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  const dimensions = await page.evaluate(() => ({ width: innerWidth, scroll: document.documentElement.scrollWidth }));
  expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.width);
  const map = await page.locator('#postal-map').boundingBox();
  expect(map.height).toBeGreaterThanOrEqual(844 * 0.65);
  await expect(page.getByRole('searchbox', { name: 'Código postal', exact: true })).toBeHidden();
  await page.locator('#viewer-controls > summary').click();
  await expect(page.getByRole('searchbox', { name: 'Código postal', exact: true })).toBeVisible();
});

for (const width of [320, 390]) {
  test(`keeps the open legend within a ${width}px mobile viewport`, async ({ page }) => {
    await page.setViewportSize({ width, height: 844 });
    await page.goto(mapPath);
    await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
    await page.locator('.postal-legend summary').click();
    const legend = await page.locator('.postal-legend-content').boundingBox();
    expect(legend.x).toBeGreaterThanOrEqual(0);
    expect(legend.x + legend.width).toBeLessThanOrEqual(width);
    const documentWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(documentWidth).toBeLessThanOrEqual(width);
  });

  test(`keeps prefix help readable within a ${width}px mobile panel`, async ({ page }) => {
    await page.setViewportSize({ width, height: 568 });
    await page.goto(mapPath);
    await page.locator('#viewer-controls > summary').click();
    await page.getByRole('button', { name: 'Información sobre el prefijo', exact: true }).click();
    const help = page.locator('#postal-prefix-help');
    await expect(help).toBeVisible();
    const bounds = await help.boundingBox();
    expect(bounds.x).toBeGreaterThanOrEqual(0);
    expect(bounds.x + bounds.width).toBeLessThanOrEqual(width);
    const dimensions = await help.evaluate(element => ({ scroll: element.scrollWidth, width: element.clientWidth }));
    expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.width);
    const documentWidth = await page.evaluate(() => document.documentElement.scrollWidth);
    expect(documentWidth).toBeLessThanOrEqual(width);
  });
}

test('uses one tab stop and supports keyboard navigation between search panels', async ({ page }) => {
  await page.goto(mapPath);
  const cpTab = page.getByRole('tab', { name: 'Código postal', exact: true });
  const addressTab = page.getByRole('tab', { name: 'Dirección', exact: true });
  await expect(cpTab).toHaveAttribute('tabindex', '0');
  await expect(addressTab).toHaveAttribute('tabindex', '-1');
  await cpTab.press('ArrowRight');
  await expect(addressTab).toBeFocused();
  await expect(addressTab).toHaveAttribute('aria-selected', 'true');
  await expect(addressTab).toHaveAttribute('tabindex', '0');
  await expect(cpTab).toHaveAttribute('tabindex', '-1');
  await expect(page.getByRole('searchbox', { name: 'Código postal', exact: true })).toBeHidden();
  await addressTab.press('Tab');
  await expect(page.getByRole('searchbox', { name: 'Dirección', exact: true })).toBeFocused();
  await addressTab.press('Home');
  await expect(cpTab).toBeFocused();
  await expect(cpTab).toHaveAttribute('aria-selected', 'true');
  await cpTab.press('End');
  await expect(addressTab).toBeFocused();
  await addressTab.press('ArrowLeft');
  await expect(cpTab).toBeFocused();
});

test('toggles the prefix explanation with its accessible help button', async ({ page }) => {
  await page.goto(mapPath);
  const help = page.getByRole('button', { name: 'Información sobre el prefijo', exact: true });
  await expect(page.locator('#postal-prefix-help')).toBeHidden();
  await expect(help).toHaveAttribute('aria-expanded', 'false');
  await help.click();
  await expect(page.locator('#postal-prefix-help')).toBeVisible();
  await expect(help).toHaveAttribute('aria-expanded', 'true');
  await help.click();
  await expect(page.locator('#postal-prefix-help')).toBeHidden();
  await expect(help).toHaveAttribute('aria-expanded', 'false');
});

test('closes the legend when clicking outside it', async ({ page }) => {
  await page.goto(mapPath);
  await page.locator('.postal-legend summary').click();
  await expect(page.locator('.postal-legend-content')).toBeVisible();
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await expect(page.locator('.postal-legend-content')).toBeHidden();
  await expect(page.getByRole('searchbox', { name: 'Dirección', exact: true })).toBeVisible();
});

test('shows a loading state until a new prefix has finished downloading', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  let releaseDownload;
  const downloadHeld = new Promise(resolve => { releaseDownload = resolve; });
  await page.route('**/cp-28.geojson', async route => {
    await downloadHeld;
    await route.continue();
  });
  await page.locator('#postal-prefix').selectOption('28');
  await expect(page.locator('#map-loading')).toBeVisible();
  await expect(page.locator('#postal-map')).toHaveAttribute('aria-busy', 'true');
  releaseDownload();
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready');
  await expect(page.locator('#map-loading')).toBeHidden();
  await expect(page.locator('#postal-map')).toHaveAttribute('aria-busy', 'false');
});

test('closes the layer panel with its close button or an outside click', async ({ page }) => {
  await page.goto(mapPath);
  const layers = page.getByRole('button', { name: 'Capas', exact: true });
  await layers.click();
  await expect(page.locator('.leaflet-control-layers-toggle')).toHaveAttribute('aria-expanded', 'true');
  await page.getByRole('button', { name: 'Cerrar capas', exact: true }).click();
  await expect(page.locator('.leaflet-control-layers')).not.toHaveClass(/leaflet-control-layers-expanded/);
  await expect(layers).toHaveAttribute('aria-expanded', 'false');
  await layers.click();
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await expect(page.locator('.leaflet-control-layers')).not.toHaveClass(/leaflet-control-layers-expanded/);
});

test('closes the legend drawer with Escape and returns focus to its trigger', async ({ page }) => {
  await page.goto(mapPath);
  const trigger = page.locator('.postal-legend summary');
  await trigger.click();
  await page.getByRole('button', { name: 'Cerrar leyenda', exact: true }).press('Escape');
  await expect(page.locator('.postal-legend-content')).toBeHidden();
  await expect(trigger).toBeFocused();
});
