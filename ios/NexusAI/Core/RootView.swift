import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            NexusBackground()
            HomeView()
                .transition(.opacity)
        }
        .environment(\.layoutDirection, app.locale.layoutDirection)
        .task {
            await app.refreshHealth()
        }
    }
}
