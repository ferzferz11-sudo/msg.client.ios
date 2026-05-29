// GRPCProtobuf.swift — Shim module for grpc-swift 2.x compatibility
//
// The protoc-gen-grpc-swift 2.x plugin generates code that imports GRPCProtobuf
// and uses GRPCProtobuf.ProtobufSerializer / GRPCProtobuf.ProtobufDeserializer.
// grpc-swift 2.x moved these into GRPCCore but the generator wasn't fully updated.
// This shim bridges the gap.

import SwiftProtobuf
import GRPCCore
import Foundation

// MARK: - ProtobufSerializer

struct ProtobufSerializer<Message: SwiftProtobuf.Message>: MessageSerializer {
    init() {}

    func serialize(_ message: Message, into buffer: inout UnsafeMutableRawBufferPointer) throws -> Int {
        let data = try message.serializedData()
        guard data.count <= buffer.count else {
            throw SerializationError.insufficientSpace
        }
        data.withUnsafeBytes { source in
            buffer.baseAddress?.copyMemory(from: source.baseAddress!, byteCount: data.count)
        }
        return data.count
    }
}

// MARK: - ProtobufDeserializer

struct ProtobufDeserializer<Message: SwiftProtobuf.Message>: MessageDeserializer {
    init() {}

    func deserialize(buffer: UnsafeRawBufferPointer) throws -> Message {
        let data = Data(buffer)
        return try Message(serializedData: data)
    }
}

// MARK: - Error

enum SerializationError: Error {
    case insufficientSpace
}

// MARK: - Module namespace shim

/// The generated code uses `GRPCProtobuf.ProtobufSerializer<T>()` and
/// `GRPCProtobuf.ProtobufDeserializer<T>()`. We provide these via a namespace shim.
enum GRPCProtobuf {
    typealias ProtobufSerializer<T: SwiftProtobuf.Message> = LavenderMessengerLib.ProtobufSerializer<T>
    typealias ProtobufDeserializer<T: SwiftProtobuf.Message> = LavenderMessengerLib.ProtobufDeserializer<T>
}
