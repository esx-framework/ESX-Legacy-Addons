<script lang="ts">
  /**
   * A large amount: the number in full size, the currency symbol smaller and quieter in front,
   * the way price tags set it.
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

<span class="money"><span class="currency">{currency}</span>{formatNumber(amount, locale)}</span>

<style>
  .money {
    font-size: 40px;
    font-weight: 700;
    line-height: 1.05;
    letter-spacing: -0.015em;
    font-variant-numeric: tabular-nums;
  }

  .currency {
    margin-right: 3px;
    font-size: 0.6em;
    font-weight: 600;
    color: var(--light-color);
    vertical-align: 0.5em;
  }
</style>
