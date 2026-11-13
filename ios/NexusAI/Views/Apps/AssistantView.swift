import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var voice = VoiceRecognizer()
    @State private var chats: [NexusChat] = []
    @State private var projects: [NexusProject] = []
    @State private var messages: [NexusMessage] = []
    @State private var currentChatID: String?
    @State private var projectID: String?
    @State private var input = ""
    @State private var sending = false
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var showHistory = false
    @State private var showVoiceError = false
    private let initialProjectID: String?

    init(initialProjectID: String? = nil) {
        self.initialProjectID = initialProjectID
    }

    var body: some View {
        VStack(spacing: 0) {
            contextBar
            Divider().overlay(.white.opacity(0.06))
            conversation
            Divider().overlay(.white.opacity(0.06))
            composer
        }
        .task { await loadInitial() }
        .onChange(of: voice.transcript) { value in
            if !value.isEmpty { input = value }
        }
        .onChange(of: voice.errorMessage) { value in
            showVoiceError = value != nil
        }
        .alert(app.text("common.error"), isPresented: $showVoiceError) {
            Button(app.text("common.done"), role: .cancel) { voice.errorMessage = nil }
        } message: {
            Text(voice.errorMessage ?? "")
        }
        .sheet(isPresented: $showHistory) {
            HistorySheet(chats: chats, currentID: currentChatID) { chat in
                showHistory = false
                Task { await open(chat) }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var contextBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button(app.text("assistant.project") + ": —") { selectProject(nil) }
                ForEach(projects) { project in
                    Button(project.name) { selectProject(project.id) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10, weight: .bold))
                    Text(selectedProjectName)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundStyle(NexusTheme.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(NexusTheme.gold.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(NexusTheme.gold.opacity(0.24), lineWidth: 1))
            }
            Spacer()
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NexusTheme.text)
            }
            .buttonStyle(.plain)
            Button {
                startNew()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text(app.text("assistant.newChat"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(NexusTheme.emerald)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if loading {
                        ProgressView().tint(NexusTheme.emerald).padding(.top, 40)
                    } else if messages.isEmpty {
                        EmptyStateView(
                            symbol: "sparkles",
                            title: app.text("assistant"),
                            subtitle: app.text("assistant.empty")
                        )
                        .padding(.top, 30)
                    } else {
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                    }
                    if sending {
                        HStack(spacing: 8) {
                            ProgressView().tint(NexusTheme.emerald)
                            Text(app.text("assistant.thinking"))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(NexusTheme.muted)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    if let errorMessage {
                        InlineError(message: errorMessage) {
                            Task { await reload(currentChatID) }
                        }
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(16)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: sending) { _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func bubble(_ message: NexusMessage) -> some View {
        let isUser = message.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 5) {
                Text(isUser ? app.text("assistant.you") : app.text("assistant"))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(isUser ? NexusTheme.ink.opacity(0.65) : NexusTheme.emerald)
                Text(message.content)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(isUser ? NexusTheme.ink : NexusTheme.text)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(
                isUser
                    ? AnyShapeStyle(LinearGradient(colors: [NexusTheme.emerald, NexusTheme.emeraldDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(.white.opacity(0.055)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isUser ? NexusTheme.emerald.opacity(0.4) : .white.opacity(0.08), lineWidth: 1)
            )
            if !isUser { Spacer(minLength: 44) }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if voice.isRecording {
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .foregroundStyle(NexusTheme.emerald)
                    Text(app.text("assistant.listening"))
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.text)
                    Spacer()
                    Button(app.text("common.done")) { voice.stop() }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(NexusTheme.emerald)
                }
                .padding(.horizontal, 4)
            }
            HStack(alignment: .bottom, spacing: 9) {
                Button {
                    if voice.isRecording {
                        voice.stop()
                    } else {
                        voice.start(locale: app.locale)
                    }
                } label: {
                    Image(systemName: voice.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(voice.isRecording ? NexusTheme.danger : NexusTheme.gold)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(app.user?.assistantVoice == false)

                TextField(app.text("assistant.placeholder"), text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(NexusTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))

                Button {
                    Task { await send() }
                } label: {
                    Group {
                        if sending {
                            ProgressView().tint(NexusTheme.ink)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(NexusTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(NexusTheme.emerald, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(sending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(sending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var selectedProjectName: String {
        guard let projectID, let project = projects.first(where: { $0.id == projectID }) else {
            return app.text("assistant.project") + " —"
        }
        return project.name
    }

    private func selectProject(_ id: String?) {
        projectID = id
        startNew()
    }

    private func startNew() {
        currentChatID = nil
        messages = []
        errorMessage = nil
        input = ""
    }

    private func loadInitial() async {
        loading = true
        defer { loading = false }
        guard let client = app.apiClient else { return }
        do {
            async let projectList = client.projects()
            async let chatList = client.chats()
            projects = try await projectList
            chats = try await chatList
            if let initialProjectID {
                projectID = initialProjectID
                currentChatID = nil
                messages = []
            } else if let first = chats.first {
                await open(first)
            }
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func open(_ chat: NexusChat) async {
        currentChatID = chat.id
        projectID = chat.projectID
        await reload(chat.id)
    }

    private func reload(_ chatID: String?) async {
        guard let client = app.apiClient, let chatID else { return }
        do {
            let detail = try await client.chat(id: chatID)
            messages = detail.messages
            currentChatID = detail.id
            projectID = detail.projectID
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = app.apiClient else { return }
        voice.stop()
        let local = NexusMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(local)
        input = ""
        sending = true
        errorMessage = nil
        defer { sending = false }
        do {
            let reply = try await client.assistant(
                message: text,
                chatID: currentChatID,
                projectID: projectID,
                mode: "chat"
            )
            currentChatID = reply.chatID
            let assistant = NexusMessage(
                id: UUID().uuidString,
                role: "assistant",
                content: reply.answer,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            messages.append(assistant)
            if let client = app.apiClient {
                chats = (try? await client.chats()) ?? chats
            }
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}

private struct HistorySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let chats: [NexusChat]
    let currentID: String?
    let onSelect: (NexusChat) -> Void

    var body: some View {
        ZStack {
            NexusBackground()
            VStack(spacing: 12) {
                HStack {
                    Text(app.text("assistant"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(NexusTheme.text)
                    Spacer()
                    Button(app.text("common.close")) { dismiss() }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.emerald)
                }
                .padding(.top, 18)
                .padding(.horizontal, 18)

                if chats.isEmpty {
                    EmptyStateView(symbol: "clock", title: app.text("common.noData"))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(chats) { chat in
                                Button {
                                    onSelect(chat)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(chat.title)
                                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                                .foregroundStyle(NexusTheme.text)
                                                .lineLimit(1)
                                            Text(chat.lastMessage)
                                                .font(.system(.caption2, design: .rounded))
                                                .foregroundStyle(NexusTheme.muted)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Text("\(chat.messageCount)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(NexusTheme.gold)
                                    }
                                    .padding(12)
                                    .background(
                                        chat.id == currentID ? NexusTheme.emerald.opacity(0.10) : .white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }
                }
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
    }
}
