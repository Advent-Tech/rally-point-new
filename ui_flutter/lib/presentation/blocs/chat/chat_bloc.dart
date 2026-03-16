import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/chat_model.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ApiClient? _apiClient;
  WebSocket? _chatSocket;
  StreamSubscription? _socketSubscription;
  bool _isInitialized = false;
  String? _currentUserId;
  String? _currentUserName;

  // Typing indicator timers
  final Map<String, Timer> _typingTimers = {};

  // Polling timer (WebSocket fallback)
  Timer? _pollTimer;

  ChatBloc() : super(ChatInitial()) {
    on<ChatLoadConversations>(_onLoadConversations);
    on<ChatSelectConversation>(_onSelectConversation);
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatCreateDirect>(_onCreateDirect);
    on<ChatGetTeamConversation>(_onGetTeamConversation);
    on<ChatMarkAsRead>(_onMarkAsRead);
    on<ChatSendTyping>(_onSendTyping);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatTypingReceived>(_onTypingReceived);
    on<ChatUserStatusChanged>(_onUserStatusChanged);
    on<ChatEditMessage>(_onEditMessage);
    on<ChatDeleteMessage>(_onDeleteMessage);
    on<ChatClearCurrentConversation>(_onClearCurrentConversation);
    on<ChatConnectWebSocket>(_onConnectWebSocket);
    on<ChatDisconnectWebSocket>(_onDisconnectWebSocket);
    on<_ChatPollMessages>(_onPollMessages);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  /// Get the chat WebSocket URL based on environment
  String _getChatWsUrl(String conversationId) {
    String baseUrl;
    if (kReleaseMode) {
      baseUrl = 'wss://backend.lightsquads.com';
    } else {
      // Use production server for real devices
      final httpBase = ApiConstants.prodBaseUrl;
      baseUrl = httpBase
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
    }
    return '$baseUrl${ApiConstants.wsChat}?user_id=$_currentUserId&conversation_id=$conversationId';
  }

  ApiClient get _api => _apiClient!;

  void setCurrentUser(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
  }

  Future<void> _onLoadConversations(
    ChatLoadConversations event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());

    try {
      await _initialize();

      final response = await _api.get(
        '/api/chat/conversations',
        queryParameters: {'limit': event.limit, 'offset': event.offset},
      );

      if (response.statusCode == 200) {
        final data = response.data['conversations'] ?? [];
        final conversations = (data as List)
            .map<ChatConversation>((json) => ChatConversation.fromJson(json))
            .toList();

        emit(ChatConversationsLoaded(conversations: conversations));
      } else {
        emit(ChatConversationsLoaded(conversations: []));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error loading conversations: $e');
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onSelectConversation(
    ChatSelectConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _api.get(
        '/api/chat/conversations/${event.conversationId}',
      );

      if (response.statusCode == 200) {
        final conversation = ChatConversation.fromJson(response.data);

        emit(
          ChatInConversation(
            conversation: conversation,
            messages: [],
            typingUsers: [],
            isLoadingMessages: true,
          ),
        );

        // Load messages
        add(ChatLoadMessages(conversationId: event.conversationId));

        // Connect WebSocket for this conversation
        add(ChatConnectWebSocket(conversationId: event.conversationId));
      } else {
        emit(const ChatError(message: 'Failed to load conversation'));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error selecting conversation: $e');
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onLoadMessages(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatInConversation) return;

    try {
      await _initialize();

      final response = await _api.get(
        '/api/chat/conversations/${event.conversationId}/messages',
        queryParameters: {'limit': event.limit, 'offset': event.offset},
      );

      if (response.statusCode == 200) {
        final data = response.data['messages'] ?? [];
        final messages = (data as List)
            .map<ChatMessage>((json) => ChatMessage.fromJson(json))
            .toList();

        emit(
          currentState.copyWith(messages: messages, isLoadingMessages: false),
        );

        // Mark messages as read to clear unread count
        if (messages.isNotEmpty) {
          add(
            ChatMarkAsRead(
              conversationId: event.conversationId,
              messageId: messages.last.id,
            ),
          );
        }
      } else {
        emit(currentState.copyWith(isLoadingMessages: false));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error loading messages: $e');
      final latestState = state;
      if (latestState is ChatInConversation) {
        emit(latestState.copyWith(isLoadingMessages: false));
      }
    }
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    debugPrint(
      'ChatBloc: _onSendMessage called with content: "${event.content}"',
    );

    final currentState = state;
    debugPrint('ChatBloc: Current state type: ${currentState.runtimeType}');

    if (currentState is! ChatInConversation) {
      debugPrint('ChatBloc: Not in conversation, returning early');
      return;
    }

    try {
      await _initialize();

      // Create optimistic message
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticMessage = ChatMessage(
        id: tempId,
        conversationId: event.conversationId,
        senderId: _currentUserId ?? '',
        senderName: _currentUserName ?? 'You',
        content: event.content,
        messageType: event.messageType,
        mediaUrl: event.mediaUrl,
        replyToId: event.replyToId,
        createdAt: DateTime.now(),
        isSending: true,
      );

      // Add optimistic message
      final messagesWithOptimistic = [
        ...currentState.messages,
        optimisticMessage,
      ];
      emit(currentState.copyWith(messages: messagesWithOptimistic));

      debugPrint(
        'ChatBloc: Sending message to conversation ${event.conversationId}',
      );

      // Send to server
      final response = await _api.post(
        '/api/chat/messages',
        data: {
          'conversation_id': event.conversationId,
          'content': event.content,
          'message_type': event.messageType.name,
          if (event.mediaUrl != null) 'media_url': event.mediaUrl,
          if (event.replyToId != null) 'reply_to_id': event.replyToId,
        },
      );

      debugPrint(
        'ChatBloc: Send message response status: ${response.statusCode}',
      );

      // Get the latest state after the API call
      final latestState = state;
      if (latestState is! ChatInConversation) return;

      if (response.statusCode == 201) {
        final sentMessage = ChatMessage.fromJson(response.data);

        // Replace optimistic message with real one using latest state
        final finalMessages =
            latestState.messages.where((m) => m.id != tempId).toList()
              ..add(sentMessage);

        emit(latestState.copyWith(messages: finalMessages));
      } else {
        debugPrint(
          'ChatBloc: Send message failed with status ${response.statusCode}: ${response.data}',
        );
        // Mark as failed using latest state
        final failedMessages = latestState.messages.map((m) {
          if (m.id == tempId) {
            return m.copyWith(isSending: false, hasFailed: true);
          }
          return m;
        }).toList();
        emit(latestState.copyWith(messages: failedMessages));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error sending message: $e');
      // Try to mark the message as failed
      final latestState = state;
      if (latestState is ChatInConversation) {
        final failedMessages = latestState.messages.map((m) {
          if (m.isSending) {
            return m.copyWith(isSending: false, hasFailed: true);
          }
          return m;
        }).toList();
        emit(latestState.copyWith(messages: failedMessages));
      }
    }
  }

  Future<void> _onCreateDirect(
    ChatCreateDirect event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());

    try {
      await _initialize();

      final response = await _api.post(
        '/api/chat/conversations/direct',
        data: {'other_user_id': event.otherUserId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final conversation = ChatConversation.fromJson(response.data);

        emit(
          ChatInConversation(
            conversation: conversation,
            messages: [],
            typingUsers: [],
            isLoadingMessages: true,
          ),
        );

        // Load messages if any exist
        add(ChatLoadMessages(conversationId: conversation.id));
        add(ChatConnectWebSocket(conversationId: conversation.id));
      } else {
        emit(const ChatError(message: 'Failed to create conversation'));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error creating direct conversation: $e');
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onGetTeamConversation(
    ChatGetTeamConversation event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());

    try {
      await _initialize();

      final response = await _api.get(
        '/api/chat/conversations/team/${event.teamId}',
        queryParameters: {
          if (event.teamName != null) 'name': event.teamName,
          if (_currentUserName != null) 'user_name': _currentUserName,
        },
      );

      if (response.statusCode == 200) {
        final conversation = ChatConversation.fromJson(response.data);

        emit(
          ChatInConversation(
            conversation: conversation,
            messages: [],
            typingUsers: [],
            isLoadingMessages: true,
          ),
        );

        add(ChatLoadMessages(conversationId: conversation.id));
        add(ChatConnectWebSocket(conversationId: conversation.id));
      } else {
        emit(const ChatError(message: 'Failed to get team conversation'));
      }
    } catch (e) {
      debugPrint('ChatBloc: Error getting team conversation: $e');
      emit(ChatError(message: e.toString()));
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _initialize();

      await _api.post(
        '/api/chat/messages/read',
        data: {
          'conversation_id': event.conversationId,
          'message_id': event.messageId,
        },
      );
    } catch (e) {
      debugPrint('ChatBloc: Error marking as read: $e');
    }
  }

  Future<void> _onSendTyping(
    ChatSendTyping event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _initialize();

      await _api.post(
        '/api/chat/conversations/${event.conversationId}/typing',
        data: {'is_typing': event.isTyping},
      );
    } catch (e) {
      debugPrint('ChatBloc: Error sending typing indicator: $e');
    }
  }

  Future<void> _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatInConversation) return;

    try {
      final message = ChatMessage.fromJson(event.messageData);

      // Only add if it's for the current conversation and not already present
      if (message.conversationId == currentState.conversation.id) {
        final exists = currentState.messages.any((m) => m.id == message.id);
        if (!exists) {
          final updatedMessages = [...currentState.messages, message];
          emit(currentState.copyWith(messages: updatedMessages));
        }
      }
    } catch (e) {
      debugPrint('ChatBloc: Error processing received message: $e');
    }
  }

  Future<void> _onTypingReceived(
    ChatTypingReceived event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatInConversation) return;

    if (event.conversationId != currentState.conversation.id) return;
    if (event.userId == _currentUserId) return; // Ignore own typing

    // Cancel existing timer for this user
    _typingTimers[event.userId]?.cancel();

    List<TypingIndicator> updatedTyping;

    if (event.isTyping) {
      // Add or update typing indicator
      final indicator = TypingIndicator(
        conversationId: event.conversationId,
        userId: event.userId,
        userName: event.userName,
        isTyping: true,
      );

      updatedTyping = [
        ...currentState.typingUsers.where((t) => t.userId != event.userId),
        indicator,
      ];

      // Auto-remove after 5 seconds
      _typingTimers[event.userId] = Timer(const Duration(seconds: 5), () {
        add(
          ChatTypingReceived(
            conversationId: event.conversationId,
            userId: event.userId,
            userName: event.userName,
            isTyping: false,
          ),
        );
      });
    } else {
      // Remove typing indicator
      updatedTyping = currentState.typingUsers
          .where((t) => t.userId != event.userId)
          .toList();
    }

    emit(currentState.copyWith(typingUsers: updatedTyping));
  }

  Future<void> _onUserStatusChanged(
    ChatUserStatusChanged event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatInConversation) return;

    // Update participant status
    final updatedParticipants = currentState.conversation.participants.map((p) {
      if (p.userId == event.userId) {
        return p.copyWith(isOnline: event.isOnline);
      }
      return p;
    }).toList();

    emit(
      currentState.copyWith(
        conversation: currentState.conversation.copyWith(
          participants: updatedParticipants,
        ),
      ),
    );
  }

  Future<void> _onEditMessage(
    ChatEditMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _api.put(
        '/api/chat/messages/${event.messageId}',
        data: {'content': event.newContent},
      );

      if (response.statusCode == 200) {
        final currentState = state;
        if (currentState is ChatInConversation) {
          final updatedMessages = currentState.messages.map((m) {
            if (m.id == event.messageId) {
              return m.copyWith(content: event.newContent, isEdited: true);
            }
            return m;
          }).toList();
          emit(currentState.copyWith(messages: updatedMessages));
        }
      }
    } catch (e) {
      debugPrint('ChatBloc: Error editing message: $e');
    }
  }

  Future<void> _onDeleteMessage(
    ChatDeleteMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _api.delete(
        '/api/chat/messages/${event.messageId}',
      );

      if (response.statusCode == 200) {
        final currentState = state;
        if (currentState is ChatInConversation) {
          final updatedMessages = currentState.messages.map((m) {
            if (m.id == event.messageId) {
              return m.copyWith(isDeleted: true, content: '[Message deleted]');
            }
            return m;
          }).toList();
          emit(currentState.copyWith(messages: updatedMessages));
        }
      }
    } catch (e) {
      debugPrint('ChatBloc: Error deleting message: $e');
    }
  }

  Future<void> _onClearCurrentConversation(
    ChatClearCurrentConversation event,
    Emitter<ChatState> emit,
  ) async {
    add(const ChatDisconnectWebSocket());
    add(const ChatLoadConversations());
  }

  Future<void> _onConnectWebSocket(
    ChatConnectWebSocket event,
    Emitter<ChatState> emit,
  ) async {
    // Disconnect existing socket if any
    await _disconnectChatSocket();
    _stopPolling();

    if (event.conversationId == null || _currentUserId == null) {
      debugPrint(
        'ChatBloc: Cannot connect WebSocket - missing conversationId or userId',
      );
      // Still start polling as fallback
      _startPolling();
      return;
    }

    await _initialize();

    try {
      final wsUrl = _getChatWsUrl(event.conversationId!);

      _chatSocket = await WebSocket.connect(wsUrl);

      // Listen for messages
      _socketSubscription = _chatSocket!.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) {
          debugPrint('ChatBloc: WebSocket error: $error');
        },
        onDone: () {
          _chatSocket = null;
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('ChatBloc: Failed to connect WebSocket: $e');
    }

    // Always start polling as fallback (WebSocket may silently fail)
    _startPolling();
  }

  void _handleWebSocketMessage(dynamic data) {
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final type = json['type']?.toString();
      debugPrint('ChatBloc: Received WebSocket message type: $type');

      if (type == 'chat_message') {
        final messageData = json['data'] ?? json;
        add(
          ChatMessageReceived(
            messageData: messageData is Map<String, dynamic> ? messageData : {},
          ),
        );
      } else if (type == 'chat_typing') {
        final msgData = json['data'] ?? json;
        add(
          ChatTypingReceived(
            conversationId: msgData['conversation_id']?.toString() ?? '',
            userId: msgData['user_id']?.toString() ?? '',
            userName: msgData['user_name']?.toString() ?? '',
            isTyping: msgData['is_typing'] ?? false,
          ),
        );
      } else if (type == 'chat_user_online' || type == 'chat_user_offline') {
        final msgData = json['data'] ?? json;
        add(
          ChatUserStatusChanged(
            userId: msgData['user_id']?.toString() ?? '',
            isOnline: type == 'chat_user_online',
          ),
        );
      }
    } catch (e) {
      debugPrint('ChatBloc: Error parsing WebSocket message: $e');
    }
  }

  Future<void> _onDisconnectWebSocket(
    ChatDisconnectWebSocket event,
    Emitter<ChatState> emit,
  ) async {
    _stopPolling();
    await _disconnectChatSocket();
  }

  Future<void> _disconnectChatSocket() async {
    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_chatSocket != null) {
      await _chatSocket!.close();
      _chatSocket = null;
    }

    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      add(const _ChatPollMessages());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _onPollMessages(
    _ChatPollMessages event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatInConversation) return;

    try {
      await _initialize();

      final response = await _api.get(
        '/api/chat/conversations/${currentState.conversation.id}/messages',
        queryParameters: {'limit': 50},
      );

      if (response.statusCode == 200) {
        final data = response.data['messages'] ?? [];
        final serverMessages = (data as List)
            .map<ChatMessage>((json) => ChatMessage.fromJson(json))
            .toList();

        // Check if there are new messages not in our current list
        final existingIds = currentState.messages.map((m) => m.id).toSet();
        final hasNew = serverMessages.any((m) => !existingIds.contains(m.id));

        if (hasNew) {
          // Merge: keep existing messages, add new ones
          final merged = <ChatMessage>[];
          final mergedIds = <String>{};
          for (final m in currentState.messages) {
            // Skip temp/sending messages that now have real versions
            if (!m.isSending) {
              merged.add(m);
              mergedIds.add(m.id);
            }
          }
          for (final m in serverMessages) {
            if (!mergedIds.contains(m.id)) {
              merged.add(m);
              mergedIds.add(m.id);
            }
          }
          merged.sort(
            (a, b) => (a.createdAt ?? DateTime(0)).compareTo(
              b.createdAt ?? DateTime(0),
            ),
          );
          emit(currentState.copyWith(messages: merged));
        }
      }
    } catch (_) {
      // Silent failure — polling will retry
    }
  }

  @override
  Future<void> close() {
    _stopPolling();
    _disconnectChatSocket();
    return super.close();
  }
}
