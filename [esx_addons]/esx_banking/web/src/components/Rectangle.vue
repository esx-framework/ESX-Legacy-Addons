<template>
  <div class="rectangle">
    <TabBar @view-change="handleViewChange" />
    <Overview v-if="currentView === 'overview'" />
    <Accounts v-if="currentView === 'accounts'" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import TabBar from './TabBar.vue';
import Overview from './Overview.vue';
import Accounts from './Accounts.vue';

const currentView = ref('overview');

const handleViewChange = (view: string) => {
  currentView.value = view;
};
</script>

<style scoped>
.rectangle {
  width: 1200px;
  height: 800px;
  background-color: #1B1B1B;
  border-radius: 12px;
  position: relative;
  overflow: hidden;
  margin: 20px;
}
</style> 