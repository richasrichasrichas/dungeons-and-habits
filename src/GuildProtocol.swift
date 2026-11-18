// SPDX-License-Identifier: MPL-2.0
import Foundation

/// Current JSON wire-format version shared with internal/guildprotocol in Go.
enum GuildProtocol {
    static let currentVersion: UInt16 = 1
}

/// A chat presence lease. The receiver measures lease expiry using its own
/// clock and receive time; sentAtMS is informational.
struct ChatHeartbeat: Codable, Hashable, Sendable {
    var type: String = "chat.heartbeat"
    let protocolVersion: UInt16
    let guildID: String
    let roomID: String
    let peerID: String
    let sessionID: String
    let sequence: UInt64
    let sentAtMS: Int64

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion = "protocol_version"
        case guildID = "guild_id"
        case roomID = "room_id"
        case peerID = "peer_id"
        case sessionID = "session_id"
        case sequence
        case sentAtMS = "sent_at_ms"
    }
}

/// Ephemeral chat content. Do not persist this model or include it in durable
/// diagnostic logs.
struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    var type: String = "chat.message"
    let protocolVersion: UInt16
    let id: String
    let guildID: String
    let roomID: String
    let senderID: String
    let sentAtMS: Int64
    let text: String
    let senderSignature: String

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion = "protocol_version"
        case id
        case guildID = "guild_id"
        case roomID = "room_id"
        case senderID = "sender_id"
        case sentAtMS = "sent_at_ms"
        case text
        case senderSignature = "sender_signature"
    }
}

/// A BBS post replicated among peers. A nil expiration uses the guild's
/// default retention policy. Pin metadata is signed by a guild moderator.
struct BBSPost: Codable, Hashable, Identifiable, Sendable {
    var type: String = "bbs.post"
    let protocolVersion: UInt16
    let postID: String
    let guildID: String
    let authorID: String
    let revision: UInt64
    let createdAtMS: Int64
    let expiresAtMS: Int64?
    let body: String
    let pinned: Bool
    let pinnedBy: String?
    let pinnedAtMS: Int64?
    let authorSignature: String
    let pinSignature: String?

    var id: String { postID }

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion = "protocol_version"
        case postID = "post_id"
        case guildID = "guild_id"
        case authorID = "author_id"
        case revision
        case createdAtMS = "created_at_ms"
        case expiresAtMS = "expires_at_ms"
        case body
        case pinned
        case pinnedBy = "pinned_by"
        case pinnedAtMS = "pinned_at_ms"
        case authorSignature = "author_signature"
        case pinSignature = "pin_signature"
    }
}

/// A moderator-signed deletion record that prevents a stale replica from
/// restoring a post after it reconnects.
struct BBSTombstone: Codable, Hashable, Identifiable, Sendable {
    var type: String = "bbs.tombstone"
    let protocolVersion: UInt16
    let tombstoneID: String
    let guildID: String
    let postID: String
    let postRevision: UInt64
    let deletedAtMS: Int64
    let deletedBy: String
    let reason: String?
    let moderatorSignature: String

    var id: String { tombstoneID }

    enum CodingKeys: String, CodingKey {
        case type
        case protocolVersion = "protocol_version"
        case tombstoneID = "tombstone_id"
        case guildID = "guild_id"
        case postID = "post_id"
        case postRevision = "post_revision"
        case deletedAtMS = "deleted_at_ms"
        case deletedBy = "deleted_by"
        case reason
        case moderatorSignature = "moderator_signature"
    }
}

/// Type-safe decoder for the protocol's top-level "type" discriminator.
enum GuildWireMessage: Codable, Hashable, Sendable {
    case chat(ChatMessage)
    case heartbeat(ChatHeartbeat)
    case post(BBSPost)
    case tombstone(BBSTombstone)

    private enum DiscriminatorKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DiscriminatorKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "chat.message":
            let message = try ChatMessage(from: decoder)
            try Self.validateVersion(message.protocolVersion, decoder: decoder)
            self = .chat(message)
        case "chat.heartbeat":
            let message = try ChatHeartbeat(from: decoder)
            try Self.validateVersion(message.protocolVersion, decoder: decoder)
            self = .heartbeat(message)
        case "bbs.post":
            let message = try BBSPost(from: decoder)
            try Self.validateVersion(message.protocolVersion, decoder: decoder)
            self = .post(message)
        case "bbs.tombstone":
            let message = try BBSTombstone(from: decoder)
            try Self.validateVersion(message.protocolVersion, decoder: decoder)
            self = .tombstone(message)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown guild message type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .chat(let message):
            try message.encode(to: encoder)
        case .heartbeat(let message):
            try message.encode(to: encoder)
        case .post(let message):
            try message.encode(to: encoder)
        case .tombstone(let message):
            try message.encode(to: encoder)
        }
    }

    private static func validateVersion(
        _ version: UInt16,
        decoder: Decoder
    ) throws {
        guard version == GuildProtocol.currentVersion else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported guild protocol version: \(version)"
                )
            )
        }
    }
}
