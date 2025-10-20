import React, { createContext, useContext, useState, useCallback, useEffect, type PropsWithChildren } from 'react';
import type { LocaleCode, LocaleTranslations } from '@/types/locale.types';
import { getLocale, getBrowserLocale } from '@/locales';
import { useNuiEvent } from '@/hooks/useNuiEvent';

interface LocaleContextValue {
  locale: LocaleCode;
  translations: LocaleTranslations;
  setLocale: (code: LocaleCode) => void;
  t: (key: string) => string;
}

const LocaleContext = createContext<LocaleContextValue | null>(null);

export const useLocale = () => {
  const context = useContext(LocaleContext);
  if (!context) {
    throw new Error('useLocale must be used within LocaleProvider');
  }
  return context;
};

export const LocaleProvider: React.FC<PropsWithChildren> = ({ children }) => {
  const [locale, setLocaleState] = useState<LocaleCode>(getBrowserLocale());
  const [translations, setTranslations] = useState<LocaleTranslations>(
    getLocale(getBrowserLocale()).translations
  );

  const setLocale = useCallback((code: LocaleCode) => {
    const newLocale = getLocale(code);
    setLocaleState(code);
    setTranslations(newLocale.translations);
    localStorage.setItem('esx_garages:locale', code);
  }, []);

  const t = useCallback((key: string): string => {
    const keys = key.split('.');
    let value: any = translations;

    for (const k of keys) {
      if (value && typeof value === 'object' && k in value) {
        value = value[k];
      } else {
        console.warn(`[i18n] Missing translation key: ${key}`);
        return key;
      }
    }

    return typeof value === 'string' ? value : key;
  }, [translations]);

  useNuiEvent<LocaleCode>('setLocale', (code) => {
    setLocale(code);
  });

  useNuiEvent<Record<string, any>>('setTranslations', (customTranslations) => {
    setTranslations(customTranslations as LocaleTranslations);
  });

  useEffect(() => {
    const savedLocale = localStorage.getItem('esx_garages:locale') as LocaleCode;
    if (savedLocale && getLocale(savedLocale)) {
      setLocale(savedLocale);
    }
  }, [setLocale]);

  const value: LocaleContextValue = {
    locale,
    translations,
    setLocale,
    t
  };

  return (
    <LocaleContext.Provider value={value}>
      {children}
    </LocaleContext.Provider>
  );
};
