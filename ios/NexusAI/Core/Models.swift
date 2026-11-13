import Foundation

struct NexusUser: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var name: String
    var locale: String
    var appearance: String
    var soundEnabled: Bool
    var assistantVoice: Bool
}

struct NexusToken: Codable {
    let accessToken: String
    let tokenType: String
    let user: NexusUser
}

struct NexusProject: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var description: String
    var goals: String
    var createdAt: String
    var updatedAt: String
    var fileCount: Int
    var chatCount: Int
}

struct NexusFile: Codable, Identifiable, Equatable {
    let id: String
    var projectID: String?
    var path: String
    var isFolder: Bool
    var content: String
    var updatedAt: String
}

struct NexusMessage: Codable, Identifiable, Equatable {
    let id: String
    let role: String
    let content: String
    let createdAt: String
}

struct NexusChat: Codable, Identifiable, Equatable {
    let id: String
    var projectID: String?
    var title: String
    var createdAt: String
    var updatedAt: String
    var messageCount: Int
    var lastMessage: String
}

struct NexusChatDetail: Codable, Identifiable, Equatable {
    let id: String
    var projectID: String?
    var title: String
    var messages: [NexusMessage]
}

struct AssistantAction: Codable, Equatable, Identifiable {
    var id: String { "\(tool)-\(detail)" }
    let tool: String
    let status: String
    let detail: String
}

struct AssistantReply: Codable, Equatable {
    let chatID: String
    let answer: String
    let model: String
    let actions: [AssistantAction]
    let createdFiles: [String]
    let usedContext: [String]
}

struct NexusTool: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
    let status: String
    let category: String
    let endpoint: String?
}

struct NexusSession: Codable, Identifiable, Equatable {
    let id: String
    let device: String
    let createdAt: String
    let lastSeenAt: String
    let expiresAt: String
    let current: Bool
}

struct SecurityCheck: Codable, Identifiable, Equatable {
    var id: String { identifier }
    let identifier: String
    let label: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case label
        case state
    }
}

struct SecurityStatus: Codable, Equatable {
    let authenticated: Bool
    let currentSessionID: String
    let activeSessions: Int
    let projects: Int
    let files: Int
    let chats: Int
    let checks: [SecurityCheck]
}

struct NexusHealth: Codable, Equatable {
    let status: String
    let service: String
    let version: String
    let database: String
    let geminiConfigured: Bool
    let geminiModel: String
    let time: String
}

struct BoardItem: Identifiable, Equatable {
    let id: String
    let symbol: String
    let value: String
    let delta: String
    let positive: Bool
}
