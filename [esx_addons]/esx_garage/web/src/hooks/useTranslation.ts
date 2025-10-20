import { useLocale } from '@/providers/LocaleProvider';

/**
 * Hook for accessing translation functionality.
 *
 * @returns {Object} Translation utilities
 * @property {function(string): string} t - Translate a key to the current locale
 * @property {string} locale - Current locale code
 * @property {Object} translations - All translations for the current locale
 * @property {function(string): void} setLocale - Change the active locale
 *
 * @example
 * ```typescript
 * const { t, locale, setLocale } = useTranslation();
 *
 * return (
 *   <div>
 *     <h1>{t('garage.title')}</h1>
 *     <button onClick={() => setLocale('de')}>Deutsch</button>
 *     <span>Current: {locale}</span>
 *   </div>
 * );
 * ```
 */
export const useTranslation = () => {
  const { locale, translations, setLocale, t } = useLocale();

  return {
    locale,
    translations,
    setLocale,
    t
  };
};
