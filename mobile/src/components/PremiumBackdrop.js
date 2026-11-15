import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Colors } from '../theme/colors';

export function PremiumBackdrop() {
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <View style={styles.topGlow} />
      <View style={styles.sideGlow} />
    </View>
  );
}

const styles = StyleSheet.create({
  topGlow: { position: 'absolute', top: -170, right: -100, width: 340, height: 340, borderRadius: 170, backgroundColor: Colors.gold + '0D' },
  sideGlow: { position: 'absolute', bottom: 40, left: -150, width: 300, height: 300, borderRadius: 150, backgroundColor: '#3D8EFF0A' },
});
