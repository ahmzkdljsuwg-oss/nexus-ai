import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, StyleSheet, Text, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { useApp } from '../state/AppContext';
import { splashCanFinish, splashStatus, SPLASH_MAX_MS, SPLASH_MIN_MS } from '../state/startup';

export default function SplashScreen({ onFinish }) {
  const insets = useSafeAreaInsets();
  const { ready, booting, baseUrl, connection, language } = useApp();
  const [elapsed, setElapsed] = useState(false);
  const [forced, setForced] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const opacity = useRef(new Animated.Value(1)).current;
  const float = useRef(new Animated.Value(0)).current;
  const progress = useRef(new Animated.Value(0)).current;
  const glow = useRef(new Animated.Value(0.65)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(float, { toValue: 1, duration: 1500, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
        Animated.timing(float, { toValue: 0, duration: 1500, easing: Easing.inOut(Easing.quad), useNativeDriver: true }),
      ]),
    );
    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(glow, { toValue: 1, duration: 1300, useNativeDriver: true }),
        Animated.timing(glow, { toValue: 0.65, duration: 1300, useNativeDriver: true }),
      ]),
    );
    loop.start();
    pulse.start();
    Animated.timing(progress, { toValue: 1, duration: 2600, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start();
    const minTimer = setTimeout(() => setElapsed(true), SPLASH_MIN_MS);
    const maxTimer = setTimeout(() => setForced(true), SPLASH_MAX_MS);
    return () => {
      loop.stop();
      pulse.stop();
      clearTimeout(minTimer);
      clearTimeout(maxTimer);
    };
  }, [float, glow, progress]);

  useEffect(() => {
    if (!splashCanFinish({ elapsed, ready, booting, forced }) || leaving) return;
    setLeaving(true);
    Animated.timing(opacity, { toValue: 0, duration: 420, easing: Easing.out(Easing.quad), useNativeDriver: true }).start();
    const handoff = setTimeout(() => { if (onFinish) onFinish(); }, 520);
    return () => clearTimeout(handoff);
  }, [booting, elapsed, forced, leaving, onFinish, opacity, ready]);

  const status = splashStatus({ baseUrl, connection, booting, language });
  const width = progress.interpolate({ inputRange: [0, 1], outputRange: ['4%', '100%'] });
  const translateY = float.interpolate({ inputRange: [0, 1], outputRange: [0, -7] });

  return (
    <Animated.View style={[styles.root, { opacity }]} pointerEvents="auto">
      <Animated.View style={[styles.glowTop, { opacity: glow }]} />
      <View style={styles.glowBottom} />
      <View style={styles.grid} />
      <View style={[styles.center, { paddingTop: insets.top }]}>
        <Animated.View style={[styles.ring, { transform: [{ translateY }] }]}>
          <LinearGradient colors={['#24243C', '#0B0B16']} style={styles.ringInner}>
            <Text style={styles.mark}>N</Text>
            <View style={styles.markDot} />
          </LinearGradient>
        </Animated.View>
        <Text style={styles.name}>NEXUS AI</Text>
        <Text style={styles.arabic}>نظام ذكاء التداول</Text>
        <Text style={styles.tagline}>ADVANCED MARKET INTELLIGENCE</Text>
      </View>

      <View style={[styles.progressWrap, { bottom: insets.bottom + 92 }]}>
        <Text style={styles.status}>{status}</Text>
        <View style={styles.track}>
          <Animated.View style={[styles.fill, { width }]} />
        </View>
      </View>

      <View style={[styles.footer, { bottom: insets.bottom + 30 }]}>
        <Text style={styles.footerLabel}>POWERED BY</Text>
        <View style={styles.partner}><Text style={styles.partnerText}>GEMINI</Text></View>
        <View style={styles.partner}><Text style={styles.partnerText}>MISTRAL</Text></View>
        <View style={styles.partner}><Text style={styles.partnerText}>EO DATA</Text></View>
      </View>
      <View style={[styles.homeBar, { bottom: insets.bottom + 8 }]} />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: { ...StyleSheet.absoluteFillObject, zIndex: 50, elevation: 50, backgroundColor: Colors.background, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  glowTop: { position: 'absolute', top: -140, width: 460, height: 460, borderRadius: 230, backgroundColor: '#F0A50018' },
  glowBottom: { position: 'absolute', bottom: -110, right: -110, width: 380, height: 380, borderRadius: 190, backgroundColor: '#3D8EFF12' },
  grid: { ...StyleSheet.absoluteFillObject, opacity: 0.045, borderColor: '#FFFFFF', borderTopWidth: 1, borderLeftWidth: 1 },
  center: { alignItems: 'center', marginTop: -24 },
  ring: { width: 124, height: 124, borderRadius: 38, alignItems: 'center', justifyContent: 'center', backgroundColor: '#F0A50010', borderWidth: 1.5, borderColor: '#F0A50066', shadowColor: Colors.gold, shadowOpacity: 0.42, shadowRadius: 28, shadowOffset: { width: 0, height: 0 } },
  ringInner: { width: 104, height: 104, borderRadius: 30, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: '#FFFFFF10' },
  mark: { color: Colors.goldLight, fontSize: 56, fontWeight: '900', letterSpacing: -3, marginTop: -4 },
  markDot: { position: 'absolute', right: 24, bottom: 24, width: 7, height: 7, borderRadius: 4, backgroundColor: Colors.greenPositive },
  name: { color: Colors.goldLight, fontSize: 38, fontWeight: '900', letterSpacing: 3, marginTop: 26, textShadowColor: '#F0A50055', textShadowRadius: 18 },
  arabic: { color: Colors.textSecondary, fontSize: 16, marginTop: 4, letterSpacing: 1 },
  tagline: { color: Colors.textMuted, fontSize: 10, letterSpacing: 2.4, marginTop: 10, fontWeight: '700' },
  progressWrap: { position: 'absolute', width: 230, alignItems: 'center' },
  status: { color: Colors.textMuted, fontSize: 9, fontWeight: '800', letterSpacing: 0.9, marginBottom: 10, textAlign: 'center' },
  track: { width: '100%', height: 3, borderRadius: 3, backgroundColor: '#FFFFFF12', overflow: 'hidden' },
  fill: { height: '100%', borderRadius: 3, backgroundColor: Colors.goldLight },
  footer: { position: 'absolute', flexDirection: 'row', alignItems: 'center', gap: 7 },
  footerLabel: { color: Colors.textMuted, fontSize: 8, letterSpacing: 0.8, marginRight: 2 },
  partner: { borderRadius: 8, borderWidth: 1, borderColor: Colors.border, backgroundColor: '#FFFFFF08', paddingHorizontal: 8, paddingVertical: 4 },
  partnerText: { color: Colors.textSecondary, fontSize: 8, fontWeight: '800', letterSpacing: 0.5 },
  homeBar: { position: 'absolute', width: 130, height: 4, borderRadius: 2, backgroundColor: '#FFFFFF2E' },
});
