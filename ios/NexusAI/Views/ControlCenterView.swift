import SwiftUI

struct ControlCenterView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    connectionCard
                    preferencesCard
                    accountCard
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .confirmationDialog(app.text("common.logout"), isPresented: $confirmLogout, titleVisibility: .visible) {
            Button(app.text("common.logout"), role: .destructive) {
                Task { await app.signOut(); dismiss() }
            }
            Button(app.text("common.cancel"), role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(app.text("control"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.text)
                Text(app.text("app.subtitle"))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(NexusTheme.gold)
            }
            Spacer()
            Button {
                Task { await app.refreshHealth(); await app.refreshAccount() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(NexusTheme.emerald)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: app.text("home.status"))
            HStack {
                StatusPill(label: app.health == nil ? app.text("home.offline") : app.text("home.online"), active: app.health != nil)
                Spacer()
                if let health = app.health {
                    Text("\(health.service) · v\(health.version)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(NexusTheme.muted)
                }
            }
            if let health = app.health {
                HStack(spacing: 8) {
                    miniPill(icon: "cylinder.split.1x2", text: health.database == "ok" ? app.text("server.databaseOk") : app.text("server.databaseDown"), active: health.database == "ok")
                    miniPill(icon: "brain", text: health.geminiConfigured ? health.geminiModel : app.text("common.unavailable"), active: health.geminiConfigured)
                }
            }
            if let message = app.statusMessage {
                Text(message)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(NexusTheme.gold)
            }
        }
        .padding(16)
        .glassPanel(app.appearance)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            SectionTitle(text: app.text("settings.subtitle"))
                .padding(.bottom, 12)

            HStack {
                label(icon: "globe", text: app.text("common.language"))
                Spacer()
                Button(app.locale == .english ? "العربية" : "English") {
                    Task { await app.switchLanguage() }
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(NexusTheme.emerald)
                .buttonStyle(.plain)
            }
            .padding(.vertical, 11)

            Divider().overlay(.white.opacity(0.08))

            HStack {
                label(icon: "moon.stars", text: app.text("common.appearance"))
                Spacer()
                Picker("", selection: Binding(
                    get: { app.appearance },
                    set: { value in Task { await app.setAppearance(value) } }
                )) {
                    Text(app.text("common.dark")).tag("dark")
                    Text(app.text("common.midnight")).tag("midnight")
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            .padding(.vertical, 11)

            Divider().overlay(.white.opacity(0.08))

            HStack {
                label(icon: "speaker.wave.2", text: app.text("common.sound"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { app.user?.soundEnabled ?? true },
                    set: { value in Task { await app.updateSettings(soundEnabled: value) } }
                ))
                .labelsHidden()
                .tint(NexusTheme.emerald)
            }
            .padding(.vertical, 11)

            Divider().overlay(.white.opacity(0.08))

            HStack {
                label(icon: "mic", text: app.text("common.voice"))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { app.user?.assistantVoice ?? true },
                    set: { value in Task { await app.updateSettings(voiceEnabled: value) } }
                ))
                .labelsHidden()
                .tint(NexusTheme.emerald)
            }
            .padding(.vertical, 11)
        }
        .padding(16)
        .glassPanel(app.appearance)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: app.text("common.account"))
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(NexusTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.user?.name.isEmpty == false ? app.user?.name ?? "" : "NEXUS")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.text)
                    Text(app.user?.email ?? "")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(NexusTheme.muted)
                }
                Spacer()
            }
            Button {
                confirmLogout = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(app.text("common.logout"))
                    Spacer()
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(NexusTheme.danger)
                .padding(12)
                .background(NexusTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassPanel(app.appearance)
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NexusTheme.muted)
                .frame(width: 18)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(NexusTheme.text)
        }
    }

    private func miniPill(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            Text(text).font(.system(size: 9.5, weight: .medium, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(active ? NexusTheme.emerald : NexusTheme.gold)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.white.opacity(0.05), in: Capsule())
    }
}
