// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'walkie_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalkieChannel _$WalkieChannelFromJson(Map<String, dynamic> json) =>
    WalkieChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      teamId: json['team_id'] as String,
      channelType: json['channel_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$WalkieChannelToJson(WalkieChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'team_id': instance.teamId,
      'channel_type': instance.channelType,
      'is_active': instance.isActive,
      'participant_count': instance.participantCount,
      'created_at': instance.createdAt?.toIso8601String(),
    };

WalkieMessage _$WalkieMessageFromJson(Map<String, dynamic> json) =>
    WalkieMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String?,
      messageType: json['message_type'] as String,
      audioUrl: json['audio_url'] as String?,
      audioDurationMs: (json['audio_duration_ms'] as num?)?.toInt(),
      text: json['text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );

Map<String, dynamic> _$WalkieMessageToJson(WalkieMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'channel_id': instance.channelId,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'sender_avatar': instance.senderAvatar,
      'message_type': instance.messageType,
      'audio_url': instance.audioUrl,
      'audio_duration_ms': instance.audioDurationMs,
      'text': instance.text,
      'created_at': instance.createdAt.toIso8601String(),
      'is_read': instance.isRead,
    };

WalkieParticipant _$WalkieParticipantFromJson(Map<String, dynamic> json) =>
    WalkieParticipant(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      isSpeaking: json['is_speaking'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? true,
      lastActive: json['last_active'] == null
          ? null
          : DateTime.parse(json['last_active'] as String),
    );

Map<String, dynamic> _$WalkieParticipantToJson(WalkieParticipant instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'is_speaking': instance.isSpeaking,
      'is_muted': instance.isMuted,
      'is_online': instance.isOnline,
      'last_active': instance.lastActive?.toIso8601String(),
    };

WalkieSession _$WalkieSessionFromJson(Map<String, dynamic> json) =>
    WalkieSession(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      channelName: json['channel_name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      participants: (json['participants'] as List<dynamic>?)
              ?.map(
                  (e) => WalkieParticipant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WalkieSessionToJson(WalkieSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'channel_id': instance.channelId,
      'channel_name': instance.channelName,
      'started_at': instance.startedAt.toIso8601String(),
      'ended_at': instance.endedAt?.toIso8601String(),
      'participants': instance.participants,
      'message_count': instance.messageCount,
    };

StartWalkieRequest _$StartWalkieRequestFromJson(Map<String, dynamic> json) =>
    StartWalkieRequest(
      channelId: json['channel_id'] as String,
      teamId: json['team_id'] as String,
    );

Map<String, dynamic> _$StartWalkieRequestToJson(StartWalkieRequest instance) =>
    <String, dynamic>{
      'channel_id': instance.channelId,
      'team_id': instance.teamId,
    };

SendWalkieMessageRequest _$SendWalkieMessageRequestFromJson(
        Map<String, dynamic> json) =>
    SendWalkieMessageRequest(
      channelId: json['channel_id'] as String,
      messageType: json['message_type'] as String,
      audioData: json['audio_data'] as String?,
      audioDurationMs: (json['audio_duration_ms'] as num?)?.toInt(),
      text: json['text'] as String?,
    );

Map<String, dynamic> _$SendWalkieMessageRequestToJson(
        SendWalkieMessageRequest instance) =>
    <String, dynamic>{
      'channel_id': instance.channelId,
      'message_type': instance.messageType,
      'audio_data': instance.audioData,
      'audio_duration_ms': instance.audioDurationMs,
      'text': instance.text,
    };
