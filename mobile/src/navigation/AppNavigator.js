import React from 'react';
import { Platform, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { BlurView } from 'expo-blur';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Colors } from '../theme/colors';
import { Fonts } from '../theme/fonts';
import { useApp } from '../state/AppContext';
import { t } from '../i18n';
import HomeScreen from '../screens/HomeScreen';
import MarketDetailScreen from '../screens/MarketDetailScreen';
import RecommendationsScreen from '../screens/RecommendationsScreen';
import HistoryScreen from '../screens/HistoryScreen';
import ChatScreen from '../screens/ChatScreen';
import SettingsScreen from '../screens/SettingsScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

const TABS = [
  { name: 'HomeTab', icon: '◈', en: 'Home', ar: 'الرئيسية' },
  { name: 'SignalsTab', icon: '⚡', en: 'Signals', ar: 'التوصيات' },
  { name: 'ChatTab', icon: '✦', en: 'Chat', ar: 'المحادثة' },
  { name: 'HistoryTab', icon: '▤', en: 'History', ar: 'السجل' },
  { name: 'SettingsTab', icon: '⚙', en: 'Settings', ar: 'الإعدادات' },
];

function TabBar({ state, navigation }) {
  const insets = useSafeAreaInsets();
  const { language } = useApp();
  return (
    <View style={[styles.tabWrap, { paddingBottom: insets.bottom + 8 }]} pointerEvents="box-none">
      <BlurView intensity={Platform.OS === 'ios' ? 60 : 90} tint="dark" style={styles.tabBar}>
        {state.routes.map((route, index) => {
          const item = TABS.find((tab) => tab.name === route.name);
          const focused = state.index === index;
          return (
            <TouchableOpacity
              key={route.key}
              accessibilityRole="button"
              accessibilityLabel={language === 'ar' ? item.ar : item.en}
              onPress={() => {
                const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
                if (!focused && !event.defaultPrevented) navigation.navigate(route.name);
              }}
              style={styles.tabItem}
            >
              <Text style={[styles.tabIcon, focused && styles.tabIconActive]}>{item.icon}</Text>
              <Text style={[styles.tabLabel, focused && styles.tabLabelActive]} numberOfLines={1}>
                {language === 'ar' ? item.ar : item.en}
              </Text>
              {focused ? <View style={styles.activeDot} /> : null}
            </TouchableOpacity>
          );
        })}
      </BlurView>
    </View>
  );
}

export default function AppNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false, contentStyle: { backgroundColor: Colors.background }, animation: 'fade_from_bottom' }}>
      <Stack.Screen name="Tabs">
        {() => (
          <Tab.Navigator screenOptions={{ headerShown: false }} tabBar={(props) => <TabBar {...props} />}>
            <Tab.Screen name="HomeTab" component={HomeScreen} />
            <Tab.Screen name="SignalsTab" component={RecommendationsScreen} />
            <Tab.Screen name="ChatTab" component={ChatScreen} />
            <Tab.Screen name="HistoryTab" component={HistoryScreen} />
            <Tab.Screen name="SettingsTab" component={SettingsScreen} />
          </Tab.Navigator>
        )}
      </Stack.Screen>
      <Stack.Screen name="MarketDetail" component={MarketDetailScreen} options={{ animation: 'slide_from_right' }} />
    </Stack.Navigator>
  );
}

const styles = StyleSheet.create({
  tabWrap: { position: 'absolute', left: 0, right: 0, bottom: 0, paddingHorizontal: 14 },
  tabBar: {
    flexDirection: 'row',
    borderRadius: 24,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: Colors.borderLight,
    backgroundColor: '#0D0D14B3',
    paddingVertical: 9,
  },
  tabItem: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 2 },
  tabIcon: { color: Colors.textMuted, fontSize: 15 },
  tabIconActive: { color: Colors.gold },
  tabLabel: { color: Colors.textMuted, fontSize: 8, fontWeight: '700' },
  tabLabelActive: { color: Colors.goldLight, fontWeight: '900' },
  activeDot: { width: 4, height: 4, borderRadius: 2, backgroundColor: Colors.gold, marginTop: 1 },
});
