import SwiftUI

struct ConnectionStatusView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    statusCard
                    detailsCard
                    NexusPrimaryButton(
                        title: app.text("connection.refresh"),
                        icon: "arrow.clockwise",
                        loading: app.healthBusy
                    ) {
                        Task { await app.refreshHealth() }
                    }
                }
                .padding(18)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .task { await app.refreshHealth() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(app.text("connection.title"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.text)
                Text(app.text("connection.subtitle"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
            }
            Spacer()
            Button(app.text("common.close")) { dismiss() }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(NexusTheme.emerald)
                .buttonStyle(.plain)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(NexusTheme.text)
                    Text(app.text("connection.checkedAt") + ": " + checkedText)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(NexusTheme.muted)
                }
                Spacer()
                if app.healthBusy {
                    ProgressView().tint(NexusTheme.emerald)
                } else {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                        .shadow(color: tint.opacity(0.7), radius: 5)
                }
            }
            if let health = app.health {
                HStack(spacing: 8) {
                    StatusPill(label: health.service, active: health.status == "ok")
                    StatusPill(label: "v\(health.version)", active: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(app.appearance)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: app.text("connection.state"))
            detail(app.text("connection.endpoint"), app.baseURLString.isEmpty ? app.text("server.notConfigured") : app.baseURLString)
            if let health = app.health {
                detail(app.text("connection.service"), health.service)
                detail(app.text("connection.version"), health.version)
                detail(app.text("connection.database"), health.database == "ok" ? app.text("server.databaseOk") : app.text("server.databaseDown"))
                detail(app.text("connection.gemini"), health.geminiConfigured ? health.geminiModel : app.text("common.unavailable"))
                detail(app.text("common.lastUpdate"), health.time)
            }
            if let error = app.healthError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("connection.error").uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(NexusTheme.danger)
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(NexusTheme.text)
                        .textSelection(.enabled)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .glassPanel(app.appearance)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(NexusTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(NexusTheme.text)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }

    private var label: String {
        switch app.connectionState {
        case .notConfigured: return app.text("server.notConfigured")
        case .checking: return app.text("common.loading")
        case .reachable: return app.text("health.ok")
        case .degraded: return app.text("health.degraded")
        case .offline: return app.text("home.offline")
        }
    }

    private var symbol: String {
        switch app.connectionState {
        case .notConfigured: return "link.badge.plus"
        case .checking: return "arrow.triangle.2.circlepath"
        case .reachable: return "checkmark.seal.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        }
    }

    private var tint: Color {
        switch app.connectionState {
        case .reachable: return NexusTheme.emerald
        case .degraded, .checking, .notConfigured: return NexusTheme.gold
        case .offline: return NexusTheme.danger
        }
    }

    private var checkedText: String {
        guard let date = app.healthCheckedAt else { return app.text("connection.never") }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
