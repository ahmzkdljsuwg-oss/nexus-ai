import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var selected: NexusModule?
    @State private var showControlCenter = false
    @State private var security: SecurityStatus?
    @State private var loadError: String?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let dock: [NexusModule] = [.assistant, .files, .projects, .settings]

    var body: some View {
        ZStack(alignment: .bottom) {
            NexusBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    topBar
                    hero
                    systemStrip
                    applications
                    Color.clear.frame(height: 112)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            dockBar
        }
        .task { await loadDashboard() }
        .sheet(item: $selected) { module in
            ModuleHost(module: module)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showControlCenter) {
            ControlCenterView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(NexusTheme.emerald.opacity(0.14))
                    .frame(width: 42, height: 42)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(NexusTheme.emerald.opacity(0.4), lineWidth: 1))
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(NexusTheme.emerald)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(app.text("app.name"))
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .tracking(2)
                    .foregroundStyle(NexusTheme.text)
                Text(app.text("app.subtitle"))
                    .font(.system(size: 7.5, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(NexusTheme.muted)
            }
            Spacer()
            Button {
                showControlCenter = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NexusTheme.text)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.06), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(app.text("control"))
            Button {
                selected = .settings
            } label: {
                Text(initials)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.ink)
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: [NexusTheme.gold, NexusTheme.emerald], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(app.text("common.account"))
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(app.text("home.welcome")), \(app.user?.name.components(separatedBy: " ").first ?? "")")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(NexusTheme.muted)
                    Text("NEXUS")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(
                            LinearGradient(colors: [NexusTheme.text, NexusTheme.emerald.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        )
                    Text(app.text("home.pulse"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle().fill(NexusTheme.glow()).frame(width: 128, height: 128)
                    Circle()
                        .stroke(NexusTheme.emerald.opacity(0.30), lineWidth: 1)
                        .frame(width: 84, height: 84)
                    Circle()
                        .stroke(NexusTheme.gold.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                        .frame(width: 108, height: 108)
                    Image(systemName: "atom")
                        .font(.system(size: 38, weight: .ultraLight))
                        .foregroundStyle(NexusTheme.emerald)
                }
                .frame(width: 120, height: 120)
            }
        }
        .padding(20)
        .glassPanel(app.appearance)
    }

    private var systemStrip: some View {
        HStack(spacing: 10) {
            statusTile(
                icon: "antenna.radiowaves.left.and.right",
                label: app.health == nil ? app.text("home.offline") : app.text("home.online"),
                detail: app.health.map { "\($0.service) \($0.version)" } ?? app.text("server.notConfigured"),
                active: app.health != nil
            )
            statusTile(
                icon: "cylinder.split.1x2",
                label: app.text("settings.database"),
                detail: databaseDetail,
                active: app.health?.database == "ok"
            )
            statusTile(
                icon: "brain",
                label: "Gemini",
                detail: app.health?.geminiConfigured == true ? app.health?.geminiModel ?? "" : app.text("common.unavailable"),
                active: app.health?.geminiConfigured == true
            )
        }
    }

    private func statusTile(icon: String, label: String, detail: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? NexusTheme.emerald : NexusTheme.gold)
                Circle()
                    .fill(active ? NexusTheme.emerald : NexusTheme.gold)
                    .frame(width: 5, height: 5)
            }
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(NexusTheme.text)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(NexusTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var applications: some View {
        VStack(spacing: 12) {
            SectionTitle(text: app.text("home.apps"), trailing: security.map { "\($0.projects) P · \($0.files) F · \($0.chats) C" })
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(NexusModule.allCases) { module in
                    Button {
                        selected = module
                    } label: {
                        appTile(module)
                    }
                    .buttonStyle(AppTileButtonStyle())
                }
            }
            if let loadError {
                InlineError(message: loadError) {
                    Task { await loadDashboard() }
                }
            }
        }
    }

    private func appTile(_ module: NexusModule) -> some View {
        HStack(spacing: 12) {
            AppGlyph(symbol: module.symbol, accent: module.accent, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.text(module.titleKey))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(NexusTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(tileSubtitle(module))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(colors: [module.accent.opacity(0.28), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }

    private var dockBar: some View {
        HStack(spacing: 8) {
            ForEach(dock) { module in
                Button {
                    selected = module
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: module.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(module.accent)
                        Text(app.text(module.titleKey))
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(NexusTheme.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var initials: String {
        let source = app.user?.name.isEmpty == false ? app.user?.name : app.user?.email
        let parts = (source ?? "N").split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var databaseDetail: String {
        guard let health = app.health else { return app.text("server.notConfigured") }
        return health.database == "ok" ? app.text("server.databaseOk") : app.text("server.databaseDown")
    }

    private func tileSubtitle(_ module: NexusModule) -> String {
        switch module {
        case .assistant: return "Gemini · projects · files"
        case .files: return app.text("files.subtitle")
        case .projects: return app.text("projects.subtitle")
        case .studio: return app.text("studio.subtitle")
        case .security: return app.text("security.subtitle")
        case .store: return app.text("store.subtitle")
        case .settings: return app.text("settings.subtitle")
        }
    }

    private func loadDashboard() async {
        guard let client = app.apiClient else { return }
        do {
            async let health = client.health()
            async let status = client.securityStatus()
            app.health = try await health
            security = try await status
            loadError = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { loadError = app.friendly(error) }
        } catch {
            loadError = app.friendly(error)
        }
    }
}

private struct AppTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
