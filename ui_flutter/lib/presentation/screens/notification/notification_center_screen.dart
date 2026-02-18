import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../widgets/notification/notification_tile.dart';
import '../../../data/models/notification_model.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late final NotificationBloc _bloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bloc = NotificationBloc()..add(const NotificationLoadList());

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _bloc.add(const NotificationLoadMore());
      }
    });
  }

  @override
  void dispose() {
    _bloc.close();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/notifications/settings'),
            ),
            BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                if (state.unreadCount == 0) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () => _bloc.add(const NotificationMarkAllRead()),
                  child: const Text('Mark All Read'),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            if (state.isLoading && state.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.notifications.isEmpty) {
              return _buildEmptyState(context);
            }

            final grouped = _groupNotifications(state.notifications);

            return RefreshIndicator(
              onRefresh: () async {
                _bloc.add(const NotificationLoadList());
                // Wait for the state to update
                await _bloc.stream.firstWhere((s) => !s.isLoading);
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: grouped.length + (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= grouped.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = grouped[index];
                  if (item is String) {
                    return _buildSectionHeader(context, item);
                  }
                  final notification = item as NotificationModel;
                  return NotificationTile(
                    notification: notification,
                    onTap: () {
                      if (!notification.isRead) {
                        _bloc.add(NotificationMarkRead(notification.id));
                      }
                      _navigateToContext(notification);
                    },
                    onDismiss: () {
                      _bloc.add(NotificationDelete(notification.id));
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see updates about your territory,\ndeliveries, and team here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Group notifications by time period: Today, Yesterday, This Week, Earlier
  List<dynamic> _groupNotifications(List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final grouped = <dynamic>[];
    String? lastSection;

    for (final n in notifications) {
      final date = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      String section;

      if (date == today || date.isAfter(today)) {
        section = 'Today';
      } else if (date == yesterday || (date.isAfter(yesterday) && date.isBefore(today))) {
        section = 'Yesterday';
      } else if (date.isAfter(weekAgo)) {
        section = 'This Week';
      } else {
        section = 'Earlier';
      }

      if (section != lastSection) {
        grouped.add(section);
        lastSection = section;
      }
      grouped.add(n);
    }

    return grouped;
  }

  void _navigateToContext(NotificationModel notification) {
    switch (notification.type) {
      case 'geofence':
      case 'session':
        context.push('/territory');
        break;
      case 'prayer':
        final id = notification.data['prayer_request_id']?.toString();
        if (id != null) {
          context.push('/prayer-requests/$id');
        } else {
          context.push('/prayer-requests');
        }
        break;
      case 'delivery':
        context.push('/delivery');
        break;
      case 'survey':
        context.push('/survey');
        break;
      case 'team':
        // Team leaders go to team members, workers stay on home
        context.push('/home');
        break;
      case 'walkie':
        context.push('/walkie');
        break;
      case 'chat':
        final conversationId = notification.data['conversation_id']?.toString();
        if (conversationId != null) {
          context.push('/chat/$conversationId');
        } else {
          context.push('/chat');
        }
        break;
      default:
        break;
    }
  }
}
