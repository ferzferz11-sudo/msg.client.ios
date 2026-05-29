import SwiftUI

struct ContactsView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Text("Contacts feature coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Contacts")
        }
    }
}

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Text(String(authViewModel.username.prefix(1)).uppercased())
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.purple)
                            }

                        VStack(alignment: .leading) {
                            Text(authViewModel.username)
                                .font(.headline)
                            Text("Online")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Account") {
                    NavigationLink("Edit Profile") {
                        EditProfileView(authViewModel: authViewModel)
                    }

                    NavigationLink("Security") {
                        SecurityView()
                    }

                    NavigationLink("Notifications") {
                        NotificationsView()
                    }

                    NavigationLink("Appearance") {
                        AppearanceView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(ClientVersion.string)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Server")
                        Spacer()
                        Text(authViewModel.serverAddress)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Section {
                    Button(role: .destructive, action: {
                        authViewModel.logout()
                    }) {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
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
