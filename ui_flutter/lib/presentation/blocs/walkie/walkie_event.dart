part of 'walkie_bloc.dart';

abstract class WalkieEvent extends Equatable {
  const WalkieEvent();

  @override
  List<Object?> get props => [];
}

/// Load available channels
class WalkieLoadChannels extends WalkieEvent {
  final String teamId;
  final String? userId;
  final String? userName;

  const WalkieLoadChannels({
    required this.teamId,
    this.userId,
    this.userName,
  });

  @override
  List<Object?> get props => [teamId, userId, userName];
}

/// Join a channel
class WalkieJoinChannel extends WalkieEvent {
  final String channelId;
  final String channelName;

  const WalkieJoinChannel({
    required this.channelId,
    required this.channelName,
  });

  @override
  List<Object?> get props => [channelId, channelName];
}

/// Leave current channel
class WalkieLeaveChannel extends WalkieEvent {
  const WalkieLeaveChannel();
}

/// Start speaking (push-to-talk pressed)
class WalkieStartSpeaking extends WalkieEvent {
  const WalkieStartSpeaking();
}

/// Stop speaking (push-to-talk released)
class WalkieStopSpeaking extends WalkieEvent {
  const WalkieStopSpeaking();
}

/// Send a text message
class WalkieSendTextMessage extends WalkieEvent {
  final String text;

  const WalkieSendTextMessage({required this.text});

  @override
  List<Object?> get props => [text];
}

/// Receive a message from WebSocket
class WalkieMessageReceived extends WalkieEvent {
  final Map<String, dynamic> messageData;

  const WalkieMessageReceived({required this.messageData});

  @override
  List<Object?> get props => [messageData];
}

/// Participant status changed
class WalkieParticipantUpdated extends WalkieEvent {
  final String participantId;
  final bool? isSpeaking;
  final bool? isOnline;

  const WalkieParticipantUpdated({
    required this.participantId,
    this.isSpeaking,
    this.isOnline,
  });

  @override
  List<Object?> get props => [participantId, isSpeaking, isOnline];
}

/// Load message history
class WalkieLoadHistory extends WalkieEvent {
  final String channelId;
  final int limit;

  const WalkieLoadHistory({
    required this.channelId,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [channelId, limit];
}

/// Toggle mute
class WalkieToggleMute extends WalkieEvent {
  const WalkieToggleMute();
}

/// Send alert to channel
class WalkieSendAlert extends WalkieEvent {
  final String alertType; // 'emergency', 'attention', 'help'
  final String? message;

  const WalkieSendAlert({
    required this.alertType,
    this.message,
  });

  @override
  List<Object?> get props => [alertType, message];
}

/// Play a voice message
class WalkiePlayMessage extends WalkieEvent {
  final String messageId;

  const WalkiePlayMessage({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

/// Audio level changed during recording
class WalkieAudioLevelChanged extends WalkieEvent {
  final double level;

  const WalkieAudioLevelChanged({required this.level});

  @override
  List<Object?> get props => [level];
}

/// Internal: poll for new messages (WebSocket fallback)
class _WalkiePollMessages extends WalkieEvent {
  const _WalkiePollMessages();
}
