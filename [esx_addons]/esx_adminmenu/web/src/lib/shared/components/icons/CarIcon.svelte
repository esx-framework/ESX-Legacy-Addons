<script lang="ts">
  const { class: className } = $props<{ class?: string }>();
</script>

<svg class={`data-component-icon ${className ?? ""}`} viewBox="0 0 384 384" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="m340 64l44 128v171q0 8-6.5 14.5T363 384h-22q-8 0-14.5-6.5T320 363v-22H64v22q0 8-6.5 14.5T43 384H21q-8 0-14.5-6.5T0 363V192L44 64q8-21 31-21h234q23 0 31 21zM74.5 277q13.5 0 23-9t9.5-22.5t-9.5-23t-23-9.5t-22.5 9.5t-9 23t9 22.5t22.5 9zm235 0q13.5 0 22.5-9t9-22.5t-9-23t-22.5-9.5t-23 9.5t-9.5 23t9.5 22.5t23 9zM43 171h298l-32-96H75z" fill="currentColor"/>
</svg>
