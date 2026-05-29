# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Unit tests for CryptoManager and ProtoUtils
- Image picker integration
- Push notifications (FCM)
- Group chat creation
- Chat drafts persistence
- Theme system
- Localization (en/ru)

---

## [0.2.0] - 2026-05-29

### Added
- OSLog logging throughout GRPCManager
- Automatic clientVersion from Bundle.infoDictionary
- Separate component files for UI:
  - MessageBubbleView (message bubbles + reactions + context menu)
  - ReactionPickerView (emoji picker)
  - TypingIndicatorView (animated typing indicator)
  - ReplyPreviewView (reply preview with cancel)
  - ChatInputAreaView (text input + send button)
  - ImageViewerSheet (full-screen image viewer)
- SettingsViews (ChatInfo, EditProfile, Security, Notifications, Appearance)

### Changed
- **BREAKING**: Migrated from grpc-swift 1.x to 2.x
  - `GRPCChannel` → `GRPCClient<HTTP2ClientTransport>`
  - `GRPCChannelPool` → `withGRPCClient(transport:)`
  - `bidirectionalStreaming(request:descriptor:serializer:deserializer:)` API
- Removed CommonCrypto dependency (CryptoManager now uses only CryptoKit)
- Removed GRPCProtobufShim (using official `grpc-swift-protobuf` package)
- ChatRoomView reduced from 797 to 120 lines (components extracted)
- swift-tools-version bumped to 6.0
- Package.swift: iOS-only platform target

### Removed
- GRPCProtobufShim.swift (replaced by grpc-swift-protobuf package)
- CommonCrypto import from CryptoManager
- KeychainAccess SPM dependency (using native Security framework)

### Fixed
- Placeholder.swift removed (was causing build errors)
- AuthViewModel UIDevice references wrapped in `#if canImport(UIKit)`
- Deprecated `navigationBarHidden` replaced with `.toolbar(.hidden)`

---

## [0.1.0] - 2026-05-29

### Added
- Initial project structure
- Generated gRPC code from messenger.proto (messenger.pb.swift, messenger.grpc.swift)
- GRPCManager with bidirectional streaming (stub)
- CryptoManager: AES-256-GCM encryption matching server crypto.go
- E2EE support: ECDH key exchange + HKDF key derivation
- CredentialStore: Keychain-backed secure storage
- AuthViewModel: login/registration flow
- ChatViewModel: chat state, typing, reactions, drafts
- AuthView: login + registration forms
- ChatListView: chat list + new chat sheets
- ChatRoomView: message bubbles, replies, reactions, image viewer
- GRPCProtobufShim for grpc-swift 2.x compatibility
- Xcode project via xcodegen

### Known Issues
- GRPCChannel API may need adaptation for grpc-swift 2.x
- ChatRoomView is 797 lines (needs refactoring)
- No tests yet
- CommonCrypto dependency needs replacement
- Many unary RPC methods are stubs

---

[Unreleased]: https://github.com/ferzferz11-sudo/msg.client.ios/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ferzferz11-sudo/msg.client.ios/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ferzferz11-sudo/msg.client.ios/releases/tag/v0.1.0
