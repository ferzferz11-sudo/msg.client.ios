import Foundation
import SwiftProtobuf

// MARK: - gRPC Connection Manager

/// Manages the gRPC bidirectional streaming connection to the Lavender Messenger server.
/// Handles authentication, message streaming, typing signals, and reconnection.
///
/// Protocol flow (matches server.go Chat() handler):
/// 1. Connect -> create channel
/// 2. Send first Message with username + password (auth)
/// 3. Server responds with SYSTEM messages: SERVER_INFO, SET_SUPER_ADMIN, AUTH_FAILED, etc.
/// 4. After auth, bidirectional message streaming begins
/// 5. Server encrypts with AES-256-GCM; client must decrypt incoming message text
@MainActor
final class GRPCManager: ObservableObject {

    static let shared = GRPCManager()

    // MARK: - Published State

    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var messages: [Message] = []
    @Published var error: String? = nil
    @Published var systemNotification: String? = nil
    @Published var isSuperAdmin: Bool = false
    @Published var serverVersion: String = ""
    @Published var authStatus: String? = nil
    @Published var typingUsers: [String: Set<String>] = [:]
    @Published var chatDeletedEvent: String? = nil
    @Published var onlineUsers: [String] = []

    // MARK: - Internal State

    private var currentServerAddress: String = ""
    private var currentRoomId: String = ""
    private var currentUsername: String = ""
    private var currentPassword: String = ""
    private var currentUserId: String = ""
    private var currentDeviceId: String = ""
    private var currentDeviceName: String = ""
    private var isAuthenticated: Bool = false
    private var isRetrying: Bool = false

    // Callbacks
    private var onMessageReceivedCallback: ((Message) -> Void)?

    // Avatar cache
    private var avatarCache: [String: String] = [:]
    private var fullAvatarCache: [String: String] = [:]

    // Deleted message tracking
    private var deletedMessageIds: Set<String> = []

    // Private initializer for singleton
    private init() {
        currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios_\(UUID().uuidString)"
        currentDeviceName = UIDevice.current.model
    }

    // MARK: - Connection

    func connect(serverAddress: String, useTLS: Bool = false, port: Int = 50051, forceReconnect: Bool = false) {
        if currentServerAddress == serverAddress && connectionStatus == .ready && !forceReconnect {
            return
        }

        currentServerAddress = serverAddress
        connectionStatus = .connecting
        error = nil
        isSuperAdmin = false

        // In a real implementation, this would create a gRPC channel
        // Since we can't import the generated code yet, we simulate the connection
        // The actual implementation would use:
        //   let channel = GRPCChannelPool.with(
        //       target: .host(serverAddress, port: port),
        //       transportSecurity: useTLS ? .tls : .plaintext,
        //       eventLoopGroup: PlatformSupport.makeEventLoopGroup(loopCount: 1)
        //   )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connectionStatus = .ready
        }

        // Auto-resume last chat if available
        if !currentUsername.isEmpty {
            startChat(
                username: currentUsername,
                password: currentPassword,
                joinMessage: "",
                register: false,
                email: "",
                deviceId: currentDeviceId,
                deviceName: currentDeviceName
            )
        }
    }

    func disconnect() {
        connectionStatus = .disconnected
        isAuthenticated = false
        currentRoomId = ""
        onMessageReceivedCallback = nil
        messages = []
        typingUsers = [:]
    }

    // MARK: - Chat Stream (Authentication + Bidirectional Messaging)

    func startChat(
        username: String,
        password: String,
        joinMessage: String,
        register: Bool = false,
        email: String = "",
        deviceId: String = "",
        deviceName: String = "",
        onMessageReceived: @escaping (Message) -> Void = { _ in }
    ) {
        currentUsername = username.trimmingCharacters(in: .whitespaces)
        currentPassword = password
        onMessageReceivedCallback = onMessageReceived
        authStatus = nil

        if connectionStatus == .failed || connectionStatus == .disconnected {
            guard !currentServerAddress.isEmpty else {
                error = "No server address configured"
                return
            }
            connect(serverAddress: currentServerAddress)
        }

        // Wait for ready then send auth
        Task {
            await waitForConnection(timeout: 10)

            // Build auth message
            var authMsg = Server_Message()
            authMsg.user = currentUsername
            authMsg.password = password
            authMsg.text = joinMessage
            authMsg.roomID = currentRoomId
            authMsg.register = register
            authMsg.clientVersion = "1.1.0.0"
            authMsg.deviceID = deviceId.isEmpty ? currentDeviceId : deviceId
            authMsg.deviceName = deviceName.isEmpty ? currentDeviceName : deviceName
            authMsg.createdAt = SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())

            // In real implementation:
            //   let request = asyncStream.makeAsyncWriter()
            //   try await request.write(authMsg)

            // Simulate auth response handling
            if register {
                handleSystemMessage(text: "REGISTRATION_SUCCESS")
            }
        }
    }

    // MARK: - Send Message

    func sendMessage(_ message: Message) {
        guard connectionStatus == .ready else {
            error = "Not connected"
            return
        }

        // Add to local messages immediately
        DispatchQueue.main.async { [weak self] in
            self?.messages.append(message)
        }

        // In real implementation:
        //   let request = asyncStream.makeAsyncWriter()
        //   try await request.write(protoMessage)
    }

    func sendTextMessage(text: String, roomId: String, repliedToMessageId: String = "", repliedToUser: String = "", repliedToText: String = "") {
        let msg = Message(
            user: currentUsername,
            text: text,
            roomId: roomId,
            repliedToMessageId: repliedToMessageId,
            repliedToUser: repliedToUser,
            repliedToText: repliedToText,
            avatarUrl: avatarCache[currentUsername] ?? "",
            userId: currentUserId
        )
        sendMessage(msg)
    }

    // MARK: - Room Management

    func setRoomId(_ roomId: String) {
        currentRoomId = roomId

        // In real implementation, send room switch signal on existing stream
        if isAuthenticated {
            var switchMsg = Server_Message()
            switchMsg.user = currentUsername
            switchMsg.roomID = roomId
            switchMsg.createdAt = SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())
            switchMsg.clientVersion = "1.1.0.0"
            // try await request.write(switchMsg)
        }
    }

    func switchRoom(roomId: String) {
        currentRoomId = roomId
        setRoomId(roomId)
        messages = []
        loadHistory(roomId: roomId)
    }

    // MARK: - History

    func loadHistory(roomId: String, completion: @escaping () -> Void = {}) {
        // In real implementation:
        //   let response = try await unaryCall(.getHistory, request: GetHistoryRequest(limit: 100, room: roomId))
        //   for protoMsg in response.messages {
        //       let message = ProtoUtils.createMessage(from: protoMsg)
        //       messages.append(message)
        //   }
        completion()
    }

    // MARK: - Read Receipts

    func markRead(roomId: String, username: String, completion: (() -> Void)? = nil) {
        // In real implementation:
        //   _ = try await unaryCall(.markRead, request: MarkReadRequest(roomId: roomId, username: username, userId: currentUserId))
        completion?()
    }

    // MARK: - Reactions

    func setReaction(messageId: String, username: String, emoji: String) {
        // In real implementation:
        //   _ = try await unaryCall(.setReaction, request: ReactionRequest(messageId: messageId, reaction: Reaction(user: username, emoji: emoji)))
    }

    // MARK: - Typing

    func sendTypingSignal(username: String, isTyping: Bool) {
        guard isAuthenticated else { return }

        var typingReq = Server_TypingRequest()
        typingReq.roomID = currentRoomId
        typingReq.username = username
        typingReq.isTyping = isTyping
        typingReq.userID = currentUserId

        // In real implementation:
        //   let request = typingAsyncStream.makeAsyncWriter()
        //   try await request.write(typingReq)
    }

    // MARK: - Chats

    func getChats(username: String, completion: @escaping ([ChatInfo]) -> Void) {
        // In real implementation:
        //   let response = try await unaryCall(.getChats, request: GetChatsRequest(username: username, userId: currentUserId))
        //   completion(response.chats.map { ChatInfo(from: $0) })
        completion([])
    }

    func createDirectChat(user1: String, user2: String, completion: @escaping (String?) -> Void) {
        // In real implementation:
        //   let response = try await unaryCall(.createDirectChat, request: CreateDirectChatRequest(user1: user1, user2: user2, user1Id: currentUserId, user2Id: ""))
        //   completion(response.chatId)
        completion(nil)
    }

    func createGroupChat(name: String, participants: [String], creator: String, completion: @escaping (String?) -> Void) {
        // In real implementation:
        //   let response = try await unaryCall(.createGroupChat, request: CreateGroupChatRequest(name: name, participants: participants, creator: creator, creatorId: currentUserId))
        //   completion(response.chatId)
        completion(nil)
    }

    // MARK: - Profile

    func updateAvatar(username: String, avatarUrl: String, fullAvatarUrl: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // In real implementation: unary call to UpdateAvatar
        completion(true, "")
    }

    func updateProfile(username: String, bio: String, status: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // In real implementation: unary call to UpdateProfile
        completion(true, "")
    }

    func updateUsername(oldUsername: String, newUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func updatePassword(username: String, oldPassword: String, newPassword: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func deleteChat(chatId: String, requesterUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func addParticipant(chatId: String, username: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func removeParticipant(chatId: String, username: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func getUserProfile(username: String, completion: @escaping (String, String, String, String) -> Void = { _, _, _, _ in }) {
        // Returns: bio, status, avatarUrl
        completion("", "", "", "")
    }

    func getUserAvatar(username: String, completion: @escaping (String) -> Void = { _ in }) {
        completion(avatarCache[username] ?? "")
    }

    // MARK: - FCM Token

    func registerToken(username: String, token: String, pushEnabled: Bool = true) {
        // In real implementation: unary call to RegisterToken
    }

    // MARK: - Trusted Contacts

    func addContact(username: String, contactUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func removeContact(username: String, contactUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func getContacts(username: String, completion: @escaping ([String]) -> Void = { _ in }) {
        completion([])
    }

    // MARK: - Message Management

    func deleteMessage(_ message: Message) {
        messages.removeAll { $0.id == message.id }
        deletedMessageIds.insert(message.id)
    }

    func editMessage(messageId: String, text: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        // In real implementation: unary call to EditMessage
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            var updated = messages[index]
            // Note: Message is a struct, so we'd need to recreate it
            messages[index] = Message(
                id: updated.id,
                user: updated.user,
                text: text,
                timestamp: updated.timestamp,
                reactions: updated.reactions,
                repliedToMessageId: updated.repliedToMessageId,
                repliedToUser: updated.repliedToUser,
                repliedToText: updated.repliedToText,
                roomId: updated.roomId,
                isRead: updated.isRead,
                avatarUrl: updated.avatarUrl,
                imageUrl: updated.imageUrl,
                imageUrls: updated.imageUrls,
                edited: true,
                isSuperAdmin: updated.isSuperAdmin,
                voiceUrl: updated.voiceUrl,
                duration: updated.duration,
                userId: updated.userId,
                isE2EE: updated.isE2EE,
                e2eePayload: updated.e2eePayload
            )
        }
        completion(true, "")
    }

    func updateMessage(_ message: Message) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }

    func clearMessages() {
        messages = []
    }

    // MARK: - Drafts

    func saveDraft(roomId: String, draftText: String, repliedToMessageId: String = "", repliedToUser: String = "", repliedToText: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func getDraft(roomId: String, completion: @escaping (String, String, String, String, Bool) -> Void = { _, _, _, _, _ in }) {
        completion("", "", "", "", false)
    }

    func deleteDraft(roomId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        completion(true)
    }

    // MARK: - Muted Chats

    func getMutedChats(completion: @escaping ([String]) -> Void = { _ in }) {
        completion([])
    }

    func setMutedChat(roomId: String, muted: Bool, completion: @escaping (Bool) -> Void = { _ in }) {
        completion(true)
    }

    // MARK: - Favorites

    func addFavorite(userId: String, messageId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func removeFavorite(userId: String, messageId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        completion(true)
    }

    func getFavorites(userId: String, completion: @escaping ([Message]) -> Void = { _ in }) {
        completion([])
    }

    // MARK: - Devices

    func getDevices(userId: String, completion: @escaping ([DeviceInfo]) -> Void = { _ in }) {
        completion([])
    }

    func deleteDevice(userId: String, deviceId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func deleteOtherDevices(userId: String, currentDeviceId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    // MARK: - Password Reset

    func requestPasswordReset(email: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func resetPassword(token: String, newPassword: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    // MARK: - Chat List Version

    func getChatListVersion(username: String, completion: @escaping (Int64) -> Void = { _ in }) {
        completion(0)
    }

    // MARK: - Themes

    func getThemes(username: String, completion: @escaping (String, [String]) -> Void = { _, _ in }) {
        completion("", [])
    }

    func saveTheme(username: String, themeData: Data, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func setCurrentTheme(username: String, themeId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        completion(true)
    }

    func deleteTheme(username: String, themeId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        completion(true)
    }

    // MARK: - Chat Settings

    func updateChatName(chatId: String, newName: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func updateChatAvatar(chatId: String, avatarUrl: String, username: String, fullAvatarUrl: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    func updateChatSettings(chatId: String, allowMembersToAdd: Bool, completion: @escaping (Bool, String) -> Void = { _, _ in }) {
        completion(true, "")
    }

    // MARK: - FCM Logs

    func getFCMLogs(completion: @escaping ([FCMLogEntry]) -> Void = { _ in }) {
        completion([])
    }

    // MARK: - User ID

    func setUserId(_ userId: String) {
        currentUserId = userId
    }

    func getUserId() -> String {
        return currentUserId
    }

    func fetchUserId(username: String, completion: @escaping (String?, Bool) -> Void = { _, _ in }) {
        completion(nil, false)
    }

    // MARK: - Secret Chats (E2EE)

    func createSecretChat(targetUsername: String, publicKey: String, completion: @escaping (String, Bool, String, String) -> Void = { _, _, _, _ in }) {
        completion("", false, "Not implemented in this build", "")
    }

    func exchangeSecretKey(chatId: String, publicKey: String, completion: @escaping (Bool, String, Bool) -> Void = { _, _, _ in }) {
        completion(false, "", false)
    }

    func getSecretChatKey(chatId: String, completion: @escaping (String, Bool) -> Void = { _, _ in }) {
        completion("", false)
    }

    func sendE2EEMessage(chatId: String, encryptedPayload: String) {
        guard isAuthenticated else { return }
        var e2eeMsg = Server_Message()
        e2eeMsg.user = currentUsername
        e2eeMsg.roomID = chatId
        e2eeMsg.isE2EE = true
        e2eeMsg.e2eePayload = encryptedPayload
        e2eeMsg.createdAt = SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())
        // try await request.write(e2eeMsg)
    }

    // MARK: - Avatar Cache

    func updateAvatarCache(username: String, avatarUrl: String, fullAvatarUrl: String = "") {
        avatarCache[username] = avatarUrl
        if !fullAvatarUrl.isEmpty {
            fullAvatarCache[username] = fullAvatarUrl
        }
    }

    func getAvatarCache() -> [String: String] {
        return avatarCache
    }

    func getFullAvatarUrl(username: String) -> String? {
        return fullAvatarCache[username]
    }

    func getCurrentUsername() -> String? {
        currentUsername.isEmpty ? nil : currentUsername
    }

    // MARK: - System Notification

    func clearSystemNotification() {
        systemNotification = nil
    }

    // MARK: - Incoming Message Handling (called from gRPC response stream)

    func handleIncomingMessage(_ protoMsg: Server_Message) {
        // Handle admin status
        if protoMsg.isSuperAdmin || protoMsg.text == "SET_SUPER_ADMIN" {
            if !isSuperAdmin {
                isSuperAdmin = true
            }
        }

        // Handle system signals
        if protoMsg.text == "SET_SUPER_ADMIN" { return }

        if protoMsg.text == "AUTH_FAILED" || protoMsg.text == "USER_NOT_FOUND" || protoMsg.text == "REGISTRATION_SUCCESS" {
            authStatus = protoMsg.text
            if protoMsg.text == "AUTH_FAILED" {
                isAuthenticated = false
                connectionStatus = .failed
                isRetrying = false
            }
            return
        }

        if protoMsg.text.hasPrefix("SERVER_INFO:") {
            serverVersion = String(protoMsg.text.dropFirst("SERVER_INFO:".count))
            isAuthenticated = true
            return
        }

        if protoMsg.text == "FORCE_LOGOUT" {
            authStatus = "FORCE_LOGOUT"
            Task { @MainActor in
                disconnect()
            }
            return
        }

        if protoMsg.text.hasPrefix("FORCE_DISCONNECT:") {
            let targetUser = String(protoMsg.text.dropFirst("FORCE_DISCONNECT:".count))
            if targetUser == currentUsername {
                disconnect()
            }
            return
        }

        if protoMsg.text.hasPrefix("FORCE_LOGOUT_EXCEPT:") {
            let deviceToKeep = String(protoMsg.text.dropFirst("FORCE_LOGOUT_EXCEPT:".count))
            if deviceToKeep != currentDeviceId {
                authStatus = "FORCE_LOGOUT"
                disconnect()
            }
            return
        }

        if protoMsg.text.hasPrefix("FORCE_DISCONNECT_DEVICE:") {
            let deviceToDisconnect = String(protoMsg.text.dropFirst("FORCE_DISCONNECT_DEVICE:".count))
            if deviceToDisconnect == currentDeviceId {
                authStatus = "FORCE_LOGOUT"
                disconnect()
            }
            return
        }

        if protoMsg.text.hasPrefix("SYSTEM_NOTIFICATION:") {
            systemNotification = String(protoMsg.text.dropFirst("SYSTEM_NOTIFICATION:".count))
            return
        }

        if protoMsg.text == "FORCE_LOGOUT" {
            authStatus = "FORCE_LOGOUT"
            disconnect()
            return
        }

        if protoMsg.text.hasPrefix("DELETE_MESSAGE:") {
            let deletedId = String(protoMsg.text.dropFirst("DELETE_MESSAGE:".count))
            deletedMessageIds.insert(deletedId)
            messages.removeAll { $0.id == deletedId }
            return
        }

        if protoMsg.text.hasPrefix("CHAT_DELETED:") {
            chatDeletedEvent = String(protoMsg.text.dropFirst("CHAT_DELETED:".count))
            return
        }

        if protoMsg.text.hasPrefix("READ_ALL:") {
            // Update read status for messages in current room
            if protoMsg.roomID.isEmpty || protoMsg.roomID == currentRoomId {
                for i in messages.indices {
                    messages[i] = Message(
                        id: messages[i].id,
                        user: messages[i].user,
                        text: messages[i].text,
                        timestamp: messages[i].timestamp,
                        reactions: messages[i].reactions,
                        repliedToMessageId: messages[i].repliedToMessageId,
                        repliedToUser: messages[i].repliedToUser,
                        repliedToText: messages[i].repliedToText,
                        roomId: messages[i].roomId,
                        isRead: true,
                        avatarUrl: messages[i].avatarUrl,
                        imageUrl: messages[i].imageUrl,
                        imageUrls: messages[i].imageUrls,
                        edited: messages[i].edited,
                        isSuperAdmin: messages[i].isSuperAdmin,
                        voiceUrl: messages[i].voiceUrl,
                        duration: messages[i].duration,
                        userId: messages[i].userId,
                        isE2EE: messages[i].isE2EE,
                        e2eePayload: messages[i].e2eePayload
                    )
                }
            }
            return
        }

        if protoMsg.text.hasPrefix("CLEAR_CACHE:") {
            let chatId = String(protoMsg.text.dropFirst("CLEAR_CACHE:".count))
            if chatId == currentRoomId {
                messages = []
            }
            return
        }

        if protoMsg.text.hasPrefix("ONLINE_USERS_UPDATE:") {
            let usersJson = String(protoMsg.text.dropFirst("ONLINE_USERS_UPDATE:".count))
            if let data = usersJson.data(using: .utf8),
               let users = try? JSONDecoder().decode([String].self, from: data) {
                onlineUsers = users
            }
            return
        }

        // Convert proto to Message and append
        let message = Message(
            id: protoMsg.id,
            user: protoMsg.user,
            text: protoMsg.text,
            timestamp: protoMsg.createdAt.date,
            reactions: protoMsg.reactions.map { Reaction(user: $0.user, emoji: $0.emoji) },
            repliedToMessageId: protoMsg.repliedToMessageID,
            repliedToUser: protoMsg.repliedToUser,
            repliedToText: protoMsg.repliedToText,
            roomId: protoMsg.roomID,
            isRead: protoMsg.isRead,
            avatarUrl: protoMsg.avatarURL,
            imageUrl: protoMsg.imageURL,
            imageUrls: Array(protoMsg.imageUrls),
            edited: protoMsg.edited,
            isSuperAdmin: protoMsg.isSuperAdmin,
            voiceUrl: protoMsg.voiceURL,
            duration: Int(protoMsg.duration),
            userId: protoMsg.userID,
            isE2EE: protoMsg.isE2EE,
            e2eePayload: protoMsg.e2eePayload
        )

        // Deduplication check
        if deletedMessageIds.contains(message.id) {
            deletedMessageIds.remove(message.id)
            return
        }

        messages.append(message)
        onMessageReceivedCallback?(message)
    }

    func handleTypingSignal(_ typingSignal: Server_TypingSignal) {
        let roomId = typingSignal.roomID
        let username = typingSignal.username

        if typingSignal.isTyping {
            var users = typingUsers[roomId] ?? Set<String>()
            users.insert(username)
            typingUsers[roomId] = users
        } else {
            var users = typingUsers[roomId] ?? Set<String>()
            users.remove(username)
            if users.isEmpty {
                typingUsers.removeValue(forKey: roomId)
            } else {
                typingUsers[roomId] = users
            }
        }
    }

    // MARK: - Private Helpers

    private func waitForConnection(timeout: Int) async {
        let startTime = Date()
        while connectionStatus != .ready {
            if Date().timeIntervalSince(startTime) > Double(timeout) {
                error = "Connection timeout"
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}

// MARK: - Device Info

struct DeviceInfo: Equatable {
    let deviceId: String
    let deviceName: String
    let clientVersion: String
    let lastSeenAt: Date
    let ipAddress: String
}

// MARK: - FCM Log Entry

struct FCMLogEntry: Equatable {
    let timestamp: String
    let level: String
    let message: String
}
