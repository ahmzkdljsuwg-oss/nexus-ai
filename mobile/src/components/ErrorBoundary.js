import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Colors } from '../theme/colors';

export default class ErrorBoundary extends React.Component {
  state = { error: null };

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidCatch(error, info) {
    console.error('NEXUS_APP_ERROR', error, info?.componentStack);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <View style={styles.root}>
        <Text style={styles.title}>NEXUS AI</Text>
        <Text style={styles.body}>The app hit a startup error.</Text>
        <Text style={styles.body}>تعذّر تشغيل الواجهة.</Text>
        <Text style={styles.detail} numberOfLines={4}>{String(this.state.error?.message || this.state.error)}</Text>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: Colors.background, alignItems: 'center', justifyContent: 'center', padding: 28 },
  title: { color: Colors.goldLight, fontSize: 30, fontWeight: '900', letterSpacing: 3 },
  body: { color: Colors.textPrimary, fontSize: 14, marginTop: 14, textAlign: 'center' },
  detail: { color: Colors.textMuted, fontSize: 11, marginTop: 14, textAlign: 'center' },
});
