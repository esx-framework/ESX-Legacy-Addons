import { reactive, computed, onMounted, onBeforeUnmount, toRefs } from 'vue';

function clamp(n, min, max) { return Math.max(min, Math.min(max, n)); }

export function useGarage() {
  const state = reactive({
    visible: false,
    tab: 'garage',
    vehicles: [],
    impoundedVehicles: [],
    searchGarage: '',
    searchImpounded: '',
    spawnPoint: null,
    poundCost: 0,
    poundName: '',
    poundSpawnPoint: null,
    impoundOnly: false,
    locales: {
      garage_title: 'Garage',
      garage_tab: 'Garage',
      impounded_tab: 'Impounded',
      veh_model: 'Model',
      veh_plate: 'Plate',
      veh_condition: 'Condition',
      action: 'Retrieve',
      impound_action: 'Release',
      no_veh_parking: 'No Vehicles Stored Here.',
      no_veh_impounded: 'No Impounded Vehicles.',
      search_placeholder: 'Search by model or plate…'
    }
  });

  const filteredGarage = computed(() => {
    const q = state.searchGarage.trim().toLowerCase();
    if (!q) return state.vehicles;
    return state.vehicles.filter(v => (String(v.model||'').toLowerCase().includes(q) || String(v.plate||'').toLowerCase().includes(q)));
  });

  const filteredImpounded = computed(() => {
    const q = state.searchImpounded.trim().toLowerCase();
    if (!q) return state.impoundedVehicles;
    return state.impoundedVehicles.filter(v => (String(v.model||'').toLowerCase().includes(q) || String(v.plate||'').toLowerCase().includes(q)));
  });

  function damagePercent(veh) {
    const p = veh.props || {};
    const b = clamp(((typeof p.bodyHealth === 'number' ? p.bodyHealth : 1000) / 1000) * 100, 0, 100);
    const e = clamp(((typeof p.engineHealth === 'number' ? p.engineHealth : 1000) / 1000) * 100, 0, 100);
    const t = clamp(((typeof p.tankHealth === 'number' ? p.tankHealth : 1000) / 1000) * 100, 0, 100);
    return clamp(Math.round(((b + e + t) / 300) * 100), 0, 100);
  }

  function post(endpoint, payload) {
    fetch(`https://esx_garage/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload || {})
    });
  }

  function openMenu(data) {
    state.visible = true;
    state.impoundOnly = data.type === 'impound';
    state.tab = state.impoundOnly ? 'impounded' : 'garage';
    if (data.locales) Object.assign(state.locales, data.locales);
    state.spawnPoint = data.spawnPoint || null;
    if (typeof data.poundCost === 'number') state.poundCost = data.poundCost;
    const safeParse = (label, raw) => {
      if (!raw) return [];
      if (typeof raw === 'object') return Array.isArray(raw) ? raw.slice() : raw;
      if (Array.isArray(raw)) {
        raw = raw[0];
      }
      if (typeof raw !== 'string') return [];
      return JSON.parse(raw);
    };

    state.vehicles = safeParse('vehiclesList', data.vehiclesList);
    state.impoundedVehicles = safeParse('vehiclesImpoundedList', data.vehiclesImpoundedList);
    state.poundName = data.poundName || '';
    state.poundSpawnPoint = data.poundSpawnPoint || null;
  }

  function hideAll() {
    state.visible = false;
    state.searchGarage = '';
    state.searchImpounded = '';
  }

  function spawnVehicle(veh) {
    post('spawnVehicle', {
      vehicleProps: veh.props,
      spawnPoint: state.spawnPoint,
      exitVehicleCost: state.poundCost || 0
    });
    hideAll();
  }

  function impoundVehicle(veh) {
    post('impound', {
      vehicleProps: veh.props,
      poundName: state.poundName,
      poundSpawnPoint: state.poundSpawnPoint
    });
    hideAll();
  }

  function closeUI() {
    post('escape', {});
    hideAll();
  }

  function onMessage(e) {
    const data = e.data || {};
    if (!data.showMenu && !data.hideAll) return;
    if (data.showMenu) openMenu(data);
    else if (data.hideAll) hideAll();
  }

  function onKey(e) {
    if (e.key === 'Escape' && state.visible) {
      closeUI();
    }
  }

  onMounted(() => {
    window.addEventListener('message', onMessage);
    window.addEventListener('keyup', onKey);
  });

  onBeforeUnmount(() => {
    window.removeEventListener('message', onMessage);
    window.removeEventListener('keyup', onKey);
  });

  return {
    ...toRefs(state),
    filteredGarage,
    filteredImpounded,
    damagePercent,
    spawnVehicle,
    impoundVehicle,
    closeUI
  };
}

export default useGarage;
