const { test, expect } = require('@playwright/test');
const base = process.env.SITE_BASEURL ?? '/codigospostales';
const mapPath = `${base}/visor/mapa/`;

test('loads areas, finds a CP and restores a shared view', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 08', { timeout: 45000 });
  await expect(page.locator('#postal-map canvas')).toBeVisible();
  await page.getByLabel('Código postal', { exact: true }).fill('28013');
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
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 08', { timeout: 45000 });
  await page.locator('#postal-code').fill('08000');
  await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
  await expect(page.locator('#postal-code-status')).toContainText('no está en las áreas publicadas');
});

test('retains the previous areas when a prefix download fails', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 08', { timeout: 45000 });
  await page.route('**/cp-28.geojson', route => route.fulfill({ status: 503, body: '' }));
  await page.locator('#postal-prefix').selectOption('28');
  await expect(page.locator('#map-status')).toContainText('Se mantiene el dominio 08xxx');
  await expect(page.locator('#postal-prefix')).toHaveValue('08');
});

test('shares the view without the searched address or marker', async ({ page }) => {
  await page.route('**/geocoder/candidates?*', route => route.fulfill({
    json: [{ address: 'CALLE MAYOR 1, Madrid', postalCode: '28013', lat: 40.415, lng: -3.707 }]
  }));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 08', { timeout: 45000 });
  await page.getByLabel('Dirección', { exact: true }).fill('Calle Mayor 1, Madrid');
  await page.getByRole('button', { name: 'Buscar', exact: true }).click();
  await page.getByRole('button', { name: 'CALLE MAYOR 1, Madrid · 28013', exact: true }).click();
  await expect(page.locator('#address-status')).toContainText('Dirección localizada.');
  await page.getByRole('button', { name: 'Compartir vista', exact: true }).click();
  await expect(page.locator('#share-url')).toHaveValue(/#prefix=28&lat=[^&]+&lng=[^&]+&zoom=16$/);
  await page.reload();
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 28');
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
  await expect(page.getByLabel('Dirección', { exact: true })).toHaveValue('');
});

test('shows the map early on mobile and keeps controls within the viewport', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${base}/visor/`);
  const frame = page.locator('iframe.postal-map-frame');
  await expect(frame).toBeVisible();
  expect((await frame.boundingBox()).y).toBeLessThan(600);
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toContainText('códigos postales con prefijo 08', { timeout: 45000 });
  const dimensions = await page.evaluate(() => ({ width: innerWidth, scroll: document.documentElement.scrollWidth }));
  expect(dimensions.scroll).toBeLessThanOrEqual(dimensions.width);
  await expect(page.getByLabel('Código postal', { exact: true })).toBeVisible();
});
