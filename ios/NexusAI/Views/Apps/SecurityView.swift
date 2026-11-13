import SwiftUI

struct SecurityView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var status: SecurityStatus?
    @State private var sessions: [NexusSession] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var confirmLogout = false

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

                    HStack(spacing: 9) {
                        metric("\(status.projects)", app.text("projects"))
                        metric("\(status.files)", app.text("files"))
                        metric("\(status.chats)", app.text("chats"))
                    }
                }

                HStack {
                    SectionTitle(text: app.text("security.sessions"))
                    Spacer()
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }
                    .buttonStyle(.plain)
                }

                if sessions.isEmpty {
                    Text(app.text("security.noSessions"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                } else {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
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
                .padding(.top, 6)
            }
            .padding(16)
        }
        .task { await load() }
        .refreshable { await load() }
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

    private var shieldCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NexusTheme.emerald.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: status?.authenticated == true ? "lock.shield.fill" : "lock.shield")
                    .font(.system(size: 24))
                    .foregroundStyle(status?.authenticated == true ? NexusTheme.emerald : NexusTheme.gold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(status?.authenticated == true ? app.text("security.subtitle") : app.text("home.connect"))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.text)
                HStack(spacing: 6) {
                    Circle()
                        .fill(app.health == nil ? NexusTheme.danger : NexusTheme.emerald)
                        .frame(width: 6, height: 6)
                    Text(app.health == nil ? app.text("home.offline") : app.text("home.online"))
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

    private func sessionRow(_ session: NexusSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: session.current ? "iphone" : "desktopcomputer")
                .foregroundStyle(session.current ? NexusTheme.emerald : NexusTheme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.current ? app.text("security.current") : session.device)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.text)
                Text(session.lastSeenAt)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(NexusTheme.muted)
                    .lineLimit(1)
            }
            Spacer()
            if !session.current {
                Button(app.text("security.revoke")) {
                    Task { await revoke(session) }
                }
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(NexusTheme.danger)
                .buttonStyle(.plain)
            }
        }
        .padding(11)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(NexusTheme.text)
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
        guard let client = app.apiClient else { return }
        do {
            async let statusTask = client.securityStatus()
            async let sessionsTask = client.sessions()
            status = try await statusTask
            sessions = try await sessionsTask
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func revoke(_ session: NexusSession) async {
        guard let client = app.apiClient else { return }
        do {
            try await client.revokeSession(id: session.id)
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}
