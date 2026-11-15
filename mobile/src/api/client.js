import axios from 'axios';

export function normaliseBaseUrl(value) {
  const raw = String(value || '').trim().replace(/\/+$/, '');
  if (!raw) return '';
  if (!/^https?:\/\//i.test(raw)) return '';
  return raw;
}

export function friendlyError(error) {
  if (error?.code === 'ECONNABORTED') return 'The server did not answer in time.';
  const status = error?.response?.status;
  const detail = error?.response?.data?.detail;
  if (typeof detail === 'string') return detail;
  if (detail?.message) return detail.message;
  if (status === 404) return 'Backend route not found. Check the server URL and deployment.';
  if (status === 503) return detail?.message || 'Verified data is unavailable right now.';
  if (status) return `Server error (${status}).`;
  return 'Cannot reach the backend. Check the server URL and connection.';
}

export function createClient(getBaseUrl) {
  const http = axios.create({ timeout: 25000, headers: { Accept: 'application/json' } });

  async function call(path, options = {}) {
    const base = normaliseBaseUrl(getBaseUrl());
    if (!base) {
      const error = new Error('Backend URL is not configured.');
      error.code = 'NO_BASE_URL';
      throw error;
    }
    return http.request({ baseURL: base, url: path, ...options });
  }

  return {
    health: () => call('/api/health', { timeout: 8000 }),
    markets: () => call('/api/markets', { timeout: 30000 }),
    market: (key, assetKey) =>
      call(`/api/markets/${encodeURIComponent(key)}${assetKey ? `?asset=${encodeURIComponent(assetKey)}` : ''}`, { timeout: 30000 }),
    analyse: (body) => call('/api/analyse', { method: 'POST', data: body, timeout: 90000 }),
    recommendations: () => call('/api/recommendations', { timeout: 20000 }),
    history: (limit = 50) => call(`/api/history?limit=${limit}`, { timeout: 20000 }),
    chat: (body) => call('/api/chat', { method: 'POST', data: body, timeout: 60000 }),
  };
}
