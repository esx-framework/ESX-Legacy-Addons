<script setup>
import { computed } from 'vue';
import { useGarage } from '../composables/useGarage';
import logo from '@/assets/logo.png';
import VehicleCard from './VehicleCard.vue';

const {
  visible,
  tab,
  searchGarage,
  searchImpounded,
  poundCost,
  locales,
  impoundOnly,
  filteredGarage,
  filteredImpounded,
  damagePercent,
  spawnVehicle,
  impoundVehicle,
  closeUI
} = useGarage();

function switchTab(next) { if (!impoundOnly.value) tab.value = next; }

const garageAriaLabel = computed(() => locales.garage_tab + ' vehicles list');
const impoundedAriaLabel = computed(() => locales.impounded_tab + ' vehicles list');
</script>

<template>
  <div id="container" role="dialog" v-show="visible" style="display:grid;">
    <div id="header">
      <div class="title" id="garage-title">{{ locales.garage_title }}</div>
      <ul role="tablist" v-show="!impoundOnly">
        <li :class="{selected: tab==='garage'}" role="tab" @click="switchTab('garage')">{{ locales.garage_tab }}</li>
        <li :class="{selected: tab==='impounded'}" role="tab" @click="switchTab('impounded')">{{ locales.impounded_tab }}</li>
      </ul>
      <img class="logo-left" :src="logo" alt="ESX logo" />
      <button class="close" title="Close" @click="closeUI">×</button>
    </div>

    <div id="menu">
      <!-- Garage Tab -->
      <div class="content" role="tabpanel" v-show="tab==='garage'">
        <div class="toolbar">
          <input id="search-garage" type="search" :placeholder="locales.search_placeholder" v-model="searchGarage" />
        </div>
        <h2 class="empty" v-show="!filteredGarage.length">{{ locales.no_veh_parking }}</h2>
        <div class="vehicle-list" :aria-label="garageAriaLabel">
          <VehicleCard
            v-for="veh in filteredGarage"
            :key="veh.plate"
            :veh="veh"
            :locales="locales"
            :damagePercent="damagePercent"
            :action="spawnVehicle"
            action-type="spawn"
            :poundCost="poundCost"
            @action="spawnVehicle"
          />
        </div>
      </div>

      <div class="impounded_content" role="tabpanel" v-show="tab==='impounded'">
        <div class="toolbar">
          <input id="search-impounded" type="search" :placeholder="locales.search_placeholder" v-model="searchImpounded" />
        </div>
        <h2 class="empty" v-show="!filteredImpounded.length">{{ locales.no_veh_impounded }}</h2>
        <div class="vehicle-list" :aria-label="impoundedAriaLabel">
          <VehicleCard
            v-for="veh in filteredImpounded"
            :key="veh.plate"
            :veh="veh"
            :locales="locales"
            :damagePercent="damagePercent"
            :action="impoundVehicle"
            action-type="impound"
            @action="impoundVehicle"
          />
        </div>
      </div>
    </div>
  </div>
</template>
