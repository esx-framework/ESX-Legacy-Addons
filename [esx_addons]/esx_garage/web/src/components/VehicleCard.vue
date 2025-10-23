<script setup>
import { computed } from 'vue';

const props = defineProps({
  veh: { type: Object, required: true },
  locales: { type: Object, required: true },
  damagePercent: { type: Function, required: true },
  action: { type: Function, required: true },
  actionType: { type: String, default: 'spawn' },
  poundCost: { type: Number, default: 0 }
});

const emit = defineEmits(['action']);

function handleClick() {
  emit('action', props.veh);
}

const isImpound = computed(() => props.actionType === 'impound');
const dmg = computed(() => props.damagePercent(props.veh));
</script>

<template>
  <div class="vehicle-listing" :data-model="(veh.model||'').toLowerCase()" :data-plate="(veh.plate||'').toLowerCase()">
    <div>{{ locales.veh_model }}: <strong>{{ veh.model }}</strong></div>
    <div>{{ locales.veh_plate }}: <strong>{{ veh.plate }}</strong></div>
    <div class="condition">
      <span>{{ locales.veh_condition }}</span>
      <div class="bar"><div class="fill" :style="{width: dmg + '%'}"></div></div>
      <strong class="percent">{{ dmg }}%</strong>
    </div>
    <button
      class="vehicle-action unstyled-button"
      :class="{ red: isImpound }"
      @click="handleClick"
    >
      <template v-if="!isImpound">
        {{ locales.action }}<span v-if="poundCost && poundCost>0"> (${{ poundCost }})</span>
      </template>
      <template v-else>
        {{ locales.impound_action }}
      </template>
    </button>
  </div>
</template>
