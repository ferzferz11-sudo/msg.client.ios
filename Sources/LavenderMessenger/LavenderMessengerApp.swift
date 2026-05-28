import SwiftUI

// MARK: - LavenderMessengerApp

/// Main app entry point.
/// Uses @StateObject for global AuthViewModel to persist auth state across views.
@main
struct LavenderMessengerApp: App {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                MainTabView(authViewModel: authViewModel)
                    .environmentObject(authViewModel)
            } else {
                AuthView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
