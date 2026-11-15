import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, TouchableOpacity, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { CandleChart, DirectionBadge, FadeIn, PrimaryButton } from '../components/ui';
import { MARKET_COPY, directionLabel, t } from '../i18n';
import { friendlyError } from '../api/client';

function Row({ label, value, color = Colors.white }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={[styles.rowValue, { color }]}>{value}</Text>
    </View>
  );
}

export default function MarketDetailScreen({ route, navigation }) {
  const insets = useSafeAreaInsets();
  const { client, language, connection } = useApp();
  const marketKey = route.params?.marketKey || 'FOREX';
  const copy = MARKET_COPY[marketKey] || {};
  const [snapshot, setSnapshot] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [selectedAsset, setSelectedAsset] = useState(null);
  const [mode, setMode] = useState('auto');
  const [duration, setDuration] = useState(300);
  const [result, setResult] = useState(null);

  const load = useCallback(async (assetKey = null) => {
    setLoading(true);
    setError('');
    try {
      const response = await client.market(marketKey, assetKey);
      setSnapshot(response.data);
      const preferred = response.data.asset?.key || assetKey || response.data.assets?.[0]?.key || null;
      setSelectedAsset(preferred);
      if (response.data.durations?.length) {
        setDuration(response.data.durations.includes(300) ? 300 : response.data.durations[0]);
      }
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setLoading(false);
    }
  }, [client, marketKey]);

  useEffect(() => { load(); }, [load]);

  const analyse = async (auto = false) => {
    setBusy(true);
    setError('');
    try {
      const response = await client.analyse({
        market: marketKey,
        asset: selectedAsset,
        duration_mode: auto ? 'auto' : mode,
        duration: auto || mode === 'auto' ? null : duration,
        language,
      });
      setResult(response.data);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
    }
  };

  const title = language === 'ar' ? copy.ar : copy.en;
  const live = snapshot?.status === 'LIVE';
  const available = snapshot?.durations || [];
  const ai = result?.ai || {};
  const comparison = ai.comparison || {};
  const technical = result?.technical || {};
  const entry = result?.entry || {};

  return (
    <View style={styles.container}>
      <View style={[styles.header, { paddingTop: insets.top + 10 }]}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.back}>
          <Text style={styles.backText}>‹</Text>
        </TouchableOpacity>
        <View style={{ flex: 1 }}>
          <Text style={styles.title}>{title || marketKey}</Text>
          <Text style={styles.subtitle}>
            {live ? `${snapshot.source} · ${snapshot.timeframe}` : t(language, 'Waiting for verified data', 'بانتظار بيانات موثقة')}
          </Text>
        </View>
        <View style={[styles.livePill, { borderColor: live ? Colors.greenPositive : Colors.red }]}>
          <View style={[styles.liveDot, { backgroundColor: live ? Colors.greenPositive : Colors.red }]} />
          <Text style={[styles.liveText, { color: live ? Colors.greenPositive : Colors.red }]}>
            {live ? 'LIVE' : 'OFFLINE'}
          </Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 130 }} showsVerticalScrollIndicator={false}>
        {loading ? (
          <View style={styles.loading}><ActivityIndicator color={Colors.gold} /><Text style={styles.muted}>{t(language, 'Loading market…', 'جارٍ تحميل السوق…')}</Text></View>
        ) : null}

        {!loading && !live ? (
          <View style={styles.unavailable}>
            <Text style={styles.unavailableTitle}>{t(language, 'DATA UNAVAILABLE', 'البيانات غير متاحة')}</Text>
            <Text style={styles.muted}>{error || snapshot?.error || t(language, 'No verified feed for this market.', 'لا يوجد مصدر موثق لهذا السوق.')}</Text>
            <Text style={styles.unavailableHint}>
              {t(
                language,
                'No recommendation is generated from unverified prices. Configure the matching server-side source, then retry.',
                'لا تُصدر توصية من أسعار غير متحقق منها. اضبط المصدر المناسب داخل الخادم ثم أعد المحاولة.',
              )}
            </Text>
            <TouchableOpacity onPress={() => load()}><Text style={styles.retry}>{t(language, 'Retry data check', 'إعادة فحص البيانات')}</Text></TouchableOpacity>
          </View>
        ) : null}

        {live ? (
          <FadeIn style={styles.chartCard}>
            <View style={styles.chartHead}>
              <View>
                <Text style={styles.chartLabel}>{selectedAsset ? snapshot.assets.find((a) => a.key === selectedAsset)?.display : '—'}</Text>
                <Text style={styles.chartPrice}>{snapshot.price_display}</Text>
              </View>
              <View style={{ alignItems: 'flex-end' }}>
                <Text style={styles.smallLabel}>{t(language, 'CANDLES', 'الشموع')}</Text>
                <Text style={styles.chartMeta}>{snapshot.timeframe}</Text>
              </View>
            </View>
            <CandleChart candles={snapshot.candles || []} accent={snapshot.accent} language={language} />
            <Text style={styles.chartFoot}>
              {t(language, 'Last verified candle', 'آخر شمعة موثقة')}: {snapshot.updated_at ? new Date(snapshot.updated_at).toLocaleTimeString() : '—'}
            </Text>
          </FadeIn>
        ) : null}

        {snapshot?.assets?.length > 1 ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t(language, 'ASSET', 'الأصل')}</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
              {snapshot.assets.map((asset) => (
                <Pressable
                  key={asset.key}
                  onPress={() => load(asset.key)}
                  style={[styles.chip, selectedAsset === asset.key && styles.chipActive]}
                >
                  <Text style={[styles.chipText, selectedAsset === asset.key && styles.chipTextActive]}>{asset.display}</Text>
                </Pressable>
              ))}
            </ScrollView>
          </View>
        ) : null}

        {live ? (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>{t(language, 'TRADE DURATION', 'مدة الصفقة')}</Text>
            <View style={styles.modeRow}>
              <Pressable onPress={() => setMode('auto')} style={[styles.mode, mode === 'auto' && styles.modeActive]}>
                <Text style={[styles.modeTitle, mode === 'auto' && styles.modeTitleActive]}>
                  {t(language, 'Analyse by candle', 'تحليل الوقت حسب الشمعة')}
                </Text>
                <Text style={styles.modeSub}>{t(language, 'Engine proposes the expiry from structure', 'المحرك يقترح المدة من بنية الشموع')}</Text>
              </Pressable>
              <Pressable onPress={() => setMode('manual')} style={[styles.mode, mode === 'manual' && styles.modeActive]}>
                <Text style={[styles.modeTitle, mode === 'manual' && styles.modeTitleActive]}>
                  {t(language, 'Manual', 'يدوي')}
                </Text>
                <Text style={styles.modeSub}>{t(language, 'You choose the fixed expiry', 'أنت تحدد المدة الثابتة')}</Text>
              </Pressable>
            </View>
            {mode === 'manual' ? (
              <View style={styles.durations}>
                {available.map((seconds) => (
                  <Pressable key={seconds} onPress={() => setDuration(seconds)} style={[styles.duration, duration === seconds && styles.durationActive]}>
                    <Text style={[styles.durationText, duration === seconds && styles.durationTextActive]}>
                      {snapshot.duration_labels?.[String(seconds)]?.split(' / ')[language === 'ar' ? 0 : 1] || `${seconds}s`}
                    </Text>
                  </Pressable>
                ))}
              </View>
            ) : null}
          </View>
        ) : null}

        {live ? (
          <PrimaryButton
            title={t(language, 'ANALYSE THIS MARKET', 'حلل هذا السوق')}
            subtitle={t(language, 'Real candles · deterministic engine · Gemini + Mistral comparison', 'شموع حقيقية · محرك حاسم · مقارنة Gemini و Mistral')}
            onPress={() => analyse(false)}
            loading={busy}
            style={{ marginTop: 4 }}
          />
        ) : null}

        {error && live ? <Text style={styles.errorText}>{error}</Text> : null}

        {result ? (
          <FadeIn style={{ marginTop: 18 }}>
            <View style={[styles.resultCard, {
              borderColor: result.direction === 'UP' ? Colors.green + '66' : result.direction === 'DOWN' ? Colors.red + '66' : Colors.border,
            }]}>
              <View style={styles.resultTop}>
                <View>
                  <Text style={styles.smallLabel}>{t(language, 'FINAL RECOMMENDATION', 'التوصية النهائية')}</Text>
                  <Text style={styles.resultAsset}>{result.asset}</Text>
                </View>
                <DirectionBadge direction={result.direction} language={language} />
              </View>

              {result.status === 'READY' ? (
                <>
                  <Row label={t(language, 'ENTRY', 'الدخول')} value={entry.price_display || '—'} color={Colors.goldLight} />
                  <Row label={t(language, 'VALID UNTIL', 'صالح حتى')} value={entry.valid_until ? new Date(entry.valid_until).toLocaleTimeString() : '—'} />
                  <Row label={t(language, 'DURATION', 'المدة')} value={result.duration_label || '—'} />
                  <Row label={t(language, 'EVIDENCE', 'قوة الأدلة')} value={`${result.evidence_score || 0}%`} color={Colors.greenPositive} />
                  <Text style={styles.note}>{result.confidence_note}</Text>
                  <Text style={styles.blockTitle}>{t(language, 'WHY', 'الأسباب')}</Text>
                  {(result.reasons || []).map((reason, index) => (
                    <Text key={index} style={styles.bullet}>• {reason}</Text>
                  ))}
                  <Text style={styles.blockTitle}>{t(language, 'INVALIDATION', 'إلغاء الإشارة')}</Text>
                  {(entry.invalidation || []).map((item, index) => (
                    <Text key={index} style={styles.bullet}>• {item}</Text>
                  ))}
                  <Text style={styles.note}>{entry.condition}</Text>
                </>
              ) : (
                <>
                  <Text style={styles.noTrade}>{t(language, 'NO ACTIONABLE RECOMMENDATION', 'لا توجد توصية قابلة للتنفيذ')}</Text>
                  <Text style={styles.muted}>{result.no_trade_reason || result.duration_reason}</Text>
                </>
              )}
              <Text style={styles.durationReason}>{result.duration_reason}</Text>
            </View>

            <Text style={styles.sectionTitle}>{t(language, 'ENGINE ANALYSIS', 'تحليل المحرك')}</Text>
            <View style={styles.technicalCard}>
              <Row label="TREND" value={technical.trend || '—'} />
              <Row label="MOMENTUM" value={technical.momentum || '—'} />
              <Row label="RSI" value={technical.indicators?.rsi != null ? Number(technical.indicators.rsi).toFixed(1) : '—'} />
              <Row label="ADX" value={technical.indicators?.adx != null ? Number(technical.indicators.adx).toFixed(1) : '—'} />
              <Row label="EMA 200" value={technical.indicators?.ema200 != null ? Number(technical.indicators.ema200).toFixed(5) : '—'} />
              <Row label="BOS / CHoCH" value={`${technical.smc?.bos || '—'} / ${technical.smc?.choch || '—'}`} />
              <Row label="FVG" value={technical.smc?.fvg ? t(language, 'detected', 'مرصود') : t(language, 'none', 'لا يوجد')} />
            </View>

            <Text style={styles.sectionTitle}>{t(language, 'AI COMPARISON', 'مقارنة الذكاء الاصطناعي')}</Text>
            <View style={styles.aiRow}>
              {[ai.gemini, ai.mistral].map((model, index) => (
                <View key={index} style={styles.aiCard}>
                  <Text style={styles.aiName}>{model?.provider || (index ? 'Mistral' : 'Gemini')}</Text>
                  <Text style={[styles.aiDirection, { color: model?.online ? (model.direction === 'UP' ? Colors.greenPositive : model.direction === 'DOWN' ? Colors.red : Colors.textSecondary) : Colors.textMuted }]}>
                    {model?.online ? directionLabel(language, model.direction) : t(language, 'NOT AVAILABLE', 'غير متاح')}
                  </Text>
                  <Text style={styles.aiSummary} numberOfLines={5}>{model?.summary || model?.error || '—'}</Text>
                </View>
              ))}
            </View>
            <View style={styles.synth}>
              <Text style={styles.synthLabel}>{t(language, 'SYNTHESIS', 'الخلاصة')}</Text>
              <Text style={styles.synthText}>{comparison.summary || '—'}</Text>
              {comparison.differences?.length ? (
                comparison.differences.map((item, index) => <Text key={index} style={styles.diff}>△ {item}</Text>)
              ) : null}
              <Text style={styles.disclaimer}>{comparison.disclaimer || result.disclaimer}</Text>
            </View>
          </FadeIn>
        ) : null}

        {!live && connection.state !== 'online' ? (
          <Text style={styles.footer}>{connection.detail}</Text>
        ) : null}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingBottom: 12 },
  back: { width: 36, height: 36, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, alignItems: 'center', justifyContent: 'center' },
  backText: { color: Colors.white, fontSize: 26, marginTop: -3 },
  title: { color: Colors.white, fontSize: Fonts.sizes.lg, fontWeight: '900' },
  subtitle: { color: Colors.textMuted, fontSize: 10, marginTop: 2 },
  livePill: { flexDirection: 'row', alignItems: 'center', gap: 4, borderWidth: 1, borderRadius: 999, paddingHorizontal: 8, paddingVertical: 4 },
  liveDot: { width: 5, height: 5, borderRadius: 3 },
  liveText: { fontSize: 8, fontWeight: '900' },
  loading: { paddingVertical: 60, alignItems: 'center', gap: 10 },
  muted: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, lineHeight: 20 },
  unavailable: { borderRadius: 20, borderWidth: 1, borderColor: Colors.red + '55', backgroundColor: Colors.red + '0D', padding: 18, marginTop: 10 },
  unavailableTitle: { color: Colors.red, fontSize: Fonts.sizes.lg, fontWeight: '900', letterSpacing: 0.5 },
  unavailableHint: { color: Colors.textMuted, fontSize: Fonts.sizes.xs, lineHeight: 18, marginTop: 10 },
  retry: { color: Colors.gold, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 12 },
  chartCard: { borderRadius: 22, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, padding: 14, marginBottom: 16 },
  chartHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 },
  chartLabel: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, fontWeight: '700' },
  chartPrice: { color: Colors.white, fontSize: Fonts.sizes.xxl, fontWeight: '900', marginTop: 2 },
  smallLabel: { color: Colors.textMuted, fontSize: 8, fontWeight: '800', letterSpacing: 0.9 },
  chartMeta: { color: Colors.goldLight, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 2 },
  chartFoot: { color: Colors.textMuted, fontSize: 9, marginTop: 6, textAlign: 'right' },
  section: { marginBottom: 16 },
  sectionTitle: { color: Colors.white, fontSize: Fonts.sizes.md, fontWeight: '900', letterSpacing: 0.6, marginBottom: 9, marginTop: 8 },
  chip: { borderWidth: 1, borderColor: Colors.border, borderRadius: 12, paddingHorizontal: 12, paddingVertical: 8, backgroundColor: Colors.cardBg },
  chipActive: { borderColor: Colors.gold, backgroundColor: Colors.gold + '18' },
  chipText: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, fontWeight: '700' },
  chipTextActive: { color: Colors.goldLight },
  modeRow: { flexDirection: 'row', gap: 8 },
  mode: { flex: 1, borderRadius: 16, borderWidth: 1, borderColor: Colors.border, padding: 12, backgroundColor: Colors.cardBg },
  modeActive: { borderColor: Colors.gold, backgroundColor: Colors.gold + '12' },
  modeTitle: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, fontWeight: '800' },
  modeTitleActive: { color: Colors.goldLight },
  modeSub: { color: Colors.textMuted, fontSize: 9, lineHeight: 13, marginTop: 3 },
  durations: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 },
  duration: { borderRadius: 10, borderWidth: 1, borderColor: Colors.border, paddingHorizontal: 12, paddingVertical: 8 },
  durationActive: { borderColor: Colors.greenPositive, backgroundColor: Colors.greenPositive + '15' },
  durationText: { color: Colors.textSecondary, fontSize: Fonts.sizes.xs, fontWeight: '700' },
  durationTextActive: { color: Colors.greenPositive },
  errorText: { color: Colors.red, fontSize: Fonts.sizes.sm, marginTop: 10, lineHeight: 18 },
  resultCard: { borderRadius: 22, borderWidth: 1, backgroundColor: Colors.cardBg, padding: 16 },
  resultTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 },
  resultAsset: { color: Colors.white, fontSize: Fonts.sizes.xl, fontWeight: '900', marginTop: 2 },
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 7, borderBottomWidth: 1, borderBottomColor: Colors.border },
  rowLabel: { color: Colors.textMuted, fontSize: 10, fontWeight: '700' },
  rowValue: { fontSize: Fonts.sizes.sm, fontWeight: '800', maxWidth: '62%', textAlign: 'right' },
  note: { color: Colors.textMuted, fontSize: 9, lineHeight: 15, marginTop: 8 },
  blockTitle: { color: Colors.goldLight, fontSize: 10, fontWeight: '800', letterSpacing: 0.7, marginTop: 12, marginBottom: 4 },
  bullet: { color: Colors.textSecondary, fontSize: Fonts.sizes.xs, lineHeight: 18 },
  noTrade: { color: Colors.gold, fontSize: Fonts.sizes.md, fontWeight: '900', marginTop: 10 },
  durationReason: { color: Colors.textMuted, fontSize: 9, lineHeight: 15, marginTop: 10, fontStyle: 'italic' },
  technicalCard: { borderRadius: 18, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, padding: 14 },
  aiRow: { flexDirection: 'row', gap: 8 },
  aiCard: { flex: 1, borderRadius: 16, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, padding: 12 },
  aiName: { color: Colors.goldLight, fontSize: 10, fontWeight: '900', letterSpacing: 0.7 },
  aiDirection: { fontSize: Fonts.sizes.sm, fontWeight: '900', marginTop: 4 },
  aiSummary: { color: Colors.textSecondary, fontSize: 9, lineHeight: 14, marginTop: 5 },
  synth: { borderRadius: 16, borderWidth: 1, borderColor: Colors.gold + '44', backgroundColor: Colors.gold + '0D', padding: 14, marginTop: 10 },
  synthLabel: { color: Colors.gold, fontSize: 10, fontWeight: '900', letterSpacing: 0.8 },
  synthText: { color: Colors.textPrimary, fontSize: Fonts.sizes.xs, lineHeight: 18, marginTop: 5 },
  diff: { color: Colors.goldLight, fontSize: 9, lineHeight: 15, marginTop: 5 },
  disclaimer: { color: Colors.textMuted, fontSize: 9, lineHeight: 14, marginTop: 8 },
  footer: { color: Colors.textMuted, fontSize: Fonts.sizes.xs, textAlign: 'center', marginTop: 16 },
});
