import Foundation
import SwiftProtobuf
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import NIOCore
import NIOPosix
import OSLog

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Logger

private let logger = Logger(subsystem: "com.lavender.messenger", category: "GRPCManager")

// MARK: - Device Info

enum DeviceInfo {
    static var id: String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? "ios_\(UUID().uuidString)"
        #else
        return "ios_\(UUID().uuidString)"
        #endif
    }

    static var name: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "iOS Device"
        #endif
    }
}

// MARK: - GRPC Connection Manager

@available(iOS 18.0, *)
@MainActor
final class GRPCManager: ObservableObject {

    static let shared = GRPCManager()

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

    private var currentServerHost: String = ""
    private var currentServerPort: Int = 50051
    private var currentRoomId: String = ""
    private var currentUsername: String = ""
    private var currentPassword: String = ""
    private var currentUserId: String = ""
    private var currentDeviceId: String = ""
    private var currentDeviceName: String = ""
    private var isStreamAuthenticated: Bool = false

    private var grpcClient: GRPCClient<HTTP2ClientTransport.Posix>?
    private var eventLoopGroup: EventLoopGroup?
    private var chatTask: Task<Void, Never>?
    private var typingTask: Task<Void, Never>?
    private var typingContinuation: AsyncStream<Messenger_TypingRequest>.Continuation?
    private var reconnectTask: Task<Void, Never>?

    private var onMessageReceivedCallback: ((Message) -> Void)?
    private var avatarCache: [String: String] = [:]
    private var fullAvatarCache: [String: String] = [:]
    private var deletedMessageIds: Set<String> = []

    private init() {
        currentDeviceId = DeviceInfo.id
        currentDeviceName = DeviceInfo.name
    }

    deinit {
        chatTask?.cancel()
        typingTask?.cancel()
        reconnectTask?.cancel()
    }

    // MARK: - Connection

    func connect(serverAddress: String, useTLS: Bool = false, port: Int = 50051, forceReconnect: Bool = false) {
        if currentServerHost == serverAddress && currentServerPort == port && connectionStatus == .ready && !forceReconnect {
            return
        }
        reconnectTask?.cancel()
        currentServerHost = serverAddress
        currentServerPort = port
        connectionStatus = .connecting
        error = nil
        isSuperAdmin = false

        do {
            eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

            let transportSecurity: HTTP2ClientTransport.Posix.TransportSecurity
            if useTLS {
                transportSecurity = .tls(.defaults)
            } else {
                transportSecurity = .plaintext
            }

            let transport = try HTTP2ClientTransport.Posix(
                target: .ipv4(host: serverAddress, port: port),
                transportSecurity: transportSecurity,
                eventLoopGroup: eventLoopGroup!
            )

            grpcClient = GRPCClient(transport: transport)
            connectionStatus = .ready
            logger.info("Connected to \(serverAddress):\(port)")

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
        } catch {
            connectionStatus = .failed
            self.error = "Connection failed: \(error.localizedDescription)"
            logger.error("Connection failed: \(error.localizedDescription)")
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self = self, !Task.isCancelled else { return }
            Task { @MainActor in
                self.connect(serverAddress: self.currentServerHost, port: self.currentServerPort, forceReconnect: true)
            }
        }
    }

    func disconnect() {
        chatTask?.cancel()
        typingTask?.cancel()
        reconnectTask?.cancel()
        typingContinuation?.finish()
        typingContinuation = nil
        grpcClient?.beginGracefulShutdown()
        grpcClient = nil
        try? eventLoopGroup?.syncShutdownGracefully()
        eventLoopGroup = nil
        connectionStatus = .disconnected
        isStreamAuthenticated = false
        currentRoomId = ""
        messages = []
        typingUsers = [:]
        logger.info("Disconnected")
    }

    // MARK: - Chat Auth + Stream

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

        guard let client = grpcClient else {
            if !currentServerHost.isEmpty {
                connect(serverAddress: currentServerHost, port: currentServerPort)
            }
            return
        }
        chatTask?.cancel()

        let did = deviceId.isEmpty ? currentDeviceId : deviceId
        let dname = deviceName.isEmpty ? currentDeviceName : deviceName

        var authMsg = Messenger_Message()
        authMsg.user = currentUsername
        authMsg.password = password
        authMsg.text = joinMessage
        authMsg.roomID = currentRoomId
        authMsg.register = register
        authMsg.clientVersion = ClientVersion.string
        authMsg.deviceID = did
        authMsg.deviceName = dname
        authMsg.createdAt = Google_Protobuf_Timestamp(date: Date())

        let authMessage = authMsg
        let (stream, continuation) = AsyncStream<Messenger_Message>.makeStream()
        chatMessageStream = stream
        chatMessageContinuation = continuation

        chatTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.grpcClient!.bidirectionalStreaming(
                    request: StreamingClientRequest(of: Messenger_Message.self) { writer in
                        try await writer.write(authMessage)
                        for await message in stream {
                            try await writer.write(message)
                        }
                    },
                    descriptor: Messenger_ChatService.Method.Chat.descriptor,
                    serializer: ProtobufSerializer<Messenger_Message>(),
                    deserializer: ProtobufDeserializer<Messenger_Message>(),
                    options: .defaults
                ) { response in
                    for try await message in response.messages {
                        await self.handleIncomingProtoMessage(message)
                    }
                }
            } catch is CancellationError {
                logger.debug("Chat stream cancelled")
            } catch {
                logger.error("Chat stream error: \(error.localizedDescription)")
                Task { @MainActor in self.handleStreamError(error) }
            }
        }
        startTypingStream()
    }

    // MARK: - Message Sending

    func sendMessage(_ message: Message) {
        DispatchQueue.main.async { [weak self] in self?.messages.append(message) }
        sendProtoMessage(ProtoUtils.messageToProto(message))
    }

    func sendTextMessage(text: String, roomId: String, repliedToMessageId: String = "", repliedToUser: String = "", repliedToText: String = "") {
        sendMessage(Message(
            user: currentUsername,
            text: text,
            reactions: [],
            repliedToMessageId: repliedToMessageId,
            repliedToUser: repliedToUser,
            repliedToText: repliedToText,
            roomId: roomId,
            avatarUrl: avatarCache[currentUsername] ?? "",
            userId: currentUserId
        ))
    }

    private var chatMessageStream: AsyncStream<Messenger_Message>?
    private var chatMessageContinuation: AsyncStream<Messenger_Message>.Continuation?

    private func sendProtoMessage(_ protoMsg: Messenger_Message) {
        chatMessageContinuation?.yield(protoMsg)
    }

    // MARK: - Room Management

    func setRoomId(_ roomId: String) {
        currentRoomId = roomId
        guard isStreamAuthenticated else { return }
        var msg = Messenger_Message()
        msg.user = currentUsername
        msg.roomID = roomId
        msg.createdAt = Google_Protobuf_Timestamp(date: Date())
        msg.clientVersion = ClientVersion.string
        msg.deviceID = currentDeviceId
        msg.deviceName = currentDeviceName
        sendProtoMessage(msg)
    }

    func switchRoom(roomId: String) {
        currentRoomId = roomId
        setRoomId(roomId)
        messages = []
        loadHistory(roomId: roomId)
    }

    // MARK: - History

    func loadHistory(roomId: String, completion: @escaping () -> Void = {}) {
        guard let client = grpcClient else { completion(); return }
        var request = Messenger_GetHistoryRequest()
        request.limit = 100
        request.room = roomId
        Task {
            do {
                let response = try await client.unary(
                    request: ClientRequest(message: request),
                    descriptor: Messenger_ChatService.Method.GetHistory.descriptor,
                    serializer: ProtobufSerializer<Messenger_GetHistoryRequest>(),
                    deserializer: ProtobufDeserializer<Messenger_GetHistoryResponse>(),
                    options: .defaults
                ) { response in
                    return try? response.message.messages
                }
                for protoMsg in response {
                    await handleIncomingProtoMessage(protoMsg)
                }
            } catch {
                logger.error("Failed to load history: \(error.localizedDescription)")
            }
            completion()
        }
    }

    // MARK: - Read Receipts

    func markRead(roomId: String, username: String, completion: (() -> Void)? = nil) {
        guard let client = grpcClient else { completion?(); return }
        var request = Messenger_MarkReadRequest()
        request.roomID = roomId
        request.username = username
        request.userID = currentUserId
        Task {
            do {
                _ = try await client.unary(
                    request: ClientRequest(message: request),
                    descriptor: Messenger_ChatService.Method.MarkRead.descriptor,
                    serializer: ProtobufSerializer<Messenger_MarkReadRequest>(),
                    deserializer: ProtobufDeserializer<Messenger_MarkReadResponse>(),
                    options: .defaults
                ) { _ in () }
            } catch {
                logger.error("Failed to mark read: \(error.localizedDescription)")
            }
            completion?()
        }
    }

    // MARK: - Reactions

    func setReaction(messageId: String, username: String, emoji: String) {
        guard let client = grpcClient else { return }
        var reaction = Messenger_Reaction()
        reaction.user = username
        reaction.emoji = emoji
        var request = Messenger_ReactionRequest()
        request.messageID = messageId
        request.reaction = reaction
        Task {
            do {
                _ = try await client.unary(
                    request: ClientRequest(message: request),
                    descriptor: Messenger_ChatService.Method.SetReaction.descriptor,
                    serializer: ProtobufSerializer<Messenger_ReactionRequest>(),
                    deserializer: ProtobufDeserializer<Messenger_ReactionResponse>(),
                    options: .defaults
                ) { _ in () }
            } catch {
                logger.error("Failed to set reaction: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Typing Stream

    private func startTypingStream() {
        guard let client = grpcClient else { return }
        typingTask?.cancel()

        typingTask = Task { [weak self] in
            guard let self = self else { return }
            let (stream, continuation) = AsyncStream<Messenger_TypingRequest>.makeStream()
            self.typingContinuation = continuation

            do {
                try await self.grpcClient!.bidirectionalStreaming(
                    request: StreamingClientRequest(of: Messenger_TypingRequest.self) { writer in
                        for await typingReq in stream {
                            try await writer.write(typingReq)
                        }
                    },
                    descriptor: Messenger_ChatService.Method.Typing.descriptor,
                    serializer: ProtobufSerializer<Messenger_TypingRequest>(),
                    deserializer: ProtobufDeserializer<Messenger_TypingSignal>(),
                    options: .defaults
                ) { response in
                    for try await signal in response.messages {
                        await self.handleTypingSignal(signal)
                    }
                }
            } catch is CancellationError {
                logger.debug("Typing stream cancelled")
            } catch {
                logger.error("Typing stream error: \(error.localizedDescription)")
            }
        }
    }

    func sendTypingSignal(username: String, isTyping: Bool) {
        guard isStreamAuthenticated else { return }
        var req = Messenger_TypingRequest()
        req.roomID = currentRoomId
        req.username = username
        req.isTyping = isTyping
        req.userID = currentUserId
        typingContinuation?.yield(req)
    }

    // MARK: - Unary RPC Stubs

    func getChats(username: String, completion: @escaping ([ChatInfo]) -> Void) { completion([]) }
    func createDirectChat(user1: String, user2: String, completion: @escaping (String?) -> Void) { completion(nil) }
    func createGroupChat(name: String, participants: [String], creator: String, completion: @escaping (String?) -> Void) { completion(nil) }
    func loadUsers() {}
    func loadAllUsers(completion: @escaping ([Messenger_UserInfo]) -> Void = { _ in }) {}
    func updateAvatar(username: String, avatarUrl: String, fullAvatarUrl: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func updateProfile(username: String, bio: String, status: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func updateUsername(oldUsername: String, newUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func updatePassword(username: String, oldPassword: String, newPassword: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func deleteChat(chatId: String, requesterUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func addParticipant(chatId: String, username: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func removeParticipant(chatId: String, username: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func editMessage(messageId: String, text: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func deleteMessage(_ message: Message) { messages.removeAll { $0.id == message.id }; deletedMessageIds.insert(message.id) }
    func updateMessage(_ message: Message) { if let i = messages.firstIndex(where: { $0.id == message.id }) { messages[i] = message } }
    func clearMessages() { messages = [] }

    func saveDraft(roomId: String, draftText: String, repliedToMessageId: String = "", repliedToUser: String = "", repliedToText: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func getDraft(roomId: String, completion: @escaping (String, String, String, String, Bool) -> Void = { _, _, _, _, _ in }) {}
    func deleteDraft(roomId: String, completion: @escaping (Bool) -> Void = { _ in }) {}

    func getMutedChats(completion: @escaping ([String]) -> Void = { _ in }) {}
    func setMutedChat(roomId: String, muted: Bool, completion: @escaping (Bool) -> Void = { _ in }) {}

    func addFavorite(userId: String, messageId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func removeFavorite(userId: String, messageId: String, completion: @escaping (Bool) -> Void = { _ in }) {}
    func getFavorites(userId: String, completion: @escaping ([Message]) -> Void = { _ in }) {}

    func getDevices(userId: String, completion: @escaping ([DeviceInfo]) -> Void = { _ in }) {}
    func deleteDevice(userId: String, deviceId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func deleteOtherDevices(userId: String, currentDeviceId: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}

    func requestPasswordReset(email: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func resetPassword(token: String, newPassword: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}

    func getUserProfile(username: String, completion: @escaping (String, String, String, String) -> Void = { _, _, _, _ in }) {}
    func getUserAvatar(username: String, completion: @escaping (String) -> Void = { _ in }) {}

    func addContact(username: String, contactUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func removeContact(username: String, contactUsername: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func getContacts(username: String, completion: @escaping ([String]) -> Void = { _ in }) {}

    func getChatListVersion(username: String, completion: @escaping (Int64) -> Void = { _ in }) {}

    func registerToken(username: String, token: String, pushEnabled: Bool = true) {}

    func updateChatName(chatId: String, newName: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func updateChatAvatar(chatId: String, avatarUrl: String, username: String, fullAvatarUrl: String = "", completion: @escaping (Bool, String) -> Void = { _, _ in }) {}
    func updateChatSettings(chatId: String, allowMembersToAdd: Bool, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}

    func createSecretChat(targetUsername: String, publicKey: String, completion: @escaping (String, Bool, String, String) -> Void = { _, _, _, _ in }) {}
    func exchangeSecretKey(chatId: String, publicKey: String, completion: @escaping (Bool, String, Bool) -> Void = { _, _, _ in }) {}
    func getSecretChatKey(chatId: String, completion: @escaping (String, Bool) -> Void = { _, _ in }) {}

    func sendE2EEMessage(chatId: String, encryptedPayload: String) {
        guard isStreamAuthenticated else { return }
        var msg = Messenger_Message()
        msg.user = currentUsername
        msg.roomID = chatId
        msg.isE2Ee = true
        msg.e2EePayload = encryptedPayload
        msg.createdAt = Google_Protobuf_Timestamp(date: Date())
        sendProtoMessage(msg)
    }

    struct FCMLogEntry: Equatable {
        let timestamp: String
        let level: String
        let message: String
    }

    func getFCMLogs(completion: @escaping ([FCMLogEntry]) -> Void = { _ in }) {}

    func setUserId(_ userId: String) { currentUserId = userId }
    func getUserId() -> String { currentUserId }
    func fetchUserId(username: String, completion: @escaping (String?, Bool) -> Void = { _, _ in }) {}

    func deleteProfile(username: String, completion: @escaping (Bool, String) -> Void = { _, _ in }) {}

    func updateAvatarCache(username: String, avatarUrl: String, fullAvatarUrl: String = "") {
        avatarCache[username] = avatarUrl
        if !fullAvatarUrl.isEmpty { fullAvatarCache[username] = fullAvatarUrl }
    }
    func getAvatarCache() -> [String: String] { avatarCache }
    func getFullAvatarUrl(username: String) -> String? { fullAvatarCache[username] }
    func getCurrentUsername() -> String? { currentUsername.isEmpty ? nil : currentUsername }
    func clearSystemNotification() { systemNotification = nil }

    // MARK: - Incoming Message Handling

    private func handleIncomingProtoMessage(_ proto: Messenger_Message) async {
        await MainActor.run { self.processIncoming(proto) }
    }

    private func processIncoming(_ proto: Messenger_Message) {
        if proto.isSuperAdmin || proto.text == "SET_SUPER_ADMIN" {
            if !isSuperAdmin { isSuperAdmin = true }
        }
        if proto.text == "SET_SUPER_ADMIN" { return }

        if proto.text == "AUTH_FAILED" || proto.text == "USER_NOT_FOUND" || proto.text == "REGISTRATION_SUCCESS" {
            authStatus = proto.text
            if proto.text == "AUTH_FAILED" {
                isStreamAuthenticated = false
                connectionStatus = .failed
            }
            return
        }

        if proto.text.hasPrefix("SERVER_INFO:") {
            serverVersion = String(proto.text.dropFirst("SERVER_INFO:".count))
            isStreamAuthenticated = true
            return
        }

        if proto.text == "FORCE_LOGOUT" {
            authStatus = "FORCE_LOGOUT"
            disconnect()
            return
        }
        if proto.text.hasPrefix("FORCE_DISCONNECT:") {
            if String(proto.text.dropFirst("FORCE_DISCONNECT:".count)) == currentUsername { disconnect() }
            return
        }
        if proto.text.hasPrefix("FORCE_LOGOUT_EXCEPT:") {
            if String(proto.text.dropFirst("FORCE_LOGOUT_EXCEPT:".count)) != currentDeviceId {
                authStatus = "FORCE_LOGOUT"; disconnect()
            }
            return
        }
        if proto.text.hasPrefix("FORCE_DISCONNECT_DEVICE:") {
            if String(proto.text.dropFirst("FORCE_DISCONNECT_DEVICE:".count)) == currentDeviceId {
                authStatus = "FORCE_LOGOUT"; disconnect()
            }
            return
        }
        if proto.text.hasPrefix("SYSTEM_NOTIFICATION:") {
            systemNotification = String(proto.text.dropFirst("SYSTEM_NOTIFICATION:".count))
            return
        }
        if proto.text.hasPrefix("DELETE_MESSAGE:") {
            let id = String(proto.text.dropFirst("DELETE_MESSAGE:".count))
            deletedMessageIds.insert(id)
            messages.removeAll { $0.id == id }
            return
        }
        if proto.text.hasPrefix("CHAT_DELETED:") {
            chatDeletedEvent = String(proto.text.dropFirst("CHAT_DELETED:".count))
            return
        }
        if proto.text.hasPrefix("READ_ALL:") {
            if proto.roomID.isEmpty || proto.roomID == currentRoomId {
                for i in messages.indices {
                    messages[i] = Message(
                        id: messages[i].id, user: messages[i].user, text: messages[i].text,
                        timestamp: messages[i].timestamp, reactions: messages[i].reactions,
                        repliedToMessageId: messages[i].repliedToMessageId, repliedToUser: messages[i].repliedToUser,
                        repliedToText: messages[i].repliedToText, roomId: messages[i].roomId,
                        isRead: true, avatarUrl: messages[i].avatarUrl, imageUrl: messages[i].imageUrl,
                        imageUrls: messages[i].imageUrls, edited: messages[i].edited,
                        isSuperAdmin: messages[i].isSuperAdmin, voiceUrl: messages[i].voiceUrl,
                        duration: messages[i].duration, userId: messages[i].userId,
                        isE2EE: messages[i].isE2EE, e2eePayload: messages[i].e2eePayload
                    )
                }
            }
            return
        }
        if proto.text.hasPrefix("CLEAR_CACHE:") {
            if String(proto.text.dropFirst("CLEAR_CACHE:".count)) == currentRoomId { messages = [] }
            return
        }
        if proto.text.hasPrefix("ONLINE_USERS_UPDATE:") {
            let json = String(proto.text.dropFirst("ONLINE_USERS_UPDATE:".count))
            if let data = json.data(using: .utf8),
               let users = try? JSONDecoder().decode([String].self, from: data) {
                onlineUsers = users
            }
            return
        }

        let message = ProtoUtils.protoToMessage(proto)
        if deletedMessageIds.contains(message.id) {
            deletedMessageIds.remove(message.id)
            return
        }
        messages.append(message)
        onMessageReceivedCallback?(message)
    }

    // MARK: - Typing Signal

    private func handleTypingSignal(_ signal: Messenger_TypingSignal) async {
        await MainActor.run {
            let roomId = signal.roomID
            let username = signal.username
            if signal.isTyping {
                var users = self.typingUsers[roomId] ?? Set<String>()
                users.insert(username)
                self.typingUsers[roomId] = users
            } else {
                var users = self.typingUsers[roomId] ?? Set<String>()
                users.remove(username)
                if users.isEmpty {
                    self.typingUsers.removeValue(forKey: roomId)
                } else {
                    self.typingUsers[roomId] = users
                }
            }
        }
    }

    // MARK: - Stream Error

    private func handleStreamError(_ error: Error) {
        connectionStatus = .failed
        self.error = "Stream error: \(error.localizedDescription)"
        isStreamAuthenticated = false
        logger.error("Stream error: \(error.localizedDescription)")
        scheduleReconnect()
    }
}
