import 'package:flutter/material.dart';
import '../../services/realtime_provider.dart';

/// A badge that shows unread notification count
class RealtimeNotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const RealtimeNotificationBadge({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<RealtimeNotificationBadge> createState() => _RealtimeNotificationBadgeState();
}

class _RealtimeNotificationBadgeState extends State<RealtimeNotificationBadge> {
  RealtimeProvider? _provider;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    _provider = await RealtimeProvider.getInstance();
    _provider!.addListener(_updateCount);
    _updateCount();
  }

  void _updateCount() {
    if (mounted) {
      setState(() {
        _unreadCount = _provider?.unreadNotificationCount ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_updateCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: _unreadCount > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: _unreadCount > 9 ? BorderRadius.circular(8) : null,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A list showing recent notifications
class RealtimeNotificationList extends StatefulWidget {
  final int maxItems;
  final VoidCallback? onClear;

  const RealtimeNotificationList({
    super.key,
    this.maxItems = 20,
    this.onClear,
  });

  @override
  State<RealtimeNotificationList> createState() => _RealtimeNotificationListState();
}

class _RealtimeNotificationListState extends State<RealtimeNotificationList> {
  RealtimeProvider? _provider;
  List<RealtimeNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    _provider = await RealtimeProvider.getInstance();
    _provider!.addListener(_updateNotifications);
    _updateNotifications();
  }

  void _updateNotifications() {
    if (mounted) {
      setState(() {
        _notifications = _provider?.notifications.take(widget.maxItems).toList() ?? [];
      });
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_updateNotifications);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (widget.onClear != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_notifications.length} notifications',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton(
                  onPressed: () {
                    _provider?.clearNotifications();
                    widget.onClear?.call();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () {
                  _provider?.markNotificationRead(notification.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final RealtimeNotification notification;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _buildIcon(context),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(notification.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.walkieMessage:
        icon = Icons.mic;
        color = Colors.green;
        break;
      case NotificationType.deliveryUpdate:
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case NotificationType.alert:
        icon = notification.priority == NotificationPriority.high
            ? Icons.warning
            : Icons.info;
        color = notification.priority == NotificationPriority.high
            ? Colors.red
            : Colors.orange;
        break;
      case NotificationType.teamStatus:
        icon = Icons.person;
        color = Colors.purple;
        break;
      case NotificationType.sessionUpdate:
        icon = Icons.timer;
        color = Colors.teal;
        break;
      case NotificationType.general:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

/// Connection status indicator
class RealtimeConnectionStatus extends StatefulWidget {
  final bool showLabel;

  const RealtimeConnectionStatus({
    super.key,
    this.showLabel = true,
  });

  @override
  State<RealtimeConnectionStatus> createState() => _RealtimeConnectionStatusState();
}

class _RealtimeConnectionStatusState extends State<RealtimeConnectionStatus> {
  RealtimeProvider? _provider;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    _provider = await RealtimeProvider.getInstance();
    _provider!.addListener(_updateStatus);
    _updateStatus();
  }

  void _updateStatus() {
    if (mounted) {
      setState(() {
        _isConnected = _provider?.isConnected ?? false;
      });
    }
  }

  @override
  void dispose() {
    _provider?.removeListener(_updateStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(width: 6),
          Text(
            _isConnected ? 'Connected' : 'Offline',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ],
    );
  }
}
