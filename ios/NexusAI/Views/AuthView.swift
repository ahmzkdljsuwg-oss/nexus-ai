import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var app: AppState
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var serverText = ""
    @State private var serverBusy = false
    @FocusState private var focus: Field?

    private enum Mode: Hashable { case login, register }
    private enum Field: Hashable { case email, name, password, server }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                serverCard
                formCard
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 54)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { serverText = app.baseURLString }
        .onChange(of: serverText) { value in
            if value != app.baseURLString { app.authError = nil }
        }
        .onChange(of: email) { _ in app.authError = nil }
        .onChange(of: password) { _ in app.authError = nil }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(NexusTheme.glow())
                    .frame(width: 168, height: 168)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [NexusTheme.emerald.opacity(0.92), NexusTheme.emeraldDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 78, height: 78)
                    .overlay(
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(NexusTheme.ink)
                    )
                    .shadow(color: NexusTheme.emerald.opacity(0.5), radius: 24, y: 8)
            }
            .frame(height: 118)

            Text(app.text("app.name"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(NexusTheme.text)
            Text(app.text("app.subtitle"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(3.4)
                .foregroundStyle(NexusTheme.gold)
            Text(app.text("auth.line"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(NexusTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: app.text("common.server"), trailing: app.isServerConfigured ? app.text("server.configured") : app.text("server.notConfigured"))
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(NexusTheme.emerald)
                TextField(app.text("auth.serverHint"), text: $serverText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($focus, equals: .server)
                    .foregroundStyle(NexusTheme.text)
                    .font(.system(.subheadline, design: .monospaced))
                    .accessibilityIdentifier("auth.server")
            }
            .padding(14)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))

            HStack {
                if serverBusy {
                    ProgressView().tint(NexusTheme.emerald)
                } else if app.connectionState == .reachable {
                    StatusPill(label: app.text("health.ok"), active: true)
                } else if app.connectionState == .degraded {
                    StatusPill(label: app.text("health.degraded"), active: false)
                } else if app.connectionState == .offline, app.isServerConfigured {
                    StatusPill(label: app.text("home.offline"), active: false)
                }
                Spacer()
                NexusGhostButton(title: app.text("auth.saveServer"), icon: "arrow.triangle.2.circlepath") {
                    Task {
                        serverBusy = true
                        await app.configureServer(serverText)
                        serverBusy = false
                    }
                }
                .disabled(serverBusy || serverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let message = app.statusMessage {
                Text(message)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(NexusTheme.gold)
            }
        }
        .padding(18)
        .glassPanel(app.appearance)
    }

    private var formCard: some View {
        VStack(spacing: 16) {
            Picker("", selection: $mode) {
                Text(app.text("auth.login")).tag(Mode.login)
                Text(app.text("auth.register")).tag(Mode.register)
            }
            .pickerStyle(.segmented)

            if mode == .register {
                field(icon: "person", placeholder: app.text("auth.name"), text: $name, focusValue: .name)
                    .textContentType(.name)
                    .accessibilityIdentifier("auth.name")
            }
            field(icon: "envelope", placeholder: app.text("auth.email"), text: $email, focusValue: .email)
                .textContentType(.emailAddress)
                .accessibilityIdentifier("auth.email")
                .keyboardType(.emailAddress)
            secureField

            if let error = app.authError {
                Text(error)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(NexusTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            NexusPrimaryButton(
                title: mode == .login ? app.text("auth.login") : app.text("auth.register"),
                icon: mode == .login ? "arrow.right" : "sparkles",
                loading: app.isBusy
            ) {
                focus = nil
                Task {
                    if mode == .login {
                        await app.signIn(email: email, password: password)
                    } else {
                        await app.register(email: email, name: name, password: password)
                    }
                }
            }
            .disabled(!app.isServerConfigured)
            .accessibilityIdentifier("auth.submit")

            Button {
                mode = mode == .login ? .register : .login
                app.authError = nil
            } label: {
                Text(mode == .login ? app.text("auth.toRegister") : app.text("auth.toLogin"))
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(NexusTheme.emerald)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassPanel(app.appearance)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, focusValue: Field) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(NexusTheme.muted).frame(width: 18)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: focusValue)
                .foregroundStyle(NexusTheme.text)
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var secureField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock").foregroundStyle(NexusTheme.muted).frame(width: 18)
            SecureField(app.text("auth.password"), text: $password)
                .textContentType(mode == .login ? .password : .newPassword)
                .focused($focus, equals: .password)
                .foregroundStyle(NexusTheme.text)
                .accessibilityIdentifier("auth.password")
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var footer: some View {
        Button(app.text("settings.toggleLanguage")) {
            Task { await app.switchLanguage() }
        }
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(NexusTheme.emerald)
        .padding(.top, 4)
    }
}
