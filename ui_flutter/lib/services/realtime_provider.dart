import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_service.dart';
import '../data/models/walkie_model.dart';

/// Provider for real-time updates across the app
class RealtimeProvider extends ChangeNotifier {
  static RealtimeProvider? _instance;

  WebSocketService? _wsService;
  bool _isInitialized = false;
  bool _isConnected = false;

  // Subscriptions
  StreamSubscription? _messageSubscription;

  // Current data
  final List<WalkieMessage> _recentWalkieMessages = [];
  final Map<String, WorkerLocationUpdate> _workerLocations = {};
  final List<RealtimeNotification> _notifications = [];

  RealtimeProvider._();

  factory RealtimeProvider() {
    _instance ??= RealtimeProvider._();
    return _instance!;
  }

  static Future<RealtimeProvider> getInstance() async {
    _instance ??= RealtimeProvider._();
    if (!_instance!._isInitialized) {
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    _wsService = await WebSocketService.getInstance();
    _isInitialized = true;

    // Set up connection callbacks
    _wsService!.onConnected(() {
      _isConnected = true;
      notifyListeners();
      debugPrint('RealtimeProvider: Connected');
    });

    _wsService!.onDisconnected((reason) {
      _isConnected = false;
      notifyListeners();
      debugPrint('RealtimeProvider: Disconnected - $reason');
    });

    // Listen to message stream
    _messageSubscription = _wsService!.messageStream.listen(_handleMessage);
  }

  /// Connect to real-time services
  Future<bool> connect() async {
    await _initialize();
    return await _wsService!.connect();
  }

  /// Disconnect from real-time services
  Future<void> disconnect() async {
    await _wsService?.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Recent walkie messages
  List<WalkieMessage> get recentWalkieMessages => _recentWalkieMessages.toList();

  /// Worker locations
  Map<String, WorkerLocationUpdate> get workerLocations => Map.from(_workerLocations);

  /// Notifications
  List<RealtimeNotification> get notifications => _notifications.toList();

  /// Unread notification count
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  void _handleMessage(WsMessage message) {
    switch (message.type) {
      case WsMessageType.walkieMessage:
        _handleWalkieMessage(message);
        break;
      case WsMessageType.workerLocationBroadcast:
        _handleWorkerLocation(message);
        break;
      case WsMessageType.deliveryCreated:
      case WsMessageType.deliveryUpdated:
      case WsMessageType.deliveryStatusChanged:
        _handleDeliveryUpdate(message);
        break;
      case WsMessageType.alertBroadcast:
        _handleAlert(message);
        break;
      case WsMessageType.teamMemberOnline:
      case WsMessageType.teamMemberOffline:
        _handleTeamMemberStatus(message);
        break;
      default:
        // Handle server-side notifications (from api-gateway notification handler)
        if (message.type.name == 'unknown' && message.data['type'] == 'notification') {
          _handleServerNotification(message);
        }
        break;
    }
  }

  void _handleServerNotification(WsMessage message) {
    try {
      final data = message.data;
      final notifType = _mapNotificationType(data['type']?.toString() ?? 'general');

      _addNotification(RealtimeNotification(
        id: data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: notifType,
        title: data['title']?.toString() ?? '',
        body: data['body']?.toString() ?? '',
        data: data,
        timestamp: data['created_at'] != null
            ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        priority: data['priority'] == 'high'
            ? NotificationPriority.high
            : NotificationPriority.normal,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing server notification: $e');
    }
  }

  /// Called by PushNotificationService when an FCM message arrives in foreground
  void addServerNotification({
    required String id,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    _addNotification(RealtimeNotification(
      id: id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString(),
      type: _mapNotificationType(type),
      title: title,
      body: body,
      data: data,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  NotificationType _mapNotificationType(String type) {
    switch (type) {
      case 'geofence':
      case 'session':
        return NotificationType.sessionUpdate;
      case 'prayer':
      case 'delivery':
      case 'book_sale':
      case 'survey':
        return NotificationType.deliveryUpdate;
      case 'team':
        return NotificationType.teamStatus;
      case 'walkie':
        return NotificationType.walkieMessage;
      case 'chat':
        return NotificationType.walkieMessage;
      default:
        return NotificationType.general;
    }
  }

  void _handleWalkieMessage(WsMessage message) {
    try {
      final walkieMessage = WalkieMessage.fromJson(message.data);
      _recentWalkieMessages.insert(0, walkieMessage);

      // Keep only last 50 messages
      if (_recentWalkieMessages.length > 50) {
        _recentWalkieMessages.removeLast();
      }

      // Add notification for voice messages
      if (walkieMessage.messageType == 'voice') {
        _addNotification(RealtimeNotification(
          id: walkieMessage.id,
          type: NotificationType.walkieMessage,
          title: 'Voice Message',
          body: '${walkieMessage.senderName} sent a voice message',
          data: message.data,
          timestamp: walkieMessage.createdAt,
        ));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing walkie message: $e');
    }
  }

  void _handleWorkerLocation(WsMessage message) {
    try {
      final update = WorkerLocationUpdate.fromJson(message.data);
      _workerLocations[update.workerId] = update;
      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing worker location: $e');
    }
  }

  void _handleDeliveryUpdate(WsMessage message) {
    try {
      final deliveryId = message.data['id']?.toString() ?? '';
      final status = message.data['status']?.toString() ?? '';

      _addNotification(RealtimeNotification(
        id: deliveryId,
        type: NotificationType.deliveryUpdate,
        title: 'Delivery Update',
        body: 'Delivery status changed to $status',
        data: message.data,
        timestamp: message.timestamp,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing delivery update: $e');
    }
  }

  void _handleAlert(WsMessage message) {
    try {
      final alertType = message.data['alert_type']?.toString() ?? 'alert';
      final alertMessage = message.data['message']?.toString() ?? 'Alert received';

      _addNotification(RealtimeNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.alert,
        title: alertType.toUpperCase(),
        body: alertMessage,
        data: message.data,
        timestamp: message.timestamp,
        priority: alertType == 'emergency' ? NotificationPriority.high : NotificationPriority.normal,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing alert: $e');
    }
  }

  void _handleTeamMemberStatus(WsMessage message) {
    try {
      final memberName = message.data['display_name']?.toString() ?? 'Team member';
      final isOnline = message.type == WsMessageType.teamMemberOnline;

      _addNotification(RealtimeNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: NotificationType.teamStatus,
        title: isOnline ? 'Member Online' : 'Member Offline',
        body: '$memberName is now ${isOnline ? 'online' : 'offline'}',
        data: message.data,
        timestamp: message.timestamp,
        priority: NotificationPriority.low,
      ));

      notifyListeners();
    } catch (e) {
      debugPrint('RealtimeProvider: Error parsing team member status: $e');
    }
  }

  void _addNotification(RealtimeNotification notification) {
    _notifications.insert(0, notification);

    // Keep only last 100 notifications
    if (_notifications.length > 100) {
      _notifications.removeLast();
    }
  }

  /// Mark a notification as read
  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  void markAllNotificationsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  /// Clear all notifications
  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  /// Join a team's real-time channel
  void joinTeam(String teamId) {
    _wsService?.joinTeamChannel(teamId);
  }

  /// Leave a team's real-time channel
  void leaveTeam(String teamId) {
    _wsService?.leaveTeamChannel(teamId);
  }

  /// Send location update
  void sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? sessionId,
  }) {
    _wsService?.sendLocationUpdate(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      sessionId: sessionId,
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _wsService?.dispose();
    _instance = null;
    super.dispose();
  }
}

/// Worker location update
class WorkerLocationUpdate {
  final String workerId;
  final String? workerName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;
  final bool isActive;

  WorkerLocationUpdate({
    required this.workerId,
    this.workerName,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
    this.isActive = true,
  });

  factory WorkerLocationUpdate.fromJson(Map<String, dynamic> json) {
    return WorkerLocationUpdate(
      workerId: json['worker_id']?.toString() ?? json['user_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? json['display_name']?.toString(),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isActive: json['is_active'] ?? true,
    );
  }
}

/// Notification types
enum NotificationType {
  walkieMessage,
  deliveryUpdate,
  alert,
  teamStatus,
  sessionUpdate,
  general,
}

/// Notification priority
enum NotificationPriority {
  low,
  normal,
  high,
}

/// Real-time notification model
class RealtimeNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final NotificationPriority priority;

  RealtimeNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
  });

  RealtimeNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    NotificationPriority? priority,
  }) {
    return RealtimeNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
    );
  }
}
