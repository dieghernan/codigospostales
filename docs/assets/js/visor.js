(() => {
  const container = document.getElementById('postal-map');
  if (!container) return;

  const status = document.getElementById('map-status');
  const select = document.getElementById('postal-prefix');
  const loading = document.getElementById('map-loading');
  const pendingLoads = new Map();

  function beginLoading(message) {
    const token = Symbol();
    pendingLoads.set(token, message);
    renderLoading();
    return () => {
      pendingLoads.delete(token);
      renderLoading();
    };
  }

  function renderLoading() {
    loading.hidden = pendingLoads.size === 0;
    container.setAttribute('aria-busy', String(pendingLoads.size > 0));
    if (pendingLoads.size) {
      document.getElementById('map-loading-text').textContent =
        [...pendingLoads.values()].at(-1);
    }
  }

  if (!window.L || !L.tileLayer.providerESP) {
    status.dataset.state = 'error';
    status.textContent =
      'No se ha podido cargar Leaflet. Recarga la página para reintentar.';
    return;
  }

  const saved = new URLSearchParams(window.location.hash.slice(1));
  const savedView = ['lat', 'lng', 'zoom'].every(key =>
    saved.has(key) && saved.get(key).trim() !== '' && Number.isFinite(Number(saved.get(key)))
  ) && Math.abs(Number(saved.get('lat'))) <= 85
    && Math.abs(Number(saved.get('lng'))) <= 180
    && Number(saved.get('zoom')) >= 0 && Number(saved.get('zoom')) <= 18;
  let selectedCode;
  let ready = false;

  const map = L.map(container, {
    preferCanvas: true,
    scrollWheelZoom: true,
    minZoom: 0,
    maxZoom: 18,
    zoomControl: false
  }).setView([40.4, -3.7], 8);
  L.control.zoom({ zoomInTitle: 'Acercar', zoomOutTitle: 'Alejar' }).addTo(map);
  map.on('popupopen', event => {
    const close = event.popup.getElement().querySelector('.leaflet-popup-close-button');
    if (close) {
      close.title = 'Cerrar ventana';
      close.setAttribute('aria-label', 'Cerrar ventana');
    }
  });

  const selectedStyle = {
    color: '#a52b27', weight: 4, fillColor: '#eb6864', fillOpacity: 0.5
  };

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

      layer.on({
        click() {
          selectCode(feature.properties.COD_POSTAL, false);
        },
        mouseover(event) {
          const polygon = event.target;

          polygon.setStyle({
            color: '#b52f2b',
            weight: feature.properties.COD_POSTAL === selectedCode ? 4 : 3,
            fillColor: '#eb6864',
            fillOpacity: 0.5
          });

          polygon.bringToFront();
        },

        mouseout(event) {
          if (feature.properties.COD_POSTAL === selectedCode) {
            event.target.setStyle(selectedStyle);
          } else {
            postal.resetStyle(event.target);
          }
        }
      });
    },

    attribution:
      'Elaboración: <a href="https://dieghernan.github.io/">dieghernan</a>' +
      ' · CartoCiudad (IGN/CNIG)' +
      ' · <a href="https://doi.org/10.5281/zenodo.15345101">Goerlich y Pérez Vázquez (2025)</a>' +
      ' · Método: <a href="https://www.uv.es/goerlich/Ivie/CodPost.html">Goerlich (2022)</a>'
  }).addTo(map);

  // Mostrar el acceso a toda ventana cuando el visor esté incrustado.
  if (window.self !== window.top) {
    const fullWindowControl = L.control({ position: 'topright' });

    fullWindowControl.onAdd = function () {
      const control = L.DomUtil.create(
        'div',
        'leaflet-bar postal-full-window'
      );

      const link = L.DomUtil.create('a', '', control);

      // La URL del documento actual corresponde a /visor/mapa/.
      link.href = window.location.href;
      link.target = '_top';
      link.title = 'Abrir el mapa a toda ventana';
      link.setAttribute('aria-label', 'Abrir el mapa a toda ventana');
      link.textContent = '⛶';

      L.DomEvent.disableClickPropagation(control);
      L.DomEvent.disableScrollPropagation(control);

      return control;
    };

    fullWindowControl.addTo(map);
  }

  const layersControl = L.control.layers(
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

  // Leaflet's collapsed layer switch has an English accessible name by default.
  const layersLink = container.querySelector('.leaflet-control-layers-toggle');
  layersLink.title = 'Capas';
  layersLink.setAttribute('aria-label', 'Capas');
  const layersPanel = layersControl.getContainer();
  // Keep the panel stable until the user dismisses it explicitly or clicks outside.
  L.DomEvent.off(layersPanel, 'mouseenter mouseleave');
  layersPanel.querySelector('.leaflet-control-layers-list').id = 'postal-layer-options';
  layersLink.setAttribute('aria-controls', 'postal-layer-options');
  layersLink.setAttribute('aria-expanded', 'false');
  new MutationObserver(() => {
    layersLink.setAttribute('aria-expanded', String(layersPanel.classList.contains('leaflet-control-layers-expanded')));
  }).observe(layersPanel, { attributes: true, attributeFilter: ['class'] });
  layersLink.addEventListener('keydown', event => {
    if (event.key === ' ') {
      event.preventDefault();
      layersControl.expand();
    }
  });
  const layersClose = document.createElement('button');
  layersClose.type = 'button';
  layersClose.className = 'layers-close';
  layersClose.setAttribute('aria-label', 'Cerrar capas');
  layersClose.textContent = '×';
  layersPanel.prepend(layersClose);
  layersClose.addEventListener('click', () => {
    layersControl.collapse();
    layersLink.focus();
  });
  document.addEventListener('click', event => {
    if (!layersPanel.contains(event.target)) layersControl.collapse();
  }, true);
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && layersPanel.classList.contains('leaflet-control-layers-expanded')) {
      layersControl.collapse();
      layersLink.focus();
    }
  });
  if (typeof ResizeObserver !== 'undefined') {
    new ResizeObserver(() => map.invalidateSize({ pan: false, debounceMoveend: true })).observe(container);
  }

  L.control.scale({ imperial: false }).addTo(map);

  let request;
  let loadedPrefix;

  async function loadPrefix({ fit = true } = {}) {
    request?.abort();

    const current = new AbortController();
    request = current;

    const prefix = select.value;
    status.dataset.state = 'loading';
    status.textContent = 'Cargando…';
    const finishLoading = beginLoading(`Cargando áreas ${prefix}xxx…`);

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
      selectedCode = undefined;
      document.getElementById('postal-code-status').textContent = '';

      if (fit) {
        map.fitBounds(postal.getBounds(), {
          padding: [16, 16],
          maxZoom: 12
        });
      }

      status.dataset.state = 'ready';
      status.textContent = `${data.features.length} CP`;

      saveView();

      return true;
    } catch (error) {
      if (error.name === 'AbortError') return false;

      const previous = loadedPrefix
        ? ` Se mantiene el dominio ${loadedPrefix}xxx.`
        : '';

      status.dataset.state = 'error';
      status.textContent =
        `No se ha podido cargar ${prefix}xxx.${previous}` +
        ' Elige otro prefijo o recarga la página para reintentar.';

      if (loadedPrefix) {
        select.value = loadedPrefix;
      }

      return false;
    } finally {
      finishLoading();
    }
  }

  select.addEventListener('change', () => {
    document.getElementById('postal-code-status').textContent = '';
    loadPrefix();
  });

  function saveView() {
    if (!ready || !loadedPrefix) return;
    const center = map.getCenter();
    const state = new URLSearchParams({
      prefix: loadedPrefix,
      lat: center.lat.toFixed(5),
      lng: center.lng.toFixed(5),
      zoom: String(map.getZoom())
    });
    if (selectedCode) state.set('cp', selectedCode);
    // Address queries and markers deliberately stay out of the shared URL.
    window.history.replaceState(null, '', `#${state}`);
  }

  map.on('moveend', saveView);

  function selectCode(code, fit = true) {
    map.closePopup();
    let match;
    postal.eachLayer(layer => {
      if (layer.feature.properties.COD_POSTAL === code) match = layer;
      postal.resetStyle(layer);
    });
    if (!match) {
      selectedCode = undefined;
      saveView();
      return false;
    }
    selectedCode = code;
    match.setStyle(selectedStyle).bringToFront();
    if (fit) map.fitBounds(match.getBounds(), { padding: [24, 24], maxZoom: 16 });
    match.openPopup();
    document.getElementById('postal-code').value = code;
    document.getElementById('postal-code-status').textContent =
      `CP ${code}: área estimada seleccionada.`;
    saveView();
    return true;
  }

  let codeSearch = 0;
  document.getElementById('postal-search').addEventListener('submit', async event => {
    event.preventDefault();
    const search = ++codeSearch;
    const code = document.getElementById('postal-code').value.trim();
    const codeStatus = document.getElementById('postal-code-status');
    if (!/^\d{5}$/.test(code)) {
      codeStatus.textContent = 'Introduce un código postal de cinco dígitos.';
      return;
    }
    if (select.disabled) {
      codeStatus.textContent = 'Espera a que cargue el catálogo de prefijos.';
      return;
    }
    const prefix = code.slice(0, 2);
    if (![...select.options].some(option => option.value === prefix)) {
      codeStatus.textContent = `El prefijo ${prefix} no está disponible en el visor.`;
      return;
    }
    codeStatus.textContent = `Buscando CP ${code}…`;
    if (loadedPrefix !== prefix) {
      select.value = prefix;
      if (!await loadPrefix() || search !== codeSearch) {
        codeStatus.textContent = 'No se ha completado la búsqueda. Vuelve a intentarlo.';
        return;
      }
    }
    if (!selectCode(code)) {
      codeStatus.textContent = `El CP ${code} no está en las áreas publicadas. Esto no implica que no exista.`;
    }
  });

  document.getElementById('share-view').addEventListener('click', async () => {
    saveView();
    const shareStatus = document.getElementById('share-status');
    const field = document.getElementById('share-url');
    field.value = window.location.href;
    field.hidden = false;
    try {
      await navigator.clipboard.writeText(field.value);
      shareStatus.textContent = 'Enlace copiado. No incluye direcciones buscadas.';
    } catch {
      field.focus();
      field.select();
      shareStatus.textContent = 'Copia el enlace del campo para compartir esta vista.';
    }
  });

  const addressForm = document.getElementById('address-search');
  const addressQuery = document.getElementById('address-query');
  const addressStatus = document.getElementById('address-status');
  const addressResults = document.getElementById('address-results');

  let addressRequest;
  let locationRequest;
  let addressMarker;
  let addressSelection = 0;

  function hasCoordinates(value) {
    return value != null
      && Number.isFinite(value.lat)
      && Number.isFinite(value.lng)
      && Math.abs(value.lat) <= 90
      && Math.abs(value.lng) <= 180
      && !(value.lat === 0 && value.lng === 0);
  }

  async function showAddress(candidate) {
    const selection = ++addressSelection;

    locationRequest?.abort();

    const current = new AbortController();
    locationRequest = current;

    const timeout = setTimeout(() => current.abort(), 15000);
    addressStatus.textContent = 'Localizando dirección…';
    const finishLoading = beginLoading('Localizando dirección…');

    try {
      let location = candidate;

      // Algunas calles llegan con coordenadas provisionales 0,0.
      // En ese caso se consulta su ubicación real mediante /find.
      if (!hasCoordinates(location)) {
        if (candidate.id == null || !candidate.type) {
          throw new Error('Falta el identificador de la dirección');
        }

        const url = new URL(
          'https://www.cartociudad.es/geocoder/api/geocoder/find'
        );

        url.searchParams.set('id', candidate.id);
        url.searchParams.set('type', candidate.type);

        const response = await fetch(url, {
          signal: current.signal
        });

        if (!response.ok) {
          throw new Error('No se ha podido localizar');
        }

        location = await response.json();
      }

      if (selection !== addressSelection || current.signal.aborted) {
        return;
      }

      if (!hasCoordinates(location)) {
        throw new Error('Coordenadas no disponibles');
      }

      clearTimeout(timeout);

      const code = String(
        location.postalCode || candidate.postalCode || ''
      );

      const province = String(
        location.provinceCode || candidate.provinceCode || ''
      );

      const prefix = /^\d{5}$/.test(code)
        ? code.slice(0, 2)
        : (/^\d{2}$/.test(province) ? province : null);

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

      if (addressMarker) {
        addressMarker.remove();
      }

      const label = document.createElement('div');
      label.textContent =
        candidate.address +
        (code ? ` · CP ${code} (CartoCiudad)` : '');

      addressMarker = L.marker([location.lat, location.lng], {
        alt: 'Dirección localizada', title: 'Dirección localizada'
      })
        .addTo(map)
        .bindPopup(label);

      map.setView([location.lat, location.lng], 16);
      addressMarker.openPopup();

      addressResults.hidden = true;

      addressStatus.textContent = 'Dirección localizada.';

      if (!prefix || !loaded) {
        addressStatus.textContent +=
          ' No se han cargado las áreas postales de esta dirección; comprueba el selector de prefijo.';
      } else if (!/^\d{5}$/.test(code)) {
        addressStatus.textContent +=
          ` CartoCiudad no devuelve un código postal; se muestran como referencia los polígonos del prefijo ${prefix}, a partir de la provincia.`;
      }
    } catch {
      if (selection === addressSelection) {
        addressStatus.textContent =
          'No se ha podido localizar esta dirección. Elige otro resultado o vuelve a intentarlo.';
      }
    } finally {
      clearTimeout(timeout);
      finishLoading();
    }
  }

  addressForm.addEventListener('submit', async event => {
    event.preventDefault();

    const query = addressQuery.value.trim();

    if (query.length < 3) {
      addressStatus.textContent =
        'Introduce al menos tres caracteres.';
      return;
    }

    addressRequest?.abort();
    locationRequest?.abort();
    ++addressSelection;

    const current = new AbortController();
    addressRequest = current;

    const timeout = setTimeout(() => current.abort(), 15000);

    addressResults.replaceChildren();
    addressResults.hidden = true;
    addressStatus.textContent = 'Buscando direcciones…';
    addressForm.setAttribute('aria-busy', 'true');
    const finishLoading = beginLoading('Buscando direcciones…');

    try {
      const url = new URL(
        'https://www.cartociudad.es/geocoder/api/geocoder/candidates'
      );

      url.searchParams.set('q', query);
      url.searchParams.set('limit', '5');

      const response = await fetch(url, {
        signal: current.signal
      });

      if (!response.ok) {
        throw new Error('Servicio no disponible');
      }

      const data = await response.json();

      if (addressRequest !== current || current.signal.aborted) {
        return;
      }

      if (!Array.isArray(data)) {
        throw new Error('Respuesta no válida');
      }

      const candidates = data.filter(item =>
        item &&
        typeof item.address === 'string' &&
        (
          hasCoordinates(item) ||
          (item.id != null && item.type)
        )
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

        button.addEventListener('click', () => {
          showAddress(candidate);
        });

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
      finishLoading();

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
        !prefixes.every(prefix => /^\d{2}$/.test(prefix))
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
          name ? `${prefix} · ${name}` : prefix,
          prefix
        );
      }));

      select.value = prefixes.includes(saved.get('prefix'))
        ? saved.get('prefix')
        : (prefixes.includes('08') ? '08' : prefixes[0]);
      select.disabled = false;

      const loaded = await loadPrefix({ fit: !savedView });
      if (savedView) {
        map.setView([Number(saved.get('lat')), Number(saved.get('lng'))], Number(saved.get('zoom')));
      }
      if (loaded && /^\d{5}$/.test(saved.get('cp') || '')) {
        if (!selectCode(saved.get('cp'), !savedView)) {
          document.getElementById('postal-code-status').textContent =
            'El CP del enlace no está en las áreas del prefijo seleccionado.';
        }
      }
      ready = true;
      saveView();
    } catch {
      status.dataset.state = 'error';
      status.textContent =
        'No se ha podido cargar el catálogo de prefijos. Recarga la página para reintentar.';
    }
  })();
  // Tabs, ayuda del prefijo y cierre de leyenda.
  (function initUI() {
    const tabCp = document.getElementById('tab-cp');
    const tabAddress = document.getElementById('tab-address');
    const panelCp = document.getElementById('panel-cp');
    const panelAddress = document.getElementById('panel-address');
    const helpBtn = document.querySelector('.help-toggle');
    const helpText = document.getElementById('postal-prefix-help');
    const legend = document.querySelector('.postal-legend');
    const controls = document.getElementById('viewer-controls');
    const mobile = window.matchMedia('(max-width: 600px)');
    const syncControls = () => { controls.open = !mobile.matches; };
    syncControls();
    mobile.addEventListener('change', syncControls);
    controls.addEventListener('toggle', () => map.invalidateSize({ pan: false }));
    const legendTrigger = legend.querySelector('summary');
    document.getElementById('legend-close').addEventListener('click', () => {
      legend.open = false;
      legendTrigger.focus();
    });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && legend.open) {
        legend.open = false;
        legendTrigger.focus();
      }
    });

    function switchTab(target) {
      const isCp = target === 'cp';
      tabCp.classList.toggle('active', isCp);
      tabAddress.classList.toggle('active', !isCp);
      tabCp.setAttribute('aria-selected', isCp);
      tabAddress.setAttribute('aria-selected', !isCp);
      tabCp.tabIndex = isCp ? 0 : -1;
      tabAddress.tabIndex = isCp ? -1 : 0;
      panelCp.classList.toggle('active', isCp);
      panelAddress.classList.toggle('active', !isCp);
      panelCp.hidden = !isCp;
      panelAddress.hidden = isCp;
    }

    tabCp?.addEventListener('click', () => switchTab('cp'));
    tabAddress?.addEventListener('click', () => switchTab('address'));

    // Teclado en tabs
    [tabCp, tabAddress].forEach(tab => {
      tab?.addEventListener('keydown', e => {
        let target;
        if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
          target = tab === tabCp ? tabAddress : tabCp;
        } else if (e.key === 'Home') {
          target = tabCp;
        } else if (e.key === 'End') {
          target = tabAddress;
        } else {
          return;
        }
        e.preventDefault();
        switchTab(target === tabCp ? 'cp' : 'address');
        target.focus();
      });
    });

    // Botón de ayuda del prefijo
    helpBtn?.addEventListener('click', () => {
      const open = helpText.hidden;
      helpText.hidden = !open;
      helpBtn.setAttribute('aria-expanded', open);
    });

    // Cerrar leyenda al hacer clic fuera
    document.addEventListener('click', e => {
      if (legend?.open && !legend.contains(e.target)) {
        legend.open = false;
      }
    }, true);
  })();
})();
