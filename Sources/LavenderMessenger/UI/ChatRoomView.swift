import SwiftUI

// MARK: - ChatRoomView

/// Main chat screen displaying messages, input field, and message actions.
/// Supports text messages, image messages, replies, reactions, and voice messages.
struct ChatRoomView: View {
    let chatId: String
    let chatName: String
    let username: String

    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showChatInfo: Bool = false
    @FocusState private var isInputFocused: Bool

    init(chatId: String, chatName: String, username: String) {
        self.chatId = chatId
        self.chatName = chatName
        self.username = username
        _viewModel = StateObject(wrappedValue: ChatViewModel(roomId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            messagesScrollView

            // Typing indicator
            if !viewModel.typingText.isEmpty {
                typingIndicator
            }

            // Reply preview
            if let replyMsg = viewModel.replyingToMessage {
                replyPreview(replyMsg)
            }

            // Input area
            inputArea
        }
        .navigationTitle(chatName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChatInfo = true }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .onAppear {
            viewModel.setCurrentUsername(username)
            viewModel.markAsRead()
        }
        .onDisappear {
            viewModel.saveDraft()
        }
        .sheet(isPresented: $showChatInfo) {
            ChatInfoView(chatId: chatId, chatName: chatName, username: username)
        }
        .sheet(isPresented: $viewModel.showImageViewer) {
            if !viewModel.viewerImageUrl.isEmpty {
                ImageViewerSheet(imageUrl: viewModel.viewerImageUrl)
            }
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .padding()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isCurrentUser: message.user == username,
                            onReply: { viewModel.startReply(to: message) },
                            onReaction: { emoji in viewModel.setReaction(messageId: message.id, emoji: emoji) },
                            onDelete: { viewModel.deleteMessage(message) },
                            onImageTap: { url in
                                viewModel.viewerImageUrl = url
                                viewModel.showImageViewer = true
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                // Auto-scroll to bottom on new message
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(i) * 0.2),
                            value: viewModel.typingText
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(16)

            Spacer()
        }
        .padding(.horizontal, 12)
        .transition(.opacity)
    }

    // MARK: - Reply Preview

    private func replyPreview(_ message: Message) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.purple)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.user)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)

                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: { viewModel.cancelReply() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input
            HStack(alignment: .bottom, spacing: 4) {
                TextField("Message...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: viewModel.inputText) { _, _ in
                        viewModel.onInputTextChanged()
                    }

                // Image picker button
                Button(action: { /* Image picker */ }) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            // Send button
            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color(.systemGray4)
                        : Color.purple
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let onReply: () -> Void
    let onReaction: (String) -> Void
    let onDelete: () -> Void
    let onImageTap: (String) -> Void

    @State private var showActions: Bool = false
    @State private var showReactionPicker: Bool = false

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 50) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (for non-current user)
                if !isCurrentUser {
                    Text(message.user)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }

                // Reply reference
                if !message.repliedToText.isEmpty {
                    HStack {
                        Rectangle()
                            .fill(isCurrentUser ? Color.white.opacity(0.5) : Color.purple.opacity(0.3))
                            .frame(width: 3)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(message.repliedToUser)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isCurrentUser ? .white.opacity(0.8) : .purple)
                            Text(message.repliedToText)
                                .font(.caption2)
                                .foregroundStyle(isCurrentUser ? .white.opacity(0.6) : .secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (isCurrentUser ? Color.white : Color.purple).opacity(0.15)
                    )
                    .cornerRadius(8)
                }

                // Message content
                VStack(alignment: .leading, spacing: 4) {
                    // Image
                    if !message.imageUrl.isEmpty {
                        AsyncImage(url: URL(string: message.imageUrl)) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 200, height: 150)
                                    .overlay(ProgressView())
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: 250)
                                    .cornerRadius(12)
                                    .clipped()
                                    .onTapGesture { onImageTap(message.imageUrl) }
                            case .failure:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                                    .frame(width: 200, height: 100)
                                    .overlay {
                                        VStack {
                                            Image(systemName: "exclamationmark.triangle")
                                            Text("Failed to load image")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.red)
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }

                    // Text content
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(isCurrentUser ? .white : .primary)
                    }

                    // Voice message indicator
                    if message.hasVoice {
                        HStack {
                            Image(systemName: "waveform")
                            Text("\(message.duration)s")
                                .font(.caption)
                        }
                        .foregroundStyle(isCurrentUser ? .white : .purple)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isCurrentUser
                    ? Color.purple.gradient
                    : Color(.systemGray5).gradient
                )
                .cornerRadius(18, corners: isCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])

                // Reactions
                if !message.reactions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(message.reactions) { reaction in
                                Button(action: { onReaction(reaction.emoji) }) {
                                    HStack(spacing: 2) {
                                        Text(reaction.emoji)
                                        if message.reactions.filter({ $0.emoji == reaction.emoji }).count > 1 {
                                            Text("\(message.reactions.filter { $0.emoji == reaction.emoji }.count)")
                                                .font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Time + edited + read status
                HStack(spacing: 4) {
                    if message.edited {
                        Text("(edited)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isCurrentUser {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(message.isRead ? .blue : .secondary.opacity(0.5))
                    }
                }
            }
            .contextMenu {
                Button(action: onReply) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }

                Button(action: { onReaction("👍") }) {
                    Label("Like", systemImage: "hand.thumbsup")
                }

                if isCurrentUser {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onLongPressGesture {
                showReactionPicker = true
            }
            .sheet(isPresented: $showReactionPicker) {
                ReactionPickerView(onSelect: { emoji in
                    onReaction(emoji)
                    showReactionPicker = false
                })
            }

            if !isCurrentUser { Spacer(minLength: 50) }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Reaction Picker

struct ReactionPickerView: View {
    let onSelect: (String) -> Void

    private let emojis = ["👍", "👎", "❤️", "😂", "😮", "😢", "🔥", "🎉", "🙏", "💪"]

    var body: some View {
        VStack(spacing: 20) {
            Text("React")
                .font(.headline)
                .padding(.top)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { onSelect(emoji) }) {
                        Text(emoji)
                            .font(.system(size: 32))
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.height(180)])
    }
}

// MARK: - Chat Info View

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

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("Failed to load image")
                        }
                        .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - ContactsView

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

// MARK: - SettingsView

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
                        Text("1.1.0.0")
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

// MARK: - EditProfileView

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
                Button("Save") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - SecurityView

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

// MARK: - NotificationsView

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

// MARK: - AppearanceView

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

// MARK: - ChatRoomView Preview

#Preview {
    NavigationStack {
        ChatRoomView(
            chatId: "general",
            chatName: "General",
            username: "test_user"
        )
    }
}
