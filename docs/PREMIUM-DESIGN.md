# NEXUS AI — Premium design integration

Source of truth: `NEXUS AI — v2 Premium.html` (last approved HTML shell from the workspace mini-app history; kept beside the project, not generated anew).

The Expo iOS app keeps the original ForexBro structure and navigation. The approved HTML look is applied through shared tokens and components instead of replacing screens.

## Token mapping

| HTML | App token |
| --- | --- |
| `--bg: #070711` | `Colors.background` |
| `--card: #111120` | `Colors.cardBg` |
| `--card2: #161628` | `Colors.cardBg2` |
| `--gold: #F0A500` | `Colors.gold` |
| `--gold2: #FFB930` | `Colors.goldLight` |
| `--green: #00C896` | `Colors.greenPositive` |
| `--red: #FF3D5A` | `Colors.red` |
| `--text: #F0F0F8` | `Colors.textPrimary` |
| `--text2: #8888A8` | `Colors.textSecondary` |
| `--text3: #4A4A6A` | `Colors.textMuted` |
| `--radius: 18px` | 18–24 px cards |

## What was integrated

- `mobile/src/screens/SplashScreen.js` — gold ring logo, Arabic subtitle, `ADVANCED MARKET INTELLIGENCE`, animated glow, progress track and honest server status line.
- `mobile/src/state/startup.js` — splash timing (2.2 s minimum, 6.5 s maximum) and automatic base-URL resolution.
- `mobile/src/components/PremiumBackdrop.js` — the HTML soft gold/blue glows, added to every screen.
- `mobile/src/screens/HomeScreen.js` — gold logo ring, intelligence pill, refresh/settings actions, date line, gold hero card and honest “awaiting deployment” card.
- `mobile/src/components/MarketCard.js` — deeper gradients, accent border and shadow per market.
- `mobile/src/navigation/AppNavigator.js` — translucent tab bar with gold active pill.
- `mobile/src/screens/SettingsScreen.js` — automatic production URL status; manual URL moved to an optional fallback section.

## Preserved

All seven markets stay separate, the normal and strong analysis modes are unchanged, recommendations/history/chat/settings are unchanged, no login gate was added, and no fake prices or fake Online state are introduced.
