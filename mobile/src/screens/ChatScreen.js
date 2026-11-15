import React, { useRef, useState } from 'react';
import {
  KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Colors } from '../theme/colors';
import { PremiumBackdrop } from '../components/PremiumBackdrop';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { t } from '../i18n';
import { friendlyError } from '../api/client';

export default function ChatScreen() {
  const insets = useSafeAreaInsets();
  const { client, language } = useApp();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const scroll = useRef(null);

  const send = async () => {
    const text = input.trim();
    if (!text || busy) return;
    setInput('');
    setError('');
    const next = [...messages, { role: 'user', content: text }];
    setMessages(next);
    setBusy(true);
    try {
      const response = await client.chat({
        message: text,
        history: next.slice(-12).map((item) => ({ role: item.role, content: item.content })),
        context: '',
      });
      setMessages([...next, { role: 'assistant', content: response.data.answer, model: response.data.model }]);
    } catch (err) {
      setError(friendlyError(err));
    } finally {
      setBusy(false);
      setTimeout(() => scroll.current?.scrollToEnd({ animated: true }), 80);
    }
  };

  return (
    <KeyboardAvoidingView style={styles.container} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <PremiumBackdrop />
      <View style={[styles.header, { paddingTop: insets.top + 10 }]}>
        <View>
          <Text style={styles.title}>{t(language, 'GEMINI CHAT', 'محادثة Gemini')}</Text>
          <Text style={styles.subtitle}>
            {t(language, 'Separate from the analysis engine. It cannot issue recommendations.', 'منفصلة عن محرك التحليل. لا تصدر توصيات.')}
          </Text>
        </View>
      </View>
      <ScrollView
        ref={scroll}
        contentContainerStyle={{ padding: 16, paddingBottom: 24 }}
        onContentSizeChange={() => scroll.current?.scrollToEnd({ animated: true })}
      >
        {!messages.length ? (
          <View style={styles.intro}>
            <Text style={styles.introTitle}>{t(language, 'Ask about concepts, not prices.', 'اسأل عن المفاهيم، لا عن الأسعار.')}</Text>
            <Text style={styles.introText}>
              {t(
                language,
                'This page explains trading concepts and answers general questions. Live prices and recommendations come only from the analysis screens, where every number is tied to a verified source.',
                'تشرح هذه الصفحة مفاهيم التداول وتجيب على أسئلة عامة. الأسعار والتوصيات تأتي فقط من شاشات التحليل حيث كل رقم مرتبط بمصدر موثق.',
              )}
            </Text>
          </View>
        ) : null}
        {messages.map((message, index) => (
          <View key={index} style={[styles.bubble, message.role === 'user' ? styles.userBubble : styles.aiBubble]}>
            <Text style={styles.role}>{message.role === 'user' ? t(language, 'YOU', 'أنت') : (message.model || 'GEMINI')}</Text>
            <Text style={message.role === 'user' ? styles.userText : styles.aiText}>{message.content}</Text>
          </View>
        ))}
        {busy ? <Text style={styles.typing}>{t(language, 'Thinking…', 'جارٍ التفكير…')}</Text> : null}
        {error ? <Text style={styles.error}>{error}</Text> : null}
      </ScrollView>
      <View style={[styles.composer, { paddingBottom: insets.bottom + 8 }]}>
        <TextInput
          value={input}
          onChangeText={setInput}
          placeholder={t(language, 'Type a question…', 'اكتب سؤالك…')}
          placeholderTextColor={Colors.textMuted}
          style={styles.input}
          multiline
          maxLength={4000}
        />
        <Pressable onPress={send} disabled={busy || !input.trim()} style={[styles.send, (!input.trim() || busy) && { opacity: 0.4 }]}>
          <Text style={styles.sendText}>↑</Text>
        </Pressable>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: { paddingHorizontal: 16, paddingBottom: 10, borderBottomWidth: 1, borderBottomColor: Colors.border },
  title: { color: Colors.white, fontSize: Fonts.sizes.xxl, fontWeight: '900' },
  subtitle: { color: Colors.textMuted, fontSize: 9, marginTop: 3 },
  intro: { borderRadius: 18, borderWidth: 1, borderColor: Colors.border, padding: 16, backgroundColor: Colors.cardBg },
  introTitle: { color: Colors.goldLight, fontSize: Fonts.sizes.md, fontWeight: '900' },
  introText: { color: Colors.textSecondary, fontSize: Fonts.sizes.xs, lineHeight: 18, marginTop: 8 },
  bubble: { borderRadius: 16, padding: 12, marginBottom: 10, maxWidth: '92%' },
  userBubble: { alignSelf: 'flex-end', backgroundColor: Colors.greenPositive + '18', borderWidth: 1, borderColor: Colors.greenPositive + '44' },
  aiBubble: { alignSelf: 'flex-start', backgroundColor: Colors.cardBg, borderWidth: 1, borderColor: Colors.border },
  role: { color: Colors.textMuted, fontSize: 8, fontWeight: '900', letterSpacing: 0.8, marginBottom: 4 },
  userText: { color: Colors.white, fontSize: Fonts.sizes.sm, lineHeight: 20 },
  aiText: { color: Colors.textPrimary, fontSize: Fonts.sizes.sm, lineHeight: 21 },
  typing: { color: Colors.textMuted, fontSize: Fonts.sizes.xs, marginBottom: 8 },
  error: { color: Colors.red, fontSize: Fonts.sizes.xs, lineHeight: 18 },
  composer: { flexDirection: 'row', alignItems: 'flex-end', gap: 8, paddingHorizontal: 12, paddingTop: 8, borderTopWidth: 1, borderTopColor: Colors.border, backgroundColor: '#0D0D14' },
  input: { flex: 1, color: Colors.white, backgroundColor: Colors.cardBg, borderRadius: 16, borderWidth: 1, borderColor: Colors.border, paddingHorizontal: 14, paddingVertical: 10, maxHeight: 120, fontSize: Fonts.sizes.sm },
  send: { width: 40, height: 40, borderRadius: 20, backgroundColor: Colors.gold, alignItems: 'center', justifyContent: 'center' },
  sendText: { color: Colors.background, fontSize: 20, fontWeight: '900' },
});
