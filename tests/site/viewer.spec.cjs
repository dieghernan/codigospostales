const { test, expect } = require('@playwright/test');
const base = process.env.SITE_BASEURL ?? '/codigospostales';
const mapPath = `${base}/visor/mapa/`;

async function locateMadridAddress(page) {
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
}

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

for (const code of ['28013', '08001']) {
  test(`removes the address marker when searching for CP ${code}`, async ({ page }) => {
    await locateMadridAddress(page);
    await expect(page.locator('.leaflet-marker-icon')).toHaveCount(1);
    await page.getByRole('tab', { name: 'Código postal', exact: true }).click();
    await page.getByRole('searchbox', { name: 'Código postal', exact: true }).fill(code);
    await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
    await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
    await expect(page.locator('#postal-code-status')).toHaveText(`CP ${code}: área estimada seleccionada.`);
    await expect(page.locator('#address-status')).toBeEmpty();
  });
}

test('removes the address marker when changing the prefix filter', async ({ page }) => {
  await locateMadridAddress(page);
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(1);
  await page.locator('#postal-prefix').selectOption('08');
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready');
  await expect(page.locator('#address-status')).toBeEmpty();
});

test('removes the previous marker even when a new address search finds nothing', async ({ page }) => {
  await locateMadridAddress(page);
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(1);
  await page.route('**/geocoder/candidates?*', route => route.fulfill({ json: [] }));
  await page.getByRole('searchbox', { name: 'Dirección', exact: true }).fill('Nueva dirección');
  await page.getByRole('button', { name: 'Buscar', exact: true }).click();
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
  await expect(page.locator('#address-status')).toContainText('No se han encontrado direcciones.');
});

test('cancels a pending address prefix load when a CP search takes over', async ({ page }) => {
  await page.route('**/geocoder/candidates?*', route => route.fulfill({
    json: [{ address: 'CALLE MAYOR 1, Madrid', postalCode: '28013', lat: 40.415, lng: -3.707 }]
  }));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  let holdPrefix;
  const prefixRequested = new Promise(resolve => { holdPrefix = resolve; });
  await page.route('**/cp-28.geojson', () => { holdPrefix(); });
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await page.getByRole('searchbox', { name: 'Dirección', exact: true }).fill('Calle Mayor 1, Madrid');
  await page.getByRole('button', { name: 'Buscar', exact: true }).click();
  await page.getByRole('button', { name: 'CALLE MAYOR 1, Madrid · 28013', exact: true }).click();
  await prefixRequested;
  const cancelled = page.waitForEvent('requestfailed', {
    predicate: request => request.url().endsWith('/cp-28.geojson')
  });
  await page.getByRole('tab', { name: 'Código postal', exact: true }).click();
  await page.getByRole('searchbox', { name: 'Código postal', exact: true }).fill('08001');
  await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
  await cancelled;
  await expect(page.locator('#postal-code-status')).toHaveText('CP 08001: área estimada seleccionada.');
  await expect(page.locator('#postal-prefix')).toHaveValue('08');
  await expect(page.locator('.leaflet-marker-icon')).toHaveCount(0);
  await expect(page.locator('#map-loading')).toBeHidden();
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

test('clears CP search loading feedback when the download fails', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  let releaseDownload;
  const held = new Promise(resolve => { releaseDownload = resolve; });
  await page.route('**/cp-28.geojson', async route => {
    await held;
    await route.fulfill({ status: 503, body: '' });
  });
  await page.getByRole('searchbox', { name: 'Código postal', exact: true }).fill('28013');
  await page.getByRole('button', { name: 'Ver CP', exact: true }).click();
  await expect(page.locator('#map-loading')).toBeVisible();
  await expect(page.locator('#postal-map')).toHaveAttribute('aria-busy', 'true');
  releaseDownload();
  await expect(page.locator('#postal-code-status')).toContainText('No se ha completado la búsqueda.');
  await expect(page.locator('#map-loading')).toBeHidden();
  await expect(page.locator('#postal-map')).toHaveAttribute('aria-busy', 'false');
});

for (const width of [390, 1280]) {
  test(`keeps the legend clear of map controls and attribution at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 844 });
    await page.goto(mapPath);
    await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
    await page.locator('.postal-legend summary').click();
    const overlaps = await page.locator('.postal-legend-content').evaluate(panel => {
      const legend = panel.getBoundingClientRect();
      return ['.leaflet-control-zoom', '.leaflet-control-layers', '.leaflet-control-attribution'].filter(selector => {
        const rect = document.querySelector(selector).getBoundingClientRect();
        return legend.left < rect.right && legend.right > rect.left && legend.top < rect.bottom && legend.bottom > rect.top;
      });
    });
    expect(overlaps).toEqual([]);
    await page.getByRole('button', { name: 'Capas', exact: true }).click();
    await expect(page.locator('.postal-legend-content')).toBeHidden();
    await expect(page.getByRole('button', { name: 'Cerrar capas', exact: true })).toBeVisible();
  });
}

test('distinguishes polygon hover from selection and restores each on mouseout', async ({ page }) => {
  await page.route('**/cp-08.geojson', route => route.fulfill({ json: {
    type: 'FeatureCollection', features: [{ type: 'Feature', properties: { COD_POSTAL: '08001' },
      geometry: { type: 'Polygon', coordinates: [[[2, 41], [2.02, 41], [2.02, 41.02], [2, 41.02], [2, 41]]] } }]
  } }));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  const canvas = page.locator('#postal-map canvas');
  const centerPixel = () => canvas.evaluate(element => Array.from(element.getContext('2d').getImageData(
    Math.floor(element.width / 2), Math.floor(element.height / 2), 1, 1
  ).data));
  await expect.poll(async () => (await centerPixel())[3]).toBeGreaterThan(0);
  const normal = await centerPixel();
  const map = page.locator('#postal-map');
  const box = await map.boundingBox();
  const position = { x: box.width / 2, y: box.height / 2 };
  await map.hover({ position });
  await expect.poll(centerPixel).not.toEqual(normal);
  const hover = await centerPixel();
  await page.getByRole('tab', { name: 'Código postal', exact: true }).hover();
  await expect.poll(centerPixel).toEqual(normal);
  await map.click({ position });
  await expect(page.locator('#postal-code-status')).toHaveText('CP 08001: área estimada seleccionada.');
  await expect.poll(centerPixel).not.toEqual(hover);
  const selected = await centerPixel();
  await page.getByRole('tab', { name: 'Código postal', exact: true }).hover();
  await expect.poll(centerPixel).toEqual(selected);
});

for (const width of [850, 1280]) {
  for (const mode of ['Código postal', 'Dirección']) {
    test(`aligns desktop search controls in one row at ${width}px in ${mode} mode`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto(mapPath);
      await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
      await page.getByRole('tab', { name: mode, exact: true }).click();
      const boxes = await page.locator('#postal-prefix, .search-tabs, .tab-panel.active input, .tab-panel.active form button[type="submit"]').evaluateAll(elements => elements.map(element => {
        const { x, y, width, height } = element.getBoundingClientRect();
        return { x, y, width, height };
      }));
      expect(boxes).toHaveLength(4);
      for (const box of boxes) {
        expect(box.height).toBeCloseTo(32, 0);
        expect(Math.abs(box.y - boxes[0].y)).toBeLessThanOrEqual(1);
        expect(box.width).toBeGreaterThan(40);
        expect(box.x + box.width).toBeLessThanOrEqual(width);
      }
      const share = await page.locator('#share-view').boundingBox();
      const legend = await page.locator('.postal-legend > summary').boundingBox();
      expect(share.y).toBeGreaterThanOrEqual(boxes[0].y + 32);
      expect(Math.abs((share.y + share.height / 2) - (legend.y + legend.height / 2))).toBeLessThanOrEqual(1);
      expect(legend.x).toBeGreaterThan(share.x + share.width);
    });
  }
}

for (const width of [320, 1280]) {
  test(`toggles accessible address help without horizontal overflow at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto(mapPath);
    if (width < 601) await page.locator('#viewer-controls > summary').click();
    await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
    const help = page.getByRole('button', { name: 'Información sobre la búsqueda por dirección', exact: true });
    await expect(page.locator('#address-help')).toBeHidden();
    await help.click();
    await expect(help).toHaveAttribute('aria-expanded', 'true');
    await expect(page.locator('#address-help')).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
    await help.click();
    await expect(help).toHaveAttribute('aria-expanded', 'false');
    await expect(page.locator('#address-help')).toBeHidden();
  });
}

test('returns keyboard focus to the address field after choosing a result', async ({ page }) => {
  await page.route('**/geocoder/candidates?*', route => route.fulfill({
    json: [{ address: 'CALLE MAYOR 1, Madrid', postalCode: '28013', lat: 40.415, lng: -3.707 }]
  }));
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await page.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await page.getByRole('searchbox', { name: 'Dirección', exact: true }).fill('Calle Mayor 1, Madrid');
  await page.getByRole('button', { name: 'Buscar', exact: true }).click();
  await page.getByRole('button', { name: 'CALLE MAYOR 1, Madrid · 28013', exact: true }).focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('#address-status')).toContainText('CP 28013 (CartoCiudad)');
  await expect(page.locator('#address-query')).toBeFocused();
});

test('explores and selects a CP using the filterable keyboard list', async ({ page }) => {
  await page.goto(mapPath);
  await expect(page.locator('#map-status')).toHaveAttribute('data-state', 'ready', { timeout: 45000 });
  await page.locator('.postal-code-browser > summary').focus();
  await page.keyboard.press('Enter');
  await page.getByRole('searchbox', { name: 'Filtrar códigos del prefijo' }).fill('08001');
  await expect(page.locator('#code-list option')).toHaveCount(1);
  await page.getByRole('button', { name: 'Ver área', exact: true }).click();
  await expect(page.locator('#postal-code-status')).toHaveText('CP 08001: área estimada seleccionada.');
  await expect(page.locator('.postal-code-browser > summary')).toBeFocused();
  await page.keyboard.press('Enter');
  await page.getByRole('searchbox', { name: 'Filtrar códigos del prefijo' }).fill('99999');
  await expect(page.getByRole('button', { name: 'Ver área', exact: true })).toBeDisabled();
  await page.keyboard.press('Escape');
  await expect(page.locator('.postal-code-browser > summary')).toBeFocused();
  await expect(page.locator('#code-list')).toBeHidden();
});

test('gives the embedded desktop map enough width for inline controls', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(`${base}/visor/`);
  const frame = page.locator('iframe.postal-map-frame');
  expect((await frame.boundingBox()).width).toBeGreaterThanOrEqual(850);
});

test('keeps the CP browser and its submit button reachable in a narrow embedded map', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto(`${base}/visor/`);
  const frame = page.frameLocator('iframe.postal-map-frame');
  await frame.locator('#viewer-controls > summary').click();
  await frame.getByRole('tab', { name: 'Dirección', exact: true }).click();
  await frame.locator('.postal-code-browser > summary').click();
  const panel = frame.locator('.postal-code-browser-content');
  await expect.poll(() => panel.evaluate(element => element.getBoundingClientRect().bottom <= innerHeight)).toBe(true);
  await expect.poll(() => panel.evaluate(element => element.getBoundingClientRect().bottom <= document.querySelector('.leaflet-control-attribution').getBoundingClientRect().top)).toBe(true);
  await frame.getByRole('button', { name: 'Ver área', exact: true }).scrollIntoViewIfNeeded();
  await expect(frame.getByRole('button', { name: 'Ver área', exact: true })).toBeInViewport();
});
