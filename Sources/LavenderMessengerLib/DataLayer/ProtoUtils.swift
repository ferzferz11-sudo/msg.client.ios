import Foundation
import SwiftProtobuf

// MARK: - Proto Utilities

enum ProtoUtils {

    // MARK: - Message -> Proto

    static func messageToProto(_ message: Message) -> Messenger_Message {
        var timestamp = Google_Protobuf_Timestamp(date: message.timestamp)

        var builder = Messenger_Message()
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
        builder.isE2Ee = message.isE2EE

        for reaction in message.reactions {
            var r = Messenger_Reaction()
            r.user = reaction.user
            r.emoji = reaction.emoji
            builder.reactions.append(r)
        }

        return builder
    }

    // MARK: - Proto -> Message

    static func protoToMessage(_ proto: Messenger_Message) -> Message {
        let timestamp: Date
        if proto.hasCreatedAt {
            timestamp = proto.createdAt.date
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
            isE2EE: proto.isE2Ee,
            e2eePayload: proto.e2EePayload
        )
    }

    // MARK: - ChatInfo

    static func protoToChatInfo(_ proto: Messenger_ChatInfo) -> ChatInfo {
        let createdAt = proto.hasCreatedAt ? proto.createdAt.date : Date()
        let lastMessageTime = proto.hasLastMessageTime ? proto.lastMessageTime.date : Date()

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
}

// MARK: - Google_Protobuf_Timestamp Extensions

extension Google_Protobuf_Timestamp {
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
