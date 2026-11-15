# NEXUS AI — Black Screen Fix (iOS)

## Symptom
The installed IPA opened on a dark blank screen and never showed the interface.

## Root cause (confirmed from the device-simulator log)
`SplashScreen.js` applied an `Animated.Value` (`glow`) to the `opacity` style of a **plain `View`**:

```jsx
<View style={[styles.glowTop, { opacity: glow }]} />
```

A plain `View` cannot receive an animated value. React Native passed the animation object to the native layer, which tried `-[__NSDictionaryM doubleValue]` and raised:

```
Exception thrown while executing UI block:
-[__NSDictionaryM doubleValue]: unrecognized selector sent to instance
```

That exception aborted the whole UI commit, so only the dark root background was rendered.

## Fix
The node is now an `Animated.View`:

```jsx
<Animated.View style={[styles.glowTop, { opacity: glow }]} />
```

## Verification
- iOS simulator build of commit `fix: animate splash glow with Animated.View to prevent native UI crash`.
- App log: `0` occurrences of "Exception thrown while executing UI block".
- Screenshot OCR of the running app reads the real Home screen:
  `NEXUS AI`, `ADVANCED TRADING INTELLIGENCE`, `BACKEND OFFLINE`,
  `AWAITING SERVER DEPLOYMENT`, `0/7`, `MARKETS`, bottom tabs
  `Home / Signals / Chat / History / Settings`.
- Screenshot kept at `docs/screenshots/expo-app-launch.png`.

The app now renders normally with no backend configured. It honestly shows
`BACKEND OFFLINE` and `AWAITING SERVER DEPLOYMENT`; it does not invent prices.
