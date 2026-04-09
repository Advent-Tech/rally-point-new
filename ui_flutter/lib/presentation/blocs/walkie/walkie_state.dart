part of 'walkie_bloc.dart';

abstract class WalkieState extends Equatable {
  const WalkieState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class WalkieInitial extends WalkieState {}

/// Loading channels or session
class WalkieLoading extends WalkieState {}

/// Channels loaded, not in a session
class WalkieChannelsLoaded extends WalkieState {
  final List<WalkieChannel> channels;

  const WalkieChannelsLoaded({required this.channels});

  @override
  List<Object?> get props => [channels];
}

/// Active in a channel
class WalkieInChannel extends WalkieState {
  final WalkieChannel channel;
  final List<WalkieParticipant> participants;
  final List<WalkieMessage> messages;
  final bool isSpeaking;
  final bool isMuted;
  final WalkieParticipant? currentSpeaker;
  final double audioLevel;

  const WalkieInChannel({
    required this.channel,
    this.participants = const [],
    this.messages = const [],
    this.isSpeaking = false,
    this.isMuted = false,
    this.currentSpeaker,
    this.audioLevel = 0.0,
  });

  WalkieInChannel copyWith({
    WalkieChannel? channel,
    List<WalkieParticipant>? participants,
    List<WalkieMessage>? messages,
    bool? isSpeaking,
    bool? isMuted,
    WalkieParticipant? currentSpeaker,
    bool clearCurrentSpeaker = false,
    double? audioLevel,
  }) {
    return WalkieInChannel(
      channel: channel ?? this.channel,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      currentSpeaker: clearCurrentSpeaker ? null : (currentSpeaker ?? this.currentSpeaker),
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }

  @override
  List<Object?> get props => [channel, participants, messages, isSpeaking, isMuted, currentSpeaker, audioLevel];
}

/// Error state
class WalkieError extends WalkieState {
  final String message;

  const WalkieError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Speaking state for visual feedback
class WalkieSpeakingState extends WalkieState {
  final bool isRecording;
  final int durationMs;
  final double audioLevel;

  const WalkieSpeakingState({
    this.isRecording = false,
    this.durationMs = 0,
    this.audioLevel = 0.0,
  });

  @override
  List<Object?> get props => [isRecording, durationMs, audioLevel];
}
