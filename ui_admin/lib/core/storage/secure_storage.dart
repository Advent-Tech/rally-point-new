import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static SecureStorage? _instance;
  FlutterSecureStorage? _storage;
  SharedPreferences? _webStorage;
  bool _useWebFallback = false;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';

  SecureStorage._internal();

  static Future<SecureStorage> getInstance() async {
    if (_instance == null) {
      _instance = SecureStorage._internal();

      if (kIsWeb) {
        // On web, use SharedPreferences (localStorage) as fallback
        // since flutter_secure_storage requires HTTPS for Web Crypto API
        _instance!._useWebFallback = true;
        _instance!._webStorage = await SharedPreferences.getInstance();
      } else {
        _instance!._storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );
      }
    }
    return _instance!;
  }

  Future<void> _write(String key, String value) async {
    if (_useWebFallback) {
      await _webStorage!.setString(key, value);
    } else {
      await _storage!.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    if (_useWebFallback) {
      return _webStorage!.getString(key);
    } else {
      return _storage!.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    if (_useWebFallback) {
      await _webStorage!.remove(key);
    } else {
      await _storage!.delete(key: key);
    }
  }

  // Token management
  Future<void> saveAccessToken(String token) async {
    await _write(_accessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    return _read(_accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _write(_refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    return _read(_refreshTokenKey);
  }

  // User info
  Future<void> saveUserRole(String role) async {
    await _write(_userRoleKey, role);
  }

  Future<String?> getUserRole() async {
    return _read(_userRoleKey);
  }

  Future<void> saveUserId(String id) async {
    await _write(_userIdKey, id);
  }

  Future<String?> getUserId() async {
    return _read(_userIdKey);
  }

  Future<void> saveUserEmail(String email) async {
    await _write(_userEmailKey, email);
  }

  Future<String?> getUserEmail() async {
    return _read(_userEmailKey);
  }

  // Clear all
  Future<void> clearAll() async {
    if (_useWebFallback) {
      await _webStorage!.clear();
    } else {
      await _storage!.deleteAll();
    }
  }

  Future<void> clearTokens() async {
    await _delete(_accessTokenKey);
    await _delete(_refreshTokenKey);
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
