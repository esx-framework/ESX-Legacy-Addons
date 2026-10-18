<script lang="ts">
  /**
   * The mark of a payment that went through: the circle pops in, the check draws itself and a
   * ring pulses out once.
   */
</script>

<div class="mark" aria-hidden="true">
  <span class="pulse"></span>
  <svg viewBox="0 0 64 64" width="64" height="64">
    <circle class="disc" cx="32" cy="32" r="29" />
    <path class="check" d="M20 33.5 L28.5 42 L44.5 24.5" />
  </svg>
</div>

<style>
  .mark {
    position: relative;
    display: grid;
    place-items: center;
    width: 64px;
    height: 64px;
    animation: mark-in 420ms cubic-bezier(0.3, 1.5, 0.5, 1) backwards;
  }

  .disc {
    fill: rgba(var(--brand-color-rgb), 0.14);
    stroke: var(--brand-color);
    stroke-width: 3;
  }

  .check {
    fill: none;
    stroke: var(--brand-color);
    stroke-width: 5;
    stroke-linecap: round;
    stroke-linejoin: round;
    stroke-dasharray: 40;
    stroke-dashoffset: 40;
    animation: draw 380ms cubic-bezier(0.65, 0, 0.35, 1) 160ms forwards;
  }

  .pulse {
    position: absolute;
    inset: 0;
    border: 2px solid var(--brand-color);
    border-radius: 50%;
    opacity: 0;
    animation: pulse 900ms ease-out 220ms;
  }

  @keyframes mark-in {
    from {
      opacity: 0;
      transform: scale(0.55);
    }
  }

  @keyframes draw {
    to {
      stroke-dashoffset: 0;
    }
  }

  @keyframes pulse {
    from {
      opacity: 0.7;
      transform: scale(1);
    }
    to {
      opacity: 0;
      transform: scale(1.7);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .mark,
    .pulse {
      animation: none;
    }

    .check {
      animation: none;
      stroke-dashoffset: 0;
    }
  }
</style>
