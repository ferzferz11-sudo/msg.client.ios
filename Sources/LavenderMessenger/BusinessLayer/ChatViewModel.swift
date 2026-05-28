import Foundation
import SwiftUI
import Combine

// MARK: - ChatViewModel

/// Manages the chat state for a specific room.
/// Handles message list, sending messages, typing indicators, and history loading.
/// Mirrors Android's ChatViewModel.
@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [Message] = []
    @Published var currentRoomId: String = "general"
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var systemNotification: String? = nil
    @Published var typingText: String = ""
    @Published var isTyping: Bool = false
    @Published var inputText: String = ""
    @Published var showImageViewer: Bool = false
    @Published var viewerImageUrl: String = ""

    // Reply state
    @Published var replyingToMessage: Message? = nil

    // MARK: - Dependencies

    private let grpcManager = GRPCManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private var currentUsername: String = ""

    // MARK: - Init

    init(roomId: String = "general") {
        self.currentRoomId = roomId

        // Observe messages
        grpcManager.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                guard let self = self else { return }
                self.messages = msgs.filter { $0.roomId == self.currentRoomId || self.currentRoomId.isEmpty }
            }
            .store(in: &cancellables)

        // Observe typing users
        grpcManager.$typingUsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] typingUsers in
                self?.updateTypingText(typingUsers)
            }
            .store(in: &cancellables)

        // Observe connection state
        grpcManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .ready {
                    self?.loadHistory()
                }
            }
            .store(in: &cancellables)

        // Observe errors
        grpcManager.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error
            }
            .store(in: &cancellables)

        // Observe system notifications
        grpcManager.$systemNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.systemNotification = notification
            }
            .store(in: &cancellables)

        // Observe chat deleted events
        grpcManager.$chatDeletedEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chatId in
                if chatId == self?.currentRoomId {
                    self?.messages = []
                    self?.error = "This chat has been deleted"
                }
            }
            .store(in: &cancellables)

        // Restore draft
        restoreDraft()
    }

    // MARK: - Room Switching

    func switchRoom(to roomId: String) {
        saveDraft()

        // Mark current room as read
        if !currentRoomId.isEmpty && !currentUsername.isEmpty {
            grpcManager.markRead(roomId: currentRoomId, username: currentUsername)
        }

        currentRoomId = roomId
        grpcManager.switchRoom(roomId: roomId)
        loadHistory()
        restoreDraft()
    }

    // MARK: - Send Message

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !currentRoomId.isEmpty else { return }

        let repliedId = replyingToMessage?.id ?? ""
        let repliedUser = replyingToMessage?.user ?? ""
        let repliedText = replyingToMessage?.text ?? ""

        // Check for E2EE
        // In a real app, we'd check if this is a secret chat
        grpcManager.sendTextMessage(
            text: trimmed,
            roomId: currentRoomId,
            repliedToMessageId: repliedId,
            repliedToUser: repliedUser,
            repliedToText: repliedText
        )

        inputText = ""
        replyingToMessage = nil
        sendTypingSignal(isTyping: false)
        saveDraft()
    }

    func sendImageMessage(imageUrl: String, text: String = "") {
        guard !currentRoomId.isEmpty else { return }

        let msg = Message(
            user: currentUsername,
            text: text,
            roomId: currentRoomId,
            imageUrl: imageUrl
        )
        grpcManager.sendMessage(msg)
    }

    // MARK: - Message Actions

    func deleteMessage(_ message: Message) {
        grpcManager.deleteMessage(message)
    }

    func editMessage(_ messageId: String, newText: String) {
        grpcManager.editMessage(messageId: messageId, text: newText)
    }

    func setReaction(messageId: String, emoji: String) {
        guard !currentUsername.isEmpty else { return }
        grpcManager.setReaction(messageId: messageId, username: currentUsername, emoji: emoji)
    }

    func startReply(to message: Message) {
        replyingToMessage = message
    }

    func cancelReply() {
        replyingToMessage = nil
    }

    // MARK: - Typing

    func sendTypingSignal(isTyping: Bool) {
        guard !currentUsername.isEmpty else { return }
        grpcManager.sendTypingSignal(username: currentUsername, isTyping: isTyping)
    }

    func onInputTextChanged() {
        if !isTyping && !inputText.isEmpty {
            isTyping = true
            sendTypingSignal(isTyping: true)
        }

        // Reset typing timer
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isTyping = false
                self?.sendTypingSignal(isTyping: false)
            }
        }
    }

    // MARK: - History

    func loadHistory() {
        isLoading = true
        grpcManager.loadHistory(roomId: currentRoomId) { [weak self] in
            Task { @MainActor in
                self?.isLoading = false
            }
        }
    }

    func markAsRead() {
        guard !currentRoomId.isEmpty && !currentUsername.isEmpty else { return }
        grpcManager.markRead(roomId: currentRoomId, username: currentUsername)
    }

    // MARK: - Draft

    func saveDraft() {
        let repliedId = replyingToMessage?.id ?? ""
        let repliedUser = replyingToMessage?.user ?? ""
        let repliedText = replyingToMessage?.text ?? ""

        grpcManager.saveDraft(
            roomId: currentRoomId,
            draftText: inputText,
            repliedToMessageId: repliedId,
            repliedToUser: repliedUser,
            repliedToText: repliedText
        )
    }

    func restoreDraft() {
        grpcManager.getDraft(roomId: currentRoomId) { [weak self] draftText, repliedToMessageId, repliedToUser, repliedToText, hasDraft in
            Task { @MainActor in
                if hasDraft {
                    self?.inputText = draftText
                    if !repliedToMessageId.isEmpty {
                        // Find the message being replied to
                        if let msg = self?.messages.first(where: { $0.id == repliedToMessageId }) {
                            self?.replyingToMessage = msg
                        }
                    }
                }
            }
        }
    }

    func clearDraft() {
        grpcManager.deleteDraft(roomId: currentRoomId)
    }

    // MARK: - Helpers

    private func updateTypingText(_ typingUsers: [String: Set<String>]) {
        guard let users = typingUsers[currentRoomId], !users.isEmpty else {
            typingText = ""
            return
        }

        let filteredUsers = users.filter { $0 != currentUsername }
        if filteredUsers.isEmpty {
            typingText = ""
        } else if filteredUsers.count == 1 {
            typingText = "\(filteredUsers.first!) is typing..."
        } else if filteredUsers.count == 2 {
            let names = filteredUsers.sorted().joined(separator: " and ")
            typingText = "\(names) are typing..."
        } else {
            typingText = "\(filteredUsers.count) people are typing..."
        }
    }

    func setCurrentUsername(_ username: String) {
        currentUsername = username
    }

    func clearSystemNotification() {
        grpcManager.clearSystemNotification()
    }

    // MARK: - Cleanup

    deinit {
        typingTimer?.invalidate()
    }
}

// MARK: - ChatListViewModel

/// Manages the list of chats for the home screen.
@MainActor
final class ChatListViewModel: ObservableObject {

    @Published var chats: [ChatInfo] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    @Published var showCreateChat: Bool = false
    @Published var showNewGroup: Bool = false

    private let grpcManager = GRPCManager.shared
    private var currentUsername: String = ""

    func loadChats(username: String) {
        currentUsername = username
        isLoading = true
        grpcManager.getChats(username: username) { [weak self] chats in
            Task { @MainActor in
                self?.chats = chats
                self?.isLoading = false
            }
        }
    }

    func createDirectChat(with username: String) {
        guard !currentUsername.isEmpty else { return }
        grpcManager.createDirectChat(user1: currentUsername, user2: username) { [weak self] chatId in
            if let chatId = chatId {
                self?.loadChats(username: self?.currentUsername ?? "")
            }
        }
    }

    func createGroupChat(name: String, participants: [String]) {
        guard !currentUsername.isEmpty else { return }
        grpcManager.createGroupChat(name: name, participants: participants, creator: currentUsername) { [weak self] chatId in
            if let chatId = chatId {
                self?.loadChats(username: self?.currentUsername ?? "")
            }
        }
    }

    func deleteChat(chatId: String) {
        guard !currentUsername.isEmpty else { return }
        grpcManager.deleteChat(chatId: chatId, requesterUsername: currentUsername) { [weak self] success, message in
            if success {
                self?.chats.removeAll { $0.id == chatId }
            }
        }
    }
}
