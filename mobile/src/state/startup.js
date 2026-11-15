export const SPLASH_MIN_MS = 2200;
export const SPLASH_MAX_MS = 6500;

export function pickBaseUrl({ buildUrl, savedUrl }) {
  const clean = (value) => String(value || '').trim().replace(/\/+$/, '');
  const build = clean(buildUrl);
  const saved = clean(savedUrl);
  if (build && /^https?:\/\//i.test(build)) return build;
  if (saved && /^https?:\/\//i.test(saved)) return saved;
  return '';
}

export function splashCanFinish({ elapsed, ready, booting, forced }) {
  return Boolean(forced || (ready && elapsed && !booting));
}

export function splashStatus({ baseUrl, connection, booting, language }) {
  if (!baseUrl) {
    return language === 'ar'
      ? 'بانتظار نشر الخادم — التطبيق سيفتح بدون اتصال'
      : 'AWAITING SERVER DEPLOYMENT — OPENING OFFLINE';
  }
  if (booting || connection?.state === 'checking') {
    return language === 'ar' ? 'جارٍ الاتصال بنواة NEXUS' : 'CONNECTING TO NEXUS CORE';
  }
  if (connection?.state === 'online') {
    return language === 'ar' ? 'تم التحقق من الخادم' : 'SERVER VERIFIED';
  }
  if (connection?.state === 'degraded') {
    return language === 'ar' ? 'الخادم متاح جزئياً' : 'SERVER DEGRADED';
  }
  return language === 'ar' ? 'الخادم غير متاح — فتح بدون بيانات' : 'SERVER UNAVAILABLE — OPENING WITHOUT DATA';
}
