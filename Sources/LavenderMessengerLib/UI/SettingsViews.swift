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
