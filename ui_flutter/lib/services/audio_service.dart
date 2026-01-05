import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Callback types for audio events
typedef OnRecordingStarted = void Function();
typedef OnRecordingStopped = void Function(String? audioPath, int durationMs);
typedef OnRecordingError = void Function(String error);
typedef OnPlaybackStarted = void Function(String audioId);
typedef OnPlaybackCompleted = void Function(String audioId);
typedef OnAudioLevelChanged = void Function(double level);

/// Service for audio recording and playback (walkie-talkie functionality)
class AudioService {
  static AudioService? _instance;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _levelTimer;

  // Callbacks
  OnRecordingStarted? onRecordingStarted;
  OnRecordingStopped? onRecordingStopped;
  OnRecordingError? onRecordingError;
  OnPlaybackStarted? onPlaybackStarted;
  OnPlaybackCompleted? onPlaybackCompleted;
  OnAudioLevelChanged? onAudioLevelChanged;

  AudioService._();

  factory AudioService() {
    _instance ??= AudioService._();
    return _instance!;
  }

  static Future<AudioService> getInstance() async {
    _instance ??= AudioService._();
    if (!_instance!._isInitialized) {
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        onPlaybackCompleted?.call('');
      }
    });

    _isInitialized = true;
    debugPrint('AudioService: Initialized');
  }

  /// Check if recording is in progress
  bool get isRecording => _isRecording;

  /// Check if playback is in progress
  bool get isPlaying => _isPlaying;

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start recording audio
  Future<bool> startRecording() async {
    if (_isRecording) return false;

    try {
      // Check permission
      if (!await hasMicrophonePermission()) {
        final granted = await requestMicrophonePermission();
        if (!granted) {
          onRecordingError?.call('Microphone permission denied');
          return false;
        }
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        onRecordingError?.call('Recording not available');
        return false;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/walkie_$timestamp.m4a';

      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Start monitoring audio levels
      _startLevelMonitoring();

      onRecordingStarted?.call();
      debugPrint('AudioService: Recording started');
      return true;
    } catch (e) {
      debugPrint('AudioService: Error starting recording: $e');
      onRecordingError?.call(e.toString());
      return false;
    }
  }

  /// Stop recording and return the audio file path
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _stopLevelMonitoring();

      final path = await _recorder.stop();
      _isRecording = false;

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      _recordingStartTime = null;

      if (path != null && path.isNotEmpty) {
        onRecordingStopped?.call(path, durationMs);
        debugPrint('AudioService: Recording stopped, duration: ${durationMs}ms');

        return RecordingResult(
          path: path,
          durationMs: durationMs,
        );
      }

      return null;
    } catch (e) {
      debugPrint('AudioService: Error stopping recording: $e');
      _isRecording = false;
      onRecordingError?.call(e.toString());
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      _stopLevelMonitoring();
      await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;

      // Delete the file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      debugPrint('AudioService: Recording cancelled');
    } catch (e) {
      debugPrint('AudioService: Error cancelling recording: $e');
    }
  }

  void _startLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      try {
        final amplitude = await _recorder.getAmplitude();
        // Convert to 0-1 range (amplitude.current is typically -160 to 0)
        final level = ((amplitude.current + 160) / 160).clamp(0.0, 1.0);
        onAudioLevelChanged?.call(level);
      } catch (_) {}
    });
  }

  void _stopLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  /// Play audio from URL
  Future<bool> playFromUrl(String url, {String? audioId}) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      await _player.setUrl(url);
      _isPlaying = true;
      onPlaybackStarted?.call(audioId ?? url);
      await _player.play();
      debugPrint('AudioService: Playing from URL');
      return true;
    } catch (e) {
      debugPrint('AudioService: Error playing from URL: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Play audio from file path
  Future<bool> playFromFile(String path, {String? audioId}) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      await _player.setFilePath(path);
      _isPlaying = true;
      onPlaybackStarted?.call(audioId ?? path);
      await _player.play();
      debugPrint('AudioService: Playing from file');
      return true;
    } catch (e) {
      debugPrint('AudioService: Error playing from file: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Play audio from base64 encoded data
  Future<bool> playFromBase64(String base64Data, {String? audioId}) async {
    try {
      final bytes = base64Decode(base64Data);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tempFile.writeAsBytes(bytes);

      return await playFromFile(tempFile.path, audioId: audioId);
    } catch (e) {
      debugPrint('AudioService: Error playing from base64: $e');
      return false;
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    if (!_isPlaying) return;

    try {
      await _player.stop();
      _isPlaying = false;
      debugPrint('AudioService: Playback stopped');
    } catch (e) {
      debugPrint('AudioService: Error stopping playback: $e');
    }
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    if (!_isPlaying) return;

    try {
      await _player.pause();
      debugPrint('AudioService: Playback paused');
    } catch (e) {
      debugPrint('AudioService: Error pausing playback: $e');
    }
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    try {
      await _player.play();
      debugPrint('AudioService: Playback resumed');
    } catch (e) {
      debugPrint('AudioService: Error resuming playback: $e');
    }
  }

  /// Get audio file as base64
  Future<String?> getRecordingAsBase64(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      debugPrint('AudioService: Error reading file as base64: $e');
    }
    return null;
  }

  /// Get audio file as bytes
  Future<Uint8List?> getRecordingAsBytes(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('AudioService: Error reading file: $e');
    }
    return null;
  }

  /// Clean up temporary audio files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('walkie_')) {
          await file.delete();
        }
      }
      debugPrint('AudioService: Temp files cleaned up');
    } catch (e) {
      debugPrint('AudioService: Error cleaning up: $e');
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await cancelRecording();
    await stopPlayback();
    await _recorder.dispose();
    await _player.dispose();
    _instance = null;
  }
}

/// Result of a recording session
class RecordingResult {
  final String path;
  final int durationMs;

  RecordingResult({
    required this.path,
    required this.durationMs,
  });

  String get formattedDuration {
    final seconds = durationMs ~/ 1000;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}
