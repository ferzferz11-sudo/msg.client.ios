# Lavender Messenger — iOS Client

> **A secure messaging application** — SwiftUI + gRPC + AES-256 encryption

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift%205.10-orange)](https://swift.org/)
[![gRPC](https://img.shields.io/badge/gRPC-Swift-green)](https://github.com/grpc/grpc-swift)
[![License](https://img.shields.io/badge/license-Proprietary-lightgrey)](LICENSE)

---

## Overview

Lavender Messenger is a cross-platform secure messaging application. This is the **iOS client**, built with **SwiftUI** and **gRPC** for real-time bidirectional messaging.

### Architecture

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  AuthView → MainTabView → ChatRoomView          │
│  (SwiftUI Views + ViewModels)                   │
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
│  (from messenger.proto via swift-protobuf)       │
└─────────────────────────────────────────────────┘
```

### Features

| Feature | Status |
|---------|--------|
| User login / registration | ✅ |
| Bidirectional gRPC messaging | ✅ (stub) |
| AES-256-GCM encryption | ✅ |
| Secure credential storage (Keychain) | ✅ |
| Typing indicators | ✅ |
| Message reactions | ✅ |
| Reply to messages | ✅ |
| Read receipts | ✅ |
| Image messages | ✅ |
| Voice messages | ✅ (UI only) |
| E2EE secret chats (ECDH + AES-256) | ✅ |
| Group chats | ✅ (stub) |
| Chat drafts | ✅ (stub) |
| Push notifications (FCM) | ⏳ |
| Themes | ✅ (UI only) |
| Favorites | ⏳ |
| Admin panel | ⏳ |

**Legend:** ✅ = implemented, ⏳ = server-side stub only

---

## Project Structure

```
LavenderMessenger-ios/
├── Sources/LavenderMessenger/
│   ├── LavenderMessengerApp.swift     # @main app entry
│   ├── Models/
│   │   └── Models.swift               # Message, ChatInfo, UserSession, etc.
│   ├── DataLayer/
│   │   ├── GRPCManager.swift          # gRPC connection + streaming
│   │   ├── CryptoManager.swift        # AES-256-GCM (matches crypto.go)
│   │   ├── CredentialStore.swift      # Keychain-backed secure storage
│   │   └── ProtoUtils.swift           # Proto ↔ Model conversion
│   ├── BusinessLayer/
│   │   ├── AuthViewModel.swift        # Login / registration logic
│   │   └── ChatViewModel.swift        # Chat state management
│   ├── UI/
│   │   ├── AuthView.swift             # Login + registration screen
│   │   ├── ChatListView.swift         # Chat list + new chat sheets
│   │   └── ChatRoomView.swift         # Message bubbles + input + actions
│   ├── Generated/
│   │   └── Placeholder.swift          # Temporary — run generate_grpc.sh
│   └── Resources/
├── Tests/
├── generate_grpc.sh                   # Swift protobuf generation script
├── Package.swift                      # SPM dependencies
└── README.md
```

---

## Getting Started

### Prerequisites

- **Xcode 15+** (iOS 17 SDK)
- **macOS 14+** (for Swift 5.10)
- **Homebrew** with:
  ```bash
  brew install swift-protobuf grpc-swift
  ```

### 1. Generate gRPC Code

```bash
cd LavenderMessenger-ios
bash generate_grpc.sh
```

This copies `messenger.proto` from the server repo and generates:
- `Sources/Generated/Messenger.pb.swift` — protobuf messages
- `Sources/Generated/Messenger.grpc.swift` — gRPC service stubs

### 2. Open in Xcode

Open `Package.swift` with Xcode or use:

```bash
open Package.swift
```

### 3. Configure Server

Default server: `13.140.25.249:50051` (editable in auth screen).

### 4. Build & Run

`Cmd+R` in Xcode. Minimum deployment target: iOS 17.0.

---

## Protocol

The client communicates with the Lavender Messenger Go server via **gRPC** using a single bidirectional stream for messaging:

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
   - `USER_NOT_FOUND` → user doesn't exist (and not registering)
   - `EMAIL_ALREADY_IN_USE` → email taken

### Encryption

- **Server-side**: Messages encrypted with AES-256-GCM using `CHAT_SECRET_KEY` env var (32 bytes)
- **E2EE (secret chats)**: Client-side ECDH key exchange + AES-256-GCM with derived shared secret
- Matches the Go server's `crypto.go` implementation exactly

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
