import Foundation
import SwiftUI

enum ServerConnectionState: Equatable {
    case notConfigured
    case checking
    case reachable
    case degraded
    case offline
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: NexusUser?
    @Published var baseURLString: String
    @Published var health: NexusHealth?
    @Published private(set) var healthBusy = false
    @Published private(set) var healthCheckedAt: Date?
    @Published private(set) var healthError: String?
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var authError: String?
    @Published var locale: AppLanguage
    @Published var appearance: String

    private let tokenAccount = "access-token"
    private let baseKey = "nexus.base-url"
    private let localeKey = "nexus.locale"
    private let appearanceKey = "nexus.appearance"

    init() {
        token = Keychain.read(account: tokenAccount)
        baseURLString = UserDefaults.standard.string(forKey: baseKey) ?? ""
        let storedLocale = UserDefaults.standard.string(forKey: localeKey) ?? "en"
        locale = AppLanguage(rawValue: storedLocale) ?? .english
        appearance = UserDefaults.standard.string(forKey: appearanceKey) ?? "dark"
    }

    var strings: Strings { Strings(language: locale) }
    func text(_ key: String) -> String { strings.text(key) }

    var isServerConfigured: Bool { serverURL != nil }

    var serverURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              url.query == nil,
              url.fragment == nil else { return nil }
        if scheme == "https" { return url }
        if scheme == "http", host == "localhost" || host == "127.0.0.1" { return url }
        return nil
    }

    var apiClient: APIClient? {
        guard let serverURL else { return nil }
        return APIClient(baseURL: serverURL, token: token)
    }

    var isAuthenticated: Bool { token != nil }

    var connectionState: ServerConnectionState {
        guard serverURL != nil else { return .notConfigured }
        if healthBusy { return .checking }
        guard let health else { return .offline }
        return health.status == "ok" ? .reachable : .degraded
    }

    func configureServer(_ raw: String) async {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        baseURLString = cleaned
        guard let url = serverURL else {
            UserDefaults.standard.removeObject(forKey: baseKey)
            health = nil
            healthCheckedAt = nil
            healthError = text("auth.invalidServer")
            statusMessage = text("auth.invalidServer")
            return
        }
        UserDefaults.standard.set(url.absoluteString, forKey: baseKey)
        baseURLString = url.absoluteString
        authError = nil
        await refreshHealth()
    }

    func refreshHealth() async {
        guard let client = apiClient else {
            health = nil
            healthCheckedAt = nil
            healthError = text("common.requiredServer")
            statusMessage = nil
            return
        }
        healthBusy = true
        defer {
            healthBusy = false
            healthCheckedAt = Date()
        }
        do {
            health = try await client.health()
            healthError = nil
            statusMessage = nil
        } catch {
            health = nil
            healthError = friendly(error)
            statusMessage = friendly(error)
        }
    }

    func signIn(email: String, password: String) async {
        guard let client = apiClient else {
            authError = text("common.requiredServer")
            return
        }
        isBusy = true
        authError = nil
        defer { isBusy = false }
        do {
            let result = try await client.login(email: email, password: password)
            apply(token: result.accessToken, user: result.user)
        } catch {
            authError = friendly(error)
        }
    }

    func register(email: String, name: String, password: String) async {
        guard let client = apiClient else {
            authError = text("common.requiredServer")
            return
        }
        isBusy = true
        authError = nil
        defer { isBusy = false }
        do {
            let result = try await client.register(email: email, name: name, password: password)
            apply(token: result.accessToken, user: result.user)
        } catch {
            authError = friendly(error)
        }
    }

    func restoreSession() async {
        guard let client = apiClient else { return }
        do {
            let account = try await client.account()
            user = account
            adopt(account)
        } catch let error as APIError {
            if error.isUnauthorized { clearSession() }
        } catch {
            statusMessage = friendly(error)
        }
    }

    func refreshAccount() async {
        guard let client = apiClient else { return }
        do {
            let account = try await client.account()
            user = account
            adopt(account)
        } catch let error as APIError {
            if error.isUnauthorized { clearSession() }
            else { statusMessage = friendly(error) }
        } catch {
            statusMessage = friendly(error)
        }
    }

    func updateSettings(
        locale newLocale: AppLanguage? = nil,
        appearance newAppearance: String? = nil,
        soundEnabled: Bool? = nil,
        voiceEnabled: Bool? = nil
    ) async {
        guard let client = apiClient else { return }
        let chosenLocale = newLocale ?? locale
        let chosenAppearance = newAppearance ?? appearance
        do {
            let account = try await client.updateSettings(
                locale: chosenLocale.rawValue,
                appearance: chosenAppearance,
                soundEnabled: soundEnabled,
                voiceEnabled: voiceEnabled
            )
            user = account
            adopt(account)
        } catch let error as APIError {
            if error.isUnauthorized { clearSession() }
            else { statusMessage = friendly(error) }
        } catch {
            statusMessage = friendly(error)
        }
    }

    func switchLanguage() async {
        let next: AppLanguage = locale == .english ? .arabic : .english
        locale = next
        UserDefaults.standard.set(next.rawValue, forKey: localeKey)
        await updateSettings(locale: next)
    }

    func setAppearance(_ value: String) async {
        appearance = value
        UserDefaults.standard.set(value, forKey: appearanceKey)
        await updateSettings(appearance: value)
    }

    func signOut() async {
        if let client = apiClient {
            try? await client.logout()
        }
        clearSession()
    }

    func handleUnauthorized() {
        clearSession()
        authError = text("common.sessionExpired")
    }

    func friendly(_ error: Error) -> String {
        if let api = error as? APIError {
            if api.isUnauthorized { return text("common.sessionExpired") }
            return api.errorDescription ?? text("common.error")
        }
        return error.localizedDescription
    }

    private func apply(token newToken: String, user newUser: NexusUser) {
        token = newToken
        Keychain.save(newToken, account: tokenAccount)
        user = newUser
        adopt(newUser)
        Task { await refreshHealth() }
    }

    private func adopt(_ account: NexusUser) {
        if let language = AppLanguage(rawValue: account.locale) {
            locale = language
            UserDefaults.standard.set(language.rawValue, forKey: localeKey)
        }
        appearance = account.appearance
        UserDefaults.standard.set(account.appearance, forKey: appearanceKey)
    }

    private func clearSession() {
        token = nil
        user = nil
        Keychain.delete(account: tokenAccount)
    }
}
