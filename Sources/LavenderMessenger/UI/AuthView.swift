import SwiftUI

// MARK: - AuthView

/// Login and registration screen.
/// Provides forms for both login and registration modes.
struct AuthView: View {

    @StateObject private var viewModel = AuthViewModel()
    @State private var showServerPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo area
                    VStack(spacing: 12) {
                        Image(systemName: "message.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.purple.gradient)

                        Text("Lavender Messenger")
                            .font(.title.bold())
                            .foregroundStyle(.primary)

                        Text("Secure messaging")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    // Server selector
                    serverSection

                    // Form
                    if viewModel.isRegistering {
                        registrationForm
                    } else {
                        loginForm
                    }

                    // Toggle mode
                    toggleModeButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
                MainTabView(authViewModel: viewModel)
            }
        }
    }

    // MARK: - Server Section

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.purple)
                    .frame(width: 20)

                TextField("Server address", text: $viewModel.serverAddress)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 16) {
            FormField(
                icon: "person.fill",
                placeholder: "Username",
                text: $viewModel.username
            )

            FormField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $viewModel.password,
                isSecure: true
            )

            Button(action: { viewModel.login() }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.gradient)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Registration Form

    private var registrationForm: some View {
        VStack(spacing: 16) {
            FormField(
                icon: "person.fill",
                placeholder: "Username",
                text: $viewModel.username
            )

            FormField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $viewModel.email
            )
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            FormField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $viewModel.password,
                isSecure: true
            )

            FormField(
                icon: "lock.rotation",
                placeholder: "Confirm Password",
                text: $viewModel.confirmPassword,
                isSecure: true
            )

            Button(action: { viewModel.register() }) {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.gradient)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Toggle Mode

    private var toggleModeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.isRegistering.toggle()
                viewModel.errorMessage = nil
            }
        }) {
            HStack {
                Text(viewModel.isRegistering ? "Already have an account?" : "Don't have an account?")
                    .foregroundStyle(.secondary)
                Text(viewModel.isRegistering ? "Sign In" : "Register")
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.purple)
                Text(viewModel.isRegistering ? "Creating account..." : "Signing in...")
                    .font(.headline)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - Form Field

struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AuthView Preview

#Preview {
    AuthView()
}
