import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Secure Storage for sensitive data like tokens
class SecureStorage {
  static SecureStorage? _instance;
  late final FlutterSecureStorage _storage;

  SecureStorage._() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
  }

  static Future<SecureStorage> getInstance() async {
    _instance ??= SecureStorage._();
    return _instance!;
  }

  // Access Token
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  // Token Expiry
  Future<void> saveTokenExpiry(int expiresIn) async {
    final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: 'token_expiry', value: expiryTime.toIso8601String());
  }

  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _storage.read(key: 'token_expiry');
    if (expiryStr != null) {
      return DateTime.tryParse(expiryStr);
    }
    return null;
  }

  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    // Add 2 minute buffer for refresh
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
  }

  // Clear all tokens (logout)
  Future<void> clearTokens() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await _storage.delete(key: 'token_expiry');
  }

  // Generic storage methods
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
