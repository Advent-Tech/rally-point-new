import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Local Storage for non-sensitive data using SharedPreferences
class LocalStorage {
  static LocalStorage? _instance;
  late final SharedPreferences _prefs;

  LocalStorage._(this._prefs);

  static Future<LocalStorage> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = LocalStorage._(prefs);
    }
    return _instance!;
  }

  // Theme Mode
  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.themeKey, mode);
  }

  String? getThemeMode() {
    return _prefs.getString(AppConstants.themeKey);
  }

  // Onboarding
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(AppConstants.onboardingKey, completed);
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool(AppConstants.onboardingKey) ?? false;
  }

  // User Data (cached)
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs.setString(AppConstants.userDataKey, jsonEncode(userData));
  }

  Map<String, dynamic>? getUserData() {
    final data = _prefs.getString(AppConstants.userDataKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _prefs.remove(AppConstants.userDataKey);
  }

  // Territory Assignments (cached)
  Future<void> saveTerritoryAssignments(List<dynamic> assignments) async {
    await _prefs.setString('territory_assignments', jsonEncode(assignments));
  }

  List<Map<String, dynamic>>? getTerritoryAssignments() {
    final data = _prefs.getString('territory_assignments');
    if (data != null) {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return null;
  }

  Future<void> clearTerritoryAssignments() async {
    await _prefs.remove('territory_assignments');
  }

  // Location Sessions (cached)
  Future<void> saveLocationSessions(List<dynamic> sessions) async {
    await _prefs.setString('location_sessions', jsonEncode(sessions));
  }

  List<Map<String, dynamic>>? getLocationSessions() {
    final data = _prefs.getString('location_sessions');
    if (data != null) {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return null;
  }

  // Pending Location Updates (for offline sync)
  Future<void> savePendingLocationUpdates(List<dynamic> updates) async {
    await _prefs.setString('pending_location_updates', jsonEncode(updates));
  }

  List<Map<String, dynamic>>? getPendingLocationUpdates() {
    final data = _prefs.getString('pending_location_updates');
    if (data != null) {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return null;
  }

  Future<void> clearPendingLocationUpdates() async {
    await _prefs.remove('pending_location_updates');
  }

  // Deliveries (cached)
  Future<void> saveDeliveries(List<dynamic> deliveries) async {
    await _prefs.setString('deliveries', jsonEncode(deliveries));
  }

  List<Map<String, dynamic>>? getDeliveries() {
    final data = _prefs.getString('deliveries');
    if (data != null) {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return null;
  }

  // Surveys (cached)
  Future<void> saveSurveys(List<dynamic> surveys) async {
    await _prefs.setString('surveys', jsonEncode(surveys));
  }

  List<Map<String, dynamic>>? getSurveys() {
    final data = _prefs.getString('surveys');
    if (data != null) {
      final list = jsonDecode(data) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return null;
  }

  // Last Sync Time
  Future<void> saveLastSyncTime(DateTime time) async {
    await _prefs.setString(AppConstants.lastSyncKey, time.toIso8601String());
  }

  DateTime? getLastSyncTime() {
    final timeStr = _prefs.getString(AppConstants.lastSyncKey);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }

  // Generic methods
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) {
    return _prefs.getString(key);
  }

  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clear() async {
    await _prefs.clear();
  }

  // Work Session (current active session)
  Future<void> saveCurrentWorkSession(Map<String, dynamic> session) async {
    await _prefs.setString('current_work_session', jsonEncode(session));
  }

  Map<String, dynamic>? getCurrentWorkSession() {
    final data = _prefs.getString('current_work_session');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> clearCurrentWorkSession() async {
    await _prefs.remove('current_work_session');
  }
}
