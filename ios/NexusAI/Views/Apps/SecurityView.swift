import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var app: AppState
    @State private var status: SecurityStatus?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                shieldCard

                if let errorMessage {
                    InlineError(message: errorMessage) { Task { await load() } }
                }

                if let status {
                    SectionTitle(text: app.text("security.checks"))
                    VStack(spacing: 8) {
                        ForEach(status.checks) { check in
                            checkRow(check)
                        }
                    }

                    let health = app.health
                    let online = health?.status == "ok"
                    HStack(spacing: 9) {
                        metric(online ? app.text("home.online") : app.text("home.offline"), app.text("common.status"))
                        metric(health?.database == "ok" ? app.text("health.ok") : app.text("common.unavailable"), app.text("settings.database"))
                        metric(health?.geminiConfigured == true ? app.text("health.ok") : app.text("common.unavailable"), "Gemini")
                    }
                }

                Button {
                    Task { await load() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(app.text("connection.refresh"))
                        Spacer()
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.emerald)
                    .padding(12)
                    .background(NexusTheme.emerald.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(16)
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var shieldCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NexusTheme.emerald.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: app.health?.status == "ok" ? "lock.shield.fill" : "lock.shield")
                    .font(.system(size: 24))
                    .foregroundStyle(app.health?.status == "ok" ? NexusTheme.emerald : NexusTheme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(app.health?.status == "ok" ? app.text("security.subtitle") : app.text("home.connect"))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.text)
                HStack(spacing: 6) {
                    Circle()
                        .fill(app.health?.status == "ok" ? NexusTheme.emerald : NexusTheme.danger)
                        .frame(width: 6, height: 6)
                    Text(app.health?.status == "ok" ? app.text("home.online") : app.text("home.offline"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                    if let health = app.health {
                        Text("· \(health.geminiConfigured ? health.geminiModel : app.text("common.unavailable"))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(NexusTheme.muted)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if loading { ProgressView().tint(NexusTheme.emerald) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(app.appearance)
    }

    private func checkRow(_ check: SecurityCheck) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol(for: check.state))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color(for: check.state))
                .frame(width: 20)
            Text(check.label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(NexusTheme.text)
            Spacer()
            Text(check.state.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color(for: check.state))
        }
        .padding(11)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(NexusTheme.text)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 8.5, design: .rounded))
                .foregroundStyle(NexusTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func color(for state: String) -> Color {
        switch state.lowercased() {
        case "ok", "secure", "active", "valid": return NexusTheme.emerald
        case "warn", "warning", "degraded": return NexusTheme.gold
        default: return NexusTheme.danger
        }
    }

    private func symbol(for state: String) -> String {
        switch state.lowercased() {
        case "ok", "secure", "active", "valid": return "checkmark.shield.fill"
        case "warn", "warning", "degraded": return "exclamationmark.shield.fill"
        default: return "xmark.shield.fill"
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        await app.refreshHealth()
        guard let client = app.apiClient else {
            errorMessage = app.text("common.requiredServer")
            return
        }
        do {
            status = try await client.securityStatus()
            errorMessage = nil
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}
