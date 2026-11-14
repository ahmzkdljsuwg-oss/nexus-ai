import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAccount = false
    @State private var showSecurity = false
    @State private var showConnection = false
    @State private var confirmLogout = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileCard
                preferencesCard
                serverCard
                securityRow
                aboutCard
                logoutButton
            }
            .padding(16)
        }
        .task { await app.refreshHealth() }
        .sheet(isPresented: $showAccount) {
            AccountEditorView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showConnection) {
            ConnectionStatusView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSecurity) {
            NexusWindowChrome(
                title: app.text("security"),
                symbol: NexusModule.security.symbol,
                accent: NexusModule.security.accent
            ) {
                SecurityView()
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(app.text("common.logout"), isPresented: $confirmLogout, titleVisibility: .visible) {
            Button(app.text("common.logout"), role: .destructive) {
                Task {
                    await app.signOut()
                    dismiss()
                }
            }
            Button(app.text("common.cancel"), role: .cancel) {}
        }
    }

    private var profileCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(NexusTheme.gold.opacity(0.12)).frame(width: 50, height: 50)
                Text(initials)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.user?.name ?? "NEXUS")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.text)
                Text(app.user?.email ?? "")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(NexusTheme.muted)
            }
            Spacer()
            Button {
                showAccount = true
            } label: {
                Text(app.text("common.edit"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(NexusTheme.emerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(NexusTheme.emerald.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .glassPanel(app.appearance)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            row(icon: "globe", title: app.text("common.language")) {
                Button(app.locale == .english ? "العربية" : "English") {
                    Task { await app.switchLanguage() }
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(NexusTheme.emerald)
                .buttonStyle(.plain)
            }
            divider
            row(icon: "moon.stars", title: app.text("common.appearance")) {
                Picker("", selection: Binding(
                    get: { app.appearance },
                    set: { value in Task { await app.setAppearance(value) } }
                )) {
                    Text(app.text("common.dark")).tag("dark")
                    Text(app.text("common.midnight")).tag("midnight")
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            divider
            row(icon: "speaker.wave.2", title: app.text("common.sound")) {
                Toggle("", isOn: Binding(
                    get: { app.user?.soundEnabled ?? true },
                    set: { value in Task { await app.updateSettings(soundEnabled: value) } }
                ))
                .labelsHidden()
                .tint(NexusTheme.emerald)
            }
            divider
            row(icon: "mic", title: app.text("common.voice")) {
                Toggle("", isOn: Binding(
                    get: { app.user?.assistantVoice ?? true },
                    set: { value in Task { await app.updateSettings(voiceEnabled: value) } }
                ))
                .labelsHidden()
                .tint(NexusTheme.emerald)
            }
        }
        .padding(15)
        .glassPanel(app.appearance)
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: app.text("settings.serverInfo"))
                Button {
                    showConnection = true
                } label: {
                    HStack(spacing: 4) {
                        Text(app.text("connection.title"))
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(NexusTheme.emerald)
                }
                .buttonStyle(.plain)
            }
            infoRow(app.text("connection.endpoint"), app.baseURLString.isEmpty ? app.text("server.notConfigured") : app.baseURLString)
            infoRow(app.text("common.status"), connectionLabel)
            infoRow(app.text("settings.database"), app.health?.database ?? "—")
            infoRow(app.text("settings.gemini"), app.health?.geminiConfigured == true ? app.health?.geminiModel ?? "—" : app.text("common.unavailable"))
            if let message = app.statusMessage {
                Text(message)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(NexusTheme.gold)
            }
            NexusGhostButton(title: app.text("connection.refresh"), icon: "arrow.clockwise") {
                Task { await app.refreshHealth() }
            }
        }
        .padding(15)
        .glassPanel(app.appearance)
    }

    private var securityRow: some View {
        Button {
            showSecurity = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(NexusTheme.emerald)
                Text(app.text("security"))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(NexusTheme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NexusTheme.muted)
            }
            .padding(15)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: app.text("settings.about"))
            infoRow(app.text("settings.version"), appVersion)
            infoRow("API", app.health.map { "v\($0.version)" } ?? "—")
            Text(app.text("home.pulse"))
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(NexusTheme.muted)
        }
        .padding(15)
        .glassPanel(app.appearance)
    }

    private var logoutButton: some View {
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
            .padding(13)
            .background(NexusTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().overlay(.white.opacity(0.07))
    }

    private var connectionLabel: String {
        switch app.connectionState {
        case .notConfigured: return app.text("server.notConfigured")
        case .checking: return app.text("common.loading")
        case .reachable: return app.text("health.ok")
        case .degraded: return app.text("health.degraded")
        case .offline: return app.text("home.offline")
        }
    }

    private var initials: String {
        let name = app.user?.name ?? "N"
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func row<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NexusTheme.muted)
                .frame(width: 18)
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(NexusTheme.text)
            Spacer()
            content()
        }
        .padding(.vertical, 10)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(NexusTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(NexusTheme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct AccountEditorView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var password = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var saved = false

    var body: some View {
        ZStack {
            NexusBackground()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(app.text("common.account"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(NexusTheme.text)
                    Spacer()
                    Button(app.text("common.close")) { dismiss() }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.emerald)
                }
                Text(app.user?.email ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(NexusTheme.muted)

                Text(app.text("common.name"))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.muted)
                TextField(app.text("common.name"), text: $name)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(NexusTheme.text)
                    .padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(app.text("auth.password"))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.muted)
                SecureField(app.text("auth.password"), text: $password)
                    .textContentType(.newPassword)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(NexusTheme.text)
                    .padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(app.text("common.formHint"))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)

                if let errorMessage {
                    InlineError(message: errorMessage) { self.errorMessage = nil }
                }
                if saved {
                    Text(app.text("common.save"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.emerald)
                }

                NexusPrimaryButton(title: app.text("common.save"), icon: "tray.and.arrow.down", loading: saving) {
                    Task { await save() }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.isEmpty)
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .onAppear { name = app.user?.name ?? "" }
    }

    private func save() async {
        guard let client = app.apiClient else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            _ = try await client.updateAccount(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password.isEmpty ? nil : password
            )
            await app.refreshAccount()
            password = ""
            saved = true
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}
