// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatConversation _$ChatConversationFromJson(Map<String, dynamic> json) =>
    ChatConversation(
      id: json['id'] as String,
      type: $enumDecode(_$ConversationTypeEnumMap, json['type']),
      teamId: json['team_id'] as String?,
      name: json['name'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      lastMessage: json['last_message'] as String?,
      lastMessageBy: json['last_message_by'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => ChatParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ChatConversationToJson(ChatConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConversationTypeEnumMap[instance.type]!,
      'team_id': instance.teamId,
      'name': instance.name,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'last_message_at': instance.lastMessageAt?.toIso8601String(),
      'last_message': instance.lastMessage,
      'last_message_by': instance.lastMessageBy,
      'unread_count': instance.unreadCount,
      'participants': instance.participants,
    };

const _$ConversationTypeEnumMap = {
  ConversationType.direct: 'direct',
  ConversationType.team: 'team',
};

ChatParticipant _$ChatParticipantFromJson(Map<String, dynamic> json) =>
    ChatParticipant(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      role: $enumDecodeNullable(_$ParticipantRoleEnumMap, json['role']) ??
          ParticipantRole.member,
      joinedAt: json['joined_at'] == null
          ? null
          : DateTime.parse(json['joined_at'] as String),
      lastReadAt: json['last_read_at'] == null
          ? null
          : DateTime.parse(json['last_read_at'] as String),
      isOnline: json['is_online'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
    );

Map<String, dynamic> _$ChatParticipantToJson(ChatParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversation_id': instance.conversationId,
      'user_id': instance.userId,
      'user_name': instance.userName,
      'avatar_url': instance.avatarUrl,
      'role': _$ParticipantRoleEnumMap[instance.role]!,
      'joined_at': instance.joinedAt?.toIso8601String(),
      'last_read_at': instance.lastReadAt?.toIso8601String(),
      'is_online': instance.isOnline,
      'is_muted': instance.isMuted,
    };

const _$ParticipantRoleEnumMap = {
  ParticipantRole.member: 'member',
  ParticipantRole.admin: 'admin',
};

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String?,
      messageType:
          $enumDecodeNullable(_$ChatMessageTypeEnumMap, json['message_type']) ??
              ChatMessageType.text,
      content: json['content'] as String,
      mediaUrl: json['media_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      replyToId: json['reply_to_id'] as String?,
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      readBy: (json['read_by'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversation_id': instance.conversationId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'sender_avatar': instance.senderAvatar,
      'message_type': _$ChatMessageTypeEnumMap[instance.messageType]!,
      'content': instance.content,
      'media_url': instance.mediaUrl,
      'metadata': instance.metadata,
      'reply_to_id': instance.replyToId,
      'is_edited': instance.isEdited,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'read_by': instance.readBy,
    };

const _$ChatMessageTypeEnumMap = {
  ChatMessageType.text: 'text',
  ChatMessageType.image: 'image',
  ChatMessageType.file: 'file',
  ChatMessageType.location: 'location',
  ChatMessageType.system: 'system',
};
