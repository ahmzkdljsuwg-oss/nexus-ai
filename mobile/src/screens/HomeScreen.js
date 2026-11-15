import React, { useEffect, useRef } from 'react';
import {
  ActivityIndicator, Animated, RefreshControl, ScrollView, StyleSheet, Text, TouchableOpacity, View,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { PremiumBackdrop } from '../components/PremiumBackdrop';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { MarketCard } from '../components/MarketCard';
import { ConnectionBadge } from '../components/ui';
import { t } from '../i18n';

const MARKET_ORDER = ['OTC', 'SMARTY', 'FOOTBALL', 'LUXURY', 'AI', 'CRICKET', 'FOREX'];

export default function HomeScreen({ navigation }) {
  const insets = useSafeAreaInsets();
  const { overview, marketsState, connection, language, lastUpdated, refresh, baseUrl } = useApp();
  const header = useRef(new Animated.Value(-30)).current;

  useEffect(() => {
    Animated.spring(header, { toValue: 0, tension: 55, friction: 9, useNativeDriver: true }).start();
  }, [header]);

  const rows = MARKET_ORDER.map((key) => overview?.markets?.find((item) => item.key === key))
    .filter(Boolean);
  const available = rows.filter((item) => item.status === 'LIVE').length;
  const ai = overview?.ai || {};
  const gemini = ai.gemini;
  const mistral = ai.mistral;

  return (
    <View style={styles.container}>
      <PremiumBackdrop />
      <Animated.View style={{ transform: [{ translateY: header }] }}>
        <LinearGradient colors={['#16161F', Colors.background]} style={[styles.header, { paddingTop: insets.top + 12 }]}>
          <View style={styles.topBar}>
            <View style={styles.academyPill}>
              <Text style={styles.academyText}>◈ {t(language, 'INTELLIGENCE', 'الذكاء')}</Text>
            </View>
            <View style={styles.topActions}>
              <TouchableOpacity onPress={refresh} style={styles.iconBtn}><Text style={styles.iconText}>↻</Text></TouchableOpacity>
              <TouchableOpacity onPress={() => navigation.navigate('SettingsTab')} style={styles.iconBtn}><Text style={styles.iconText}>⚙</Text></TouchableOpacity>
            </View>
          </View>
          <View style={styles.brandRow}>
            <View style={styles.logoRing}>
              <LinearGradient colors={['#24243C', '#0B0B16']} style={styles.logoInner}>
                <Text style={styles.logoText}>N</Text>
                <View style={styles.logoDot} />
              </LinearGradient>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.appName}>NEXUS AI</Text>
              <Text style={styles.tagline}>ADVANCED TRADING INTELLIGENCE</Text>
              <Text style={styles.greetDate}>
                {new Date().toLocaleDateString(language === 'ar' ? 'ar' : 'en', { weekday: 'long', day: 'numeric', month: 'short' })}
              </Text>
            </View>
          </View>
          <View style={styles.badgeRow}><ConnectionBadge connection={connection} language={language} /></View>
        </LinearGradient>
      </Animated.View>

      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 120 }}
        refreshControl={<RefreshControl refreshing={marketsState === 'refreshing'} onRefresh={refresh} tintColor={Colors.gold} />}
      >
        {!baseUrl ? (
          <View>
            <LinearGradient colors={['#241D0D', '#12101A']} style={styles.setupCard}>
              <View style={styles.setupTop}>
                <Text style={styles.setupTitle}>{t(language, 'AWAITING SERVER DEPLOYMENT', 'بانتظار نشر الخادم')}</Text>
                <View style={styles.standbyDot} />
              </View>
              <Text style={styles.setupText}>
                {t(
                  language,
                  'The app is ready and opens without a server. The production URL will load automatically once it is set in the build. No price is invented while the backend is offline.',
                  'التطبيق جاهز ويفتح بدون خادم. سيُحمّل رابط الإنتاج تلقائياً بعد ضبطه في البناء. لا تُعرض أي أسعار مُختلقة أثناء انقطاع الخادم.',
                )}
              </Text>
              <TouchableOpacity onPress={() => navigation.navigate('SettingsTab')}>
                <Text style={styles.setupAction}>{t(language, 'Optional fallback URL →', 'رابط احتياطي اختياري ←')}</Text>
              </TouchableOpacity>
            </LinearGradient>
          </View>
        ) : null}

        <LinearGradient colors={['#1E190D', '#0D0D18']} style={styles.hero}>
          <View style={styles.heroTop}>
            <Text style={styles.heroBadge}>{t(language, 'EVIDENCE-FIRST ENGINE', 'محرك قائم على الأدلة')}</Text>
            <Text style={styles.heroCount}>{available}/7</Text>
          </View>
          <Text style={styles.heroTitle}>
            {t(language, 'Seven markets. One honest standard.', 'سبعة أسواق. معيار واحد صادق.')}
          </Text>
          <Text style={styles.heroText}>
            {t(
              language,
              'Candle-by-candle structure, Alligator and MA 200 confirmation. If the feed fails validation, the market states DATA UNAVAILABLE instead of inventing a signal.',
              'تحليل شمعة بشمعة مع تأكيد Alligator و MA 200. إذا فشل التحقق من المصدر يظهر DATA UNAVAILABLE بدلاً من اختراع إشارة.',
            )}
          </Text>
          <View style={styles.heroStats}>
            <View style={styles.heroStat}>
              <Text style={styles.heroStatValue}>{gemini?.configured ? 'READY' : '—'}</Text>
              <Text style={styles.heroStatLabel}>GEMINI</Text>
            </View>
            <View style={styles.heroDivider} />
            <View style={styles.heroStat}>
              <Text style={styles.heroStatValue}>{mistral?.configured ? 'READY' : '—'}</Text>
              <Text style={styles.heroStatLabel}>MISTRAL</Text>
            </View>
            <View style={styles.heroDivider} />
            <View style={styles.heroStat}>
              <Text style={styles.heroStatValue}>{lastUpdated ? new Date(lastUpdated).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '—'}</Text>
              <Text style={styles.heroStatLabel}>{t(language, 'UPDATED', 'آخر تحديث')}</Text>
            </View>
          </View>
        </LinearGradient>

        <View style={styles.sectionHead}>
          <Text style={styles.sectionTitle}>{t(language, 'MARKETS', 'الأسواق')}</Text>
          <Text style={styles.sectionSub}>{t(language, 'Each market is analysed separately', 'كل سوق يُحلل بشكل منفصل')}</Text>
        </View>

        {marketsState === 'loading' && !rows.length ? (
          <View style={styles.loading}>
            <ActivityIndicator color={Colors.gold} />
            <Text style={styles.loadingText}>{t(language, 'Reading verified sources…', 'جارٍ قراءة المصادر الموثقة…')}</Text>
          </View>
        ) : null}

        <View style={styles.grid}>
          {rows.map((market, index) => (
            <MarketCard
              key={market.key}
              market={market}
              language={language}
              index={index}
              onPress={() => navigation.navigate('MarketDetail', { marketKey: market.key })}
            />
          ))}
        </View>

        {marketsState === 'error' ? (
          <View style={styles.errorBox}>
            <Text style={styles.errorTitle}>{t(language, 'DATA UNAVAILABLE', 'البيانات غير متاحة')}</Text>
            <Text style={styles.errorText}>{connection.detail}</Text>
            <TouchableOpacity onPress={refresh}><Text style={styles.retry}>{t(language, 'Retry', 'إعادة المحاولة')}</Text></TouchableOpacity>
          </View>
        ) : null}

        <View style={styles.note}>
          <Text style={styles.noteText}>
            {t(
              language,
              'NEXUS AI analyses data only. It never executes trades and never guarantees profit.',
              'NEXUS AI يحلل البيانات فقط. لا ينفذ صفقات ولا يضمن الربح.',
            )}
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { paddingHorizontal: 16, paddingBottom: 14, gap: 12 },
  topBar: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  academyPill: { borderRadius: 999, borderWidth: 1, borderColor: Colors.border, backgroundColor: '#FFFFFF06', paddingHorizontal: 10, paddingVertical: 5 },
  academyText: { color: Colors.textSecondary, fontSize: 8, fontWeight: '800', letterSpacing: 0.8 },
  topActions: { flexDirection: 'row', gap: 7 },
  iconBtn: { width: 32, height: 32, borderRadius: 10, borderWidth: 1, borderColor: Colors.border, backgroundColor: '#FFFFFF06', alignItems: 'center', justifyContent: 'center' },
  iconText: { color: Colors.gold, fontSize: 14 },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  logoRing: { width: 48, height: 48, borderRadius: 15, borderWidth: 1, borderColor: Colors.gold + '66', padding: 3, backgroundColor: Colors.gold + '10' },
  logoInner: { flex: 1, borderRadius: 11, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: '#FFFFFF12' },
  logoText: { color: Colors.goldLight, fontSize: 25, fontWeight: '900', marginTop: -2 },
  logoDot: { position: 'absolute', right: 7, bottom: 7, width: 4, height: 4, borderRadius: 2, backgroundColor: Colors.greenPositive },
  appName: { color: Colors.goldLight, fontSize: Fonts.sizes.xl, fontWeight: '900', letterSpacing: 1.8 },
  tagline: { color: Colors.textMuted, fontSize: 8, letterSpacing: 1.1, marginTop: 1 },
  greetDate: { color: Colors.textSecondary, fontSize: 9, marginTop: 3 },
  badgeRow: { flexDirection: 'row' },
  setupTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  standbyDot: { width: 7, height: 7, borderRadius: 4, backgroundColor: Colors.gold },
  setupCard: { borderRadius: 18, borderWidth: 1, borderColor: Colors.gold + '55', padding: 16, marginBottom: 14 },
  setupTitle: { color: Colors.gold, fontSize: Fonts.sizes.sm, fontWeight: '900', letterSpacing: 0.7 },
  setupText: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, lineHeight: 20, marginTop: 6 },
  setupAction: { color: Colors.goldLight, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 10 },
  hero: { borderRadius: 24, padding: 18, borderWidth: 1, borderColor: Colors.gold + '45', marginBottom: 20, overflow: 'hidden' },
  heroTop: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  heroBadge: { color: Colors.goldLight, fontSize: 9, fontWeight: '900', letterSpacing: 1 },
  heroCount: { color: Colors.white, fontSize: Fonts.sizes.lg, fontWeight: '900' },
  heroTitle: { color: Colors.white, fontSize: Fonts.sizes.xxl, fontWeight: '900', marginTop: 10, lineHeight: 30 },
  heroText: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, lineHeight: 20, marginTop: 8 },
  heroStats: { flexDirection: 'row', alignItems: 'center', marginTop: 16, backgroundColor: '#00000033', borderRadius: 14, padding: 10 },
  heroStat: { flex: 1, alignItems: 'center' },
  heroStatValue: { color: Colors.goldLight, fontSize: Fonts.sizes.md, fontWeight: '900' },
  heroStatLabel: { color: Colors.textMuted, fontSize: 8, letterSpacing: 0.8, marginTop: 2 },
  heroDivider: { width: 1, height: 24, backgroundColor: Colors.border },
  sectionHead: { marginBottom: 12 },
  sectionTitle: { color: Colors.white, fontSize: Fonts.sizes.lg, fontWeight: '900', letterSpacing: 1 },
  sectionSub: { color: Colors.textMuted, fontSize: Fonts.sizes.xs, marginTop: 2 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' },
  loading: { alignItems: 'center', paddingVertical: 30, gap: 10 },
  loadingText: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm },
  errorBox: { borderWidth: 1, borderColor: Colors.red + '55', backgroundColor: Colors.red + '10', borderRadius: 16, padding: 14, marginTop: 4 },
  errorTitle: { color: Colors.red, fontSize: Fonts.sizes.sm, fontWeight: '900', letterSpacing: 0.6 },
  errorText: { color: Colors.textSecondary, fontSize: Fonts.sizes.xs, marginTop: 4, lineHeight: 18 },
  retry: { color: Colors.gold, fontSize: Fonts.sizes.sm, fontWeight: '800', marginTop: 8 },
  note: { marginTop: 4, marginBottom: 12, padding: 14, borderRadius: 14, borderWidth: 1, borderColor: Colors.border },
  noteText: { color: Colors.textMuted, fontSize: Fonts.sizes.xs, lineHeight: 18, textAlign: 'center' },
});
