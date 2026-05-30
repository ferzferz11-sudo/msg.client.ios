# Lava Messenger — iOS Client

> **A secure messaging application** — SwiftUI + gRPC + AES-256 encryption

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift%206.0-orange)](https://swift.org/)
[![gRPC](https://img.shields.io/badge/gRPC%20Swift%202.x-green)](https://github.com/grpc/grpc-swift)
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey)](LICENSE)

---

## Overview

Lava Messenger is a cross-platform secure messaging application. This is the **iOS client**, built with **SwiftUI** and **gRPC** for real-time bidirectional messaging.

### Architecture

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  AuthView → MainTabView → ChatRoomView          │
│  ├── Components/                                │
│  │   ├── MessageBubbleView                      │
│  │   ├── ReactionPickerView                     │
│  │   ├── TypingIndicatorView                    │
│  │   ├── ReplyPreviewView                       │
│  │   ├── ChatInputAreaView                      │
│  │   └── ImageViewerSheet                       │
│  └── SettingsViews/                             │
│       ├── ChatInfoView                          │
│       ├── EditProfileView                       │
│       ├── SecurityView                          │
│       ├── NotificationsView                     │
│       └── AppearanceView                        │
├─────────────────────────────────────────────────┤
│              Business Layer                       │
│  AuthViewModel / ChatViewModel / ChatListVM     │
│  (@Published, MainActor, Combine)                │
├─────────────────────────────────────────────────┤
│                Data Layer                         │
│  GRPCManager ←→ CryptoManager ←→ CredentialStore│
│  (gRPC streams, AES-256-GCM, Keychain)          │
├─────────────────────────────────────────────────┤
│              Generated Layer                      │
│  messenger.pb.swift / messenger.grpc.swift       │
│  (from messenger.proto via SwiftProtobuf)        │
└─────────────────────────────────────────────────┘
```

### Features

| Feature | Status |
|---------|--------|
| User login / registration | ✅ |
| Bidirectional gRPC messaging | ✅ |
| AES-256-GCM encryption | ✅ |
| Secure credential storage (Keychain) | ✅ |
| Typing indicators | ✅ |
| Message reactions | ✅ |
| Reply to messages | ✅ |
| Read receipts | ✅ |
| Image messages | ✅ |
| E2EE secret chats (ECDH + AES-256) | ✅ |
| Group chats | 🔄 (stub) |
| Chat drafts | 🔄 (stub) |
| Push notifications (FCM) | ⏳ |
| Themes | 🔄 (UI only) |
| Secret chat key exchange | ✅ |

**Legend:** ✅ = implemented, 🔄 = partial/stub, ⏳ = planned

---

## Project Structure

```
LavenderMessenger-ios/
├── LavenderMessengerApp.swift          # @main app entry point
├── LavenderMessenger.xcodeproj/        # Xcode project (xcodegen)
├── project.yml                         # xcodegen configuration
├── Package.swift                       # SPM dependencies
├── README.md
├── CHANGELOG.md
└── Sources/LavenderMessengerLib/
    ├── Models/
    │   └── Models.swift               # Message, ChatInfo, UserSession, etc.
    ├── DataLayer/
    │   ├── GRPCManager.swift          # gRPC connection + streaming
    │   ├── CryptoManager.swift        # AES-256-GCM (matches crypto.go)
    │   ├── CredentialStore.swift      # Keychain-backed secure storage
    │   └── ProtoUtils.swift           # Proto ↔ Model conversion
    ├── BusinessLayer/
    │   ├── AuthViewModel.swift        # Login / registration logic
    │   └── ChatViewModel.swift        # Chat state management
    ├── UI/
    │   ├── AuthView.swift             # Login + registration screen
    │   ├── ChatListView.swift         # Chat list + new chat sheets
    │   ├── ChatRoomView.swift         # Main chat screen (thin wrapper)
    │   ├── Components/
    │   │   ├── MessageBubbleView.swift    # Message bubbles + reactions
    │   │   ├── ReactionPickerView.swift   # Emoji reaction picker
    │   │   ├── TypingIndicatorView.swift  # Typing animation
    │   │   ├── ReplyPreviewView.swift     # Reply preview + cancel
    │   │   ├── ChatInputAreaView.swift    # Text input + send button
    │   │   └── ImageViewerSheet.swift     # Full-screen image viewer
    │   └── SettingsViews.swift        # ChatInfo, EditProfile, Security, etc.
    └── Generated/
        ├── messenger.pb.swift         # SwiftProtobuf generated (6754 lines)
        └── messenger.grpc.swift       # gRPC Swift generated (10976 lines)
```

---

## Getting Started

### Prerequisites

- **Xcode 15+** (iOS 17 SDK)
- **Swift 6.0+**
- **macOS 14+**

### 1. Open in Xcode

```bash
open LavenderMessenger.xcodeproj
```

Xcode will automatically resolve SPM dependencies:
- `grpc-swift` 2.x (GRPCCore)
- `grpc-swift-nio-transport` (HTTP2ClientTransport)
- `grpc-swift-protobuf` (ProtobufSerializer/Deserializer)
- `swift-protobuf` 1.28+

### 2. Build & Run

`Cmd+R` in Xcode. Minimum deployment target: iOS 17.0.

### 3. Configure Server

Default server: `13.140.25.249:50051` (editable in auth screen).

---

## Protocol

The client communicates with the Lava Messenger Go server via **gRPC** using a single bidirectional stream for messaging:

```
Client                              Server
  │                                   │
  │──── Message(user, pwd) ──────────▶│  Auth (first message)
  │◀─── SYSTEM: SERVER_INFO:v1.0.7 ──│  Auth response
  │◀─── SYSTEM: SET_SUPER_ADMIN ─────│  (if admin)
  │                                   │
  │◀═══ Message (stream) ═══════════▶│  Bidirectional messages
  │     ...           ...             │
```

### Authentication Flow

1. Client sends first `Message` with `user`, `password`, optional `register=true`, optional `email`
2. Server responds with one of:
   - `SERVER_INFO:1.0.7.1` → authenticated
   - `REGISTRATION_SUCCESS` → registered + authenticated
   - `AUTH_FAILED` → wrong password
   - `USER_NOT_FOUND` → user doesn't exist

### Encryption

- **Server-side**: Messages encrypted with AES-256-GCM using `CHAT_SECRET_KEY` env var (32 bytes)
- **E2EE (secret chats)**: Client-side ECDH key exchange + AES-256-GCM with derived shared secret
- Matches the Go server's `crypto.go` implementation exactly

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `grpc-swift` | 2.x+ | gRPC core (GRPCCore) |
| `grpc-swift-nio-transport` | 1.x+ | HTTP/2 transport (NIO-based) |
| `grpc-swift-protobuf` | 1.x+ | Protobuf serialization |
| `swift-protobuf` | 1.28+ | Protobuf message types |

Native frameworks only (no third-party deps):
- `CryptoKit` — AES-256-GCM encryption
- `Security` — Keychain access
- `SwiftUI` — UI framework
- `OSLog` — logging

---

## Related Repositories

| Repo | Description |
|------|-------------|
| [`ferzferz11-sudo/msg`](https://github.com/ferzferz11-sudo/msg) | Go server |
| [`ferzferz11-sudo/msg.client.android`](https://github.com/ferzferz11-sudo/msg.client.android) | Android client (Kotlin) |
| [`ferzferz11-sudo/msg.client.ios`](https://github.com/ferzferz11-sudo/msg.client.ios) | This repo |
| [`ferzferz11-sudo/msg.client.macos`](https://github.com/ferzferz11-sudo/msg.client.macos) | macOS client (Swift/Fyne) |

---

## License

Proprietary — Pavel Davydov (ferz), 2026
