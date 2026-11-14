import SwiftUI

struct StudioView: View {
    @EnvironmentObject private var app: AppState
    @State private var files: [NexusFile] = []
    @State private var projects: [NexusProject] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var projectFilter: String?
    @State private var selected: NexusFile?
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(app.text("studio.subtitle"))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
                    .lineLimit(1)
                Spacer()
                Menu {
                    Button(app.text("server.allProjects")) { projectFilter = nil }
                    ForEach(projects) { project in
                        Button(project.name) { projectFilter = project.id }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(projectFilter == nil ? NexusTheme.muted : NexusTheme.gold)
                }
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
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
            } else if codeFiles.isEmpty {
                ScrollView {
                    EmptyStateView(symbol: "chevron.left.forwardslash.chevron.right", title: app.text("studio.saveFirst"))
                    Text(app.text("studio.noExecution"))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(codeFiles) { file in
                            Button {
                                selected = file
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(NexusTheme.emerald)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(NexusTheme.text)
                                        Text(language(for: file.path))
                                            .font(.system(size: 8.5, design: .rounded))
                                            .foregroundStyle(NexusTheme.muted)
                                    }
                                    Spacer()
                                    Text(file.path)
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(NexusTheme.muted)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(NexusTheme.muted)
                                }
                                .padding(11)
                                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                }
            }

            Text(app.text("studio.noExecution"))
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(NexusTheme.muted.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { file in
            CodeWorkbenchView(
                file: file,
                projectID: file.projectID,
                projects: projects,
                contextFiles: codeFiles.filter { $0.projectID == file.projectID }
            ) { path, content in
                await update(file: file, path: path, content: content)
            } onClose: {
                selected = nil
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showCreate) {
            CodeWorkbenchView(
                file: nil,
                projectID: projectFilter,
                projects: projects,
                contextFiles: codeFiles.filter { projectFilter == nil || $0.projectID == projectFilter }
            ) { path, content in
                await create(path: path, content: content, projectID: projectFilter)
            } onClose: {
                showCreate = false
            }
            .presentationDetents([.large])
        }
    }

    private var codeFiles: [NexusFile] {
        files
            .filter { !$0.isFolder && (projectFilter == nil || $0.projectID == projectFilter) }
            .sorted { $0.path < $1.path }
    }

    private func language(for path: String) -> String {
        let ext = path.split(separator: ".").last.map { String($0).lowercased() } ?? ""
        switch ext {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js", "mjs": return "JavaScript"
        case "ts": return "TypeScript"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "sql": return "SQL"
        case "md": return "Markdown"
        default: return ext.isEmpty ? "Text" : ext.uppercased()
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let client = app.apiClient else { return }
        do {
            async let fileTask = client.files()
            async let projectTask = client.projects()
            files = try await fileTask
            projects = try await projectTask
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func update(file: NexusFile, path: String, content: String) async -> Bool {
        guard let client = app.apiClient else { return false }
        do {
            _ = try await client.updateFile(id: file.id, path: path, content: content)
            await load()
            return true
        } catch {
            errorMessage = app.friendly(error)
            return false
        }
    }

    private func create(path: String, content: String, projectID: String?) async -> Bool {
        guard let client = app.apiClient else { return false }
        do {
            _ = try await client.createFile(path: path, content: content, isFolder: false, projectID: projectID)
            await load()
            return true
        } catch {
            errorMessage = app.friendly(error)
            return false
        }
    }
}

private struct CodeWorkbenchView: View {
    @EnvironmentObject private var app: AppState
    let file: NexusFile?
    let projectID: String?
    let projects: [NexusProject]
    let contextFiles: [NexusFile]
    let onSave: (String, String) async -> Bool
    let onClose: () -> Void

    @State private var path: String
    @State private var content: String
    @State private var busy = false
    @State private var saving = false
    @State private var result: String?
    @State private var resultTitle = ""
    @State private var errorMessage: String?

    init(
        file: NexusFile?,
        projectID: String?,
        projects: [NexusProject],
        contextFiles: [NexusFile],
        onSave: @escaping (String, String) async -> Bool,
        onClose: @escaping () -> Void
    ) {
        self.file = file
        self.projectID = projectID
        self.projects = projects
        self.contextFiles = contextFiles
        self.onSave = onSave
        self.onClose = onClose
        _path = State(initialValue: file?.path ?? "/code/")
        _content = State(initialValue: file?.content ?? "")
    }

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(file == nil ? app.text("common.new") : app.text("studio"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Spacer()
                        Button(app.text("common.close")) { onClose() }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }

                    TextField(app.text("studio.filePath"), text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(NexusTheme.text)
                        .padding(10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    TextEditor(text: $content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(NexusTheme.text)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 240)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))

                    HStack(spacing: 8) {
                        actionChip(app.text("studio.explain"), icon: "text.magnifyingglass", mode: "explain")
                        actionChip(app.text("studio.review"), icon: "checkmark.seal", mode: "review")
                        actionChip(app.text("studio.fix"), icon: "wrench.and.screwdriver", mode: "fix")
                    }

                    if busy {
                        HStack(spacing: 8) {
                            ProgressView().tint(NexusTheme.emerald)
                            Text(app.text("common.loading"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(NexusTheme.muted)
                        }
                    }

                    if let errorMessage {
                        InlineError(message: errorMessage) { result = nil; self.errorMessage = nil }
                    }

                    if let result {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(resultTitle.isEmpty ? app.text("studio.result") : resultTitle)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.1)
                                .foregroundStyle(NexusTheme.gold)
                            Text(result)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(NexusTheme.text)
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NexusTheme.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(NexusTheme.gold.opacity(0.18), lineWidth: 1))
                    }

                    NexusPrimaryButton(title: app.text("common.save"), icon: "tray.and.arrow.down", loading: saving) {
                        guard !content.isEmpty else { return }
                        saving = true
                        Task {
                            let ok = await onSave(path, content)
                            saving = false
                            if ok { onClose() }
                        }
                    }

                    Text(app.text("studio.noExecution"))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(NexusTheme.muted)
                }
                .padding(18)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
    }

    private func actionChip(_ title: String, icon: String, mode: String) -> some View {
        Button {
            Task { await analyse(mode: mode, title: title) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(NexusTheme.emerald)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(NexusTheme.emerald.opacity(0.09), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(NexusTheme.emerald.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(busy || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(busy || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    private func analyse(mode: String, title: String) async {
        guard let client = app.apiClient else { return }
        busy = true
        result = nil
        errorMessage = nil
        defer { busy = false }

        var message: String
        switch mode {
        case "review":
            let bundle = contextFiles.prefix(8).map { item in
                "FILE \(item.path)\n```\n\(String(item.content.prefix(2500)))\n```"
            }.joined(separator: "\n\n")
            let projectName = projects.first(where: { $0.id == projectID })?.name ?? "NEXUS project"
            message = "Review this project (\(projectName)) for defects, risks and missing tests.\n\n\(bundle)"
        case "fix":
            message = "Find errors in this code and return corrected code with a short explanation.\n\nFILE \(path)\n```\n\(content.prefix(6000))\n```"
        default:
            message = "Explain this code clearly, step by step.\n\nFILE \(path)\n```\n\(content.prefix(6000))\n```"
        }

        do {
            let reply = try await client.assistant(message: message, chatID: nil, projectID: projectID, mode: mode)
            resultTitle = title
            result = reply.answer
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}
