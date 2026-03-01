import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/secure_storage.dart';

/// Types of WebSocket messages
enum WsMessageType {
  // Location updates
  locationUpdate,
  workerLocationBroadcast,

  // Session updates
  sessionStarted,
  sessionEnded,

  // Walkie-talkie
  walkieMessage,
  walkieParticipantJoined,
  walkieParticipantLeft,
  walkieSpeakingStart,
  walkieSpeakingEnd,

  // Team updates
  teamMemberOnline,
  teamMemberOffline,
  teamActivityUpdate,

  // Delivery updates
  deliveryCreated,
  deliveryUpdated,
  deliveryStatusChanged,

  // Alerts
  alertBroadcast,

  // Chat
  chatMessage,
  chatMessageUpdated,
  chatMessageDeleted,
  chatTyping,
  chatRead,
  chatParticipantOnline,
  chatParticipantOffline,

  // System
  ping,
  pong,
  error,
  unknown,
}

/// WebSocket message wrapper
class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? senderId;
  final String? channelId;

  WsMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.senderId,
    this.channelId,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: _parseType(json['type']?.toString() ?? ''),
      data: json['data'] ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      senderId: json['sender_id']?.toString(),
      channelId: json['channel_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    if (senderId != null) 'sender_id': senderId,
    if (channelId != null) 'channel_id': channelId,
  };

  static WsMessageType _parseType(String typeStr) {
    switch (typeStr) {
      case 'location_update':
        return WsMessageType.locationUpdate;
      case 'worker_location_broadcast':
        return WsMessageType.workerLocationBroadcast;
      case 'session_started':
        return WsMessageType.sessionStarted;
      case 'session_ended':
        return WsMessageType.sessionEnded;
      case 'walkie_message':
        return WsMessageType.walkieMessage;
      case 'walkie_participant_joined':
        return WsMessageType.walkieParticipantJoined;
      case 'walkie_participant_left':
        return WsMessageType.walkieParticipantLeft;
      case 'walkie_speaking_start':
        return WsMessageType.walkieSpeakingStart;
      case 'walkie_speaking_end':
        return WsMessageType.walkieSpeakingEnd;
      case 'team_member_online':
        return WsMessageType.teamMemberOnline;
      case 'team_member_offline':
        return WsMessageType.teamMemberOffline;
      case 'team_activity_update':
        return WsMessageType.teamActivityUpdate;
      case 'delivery_created':
        return WsMessageType.deliveryCreated;
      case 'delivery_updated':
        return WsMessageType.deliveryUpdated;
      case 'delivery_status_changed':
        return WsMessageType.deliveryStatusChanged;
      case 'alert_broadcast':
        return WsMessageType.alertBroadcast;
      case 'chat_message':
        return WsMessageType.chatMessage;
      case 'chat_message_updated':
        return WsMessageType.chatMessageUpdated;
      case 'chat_message_deleted':
        return WsMessageType.chatMessageDeleted;
      case 'chat_typing':
        return WsMessageType.chatTyping;
      case 'chat_read':
        return WsMessageType.chatRead;
      case 'chat_participant_online':
        return WsMessageType.chatParticipantOnline;
      case 'chat_participant_offline':
        return WsMessageType.chatParticipantOffline;
      case 'ping':
        return WsMessageType.ping;
      case 'pong':
        return WsMessageType.pong;
      case 'error':
        return WsMessageType.error;
      default:
        return WsMessageType.unknown;
    }
  }
}

/// Callback types
typedef OnWsMessage = void Function(WsMessage message);
typedef OnWsConnected = void Function();
typedef OnWsDisconnected = void Function(String? reason);
typedef OnWsError = void Function(dynamic error);

/// WebSocket service for real-time communication
class WebSocketService {
  static WebSocketService? _instance;

  WebSocket? _socket;
  SecureStorage? _storage;
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // Message handlers by type
  final Map<WsMessageType, List<OnWsMessage>> _messageHandlers = {};

  // Connection callbacks
  final List<OnWsConnected> _connectedCallbacks = [];
  final List<OnWsDisconnected> _disconnectedCallbacks = [];
  final List<OnWsError> _errorCallbacks = [];

  // Message stream for reactive updates
  final StreamController<WsMessage> _messageController =
      StreamController<WsMessage>.broadcast();

  WebSocketService._();

  factory WebSocketService() {
    _instance ??= WebSocketService._();
    return _instance!;
  }

  static Future<WebSocketService> getInstance() async {
    _instance ??= WebSocketService._();
    if (!_instance!._isInitialized) {
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _storage = await SecureStorage.getInstance();
    _isInitialized = true;
  }

  /// Get the WebSocket URL for location service (via API gateway proxy)
  String get _wsUrl {
    if (kReleaseMode) {
      return 'wss://api.rallypoint.app${ApiConstants.wsLocation}';
    }
    // Development - use API gateway proxy at port 8080
    return 'ws://18.188.1.122:8080${ApiConstants.wsLocation}';
  }

  /// Message stream for reactive updates
  Stream<WsMessage> get messageStream => _messageController.stream;

  /// Filter message stream by type
  Stream<WsMessage> messagesOfType(WsMessageType type) {
    return _messageController.stream.where((msg) => msg.type == type);
  }

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<bool> connect() async {
    if (_isConnected) return true;

    try {
      await _initialize();

      final token = await _storage?.getAccessToken();
      if (token == null) {
        debugPrint('WebSocket: No auth token available');
        return false;
      }

      final uri = Uri.parse('$_wsUrl?token=$token');
      debugPrint('WebSocket: Connecting to $uri');

      _socket = await WebSocket.connect(uri.toString());
      _isConnected = true;
      _reconnectAttempts = 0;

      // Start ping timer
      _startPingTimer();

      // Listen for messages
      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Notify connected callbacks
      for (final callback in _connectedCallbacks) {
        callback();
      }

      debugPrint('WebSocket: Connected successfully');
      return true;
    } catch (e) {
      debugPrint('WebSocket: Connection error: $e');
      _onError(e);
      return false;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _stopTimers();

    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }

    _isConnected = false;
    debugPrint('WebSocket: Disconnected');
  }

  /// Send a message
  void send(WsMessage message) {
    if (!_isConnected || _socket == null) {
      debugPrint('WebSocket: Cannot send - not connected');
      return;
    }

    try {
      final json = jsonEncode(message.toJson());
      _socket!.add(json);
      debugPrint('WebSocket: Sent ${message.type}');
    } catch (e) {
      debugPrint('WebSocket: Send error: $e');
    }
  }

  /// Send raw JSON data
  void sendRaw(Map<String, dynamic> data) {
    if (!_isConnected || _socket == null) {
      debugPrint('WebSocket: Cannot send - not connected');
      return;
    }

    try {
      final json = jsonEncode(data);
      _socket!.add(json);
    } catch (e) {
      debugPrint('WebSocket: Send error: $e');
    }
  }

  /// Subscribe to a specific channel (e.g., walkie channel, team channel)
  void subscribeToChannel(String channelId, {String? channelType}) {
    send(
      WsMessage(
        type: WsMessageType.unknown,
        data: {
          'action': 'subscribe',
          'channel_id': channelId,
          if (channelType != null) 'channel_type': channelType,
        },
      ),
    );
  }

  /// Unsubscribe from a channel
  void unsubscribeFromChannel(String channelId) {
    send(
      WsMessage(
        type: WsMessageType.unknown,
        data: {'action': 'unsubscribe', 'channel_id': channelId},
      ),
    );
  }

  /// Register a message handler for a specific type
  void addMessageHandler(WsMessageType type, OnWsMessage handler) {
    _messageHandlers.putIfAbsent(type, () => []).add(handler);
  }

  /// Remove a message handler
  void removeMessageHandler(WsMessageType type, OnWsMessage handler) {
    _messageHandlers[type]?.remove(handler);
  }

  /// Register connection callbacks
  void onConnected(OnWsConnected callback) {
    _connectedCallbacks.add(callback);
  }

  void onDisconnected(OnWsDisconnected callback) {
    _disconnectedCallbacks.add(callback);
  }

  void onError(OnWsError callback) {
    _errorCallbacks.add(callback);
  }

  /// Remove callbacks
  void removeConnectedCallback(OnWsConnected callback) {
    _connectedCallbacks.remove(callback);
  }

  void removeDisconnectedCallback(OnWsDisconnected callback) {
    _disconnectedCallbacks.remove(callback);
  }

  void removeErrorCallback(OnWsError callback) {
    _errorCallbacks.remove(callback);
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final message = WsMessage.fromJson(json);

      // Handle ping/pong internally
      if (message.type == WsMessageType.ping) {
        send(WsMessage(type: WsMessageType.pong, data: {}));
        return;
      }

      // Broadcast to stream
      _messageController.add(message);

      debugPrint(
        'WebSocket: ALL received: type=${json["type"]}, data=${json["data"]}',
      );

      // Call type-specific handlers
      final handlers = _messageHandlers[message.type];
      if (handlers != null) {
        for (final handler in handlers) {
          handler(message);
        }
      }

      debugPrint('WebSocket: Received ${message.type}');
      debugPrint('WebSocket: Message data: $json');
    } catch (e) {
      debugPrint('WebSocket: Parse error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('WebSocket: Error: $error');

    for (final callback in _errorCallbacks) {
      callback(error);
    }

    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WebSocket: Connection closed');
    _isConnected = false;
    _stopTimers();

    for (final callback in _disconnectedCallbacks) {
      callback('Connection closed');
    }

    _scheduleReconnect();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected) {
        send(WsMessage(type: WsMessageType.ping, data: {}));
      }
    });
  }

  void _stopTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      debugPrint('WebSocket: Reconnect attempt $_reconnectAttempts');
      connect();
    });
  }

  /// Dispose the service
  void dispose() {
    disconnect();
    _messageController.close();
    _messageHandlers.clear();
    _connectedCallbacks.clear();
    _disconnectedCallbacks.clear();
    _errorCallbacks.clear();
    _instance = null;
  }
}

/// Extension for easy location updates
extension WebSocketLocationExtension on WebSocketService {
  void sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? sessionId,
  }) {
    send(
      WsMessage(
        type: WsMessageType.locationUpdate,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          if (sessionId != null) 'session_id': sessionId,
        },
      ),
    );
  }
}

/// Extension for walkie-talkie functionality
extension WebSocketWalkieExtension on WebSocketService {
  void joinWalkieChannel(String channelId) {
    subscribeToChannel(channelId, channelType: 'walkie');
    send(
      WsMessage(
        type: WsMessageType.walkieParticipantJoined,
        data: {'channel_id': channelId},
        channelId: channelId,
      ),
    );
  }

  void leaveWalkieChannel(String channelId) {
    send(
      WsMessage(
        type: WsMessageType.walkieParticipantLeft,
        data: {'channel_id': channelId},
        channelId: channelId,
      ),
    );
    unsubscribeFromChannel(channelId);
  }

  void startSpeaking(String channelId) {
    send(
      WsMessage(
        type: WsMessageType.walkieSpeakingStart,
        data: {'channel_id': channelId},
        channelId: channelId,
      ),
    );
  }

  void stopSpeaking(String channelId) {
    send(
      WsMessage(
        type: WsMessageType.walkieSpeakingEnd,
        data: {'channel_id': channelId},
        channelId: channelId,
      ),
    );
  }
}

/// Extension for team updates
extension WebSocketTeamExtension on WebSocketService {
  void joinTeamChannel(String teamId) {
    subscribeToChannel(teamId, channelType: 'team');
  }

  void leaveTeamChannel(String teamId) {
    unsubscribeFromChannel(teamId);
  }

  Stream<WsMessage> get teamActivityStream =>
      messagesOfType(WsMessageType.teamActivityUpdate);

  Stream<WsMessage> get teamMemberStatusStream => messageStream.where(
    (msg) =>
        msg.type == WsMessageType.teamMemberOnline ||
        msg.type == WsMessageType.teamMemberOffline,
  );
}

/// Extension for delivery updates
extension WebSocketDeliveryExtension on WebSocketService {
  Stream<WsMessage> get deliveryUpdatesStream => messageStream.where(
    (msg) =>
        msg.type == WsMessageType.deliveryCreated ||
        msg.type == WsMessageType.deliveryUpdated ||
        msg.type == WsMessageType.deliveryStatusChanged,
  );
}

/// Extension for chat functionality
extension WebSocketChatExtension on WebSocketService {
  /// Join a chat conversation channel
  void joinChatConversation(String conversationId) {
    subscribeToChannel(conversationId, channelType: 'chat');
  }

  /// Leave a chat conversation channel
  void leaveChatConversation(String conversationId) {
    unsubscribeFromChannel(conversationId);
  }

  /// Send a chat message
  void sendChatMessage({
    required String conversationId,
    required String content,
    String? tempId,
  }) {
    send(
      WsMessage(
        type: WsMessageType.chatMessage,
        data: {
          'conversation_id': conversationId,
          'content': content,
          if (tempId != null) 'temp_id': tempId,
        },
        channelId: conversationId,
      ),
    );
  }

  /// Send typing indicator
  void sendTypingIndicator({
    required String conversationId,
    required bool isTyping,
  }) {
    send(
      WsMessage(
        type: WsMessageType.chatTyping,
        data: {'conversation_id': conversationId, 'is_typing': isTyping},
        channelId: conversationId,
      ),
    );
  }

  /// Mark messages as read
  void markChatAsRead(String conversationId) {
    send(
      WsMessage(
        type: WsMessageType.chatRead,
        data: {'conversation_id': conversationId},
        channelId: conversationId,
      ),
    );
  }

  /// Stream of chat messages for a specific conversation
  Stream<WsMessage> chatMessagesFor(String conversationId) {
    return messageStream.where(
      (msg) =>
          msg.type == WsMessageType.chatMessage &&
          msg.channelId == conversationId,
    );
  }

  /// Stream of all chat-related events
  Stream<WsMessage> get chatStream => messageStream.where(
    (msg) =>
        msg.type == WsMessageType.chatMessage ||
        msg.type == WsMessageType.chatMessageUpdated ||
        msg.type == WsMessageType.chatMessageDeleted ||
        msg.type == WsMessageType.chatTyping ||
        msg.type == WsMessageType.chatRead ||
        msg.type == WsMessageType.chatParticipantOnline ||
        msg.type == WsMessageType.chatParticipantOffline,
  );

  /// Stream of typing indicators
  Stream<WsMessage> get typingStream =>
      messagesOfType(WsMessageType.chatTyping);

  /// Stream of participant status changes
  Stream<WsMessage> get chatParticipantStatusStream => messageStream.where(
    (msg) =>
        msg.type == WsMessageType.chatParticipantOnline ||
        msg.type == WsMessageType.chatParticipantOffline,
  );
}
