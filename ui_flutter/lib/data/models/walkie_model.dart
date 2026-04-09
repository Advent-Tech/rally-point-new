import 'package:json_annotation/json_annotation.dart';

part 'walkie_model.g.dart';

/// Represents a walkie-talkie channel/room
@JsonSerializable()
class WalkieChannel {
  final String id;
  final String name;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'channel_type')
  final String channelType; // 'team', 'group', 'direct'
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'participant_count')
  final int participantCount;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const WalkieChannel({
    required this.id,
    required this.name,
    required this.teamId,
    required this.channelType,
    this.isActive = true,
    this.participantCount = 0,
    this.createdAt,
  });

  factory WalkieChannel.fromJson(Map<String, dynamic> json) => _$WalkieChannelFromJson(json);
  Map<String, dynamic> toJson() => _$WalkieChannelToJson(this);
}

/// Represents a voice message in walkie-talkie
@JsonSerializable()
class WalkieMessage {
  final String id;
  @JsonKey(name: 'channel_id')
  final String channelId;
  @JsonKey(name: 'sender_id')
  final String senderId;
  @JsonKey(name: 'sender_name')
  final String senderName;
  @JsonKey(name: 'sender_avatar')
  final String? senderAvatar;
  @JsonKey(name: 'message_type')
  final String messageType; // 'voice', 'text', 'alert'
  @JsonKey(name: 'audio_url')
  final String? audioUrl;
  @JsonKey(name: 'audio_duration_ms')
  final int? audioDurationMs;
  final String? text;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'is_read')
  final bool isRead;

  const WalkieMessage({
    required this.id,
    required this.channelId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.messageType,
    this.audioUrl,
    this.audioDurationMs,
    this.text,
    required this.createdAt,
    this.isRead = false,
  });

  factory WalkieMessage.fromJson(Map<String, dynamic> json) {
    // Handle various field name formats from backend
    return WalkieMessage(
      id: json['id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? json['team_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['user_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ??
                  json['senderName']?.toString() ??
                  json['user_name']?.toString() ??
                  json['userName']?.toString() ??
                  json['display_name']?.toString() ??
                  'Unknown',
      senderAvatar: json['sender_avatar']?.toString() ?? json['avatar_url']?.toString(),
      messageType: json['message_type']?.toString() ?? json['type']?.toString() ?? 'voice',
      audioUrl: json['audio_url']?.toString() ?? json['message']?.toString(),
      audioDurationMs: _parseDuration(json['audio_duration_ms'] ?? json['duration']),
      text: json['text']?.toString() ?? json['message']?.toString(),
      createdAt: _parseDateTime(json['created_at'] ?? json['sent_at']),
      isRead: json['is_read'] == true,
    );
  }

  static int? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is int) return value > 100 ? value : value * 1000; // Convert seconds to ms if needed
    if (value is double) return value > 100 ? value.toInt() : (value * 1000).toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed > 100 ? parsed : parsed * 1000;
    return null;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
  Map<String, dynamic> toJson() => _$WalkieMessageToJson(this);

  String get formattedDuration {
    if (audioDurationMs == null || audioDurationMs == 0) return '';
    final seconds = audioDurationMs! ~/ 1000;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}

/// Represents a participant in a walkie channel
@JsonSerializable()
class WalkieParticipant {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'is_speaking')
  final bool isSpeaking;
  @JsonKey(name: 'is_muted')
  final bool isMuted;
  @JsonKey(name: 'is_online')
  final bool isOnline;
  @JsonKey(name: 'last_active')
  final DateTime? lastActive;

  const WalkieParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isSpeaking = false,
    this.isMuted = false,
    this.isOnline = true,
    this.lastActive,
  });

  factory WalkieParticipant.fromJson(Map<String, dynamic> json) => _$WalkieParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$WalkieParticipantToJson(this);
}

/// Represents an active walkie session
@JsonSerializable()
class WalkieSession {
  final String id;
  @JsonKey(name: 'channel_id')
  final String channelId;
  @JsonKey(name: 'channel_name')
  final String channelName;
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @JsonKey(name: 'ended_at')
  final DateTime? endedAt;
  final List<WalkieParticipant> participants;
  @JsonKey(name: 'message_count')
  final int messageCount;

  const WalkieSession({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.startedAt,
    this.endedAt,
    this.participants = const [],
    this.messageCount = 0,
  });

  factory WalkieSession.fromJson(Map<String, dynamic> json) => _$WalkieSessionFromJson(json);
  Map<String, dynamic> toJson() => _$WalkieSessionToJson(this);

  bool get isActive => endedAt == null;

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }
}

/// Request to start a walkie session
@JsonSerializable()
class StartWalkieRequest {
  @JsonKey(name: 'channel_id')
  final String channelId;
  @JsonKey(name: 'team_id')
  final String teamId;

  const StartWalkieRequest({
    required this.channelId,
    required this.teamId,
  });

  factory StartWalkieRequest.fromJson(Map<String, dynamic> json) => _$StartWalkieRequestFromJson(json);
  Map<String, dynamic> toJson() => _$StartWalkieRequestToJson(this);
}

/// Request to send a message
@JsonSerializable()
class SendWalkieMessageRequest {
  @JsonKey(name: 'channel_id')
  final String channelId;
  @JsonKey(name: 'message_type')
  final String messageType;
  @JsonKey(name: 'audio_data')
  final String? audioData; // Base64 encoded audio
  @JsonKey(name: 'audio_duration_ms')
  final int? audioDurationMs;
  final String? text;

  const SendWalkieMessageRequest({
    required this.channelId,
    required this.messageType,
    this.audioData,
    this.audioDurationMs,
    this.text,
  });

  factory SendWalkieMessageRequest.fromJson(Map<String, dynamic> json) => _$SendWalkieMessageRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SendWalkieMessageRequestToJson(this);
}
