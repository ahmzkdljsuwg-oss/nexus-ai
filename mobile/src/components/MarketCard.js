import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { MARKET_COPY, t } from '../i18n';
import { FadeIn } from './ui';

export function MarketCard({ market, language, onPress, index = 0 }) {
  const copy = MARKET_COPY[market.key] || {};
  const live = market.status === 'LIVE';
  const title = language === 'ar' ? copy.ar : copy.en;
  const description = language === 'ar' ? copy.descAr : copy.descEn;
  return (
    <FadeIn delay={index * 55} style={styles.wrapper}>
      <Pressable onPress={onPress} style={({ pressed }) => [styles.press, pressed && { opacity: 0.88 }]}>
        <LinearGradient
          colors={live ? [market.accent + '22', Colors.cardBg, '#0B0B15'] : ['#171726', '#0D0D18']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.card, { borderColor: live ? market.accent + '55' : Colors.border, shadowColor: live ? market.accent : '#000000' }]}
        >
          <View style={styles.head}>
            <View style={[styles.iconWrap, { backgroundColor: market.accent + '18' }]}>
              <Text style={styles.icon}>{market.icon}</Text>
            </View>
            <View style={[styles.status, { backgroundColor: live ? Colors.greenPositive + '18' : Colors.red + '14' }]}>
              <View style={[styles.statusDot, { backgroundColor: live ? Colors.greenPositive : Colors.red }]} />
              <Text style={[styles.statusText, { color: live ? Colors.greenPositive : Colors.red }]}>
                {live ? t(language, 'LIVE', 'مباشر') : t(language, 'DATA UNAVAILABLE', 'البيانات غير متاحة')}
              </Text>
            </View>
          </View>
          <Text style={styles.title}>{title}</Text>
          <Text numberOfLines={2} style={styles.desc}>{description}</Text>
          <View style={styles.footer}>
            <View>
              <Text style={styles.priceLabel}>{live ? t(language, 'LAST PRICE', 'آخر سعر') : t(language, 'SOURCE', 'المصدر')}</Text>
              <Text style={[styles.price, { color: live ? Colors.white : Colors.textMuted }]} numberOfLines={1}>
                {live ? market.price_display : t(language, 'UNAVAILABLE', 'غير متاح')}
              </Text>
            </View>
            <View style={[styles.arrow, { borderColor: market.accent + '55' }]}>
              <Text style={{ color: market.accent, fontSize: 16 }}>›</Text>
            </View>
          </View>
        </LinearGradient>
      </Pressable>
    </FadeIn>
  );
}

const styles = StyleSheet.create({
  wrapper: { width: '48.5%', marginBottom: 12 },
  press: { borderRadius: 20 },
  card: { borderRadius: 20, borderWidth: 1, padding: 14, minHeight: 194, shadowOpacity: 0.22, shadowRadius: 16, shadowOffset: { width: 0, height: 8 } },
  head: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', gap: 6 },
  iconWrap: { width: 36, height: 36, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
  icon: { fontSize: 18 },
  status: { flexDirection: 'row', alignItems: 'center', gap: 4, borderRadius: 999, paddingHorizontal: 6, paddingVertical: 3 },
  statusDot: { width: 5, height: 5, borderRadius: 3 },
  statusText: { fontSize: 8, fontWeight: '800' },
  title: { color: Colors.white, fontSize: Fonts.sizes.md, fontWeight: '900', marginTop: 12 },
  desc: { color: Colors.textSecondary, fontSize: Fonts.sizes.xs, lineHeight: 16, marginTop: 4, minHeight: 32 },
  footer: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: 'auto', paddingTop: 12 },
  priceLabel: { color: Colors.textMuted, fontSize: 8, fontWeight: '700', letterSpacing: 0.7 },
  price: { fontSize: Fonts.sizes.lg, fontWeight: '900', marginTop: 2, maxWidth: 110 },
  arrow: { width: 28, height: 28, borderRadius: 14, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
});
