import Foundation
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

// MARK: - AuthViewModel

/// Manages authentication state and login/registration flow.
/// Mirrors Android's SessionManager.login() behavior.
@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published State

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var email: String = ""
    @Published var serverAddress: String = "13.140.25.249:50051"
    @Published var isRegistering: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoggedIn: Bool = false
    @Published var showError: Bool = false

    // MARK: - Dependencies

    private let grpcManager = GRPCManager.shared
    private let credentialStore = CredentialStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Observe connection status
        grpcManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed && self?.isLoading == true {
                    self?.isLoading = false
                    self?.showErrorAlert("Connection failed")
                }
            }
            .store(in: &cancellables)

        // Observe auth status
        grpcManager.$authStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleAuthStatus(status)
            }
            .store(in: &cancellables)

        // Load saved credentials
        loadSavedCredentials()
    }

    // MARK: - Login

    func login() {
        guard validateInput() else { return }

        isLoading = true
        errorMessage = nil

        let parts = serverAddress.split(separator: ":")
        let host = String(parts.first ?? "13.140.25.249")
        let port = parts.count > 1 ? Int(parts[1]) ?? 50051 : 50051

        grpcManager.connect(serverAddress: host, useTLS: false, port: port)

        grpcManager.startChat(
            username: username,
            password: password,
            joinMessage: "",
            register: false,
            email: "",
            deviceId: grpcManager.getUserId(),
            deviceName: "iOS Device"
        ) { [weak self] message in
            // Message received callback
        }

        // Wait for auth result
        Task {
            await waitForAuthResult()
        }
    }

    // MARK: - Registration

    func register() {
        guard validateRegistrationInput() else { return }

        isLoading = true
        errorMessage = nil
        isRegistering = true

        let parts = serverAddress.split(separator: ":")
        let host = String(parts.first ?? "13.140.25.249")
        let port = parts.count > 1 ? Int(parts[1]) ?? 50051 : 50051

        grpcManager.connect(serverAddress: host, useTLS: false, port: port)

        grpcManager.startChat(
            username: username,
            password: password,
            joinMessage: "",
            register: true,
            email: email,
            deviceId: grpcManager.getUserId(),
            deviceName: "iOS Device"
        ) { [weak self] message in
            // Message received callback
        }

        Task {
            await waitForAuthResult()
        }
    }

    // MARK: - Logout

    func logout() {
        credentialStore.clear()
        grpcManager.disconnect()
        isLoggedIn = false
        username = ""
        password = ""
        email = ""
        confirmPassword = ""
    }

    // MARK: - Private Methods

    private func validateInput() -> Bool {
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            showErrorAlert("Username is required")
            return false
        }
        if password.isEmpty {
            showErrorAlert("Password is required")
            return false
        }
        if serverAddress.isEmpty {
            showErrorAlert("Server address is required")
            return false
        }
        return true
    }

    private func validateRegistrationInput() -> Bool {
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            showErrorAlert("Username is required")
            return false
        }
        if password.isEmpty {
            showErrorAlert("Password is required")
            return false
        }
        if password != confirmPassword {
            showErrorAlert("Passwords do not match")
            return false
        }
        if !email.isEmpty && !email.contains("@") {
            showErrorAlert("Invalid email address")
            return false
        }
        if serverAddress.isEmpty {
            showErrorAlert("Server address is required")
            return false
        }
        return true
    }

    private func handleAuthStatus(_ status: String?) {
        guard let status = status else { return }

        isLoading = false

        switch status {
        case "REGISTRATION_SUCCESS":
            completeLogin()

        case "AUTH_FAILED":
            showErrorAlert("Authentication failed. Check username and password.")

        case "USER_NOT_FOUND":
            showErrorAlert("User not found. Please register first.")

        case "EMAIL_ALREADY_IN_USE":
            showErrorAlert("Email is already registered.")

        case "FORCE_LOGOUT":
            logout()
            showErrorAlert("You have been logged out by the server.")

        default:
            // null or unrecognized = success (server sends SERVER_INFO after auth)
            if grpcManager.connectionStatus == .ready {
                completeLogin()
            }
        }
    }

    private func completeLogin() {
        // Save credentials
        credentialStore.save(
            username: username,
            password: password,
            email: email,
            serverAddress: serverAddress
        )

        isLoggedIn = true
        isLoading = false
    }

    private func waitForAuthResult() async {
        let startTime = Date()
        while isLoading {
            if Date().timeIntervalSince(startTime) > 15 {
                isLoading = false
                showErrorAlert("Connection timeout. Please try again.")
                return
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
        isLoading = false
    }

    private func loadSavedCredentials() {
        let savedUsername = credentialStore.getUsername()
        let savedPassword = credentialStore.getPassword()
        let savedServer = credentialStore.getServerAddress()
        let savedEmail = credentialStore.getEmail()

        if !savedUsername.isEmpty {
            username = savedUsername
            password = savedPassword
            email = savedEmail
            serverAddress = savedServer

            // Auto-login if credentials exist
            isLoggedIn = true
        }
    }
}
