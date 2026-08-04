import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:go_router/go_router.dart';
import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/navigation/app_router.dart';
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
  FlutterSoundPlayer? _audioPlayer;
  bool _initialized = false;
  Timer? _tokenRetryTimer;
  String? _pendingToken;

  PushNotificationService._();

  static PushNotificationService get instance {
    _instance ??= PushNotificationService._();
    return _instance!;
  }

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_initialized) return;
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

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

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

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle action button tap
        if (response.actionId == 'play_audio') {
          _handlePlayAudioAction(response.payload);
          return;
        }
        if (response.actionId == 'stop_audio') {
          _stopAudioPlayback();
          return;
        }
        // Handle normal notification tap — parse the JSON payload and navigate
        debugPrint('Local notification tapped: ${response.payload}');
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = json.decode(response.payload!) as Map<String, dynamic>;
            _navigateToNotification(data.map((k, v) => MapEntry(k, v.toString())));
          } catch (e) {
            debugPrint('Failed to parse notification payload: $e');
          }
        }
      },
    );
  }

  Future<void> _handlePlayAudioAction(String? payload) async {
    if (payload == null) return;
    try {
      final data = json.decode(payload) as Map<String, dynamic>;
      final audioUrl = data['audio_url']?.toString();
      if (audioUrl == null || audioUrl.isEmpty) return;

      _audioPlayer ??= FlutterSoundPlayer();
      if (!_audioPlayer!.isOpen()) {
        await _audioPlayer!.openPlayer();
      }

      if (_audioPlayer!.isPlaying) {
        await _audioPlayer!.stopPlayer();
      }

      await _audioPlayer!.startPlayer(
        fromURI: audioUrl,
        whenFinished: () {
          debugPrint('Walkie audio playback finished');
        },
      );
      debugPrint('Playing walkie audio from notification: $audioUrl');
    } catch (e) {
      debugPrint('Failed to play audio from notification: $e');
    }
  }

  Future<void> _stopAudioPlayback() async {
    try {
      if (_audioPlayer != null && _audioPlayer!.isPlaying) {
        await _audioPlayer!.stopPlayer();
      }
    } catch (e) {
      debugPrint('Failed to stop audio: $e');
    }
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
      AndroidNotificationChannel('book_distribution_channel', 'Books Distributed',
          description: 'Book distribution and targets notifications',
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
      _pendingToken = null;
      _tokenRetryTimer?.cancel();
      debugPrint('FCM token registered with server');
    } catch (e) {
      _pendingToken = token;
      _scheduleTokenRetry();
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void _scheduleTokenRetry() {
    _tokenRetryTimer ??= Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      final token = _pendingToken;
      if (token == null) {
        timer.cancel();
        _tokenRetryTimer = null;
        return;
      }
      try {
        await _apiService?.registerToken(
          token: token,
          platform: Platform.isAndroid ? 'android' : 'ios',
        );
        _pendingToken = null;
        timer.cancel();
        _tokenRetryTimer = null;
        debugPrint('FCM token registered on retry');
      } catch (_) {
        // Keep retrying until success/logout.
      }
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground message: ${message.notification?.title}');

    // Show local notification
    final notification = message.notification;
    if (notification != null) {
      final notificationType = message.data['notification_type']?.toString();
      final channelId = notificationType != null
          ? _channelIdForType(notificationType)
          : 'default_channel';

      final isWalkie = notificationType == 'walkie' &&
          message.data['audio_url'] != null &&
          message.data['audio_url'].toString().isNotEmpty;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId.replaceAll('_channel', '').replaceAll('_', ' '),
        icon: '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
        actions: isWalkie
            ? <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'play_audio',
                  '▶ Play',
                  showsUserInterface: false,
                ),
              ]
            : null,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        // Pass full data as JSON so the tap/action handler can use it
        payload: json.encode(message.data),
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
    _navigateToNotification(message.data);
  }

  /// Check if current user is a team leader
  bool _isUserLeader(BuildContext context) {
    try {
      final authState = BlocProvider.of<AuthBloc>(context, listen: false).state;
      if (authState is AuthAuthenticated) {
        return authState.user.isTeamLeader;
      }
    } catch (_) {}
    return false;
  }

  /// Navigate to the appropriate screen based on notification type and user role.
  /// Uses go() instead of push() to avoid GlobalKey conflicts with ShellRoute.
  void _navigateToNotification(Map<String, dynamic> data) {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('No navigator context for deep-link');
      return;
    }
    final router = GoRouter.of(context);

    final deepLink = data['deep_link']?.toString();
    if (deepLink != null && deepLink.isNotEmpty) {
      router.go(deepLink);
      return;
    }

    final type = data['notification_type']?.toString();
    final isLeader = _isUserLeader(context);
    debugPrint('Deep-linking for type: $type, isLeader: $isLeader');

    switch (type) {
      case 'chat':
        final conversationId = data['conversation_id']?.toString();
        if (conversationId != null && conversationId.isNotEmpty) {
          router.go(isLeader ? '/leader/chat/$conversationId' : '/chat/$conversationId');
        } else {
          router.go(isLeader ? '/leader/chat' : '/chat');
        }
        break;
      case 'walkie':
        router.go(isLeader ? '/leader/walkie' : '/walkie');
        break;
      case 'delivery':
        router.go(isLeader ? '/leader/reports' : '/delivery');
        break;
      case 'book_sale':
        router.go(isLeader ? '/leader/reports' : '/delivery');
        break;
      case 'prayer':
        router.go(isLeader ? '/leader/prayer-requests' : '/home');
        break;
      case 'team':
        router.go(isLeader ? '/leader/worker-verification' : '/home');
        break;
      case 'survey':
        router.go(isLeader ? '/leader/survey' : '/survey');
        break;
      case 'geofence':
      case 'session':
        router.go(isLeader ? '/leader/command-center?mode=workers' : '/territory');
        break;
      case 'territory':
        router.go(isLeader ? '/leader/command-center?mode=territories' : '/territory');
        break;
      default:
        router.go('/notifications');
        break;
    }
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
    _pendingToken = null;

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

  String _channelIdForType(String type) {
    switch (type) {
      case 'book_sale':
        return 'book_distribution_channel';
      default:
        return '${type}_channel';
    }
  }
}
