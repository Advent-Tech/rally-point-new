import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;

/// Callback types for audio events
typedef OnRecordingStarted = void Function();
typedef OnRecordingStopped = void Function(String? audioPath, int durationMs);
typedef OnRecordingError = void Function(String error);
typedef OnPlaybackStarted = void Function(String audioId);
typedef OnPlaybackCompleted = void Function(String audioId);
typedef OnAudioLevelChanged = void Function(double level);

/// Service for audio recording and playback (walkie-talkie functionality)
/// Supports both 'record' package and 'flutter_sound' as fallback
class AudioService {
  static AudioService? _instance;

  // Primary recorder (record package)
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Alternative recorder (flutter_sound) - used if record package fails
  fs.FlutterSoundRecorder? _flutterSoundRecorder;
  static bool useFlutterSound = true; // Using flutter_sound - record package has issues on some devices
  StreamSubscription? _flutterSoundSubscription;

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

      // Use flutter_sound if enabled (fallback for devices where record package fails)
      if (useFlutterSound) {
        return await _startRecordingWithFlutterSound();
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        onRecordingError?.call('Recording not available');
        return false;
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use WAV format for better Android compatibility
      // Some devices have issues with AAC encoder not capturing audio
      _currentRecordingPath = '${tempDir.path}/walkie_$timestamp.wav';

      debugPrint('AudioService: Starting recording to: $_currentRecordingPath');
      debugPrint('AudioService: Using record package (set useFlutterSound=true to use flutter_sound)');

      // Check available input devices
      try {
        final devices = await _recorder.listInputDevices();
        debugPrint('AudioService: Available input devices: ${devices.length}');
        for (final device in devices) {
          debugPrint('  - Device: ${device.label} (id: ${device.id})');
        }
      } catch (e) {
        debugPrint('AudioService: Could not list input devices: $e');
      }

      // Try different audio sources - the record package has issues on some devices
      // List of sources to try in order of preference
      final audioSources = [
        ('voiceRecognition', AndroidAudioSource.voiceRecognition),
        ('camcorder', AndroidAudioSource.camcorder),
        ('mic', AndroidAudioSource.mic),
        ('default', AndroidAudioSource.defaultSource),
      ];

      bool started = false;
      String usedSource = 'none';

      for (final (name, source) in audioSources) {
        try {
          debugPrint('AudioService: Trying audio source: $name');
          await _recorder.start(
            RecordConfig(
              encoder: AudioEncoder.wav,
              numChannels: 1,
              sampleRate: 44100,
              androidConfig: AndroidRecordConfig(
                audioSource: source,
              ),
            ),
            path: _currentRecordingPath!,
          );
          started = true;
          usedSource = name;
          debugPrint('AudioService: Successfully started with source: $name');
          break;
        } catch (e) {
          debugPrint('AudioService: Failed with source $name: $e');
          // Try next source
        }
      }

      if (!started) {
        // Last resort: try without any Android config
        debugPrint('AudioService: Trying without Android config...');
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            numChannels: 1,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );
        usedSource = 'default (no android config)';
      }

      debugPrint('AudioService: Recorder started with source: $usedSource');

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

    // Use flutter_sound stop if enabled
    if (useFlutterSound) {
      return await _stopRecordingWithFlutterSound();
    }

    try {
      _stopLevelMonitoring();

      debugPrint('AudioService: Stopping recording...');
      final path = await _recorder.stop();
      _isRecording = false;

      // Small delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 200));

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

  // ============ Flutter Sound Alternative Methods ============

  /// Initialize flutter_sound recorder
  Future<void> _initFlutterSound() async {
    if (_flutterSoundRecorder != null) return;

    _flutterSoundRecorder = fs.FlutterSoundRecorder();
    await _flutterSoundRecorder!.openRecorder();
    await _flutterSoundRecorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
    debugPrint('AudioService: flutter_sound initialized');
  }

  /// Start recording with flutter_sound
  Future<bool> _startRecordingWithFlutterSound() async {
    try {
      await _initFlutterSound();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use WAV format for better compatibility and easier debugging
      _currentRecordingPath = '${tempDir.path}/walkie_fs_$timestamp.wav';

      debugPrint('AudioService: Starting recording with flutter_sound');
      debugPrint('AudioService: Path: $_currentRecordingPath');

      // Try voice_communication audio source - works better for VoIP-style apps
      // This enables acoustic echo cancellation and noise suppression
      debugPrint('AudioService: Trying voice_communication audio source...');
      try {
        await _flutterSoundRecorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: fs.Codec.pcm16WAV,
          sampleRate: 16000, // Lower sample rate often works better for voice
          numChannels: 1,
          audioSource: fs.AudioSource.voice_communication,
        );
        debugPrint('AudioService: Started with voice_communication source');
      } catch (e) {
        debugPrint('AudioService: voice_communication failed: $e, trying default...');
        // Fallback to default audio source
        await _flutterSoundRecorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: fs.Codec.pcm16WAV,
          sampleRate: 16000,
          numChannels: 1,
        );
        debugPrint('AudioService: Started with default source');
      }

      // Listen to audio levels with detailed logging
      int levelCount = 0;
      double maxDbSeen = -160.0;
      _flutterSoundSubscription = _flutterSoundRecorder!.onProgress?.listen((e) {
        levelCount++;
        if (e.decibels != null) {
          final db = e.decibels!;
          if (db > maxDbSeen) maxDbSeen = db;

          // Convert decibels to 0-1 range
          // flutter_sound typically reports -160 to 0 dB
          final level = ((db + 160) / 160).clamp(0.0, 1.0);

          // Log every 10th sample for diagnostics
          if (levelCount % 10 == 0) {
            debugPrint('AudioService: flutter_sound dB: ${db.toStringAsFixed(1)}, level: ${level.toStringAsFixed(3)}, maxDb: ${maxDbSeen.toStringAsFixed(1)}');
          }

          onAudioLevelChanged?.call(level);
        } else {
          debugPrint('AudioService: flutter_sound progress - no decibels data');
        }
      });

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      onRecordingStarted?.call();

      debugPrint('AudioService: flutter_sound recording started with PCM16/WAV codec');
      return true;
    } catch (e) {
      debugPrint('AudioService: flutter_sound start error: $e');
      onRecordingError?.call(e.toString());
      return false;
    }
  }

  /// Stop recording with flutter_sound
  Future<RecordingResult?> _stopRecordingWithFlutterSound() async {
    try {
      _flutterSoundSubscription?.cancel();
      _flutterSoundSubscription = null;

      debugPrint('AudioService: Stopping flutter_sound recording...');
      final path = await _flutterSoundRecorder!.stopRecorder();
      _isRecording = false;

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      _recordingStartTime = null;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('AudioService: flutter_sound recording stopped');
          debugPrint('  - Path: $path');
          debugPrint('  - Duration: ${durationMs}ms');
          debugPrint('  - Size: $size bytes');

          onRecordingStopped?.call(path, durationMs);

          return RecordingResult(
            path: path,
            durationMs: durationMs,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('AudioService: flutter_sound stop error: $e');
      _isRecording = false;
      onRecordingError?.call(e.toString());
      return null;
    }
  }

  // ============ End Flutter Sound Methods ============

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

  /// Analyze WAV file to check if it contains actual audio
  /// Returns audio analysis info (since getAmplitude may not work on some devices)
  static Future<AudioAnalysisResult> analyzeWavFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return AudioAnalysisResult(hasAudio: false, error: 'File not found');
      }

      final bytes = await file.readAsBytes();
      if (bytes.length < 44) {
        return AudioAnalysisResult(hasAudio: false, error: 'File too small for WAV');
      }

      // WAV header: first 4 bytes should be "RIFF"
      final riff = String.fromCharCodes(bytes.sublist(0, 4));
      if (riff != 'RIFF') {
        return AudioAnalysisResult(hasAudio: false, error: 'Not a valid WAV file');
      }

      // Get audio data (skip 44-byte header for standard WAV)
      final audioData = bytes.sublist(44);
      if (audioData.isEmpty) {
        return AudioAnalysisResult(hasAudio: false, error: 'No audio data');
      }

      // Analyze audio samples - check for non-silence
      // For 16-bit audio, each sample is 2 bytes
      int maxAmplitude = 0;
      int nonSilentSamples = 0;
      final sampleCount = audioData.length ~/ 2;

      for (int i = 0; i < audioData.length - 1; i += 2) {
        // Read 16-bit signed sample (little-endian)
        int sample = audioData[i] | (audioData[i + 1] << 8);
        if (sample > 32767) sample -= 65536; // Convert to signed

        final amplitude = sample.abs();
        if (amplitude > maxAmplitude) maxAmplitude = amplitude;
        if (amplitude > 500) nonSilentSamples++; // Threshold for "non-silent"
      }

      final percentNonSilent = sampleCount > 0
          ? (nonSilentSamples / sampleCount * 100)
          : 0.0;

      // Max amplitude in 16-bit is 32767
      final normalizedMax = maxAmplitude / 32767.0;

      debugPrint('AudioService: WAV Analysis:');
      debugPrint('  - File size: ${bytes.length} bytes');
      debugPrint('  - Audio data: ${audioData.length} bytes');
      debugPrint('  - Sample count: $sampleCount');
      debugPrint('  - Max amplitude: $maxAmplitude (${(normalizedMax * 100).toStringAsFixed(1)}%)');
      debugPrint('  - Non-silent samples: ${percentNonSilent.toStringAsFixed(1)}%');

      final hasAudio = maxAmplitude > 1000 && percentNonSilent > 1.0;

      return AudioAnalysisResult(
        hasAudio: hasAudio,
        maxAmplitude: normalizedMax,
        percentNonSilent: percentNonSilent,
        sampleCount: sampleCount,
      );
    } catch (e) {
      debugPrint('AudioService: Error analyzing WAV: $e');
      return AudioAnalysisResult(hasAudio: false, error: e.toString());
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

/// Result of WAV file audio analysis
class AudioAnalysisResult {
  final bool hasAudio;
  final double maxAmplitude;
  final double percentNonSilent;
  final int sampleCount;
  final String? error;

  AudioAnalysisResult({
    required this.hasAudio,
    this.maxAmplitude = 0.0,
    this.percentNonSilent = 0.0,
    this.sampleCount = 0,
    this.error,
  });
}
