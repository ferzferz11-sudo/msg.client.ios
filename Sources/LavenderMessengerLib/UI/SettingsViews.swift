import SwiftUI

struct EditProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var bio: String = ""
    @State private var status: String = ""

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Username", text: $authViewModel.username)
                    .disabled(true)

                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)

                TextField("Status", text: $status)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { dismiss() }
            }
        }
    }
}

struct SecurityView: View {
    var body: some View {
        Form {
            Section("Change Password") {
                SecureField("Current Password", text: .constant(""))
                SecureField("New Password", text: .constant(""))
                SecureField("Confirm Password", text: .constant(""))
            }

            Section("Active Sessions") {
                Text("Active sessions management coming soon")
                    .foregroundStyle(.secondary)
            }

            Section("Secret Chats") {
                Text("E2EE chat management coming soon")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationsView: View {
    @State private var pushEnabled: Bool = true
    @State private var soundEnabled: Bool = true

    var body: some View {
        Form {
            Section("Push Notifications") {
                Toggle("Enable Notifications", isOn: $pushEnabled)
                Toggle("Sound", isOn: $soundEnabled)
            }

            Section("Do Not Disturb") {
                Text("Configure quiet hours")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppearanceView: View {
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    @AppStorage("fontSize") private var fontSize: Double = 16

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme", selection: $selectedTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Chat") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(fontSize))pt")
                        .foregroundStyle(.secondary)
                    Slider(value: $fontSize, in: 12...24, step: 1)
                        .frame(width: 120)
                }

                NavigationLink("Chat Background") {
                    Text("Background selection coming soon")
                        .navigationTitle("Background")
                }
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
