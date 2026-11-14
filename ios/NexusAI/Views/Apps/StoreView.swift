import SwiftUI

struct StoreView: View {
    @EnvironmentObject private var app: AppState
    @State private var tools: [NexusTool] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var detail: NexusTool?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(app.text("store.subtitle"))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
                    .lineLimit(1)
                Spacer()
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
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
            } else if tools.isEmpty {
                ScrollView {
                    EmptyStateView(symbol: "square.grid.2x2", title: app.text("store.empty"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(tools) { tool in
                            Button {
                                detail = tool
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: symbol(for: tool.id))
                                        .font(.system(size: 16))
                                        .foregroundStyle(NexusTheme.gold)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tool.name)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .foregroundStyle(NexusTheme.text)
                                        Text(tool.summary)
                                            .font(.system(size: 10, design: .rounded))
                                            .foregroundStyle(NexusTheme.muted)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Text(tool.status.uppercased())
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(tool.status == "available" ? NexusTheme.emerald : NexusTheme.gold)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            (tool.status == "available" ? NexusTheme.emerald : NexusTheme.gold).opacity(0.10),
                                            in: Capsule()
                                        )
                                }
                                .padding(12)
                                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $detail) { tool in
            ToolDetailView(tool: tool)
                .presentationDetents([.medium])
        }
    }

    private func symbol(for id: String) -> String {
        switch id {
        case "assistant": return "sparkles"
        case "smart-files": return "folder.badge.gearshape"
        case "projects": return "square.stack.3d.up"
        case "developer-studio": return "chevron.left.forwardslash.chevron.right"
        case "security-center": return "lock.shield"
        default: return "puzzlepiece.extension"
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        guard let client = app.apiClient else { return }
        do {
            tools = try await client.tools()
            errorMessage = nil
        } catch let error as APIError {
            if error.isUnauthorized { app.handleUnauthorized() }
            else { errorMessage = app.friendly(error) }
        } catch {
            errorMessage = app.friendly(error)
        }
    }
}

private struct ToolDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let tool: NexusTool

    var body: some View {
        ZStack {
            NexusBackground()
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(tool.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(NexusTheme.text)
                    Spacer()
                    Button(app.text("common.close")) { dismiss() }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(NexusTheme.emerald)
                }
                Text(tool.summary)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(NexusTheme.text.opacity(0.9))
                row(label: app.text("common.appearance"), value: tool.category)
                row(label: app.text("common.status"), value: tool.status)
                if let endpoint = tool.endpoint {
                    row(label: app.text("common.api"), value: endpoint)
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(NexusTheme.muted)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(NexusTheme.gold)
                .multilineTextAlignment(.trailing)
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
