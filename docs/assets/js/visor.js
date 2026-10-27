(() => {
  const container = document.getElementById('postal-map');
  if (!container) return;
  const status = document.getElementById('map-status');
  const select = document.getElementById('postal-prefix');
  if (!window.L || !L.tileLayer.providerESP) {
    status.textContent = 'No se ha podido cargar Leaflet. Recarga la página para reintentar.';
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
  const cartociudad = L.tileLayer.providerESP('Cartociudad.CodigosPostales').addTo(map);
  const limites = L.tileLayer.providerESP('UnidadesAdm.Limites');
  const postal = L.geoJSON(null, {
    style: { color: '#203b50', weight: 1.5, fillColor: '#2e8b57', fillOpacity: 0.25 },
    onEachFeature(feature, layer) {
      const label = document.createElement('strong');
      label.textContent = `Código postal ${feature.properties.COD_POSTAL}`;
      layer.bindPopup(label);
    },
    attribution: 'Elaboración: <a href="https://dieghernan.github.io/">dieghernan</a> · CartoCiudad (IGN/CNIG) · Goerlich y Pérez Vázquez (2025)'
  }).addTo(map);
  L.control.layers({ 'IGNBase Gris': gris, IGNBase: base, PNOA: pnoa }, {
    'CartoCiudad · CP (zoom ≥ 14)': cartociudad,
    'Límites administrativos · IGN': limites,
    'Códigos postales estimados': postal
  }, { collapsed: true }).addTo(map);
  L.control.scale({ imperial: false }).addTo(map);

  let request;
  let loadedPrefix;
  async function loadPrefix() {
    request?.abort();
    const current = new AbortController();
    request = current;
    const prefix = select.value;
    status.textContent = `Cargando códigos ${prefix}xxx…`;
    try {
      const response = await fetch(`${container.dataset.source}cp-${prefix}.geojson`, { signal: current.signal });
      if (!response.ok) throw new Error('No se han podido descargar los datos');
      const data = await response.json();
      if (current.signal.aborted) return;
      if (!Array.isArray(data.features) || !data.features.length) throw new Error('Dominio vacío');
      postal.clearLayers().addData(data);
      loadedPrefix = prefix;
      map.fitBounds(postal.getBounds(), { padding: [16, 16], maxZoom: 12 });
      status.textContent = `${data.features.length} códigos postales con prefijo ${prefix}.`;
    } catch (error) {
      if (error.name === 'AbortError') return;
      const previous = loadedPrefix ? ` Se mantiene el dominio ${loadedPrefix}xxx.` : '';
      status.textContent = `No se ha podido cargar ${prefix}xxx.${previous} Elige otro prefijo o recarga la página para reintentar.`;
      if (loadedPrefix) {
        select.value = loadedPrefix;
      }
    }
  }

  select.addEventListener('change', loadPrefix);
  (async () => {
    try {
      const response = await fetch(`${container.dataset.source}prefijos.json`);
      if (!response.ok) throw new Error('No se ha podido cargar el catálogo');
      const prefixes = await response.json();
      if (!Array.isArray(prefixes) || !prefixes.length || !prefixes.every(p => /^\d{2}$/.test(p))) throw new Error('Catálogo no válido');
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
        return new Option(name ? `${prefix}xxx (${name})` : `${prefix}xxx`, prefix);
      }));
      select.value = prefixes.includes('08') ? '08' : prefixes[0];
      select.disabled = false;
      await loadPrefix();
    } catch {
      status.textContent = 'No se ha podido cargar el catálogo de prefijos. Recarga la página para reintentar.';
    }
  })();
})();
