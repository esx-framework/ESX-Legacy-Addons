<script lang="ts">
  /**
   * A large amount: the number in full size, the currency symbol smaller and quieter in front of
   * it and centred on the height of the digits, the way checkout pages set a total.
   */
  import { formatNumber } from '../lib/payment/format';

  interface Props {
    /** Amount in whole units */
    amount: number;
    /** Currency symbol */
    currency: string;
    /** Locale the number is grouped by */
    locale: string;
  }

  let { amount, currency, locale }: Props = $props();
</script>

<span class="money">
  <span class="currency">{currency}</span>
  <span class="value">{formatNumber(amount, locale)}</span>
</span>

<style>
  .money {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 38px;
    font-weight: 600;
    line-height: 1;
    letter-spacing: -0.01em;
    font-variant-numeric: tabular-nums;
  }

  .currency {
    font-size: 0.5em;
    font-weight: 500;
    letter-spacing: 0;
    color: var(--light-color);
  }
</style>
