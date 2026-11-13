import SwiftUI

struct FilesView: View {
    @EnvironmentObject private var app: AppState
    @State private var files: [NexusFile] = []
    @State private var projects: [NexusProject] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var currentFolder: String?
    @State private var projectFilter: String?
    @State private var showCreate = false
    @State private var editing: NexusFile?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(.white.opacity(0.06))
            content
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showCreate) {
            FileComposerView(
                initialFolder: currentFolder,
                projectID: projectFilter,
                projects: projects
            ) { path, content, folder, projectID in
                await create(path: path, content: content, isFolder: folder, projectID: projectID)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $editing) { file in
            FileEditorView(file: file) { path, content in
                await update(file: file, path: path, content: content)
            } onDelete: {
                await delete(file: file)
            }
            .presentationDetents([.large])
        }
    }

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    if currentFolder != nil { goUp() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(currentFolder == nil ? NexusTheme.muted.opacity(0.4) : NexusTheme.text)
                }
                .buttonStyle(.plain)
                .disabled(currentFolder == nil)

                Text(currentFolder ?? "/")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NexusTheme.text)
                    .lineLimit(1)
                Spacer()
                Menu {
                    Button("All projects") { projectFilter = nil; Task { await load() } }
                    ForEach(projects) { project in
                        Button(project.name) { projectFilter = project.id; currentFolder = nil; Task { await load() } }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 15, weight: .semibold))
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
            .padding(.top, 10)

            if let errorMessage {
                InlineError(message: errorMessage) { Task { await load() } }
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            Spacer()
            ProgressView().tint(NexusTheme.emerald)
            Spacer()
        } else if visibleFiles.isEmpty {
            ScrollView {
                EmptyStateView(symbol: "folder", title: app.text("files.empty"))
                    .padding(.horizontal, 16)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 7) {
                    ForEach(visibleFiles) { file in
                        row(file)
                    }
                }
                .padding(14)
            }
        }
    }

    private func row(_ file: NexusFile) -> some View {
        Button {
            if file.isFolder {
                currentFolder = file.path
            } else {
                editing = file
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: file.isFolder ? "folder.fill" : "doc.text")
                    .font(.system(size: 15))
                    .foregroundStyle(file.isFolder ? NexusTheme.gold : NexusTheme.emerald)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(file))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(NexusTheme.text)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(file.path)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(NexusTheme.muted)
                            .lineLimit(1)
                        if let projectID = file.projectID,
                           let project = projects.first(where: { $0.id == projectID }) {
                            Text(project.name)
                                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                                .foregroundStyle(NexusTheme.gold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(NexusTheme.gold.opacity(0.10), in: Capsule())
                        }
                    }
                }
                Spacer()
                Image(systemName: file.isFolder ? "chevron.right" : "chevron.right.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NexusTheme.muted)
            }
            .padding(11)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(app.text("common.rename")) { rename(file) }
            Button(app.text("common.delete"), role: .destructive) { Task { await delete(file: file) } }
        }
    }

    private var visibleFiles: [NexusFile] {
        let pool = files.filter { projectFilter == nil || $0.projectID == projectFilter }
        guard let currentFolder else {
            return pool.sorted { $0.path < $1.path }
        }
        let prefix = currentFolder + "/"
        return pool.filter {
            $0.path.hasPrefix(prefix) && !$0.path.dropFirst(prefix.count).contains("/")
        }
        .sorted { $0.path < $1.path }
    }

    private func displayName(_ file: NexusFile) -> String {
        let parts = file.path.split(separator: "/")
        return parts.last.map(String.init) ?? file.path
    }

    private func goUp() {
        guard let currentFolder else { return }
        let parts = currentFolder.split(separator: "/")
        currentFolder = parts.count <= 1 ? nil : "/" + parts.dropLast().joined(separator: "/")
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let client = app.apiClient else { return }
        do {
            async let filesTask = client.files()
            async let projectsTask = client.projects()
            files = try await filesTask
            projects = try await projectsTask
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func create(path: String, content: String, isFolder: Bool, projectID: String?) async {
        guard let client = app.apiClient else { return }
        do {
            _ = try await client.createFile(path: path, content: content, isFolder: isFolder, projectID: projectID)
            showCreate = false
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func update(file: NexusFile, path: String, content: String) async {
        guard let client = app.apiClient else { return }
        do {
            _ = try await client.updateFile(id: file.id, path: path, content: content)
            editing = nil
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func rename(_ file: NexusFile) {
        editing = file
    }

    private func delete(file: NexusFile) async {
        guard let client = app.apiClient else { return }
        do {
            try await client.deleteFile(id: file.id)
            if editing?.id == file.id { editing = nil }
            await load()
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}

private struct FileComposerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let initialFolder: String?
    let projectID: String?
    let projects: [NexusProject]
    let onCreate: (String, String, Bool, String?) async -> Void

    @State private var path = ""
    @State private var content = ""
    @State private var isFolder = false

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(app.text("common.create"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Spacer()
                        Button(app.text("common.close")) { dismiss() }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }

                    Picker("", selection: $isFolder) {
                        Text(app.text("files.newFile")).tag(false)
                        Text(app.text("files.newFolder")).tag(true)
                    }
                    .pickerStyle(.segmented)

                    Text(app.text("files.path"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.muted)
                    TextField(app.text("files.pathHint"), text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(NexusTheme.text)
                        .padding(12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !isFolder {
                        Text(app.text("files.content"))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.muted)
                        TextEditor(text: $content)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(NexusTheme.text)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 190)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let projectID, let project = projects.first(where: { $0.id == projectID }) {
                        Label(project.name, systemImage: "square.stack.3d.up")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NexusTheme.gold)
                    }

                    NexusPrimaryButton(title: app.text("common.create"), icon: "plus") {
                        let folder = initialFolder ?? ""
                        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.hasPrefix("/") { value = folder + "/" + value }
                        Task {
                            await onCreate(value, content, isFolder, projectID)
                        }
                    }
                    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .onAppear {
            if let initialFolder, path.isEmpty { path = initialFolder + "/" }
        }
    }
}

private struct FileEditorView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let file: NexusFile
    let onSave: (String, String) async -> Void
    let onDelete: () async -> Void

    @State private var path: String
    @State private var content: String
    @State private var saving = false
    @State private var confirmDelete = false

    init(file: NexusFile, onSave: @escaping (String, String) async -> Void, onDelete: @escaping () async -> Void) {
        self.file = file
        self.onSave = onSave
        self.onDelete = onDelete
        _path = State(initialValue: file.path)
        _content = State(initialValue: file.content)
    }

    var body: some View {
        ZStack {
            NexusBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(file.isFolder ? app.text("files.newFolder") : app.text("common.edit"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Spacer()
                        Button(app.text("common.close")) { dismiss() }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(NexusTheme.emerald)
                    }

                    TextField(app.text("files.path"), text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(NexusTheme.text)
                        .padding(12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if !file.isFolder {
                        TextEditor(text: $content)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(NexusTheme.text)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 320)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if file.isFolder {
                        Text(app.text("files.newFolder"))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(NexusTheme.muted)
                    }

                    NexusPrimaryButton(title: app.text("common.save"), icon: "tray.and.arrow.down", loading: saving) {
                        saving = true
                        Task {
                            await onSave(path, content)
                            saving = false
                        }
                    }

                    Button {
                        confirmDelete = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text(app.text("common.delete"))
                            Spacer()
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.danger)
                        .padding(12)
                        .background(NexusTheme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .confirmationDialog(app.text("files.deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(app.text("common.delete"), role: .destructive) {
                Task { await onDelete() }
            }
            Button(app.text("common.cancel"), role: .cancel) {}
        }
    }
}
