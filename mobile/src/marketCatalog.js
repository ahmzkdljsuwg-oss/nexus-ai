import { MARKET_COPY } from './i18n';

// Offline placeholders keep every market reachable while the backend is
// unreachable. They never carry a price: status stays UNAVAILABLE until a
// verified server response replaces them.
const META = {
  OTC: { icon: '🌐', accent: '#4ADE80' },
  SMARTY: { icon: '🧠', accent: '#38BDF8' },
  FOOTBALL: { icon: '⚽', accent: '#F59E0B' },
  LUXURY: { icon: '💎', accent: '#E879F9' },
  AI: { icon: '🤖', accent: '#A78BFA' },
  CRICKET: { icon: '🏏', accent: '#34D399' },
  FOREX: { icon: '💱', accent: '#22D3EE' },
};

export const MARKET_ORDER = Object.keys(META);

export function fallbackMarkets() {
  return MARKET_ORDER.map((key) => ({
    key,
    label: MARKET_COPY[key]?.en || key,
    icon: META[key].icon,
    accent: META[key].accent,
    status: 'UNAVAILABLE',
    source: 'NONE',
    price: null,
    price_display: '—',
    asset: null,
    assets: [],
  }));
}
