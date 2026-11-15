import React, { useEffect, useRef, useState } from 'react';
import { Animated, Pressable, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Line, Rect } from 'react-native-svg';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { t } from '../i18n';

export function ConnectionBadge({ connection, language }) {
  const online = connection.state === 'online';
  const degraded = connection.state === 'degraded';
  const checking = connection.state === 'checking';
  const color = online ? Colors.greenPositive : degraded ? Colors.gold : checking ? Colors.gold : Colors.red;
  const label = online
    ? t(language, 'BACKEND ONLINE', 'الخادم متصل')
    : degraded
      ? t(language, 'BACKEND DEGRADED', 'الخادم يعمل جزئياً')
      : checking
        ? t(language, 'CHECKING SERVER', 'جارٍ فحص الخادم')
        : t(language, 'BACKEND OFFLINE', 'الخادم غير متصل');
  return (
    <View style={[styles.badge, { borderColor: color + '55', backgroundColor: color + '12' }]}>
      <View style={[styles.dot, { backgroundColor: color }]} />
      <Text style={[styles.badgeText, { color }]}>{label}</Text>
      {online && connection.latency != null ? (
        <Text style={styles.latency}>{connection.latency} ms</Text>
      ) : null}
    </View>
  );
}

export function DirectionBadge({ direction, language }) {
  const up = direction === 'UP';
  const down = direction === 'DOWN';
  const color = up ? Colors.greenPositive : down ? Colors.red : Colors.textSecondary;
  const label = up ? t(language, 'BUY', 'شراء') : down ? t(language, 'SELL', 'بيع') : t(language, 'NO TRADE', 'لا تداول');
  return (
    <View style={[styles.direction, { backgroundColor: color + '1C', borderColor: color + '66' }]}>
      <Text style={[styles.directionText, { color }]}>{up ? '▲ ' : down ? '▼ ' : '● '}{label}</Text>
    </View>
  );
}

export function PrimaryButton({ title, subtitle, onPress, disabled, loading, colors = Colors.gradientGreen, style }) {
  return (
    <Pressable onPress={onPress} disabled={disabled || loading} style={({ pressed }) => [style, pressed && { opacity: 0.85 }]}>
      <LinearGradient colors={disabled ? ['#24242F', '#181820'] : colors} style={styles.button}>
        <Text style={[styles.buttonTitle, disabled && { color: Colors.textMuted }]}>
          {loading ? '…' : title}
        </Text>
        {subtitle ? <Text style={styles.buttonSubtitle}>{subtitle}</Text> : null}
      </LinearGradient>
    </Pressable>
  );
}

export function FadeIn({ children, delay = 0, style }) {
  const anim = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(anim, { toValue: 1, duration: 420, delay, useNativeDriver: true }).start();
  }, [anim, delay]);
  return (
    <Animated.View style={[style, { opacity: anim, transform: [{ translateY: anim.interpolate({ inputRange: [0, 1], outputRange: [12, 0] }) }] }]}>
      {children}
    </Animated.View>
  );
}

export function CandleChart({ candles = [], accent = Colors.gold, height = 150, language = 'en' }) {
  const [width, setWidth] = useState(0);
  const rows = candles.slice(-42);
  const values = rows.flatMap((item) => [Number(item.h ?? item.high), Number(item.l ?? item.low)]).filter(Number.isFinite);
  const min = values.length ? Math.min(...values) : 0;
  const max = values.length ? Math.max(...values) : 0;
  const span = Math.max(max - min, 1e-9);
  const gap = width / Math.max(rows.length, 1);
  const bodyWidth = Math.max(2, gap * 0.58);
  return (
    <View style={{ height }} onLayout={(event) => setWidth(event.nativeEvent.layout.width)}>
      {width > 0 && rows.length ? (
        <Svg width={width} height={height}>
          {rows.map((item, index) => {
            const open = Number(item.o ?? item.open);
            const close = Number(item.c ?? item.close);
            const high = Number(item.h ?? item.high);
            const low = Number(item.l ?? item.low);
            const x = index * gap + gap / 2;
            const y = (value) => height - ((value - min) / span) * (height - 10) - 5;
            const top = Math.min(y(open), y(close));
            const bodyHeight = Math.max(1.5, Math.abs(y(open) - y(close)));
            const color = close >= open ? Colors.greenPositive : Colors.red;
            return (
              <React.Fragment key={`${item.t || index}`}>
                <Line x1={x} x2={x} y1={y(high)} y2={y(low)} stroke={color} strokeWidth={1} />
                <Rect x={x - bodyWidth / 2} y={top} width={bodyWidth} height={bodyHeight} fill={color} rx={1} />
              </React.Fragment>
            );
          })}
        </Svg>
      ) : (
        <View style={styles.chartEmpty}>
          <Text style={styles.chartEmptyText}>{t(language, 'No verified candles', 'لا توجد شموع موثقة')}</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 10,
    paddingVertical: 5,
    gap: 6,
  },
  dot: { width: 7, height: 7, borderRadius: 4 },
  badgeText: { fontSize: 10, fontWeight: '800', letterSpacing: 0.7 },
  latency: { color: Colors.textMuted, fontSize: 9 },
  direction: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 12, paddingVertical: 6 },
  directionText: { fontSize: 13, fontWeight: '900', letterSpacing: 0.5 },
  button: { borderRadius: 16, paddingVertical: 15, paddingHorizontal: 18, alignItems: 'center' },
  buttonTitle: { color: '#07110A', fontWeight: '900', fontSize: Fonts.sizes.md },
  buttonSubtitle: { color: '#07110ACC', fontSize: Fonts.sizes.xs, marginTop: 2 },
  chartEmpty: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  chartEmptyText: { color: Colors.textMuted, fontSize: Fonts.sizes.xs },
});
