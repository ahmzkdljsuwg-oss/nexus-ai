import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var token: String?
    @Published private(set) var user: NexusUser?
    @Published var baseURLString: String
    @Published var health: NexusHealth?
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
              scheme == "https" || scheme == "http",
              url.host != nil else { return nil }
        return url
    }

    var apiClient: APIClient? {
        guard let serverURL else { return nil }
        return APIClient(baseURL: serverURL, token: token)
    }

    var isAuthenticated: Bool { token != nil }

    func configureServer(_ raw: String) async {
        baseURLString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = serverURL else {
            statusMessage = "The server URL must start with https:// and include a host."
            return
        }
        UserDefaults.standard.set(url.absoluteString, forKey: baseKey)
        baseURLString = url.absoluteString
        await refreshHealth()
    }

    func refreshHealth() async {
        guard let client = apiClient else {
            health = nil
            return
        }
        do {
            health = try await client.health()
            statusMessage = nil
        } catch {
            health = nil
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
