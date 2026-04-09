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
import '../../../services/supabase_service.dart';

part 'walkie_event.dart';
part 'walkie_state.dart';

class WalkieBloc extends Bloc<WalkieEvent, WalkieState> {
  ApiClient? _apiClient;
  AudioService? _audioService;
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentUserName;

  // Direct WebSocket connection to /ws/walkie
  WebSocket? _walkieSocket;
  StreamSubscription? _socketSubscription;

  // Audio recording state
  Timer? _speakingTimer;

  // Polling timer for new messages (WebSocket fallback)
  Timer? _pollTimer;

  // Audio level tracking for diagnostics
  List<double> _recordingAudioLevels = [];
  double _maxAudioLevel = 0.0;

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
    on<_WalkiePollMessages>(_onPollMessages);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _audioService = await AudioService.getInstance();

    // Setup audio callbacks
    _audioService!.onAudioLevelChanged = (level) {
      add(WalkieAudioLevelChanged(level: level));
    };

    _audioService!.onPlaybackCompleted = (audioId) {
      if (state is WalkieInChannel) {
        final currentState = state as WalkieInChannel;
        // Clear current speaker when playback ends
        add(
          WalkieParticipantUpdated(
            participantId: currentState.currentSpeaker?.userId ?? '',
            isSpeaking: false,
          ),
        );
      }
    };

    _isInitialized = true;
  }

  /// Get the walkie WebSocket URL
  String _getWalkieWsUrl(String teamId) {
    String baseUrl;
    if (kReleaseMode) {
      baseUrl = 'wss://backend.lightsquads.com';
    } else {
      final httpBase = ApiConstants.prodBaseUrl;
      baseUrl = httpBase
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
    }
    return '$baseUrl${ApiConstants.wsWalkie}?user_id=$_currentUserId&team_id=$teamId';
  }

  ApiClient get _api => _apiClient!;
  AudioService get _audio => _audioService!;

  /// Connect directly to /ws/walkie for real-time updates
  Future<void> _connectWebSocket(String teamId) async {
    await _disconnectWalkieSocket();

    if (_currentUserId == null) return;

    try {
      final wsUrl = _getWalkieWsUrl(teamId);

      _walkieSocket = await WebSocket.connect(wsUrl);

      _socketSubscription = _walkieSocket!.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) {
          debugPrint('WalkieBloc: WebSocket error: $error');
        },
        onDone: () {
          _walkieSocket = null;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('WalkieBloc: Failed to connect WebSocket: $e');
    }
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final type = json['type']?.toString();

      if (type == 'walkie_message' || type == 'new_message') {
        final msgData = json['data'] ?? json;
        if (msgData is Map<String, dynamic>) {
          add(WalkieMessageReceived(messageData: msgData));
        }
      } else if (type == 'speaking_start') {
        final msgData = json['data'] ?? json;
        add(
          WalkieParticipantUpdated(
            participantId: msgData['user_id']?.toString() ?? '',
            isSpeaking: true,
          ),
        );
      } else if (type == 'speaking_end') {
        final msgData = json['data'] ?? json;
        add(
          WalkieParticipantUpdated(
            participantId: msgData['user_id']?.toString() ?? '',
            isSpeaking: false,
          ),
        );
      }
    } catch (e) {
      debugPrint('WalkieBloc: Error parsing WebSocket message: $e');
    }
  }

  Future<void> _disconnectWalkieSocket() async {
    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_walkieSocket != null) {
      await _walkieSocket!.close();
      _walkieSocket = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      add(const _WalkiePollMessages());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
        emit(
          WalkieChannelsLoaded(
            channels: [
              WalkieChannel(
                id: event.teamId,
                name: 'Team Channel',
                teamId: event.teamId,
                channelType: 'team',
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Fallback: create default channel
      emit(
        WalkieChannelsLoaded(
          channels: [
            WalkieChannel(
              id: event.teamId,
              name: 'Team Channel',
              teamId: event.teamId,
              channelType: 'team',
            ),
          ],
        ),
      );
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
          'speaker_name': _currentUserName ?? 'Unknown',
          'speaker_id': _currentUserId ?? '',
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
              .map<WalkieParticipant>(
                (json) => WalkieParticipant.fromJson(json),
              )
              .toList();
        }

        emit(
          WalkieInChannel(
            channel: channel,
            participants: participants,
            messages: [],
          ),
        );

        // Connect to WebSocket for real-time updates
        _connectWebSocket(event.channelId);

        // Load message history
        add(WalkieLoadHistory(channelId: event.channelId));

        // Start polling as WebSocket fallback
        _startPolling();
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

      emit(WalkieInChannel(channel: channel, participants: [], messages: []));

      _connectWebSocket(event.channelId);

      // Load message history even in fallback path
      add(WalkieLoadHistory(channelId: event.channelId));

      // Start polling as WebSocket fallback
      _startPolling();
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

      // Stop polling and disconnect WebSocket
      _stopPolling();
      _disconnectWalkieSocket();

      await _api.post(
        ApiConstants.walkieEnd,
        data: {'channel_id': currentState.channel.id},
      );

      emit(WalkieInitial());
    } catch (e) {
      _stopPolling();
      _disconnectWalkieSocket();
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

      // Reset audio level tracking
      _recordingAudioLevels = [];
      _maxAudioLevel = 0.0;

      // Start actual audio recording
      final started = await _audio.startRecording();
      if (!started) {
        return;
      }

      emit(currentState.copyWith(isSpeaking: true, audioLevel: 0.0));

      // Notify others via WebSocket
      _walkieSocket?.add(
        jsonEncode({
          'type': 'speaking_start',
          'data': {
            'user_id': _currentUserId,
            'team_id': currentState.channel.id,
          },
        }),
      );
    } catch (e) {
      // Error starting recording
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

    emit(currentState.copyWith(isSpeaking: false, audioLevel: 0.0));

    // Notify others via WebSocket
    _walkieSocket?.add(
      jsonEncode({
        'type': 'speaking_end',
        'data': {'user_id': _currentUserId, 'team_id': currentState.channel.id},
      }),
    );

    try {
      await _initialize();

      // Stop actual audio recording
      final result = await _audio.stopRecording();

      if (result == null) {
        return;
      }

      // Verify file exists and has content
      final audioFile = File(result.path);
      if (!await audioFile.exists()) {
        return;
      }
      final fileSize = await audioFile.length();

      if (fileSize < 1000) {
        return;
      }

      // Only send if > 500ms
      if (result.durationMs < 500) {
        return;
      }

      // Recording verified working with record package + AAC-LC

      // Upload to Supabase
      String? audioUrl;
      try {
        audioUrl = await _uploadAudioToSupabase(
          result.path,
          currentState.channel.id,
        );
      } catch (e) {
        // Failed to upload to Supabase
      }

      if (audioUrl == null) {
        return;
      }

      // Send the audio message to backend
      final response = await _api.post(
        ApiConstants.walkieMessages,
        data: {
          'team_id': currentState.channel.teamId,
          'message': audioUrl,
          'message_type': 'audio',
          'duration': result.durationMs ~/ 1000, // Convert to seconds
          'sender_name':
              _currentUserName, // Include sender name for backend to use
          'sender_id': _currentUserId,
        },
      );

      // Add the sent message to local state so it shows immediately
      if (response.statusCode == 200 || response.statusCode == 201) {
        final messageData = response.data;
        final sentMessage = WalkieMessage(
          id:
              messageData['id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          channelId: currentState.channel.id,
          senderId:
              messageData['sender_id']?.toString() ?? _currentUserId ?? '',
          // Use _currentUserName first since backend returns hardcoded "User"
          senderName:
              _currentUserName ??
              messageData['sender_name']?.toString() ??
              'You',
          messageType: 'audio',
          audioUrl: result
              .path, // Use local file for immediate playback (Supabase URL sent to backend for others)
          audioDurationMs: result.durationMs,
          createdAt:
              DateTime.tryParse(messageData['sent_at']?.toString() ?? '') ??
              DateTime.now(),
        );

        // Get fresh state since emit was called earlier
        final freshState = state;
        if (freshState is WalkieInChannel) {
          final updatedMessages = [...freshState.messages, sentMessage];
          emit(freshState.copyWith(messages: updatedMessages));
        }
      }
    } catch (e) {
      // Error sending voice message
    }
  }

  /// Upload audio file directly to Supabase Storage
  /// Returns the public URL of the uploaded audio
  Future<String?> _uploadAudioToSupabase(
    String filePath,
    String channelId,
  ) async {
    try {
      final supabaseService = await SupabaseService.getInstance();

      final audioUrl = await supabaseService.uploadAudioFile(
        filePath: filePath,
        teamId: channelId,
      );

      if (audioUrl != null) {
        return audioUrl;
      }

      return null;
    } catch (e) {
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

      if (response.statusCode == 200 || response.statusCode == 201) {}
    } catch (e) {
      // Error sending text message
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

      // Find speaker if voice/audio message
      WalkieParticipant? currentSpeaker;
      if (message.messageType == 'voice' || message.messageType == 'audio') {
        currentSpeaker = currentState.participants.firstWhere(
          (p) => p.userId == message.senderId,
          orElse: () => WalkieParticipant(
            userId: message.senderId,
            displayName: message.senderName,
          ),
        );
      }

      emit(
        currentState.copyWith(
          messages: updatedMessages,
          currentSpeaker: currentSpeaker,
        ),
      );

      // Auto-play voice messages from others
      if ((message.messageType == 'voice' || message.messageType == 'audio') &&
          message.audioUrl != null &&
          message.senderId != _currentUserId) {
        final audioPath = message.audioUrl!;
        if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
          final filePath = audioPath.startsWith('file://')
              ? audioPath.substring(7)
              : audioPath;
          await _audio.playFromFile(filePath, audioId: message.id);
        } else if (audioPath.startsWith('http://') ||
            audioPath.startsWith('https://')) {
          await _audio.playFromUrl(audioPath, audioId: message.id);
        } else {
          await _audio.playFromFile(audioPath, audioId: message.id);
        }
      }

      // Clear current speaker after message duration
      if (message.audioDurationMs != null) {
        Future.delayed(Duration(milliseconds: message.audioDurationMs!), () {
          if (state is WalkieInChannel) {
            final s = state as WalkieInChannel;
            if (s.currentSpeaker?.userId == message.senderId) {
              add(
                WalkieParticipantUpdated(
                  participantId: message.senderId,
                  isSpeaking: false,
                ),
              );
            }
          }
        });
      }
    } catch (e) {
      // Error processing message
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
        // Don't set currentSpeaker during playback - it's only for live speaking
        // The "speaking" indicator should only show during actual live transmission

        // Check if it's a local file or URL
        final audioPath = message.audioUrl!;
        if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
          final filePath = audioPath.startsWith('file://')
              ? audioPath.substring(7)
              : audioPath;
          await _audio.playFromFile(filePath, audioId: message.id);
        } else if (audioPath.startsWith('http://') ||
            audioPath.startsWith('https://')) {
          await _audio.playFromUrl(audioPath, audioId: message.id);
        } else {
          // Assume local file
          await _audio.playFromFile(audioPath, audioId: message.id);
        }
      }
    } catch (e) {
      // Error playing message
    }
  }

  Future<void> _onAudioLevelChanged(
    WalkieAudioLevelChanged event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;
    if (!currentState.isSpeaking) return;

    // Track audio levels for diagnostics
    _recordingAudioLevels.add(event.level);
    if (event.level > _maxAudioLevel) {
      _maxAudioLevel = event.level;
    }

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

    emit(
      currentState.copyWith(
        participants: updatedParticipants,
        currentSpeaker: currentSpeaker,
        clearCurrentSpeaker: currentSpeaker == null,
      ),
    );
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

        // API returns newest-first (ORDER BY sent_at DESC).
        // Reverse so messages are stored oldest-first — matches how
        // locally appended messages work and the reversed ListView index.
        final orderedMessages = messages.reversed.toList();

        emit(currentState.copyWith(messages: orderedMessages));
      } else {
        // History request returned non-200 status
      }
    } catch (e) {
      // Error loading history
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
    } catch (e) {
      // Error sending alert
    }
  }

  Future<void> _onPollMessages(
    _WalkiePollMessages event,
    Emitter<WalkieState> emit,
  ) async {
    final currentState = state;
    if (currentState is! WalkieInChannel) return;

    try {
      await _initialize();

      final response = await _api.get(
        '/api/walkie/messages/team/${currentState.channel.id}',
        queryParameters: {'limit': 50},
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['messages'] ?? []);
        final serverMessages = data
            .map<WalkieMessage>((json) => WalkieMessage.fromJson(json))
            .toList();

        // Server returns newest-first, reverse to oldest-first
        final ordered = serverMessages.reversed.toList();

        // Only update if there are new messages
        final existingIds = currentState.messages.map((m) => m.id).toSet();
        final hasNew = ordered.any((m) => !existingIds.contains(m.id));

        if (hasNew) {
          // Merge: keep locally-added messages (with local file paths) and add new server messages
          final merged = <WalkieMessage>[];
          final mergedIds = <String>{};

          // First add all existing local messages
          for (final m in currentState.messages) {
            merged.add(m);
            mergedIds.add(m.id);
          }

          // Then add any new server messages not already present
          for (final m in ordered) {
            if (!mergedIds.contains(m.id)) {
              merged.add(m);
              mergedIds.add(m.id);
            }
          }

          // Sort by creation time
          merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          emit(currentState.copyWith(messages: merged));
        }
      }
    } catch (_) {
      // Polling errors are non-critical
    }
  }

  @override
  Future<void> close() {
    _speakingTimer?.cancel();
    _stopPolling();
    _disconnectWalkieSocket();
    _audioService?.dispose();
    return super.close();
  }
}
