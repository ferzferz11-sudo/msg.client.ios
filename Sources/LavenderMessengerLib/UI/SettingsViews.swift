import SwiftUI

struct ChatInfoView: View {
    let chatId: String
    let chatName: String
    let username: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(String(chatName.prefix(1)).uppercased())
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.purple)
                            }

                        VStack(alignment: .leading) {
                            Text(chatName)
                                .font(.title3.weight(.semibold))
                            Text("Chat ID: \(chatId.prefix(8))...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Actions") {
                    Button(action: {}) {
                        Label("Clear History", systemImage: "trash")
                    }

                    Button(action: {}) {
                        Label("Export Chat", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive, action: {}) {
                        Label("Delete Chat", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Chat Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

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
