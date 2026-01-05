import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';

/// Screen that handles loading a team conversation and displaying chat
class TeamChatScreen extends StatefulWidget {
  final String teamId;
  final String? teamName;

  const TeamChatScreen({
    super.key,
    required this.teamId,
    this.teamName,
  });

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  late ChatBloc _chatBloc;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _chatBloc = ChatBloc();

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUserId = authState.user.id;
      _chatBloc.setCurrentUser(authState.user.id, authState.user.displayName ?? 'User');
    }

    // Load team conversation
    _chatBloc.add(ChatGetTeamConversation(
      teamId: widget.teamId,
      teamName: widget.teamName,
    ));

    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final state = _chatBloc.state;
    if (state is! ChatInConversation) return;

    final hasText = _messageController.text.isNotEmpty;
    if (hasText != _isTyping) {
      _isTyping = hasText;
      _chatBloc.add(ChatSendTyping(
        conversationId: state.conversation.id,
        isTyping: hasText,
      ));
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
    debugPrint('TeamChatScreen: _sendMessage called');

    final state = _chatBloc.state;
    debugPrint('TeamChatScreen: Bloc state type: ${state.runtimeType}');

    if (state is! ChatInConversation) {
      debugPrint('TeamChatScreen: Not in conversation, returning');
      return;
    }

    final text = _messageController.text.trim();
    debugPrint('TeamChatScreen: Message text: "$text"');

    if (text.isEmpty) {
      debugPrint('TeamChatScreen: Empty text, returning');
      return;
    }

    debugPrint('TeamChatScreen: Adding ChatSendMessage event');
    _chatBloc.add(ChatSendMessage(
      conversationId: state.conversation.id,
      content: text,
    ));

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
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatLoading) {
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.teamName ?? 'Team Chat'),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is ChatError) {
            return Scaffold(
              appBar: AppBar(
                title: Text(widget.teamName ?? 'Team Chat'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load chat',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _chatBloc.add(ChatGetTeamConversation(
                          teamId: widget.teamId,
                          teamName: widget.teamName,
                        ));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          String title = widget.teamName ?? 'Team Chat';
          String? subtitle;
          List<ChatMessage> messages = [];
          String? typingText;

          if (state is ChatInConversation) {
            title = state.conversation.name ?? widget.teamName ?? 'Team Chat';
            messages = state.messages;
            typingText = state.typingText;
            subtitle = '${state.conversation.participants.length} members';
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
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
              actions: [
                if (state is ChatInConversation)
                  IconButton(
                    icon: const Icon(Icons.group),
                    onPressed: () => _showParticipants(context, state.conversation),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // Handle menu actions
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'mute', child: Text('Mute')),
                    const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                // Messages list
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyMessages(context, isDark)
                      : _buildMessagesList(messages, isDark),
                ),

                // Typing indicator
                if (typingText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      typingText,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Message input
                _buildMessageInput(context, isDark),
              ],
            ),
          );
        },
      ),
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
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with your team!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
        final showAvatar = !isMe && (index == 0 || messages[index - 1].senderId != message.senderId);
        final showTime = index == messages.length - 1 ||
            messages[index + 1].senderId != message.senderId ||
            (messages[index + 1].createdAt?.difference(message.createdAt ?? DateTime.now()).inMinutes ?? 0) > 5;

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
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                    subtitle: Text(participant.role.name),
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

  void _showMessageOptions(BuildContext context, ChatMessage message, bool isMe) {
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
                title: const Text('Delete', style: TextStyle(color: AppColors.error)),
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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _chatBloc.add(ChatEditMessage(
                messageId: message.id,
                newContent: controller.text,
              ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            color: isDark ? AppColors.textSecondaryDark : AppColors.primary,
                          ),
                        ),
                      ),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
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
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                                    color: isMe ? Colors.white70 : AppColors.primary,
                                  ),
                                ),
                              ),
                            if (message.hasFailed)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.error_outline, size: 14, color: AppColors.error),
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
