import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/walkie_model.dart';
import '../../../services/audio_service.dart';
import '../../../services/websocket_service.dart';
import '../../../services/supabase_service.dart';

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

      // Reset audio level tracking
      _recordingAudioLevels = [];
      _maxAudioLevel = 0.0;

      // Start actual audio recording
      final started = await _audio.startRecording();
      if (!started) {
        debugPrint('WalkieBloc: Failed to start recording');
        return;
      }

      emit(currentState.copyWith(
        isSpeaking: true,
        audioLevel: 0.0,
      ));

      debugPrint('WalkieBloc: Audio level tracking started - watch for levels during recording');

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

      // Log audio level summary for diagnostics
      if (_recordingAudioLevels.isNotEmpty) {
        final avgLevel = _recordingAudioLevels.reduce((a, b) => a + b) / _recordingAudioLevels.length;
        final nonZeroLevels = _recordingAudioLevels.where((l) => l > 0.05).length;
        debugPrint('WalkieBloc: AUDIO DIAGNOSTIC SUMMARY:');
        debugPrint('  - Samples collected: ${_recordingAudioLevels.length}');
        debugPrint('  - Max level: ${_maxAudioLevel.toStringAsFixed(3)}');
        debugPrint('  - Average level: ${avgLevel.toStringAsFixed(3)}');
        debugPrint('  - Samples > 0.05: $nonZeroLevels (${(nonZeroLevels / _recordingAudioLevels.length * 100).toStringAsFixed(1)}%)');
        if (_maxAudioLevel < 0.1) {
          debugPrint('  - WARNING: Very low audio levels detected! Microphone may not be capturing sound.');
          debugPrint('  - Try: 1) Speak louder, 2) Check mic permission, 3) Check if another app is using mic');
        }
      } else {
        debugPrint('WalkieBloc: WARNING - No audio level samples collected during recording!');
      }

      // Verify file exists and has content
      final audioFile = File(result.path);
      if (!await audioFile.exists()) {
        debugPrint('WalkieBloc: Audio file does not exist!');
        return;
      }
      final fileSize = await audioFile.length();
      debugPrint('WalkieBloc: Audio file size: $fileSize bytes');

      // Log first bytes to verify file header
      try {
        final bytes = await audioFile.readAsBytes();
        if (bytes.length >= 12) {
          final header = bytes.sublist(0, 12);
          debugPrint('WalkieBloc: File header (first 12 bytes): $header');
          // WAV files start with "RIFF"
          final headerStr = String.fromCharCodes(header.sublist(0, 4));
          debugPrint('WalkieBloc: Header string: $headerStr');
        }
      } catch (e) {
        debugPrint('WalkieBloc: Error reading file header: $e');
      }

      // Analyze WAV file content to check for actual audio
      // This is more reliable than getAmplitude() which doesn't work on some devices
      debugPrint('WalkieBloc: Analyzing WAV file for audio content...');
      final analysis = await AudioService.analyzeWavFile(result.path);
      if (analysis.hasAudio) {
        debugPrint('WalkieBloc: ✓ WAV file contains audio!');
        debugPrint('  - Max amplitude: ${(analysis.maxAmplitude * 100).toStringAsFixed(1)}%');
        debugPrint('  - Non-silent: ${analysis.percentNonSilent.toStringAsFixed(1)}%');
      } else {
        debugPrint('WalkieBloc: ✗ WAV file appears to be silent or empty');
        if (analysis.error != null) {
          debugPrint('  - Error: ${analysis.error}');
        }
        debugPrint('  - Max amplitude: ${(analysis.maxAmplitude * 100).toStringAsFixed(1)}%');
        debugPrint('  - This confirms microphone is NOT capturing audio on this device');
      }

      if (fileSize < 1000) {
        debugPrint('WalkieBloc: Audio file too small ($fileSize bytes), likely empty');
        return;
      }

      // Only send if > 500ms
      if (result.durationMs < 500) {
        debugPrint('WalkieBloc: Recording too short, discarding');
        return;
      }

      // Upload to Supabase
      String? audioUrl;
      debugPrint('WalkieBloc: Starting Supabase upload process...');
      try {
        debugPrint('WalkieBloc: Calling _uploadAudioToSupabase with path: ${result.path}, channelId: ${currentState.channel.id}');
        audioUrl = await _uploadAudioToSupabase(result.path, currentState.channel.id);
        if (audioUrl != null) {
          debugPrint('WalkieBloc: Audio uploaded successfully to: $audioUrl');
        } else {
          debugPrint('WalkieBloc: Upload returned null - will use local path as fallback');
        }
      } catch (e, stackTrace) {
        debugPrint('WalkieBloc: Failed to upload to Supabase: $e');
        debugPrint('WalkieBloc: Stack trace: $stackTrace');
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
          'sender_name': _currentUserName, // Include sender name for backend to use
          'sender_id': _currentUserId,
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
          // Use _currentUserName first since backend returns hardcoded "User"
          senderName: _currentUserName ?? messageData['sender_name']?.toString() ?? 'You',
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

  /// Upload audio file directly to Supabase Storage
  /// Returns the public URL of the uploaded audio
  Future<String?> _uploadAudioToSupabase(String filePath, String channelId) async {
    debugPrint('WalkieBloc._uploadAudioToSupabase: ENTRY');
    debugPrint('WalkieBloc._uploadAudioToSupabase: filePath=$filePath');
    debugPrint('WalkieBloc._uploadAudioToSupabase: channelId=$channelId');

    try {
      debugPrint('WalkieBloc._uploadAudioToSupabase: Getting SupabaseService instance...');
      final supabaseService = await SupabaseService.getInstance();
      debugPrint('WalkieBloc._uploadAudioToSupabase: SupabaseService instance obtained successfully');

      debugPrint('WalkieBloc._uploadAudioToSupabase: Calling uploadAudioFile...');
      final audioUrl = await supabaseService.uploadAudioFile(
        filePath: filePath,
        teamId: channelId,
      );
      debugPrint('WalkieBloc._uploadAudioToSupabase: uploadAudioFile returned: $audioUrl');

      if (audioUrl != null) {
        debugPrint('WalkieBloc._uploadAudioToSupabase: SUCCESS - URL: $audioUrl');
        return audioUrl;
      }

      debugPrint('WalkieBloc._uploadAudioToSupabase: Upload returned null');
      return null;
    } catch (e, stackTrace) {
      debugPrint('WalkieBloc._uploadAudioToSupabase: ERROR: $e');
      debugPrint('WalkieBloc._uploadAudioToSupabase: Stack: $stackTrace');
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

      emit(currentState.copyWith(
        messages: updatedMessages,
        currentSpeaker: currentSpeaker,
      ));

      // Auto-play voice messages from others
      if ((message.messageType == 'voice' || message.messageType == 'audio') &&
          message.audioUrl != null &&
          message.senderId != _currentUserId) {
        debugPrint('WalkieBloc: Auto-playing voice message from ${message.senderName}');
        final audioPath = message.audioUrl!;
        if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
          final filePath = audioPath.startsWith('file://') ? audioPath.substring(7) : audioPath;
          await _audio.playFromFile(filePath, audioId: message.id);
        } else if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
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
        // Don't set currentSpeaker during playback - it's only for live speaking
        // The "speaking" indicator should only show during actual live transmission

        // Check if it's a local file or URL
        final audioPath = message.audioUrl!;
        if (audioPath.startsWith('/') || audioPath.startsWith('file://')) {
          final filePath = audioPath.startsWith('file://') ? audioPath.substring(7) : audioPath;
          await _audio.playFromFile(filePath, audioId: message.id);
        } else if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
          await _audio.playFromUrl(audioPath, audioId: message.id);
        } else {
          // Assume local file
          await _audio.playFromFile(audioPath, audioId: message.id);
        }
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

    // Track audio levels for diagnostics
    _recordingAudioLevels.add(event.level);
    if (event.level > _maxAudioLevel) {
      _maxAudioLevel = event.level;
    }

    // Log every 5th sample (every 500ms) to avoid log spam
    if (_recordingAudioLevels.length % 5 == 0) {
      debugPrint('WalkieBloc: Audio level: ${event.level.toStringAsFixed(3)} (max so far: ${_maxAudioLevel.toStringAsFixed(3)})');
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
