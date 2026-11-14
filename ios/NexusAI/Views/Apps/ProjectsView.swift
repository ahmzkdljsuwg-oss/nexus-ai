import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var app: AppState
    @State private var projects: [NexusProject] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var detail: NexusProject?
    @State private var assistantProject: NexusProject?
    @State private var deleteTarget: NexusProject?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(app.text("projects.subtitle"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
                Spacer()
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text(app.text("projects.new"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(NexusTheme.emerald)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let errorMessage {
                InlineError(message: errorMessage) { Task { await load() } }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if loading {
                Spacer()
                ProgressView().tint(NexusTheme.emerald)
                Spacer()
            } else if projects.isEmpty {
                ScrollView {
                    EmptyStateView(symbol: "square.stack.3d.up", title: app.text("projects.empty"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(projects) { project in
                            card(project)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            ProjectComposerView { name, description, goals in
                await create(name: name, description: description, goals: goals)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $detail) { project in
            ProjectDetailView(project: project) {
                assistantProject = project
                detail = nil
            }
            .presentationDetents([.large])
        }
        .sheet(item: $assistantProject) { project in
            NexusWindowChrome(
                title: app.text("assistant"),
                symbol: NexusModule.assistant.symbol,
                accent: NexusModule.assistant.accent
            ) {
                AssistantView(initialProjectID: project.id)
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(app.text("common.delete"), isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), titleVisibility: .visible) {
            Button(app.text("common.delete"), role: .destructive) {
                if let target = deleteTarget { Task { await remove(target) } }
            }
            Button(app.text("common.cancel"), role: .cancel) { deleteTarget = nil }
        }
    }

    private func card(_ project: NexusProject) -> some View {
        Button {
            detail = project
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(NexusTheme.gold)
                    Text(project.name)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Menu {
                        Button(app.text("assistant.openAssistant")) {
                            assistantProject = project
                        }
                        Button(app.text("common.delete"), role: .destructive) { deleteTarget = project }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(NexusTheme.muted)
                            .frame(width: 26, height: 26)
                    }
                }
                if !project.description.isEmpty {
                    Text(project.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 14) {
                    Label("\(project.fileCount) \(app.text("projects.files"))", systemImage: "doc.text")
                    Label("\(project.chatCount) \(app.text("projects.chats"))", systemImage: "bubble.left.and.text.bubble.right")
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(NexusTheme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LinearGradient(colors: [NexusTheme.gold.opacity(0.26), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let client = app.apiClient else { return }
        do {
            projects = try await client.projects()
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func create(name: String, description: String, goals: String) async {
        guard let client = app.apiClient else { return }
        do {
            _ = try await client.createProject(name: name, description: description, goals: goals)
            showCreate = false
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func remove(_ project: NexusProject) async {
        guard let client = app.apiClient else { return }
        do {
            try await client.deleteProject(id: project.id)
            deleteTarget = nil
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}

private struct ProjectComposerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String, String, String) async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var goals = ""

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(app.text("projects.new"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Spacer()
                        Button(app.text("common.close")) { dismiss() }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }

                    input(app.text("projects.name"), text: $name)
                    input(app.text("projects.description"), text: $description)
                    Text(app.text("projects.goals"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.muted)
                    TextEditor(text: $goals)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(NexusTheme.text)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 120)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    NexusPrimaryButton(title: app.text("common.create"), icon: "plus") {
                        Task { await onCreate(name, description, goals) }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
    }

    private func input(_ placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(placeholder)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(NexusTheme.muted)
            TextField(placeholder, text: text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(NexusTheme.text)
                .padding(12)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct ProjectDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let project: NexusProject
    let openAssistant: () -> Void

    @State private var files: [NexusFile] = []
    @State private var chats: [NexusChat] = []
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(project.name)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Spacer()
                        Button(app.text("common.close")) { dismiss() }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(NexusTheme.text.opacity(0.9))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SectionTitle(text: app.text("projects.goals"))
                        Text(project.goals.isEmpty ? "—" : project.goals)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(NexusTheme.text.opacity(0.9))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(app.appearance)

                    HStack(spacing: 10) {
                        metric("\(project.fileCount)", app.text("projects.files"), "doc.text")
                        metric("\(project.chatCount)", app.text("projects.chats"), "bubble.left.and.text.bubble.right")
                    }

                    if let errorMessage {
                        InlineError(message: errorMessage) { Task { await load() } }
                    }

                    SectionTitle(text: app.text("files"))
                    if files.isEmpty {
                        Text(app.text("common.noData"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NexusTheme.muted)
                    } else {
                        ForEach(files) { file in
                            HStack(spacing: 9) {
                                Image(systemName: file.isFolder ? "folder.fill" : "doc.text")
                                    .foregroundStyle(file.isFolder ? NexusTheme.gold : NexusTheme.emerald)
                                Text(file.path)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(NexusTheme.text)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(9)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    SectionTitle(text: app.text("chats"))
                    if chats.isEmpty {
                        Text(app.text("common.noData"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NexusTheme.muted)
                    } else {
                        ForEach(chats) { chat in
                            HStack(spacing: 9) {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .foregroundStyle(NexusTheme.emerald)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .font(.system(.caption, design: .rounded).weight(.semibold))
                                        .foregroundStyle(NexusTheme.text)
                                        .lineLimit(1)
                                    Text(chat.lastMessage)
                                        .font(.system(size: 8.5, design: .monospaced))
                                        .foregroundStyle(NexusTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(chat.messageCount)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(NexusTheme.gold)
                            }
                            .padding(9)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    NexusPrimaryButton(title: app.text("projects.openAssistant"), icon: "sparkles") {
                        openAssistant()
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .task { await load() }
    }

    private func metric(_ value: String, _ label: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(NexusTheme.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(NexusTheme.text)
                Text(label).font(.system(size: 9, design: .rounded)).foregroundStyle(NexusTheme.muted)
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() async {
        guard let client = app.apiClient else { return }
        do {
            async let fileTask = client.files()
            async let chatTask = client.chats()
            let allFiles = try await fileTask
            let allChats = try await chatTask
            files = allFiles.filter { $0.projectID == project.id }
            chats = allChats.filter { $0.projectID == project.id }
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}
