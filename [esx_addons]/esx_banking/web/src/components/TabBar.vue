<template>
  <div class="tab-bar">
    <div class="title">
      <img src="/src/svg/common/esxLogo.png" alt="ESX" class="logo" />
    </div>
    <div class="buttons">
      <button class="nav-button" :class="{ active: currentView === 'overview' }" @click="navigate('overview')">
        <img src="/src/svg/overview.svg" alt="Overview" />
        <span>Overview</span>
      </button>
      <button class="nav-button" :class="{ active: currentView === 'accounts' }" @click="navigate('accounts')">
        <img src="/src/svg/account.svg" alt="Account" />
        <span>Accounts</span>
      </button>
    </div>
    <div class="logout">
      <button class="nav-button logout-button">
        <img src="/src/svg/logout.svg" alt="Logout" />
        <span>Logout</span>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const emit = defineEmits(['view-change']);
const currentView = ref('overview');

const navigate = (view: string) => {
  currentView.value = view;
  emit('view-change', view);
};
</script>

<style scoped>
.tab-bar {
  width: 170px;
  height: 100%;
  background-color: #2A2A2A;
  position: absolute;
  left: 0;
  top: 0;
  border-right: 1px solid #3A3A3A;
}

.title {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-bottom: 0;
  border-bottom: 1px solid #3A3A3A;
  width: 100%;
}

.logo {
  height: 64px;
  width: auto;
  margin-bottom: 0;
}

.buttons {
  position: absolute;
  top: 110px;
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 0 12px;
}

.nav-button {
  display: flex;
  align-items: center;
  gap: 8px;
  background: none;
  border: none;
  color: #E0E0E0;
  font-family: 'Poppins', sans-serif;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  padding: 10px 12px;
  border-radius: 8px;
  transition: all 0.2s ease;
}

.nav-button:hover {
  background-color: #1B1B1B;
  color: white;
}

.nav-button img {
  width: 24px;
  height: 24px;
}

.logout {
  position: absolute;
  bottom: 24px;
  width: 100%;
  padding: 0 12px;
}

.logout-button {
  color: #FF4444;
  gap: 4px;
  font-size: 17px;
  padding: 12px;
}

.logout-button img {
  width: 26.5px;
  height: 26.5px;
}

.logout-button:hover {
  background-color: rgba(255, 68, 68, 0.1);
}

.nav-button.active {
  background-color: #1B1B1B;
  color: white;
}
</style> 