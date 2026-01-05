import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/walkie_model.dart';
import '../../../services/audio_service.dart';
import '../../../services/websocket_service.dart';

part 'walkie_event.dart';
part 'walkie_state.dart';

class WalkieBloc extends Bloc<WalkieEvent, WalkieState> {
  ApiClient? _apiClient;
  AudioService? _audioService;
  WebSocketService? _wsService;
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentUserName;

  // WebSocket subscriptions
  StreamSubscription? _wsMessageSubscription;
  StreamSubscription? _wsSpeakingStartSubscription;
  StreamSubscription? _wsSpeakingEndSubscription;

  // Audio recording state
  Timer? _speakingTimer;
  int _speakingDurationMs = 0;

  WalkieBloc() : super(WalkieInitial()) {
    on<WalkieLoadChannels>(_onLoadChannels);
    on<WalkieJoinChannel>(_onJoinChannel);
    on<WalkieLeaveChannel>(_onLeaveChannel);
    on<WalkieStartSpeaking>(_onStartSpeaking);
    on<WalkieStopSpeaking>(_onStopSpeaking);
    on<WalkieSendTextMessage>(_onSendTextMessage);
    on<WalkieMessageReceived>(_onMessageReceived);
    on<WalkieParticipantUpdated>(_onParticipantUpdated);
    on<WalkieLoadHistory>(_onLoadHistory);
    on<WalkieToggleMute>(_onToggleMute);
    on<WalkieSendAlert>(_onSendAlert);
    on<WalkiePlayMessage>(_onPlayMessage);
    on<WalkieAudioLevelChanged>(_onAudioLevelChanged);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _audioService = await AudioService.getInstance();
    _wsService = WebSocketService();

    // Setup audio callbacks
    _audioService!.onAudioLevelChanged = (level) {
      add(WalkieAudioLevelChanged(level: level));
    };

    _audioService!.onPlaybackCompleted = (audioId) {
      debugPrint('WalkieBloc: Playback completed for $audioId');
      if (state is WalkieInChannel) {
        final currentState = state as WalkieInChannel;
        // Clear current speaker when playback ends
        add(WalkieParticipantUpdated(
          participantId: currentState.currentSpeaker?.userId ?? '',
          isSpeaking: false,
        ));
      }
    };

    _isInitialized = true;
  }

  ApiClient get _api => _apiClient!;
  AudioService get _audio => _audioService!;

  /// Connect to WebSocket and listen for messages
  void _connectWebSocket(String channelId) {
    _cancelWebSocketSubscriptions();

    _wsService?.connect();
    _wsService?.joinWalkieChannel(channelId);

    // Listen for walkie messages
    _wsMessageSubscription = _wsService?.messagesOfType(WsMessageType.walkieMessage).listen((wsMessage) {
      debugPrint('WalkieBloc: Received WebSocket message: ${wsMessage.data}');
      add(WalkieMessageReceived(messageData: wsMessage.data));
    });

    // Listen for participant updates
    _wsSpeakingStartSubscription = _wsService?.messagesOfType(WsMessageType.walkieSpeakingStart).listen((wsMessage) {
      add(WalkieParticipantUpdated(
        participantId: wsMessage.data['user_id']?.toString() ?? '',
        isSpeaking: true,
      ));
    });

    _wsSpeakingEndSubscription = _wsService?.messagesOfType(WsMessageType.walkieSpeakingEnd).listen((wsMessage) {
      add(WalkieParticipantUpdated(
        participantId: wsMessage.data['user_id']?.toString() ?? '',
        isSpeaking: false,
      ));
    });

    debugPrint('WalkieBloc: WebSocket connected for channel $channelId');
  }

  void _cancelWebSocketSubscriptions() {
    _wsMessageSubscription?.cancel();
    _wsMessageSubscription = null;
    _wsSpeakingStartSubscription?.cancel();
    _wsSpeakingStartSubscription = null;
    _wsSpeakingEndSubscription?.cancel();
    _wsSpeakingEndSubscription = null;
  }

  void _disconnectWebSocket(String channelId) {
    _cancelWebSocketSubscriptions();
    _wsService?.leaveWalkieChannel(channelId);
    debugPrint('WalkieBloc: WebSocket disconnected');
  }

  Future<void> _onLoadChannels(
    WalkieLoadChannels event,
    Emitter<WalkieState> emit,
  ) async {
    emit(WalkieLoading());

    try {
      await _initialize();
      _currentUserId = event.userId;
      _currentUserName = event.userName;

      final response = await _api.get(
        '${ApiConstants.teams}/${event.teamId}/channels',
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['channels'] ?? []);
        final channels = data
            .map<WalkieChannel>((json) => WalkieChannel.fromJson(json))
            .toList();
        emit(WalkieChannelsLoaded(channels: channels));
      } else {
        // If no channels endpoint, create a default team channel
        emit(WalkieChannelsLoaded(channels: [
          WalkieChannel(
            id: event.teamId,
            name: 'Team Channel',
            teamId: event.teamId,
            channelType: 'team',
          ),
        ]));
      }
    } catch (e) {
      // Fallback: create default channel
      emit(WalkieChannelsLoaded(channels: [
        WalkieChannel(
          id: event.teamId,
          name: 'Team Channel',
          teamId: event.teamId,
          channelType: 'team',
        ),
      ]));
    }
  }

  Future<void> _onJoinChannel(
    WalkieJoinChannel event,
    Emitter<WalkieState> emit,
  ) async {
    emit(WalkieLoading());

    try {
      await _initialize();

      // Request microphone permission
      final hasPermission = await _audio.requestMicrophonePermission();
      if (!hasPermission) {
        emit(const WalkieError(message: 'Microphone permission required'));
        return;
      }

      final response = await _api.post(
        ApiConstants.walkieStart,
        data: {
          'channel_id': event.channelId,
          'team_id': event.channelId, // Use channel ID as team ID for now
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final channelData = response.data['channel'] ?? response.data;
        final channel = WalkieChannel(
          id: event.channelId,
          name: event.channelName,
          teamId: channelData['team_id']?.toString() ?? event.channelId,
          channelType: channelData['channel_type']?.toString() ?? 'team',
        );

        // Get participants
        List<WalkieParticipant> participants = [];
        if (response.data['participants'] != null) {
          participants = (response.data['participants'] as List)
              .map<WalkieParticipant>((json) => WalkieParticipant.fromJson(json))
              .toList();
        }

        emit(WalkieInChannel(
          channel: channel,
          participants: participants,
          messages: [],
        ));

        // Connect to WebSocket for real-time updates
        _connectWebSocket(event.channelId);

        // Load message history
        add(WalkieLoadHistory(channelId: event.channelId));
      } else {
        emit(const WalkieError(message: 'Failed to join channel'));
      }
    } catch (e) {
      // Still allow joining even if API fails
      final channel = WalkieChannel(
        id: event.channelId,
        name: event.channelName,
        teamId: event.channelId,
        channelType: 'team',
      );

      emit(WalkieInChannel(
        channel: channel,
        participants: [],
        messages: [],
      ));

      _connectWebSocket(event.channelId);
      debugPrint('WalkieBloc: Joined channel with fallback: $e');
    }
  }

  Future<void> _onLeaveChannel(
    WalkieLeaveChannel event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      // Disconnect WebSocket first
      _disconnectWebSocket(currentState.channel.id);

      await _api.post(
        ApiConstants.walkieEnd,
        data: {
          'channel_id': currentState.channel.id,
        },
      );

      emit(WalkieInitial());
    } catch (e) {
      _disconnectWebSocket(currentState.channel.id);
      emit(WalkieInitial());
    }
  }

  Future<void> _onStartSpeaking(
    WalkieStartSpeaking event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;
    if (currentState.isMuted) return;

    try {
      await _initialize();

      // Start actual audio recording
      final started = await _audio.startRecording();
      if (!started) {
        debugPrint('WalkieBloc: Failed to start recording');
        return;
      }

      // Start recording timer
      _speakingDurationMs = 0;
      _speakingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _speakingDurationMs += 100;
      });

      emit(currentState.copyWith(
        isSpeaking: true,
        audioLevel: 0.0,
      ));

      // Notify others via WebSocket
      _wsService?.startSpeaking(currentState.channel.id);

      debugPrint('WalkieBloc: Started speaking with audio recording');
    } catch (e) {
      debugPrint('WalkieBloc: Error starting recording: $e');
    }
  }

  Future<void> _onStopSpeaking(
    WalkieStopSpeaking event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    _speakingTimer?.cancel();
    _speakingTimer = null;

    final durationMs = _speakingDurationMs;
    _speakingDurationMs = 0;

    emit(currentState.copyWith(isSpeaking: false, audioLevel: 0.0));

    // Notify others via WebSocket
    _wsService?.stopSpeaking(currentState.channel.id);

    try {
      await _initialize();

      // Stop actual audio recording
      final result = await _audio.stopRecording();

      if (result == null) {
        debugPrint('WalkieBloc: No recording result');
        return;
      }

      debugPrint('WalkieBloc: Recording stopped, duration: ${result.durationMs}ms, path: ${result.path}');

      // Only send if > 500ms
      if (result.durationMs < 500) {
        debugPrint('WalkieBloc: Recording too short, discarding');
        return;
      }

      // Upload to Supabase
      String? audioUrl;
      try {
        audioUrl = await _uploadAudioToSupabase(result.path, currentState.channel.id);
        debugPrint('WalkieBloc: Audio uploaded to: $audioUrl');
      } catch (e) {
        debugPrint('WalkieBloc: Failed to upload to Supabase: $e');
        // Continue with local file as fallback
      }

      // Send the audio message to backend
      final response = await _api.post(
        ApiConstants.walkieMessages,
        data: {
          'team_id': currentState.channel.teamId,
          'message': audioUrl ?? result.path,
          'message_type': 'audio',
          'duration': result.durationMs ~/ 1000, // Convert to seconds
        },
      );

      debugPrint('WalkieBloc: Voice message sent successfully');

      // Add the sent message to local state so it shows immediately
      if (response.statusCode == 200 || response.statusCode == 201) {
        final messageData = response.data;
        final sentMessage = WalkieMessage(
          id: messageData['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          channelId: currentState.channel.id,
          senderId: messageData['sender_id']?.toString() ?? _currentUserId ?? '',
          senderName: messageData['sender_name']?.toString() ?? _currentUserName ?? 'You',
          messageType: 'audio',
          audioUrl: audioUrl ?? result.path,
          audioDurationMs: result.durationMs,
          createdAt: DateTime.tryParse(messageData['sent_at']?.toString() ?? '') ?? DateTime.now(),
        );

        // Get fresh state since emit was called earlier
        final freshState = state;
        if (freshState is WalkieInChannel) {
          final updatedMessages = [...freshState.messages, sentMessage];
          emit(freshState.copyWith(messages: updatedMessages));
          debugPrint('WalkieBloc: Added sent message to local state');
        }
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error sending voice message: $e');
    }
  }

  /// Upload audio file to backend storage
  /// TODO: Add supabase_flutter to pubspec.yaml and implement Supabase upload
  Future<String?> _uploadAudioToSupabase(String filePath, String channelId) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }

      final bytes = await file.readAsBytes();
      final fileName = 'walkie-talkie/$channelId/${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Upload via backend API instead of direct Supabase
      // The backend will handle Supabase upload
      final response = await _api.post(
        '/api/walkie/upload',
        data: {
          'file_name': fileName,
          'content_type': 'audio/mp4',
          'audio_data': base64Encode(bytes),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint('WalkieBloc: Audio upload error: $e');
      rethrow;
    }
  }

  Future<void> _onSendTextMessage(
    WalkieSendTextMessage event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      final response = await _api.post(
        ApiConstants.walkieMessages,
        data: {
          'team_id': currentState.channel.teamId,
          'message': event.text,
          'message_type': 'text',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('WalkieBloc: Text message sent');
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error sending text message: $e');
    }
  }

  Future<void> _onMessageReceived(
    WalkieMessageReceived event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      final message = WalkieMessage.fromJson(event.messageData);
      final updatedMessages = [...currentState.messages, message];

      // Find speaker if voice message
      WalkieParticipant? currentSpeaker;
      if (message.messageType == 'voice') {
        currentSpeaker = currentState.participants.firstWhere(
          (p) => p.userId == message.senderId,
          orElse: () => WalkieParticipant(
            userId: message.senderId,
            displayName: message.senderName,
          ),
        );
      }

      emit(currentState.copyWith(
        messages: updatedMessages,
        currentSpeaker: currentSpeaker,
      ));

      // Auto-play voice messages from others
      if (message.messageType == 'voice' &&
          message.audioUrl != null &&
          message.senderId != _currentUserId) {
        debugPrint('WalkieBloc: Auto-playing voice message from ${message.senderName}');
        await _audio.playFromUrl(message.audioUrl!, audioId: message.id);
      }

      // Clear current speaker after message duration
      if (message.audioDurationMs != null) {
        Future.delayed(Duration(milliseconds: message.audioDurationMs!), () {
          if (state is WalkieInChannel) {
            final s = state as WalkieInChannel;
            if (s.currentSpeaker?.userId == message.senderId) {
              add(WalkieParticipantUpdated(
                participantId: message.senderId,
                isSpeaking: false,
              ));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error processing message: $e');
    }
  }

  Future<void> _onPlayMessage(
    WalkiePlayMessage event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      final message = currentState.messages.firstWhere(
        (m) => m.id == event.messageId,
      );

      if (message.audioUrl != null) {
        // Update current speaker
        final speaker = currentState.participants.firstWhere(
          (p) => p.userId == message.senderId,
          orElse: () => WalkieParticipant(
            userId: message.senderId,
            displayName: message.senderName,
          ),
        );

        emit(currentState.copyWith(currentSpeaker: speaker));

        await _audio.playFromUrl(message.audioUrl!, audioId: message.id);
        debugPrint('WalkieBloc: Playing message ${message.id}');
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error playing message: $e');
    }
  }

  Future<void> _onAudioLevelChanged(
    WalkieAudioLevelChanged event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;
    if (!currentState.isSpeaking) return;

    emit(currentState.copyWith(audioLevel: event.level));
  }

  Future<void> _onParticipantUpdated(
    WalkieParticipantUpdated event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    final updatedParticipants = currentState.participants.map((p) {
      if (p.userId == event.participantId) {
        return WalkieParticipant(
          userId: p.userId,
          displayName: p.displayName,
          avatarUrl: p.avatarUrl,
          isSpeaking: event.isSpeaking ?? p.isSpeaking,
          isMuted: p.isMuted,
          isOnline: event.isOnline ?? p.isOnline,
          lastActive: p.lastActive,
        );
      }
      return p;
    }).toList();

    // Update current speaker
    WalkieParticipant? currentSpeaker = currentState.currentSpeaker;
    if (event.isSpeaking == true) {
      currentSpeaker = updatedParticipants.firstWhere(
        (p) => p.userId == event.participantId,
        orElse: () => currentState.currentSpeaker!,
      );
    } else if (event.isSpeaking == false &&
               currentState.currentSpeaker?.userId == event.participantId) {
      currentSpeaker = null;
    }

    emit(currentState.copyWith(
      participants: updatedParticipants,
      currentSpeaker: currentSpeaker,
      clearCurrentSpeaker: currentSpeaker == null,
    ));
  }

  Future<void> _onLoadHistory(
    WalkieLoadHistory event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      final response = await _api.get(
        '/api/walkie/messages/team/${event.channelId}',
        queryParameters: {'limit': event.limit},
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['messages'] ?? []);
        final messages = data
            .map<WalkieMessage>((json) => WalkieMessage.fromJson(json))
            .toList();

        emit(currentState.copyWith(messages: messages));
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error loading history: $e');
    }
  }

  Future<void> _onToggleMute(
    WalkieToggleMute event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    emit(currentState.copyWith(isMuted: !currentState.isMuted));
  }

  Future<void> _onSendAlert(
    WalkieSendAlert event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      await _api.post(
        ApiConstants.walkieMessages,
        data: {
          'team_id': currentState.channel.teamId,
          'message_type': 'alert',
          'message': event.alertType,
          if (event.message != null) 'text': event.message,
        },
      );

      debugPrint('WalkieBloc: Alert sent: ${event.alertType}');
    } catch (e) {
      debugPrint('WalkieBloc: Error sending alert: $e');
    }
  }

  @override
  Future<void> close() {
    _speakingTimer?.cancel();
    _cancelWebSocketSubscriptions();
    _audioService?.dispose();
    return super.close();
  }
}
