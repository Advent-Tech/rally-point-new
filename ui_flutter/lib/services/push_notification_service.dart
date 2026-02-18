import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_api_service.dart';
import 'realtime_provider.dart';

/// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Manages Firebase Cloud Messaging and local notifications
class PushNotificationService {
  static PushNotificationService? _instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  NotificationApiService? _apiService;
  String? _currentToken;

  PushNotificationService._();

  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    _apiService = await NotificationApiService.getInstance();

    // Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    // Initialize local notifications (for foreground display)
    await _initLocalNotifications();

    // Create notification channels (Android)
    await _createNotificationChannels();

    // Get and register FCM token
    await _registerToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('FCM token refreshed');
      await _registerTokenWithServer(token);
    });

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Message tap handler (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle local notification tap
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> _createNotificationChannels() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = [
      AndroidNotificationChannel('geofence_channel', 'Territory',
          description: 'Geofence entry/exit notifications',
          importance: Importance.high),
      AndroidNotificationChannel('prayer_channel', 'Prayer Requests',
          description: 'Prayer request notifications',
          importance: Importance.high),
      AndroidNotificationChannel('delivery_channel', 'Deliveries',
          description: 'Delivery assignment and status notifications',
          importance: Importance.high),
      AndroidNotificationChannel('team_channel', 'Team',
          description: 'Team join requests and approvals',
          importance: Importance.high),
      AndroidNotificationChannel('walkie_channel', 'Walkie Talkie',
          description: 'Voice message notifications',
          importance: Importance.high),
      AndroidNotificationChannel('chat_channel', 'Chat',
          description: 'Chat message notifications',
          importance: Importance.high),
      AndroidNotificationChannel('session_channel', 'Work Sessions',
          description: 'Check-in and check-out notifications',
          importance: Importance.defaultImportance),
      AndroidNotificationChannel('default_channel', 'General',
          description: 'General notifications',
          importance: Importance.defaultImportance),
    ];

    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerTokenWithServer(token);
      }
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> _registerTokenWithServer(String token) async {
    _currentToken = token;
    try {
      await _apiService?.registerToken(
        token: token,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');

    // Show local notification
    final notification = message.notification;
    if (notification != null) {
      final channelId = message.data['notification_type'] != null
          ? '${message.data['notification_type']}_channel'
          : 'default_channel';

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId.replaceAll('_channel', '').replaceAll('_', ' '),
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['notification_id'],
      );
    }

    // Feed into RealtimeProvider for in-app badge updates
    final provider = RealtimeProvider();
    final data = message.data;
    provider.addServerNotification(
      id: data['notification_id'] ?? '',
      type: data['notification_type'] ?? 'general',
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: data,
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM message tapped: ${message.data}');
    // Deep-linking is handled by the notification center screen
    // when the user taps on the notification in the app
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    if (_currentToken != null) {
      try {
        await _apiService?.removeToken(_currentToken!);
      } catch (e) {
        debugPrint('Failed to remove FCM token: $e');
      }
    }
    await _messaging.deleteToken();
    _currentToken = null;
  }
}
