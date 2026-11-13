import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            NexusBackground()
            if app.isAuthenticated {
                HomeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .animation(.easeInOut(duration: 0.35), value: app.isAuthenticated)
        .task {
            if app.token != nil {
                await app.restoreSession()
            }
            await app.refreshHealth()
        }
    }
}
