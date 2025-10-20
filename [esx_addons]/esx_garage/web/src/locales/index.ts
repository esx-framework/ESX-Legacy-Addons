import type { Locale, LocaleCode } from '@/types/locale.types';
import { de } from './de';
import { en } from './en';

export const locales: Record<LocaleCode, Locale> = {
  de: {
    code: 'de',
    name: 'Deutsch',
    translations: de
  },
  en: {
    code: 'en',
    name: 'English',
    translations: en
  },
  fr: {
    code: 'fr',
    name: 'Français',
    translations: en
  },
  es: {
    code: 'es',
    name: 'Español',
    translations: en
  },
  pl: {
    code: 'pl',
    name: 'Polski',
    translations: en
  },
  ru: {
    code: 'ru',
    name: 'Русский',
    translations: en
  }
};

export const getLocale = (code: LocaleCode): Locale => {
  return locales[code] ?? locales.en;
};

export const getBrowserLocale = (): LocaleCode => {
  const browserLang = navigator.language.split('-')[0] as LocaleCode;
  return locales[browserLang] ? browserLang : 'en';
};
