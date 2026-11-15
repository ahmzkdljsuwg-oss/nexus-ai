import React, { useCallback, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { AppProvider } from './src/state/AppContext';
import AppNavigator from './src/navigation/AppNavigator';
import { Colors } from './src/theme/colors';
import SplashScreen from './src/screens/SplashScreen';

const theme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: Colors.background,
    card: Colors.cardBg,
    text: Colors.white,
    border: Colors.border,
    primary: Colors.gold,
  },
};

export default function App() {
  const [splashDone, setSplashDone] = useState(false);
  const finishSplash = useCallback(() => setSplashDone(true), []);

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: Colors.background }}>
      <SafeAreaProvider>
        <AppProvider>
          <NavigationContainer theme={theme}>
            <StatusBar style="light" />
            <AppNavigator />
            {!splashDone ? <SplashScreen onFinish={finishSplash} /> : null}
          </NavigationContainer>
        </AppProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
