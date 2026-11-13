import SwiftUI

struct NexusBackground: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            NexusTheme.background(app.appearance).ignoresSafeArea()
            Circle()
                .fill(NexusTheme.glow())
                .frame(width: 420, height: 420)
                .offset(x: -120, y: -280)
                .blur(radius: 40)
            Circle()
                .fill(RadialGradient(colors: [NexusTheme.gold.opacity(0.18), .clear], center: .center, startRadius: 2, endRadius: 200))
                .frame(width: 360, height: 360)
                .offset(x: 170, y: 240)
                .blur(radius: 30)
        }
        .allowsHitTesting(false)
    }
}

struct AppGlyph: View {
    let symbol: String
    var accent: Color = NexusTheme.emerald
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                            .stroke(accent.opacity(0.32), lineWidth: 1)
                    )
            )
    }
}

struct StatusPill: View {
    let label: String
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? NexusTheme.emerald : NexusTheme.gold)
                .frame(width: 7, height: 7)
                .shadow(color: (active ? NexusTheme.emerald : NexusTheme.gold).opacity(0.7), radius: 5)
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(NexusTheme.text.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
    }
}

struct NexusWindowChrome<Content: View>: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    let symbol: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            NexusBackground()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    AppGlyph(symbol: symbol, accent: accent, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(NexusTheme.text)
                        Text(app.text("app.name"))
                            .font(.system(.caption2, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(NexusTheme.muted)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(NexusTheme.text)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.08), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(app.text("common.close"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)

                content()
            }
        }
        .environmentObject(app)
        .environment(\.layoutDirection, app.locale.layoutDirection)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(NexusTheme.muted)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(NexusTheme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(NexusTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

struct InlineError: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NexusTheme.gold)
            Text(message)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(NexusTheme.text.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let retry {
                Button("Retry", action: retry)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(NexusTheme.emerald)
            }
        }
        .padding(12)
        .background(NexusTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(NexusTheme.gold.opacity(0.22), lineWidth: 1))
    }
}
