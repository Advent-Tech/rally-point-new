import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/chat/chat_bloc.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late ChatBloc _chatBloc;

  @override
  void initState() {
    super.initState();
    _chatBloc = ChatBloc();

    // Set current user info
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _chatBloc.setCurrentUser(authState.user.id, authState.user.displayName ?? 'User');
    }

    _chatBloc.add(const ChatLoadConversations());
  }

  @override
  void dispose() {
    _chatBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';

    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group_add),
              onPressed: () => _showNewChatDialog(context),
              tooltip: 'New Chat',
            ),
          ],
        ),
        body: BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            if (state is ChatLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ChatError) {
              return Center(
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
                      'Error loading conversations',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _chatBloc.add(const ChatLoadConversations()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is ChatConversationsLoaded) {
              if (state.conversations.isEmpty) {
                return _buildEmptyState(context, isDark);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  _chatBloc.add(const ChatLoadConversations());
                },
                child: ListView.builder(
                  itemCount: state.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = state.conversations[index];
                    return _ConversationTile(
                      conversation: conversation,
                      currentUserId: currentUserId,
                      isDark: isDark,
                      onTap: () => context.push('/chat/${conversation.id}'),
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showNewChatDialog(context),
          child: const Icon(Icons.chat),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new chat with a team member',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showNewChatDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Chat'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NewChatBottomSheet(chatBloc: _chatBloc),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final String currentUserId;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = conversation.getDisplayName(currentUserId);
    final avatarUrl = conversation.getAvatarUrl(currentUserId);
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: conversation.type == ConversationType.team
            ? AppColors.primary.withAlpha(50)
            : AppColors.secondary.withAlpha(50),
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Icon(
                conversation.type == ConversationType.team ? Icons.groups : Icons.person,
                color: conversation.type == ConversationType.team
                    ? AppColors.primary
                    : AppColors.secondary,
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.lastMessageAt != null)
            Text(
              _formatTime(conversation.lastMessageAt!),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread
                    ? AppColors.primary
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessage ?? 'No messages yet',
              style: TextStyle(
                color: hasUnread
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('M/d').format(time);
    }
  }
}

class _NewChatBottomSheet extends StatefulWidget {
  final ChatBloc chatBloc;

  const _NewChatBottomSheet({required this.chatBloc});

  @override
  State<_NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<_NewChatBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _teamId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterMembers);
    _loadTeamMembers();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _teamMembers;
      } else {
        _filteredMembers = _teamMembers.where((member) {
          final name = (member['display_name'] ?? member['name'] ?? '').toString().toLowerCase();
          final email = (member['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadTeamMembers() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || authState.user.teamId == null) {
      debugPrint('NewChatBottomSheet: User not authenticated or no team ID');
      setState(() {
        _isLoading = false;
        _teamMembers = [];
        _filteredMembers = [];
      });
      return;
    }

    _currentUserId = authState.user.id;
    _teamId = authState.user.teamId;
    debugPrint('NewChatBottomSheet: Loading members for team $_teamId, current user: $_currentUserId');

    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.get('/api/teams/$_teamId/workers');

      debugPrint('NewChatBottomSheet: Response status: ${response.statusCode}');
      debugPrint('NewChatBottomSheet: Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Response is a direct array of users from user-service
        final List<dynamic> data = response.data is List ? response.data : [];
        debugPrint('NewChatBottomSheet: Found ${data.length} members before filtering');

        // Filter out the current user - use user_id field from API
        final members = data
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .where((m) {
              final odId = m['id']?.toString();
              final odUserId = m['user_id']?.toString();
              debugPrint('NewChatBottomSheet: Member id=$odId, user_id=$odUserId, currentUserId=$_currentUserId');
              return odId != _currentUserId && odUserId != _currentUserId;
            })
            .toList();

        debugPrint('NewChatBottomSheet: ${members.length} members after filtering');

        setState(() {
          _teamMembers = members;
          _filteredMembers = members;
          _isLoading = false;
        });
      } else {
        debugPrint('NewChatBottomSheet: Non-200 response: ${response.statusCode}');
        setState(() {
          _isLoading = false;
          _teamMembers = [];
          _filteredMembers = [];
        });
      }
    } catch (e) {
      debugPrint('NewChatBottomSheet: Error loading team members: $e');
      setState(() {
        _isLoading = false;
        _teamMembers = [];
        _filteredMembers = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'New Chat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search team members...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(50),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.groups, color: AppColors.primary),
            ),
            title: const Text('Team Chat'),
            subtitle: const Text('Message your entire team'),
            onTap: () {
              // Store the GoRouter and auth state before popping the bottom sheet
              final router = GoRouter.of(context);
              final authState = context.read<AuthBloc>().state;
              Navigator.pop(context);
              if (authState is AuthAuthenticated && authState.user.teamId != null) {
                final teamName = authState.user.teamName ?? 'Team Chat';
                debugPrint('Navigating to team chat: /chat/team/${authState.user.teamId}');
                router.push('/chat/team/${authState.user.teamId}?name=${Uri.encodeComponent(teamName)}');
              }
            },
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Team Members',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No team members found'
                              : 'No members match "${_searchController.text}"',
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          final name = member['display_name'] ?? member['name'] ?? 'Unknown';
                          final email = member['email'] ?? '';
                          final avatarUrl = member['avatar_url'];
                          final memberId = member['id'] ?? member['user_id'] ?? '';
                          final isOnline = member['is_online'] == true;

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(name[0].toUpperCase())
                                      : null,
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(name),
                            subtitle: Text(email),
                            onTap: () async {
                              // Store the GoRouter before popping the bottom sheet
                              final router = GoRouter.of(context);
                              Navigator.pop(context);
                              // Create or get the direct conversation and navigate
                              try {
                                final apiClient = await ApiClient.getInstance();
                                final response = await apiClient.post(
                                  '/api/chat/conversations/direct',
                                  data: {'other_user_id': memberId},
                                );
                                debugPrint('Create direct conversation response: ${response.statusCode} - ${response.data}');
                                if (response.statusCode == 200 || response.statusCode == 201) {
                                  final conversationId = response.data['id'];
                                  if (conversationId != null) {
                                    debugPrint('Navigating to chat: /chat/$conversationId');
                                    router.push('/chat/$conversationId');
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error creating direct conversation: $e');
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMembers);
    _searchController.dispose();
    super.dispose();
  }
}
