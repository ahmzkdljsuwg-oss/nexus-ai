import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, ScrollView, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { PremiumBackdrop } from '../components/PremiumBackdrop';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { ConnectionBadge, PrimaryButton } from '../components/ui';
import { t } from '../i18n';
import { normaliseBaseUrl } from '../api/client';

export default function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { baseUrl, automaticBaseUrl, saveBaseUrl, useAutomaticBaseUrl, connection, checkHealth, refresh, overview, language, setLanguage } = useApp();
  const [draft, setDraft] = useState(baseUrl);
  const [busy, setBusy] = useState(false);

  useEffect(() => { setDraft(baseUrl); }, [baseUrl]);

  const save = async () => {
    if (!normaliseBaseUrl(draft)) {
      Alert.alert(t(language, 'Invalid URL', 'رابط غير صالح'), t(language, 'Enter a full http(s) address.', 'أدخل عنوان http(s) كاملاً.'));
      return;
    }
    setBusy(true);
    try {
      await saveBaseUrl(draft);
      await checkHealth();
      await refresh();
    } catch (error) {
      Alert.alert(t(language, 'Could not save', 'تعذر الحفظ'), error.message);
    } finally {
      setBusy(false);
    }
  };

  const test = async () => {
    setBusy(true);
    try { await checkHealth(); } finally { setBusy(false); }
  };

  const ai = overview?.ai || {};
  const providers = overview?.data_sources || [];

  return (
    <View style={styles.container}>
      <PremiumBackdrop />
      <View style={[styles.header, { paddingTop: insets.top + 10 }]}>
        <Text style={styles.title}>{t(language, 'SETTINGS', 'الإعدادات')}</Text>
        <ConnectionBadge connection={connection} language={language} />
      </View>
      <ScrollView contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 130 }} showsVerticalScrollIndicator={false}>
        <Text style={styles.sectionTitle}>{t(language, 'BACKEND · AUTOMATIC', 'الخادم · تلقائي')}</Text>
        <View style={styles.card}>
          <View style={styles.autoRow}>
            <Text style={styles.autoLabel}>{t(language, 'PRODUCTION URL', 'رابط الإنتاج')}</Text>
            <Text style={[styles.autoState, { color: automaticBaseUrl ? Colors.greenPositive : Colors.gold }]}>
              {automaticBaseUrl ? t(language, 'CONFIGURED IN BUILD', 'مضبوط في البناء') : t(language, 'AWAITING DEPLOYMENT', 'بانتظار النشر')}
            </Text>
          </View>
          <Text style={styles.autoValue} numberOfLines={1}>{automaticBaseUrl || t(language, 'No production URL is compiled into this build.', 'لا يوجد رابط إنتاج مضمّن في هذا الإصدار.')}</Text>
          <Text style={styles.hint}>
            {t(
              language,
              'The app connects automatically when the production URL is compiled in. The field below is an optional fallback only and is never required to open the app.',
              'يتصل التطبيق تلقائياً عندما يكون رابط الإنتاج مضمّناً في البناء. الحقل أدناه خيار احتياطي فقط وليس مطلوباً لفتح التطبيق.',
            )}
          </Text>
        </View>

        <Text style={styles.sectionTitle}>{t(language, 'OPTIONAL FALLBACK URL', 'رابط احتياطي اختياري')}</Text>
        <View style={styles.card}>
          <Text style={styles.label}>{t(language, 'HTTPS base URL', 'عنوان HTTPS الأساسي')}</Text>
          <TextInput
            value={draft}
            onChangeText={setDraft}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            placeholder="https://your-service.up.railway.app"
            placeholderTextColor={Colors.textMuted}
            style={styles.input}
          />
          <Text style={styles.hint}>
            {t(
              language,
              'The app never stores API keys. Keys live only in Railway Variables on the server.',
              'التطبيق لا يخزن أي مفاتيح. المفاتيح موجودة فقط في متغيرات Railway على الخادم.',
            )}
          </Text>
          <Text style={styles.connectionDetail}>{connection.detail}{connection.latency ? ` · ${connection.latency} ms` : ''}</Text>
          <View style={styles.buttonRow}>
            {automaticBaseUrl ? (
              <TouchableOpacity onPress={async () => { await useAutomaticBaseUrl(); }} style={styles.secondary}>
                <Text style={styles.secondaryText}>{t(language, 'AUTO', 'تلقائي')}</Text>
              </TouchableOpacity>
            ) : null}
            <TouchableOpacity onPress={test} disabled={busy} style={styles.secondary}>
              {busy ? <ActivityIndicator color={Colors.gold} size="small" /> : <Text style={styles.secondaryText}>{t(language, 'TEST', 'فحص')}</Text>}
            </TouchableOpacity>
            <PrimaryButton title={t(language, 'SAVE & CONNECT', 'حفظ واتصال')} onPress={save} loading={busy} style={{ flex: 1 }} />
          </View>
        </View>

        <Text style={styles.sectionTitle}>{t(language, 'LANGUAGE', 'اللغة')}</Text>
        <View style={styles.card}>
          <View style={styles.langRow}>
            {['en', 'ar'].map((code) => (
              <TouchableOpacity
                key={code}
                onPress={() => setLanguage(code)}
                style={[styles.langChip, language === code && styles.langChipActive]}
              >
                <Text style={[styles.langText, language === code && styles.langTextActive]}>
                  {code === 'en' ? 'English' : 'العربية'}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
          <Text style={styles.hint}>{t(language, 'Saved on this device.', 'محفوظة على هذا الجهاز.')}</Text>
        </View>

        <Text style={styles.sectionTitle}>{t(language, 'AI PROVIDERS', 'مزودو الذكاء الاصطناعي')}</Text>
        <View style={styles.card}>
          {[
            ['Gemini', ai.gemini],
            ['Mistral', ai.mistral],
          ].map(([name, info]) => (
            <View key={name} style={styles.providerRow}>
              <Text style={styles.providerName}>{name}</Text>
              <Text style={[styles.providerState, { color: info?.configured ? Colors.greenPositive : Colors.red }]}>
                {info?.configured
                  ? t(language, `READY · ${info.model || ''}`, `جاهز · ${info.model || ''}`)
                  : t(language, 'KEY NOT CONFIGURED', 'المفتاح غير مضبوط')}
              </Text>
            </View>
          ))}
          <Text style={styles.hint}>
            {t(
              language,
              'If both models are unavailable, the deterministic technical engine still returns its own result and says so.',
              'إذا تعذر النموذجان يعمل المحرك الفني الحاسم ويوضح ذلك.',
            )}
          </Text>
        </View>

        <Text style={styles.sectionTitle}>{t(language, 'DATA SOURCES', 'مصادر البيانات')}</Text>
        <View style={styles.card}>
          {providers.length ? providers.map((source) => (
            <View key={source.name} style={styles.providerRow}>
              <Text style={styles.providerName}>{source.name}</Text>
              <Text style={[styles.providerState, { color: source.configured ? Colors.greenPositive : Colors.textMuted }]}>
                {source.configured ? t(language, 'CONFIGURED', 'مضبوط') : t(language, 'NOT CONFIGURED', 'غير مضبوط')}
              </Text>
            </View>
          )) : (
            <Text style={styles.hint}>{t(language, 'Connect the backend to list its sources.', 'اتصل بالخادم لعرض مصادره.')}</Text>
          )}
        </View>

        <Text style={styles.about}>
          {t(language, 'NEXUS AI · analysis only · never executes trades', 'NEXUS AI · تحليل فقط · لا ينفذ صفقات')}
        </Text>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 12 },
  title: { color: Colors.white, fontSize: Fonts.sizes.xxl, fontWeight: '900' },
  sectionTitle: { color: Colors.textSecondary, fontSize: 10, fontWeight: '900', letterSpacing: 1, marginTop: 18, marginBottom: 8 },
  card: { borderRadius: 18, borderWidth: 1, borderColor: Colors.border, backgroundColor: Colors.cardBg, padding: 14 },
  label: { color: Colors.textMuted, fontSize: 9, fontWeight: '800', letterSpacing: 0.6, marginBottom: 6 },
  input: { color: Colors.white, backgroundColor: '#0D0D14', borderRadius: 12, borderWidth: 1, borderColor: Colors.border, paddingHorizontal: 12, paddingVertical: 11, fontSize: Fonts.sizes.sm },
  hint: { color: Colors.textMuted, fontSize: 9, lineHeight: 15, marginTop: 8 },
  autoRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  autoLabel: { color: Colors.textMuted, fontSize: 9, fontWeight: '800', letterSpacing: 0.6 },
  autoState: { fontSize: 8, fontWeight: '900', letterSpacing: 0.5 },
  autoValue: { color: Colors.textPrimary, fontSize: 11, marginTop: 7, fontWeight: '600' },
  connectionDetail: { color: Colors.textSecondary, fontSize: 9, marginTop: 8, lineHeight: 15 },
  buttonRow: { flexDirection: 'row', gap: 8, marginTop: 12 },
  secondary: { width: 84, borderRadius: 16, borderWidth: 1, borderColor: Colors.gold + '66', alignItems: 'center', justifyContent: 'center' },
  secondaryText: { color: Colors.gold, fontSize: 11, fontWeight: '900' },
  langRow: { flexDirection: 'row', gap: 8 },
  langChip: { flex: 1, borderRadius: 12, borderWidth: 1, borderColor: Colors.border, paddingVertical: 10, alignItems: 'center' },
  langChipActive: { borderColor: Colors.gold, backgroundColor: Colors.gold + '15' },
  langText: { color: Colors.textSecondary, fontSize: Fonts.sizes.sm, fontWeight: '700' },
  langTextActive: { color: Colors.goldLight },
  providerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingVertical: 6 },
  providerName: { color: Colors.white, fontSize: Fonts.sizes.sm, fontWeight: '700' },
  providerState: { fontSize: 9, fontWeight: '900', letterSpacing: 0.4, maxWidth: '66%', textAlign: 'right' },
  about: { color: Colors.textMuted, fontSize: 9, textAlign: 'center', marginTop: 22 },
});
