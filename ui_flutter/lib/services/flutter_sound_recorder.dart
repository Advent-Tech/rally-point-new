import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Alternative audio recorder using flutter_sound package
/// Use this if the record package doesn't work on your device
class AlternativeAudioRecorder {
  static AlternativeAudioRecorder? _instance;

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;

  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Audio level stream
  StreamSubscription? _recorderSubscription;
  double _currentLevel = 0.0;

  // Callbacks
  void Function()? onRecordingStarted;
  void Function(String? path, int durationMs)? onRecordingStopped;
  void Function(String error)? onRecordingError;
  void Function(double level)? onAudioLevelChanged;

  AlternativeAudioRecorder._internal();

  factory AlternativeAudioRecorder() {
    _instance ??= AlternativeAudioRecorder._internal();
    return _instance!;
  }

  static Future<AlternativeAudioRecorder> getInstance() async {
    _instance ??= AlternativeAudioRecorder._internal();
    if (!_instance!._isInitialized) {
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openRecorder();
      await _player!.openPlayer();

      // Enable audio level monitoring
      await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));

      _isInitialized = true;
      debugPrint('AlternativeAudioRecorder: Initialized with flutter_sound');
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Init error: $e');
      rethrow;
    }
  }

  bool get isRecording => _isRecording;
  double get currentLevel => _currentLevel;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    if (_isRecording) return false;

    try {
      if (!await requestPermission()) {
        onRecordingError?.call('Microphone permission denied');
        return false;
      }

      await _initialize();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/walkie_fs_$timestamp.aac';

      debugPrint('AlternativeAudioRecorder: Starting recording to $_currentRecordingPath');

      // Start recording with AAC codec
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
        sampleRate: 44100,
        numChannels: 1,
      );

      // Listen to audio levels
      _recorderSubscription = _recorder!.onProgress?.listen((e) {
        if (e.decibels != null) {
          // Convert decibels to 0-1 range (typically -120 to 0 dB)
          final db = e.decibels!;
          _currentLevel = ((db + 120) / 120).clamp(0.0, 1.0);
          onAudioLevelChanged?.call(_currentLevel);

          // Log levels periodically
          if (DateTime.now().millisecondsSinceEpoch % 500 < 100) {
            debugPrint('AlternativeAudioRecorder: Level: ${_currentLevel.toStringAsFixed(3)} (${db.toStringAsFixed(1)} dB)');
          }
        }
      });

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      onRecordingStarted?.call();

      debugPrint('AlternativeAudioRecorder: Recording started');
      return true;
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Start error: $e');
      onRecordingError?.call(e.toString());
      return false;
    }
  }

  Future<AlternativeRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _recorderSubscription?.cancel();
      _recorderSubscription = null;

      final path = await _recorder!.stopRecorder();
      _isRecording = false;

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      _recordingStartTime = null;

      if (path != null && path.isNotEmpty) {
        // Verify file exists
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('AlternativeAudioRecorder: Recording stopped');
          debugPrint('  - Path: $path');
          debugPrint('  - Duration: ${durationMs}ms');
          debugPrint('  - Size: $size bytes');

          onRecordingStopped?.call(path, durationMs);

          return AlternativeRecordingResult(
            path: path,
            durationMs: durationMs,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Stop error: $e');
      _isRecording = false;
      onRecordingError?.call(e.toString());
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      _recorderSubscription?.cancel();
      await _recorder?.stopRecorder();
      _isRecording = false;
      _recordingStartTime = null;

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      debugPrint('AlternativeAudioRecorder: Recording cancelled');
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Cancel error: $e');
    }
  }

  Future<bool> playFromFile(String path) async {
    try {
      await _player?.startPlayer(
        fromURI: path,
        codec: Codec.aacADTS,
      );
      return true;
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Play error: $e');
      return false;
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player?.stopPlayer();
    } catch (e) {
      debugPrint('AlternativeAudioRecorder: Stop playback error: $e');
    }
  }

  Future<void> dispose() async {
    await cancelRecording();
    await stopPlayback();
    await _recorder?.closeRecorder();
    await _player?.closePlayer();
    _instance = null;
  }
}

class AlternativeRecordingResult {
  final String path;
  final int durationMs;

  AlternativeRecordingResult({
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
