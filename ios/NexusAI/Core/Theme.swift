import SwiftUI

enum NexusTheme {
    static let emerald = Color(red: 0.20, green: 0.96, blue: 0.70)
    static let emeraldDeep = Color(red: 0.05, green: 0.55, blue: 0.42)
    static let gold = Color(red: 0.85, green: 0.71, blue: 0.43)
    static let ink = Color(red: 0.03, green: 0.04, blue: 0.06)
    static let midnight = Color(red: 0.03, green: 0.07, blue: 0.14)
    static let text = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let muted = Color(red: 0.60, green: 0.66, blue: 0.70)
    static let danger = Color(red: 0.98, green: 0.42, blue: 0.45)

    static func background(_ appearance: String) -> LinearGradient {
        let base = appearance == "midnight" ? midnight : ink
        return LinearGradient(
            colors: [
                base,
                appearance == "midnight" ? Color(red: 0.02, green: 0.12, blue: 0.20) : Color(red: 0.02, green: 0.10, blue: 0.08),
                base
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func glow(_ color: Color = emerald) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(0.34), color.opacity(0.0)],
            center: .center,
            startRadius: 4,
            endRadius: 220
        )
    }

    static func panel(_ appearance: String) -> Color {
        appearance == "midnight" ? Color(red: 0.05, green: 0.10, blue: 0.18) : Color(red: 0.06, green: 0.08, blue: 0.10)
    }
}

struct GlassPanel: ViewModifier {
    var appearance: String = "dark"

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(NexusTheme.panel(appearance).opacity(0.45))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.20), NexusTheme.emerald.opacity(0.10), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
    }
}

extension View {
    func glassPanel(_ appearance: String = "dark") -> some View {
        modifier(GlassPanel(appearance: appearance))
    }
}

struct NexusPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(NexusTheme.ink)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title).font(.system(.headline, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(NexusTheme.ink)
            .background(
                LinearGradient(
                    colors: [NexusTheme.emerald, NexusTheme.emeraldDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: NexusTheme.emerald.opacity(0.28), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }
}

struct NexusGhostButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(NexusTheme.text)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(.caption, design: .rounded).weight(.bold))
                .tracking(1.8)
                .foregroundStyle(NexusTheme.muted)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
            }
        }
    }
}
