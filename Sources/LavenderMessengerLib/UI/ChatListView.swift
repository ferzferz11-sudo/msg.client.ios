import SwiftUI

// MARK: - MainTabView

/// Main app view after login — contains tab bar with chats, contacts, and settings.
struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var chatListViewModel = ChatListViewModel()

    var body: some View {
        TabView {
            ChatListView(
                chatListViewModel: chatListViewModel,
                authViewModel: authViewModel
            )
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chats")
            }

            ContactsView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Contacts")
                }

            SettingsView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tint(.purple)
        .onAppear {
            chatListViewModel.loadChats(username: authViewModel.username)
        }
    }
}

// MARK: - ChatListView

/// Displays the list of chats/conversations.
struct ChatListView: View {
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showNewChat: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                if chatListViewModel.chats.isEmpty && !chatListViewModel.isLoading {
                    emptyState
                } else {
                    chatList
                }
            }
            .navigationTitle("Lavender")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("New Group", action: { chatListViewModel.showNewGroup = true })
                        Button("Refresh", action: { chatListViewModel.loadChats(username: authViewModel.username) })
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatSheet(chatListViewModel: chatListViewModel, authViewModel: authViewModel)
            }
            .sheet(isPresented: $chatListViewModel.showNewGroup) {
                NewGroupSheet(chatListViewModel: chatListViewModel, authViewModel: authViewModel)
            }
        }
    }

    private var chatList: some View {
        List(chatListViewModel.chats) { chat in
            NavigationLink(destination: ChatRoomView(
                chatId: chat.id,
                chatName: chat.displayName(currentUsername: authViewModel.username),
                username: authViewModel.username
            )) {
                ChatRowView(chat: chat, currentUsername: authViewModel.username)
            }
        }
        .listStyle(.plain)
        .refreshable {
            chatListViewModel.loadChats(username: authViewModel.username)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 64))
                .foregroundStyle(.purple.opacity(0.5))

            VStack(spacing: 8) {
                Text("No conversations yet")
                    .font(.title3.weight(.semibold))

                Text("Start a new chat or create a group")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: { showNewChat = true }) {
                Text("Start Messaging")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple.gradient)
                    .cornerRadius(25)
            }
        }
    }
}

// MARK: - Chat Row

struct ChatRowView: View {
    let chat: ChatInfo
    let currentUsername: String

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(chat.displayName(currentUsername: currentUsername).prefix(1)).uppercased())
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.purple)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.displayName(currentUsername: currentUsername))
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    if chat.lastMessageTime.timeIntervalSince1970 > 0 {
                        Text(formatTime(chat.lastMessageTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text(chat.lastMessageText.isEmpty ? "No messages yet" : chat.lastMessageText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: Date()) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date())!) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Chat Sheet

struct NewChatSheet: View {
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Text("Feature requires server-side user search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()

                Spacer()
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - New Group Sheet

struct NewGroupSheet: View {
    @ObservedObject var chatListViewModel: ChatListViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var groupName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Group name", text: $groupName)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Text("Select participants (requires server-side user list)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()

                Spacer()
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        chatListViewModel.createGroupChat(name: groupName, participants: [authViewModel.username])
                        dismiss()
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }
}
