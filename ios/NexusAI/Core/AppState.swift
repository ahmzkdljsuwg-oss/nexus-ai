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
    @Published var baseURLString: String
    @Published var health: NexusHealth?
    @Published private(set) var healthBusy = false
    @Published private(set) var healthCheckedAt: Date?
    @Published private(set) var healthError: String?
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var locale: AppLanguage
    @Published var appearance: String
    @Published var soundEnabled: Bool
    @Published var assistantVoice: Bool

    private let baseKey = "nexus.base-url"
    private let localeKey = "nexus.locale"
    private let appearanceKey = "nexus.appearance"
    private let soundKey = "nexus.sound"
    private let voiceKey = "nexus.voice"

    init() {
        let saved = UserDefaults.standard.string(forKey: baseKey) ?? ""
        let bundled = ProcessInfo.processInfo.environment["NEXUS_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "NEXUS_API_BASE_URL") as? String
            ?? ""
        baseURLString = saved.isEmpty ? bundled : saved
        let storedLocale = UserDefaults.standard.string(forKey: localeKey) ?? "en"
        locale = AppLanguage(rawValue: storedLocale) ?? .english
        appearance = UserDefaults.standard.string(forKey: appearanceKey) ?? "dark"
        soundEnabled = UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
        assistantVoice = UserDefaults.standard.object(forKey: voiceKey) as? Bool ?? true
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
        return APIClient(baseURL: serverURL)
    }

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

    func updateSettings(
        locale newLocale: AppLanguage? = nil,
        appearance newAppearance: String? = nil,
        soundEnabled newSound: Bool? = nil,
        voiceEnabled newVoice: Bool? = nil
    ) async {
        if let newLocale { locale = newLocale; UserDefaults.standard.set(newLocale.rawValue, forKey: localeKey) }
        if let newAppearance { appearance = newAppearance; UserDefaults.standard.set(newAppearance, forKey: appearanceKey) }
        if let newSound { soundEnabled = newSound; UserDefaults.standard.set(newSound, forKey: soundKey) }
        if let newVoice { assistantVoice = newVoice; UserDefaults.standard.set(newVoice, forKey: voiceKey) }
    }

    func switchLanguage() async {
        let next: AppLanguage = locale == .english ? .arabic : .english
        await updateSettings(locale: next)
    }

    func setAppearance(_ value: String) async {
        await updateSettings(appearance: value)
    }

    func friendly(_ error: Error) -> String {
        if let api = error as? APIError {
            return api.errorDescription ?? text("common.error")
        }
        return error.localizedDescription
    }
}
