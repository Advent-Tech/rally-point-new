part of 'chat_bloc.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class ChatInitial extends ChatState {}

/// Loading state
class ChatLoading extends ChatState {}

/// Conversations list loaded
class ChatConversationsLoaded extends ChatState {
  final List<ChatConversation> conversations;

  const ChatConversationsLoaded({required this.conversations});

  @override
  List<Object?> get props => [conversations];
}

/// Currently in a conversation (viewing messages)
class ChatInConversation extends ChatState {
  final ChatConversation conversation;
  final List<ChatMessage> messages;
  final List<TypingIndicator> typingUsers;
  final bool isLoadingMore;

  const ChatInConversation({
    required this.conversation,
    required this.messages,
    this.typingUsers = const [],
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [conversation, messages, typingUsers, isLoadingMore];

  ChatInConversation copyWith({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    List<TypingIndicator>? typingUsers,
    bool? isLoadingMore,
  }) {
    return ChatInConversation(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      typingUsers: typingUsers ?? this.typingUsers,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  /// Get typing users text (e.g., "John is typing..." or "John and Jane are typing...")
  String? get typingText {
    if (typingUsers.isEmpty) return null;
    if (typingUsers.length == 1) {
      return '${typingUsers.first.userName} is typing...';
    }
    if (typingUsers.length == 2) {
      return '${typingUsers[0].userName} and ${typingUsers[1].userName} are typing...';
    }
    return '${typingUsers.length} people are typing...';
  }
}

/// Error state
class ChatError extends ChatState {
  final String message;

  const ChatError({required this.message});

  @override
  List<Object?> get props => [message];
}
