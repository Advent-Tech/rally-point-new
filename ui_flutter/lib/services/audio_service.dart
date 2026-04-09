import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // Playback via flutter_sound (uses Android MediaPlayer — works on OnePlus and similar devices
  // where ExoPlayer/just_audio produces no audible output)
  fs.FlutterSoundPlayer? _fsPlayer;
  String? _currentPlaybackId;

  // Alternative recorder (flutter_sound) - used as fallback
  fs.FlutterSoundRecorder? _flutterSoundRecorder;
  static bool useFlutterSound = false; // Use record package first — flutter_sound has silent recording issues
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
    _isInitialized = true;
  }

  /// Lazily init flutter_sound player for playback
  Future<fs.FlutterSoundPlayer> _ensureFsPlayer() async {
    if (_fsPlayer == null) {
      _fsPlayer = fs.FlutterSoundPlayer();
      await _fsPlayer!.openPlayer();
    }
    return _fsPlayer!;
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

      // Use AAC-LC in M4A container (record package uses MediaRecorder with MPEG_4 output)
      // This is a different native path from flutter_sound's AAC_ADTS
      _currentRecordingPath = '${tempDir.path}/walkie_$timestamp.m4a';

      // Try different audio sources with AAC-LC encoder
      // Each source uses a different Android MediaRecorder.AudioSource constant
      final audioSources = [
        ('default', AndroidAudioSource.defaultSource),
        ('mic', AndroidAudioSource.mic),
        ('voiceRecognition', AndroidAudioSource.voiceRecognition),
        ('camcorder', AndroidAudioSource.camcorder),
      ];

      bool started = false;

      for (final (_, source) in audioSources) {
        try {
          await _recorder.start(
            RecordConfig(
              encoder: AudioEncoder.aacLc,
              numChannels: 1,
              sampleRate: 44100,
              bitRate: 64000,
              androidConfig: AndroidRecordConfig(
                audioSource: source,
              ),
            ),
            path: _currentRecordingPath!,
          );
          started = true;
          break;
        } catch (e) {
        }
      }

      if (!started) {
        // Fallback: try without Android config
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            numChannels: 1,
            sampleRate: 44100,
            bitRate: 64000,
          ),
          path: _currentRecordingPath!,
        );
        // fallback succeeded
      }

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Start monitoring audio levels
      _startLevelMonitoring();

      onRecordingStarted?.call();
      return true;
    } catch (e) {
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

        return RecordingResult(
          path: path,
          durationMs: durationMs,
        );
      }

      return null;
    } catch (e) {
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
  }

  /// Start recording with flutter_sound
  Future<bool> _startRecordingWithFlutterSound() async {
    try {
      await _initFlutterSound();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Use AAC ADTS format — it uses Android's MediaRecorder API which is
      // far more reliable than AudioRecord (used by pcm16WAV). AudioRecord
      // produces all-zero buffers on many devices (OnePlus, emulators, etc.)
      _currentRecordingPath = '${tempDir.path}/walkie_fs_$timestamp.aac';

      // Try AAC ADTS first (uses MediaRecorder - reliable), fall back to WAV
      try {
        await _flutterSoundRecorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: fs.Codec.aacADTS,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
          audioSource: fs.AudioSource.microphone,
        );
      } catch (e) {
        // Fallback to WAV if AAC is not supported
        _currentRecordingPath = '${tempDir.path}/walkie_fs_$timestamp.wav';
        await _flutterSoundRecorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: fs.Codec.pcm16WAV,
          sampleRate: 16000,
          numChannels: 1,
          audioSource: fs.AudioSource.microphone,
        );
      }

      // Listen to audio levels with detailed logging
      // Note: flutter_sound dB metering does NOT work with MediaRecorder/AAC codec.
      // It always reports 0.0 dB. For AAC, we simulate a gentle pulsing level so
      // the UI doesn't look dead during recording.
      final bool isAacCodec = _currentRecordingPath!.endsWith('.aac');
      _flutterSoundSubscription = _flutterSoundRecorder!.onProgress?.listen((e) {
        if (e.decibels != null) {
          final db = e.decibels!;

          double level;
          if (isAacCodec && db >= -1.0 && db <= 0.0) {
            // AAC/MediaRecorder: dB metering is broken (always 0.0)
            // Simulate a gentle pulse so the recording indicator looks alive
            final t = DateTime.now().millisecondsSinceEpoch / 500.0;
            level = 0.3 + 0.2 * (0.5 + 0.5 * (t - t.floorToDouble()));
          } else if (db < -160.0 || db.isNaN) {
            level = 0.0;
          } else {
            // Real dB values (works with PCM/WAV codec)
            level = ((db + 160) / 160).clamp(0.0, 1.0);
          }

          // Log every 10th sample for diagnostics
          onAudioLevelChanged?.call(level);
        }
      });

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      onRecordingStarted?.call();

      return true;
    } catch (e) {
      onRecordingError?.call(e.toString());
      return false;
    }
  }

  /// Stop recording with flutter_sound
  Future<RecordingResult?> _stopRecordingWithFlutterSound() async {
    try {
      _flutterSoundSubscription?.cancel();
      _flutterSoundSubscription = null;

      final path = await _flutterSoundRecorder!.stopRecorder();
      _isRecording = false;

      final durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      _recordingStartTime = null;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          onRecordingStopped?.call(path, durationMs);

          return RecordingResult(
            path: path,
            durationMs: durationMs,
          );
        }
      }

      return null;
    } catch (e) {
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

    } catch (e) {
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

  /// Play audio from URL or file path using flutter_sound (MediaPlayer)
  Future<bool> _playUri(String uri, {String? audioId}) async {
    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      final player = await _ensureFsPlayer();
      _isPlaying = true;
      _currentPlaybackId = audioId ?? uri;
      onPlaybackStarted?.call(_currentPlaybackId!);

      await player.startPlayer(
        fromURI: uri,
        whenFinished: () {
          _isPlaying = false;
          onPlaybackCompleted?.call(_currentPlaybackId ?? '');
          _currentPlaybackId = null;
        },
      );
      return true;
    } catch (e) {
      _isPlaying = false;
      _currentPlaybackId = null;
      return false;
    }
  }

  /// Play audio from URL
  Future<bool> playFromUrl(String url, {String? audioId}) async {
    return _playUri(url, audioId: audioId);
  }

  /// Play audio from file path
  Future<bool> playFromFile(String path, {String? audioId}) async {
    return _playUri(path, audioId: audioId);
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
      return false;
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    if (!_isPlaying) return;

    try {
      await _fsPlayer?.stopPlayer();
      _isPlaying = false;
      _currentPlaybackId = null;
    } catch (e) {
    }
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    if (!_isPlaying) return;

    try {
      await _fsPlayer?.pausePlayer();
    } catch (e) {
    }
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    try {
      await _fsPlayer?.resumePlayer();
    } catch (e) {
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
    } catch (e) {
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

      final hasAudio = maxAmplitude > 1000 && percentNonSilent > 1.0;

      return AudioAnalysisResult(
        hasAudio: hasAudio,
        maxAmplitude: normalizedMax,
        percentNonSilent: percentNonSilent,
        sampleCount: sampleCount,
      );
    } catch (e) {
      return AudioAnalysisResult(hasAudio: false, error: e.toString());
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await cancelRecording();
    await stopPlayback();
    await _recorder.dispose();
    if (_fsPlayer != null) {
      await _fsPlayer!.closePlayer();
      _fsPlayer = null;
    }
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
