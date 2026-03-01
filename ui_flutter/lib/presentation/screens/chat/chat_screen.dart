import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatBloc _chatBloc;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  String _currentUserId = '';
  bool _isAtBottom = true;
  int _unreadCount = 0;
  List<ChatMessage> _previousMessages = [];

  @override
  void initState() {
    super.initState();
    _chatBloc = ChatBloc();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
      _chatBloc.setCurrentUser(
        authState.user.id,
        authState.user.displayName ?? 'User',
      );
    }

    _chatBloc.add(
      ChatSelectConversation(conversationId: widget.conversationId),
    );

    _messageController.addListener(_onTextChanged);

    _scrollController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      const threshold = 100.0;

      final isAtBottom = (maxScroll - currentScroll) <= threshold;
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
          if (isAtBottom) {
            _unreadCount = 0;
          }
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _unreadCount = 0;
        _isAtBottom = true;
      });
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.isNotEmpty;
    if (hasText != _isTyping) {
      _isTyping = hasText;
      _chatBloc.add(
        ChatSendTyping(
          conversationId: widget.conversationId,
          isTyping: hasText,
        ),
      );
    }
  }

  @override
  void dispose() {
    _chatBloc.add(const ChatDisconnectWebSocket());
    _chatBloc.close();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _chatBloc.add(
      ChatSendMessage(conversationId: widget.conversationId, content: text),
    );

    _messageController.clear();
    _isTyping = false;

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _chatBloc,
      child: BlocListener<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatInConversation) {
            final newMessages = state.messages;
            if (newMessages.length > _previousMessages.length) {
              if (_isAtBottom) {
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
              } else {
                final newCount = newMessages.length - _previousMessages.length;
                setState(() {
                  _unreadCount += newCount;
                });
              }
            }
            _previousMessages = List.from(newMessages);
          }
        },
        child: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            String title = 'Chat';
            String? subtitle;
            List<ChatMessage> messages = [];
            String? typingText;

            if (state is ChatInConversation) {
              title = state.conversation.getDisplayName(_currentUserId);
              messages = state.messages;
              typingText = state.typingText;

              // Show online status for direct chats
              if (state.conversation.type == ConversationType.direct) {
                final otherUser = state.conversation.participants.firstWhere(
                  (p) => p.userId != _currentUserId,
                  orElse: () => state.conversation.participants.first,
                );
                subtitle = otherUser.isOnline ? 'Online' : null;
              } else {
                subtitle = '${state.conversation.participants.length} members';
              }
            }

            return Scaffold(
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (state is ChatInConversation &&
                      state.conversation.type == ConversationType.team)
                    IconButton(
                      icon: const Icon(Icons.group),
                      onPressed: () =>
                          _showParticipants(context, state.conversation),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      // Handle menu actions
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'mute', child: Text('Mute')),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear chat'),
                      ),
                    ],
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Column(
                    children: [
                      // Messages list
                      Expanded(
                        child:
                            (state is ChatLoading ||
                                state is ChatInitial ||
                                (state is ChatInConversation &&
                                    state.isLoadingMessages))
                            ? _buildMessageShimmer(isDark)
                            : messages.isEmpty
                            ? _buildEmptyMessages(context, isDark)
                            : _buildMessagesList(messages, isDark),
                      ),

                      // Typing indicator
                      if (typingText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            typingText,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),

                      // Message input
                      _buildMessageInput(context, isDark),
                    ],
                  ),

                  // Unread messages indicator
                  if (_unreadCount > 0)
                    Positioned(
                      bottom: 100,
                      right: 16,
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_unreadCount new message${_unreadCount > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageShimmer(bool isDark) {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isRight = index % 3 == 0;
        final width = (index % 2 == 0) ? 0.6 : 0.45;
        return Align(
          alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            width: MediaQuery.of(context).size.width * width,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [shimmerBase, shimmerHighlight, shimmerBase],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyMessages(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<ChatMessage> messages, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == _currentUserId;
        final showAvatar =
            !isMe &&
            (index == 0 || messages[index - 1].senderId != message.senderId);
        final showTime =
            index == messages.length - 1 ||
            messages[index + 1].senderId != message.senderId ||
            (messages[index + 1].createdAt
                        ?.difference(message.createdAt ?? DateTime.now())
                        .inMinutes ??
                    0) >
                5;

        return _MessageBubble(
          message: message,
          isMe: isMe,
          showAvatar: showAvatar,
          showTime: showTime,
          isDark: isDark,
          onLongPress: () => _showMessageOptions(context, message, isMe),
        );
      },
    );
  }

  Widget _buildMessageInput(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              // TODO: Implement file attachment
            },
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showParticipants(BuildContext context, ChatConversation conversation) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Participants (${conversation.participants.length})',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: conversation.participants.length,
                itemBuilder: (context, index) {
                  final participant = conversation.participants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: participant.avatarUrl != null
                          ? NetworkImage(participant.avatarUrl!)
                          : null,
                      child: participant.avatarUrl == null
                          ? Text(participant.userName[0].toUpperCase())
                          : null,
                    ),
                    title: Text(participant.userName),
                    subtitle: Text(_formatRole(participant.role.name)),
                    trailing: participant.isOnline
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(
    BuildContext context,
    ChatMessage message,
    bool isMe,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                // TODO: Copy to clipboard
                Navigator.pop(context);
              },
            ),
            if (isMe && !message.isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _chatBloc.add(ChatDeleteMessage(messageId: message.id));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ChatMessage message) {
    final controller = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _chatBloc.add(
                ChatEditMessage(
                  messageId: message.id,
                  newContent: controller.text,
                ),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '';
    return role[0].toUpperCase() + role.substring(1);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final bool showTime;
  final bool isDark;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.showTime,
    required this.isDark,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 8 : 2,
        bottom: showTime ? 8 : 2,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(
                        message.senderName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            )
          else if (!isMe)
            const SizedBox(width: 40),
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary
                      : (isDark ? Colors.grey[800] : Colors.grey[200]),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && showAvatar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (showTime || message.isEdited || message.isSending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.formattedTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white70
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                              ),
                            ),
                            if (message.isEdited)
                              Text(
                                ' (edited)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: isMe
                                      ? Colors.white70
                                      : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                ),
                              ),
                            if (message.isSending)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isMe
                                        ? Colors.white70
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            if (message.hasFailed)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: AppColors.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
