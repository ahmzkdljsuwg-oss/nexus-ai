import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { DirectionBadge } from '../components/ui';
import { resultLabel, t } from '../i18n';
import { friendlyError } from '../api/client';

export default function HistoryScreen() {
  const insets = useSafeAreaInsets();
  const { client, language } = useApp();
  const [records, setRecords] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const response = await client.history(80);
      setRecords(response.data.items || []);
      setStats(response.data.stats || null);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => { load(); }, [load]);

  return (
    <View style={styles.container}>
      <View style={[styles.header, { paddingTop: insets.top + 10 }]}>
        <View>
          <Text style={styles.title}>{t(language, 'TRADE HISTORY', 'سجل الصفقات')}</Text>
          <Text style={styles.subtitle}>{t(language, 'Only resolved trades count toward accuracy', 'الصفقات المحسومة فقط تُحتسب في الدقة')}</Text>
        </View>
        <TouchableOpacity onPress={load} style={styles.refresh}><Text style={{ color: Colors.gold }}>⟳</Text></TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 130 }}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={Colors.gold} />}
      >
        <View style={styles.statsRow}>
          <View style={styles.statCard}>
            <Text style={styles.statValue}>{stats?.total ?? 0}</Text>
            <Text style={styles.statLabel}>{t(language, 'TOTAL', 'الإجمالي')}</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={[styles.statValue, { color: Colors.greenPositive }]}>{stats?.wins ?? 0}</Text>
            <Text style={styles.statLabel}>WIN</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={[styles.statValue, { color: Colors.red }]}>{stats?.losses ?? 0}</Text>
            <Text style={styles.statLabel}>LOSS</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={[styles.statValue, { color: Colors.goldLight }]}>
              {stats?.win_rate == null ? '—' : `${Math.round(stats.win_rate)}%`}
            </Text>
            <Text style={styles.statLabel}>{t(language, 'WIN RATE', 'دقة النجاح')}</Text>
          </View>
        </View>
        <Text style={styles.statsNote}>
          {t(language, 'Verified trades', 'الصفقات المتحققة')}: {stats ? (stats.wins + stats.losses + stats.draws) : 0} · {t(language, 'Open/unverified excluded', 'المفتوحة/غير المتحققة مستثناة')}
        </Text>

        {loading && !records.length ? (
          <View style={styles.loading}><ActivityIndicator color={Colors.gold} /></View>
        ) : null}

        {error ? (
          <View style={styles.errorBox}><Text style={styles.muted}>{error}</Text><TouchableOpacity onPress={load}><Text style={styles.retry}>{t(language, 'Retry', 'إعادة المحاولة')}</Text></TouchableOpacity></View>
        ) : null}

        {!loading && !error && !records.length ? (
          <View style={styles.empty}><Text style={styles.muted}>{t(language, 'No recommendations stored yet.', 'لا توجد توصيات محفوظة بعد.')}</Text></View>
        ) : null}

        {records.map((item, index) => {
          const resolved = item.result === 'WIN';
          const lost = item.result === 'LOSS';
          const color = resolved ? Colors.greenPositive : lost ? Colors.red : Colors.textMuted;
          return (
            <View key={item.id || index} style={styles.card}>
              <View style={styles.cardTop}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.market}>{item.market}</Text>
                  <Text style={styles.asset}>{item.asset}</Text>
                </View>
                <DirectionBadge direction={item.direction} language={language} />
              </View>
              <View style={styles.row}>
                <Text style={styles.rowLabel}>{t(language, 'ENTRY', 'الدخول')}</Text>
                <Text style={styles.rowValue}>{item.entry_price_display || '—'}</Text>
              </View>
              <View style={styles.row}>
                <Text style={styles.rowLabel}>{t(language, 'EXIT', 'الخروج')}</Text>
                <Text style={styles.rowValue}>{item.exit_price_display || '—'}</Text>
              </View>
              <View style={styles.row}>
                <Text style={styles.rowLabel}>{t(language, 'RESULT', 'النتيجة')}</Text>
                <Text style={[styles.rowValue, { color }]}>{resultLabel(language, item.result)}</Text>
              </View>
              <Text style={styles.time}>
                {item.created_at ? new Date(item.created_at).toLocaleString() : '—'} · {item.duration_label || '—'}
              </Text>
            </View>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 12 },
  title: { color: Colors.white, fontSize: Fonts.sizes.xxl, fontWeight: '900' },
  subtitle: { color: Colors.textMuted, fontSize: 9, marginTop: 3 },
  refresh: { width: 36, height: 36, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, alignItems: 'center', justifyContent: 'center' },
  statsRow: { flexDirection: 'row', gap: 8 },
  statCard: { flex: 1, borderRadius: 14, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, paddingVertical: 12, alignItems: 'center' },
  statValue: { color: Colors.white, fontSize: Fonts.sizes.lg, fontWeight: '900' },
  statLabel: { color: Colors.textMuted, fontSize: 7, fontWeight: '800', marginTop: 3, letterSpacing: 0.5 },
  statsNote: { color: Colors.textMuted, fontSize: 9, marginTop: 8, marginBottom: 14, textAlign: 'center' },
  loading: { paddingVertical: 30 },
  muted: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, lineHeight: 20 },
  card: { borderRadius: 16, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, padding: 13, marginBottom: 10 },
  cardTop: { flexDirection: 'row', alignItems: 'center', marginBottom: 6 },
  market: { color: Colors.goldLight, fontSize: 8, fontWeight: '900', letterSpacing: 0.8 },
  asset: { color: Colors.white, fontSize: Fonts.sizes.md, fontWeight: '900', marginTop: 2 },
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  rowLabel: { color: Colors.textMuted, fontSize: 9, fontWeight: '700' },
  rowValue: { color: Colors.textPrimary, fontSize: 10, fontWeight: '800' },
  time: { color: Colors.textMuted, fontSize: 8, marginTop: 6 },
  errorBox: { borderRadius: 16, borderWidth: 1, borderColor: Colors.red + '55', backgroundColor: Colors.red + '10', padding: 16 },
  retry: { color: Colors.gold, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 10 },
  empty: { borderRadius: 16, borderWidth: 1, borderColor: Colors.border, padding: 18, marginTop: 6 },
});
