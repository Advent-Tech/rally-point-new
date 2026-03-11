part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Load all conversations for the current user
class ChatLoadConversations extends ChatEvent {
  final int limit;
  final int offset;

  const ChatLoadConversations({this.limit = 50, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}

/// Select a conversation to view
class ChatSelectConversation extends ChatEvent {
  final String conversationId;

  const ChatSelectConversation({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Load messages for a conversation
class ChatLoadMessages extends ChatEvent {
  final String conversationId;
  final int limit;
  final int offset;

  const ChatLoadMessages({
    required this.conversationId,
    this.limit = 50,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [conversationId, limit, offset];
}

/// Send a message
class ChatSendMessage extends ChatEvent {
  final String conversationId;
  final String content;
  final ChatMessageType messageType;
  final String? mediaUrl;
  final String? replyToId;

  const ChatSendMessage({
    required this.conversationId,
    required this.content,
    this.messageType = ChatMessageType.text,
    this.mediaUrl,
    this.replyToId,
  });

  @override
  List<Object?> get props => [conversationId, content, messageType, mediaUrl, replyToId];
}

/// Create a new direct conversation
class ChatCreateDirect extends ChatEvent {
  final String otherUserId;
  final String? otherUserName;

  const ChatCreateDirect({required this.otherUserId, this.otherUserName});

  @override
  List<Object?> get props => [otherUserId, otherUserName];
}

/// Get or create team conversation
class ChatGetTeamConversation extends ChatEvent {
  final String teamId;
  final String? teamName;

  const ChatGetTeamConversation({required this.teamId, this.teamName});

  @override
  List<Object?> get props => [teamId, teamName];
}

/// Mark messages as read
class ChatMarkAsRead extends ChatEvent {
  final String conversationId;
  final String messageId;

  const ChatMarkAsRead({required this.conversationId, required this.messageId});

  @override
  List<Object?> get props => [conversationId, messageId];
}

/// Send typing indicator
class ChatSendTyping extends ChatEvent {
  final String conversationId;
  final bool isTyping;

  const ChatSendTyping({required this.conversationId, required this.isTyping});

  @override
  List<Object?> get props => [conversationId, isTyping];
}

/// Message received from WebSocket
class ChatMessageReceived extends ChatEvent {
  final Map<String, dynamic> messageData;

  const ChatMessageReceived({required this.messageData});

  @override
  List<Object?> get props => [messageData];
}

/// Typing indicator received from WebSocket
class ChatTypingReceived extends ChatEvent {
  final String conversationId;
  final String userId;
  final String userName;
  final bool isTyping;

  const ChatTypingReceived({
    required this.conversationId,
    required this.userId,
    required this.userName,
    required this.isTyping,
  });

  @override
  List<Object?> get props => [conversationId, userId, userName, isTyping];
}

/// User online status changed
class ChatUserStatusChanged extends ChatEvent {
  final String userId;
  final bool isOnline;

  const ChatUserStatusChanged({required this.userId, required this.isOnline});

  @override
  List<Object?> get props => [userId, isOnline];
}

/// Edit a message
class ChatEditMessage extends ChatEvent {
  final String messageId;
  final String newContent;

  const ChatEditMessage({required this.messageId, required this.newContent});

  @override
  List<Object?> get props => [messageId, newContent];
}

/// Delete a message
class ChatDeleteMessage extends ChatEvent {
  final String messageId;

  const ChatDeleteMessage({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

/// Clear current conversation
class ChatClearCurrentConversation extends ChatEvent {
  const ChatClearCurrentConversation();
}

/// Connect to WebSocket for real-time updates
class ChatConnectWebSocket extends ChatEvent {
  final String? conversationId;

  const ChatConnectWebSocket({this.conversationId});

  @override
  List<Object?> get props => [conversationId];
}

/// Disconnect from WebSocket
class ChatDisconnectWebSocket extends ChatEvent {
  const ChatDisconnectWebSocket();
}

/// Internal: poll for new messages (WebSocket fallback)
class _ChatPollMessages extends ChatEvent {
  const _ChatPollMessages();
}
