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

## [0.2.1] - 2026-05-30

### Added
- App logo from Android client (app_logo.png)
- Logo displayed in AuthView with circular clip shape
- gen.sh script for easy xcodegen rebuild + commit/push
- isConnecting guard to prevent duplicate GRPC connections

### Changed
- Branding: "Lavender Messenger" → "Lava Messenger" in UI strings
- Logo loaded from bundle via UIImage(named:) instead of Asset Catalog

### Fixed
- Autocapitalization and autocorrection disabled on login TextField
- Duplicate GRPC connect() calls causing stream cancellation
- Logo Asset Catalog issues (moved to Resources/ folder for xcodegen compatibility)

### Known Issues
- GRPC connection does not work in iOS Simulator (NIO raw sockets restriction)
- Works on real device

---

## [0.2.0] - 2026-05-30

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
- ContactsView
- SettingsView

### Changed
- **BREAKING**: Migrated from grpc-swift 1.x to 2.x
  - `GRPCChannel` → `GRPCClient<HTTP2ClientTransport.Posix>`
  - `GRPCChannelPool` → direct client creation
  - `bidirectionalStreaming(request:descriptor:serializer:deserializer:)` API
  - `unary(request:descriptor:serializer:deserializer:)` API
- **BREAKING**: Minimum iOS version raised to 18.0 (required by grpc-swift 2.x)
- Removed CommonCrypto dependency (CryptoManager now uses only CryptoKit)
- Removed GRPCProtobufShim (using official `grpc-swift-protobuf` package)
- Swift tools version bumped to 6.0
- Package.swift: iOS 18.0+ platform target

### Removed
- GRPCProtobufShim.swift (replaced by grpc-swift-protobuf package)
- CommonCrypto import from CryptoManager
- KeychainAccess SPM dependency (using native Security framework)

### Fixed
- Build errors with grpc-swift 2.x API compatibility
- Calendar.isToday/isYesterday not available in iOS 18 (use isDate(inSameDayAs:))
- Timer deinit concurrency warning (added @unchecked Sendable)
- Missing draft methods in GRPCManager
- Missing FCMLogEntry type
- Duplicate EditProfileView code in SettingsViews

---

## [0.1.0] - 2026-05-29

### Added
- Initial project structure
- Generated gRPC code from messenger.proto
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
- GRPCChannel API needed adaptation for grpc-swift 2.x
- ChatRoomView was 797 lines (needed refactoring)
- No tests yet
- CommonCrypto dependency needed replacement
- Many unary RPC methods were stubs

---

[Unreleased]: https://github.com/ferzferz11-sudo/msg.client.ios/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/ferzferz11-sudo/msg.client.ios/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ferzferz11-sudo/msg.client.ios/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ferzferz11-sudo/msg.client.ios/releases/tag/v0.1.0
