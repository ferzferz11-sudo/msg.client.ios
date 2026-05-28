import Foundation
import SwiftProtobuf

// MARK: - Proto Utilities

/// Converts between Swift protobuf messages and app models.
/// Mirrors Android's ProtoUtils.kt functionality.
enum ProtoUtils {

    // MARK: - Message -> Proto

    func messageToProto(_ message: Message) -> Server_Message {
        var timestamp = SwiftProtobuf.Google_Protobuf_Timestamp()
        timestamp.seconds = Int64(message.timestamp.timeIntervalSince1970)
        timestamp.nanos = Int32((message.timestamp.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000_000)

        var builder = Server_Message()
        builder.id = message.id
        builder.user = message.user
        builder.text = message.text
        builder.createdAt = timestamp
        builder.repliedToMessageID = message.repliedToMessageId
        builder.repliedToUser = message.repliedToUser
        builder.repliedToText = message.repliedToText
        builder.roomID = message.roomId
        builder.isRead = message.isRead
        builder.avatarURL = message.avatarUrl
        builder.imageURL = message.imageUrl
        builder.imageUrls = message.imageUrls
        builder.edited = message.edited
        builder.clientVersion = "1.1.0.0"
        builder.isSuperAdmin = message.isSuperAdmin
        builder.voiceURL = message.voiceUrl
        builder.duration = Int32(message.duration)
        builder.userID = message.userId
        builder.isE2EE = message.isE2EE
        builder.e2eePayload = message.e2eePayload

        // Add reactions
        for reaction in message.reactions {
            var reactionProto = Server_Reaction()
            reactionProto.user = reaction.user
            reactionProto.emoji = reaction.emoji
            builder.reactions.append(reactionProto)
        }

        return builder
    }

    // MARK: - Proto -> Message

    func protoToMessage(_ proto: Server_Message) -> Message {
        let timestamp: Date
        if proto.hasCreatedAt {
            let seconds = Double(proto.createdAt.seconds)
            let nanos = Double(proto.createdAt.nanos) / 1_000_000_000
            timestamp = Date(timeIntervalSince1970: seconds + nanos)
        } else {
            timestamp = Date()
        }

        return Message(
            id: proto.id.isEmpty ? UUID().uuidString : proto.id,
            user: proto.user,
            text: proto.text,
            timestamp: timestamp,
            reactions: proto.reactions.map { Reaction(user: $0.user, emoji: $0.emoji) },
            repliedToMessageId: proto.repliedToMessageID,
            repliedToUser: proto.repliedToUser,
            repliedToText: proto.repliedToText,
            roomId: proto.roomID,
            isRead: proto.isRead,
            avatarUrl: proto.avatarURL,
            imageUrl: proto.imageURL,
            imageUrls: Array(proto.imageUrls),
            edited: proto.edited,
            isSuperAdmin: proto.isSuperAdmin,
            voiceUrl: proto.voiceURL,
            duration: Int(proto.duration),
            userId: proto.userID,
            isE2EE: proto.isE2EE,
            e2eePayload: proto.e2eePayload
        )
    }

    // MARK: - ChatInfo

    func protoToChatInfo(_ proto: Server_ChatInfo) -> ChatInfo {
        let createdAt: Date
        if proto.hasCreatedAt {
            createdAt = proto.createdAt.date
        } else {
            createdAt = Date()
        }

        let lastMessageTime: Date
        if proto.hasLastMessageTime {
            lastMessageTime = proto.lastMessageTime.date
        } else {
            lastMessageTime = Date()
        }

        return ChatInfo(
            id: proto.id,
            name: proto.name,
            type: proto.type,
            participants: proto.participants,
            createdAt: createdAt,
            unreadCount: Int(proto.unreadCount),
            lastMessageTime: lastMessageTime,
            creator: proto.creator,
            lastMessageText: proto.lastMessageText,
            avatarUrl: proto.avatarURL,
            fullAvatarUrl: proto.fullAvatarURL,
            lastMessageUsername: proto.lastMessageUsername,
            lastMessageHasImage: proto.lastMessageHasImage,
            allowMembersToAdd: proto.allowMembersToAdd,
            isSecret: proto.isSecret,
            peerPublicKey: proto.peerPublicKey,
            e2eeReady: proto.e2eeReady
        )
    }

    // MARK: - Timestamp Helpers

    func getCurrentTimestamp() -> SwiftProtobuf.Google_Protobuf_Timestamp {
        return SwiftProtobuf.Google_Protobuf_Timestamp(date: Date())
    }

    func timestampToProto(_ date: Date) -> SwiftProtobuf.Google_Protobuf_Timestamp {
        return SwiftProtobuf.Google_Protobuf_Timestamp(date: date)
    }

    // MARK: - TypingRequest

    func createTypingRequest(roomId: String, username: String, isTyping: Bool, userId: String) -> Server_TypingRequest {
        var req = Server_TypingRequest()
        req.roomID = roomId
        req.username = username
        req.isTyping = isTyping
        req.userID = userId
        return req
    }
}

// MARK: - Google_Protobuf_Timestamp Extensions

extension SwiftProtobuf.Google_Protobuf_Timestamp {
    var date: Date {
        let seconds = Double(self.seconds)
        let nanos = Double(self.nanos) / 1_000_000_000
        return Date(timeIntervalSince1970: seconds + nanos)
    }

    init(date: Date) {
        let interval = date.timeIntervalSince1970
        self.init()
        self.seconds = Int64(interval)
        self.nanos = Int32((interval.truncatingRemainder(dividingBy: 1)) * 1_000_000_000)
    }
}
