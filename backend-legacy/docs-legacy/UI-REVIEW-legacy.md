# NEXUS AI — UI review and verification

## Scope

Reviewed every SwiftUI screen in `ios/NexusAI/Views` and every action they expose.
The goal: no decorative buttons, no fake online state, no demo data.

## Real behaviour

| Screen | Action | Result |
| --- | --- | --- |
| Auth | Enter server URL | `AppState.configureServer` validates the URL, saves it to `UserDefaults`, then calls `/api/health` |
| Auth | Use this server | Same check; invalid URL is rejected with a visible message and the saved value is cleared |
| Auth | Sign in / Create account | Calls the FastAPI auth endpoint; failures show the server message |
| Auth | Language | Switches EN/AR and applies layout direction |
| Home | Application tiles | Open the corresponding sheet, each backed by a real endpoint |
| Home | Dock | Same modules as the full grid |
| Home | Status strip | Opens `ConnectionStatusView`; values come from the last real `/api/health` response |
| Home | Control Center | Opens control center sheet |
| Connection | Test connection | Re-calls `/api/health`, updates timestamp, state and error |
| Assistant | Send / voice / new chat / history / project menu | Real `/api/chats`, `/api/assistant/ask` calls; Gemini failures surface as errors |
| Files | Create / edit / rename / delete | CRUD against `/api/files`; delete now asks for confirmation |
| Projects | Create / open / delete / open assistant | CRUD against `/api/projects`; detail lists real project files and chats |
| Studio | Filter / create / explain / fix | Real project-scoped calls; no code execution |
| Security | Refresh / revoke session / logout | `/api/security/status`, session revoke and sign-out |
| Store | Refresh / tool detail | `/api/tools`; tools marked unavailable when the backend says so |
| Settings | Language / appearance / sound / edit account / save | Persisted through `/api/account/settings`; no local-only illusion |
| Control Center | Refresh / language / appearance / logout | Same state as Settings; logout clears the Keychain token |

## State honesty

`ServerConnectionState` is derived only from a completed health request:

- `notConfigured` — no valid URL
- `checking` — request in flight
- `reachable` — real response with `status == "ok"`
- `degraded` — real response with another status
- `offline` — request failed

"Online" is impossible without a successful server call.

## Automated checks

- `NexusAIUITests/ScreenshotTests` launches the app, enters the server URL, registers a real user against the backend started in CI, opens all seven modules, opens the connection screen, switches to Arabic and back to English, and captures screenshots.
- The workflow `.github/workflows/ios-screenshots.yml` runs on a macOS runner with a real simulator and uploads the screenshots as an artifact.
- Backend suite: 42 passed, 1 skipped (the Gemini test needs a key).

## Captured screenshots

Real screenshots from `xcodebuild test` on an iPhone 16 simulator against a running backend
(GitHub Actions run `43602929211`, workflow `ios-screenshots.yml`):

| File | Screen |
| --- | --- |
| `screenshots/01-auth.png` | Login / server setup |
| `screenshots/02-home.png` | Home with modules and status strip |
| `screenshots/03-server-status.png` | Connection status sheet |
| `screenshots/04-assistant.png` | NEXUS Assistant |
| `screenshots/04-files.png` | Smart Files |
| `screenshots/04-projects.png` | Projects |
| `screenshots/04-studio.png` | Developer Studio |
| `screenshots/04-security.png` | Security Center |
| `screenshots/04-store.png` | NEXUS Store |
| `screenshots/04-settings.png` | Settings (English) |
| `screenshots/05-settings-arabic.png` | Settings after switching to Arabic (RTL) |

## Limits

- Assistant replies require `GEMINI_API_KEY`; without it the UI shows a real error.
- Instrumented UI tests run only in CI (no local Swift toolchain).
- Screenshots represent the app against the CI backend with SQLite; production uses Railway + PostgreSQL after deployment.
