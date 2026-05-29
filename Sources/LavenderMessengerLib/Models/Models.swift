import Foundation

// MARK: - Reaction

struct Reaction: Identifiable, Equatable, Hashable {
    var id: String { "\(user):\(emoji)" }
    let user: String
    let emoji: String
}

// MARK: - Message

struct Message: Identifiable, Equatable {
    let id: String
    let user: String
    let text: String
    let timestamp: Date
    let reactions: [Reaction]
    let repliedToMessageId: String
    let repliedToUser: String
    let repliedToText: String
    let roomId: String
    let isRead: Bool
    let avatarUrl: String
    let imageUrl: String
    let imageUrls: [String]
    let edited: Bool
    let isSuperAdmin: Bool
    let voiceUrl: String
    let duration: Int
    let userId: String
    let isE2EE: Bool
    let e2eePayload: String

    init(
        id: String = UUID().uuidString,
        user: String,
        text: String,
        timestamp: Date = Date(),
        reactions: [Reaction] = [],
        repliedToMessageId: String = "",
        repliedToUser: String = "",
        repliedToText: String = "",
        roomId: String = "",
        isRead: Bool = false,
        avatarUrl: String = "",
        imageUrl: String = "",
        imageUrls: [String] = [],
        edited: Bool = false,
        isSuperAdmin: Bool = false,
        voiceUrl: String = "",
        duration: Int = 0,
        userId: String = "",
        isE2EE: Bool = false,
        e2eePayload: String = ""
    ) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.reactions = reactions
        self.repliedToMessageId = repliedToMessageId
        self.repliedToUser = repliedToUser
        self.repliedToText = repliedToText
        self.roomId = roomId
        self.isRead = isRead
        self.avatarUrl = avatarUrl
        self.imageUrl = imageUrl
        self.imageUrls = imageUrls
        self.edited = edited
        self.isSuperAdmin = isSuperAdmin
        self.voiceUrl = voiceUrl
        self.duration = duration
        self.userId = userId
        self.isE2EE = isE2EE
        self.e2eePayload = e2eePayload
    }

    var isSystem: Bool {
        user == "SYSTEM"
    }

    var systemCommand: SystemCommand? {
        guard isSystem else { return nil }
        return SystemCommand(from: text)
    }

    var hasImage: Bool {
        !imageUrl.isEmpty || !imageUrls.isEmpty
    }

    var hasVoice: Bool {
        !voiceUrl.isEmpty
    }

    var displayAvatarUrl: String {
        avatarUrl.isEmpty ? "" : avatarUrl
    }
}

// MARK: - System Commands

enum SystemCommand: String {
    case authFailed = "AUTH_FAILED"
    case userNotFound = "USER_NOT_FOUND"
    case registrationSuccess = "REGISTRATION_SUCCESS"
    case emailAlreadyInUse = "EMAIL_ALREADY_IN_USE"
    case forceLogout = "FORCE_LOGOUT"
    case setSuperAdmin = "SET_SUPER_ADMIN"

    static func parseServerInfo(_ text: String) -> String? {
        guard text.hasPrefix("SERVER_INFO:") else { return nil }
        return String(text.dropFirst("SERVER_INFO:".count))
    }

    static func parseSystemNotification(_ text: String) -> String? {
        guard text.hasPrefix("SYSTEM_NOTIFICATION:") else { return nil }
        return String(text.dropFirst("SYSTEM_NOTIFICATION:".count))
    }

    static func parseChatDeleted(_ text: String) -> String? {
        guard text.hasPrefix("CHAT_DELETED:") else { return nil }
        return String(text.dropFirst("CHAT_DELETED:".count))
    }

    static func parseDeleteMessage(_ text: String) -> String? {
        guard text.hasPrefix("DELETE_MESSAGE:") else { return nil }
        return String(text.dropFirst("DELETE_MESSAGE:".count))
    }

    static func parseForceDisconnect(_ text: String) -> String? {
        guard text.hasPrefix("FORCE_DISCONNECT:") else { return nil }
        return String(text.dropFirst("FORCE_DISCONNECT:".count))
    }

    static func parseForceLogoutExcept(_ text: String) -> String? {
        guard text.hasPrefix("FORCE_LOGOUT_EXCEPT:") else { return nil }
        return String(text.dropFirst("FORCE_LOGOUT_EXCEPT:".count))
    }

    static func parseForceDisconnectDevice(_ text: String) -> String? {
        guard text.hasPrefix("FORCE_DISCONNECT_DEVICE:") else { return nil }
        return String(text.dropFirst("FORCE_DISCONNECT_DEVICE:".count))
    }

    static func parseClearCache(_ text: String) -> String? {
        guard text.hasPrefix("CLEAR_CACHE:") else { return nil }
        return String(text.dropFirst("CLEAR_CACHE:".count))
    }

    static func parseReadAll(_ text: String) -> (reader: String, roomId: String)? {
        guard text.hasPrefix("READ_ALL:") else { return nil }
        let payload = String(text.dropFirst("READ_ALL:".count))
        let parts = payload.components(separatedBy: ":")
        let reader = parts.first ?? ""
        return (reader: reader, roomId: "")
    }

    init?(from text: String) {
        if let cmd = SystemCommand(rawValue: text) {
            self = cmd
        } else {
            return nil
        }
    }
}

// MARK: - ChatInfo

struct ChatInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let participants: String
    let createdAt: Date
    let unreadCount: Int
    let lastMessageTime: Date
    let creator: String
    let lastMessageText: String
    let avatarUrl: String
    let fullAvatarUrl: String
    let lastMessageUsername: String
    let lastMessageHasImage: Bool
    let allowMembersToAdd: Bool
    let isSecret: Bool
    let peerPublicKey: String

    func displayName(currentUsername: String) -> String {
        if type != "direct" { return name }
        guard let data = participants.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return name
        }
        return arr.first(where: { $0 != currentUsername }) ?? name
    }
}

// MARK: - UserSession

struct UserSession: Equatable {
    var userId: String = ""
    var username: String = ""
    var password: String = ""
    var avatarUrl: String = ""
    var fullAvatarUrl: String = ""
    var isSuperAdmin: Bool = false
    var deviceId: String = ""
    var deviceName: String = ""
    var email: String = ""

    var isLoggedIn: Bool {
        !username.isEmpty && !password.isEmpty
    }
}

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case ready
    case failed

    var isConnected: Bool {
        switch self {
        case .ready: return true
        default: return false
        }
    }
}

// MARK: - Server Info

struct ServerInfo: Equatable {
    let address: String
    let port: Int
    let useTLS: Bool

    var hostPort: String {
        "\(address):\(port)"
    }
}
