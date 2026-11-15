export function t(language, en, ar) {
  return language === 'ar' ? ar : en;
}

export const MARKET_COPY = {
  OTC: { en: 'OTC Market', ar: 'سوق OTC', descEn: 'Over-the-counter synthetic feed', descAr: 'بيانات OTC من مصدر ExpertOption فقط' },
  SMARTY: { en: 'Smarty Market', ar: 'سوق Smarty', descEn: 'Smarty duration engine', descAr: 'أصول Smarty عبر جسر ExpertOption' },
  FOOTBALL: { en: 'Football Index', ar: 'مؤشر كرة القدم', descEn: 'Football index feed', descAr: 'بيانات مؤشر كرة القدم' },
  LUXURY: { en: 'Luxury Index', ar: 'مؤشر الفخامة', descEn: 'Luxury index feed', descAr: 'بيانات مؤشر الفخامة' },
  AI: { en: 'AI Index', ar: 'مؤشر الذكاء', descEn: 'AI index feed', descAr: 'بيانات مؤشر الذكاء الاصطناعي' },
  CRICKET: { en: 'Cricket Index', ar: 'مؤشر الكريكيت', descEn: 'Cricket index feed', descAr: 'بيانات مؤشر الكريكيت' },
  FOREX: { en: 'Forex Market', ar: 'سوق الفوركس', descEn: 'Live FX and metals', descAr: 'أسعار فوركس حقيقية' },
};

export const DURATION_COPY = {
  30: ['30 sec', '٣٠ ثانية'],
  60: ['1 min', 'دقيقة'],
  120: ['2 min', 'دقيقتان'],
  180: ['3 min', '٣ دقائق'],
  300: ['5 min', '٥ دقائق'],
  900: ['15 min', '١٥ دقيقة'],
  1800: ['30 min', '٣٠ دقيقة'],
  3600: ['1 hour', 'ساعة'],
};

export function directionLabel(language, direction) {
  if (direction === 'UP') return t(language, 'BUY / UP', 'شراء / UP');
  if (direction === 'DOWN') return t(language, 'SELL / DOWN', 'بيع / DOWN');
  if (direction === 'NO TRADE' || direction === 'NO_TRADE') return t(language, 'NO TRADE', 'لا تداول');
  return direction || '—';
}

export function resultLabel(language, result) {
  const map = {
    WIN: ['WIN', 'رابحة'],
    LOSS: ['LOSS', 'خاسرة'],
    DRAW: ['DRAW', 'تعادل'],
    OPEN: ['OPEN', 'مفتوحة'],
    UNVERIFIED: ['UNVERIFIED', 'غير متحقق'],
  };
  const item = map[result] || [result || '—', result || '—'];
  return language === 'ar' ? item[1] : item[0];
}
