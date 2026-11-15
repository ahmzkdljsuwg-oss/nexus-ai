import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import { createClient, friendlyError, normaliseBaseUrl } from '../api/client';

const AppContext = createContext(null);
const BASE_KEY = 'nexus.baseUrl';
const LANG_KEY = 'nexus.language';

export function AppProvider({ children }) {
  const configured = process.env.EXPO_PUBLIC_API_BASE_URL || Constants.expoConfig?.extra?.apiBaseUrl || '';
  const [baseUrl, setBaseUrl] = useState(normaliseBaseUrl(configured));
  const [language, setLanguageState] = useState('en');
  const [ready, setReady] = useState(false);
  const [connection, setConnection] = useState({ state: 'unconfigured', detail: 'Backend URL is not configured.', latency: null });
  const [overview, setOverview] = useState(null);
  const [marketsState, setMarketsState] = useState('idle');
  const [lastUpdated, setLastUpdated] = useState(null);
  const baseRef = useRef(baseUrl);

  baseRef.current = baseUrl;
  const client = useMemo(() => createClient(() => baseRef.current), []);

  useEffect(() => {
    (async () => {
      const [savedUrl, savedLang] = await Promise.all([
        AsyncStorage.getItem(BASE_KEY),
        AsyncStorage.getItem(LANG_KEY),
      ]);
      if (savedUrl) setBaseUrl(normaliseBaseUrl(savedUrl));
      if (savedLang === 'ar' || savedLang === 'en') setLanguageState(savedLang);
      setReady(true);
    })().catch(() => setReady(true));
  }, []);

  const checkHealth = useCallback(async () => {
    if (!normaliseBaseUrl(baseRef.current)) {
      setConnection({ state: 'unconfigured', detail: 'Backend URL is not configured.', latency: null });
      return false;
    }
    setConnection((current) => ({ ...current, state: current.state === 'online' ? 'online' : 'checking' }));
    const started = Date.now();
    try {
      const response = await client.health();
      const ok = response.data?.status === 'ok';
      const detail = ok ? 'Backend answered /api/health.' : 'Backend is reachable but reports DEGRADED.';
      setConnection({ state: ok ? 'online' : 'degraded', detail, latency: Date.now() - started });
      return ok;
    } catch (error) {
      setConnection({ state: 'offline', detail: friendlyError(error), latency: null });
      return false;
    }
  }, [client]);

  const refreshMarkets = useCallback(async () => {
    if (!normaliseBaseUrl(baseRef.current)) return;
    setMarketsState((state) => (state === 'idle' ? 'loading' : 'refreshing'));
    try {
      const response = await client.markets();
      setOverview(response.data);
      setLastUpdated(new Date().toISOString());
      setMarketsState('ready');
      setConnection((current) =>
        current.state === 'online' || current.state === 'degraded'
          ? current
          : { state: 'online', detail: 'Backend answered /api/markets.', latency: current.latency },
      );
    } catch (error) {
      setMarketsState('error');
      setConnection({ state: 'offline', detail: friendlyError(error), latency: null });
    }
  }, [client]);

  const refresh = useCallback(async () => {
    const ok = await checkHealth();
    if (ok) await refreshMarkets();
  }, [checkHealth, refreshMarkets]);

  useEffect(() => {
    if (!ready) return undefined;
    refresh();
    const timer = setInterval(() => {
      if (baseRef.current) refresh();
    }, 30000);
    return () => clearInterval(timer);
  }, [ready, refresh]);

  const saveBaseUrl = useCallback(async (value) => {
    const clean = normaliseBaseUrl(value);
    if (!clean) throw new Error('Enter a full http(s) backend URL.');
    setBaseUrl(clean);
    await AsyncStorage.setItem(BASE_KEY, clean);
    setTimeout(refresh, 50);
  }, [refresh]);

  const setLanguage = useCallback(async (next) => {
    setLanguageState(next);
    await AsyncStorage.setItem(LANG_KEY, next);
  }, []);

  const value = useMemo(() => ({
    ready,
    baseUrl,
    language,
    setLanguage,
    saveBaseUrl,
    connection,
    overview,
    marketsState,
    lastUpdated,
    refresh,
    checkHealth,
    client,
  }), [ready, baseUrl, language, setLanguage, saveBaseUrl, connection, overview, marketsState, lastUpdated, refresh, checkHealth, client]);

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() {
  const value = useContext(AppContext);
  if (!value) throw new Error('useApp must be used inside AppProvider');
  return value;
}
