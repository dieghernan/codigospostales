(() => {
  const container = document.getElementById('postal-map');
  if (!container) return;

  const status = document.getElementById('map-status');
  const select = document.getElementById('postal-prefix');

  if (!window.L || !L.tileLayer.providerESP) {
    status.textContent =
      'No se ha podido cargar Leaflet. Recarga la página para reintentar.';
    return;
  }

  // Evita que el zoom mínimo del WMS cambie la vista al sustituir el fondo.
  const map = L.map(container, {
    preferCanvas: true,
    scrollWheelZoom: true,
    minZoom: 0,
    maxZoom: 18
  }).setView([40.4, -3.7], 8);

  const gris = L.tileLayer.providerESP('IGNBase.Gris').addTo(map);
  const base = L.tileLayer.providerESP('IGNBase');
  const pnoa = L.tileLayer.providerESP('PNOA');

  // Ajuste temporal del minZoom del proveedor.
  const cartociudad = L.tileLayer.wms(
    'https://www.cartociudad.es/wms-inspire/direcciones-ccpp',
    {
      layers: 'codigo-postal',
      styles: 'codigopostal',
      format: 'image/png',
      transparent: true,
      version: '1.3.0',
      minZoom: 11
    }
  ).addTo(map);

  const limites = L.tileLayer.providerESP('UnidadesAdm.Limites');

  const postal = L.geoJSON(null, {
    style: {
      color: '#203b50',
      weight: 1.5,
      fillColor: '#2e8b57',
      fillOpacity: 0.25
    },
    onEachFeature(feature, layer) {
      const label = document.createElement('strong');
      label.textContent = `Código postal ${feature.properties.COD_POSTAL}`;
      layer.bindPopup(label);
    },
    attribution:
      'Elaboración: <a href="https://dieghernan.github.io/">dieghernan</a>' +
      ' · CartoCiudad (IGN/CNIG) · Goerlich y Pérez Vázquez (2025)'
  }).addTo(map);

  L.control.layers(
    {
      'IGNBase Gris': gris,
      IGNBase: base,
      PNOA: pnoa
    },
    {
      'CartoCiudad · CP (zoom ≥ 11)': cartociudad,
      'Límites administrativos · IGN': limites,
      'Códigos postales estimados': postal
    },
    { collapsed: true }
  ).addTo(map);

  L.control.scale({ imperial: false }).addTo(map);

  let request;
  let loadedPrefix;

  async function loadPrefix({ fit = true } = {}) {
    request?.abort();

    const current = new AbortController();
    request = current;

    const prefix = select.value;
    status.textContent = `Cargando códigos ${prefix}xxx…`;

    try {
      const response = await fetch(
        `${container.dataset.source}cp-${prefix}.geojson`,
        { signal: current.signal }
      );

      if (!response.ok) {
        throw new Error('No se han podido descargar los datos');
      }

      const data = await response.json();

      if (current.signal.aborted) return false;

      if (!Array.isArray(data.features) || !data.features.length) {
        throw new Error('Dominio vacío');
      }

      postal.clearLayers().addData(data);
      loadedPrefix = prefix;

      if (fit) {
        map.fitBounds(postal.getBounds(), {
          padding: [16, 16],
          maxZoom: 12
        });
      }

      status.textContent =
        `${data.features.length} códigos postales con prefijo ${prefix}.`;

      return true;
    } catch (error) {
      if (error.name === 'AbortError') return false;

      const previous = loadedPrefix
        ? ` Se mantiene el dominio ${loadedPrefix}xxx.`
        : '';

      status.textContent =
        `No se ha podido cargar ${prefix}xxx.${previous}` +
        ' Elige otro prefijo o recarga la página para reintentar.';

      if (loadedPrefix) {
        select.value = loadedPrefix;
      }
    }
  }

  select.addEventListener('change', () => loadPrefix());

  const addressForm = document.getElementById('address-search');
  const addressQuery = document.getElementById('address-query');
  const addressStatus = document.getElementById('address-status');
  const addressResults = document.getElementById('address-results');

  let addressRequest;
  let addressMarker;
  let addressSelection = 0;

  async function showAddress(candidate) {
    const selection = ++addressSelection;
    const code = String(candidate.postalCode || '');
    const prefix = /^\d{5}$/.test(code) ? code.slice(0, 2) : null;

    let loaded = true;

    if (prefix && loadedPrefix !== prefix) {
      const available = [...select.options].some(
        option => option.value === prefix
      );

      if (available && !select.disabled) {
        select.value = prefix;
        loaded = await loadPrefix({ fit: false });
      } else {
        loaded = false;
      }
    }

    if (selection !== addressSelection) return;

    if (addressMarker) addressMarker.remove();

    const label = document.createElement('div');
    label.textContent =
      candidate.address + (code ? ` · CP ${code} (CartoCiudad)` : '');

    addressMarker = L.marker([candidate.lat, candidate.lng])
      .addTo(map)
      .bindPopup(label);

    map.setView([candidate.lat, candidate.lng], 16);
    addressMarker.openPopup();

    addressResults.hidden = true;
    addressStatus.textContent =
      'Dirección localizada.' +
      (!prefix || !loaded
        ? ' No se han cargado las áreas postales de esta dirección; comprueba el selector de prefijo.'
        : '');
  }

  addressForm.addEventListener('submit', async event => {
    event.preventDefault();

    const query = addressQuery.value.trim();

    if (query.length < 3) {
      addressStatus.textContent = 'Introduce al menos tres caracteres.';
      return;
    }

    addressRequest?.abort();
    ++addressSelection;

    const current = new AbortController();
    addressRequest = current;

    const timeout = setTimeout(() => current.abort(), 15000);

    addressResults.replaceChildren();
    addressResults.hidden = true;
    addressStatus.textContent = 'Buscando direcciones…';
    addressForm.setAttribute('aria-busy', 'true');

    try {
      const url = new URL(
        'https://www.cartociudad.es/geocoder/api/geocoder/candidates'
      );

      url.searchParams.set('q', query);
      url.searchParams.set('limit', '5');

      const response = await fetch(url, { signal: current.signal });

      if (!response.ok) throw new Error('Servicio no disponible');

      const data = await response.json();

      if (addressRequest !== current) return;
      if (!Array.isArray(data)) throw new Error('Respuesta no válida');

      const candidates = data.filter(item =>
        item &&
        typeof item.address === 'string' &&
        Number.isFinite(item.lat) &&
        Number.isFinite(item.lng) &&
        Math.abs(item.lat) <= 90 &&
        Math.abs(item.lng) <= 180
      ).slice(0, 5);

      if (!candidates.length) {
        addressStatus.textContent =
          'No se han encontrado direcciones. Prueba con calle, número y municipio.';
        return;
      }

      for (const candidate of candidates) {
        const item = document.createElement('li');
        const button = document.createElement('button');

        button.type = 'button';
        button.textContent =
          candidate.address +
          (candidate.postalCode ? ` · ${candidate.postalCode}` : '');

        button.addEventListener('click', () => showAddress(candidate));

        item.append(button);
        addressResults.append(item);
      }

      addressResults.hidden = false;
      addressStatus.textContent =
        `${candidates.length} resultados. Elige una dirección para situarla en el mapa.`;
    } catch {
      if (addressRequest === current) {
        addressStatus.textContent =
          'No se ha podido completar la búsqueda. Vuelve a intentarlo.';
      }
    } finally {
      clearTimeout(timeout);

      if (addressRequest === current) {
        addressForm.removeAttribute('aria-busy');
      }
    }
  });

  (async () => {
    try {
      const response = await fetch(
        `${container.dataset.source}prefijos.json`
      );

      if (!response.ok) {
        throw new Error('No se ha podido cargar el catálogo');
      }

      const prefixes = await response.json();

      if (
        !Array.isArray(prefixes) ||
        !prefixes.length ||
        !prefixes.every(p => /^\d{2}$/.test(p))
      ) {
        throw new Error('Catálogo no válido');
      }

      // Nombres de referencia del prefijo, no límites del filtro postal.
      const names = [
        'Álava', 'Albacete', 'Alicante', 'Almería', 'Ávila', 'Badajoz',
        'Illes Balears', 'Barcelona', 'Burgos', 'Cáceres', 'Cádiz', 'Castellón',
        'Ciudad Real', 'Córdoba', 'A Coruña', 'Cuenca', 'Girona', 'Granada',
        'Guadalajara', 'Gipuzkoa', 'Huelva', 'Huesca', 'Jaén', 'León', 'Lleida',
        'La Rioja', 'Lugo', 'Madrid', 'Málaga', 'Murcia', 'Navarra', 'Ourense',
        'Asturias', 'Palencia', 'Las Palmas', 'Pontevedra', 'Salamanca',
        'Santa Cruz de Tenerife', 'Cantabria', 'Segovia', 'Sevilla', 'Soria',
        'Tarragona', 'Teruel', 'Toledo', 'Valencia', 'Valladolid', 'Bizkaia',
        'Zamora', 'Zaragoza', 'Ceuta', 'Melilla'
      ];

      select.replaceChildren(...prefixes.map(prefix => {
        const name = names[Number(prefix) - 1];

        return new Option(
          name ? `${prefix}xxx (${name})` : `${prefix}xxx`,
          prefix
        );
      }));

      select.value = prefixes.includes('08') ? '08' : prefixes[0];
      select.disabled = false;

      await loadPrefix();
    } catch {
      status.textContent =
        'No se ha podido cargar el catálogo de prefijos. Recarga la página para reintentar.';
    }
  })();
})();
