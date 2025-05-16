<script setup lang="ts">
import Rectangle from './components/Rectangle.vue'
</script>

<template>
  <div class="app">
    <Rectangle />
  </div>
</template>

<style>
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap');

.app {
  width: 100vw;
  height: 100vh;
  margin: 0;
  padding: 0;
  display: flex;
  justify-content: center;
  align-items: center;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background: transparent;
}
</style>
