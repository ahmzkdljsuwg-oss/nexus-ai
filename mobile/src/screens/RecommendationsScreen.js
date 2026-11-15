import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { DirectionBadge, FadeIn } from '../components/ui';
import { t } from '../i18n';
import { friendlyError } from '../api/client';

export default function RecommendationsScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { client, language, refresh: refreshAll } = useApp();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const response = await client.recommendations();
      setItems(response.data.items || []);
    } catch (err) {
      setError(friendlyError(err));
      setItems([]);
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => { load(); }, [load]);

  return (
    <View style={styles.container}>
      <View style={[styles.header, { paddingTop: insets.top + 10 }]}>
        <View>
          <Text style={styles.title}>{t(language, 'RECOMMENDATIONS', 'التوصيات')}</Text>
          <Text style={styles.subtitle}>{t(language, 'Ranked by evidence quality, not a random score', 'مرتبة حسب جودة الأدلة لا برقم عشوائي')}</Text>
        </View>
        <TouchableOpacity onPress={async () => { await refreshAll(); load(); }} style={styles.refresh}>
          <Text style={{ color: Colors.gold, fontSize: 16 }}>⟳</Text>
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 130 }}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={Colors.gold} />}
      >
        {loading && !items.length ? (
          <View style={styles.loading}><ActivityIndicator color={Colors.gold} /><Text style={styles.muted}>{t(language, 'Scanning verified markets…', 'جارٍ فحص الأسواق الموثقة…')}</Text></View>
        ) : null}

        {error ? (
          <View style={styles.errorBox}>
            <Text style={styles.errorTitle}>{t(language, 'NO VERIFIED DATA', 'لا توجد بيانات موثقة')}</Text>
            <Text style={styles.muted}>{error}</Text>
            <TouchableOpacity onPress={load}><Text style={styles.retry}>{t(language, 'Retry', 'إعادة المحاولة')}</Text></TouchableOpacity>
          </View>
        ) : null}

        {!loading && !error && !items.length ? (
          <View style={styles.empty}>
            <Text style={styles.emptyTitle}>{t(language, 'NO ACTIONABLE SETUP', 'لا توجد فرصة قابلة للتنفيذ')}</Text>
            <Text style={styles.muted}>
              {t(
                language,
                'The engine only publishes a recommendation when candle structure, trend and confirmation agree. Weak or stale data stays empty on purpose.',
                'لا ينشر المحرك توصية إلا عند توافق بنية الشموع والاتجاه والتأكيد. البيانات الضعيفة أو القديمة تُترك فارغة بشكل مقصود.',
              )}
            </Text>
          </View>
        ) : null}

        {items.map((item, index) => (
          <FadeIn key={`${item.market}-${item.asset}-${item.created_at || index}`} delay={index * 60}>
            <View style={[styles.card, {
              borderColor: item.direction === 'UP' ? Colors.green + '55' : item.direction === 'DOWN' ? Colors.red + '55' : Colors.border,
            }]}>
              <View style={styles.cardTop}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.market}>{item.market}</Text>
                  <Text style={styles.asset}>{item.asset}</Text>
                </View>
                <DirectionBadge direction={item.direction} language={language} />
              </View>
              <View style={styles.metaRow}>
                <View style={styles.meta}><Text style={styles.metaLabel}>{t(language, 'ENTRY', 'الدخول')}</Text><Text style={styles.metaValue}>{item.entry_price_display || '—'}</Text></View>
                <View style={styles.meta}><Text style={styles.metaLabel}>{t(language, 'DURATION', 'المدة')}</Text><Text style={styles.metaValue}>{item.duration_label || '—'}</Text></View>
                <View style={styles.meta}><Text style={styles.metaLabel}>{t(language, 'EVIDENCE', 'الأدلة')}</Text><Text style={styles.metaValue}>{item.evidence_score || 0}%</Text></View>
                <View style={styles.meta}><Text style={styles.metaLabel}>{t(language, 'STATUS', 'الحالة')}</Text><Text style={styles.metaValue}>{item.status}</Text></View>
              </View>
              {(item.reasons || []).slice(0, 3).map((reason, i) => (
                <Text key={i} style={styles.reason}>• {reason}</Text>
              ))}
              <TouchableOpacity onPress={() => navigation.navigate('MarketDetail', { marketKey: item.market })}>
                <Text style={styles.link}>{t(language, 'Open market analysis →', 'فتح تحليل السوق ←')}</Text>
              </TouchableOpacity>
            </View>
          </FadeIn>
        ))}
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
  loading: { paddingVertical: 50, alignItems: 'center', gap: 10 },
  muted: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, lineHeight: 20 },
  card: { borderRadius: 20, borderWidth: 1, backgroundColor: Colors.cardBg, padding: 14, marginBottom: 12 },
  cardTop: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  market: { color: Colors.goldLight, fontSize: 9, fontWeight: '900', letterSpacing: 1 },
  asset: { color: Colors.white, fontSize: Fonts.sizes.lg, fontWeight: '900', marginTop: 2 },
  metaRow: { flexDirection: 'row', marginTop: 12, marginBottom: 8, backgroundColor: '#00000030', borderRadius: 12, paddingVertical: 9 },
  meta: { flex: 1, alignItems: 'center' },
  metaLabel: { color: Colors.textMuted, fontSize: 7, fontWeight: '800', letterSpacing: 0.6 },
  metaValue: { color: Colors.textPrimary, fontSize: 10, fontWeight: '800', marginTop: 3 },
  reason: { color: Colors.textSecondary, fontSize: 10, lineHeight: 16 },
  link: { color: Colors.gold, fontSize: 10, fontWeight: '800', marginTop: 8 },
  errorBox: { borderRadius: 16, borderWidth: 1, borderColor: Colors.red + '55', backgroundColor: Colors.red + '10', padding: 16 },
  errorTitle: { color: Colors.red, fontSize: Fonts.sizes.sm, fontWeight: '900', letterSpacing: 0.6, marginBottom: 6 },
  retry: { color: Colors.gold, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 10 },
  empty: { borderRadius: 18, borderWidth: 1, borderColor: Colors.border, padding: 18, marginTop: 8 },
  emptyTitle: { color: Colors.gold, fontSize: Fonts.sizes.md, fontWeight: '900', marginBottom: 6 },
});
