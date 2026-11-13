import Foundation

enum APIError: LocalizedError {
    case missingServer
    case invalidURL
    case transport(String)
    case server(status: Int, message: String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingServer: return "Set the NEXUS server URL first."
        case .invalidURL: return "The server URL is not valid."
        case .transport(let detail): return detail
        case .server(_, let message): return message
        case .decoding: return "The server returned an unexpected response."
        }
    }

    var isUnauthorized: Bool {
        if case .server(let status, _) = self { return status == 401 }
        return false
    }
}

struct EmptyBody: Encodable {}

struct APIClient {
    let baseURL: URL
    var token: String?

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    init(baseURL: URL, token: String?) {
        self.baseURL = baseURL
        self.token = token
    }

    func health() async throws -> NexusHealth {
        try await get("api/health", as: NexusHealth.self)
    }

    func register(email: String, name: String, password: String) async throws -> NexusToken {
        try await send(
            "api/auth/register",
            method: "POST",
            body: RegisterBody(email: email, name: name, password: password),
            as: NexusToken.self
        )
    }

    func login(email: String, password: String) async throws -> NexusToken {
        try await send(
            "api/auth/login",
            method: "POST",
            body: LoginBody(email: email, password: password, device: "iPhone"),
            as: NexusToken.self
        )
    }

    func account() async throws -> NexusUser {
        try await get("api/account", as: NexusUser.self)
    }

    func updateSettings(locale: String?, appearance: String?, soundEnabled: Bool?, voiceEnabled: Bool?) async throws -> NexusUser {
        try await send(
            "api/settings",
            method: "PATCH",
            body: SettingsBody(locale: locale, appearance: appearance, soundEnabled: soundEnabled, assistantVoice: voiceEnabled),
            as: NexusUser.self
        )
    }

    func updateAccount(name: String?, password: String?) async throws -> NexusUser {
        struct Body: Encodable {
            let name: String?
            let password: String?
        }
        return try await send("api/account", method: "PATCH", body: Body(name: name, password: password), as: NexusUser.self)
    }

    func projects() async throws -> [NexusProject] {
        try await get("api/projects", as: [NexusProject].self)
    }

    func createProject(name: String, description: String, goals: String) async throws -> NexusProject {
        try await send(
            "api/projects",
            method: "POST",
            body: ProjectBody(name: name, description: description, goals: goals),
            as: NexusProject.self
        )
    }

    func updateProject(id: String, name: String?, description: String?, goals: String?) async throws -> NexusProject {
        try await send(
            "api/projects/\(id)",
            method: "PATCH",
            body: ProjectBody(name: name, description: description, goals: goals),
            as: NexusProject.self
        )
    }

    func deleteProject(id: String) async throws {
        try await sendNoContent("api/projects/\(id)", method: "DELETE")
    }

    func files() async throws -> [NexusFile] {
        try await get("api/files", as: [NexusFile].self)
    }

    func createFile(path: String, content: String, isFolder: Bool = false, projectID: String? = nil) async throws -> NexusFile {
        try await send(
            "api/files",
            method: "POST",
            body: FileBody(path: path, isFolder: isFolder, content: content, projectID: projectID),
            as: NexusFile.self
        )
    }

    func updateFile(id: String, path: String?, content: String?) async throws -> NexusFile {
        try await send(
            "api/files/\(id)",
            method: "PATCH",
            body: FileUpdateBody(path: path, content: content),
            as: NexusFile.self
        )
    }

    func deleteFile(id: String) async throws {
        try await sendNoContent("api/files/\(id)", method: "DELETE")
    }

    func chats() async throws -> [NexusChat] {
        try await get("api/chats", as: [NexusChat].self)
    }

    func chat(id: String) async throws -> NexusChatDetail {
        try await get("api/chats/\(id)", as: NexusChatDetail.self)
    }

    func assistant(message: String, chatID: String?, projectID: String?, mode: String) async throws -> AssistantReply {
        try await send(
            "api/assistant/chat",
            method: "POST",
            body: AssistantBody(message: message, chatID: chatID, projectID: projectID, mode: mode),
            as: AssistantReply.self
        )
    }

    func securityStatus() async throws -> SecurityStatus {
        try await get("api/security/status", as: SecurityStatus.self)
    }

    func sessions() async throws -> [NexusSession] {
        try await get("api/auth/sessions", as: [NexusSession].self)
    }

    func revokeSession(id: String) async throws {
        try await sendNoContent("api/auth/sessions/\(id)", method: "DELETE")
    }

    func logout() async throws {
        try await sendNoContent("api/auth/logout", method: "POST")
    }

    func tools() async throws -> [NexusTool] {
        try await get("api/tools", as: [NexusTool].self)
    }

    private func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await request(path: path, method: "GET", body: nil, as: type)
    }

    private func send<T: Decodable, B: Encodable>(_ path: String, method: String, body: B, as type: T.Type) async throws -> T {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(body)
        return try await request(path: path, method: method, body: data, as: type)
    }

    private func sendNoContent(_ path: String, method: String) async throws {
        let (_, response) = try await raw(path: path, method: method, body: nil)
        try validate(response: response, data: nil)
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?, as type: T.Type) async throws -> T {
        let (data, response) = try await raw(path: path, method: method, body: body)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func raw(path: String, method: String, body: Data?) async throws -> (Data, URLResponse) {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, clean].filter { !$0.isEmpty }.joined(separator: "/")
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: http.statusCode, message: Self.errorMessage(from: data) ?? "HTTP \(http.statusCode)")
        }
    }

    private static func errorMessage(from data: Data?) -> String? {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let dict = object as? [String: Any] {
            if let detail = dict["detail"] as? String { return detail }
            if let detail = dict["detail"] as? [[String: Any]] {
                return detail.compactMap { $0["msg"] as? String }.joined(separator: "\n")
            }
        }
        return nil
    }
}

private struct RegisterBody: Encodable {
    let email: String
    let name: String
    let password: String
}

private struct LoginBody: Encodable {
    let email: String
    let password: String
    let device: String
}

private struct SettingsBody: Encodable {
    let locale: String?
    let appearance: String?
    let soundEnabled: Bool?
    let assistantVoice: Bool?
}

private struct ProjectBody: Encodable {
    let name: String?
    let description: String?
    let goals: String?
}

private struct FileBody: Encodable {
    let path: String
    let isFolder: Bool
    let content: String
    let projectID: String?
}

private struct FileUpdateBody: Encodable {
    let path: String?
    let content: String?
}

private struct AssistantBody: Encodable {
    let message: String
    let chatID: String?
    let projectID: String?
    let mode: String
}
