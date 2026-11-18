package guildprotocol

import (
	"encoding/json"
	"fmt"
)

// CurrentProtocolVersion is the wire-format version understood by this package.
const CurrentProtocolVersion uint16 = 1

type MessageType string

const (
	TypeChatMessage   MessageType = "chat.message"
	TypeChatHeartbeat MessageType = "chat.heartbeat"
	TypeBBSPost       MessageType = "bbs.post"
	TypeBBSTombstone  MessageType = "bbs.tombstone"
)

// ChatMessage is transient. Do not write it to persistent storage or logs.
type ChatMessage struct {
	Type            MessageType `json:"type"`
	ProtocolVersion uint16      `json:"protocol_version"`
	ID              string      `json:"id"`
	GuildID         string      `json:"guild_id"`
	RoomID          string      `json:"room_id"`
	SenderID        string      `json:"sender_id"`
	SentAtMS        int64       `json:"sent_at_ms"`
	Text            string      `json:"text"`
	SenderSignature string      `json:"sender_signature"`
}

// ChatHeartbeat refreshes a peer's in-memory presence lease for one room.
// The receiver must use its own receive time to determine whether the peer is
// still online; SentAtMS is informational and is not trusted for lease timing.
type ChatHeartbeat struct {
	Type            MessageType `json:"type"`
	ProtocolVersion uint16      `json:"protocol_version"`
	GuildID         string      `json:"guild_id"`
	RoomID          string      `json:"room_id"`
	PeerID          string      `json:"peer_id"`
	SessionID       string      `json:"session_id"`
	Sequence        uint64      `json:"sequence"`
	SentAtMS        int64       `json:"sent_at_ms"`
}

// BBSPost is replicated between guild peers. ExpiresAtMS can be omitted when
// the guild applies a default retention period. Pin fields are signed by a
// moderator separately from the author's immutable post content.
type BBSPost struct {
	Type            MessageType `json:"type"`
	ProtocolVersion uint16      `json:"protocol_version"`
	PostID          string      `json:"post_id"`
	GuildID         string      `json:"guild_id"`
	AuthorID        string      `json:"author_id"`
	Revision        uint64      `json:"revision"`
	CreatedAtMS     int64       `json:"created_at_ms"`
	ExpiresAtMS     *int64      `json:"expires_at_ms,omitempty"`
	Body            string      `json:"body"`
	Pinned          bool        `json:"pinned"`
	PinnedBy        string      `json:"pinned_by,omitempty"`
	PinnedAtMS      *int64      `json:"pinned_at_ms,omitempty"`
	AuthorSignature string      `json:"author_signature"`
	PinSignature    string      `json:"pin_signature,omitempty"`
}

// BBSTombstone is a signed moderation record. Keep tombstones long enough to
// prevent offline peers from reintroducing deleted posts.
type BBSTombstone struct {
	Type               MessageType `json:"type"`
	ProtocolVersion    uint16      `json:"protocol_version"`
	TombstoneID        string      `json:"tombstone_id"`
	GuildID            string      `json:"guild_id"`
	PostID             string      `json:"post_id"`
	PostRevision       uint64      `json:"post_revision"`
	DeletedAtMS        int64       `json:"deleted_at_ms"`
	DeletedBy          string      `json:"deleted_by"`
	Reason             string      `json:"reason,omitempty"`
	ModeratorSignature string      `json:"moderator_signature"`
}

// DecodeMessage dispatches a JSON wire message by its "type" discriminator.
// Signature verification and authorization must be performed by the caller.
func DecodeMessage(data []byte) (any, error) {
	var header struct {
		Type            MessageType `json:"type"`
		ProtocolVersion uint16      `json:"protocol_version"`
	}
	if err := json.Unmarshal(data, &header); err != nil {
		return nil, fmt.Errorf("decode guild message header: %w", err)
	}
	if header.ProtocolVersion != CurrentProtocolVersion {
		return nil, fmt.Errorf("unsupported guild protocol version %d", header.ProtocolVersion)
	}

	switch header.Type {
	case TypeChatMessage:
		var message ChatMessage
		if err := json.Unmarshal(data, &message); err != nil {
			return nil, fmt.Errorf("decode chat message: %w", err)
		}
		return message, nil
	case TypeChatHeartbeat:
		var message ChatHeartbeat
		if err := json.Unmarshal(data, &message); err != nil {
			return nil, fmt.Errorf("decode chat heartbeat: %w", err)
		}
		return message, nil
	case TypeBBSPost:
		var message BBSPost
		if err := json.Unmarshal(data, &message); err != nil {
			return nil, fmt.Errorf("decode BBS post: %w", err)
		}
		return message, nil
	case TypeBBSTombstone:
		var message BBSTombstone
		if err := json.Unmarshal(data, &message); err != nil {
			return nil, fmt.Errorf("decode BBS tombstone: %w", err)
		}
		return message, nil
	default:
		return nil, fmt.Errorf("unknown guild message type %q", header.Type)
	}
}
