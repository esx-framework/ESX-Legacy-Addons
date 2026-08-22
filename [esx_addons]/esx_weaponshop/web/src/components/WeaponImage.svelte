<!--
  @component WeaponImage
  Loads and displays a weapon image with a skeleton placeholder
-->
<script lang="ts">
  import { shopStore } from '@stores/shopStore.svelte';
  import { resolveWeaponImage } from '@utils/weaponImage';

  interface Props {
    name: string;
    image: string;
    alt: string;
  }

  let { name, image, alt }: Props = $props();

  let src = $state('');
  let loaded = $state(false);
  let missing = $state(false);

  $effect(() => {
    const weaponName = name;
    const weaponImage = image;
    loaded = false;
    missing = false;
    src = '';
    let cancelled = false;

    void resolveWeaponImage(weaponName, weaponImage).then((url) => {
      if (cancelled) {
        return;
      }

      loaded = true;

      if (url) {
        src = url;
        return;
      }

      missing = true;
    });

    return () => {
      cancelled = true;
    };
  });

  /**
   * Treats a failed image load as a missing asset
   */
  function handleImageError(): void {
    src = '';
    missing = true;
  }
</script>

<div class="weapon-image">
  {#if !loaded}
    <div class="image-skeleton"></div>
  {/if}
  {#if src}
    <img {src} {alt} class:loaded onerror={handleImageError} />
  {:else if missing}
    <div class="missing">{shopStore.locales.noImageAvailable}</div>
  {/if}
</div>

<style>
  .weapon-image {
    position: relative;
    display: flex;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
  }

  img {
    width: 100%;
    height: 100%;
    object-fit: contain;
    opacity: 0;
    transition: opacity 0.3s ease;
  }

  img.loaded {
    opacity: 1;
  }

  .missing {
    color: var(--light-color);
    font-size: 0.72rem;
    font-weight: 500;
    text-align: center;
    padding: 0.4rem;
    line-height: 1.3;
  }

  .image-skeleton {
    position: absolute;
    inset: 0;
    background: linear-gradient(
      90deg,
      rgba(var(--lightest-color-rgb), 0.05) 25%,
      rgba(var(--lightest-color-rgb), 0.1) 50%,
      rgba(var(--lightest-color-rgb), 0.05) 75%
    );
    background-size: 200% 100%;
    animation: skeleton-loading 1.5s ease-in-out infinite;
    border-radius: 0.3rem;
  }

  @keyframes skeleton-loading {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
</style>
