import SwiftUI

enum NexusModule: String, Identifiable, CaseIterable {
    case assistant
    case files
    case projects
    case studio
    case security
    case store
    case settings

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .assistant: return "sparkles"
        case .files: return "folder.fill"
        case .projects: return "square.stack.3d.up.fill"
        case .studio: return "chevron.left.forwardslash.chevron.right"
        case .security: return "lock.shield.fill"
        case .store: return "bag.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var accent: Color {
        switch self {
        case .assistant: return NexusTheme.emerald
        case .files: return Color(red: 0.45, green: 0.78, blue: 1.0)
        case .projects: return NexusTheme.gold
        case .studio: return Color(red: 0.72, green: 0.58, blue: 1.0)
        case .security: return Color(red: 0.98, green: 0.55, blue: 0.52)
        case .store: return Color(red: 0.42, green: 0.92, blue: 0.88)
        case .settings: return Color(red: 0.70, green: 0.73, blue: 0.78)
        }
    }

    var titleKey: String {
        switch self {
        case .assistant: return "assistant"
        case .files: return "files"
        case .projects: return "projects"
        case .studio: return "studio"
        case .security: return "security"
        case .store: return "store"
        case .settings: return "settings"
        }
    }
}

struct ModuleHost: View {
    @EnvironmentObject private var app: AppState
    let module: NexusModule

    var body: some View {
        NexusWindowChrome(
            title: app.text(module.titleKey),
            symbol: module.symbol,
            accent: module.accent
        ) {
            switch module {
            case .assistant: AssistantView()
            case .files: FilesView()
            case .projects: ProjectsView()
            case .studio: StudioView()
            case .security: SecurityView()
            case .store: StoreView()
            case .settings: SettingsView()
            }
        }
    }
}
