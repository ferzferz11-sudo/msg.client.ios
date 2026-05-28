// Placeholder file.
// Run ./generate_grpc.sh to generate the actual gRPC code from messenger.proto.
//
// After generation, this Sources/Generated/ directory will contain:
//   - Messenger.pb.swift (protobuf messages)
//   - Messenger.grpc.swift (gRPC service stubs)
//
// Then update import statements in GRPCManager.swift and ProtoUtils.swift
// to use the actual Server_Message, Server_ChatInfo, etc. types.

// Temporary type aliases for compilation until proto is generated.
// These match the proto message names that swift-protobuf will generate.

import Foundation
import SwiftProtobuf

// These typealiases will be replaced by the generated code.
// The naming convention for swift-protobuf is the proto message name as-is.

typealias Server_Message = Google_Protobuf_Any
typealias Server_Reaction = Google_Protobuf_Any
typealias Server_ChatInfo = Google_Protobuf_Any
typealias Server_TypingRequest = Google_Protobuf_Any
typealias Server_TypingSignal = Google_Protobuf_Any
typealias Server_ClientListRequest = Google_Protobuf_Any
typealias Server_ClientListResponse = Google_Protobuf_Any
typealias Server_GetAllUsersRequest = Google_Protobuf_Any
typealias Server_GetAllUsersResponse = Google_Protobuf_Any
typealias Server_GetAllChatsRequest = Google_Protobuf_Any
typealias Server_GetAllChatsResponse = Google_Protobuf_Any
typealias Server_CreateChatRequest = Google_Protobuf_Any
typealias Server_GetHistoryRequest = Google_Protobuf_Any
typealias Server_GetHistoryResponse = Google_Protobuf_Any
typealias Server_DeleteMessagesRequest = Google_Protobuf_Any
typealias Server_DeleteMessagesResponse = Google_Protobuf_Any
typealias Server_TokenRequest = Google_Protobuf_Any
typealias Server_TokenResponse = Google_Protobuf_Any
typealias Server_GetChatsRequest = Google_Protobuf_Any
typealias Server_GetChatsResponse = Google_Protobuf_Any
typealias Server_CreateDirectChatRequest = Google_Protobuf_Any
typealias Server_CreateDirectChatResponse = Google_Protobuf_Any
typealias Server_CreateGroupChatRequest = Google_Protobuf_Any
typealias Server_CreateGroupChatResponse = Google_Protobuf_Any
typealias Server_UpdateUsernameRequest = Google_Protobuf_Any
typealias Server_UpdateUsernameResponse = Google_Protobuf_Any
typealias Server_UpdatePasswordRequest = Google_Protobuf_Any
typealias Server_UpdatePasswordResponse = Google_Protobuf_Any
typealias Server_MarkReadRequest = Google_Protobuf_Any
typealias Server_MarkReadResponse = Google_Protobuf_Any
typealias Server_UpdateAvatarRequest = Google_Protobuf_Any
typealias Server_UpdateAvatarResponse = Google_Protobuf_Any
typealias Server_UpdateProfileRequest = Google_Protobuf_Any
typealias Server_UpdateProfileResponse = Google_Protobuf_Any
typealias Server_GetUserProfileRequest = Google_Protobuf_Any
typealias Server_GetUserProfileResponse = Google_Protobuf_Any
typealias Server_GetUserAvatarRequest = Google_Protobuf_Any
typealias Server_GetUserAvatarResponse = Google_Protobuf_Any
typealias Server_AddParticipantRequest = Google_Protobuf_Any
typealias Server_AddParticipantResponse = Google_Protobuf_Any
typealias Server_RemoveParticipantRequest = Google_Protobuf_Any
typealias Server_RemoveParticipantResponse = Google_Protobuf_Any
typealias Server_EditMessageRequest = Google_Protobuf_Any
typealias Server_EditMessageResponse = Google_Protobuf_Any
typealias Server_DeleteChatRequest = Google_Protobuf_Any
typealias Server_DeleteChatResponse = Google_Protobuf_Any
typealias Server_DeleteProfileRequest = Google_Protobuf_Any
typealias Server_DeleteProfileResponse = Google_Protobuf_Any
typealias Server_AddContactRequest = Google_Protobuf_Any
typealias Server_AddContactResponse = Google_Protobuf_Any
typealias Server_RemoveContactRequest = Google_Protobuf_Any
typealias Server_RemoveContactResponse = Google_Protobuf_Any
typealias Server_GetContactsRequest = Google_Protobuf_Any
typealias Server_GetContactsResponse = Google_Protobuf_Any
typealias Server_GetChatListVersionRequest = Google_Protobuf_Any
typealias Server_GetChatListVersionResponse = Google_Protobuf_Any
typealias Server_CustomTheme = Google_Protobuf_Any
typealias Server_GetThemesRequest = Google_Protobuf_Any
typealias Server_GetThemesResponse = Google_Protobuf_Any
typealias Server_SaveThemeRequest = Google_Protobuf_Any
typealias Server_SaveThemeResponse = Google_Protobuf_Any
typealias Server_SetCurrentThemeRequest = Google_Protobuf_Any
typealias Server_SetCurrentThemeResponse = Google_Protobuf_Any
typealias Server_DeleteThemeRequest = Google_Protobuf_Any
typealias Server_DeleteThemeResponse = Google_Protobuf_Any
typealias Server_UpdateChatNameRequest = Google_Protobuf_Any
typealias Server_UpdateChatNameResponse = Google_Protobuf_Any
typealias Server_UpdateChatAvatarRequest = Google_Protobuf_Any
typealias Server_UpdateChatAvatarResponse = Google_Protobuf_Any
typealias Server_UpdateChatSettingsRequest = Google_Protobuf_Any
typealias Server_UpdateChatSettingsResponse = Google_Protobuf_Any
typealias Server_GetFCMLogsRequest = Google_Protobuf_Any
typealias Server_FCMLogEntry = Google_Protobuf_Any
typealias Server_GetFCMLogsResponse = Google_Protobuf_Any
typealias Server_SaveDraftRequest = Google_Protobuf_Any
typealias Server_SaveDraftResponse = Google_Protobuf_Any
typealias Server_GetDraftRequest = Google_Protobuf_Any
typealias Server_GetDraftResponse = Google_Protobuf_Any
typealias Server_DeleteDraftRequest = Google_Protobuf_Any
typealias Server_DeleteDraftResponse = Google_Protobuf_Any
typealias Server_GetMutedChatsRequest = Google_Protobuf_Any
typealias Server_GetMutedChatsResponse = Google_Protobuf_Any
typealias Server_SetMutedChatRequest = Google_Protobuf_Any
typealias Server_SetMutedChatResponse = Google_Protobuf_Any
typealias Server_GetUserIdRequest = Google_Protobuf_Any
typealias Server_GetUserIdResponse = Google_Protobuf_Any
typealias Server_AddFavoriteRequest = Google_Protobuf_Any
typealias Server_AddFavoriteResponse = Google_Protobuf_Any
typealias Server_RemoveFavoriteRequest = Google_Protobuf_Any
typealias Server_RemoveFavoriteResponse = Google_Protobuf_Any
typealias Server_GetFavoritesRequest = Google_Protobuf_Any
typealias Server_GetFavoritesResponse = Google_Protobuf_Any
typealias Server_UserInfo = Google_Protobuf_Any
typealias Server_DeviceInfo = Google_Protobuf_Any
typealias Server_GetDevicesRequest = Google_Protobuf_Any
typealias Server_GetDevicesResponse = Google_Protobuf_Any
typealias Server_DeleteDeviceRequest = Google_Protobuf_Any
typealias Server_DeleteDeviceResponse = Google_Protobuf_Any
typealias Server_RequestPasswordResetRequest = Google_Protobuf_Any
typealias Server_RequestPasswordResetResponse = Google_Protobuf_Any
typealias Server_ResetPasswordRequest = Google_Protobuf_Any
typealias Server_ResetPasswordResponse = Google_Protobuf_Any
typealias Server_CallMessage = Google_Protobuf_Any
typealias Server_ReactionRequest = Google_Protobuf_Any
typealias Server_ReactionResponse = Google_Protobuf_Any

// Chat service stub placeholder
class ChatServiceServiceClient {
    init(channel: Any) {}
}

// Service descriptor placeholder
struct ChatService.Methods {
    static let chat = "messenger.ChatService/Chat"
    static let typing = "messenger.ChatService/Typing"
    static let getHistory = "messenger.ChatService/GetHistory"
    static let getChats = "messenger.ChatService/GetChats"
    static let setReaction = "messenger.ChatService/SetReaction"
    static let markRead = "messenger.ChatService/MarkRead"
    static let sendMessage = "messenger.ChatService/SendMessage"
    static let createDirectChat = "messenger.ChatService/CreateDirectChat"
    static let createGroupChat = "messenger.ChatService/CreateGroupChat"
    static let updateAvatar = "messenger.ChatService/UpdateAvatar"
    static let deleteChat = "messenger.ChatService/DeleteChat"
    static let editMessage = "messenger.ChatService/EditMessage"
    static let registerToken = "messenger.ChatService/RegisterToken"
    static let getDevices = "messenger.ChatService/GetDevices"
    static let deleteDevice = "messenger.ChatService/DeleteDevice"
    static let deleteOtherDevices = "messenger.ChatService/DeleteOtherDevices"
    static let deleteProfile = "messenger.ChatService/DeleteProfile"
    static let updateProfile = "messenger.ChatService/UpdateProfile"
    static let updateUsername = "messenger.ChatService/UpdateUsername"
    static let updatePassword = "messenger.ChatService/UpdatePassword"
}

struct ChatService {
    struct Methods {
        static let chat = "messenger.ChatService/Chat"
    }
}
