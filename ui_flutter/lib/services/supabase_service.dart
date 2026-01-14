import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for Supabase operations (storage uploads)
class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseClient? _client;

  // Supabase configuration
  // TODO: Move these to environment config or secure storage
  static const String _supabaseUrl = 'https://nvmegykcztwwultvnwdu.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52bWVneWtjenR3d3VsdHZud2R1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjExMjc3NjYsImV4cCI6MjA3NjcwMzc2Nn0.fIfEzEVqryw_SAVS_pN8Fyd3ebzDytWk_ZSuLBH-3Ck';

  // Storage bucket for walkie-talkie audio
  static const String audioBucket = 'ministry_storage';

  SupabaseService._();

  /// Get singleton instance
  static Future<SupabaseService> getInstance() async {
    if (_instance == null) {
      _instance = SupabaseService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize Supabase
  Future<void> _initialize() async {
    if (_client != null) return;

    try {
      debugPrint('SupabaseService: Starting initialization...');

      // Check if already initialized by trying to access the instance
      bool alreadyInitialized = false;
      try {
        _client = Supabase.instance.client;
        alreadyInitialized = true;
        debugPrint('SupabaseService: Already initialized, reusing client');
      } catch (_) {
        // Not initialized yet, continue with initialization
        debugPrint('SupabaseService: Not initialized, will initialize now');
      }

      if (!alreadyInitialized) {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        _client = Supabase.instance.client;
        debugPrint('SupabaseService: Initialized successfully');
      }

      debugPrint('SupabaseService: Client ready, URL: $_supabaseUrl');
    } catch (e, stackTrace) {
      debugPrint('SupabaseService: Initialization error: $e');
      debugPrint('SupabaseService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get Supabase client
  SupabaseClient get client {
    if (_client == null) {
      throw Exception('SupabaseService not initialized. Call getInstance() first.');
    }
    return _client!;
  }

  /// Upload audio file to Supabase Storage
  /// Returns the public URL of the uploaded file
  Future<String?> uploadAudioFile({
    required String filePath,
    required String teamId,
    String? fileName,
  }) async {
    debugPrint('SupabaseService.uploadAudioFile: ENTRY - filePath=$filePath, teamId=$teamId');
    try {
      debugPrint('SupabaseService.uploadAudioFile: Checking if file exists...');
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('SupabaseService: File not found: $filePath');
        return null;
      }

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Validate file has content
      if (bytes.isEmpty) {
        debugPrint('SupabaseService: File is empty: $filePath');
        return null;
      }

      debugPrint('SupabaseService: File size: ${bytes.length} bytes');

      // Generate unique file name - detect extension from source file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sourceExtension = filePath.split('.').last.toLowerCase();
      final name = fileName ?? 'audio_$timestamp.$sourceExtension';
      final storagePath = 'walkie-talkie/$teamId/$name';

      // Determine MIME type based on file extension
      String contentType;
      switch (sourceExtension) {
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'm4a':
        case 'mp4':
          contentType = 'audio/mp4';
          break;
        case 'opus':
          contentType = 'audio/opus';
          break;
        default:
          contentType = 'audio/mpeg';
      }

      debugPrint('SupabaseService: Uploading to bucket: $audioBucket, path: $storagePath');
      debugPrint('SupabaseService: Content type: $contentType');

      // Upload to Supabase Storage
      final response = await client.storage
          .from(audioBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      debugPrint('SupabaseService: Upload response: $response');

      // Get public URL
      final publicUrl = client.storage
          .from(audioBucket)
          .getPublicUrl(storagePath);

      debugPrint('SupabaseService: Public URL: $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('SupabaseService: Upload error: $e');
      debugPrint('SupabaseService: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload audio bytes directly to Supabase Storage
  /// Returns the public URL of the uploaded file
  Future<String?> uploadAudioBytes({
    required Uint8List bytes,
    required String teamId,
    String? fileName,
  }) async {
    try {
      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'audio_$timestamp.m4a';
      final storagePath = 'walkie-talkie/$teamId/$name';

      // Upload to Supabase Storage
      await client.storage
          .from(audioBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'audio/m4a',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = client.storage
          .from(audioBucket)
          .getPublicUrl(storagePath);

      debugPrint('SupabaseService: Uploaded, URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('SupabaseService: Upload bytes error: $e');
      return null;
    }
  }

  /// Delete audio file from Supabase Storage
  Future<bool> deleteAudioFile(String storagePath) async {
    try {
      await client.storage.from(audioBucket).remove([storagePath]);
      debugPrint('SupabaseService: Deleted: $storagePath');
      return true;
    } catch (e) {
      debugPrint('SupabaseService: Delete error: $e');
      return false;
    }
  }
}
