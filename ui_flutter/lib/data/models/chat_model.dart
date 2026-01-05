import 'package:json_annotation/json_annotation.dart';

part 'chat_model.g.dart';

/// Chat conversation types
enum ConversationType {
  @JsonValue('direct')
  direct,
  @JsonValue('team')
  team,
}

/// Chat message types
enum ChatMessageType {
  @JsonValue('text')
  text,
  @JsonValue('image')
  image,
  @JsonValue('file')
  file,
  @JsonValue('location')
  location,
  @JsonValue('system')
  system,
}

/// Participant role
enum ParticipantRole {
  @JsonValue('member')
  member,
  @JsonValue('admin')
  admin,
}

/// Chat conversation model
@JsonSerializable()
class ChatConversation {
  final String id;
  final ConversationType type;
  @JsonKey(name: 'team_id')
  final String? teamId;
  final String? name;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'last_message_at')
  final DateTime? lastMessageAt;
  @JsonKey(name: 'last_message')
  final String? lastMessage;
  @JsonKey(name: 'last_message_by')
  final String? lastMessageBy;
  @JsonKey(name: 'unread_count')
  final int unreadCount;
  final List<ChatParticipant> participants;

  ChatConversation({
    required this.id,
    required this.type,
    this.teamId,
    this.name,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.lastMessage,
    this.lastMessageBy,
    this.unreadCount = 0,
    this.participants = const [],
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      _$ChatConversationFromJson(json);

  Map<String, dynamic> toJson() => _$ChatConversationToJson(this);

  /// Get display name for the conversation
  String getDisplayName(String currentUserId) {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    if (type == ConversationType.direct) {
      // For direct chats, show the other person's name
      final otherParticipant = participants.firstWhere(
        (p) => p.userId != currentUserId,
        orElse: () => participants.isNotEmpty ? participants.first : ChatParticipant(id: '', conversationId: '', userId: '', userName: 'Unknown'),
      );
      return otherParticipant.userName;
    }
    return 'Team Chat';
  }

  /// Get avatar for the conversation
  String? getAvatarUrl(String currentUserId) {
    if (type == ConversationType.direct) {
      final otherParticipant = participants.firstWhere(
        (p) => p.userId != currentUserId,
        orElse: () => participants.isNotEmpty ? participants.first : ChatParticipant(id: '', conversationId: '', userId: '', userName: 'Unknown'),
      );
      return otherParticipant.avatarUrl;
    }
    return null;
  }

  ChatConversation copyWith({
    String? id,
    ConversationType? type,
    String? teamId,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    String? lastMessage,
    String? lastMessageBy,
    int? unreadCount,
    List<ChatParticipant>? participants,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageBy: lastMessageBy ?? this.lastMessageBy,
      unreadCount: unreadCount ?? this.unreadCount,
      participants: participants ?? this.participants,
    );
  }
}

/// Chat participant model
@JsonSerializable()
class ChatParticipant {
  final String id;
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'user_name')
  final String userName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final ParticipantRole role;
  @JsonKey(name: 'joined_at')
  final DateTime? joinedAt;
  @JsonKey(name: 'last_read_at')
  final DateTime? lastReadAt;
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @JsonKey(name: 'is_muted')
  final bool isMuted;

  ChatParticipant({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.userName,
    this.avatarUrl,
    this.role = ParticipantRole.member,
    this.joinedAt,
    this.lastReadAt,
    this.isOnline = false,
    this.isMuted = false,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      _$ChatParticipantFromJson(json);

  Map<String, dynamic> toJson() => _$ChatParticipantToJson(this);

  ChatParticipant copyWith({
    String? id,
    String? conversationId,
    String? userId,
    String? userName,
    String? avatarUrl,
    ParticipantRole? role,
    DateTime? joinedAt,
    DateTime? lastReadAt,
    bool? isOnline,
    bool? isMuted,
  }) {
    return ChatParticipant(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}

/// Chat message model
@JsonSerializable()
class ChatMessage {
  final String id;
  @JsonKey(name: 'conversation_id')
  final String conversationId;
  @JsonKey(name: 'sender_id')
  final String senderId;
  @JsonKey(name: 'sender_name')
  final String senderName;
  @JsonKey(name: 'sender_avatar')
  final String? senderAvatar;
  @JsonKey(name: 'message_type')
  final ChatMessageType messageType;
  final String content;
  @JsonKey(name: 'media_url')
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'reply_to_id')
  final String? replyToId;
  @JsonKey(name: 'is_edited')
  final bool isEdited;
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;
  @JsonKey(name: 'read_by')
  final List<String> readBy;

  // Local state (not from server)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool isSending;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bool hasFailed;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.messageType = ChatMessageType.text,
    required this.content,
    this.mediaUrl,
    this.metadata,
    this.replyToId,
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
    this.readBy = const [],
    this.isSending = false,
    this.hasFailed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  /// Check if message is from current user
  bool isFromUser(String currentUserId) => senderId == currentUserId;

  /// Get formatted time
  String get formattedTime {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      return '${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt!.month}/${createdAt!.day}';
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    ChatMessageType? messageType,
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    String? replyToId,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? readBy,
    bool? isSending,
    bool? hasFailed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      metadata: metadata ?? this.metadata,
      replyToId: replyToId ?? this.replyToId,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readBy: readBy ?? this.readBy,
      isSending: isSending ?? this.isSending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }
}

/// Typing indicator model
class TypingIndicator {
  final String conversationId;
  final String userId;
  final String userName;
  final bool isTyping;
  final DateTime timestamp;

  TypingIndicator({
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.isTyping,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
