import SwiftUI

// MARK: - LavenderMessengerApp

@available(iOS 17.0, *)
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
