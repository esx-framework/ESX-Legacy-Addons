<script lang="ts">
  const { class: className } = $props<{ class?: string }>();
</script>

<svg class={`data-component-icon ${className ?? ""}`} viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M3 1.5H10L13 4.5V14.5H3V1.5Z" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M9.5 1.5V5H13" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M5.5 8H10.5M5.5 11H10.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
</svg>
