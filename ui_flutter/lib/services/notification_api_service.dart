import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';

/// REST client for notification API endpoints
class NotificationApiService {
  static NotificationApiService? _instance;
  late final ApiClient _apiClient;

  NotificationApiService._();

  static Future<NotificationApiService> getInstance() async {
    _instance ??= NotificationApiService._();
    _instance!._apiClient = await ApiClient.getInstance();
    return _instance!;
  }

  /// Register a device token for push notifications
  Future<void> registerToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await _apiClient.dio.post(
      ApiConstants.notificationsDeviceToken,
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
      },
    );
  }

  /// Remove a device token
  Future<void> removeToken(String token) async {
    await _apiClient.dio.delete(
      ApiConstants.notificationsDeviceToken,
      queryParameters: {'token': token},
    );
  }

  /// Get paginated notifications
  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      ApiConstants.notifications,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return response.data;
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final response = await _apiClient.dio.get(
      ApiConstants.notificationsUnreadCount,
    );
    return response.data['unread_count'] ?? 0;
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _apiClient.dio.put('${ApiConstants.notifications}/$notificationId/read');
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _apiClient.dio.put(ApiConstants.notificationsReadAll);
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _apiClient.dio.delete('${ApiConstants.notifications}/$notificationId');
  }

  /// Get notification preferences
  Future<List<dynamic>> getPreferences() async {
    final response = await _apiClient.dio.get(
      ApiConstants.notificationsPreferences,
    );
    return response.data['preferences'] ?? [];
  }

  /// Update notification preferences
  Future<void> updatePreferences({
    required String notificationType,
    bool? inAppEnabled,
    bool? pushEnabled,
  }) async {
    await _apiClient.dio.put(
      ApiConstants.notificationsPreferences,
      data: {
        'notification_type': notificationType,
        if (inAppEnabled != null) 'in_app_enabled': inAppEnabled,
        if (pushEnabled != null) 'push_enabled': pushEnabled,
      },
    );
  }
}
