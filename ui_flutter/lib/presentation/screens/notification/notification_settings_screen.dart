import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/navigation/app_back_button.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../../data/models/notification_model.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final NotificationBloc _bloc;

  // All notification types with display info
  static const _notificationTypes = [
    _NotifTypeInfo('Territory', [
      _NotifItem('geofence', 'Geofence Events', 'Entry/exit territory alerts'),
      _NotifItem(
        'session',
        'Work Sessions',
        'Check-in/check-out notifications',
      ),
    ]),
    _NotifTypeInfo('Ministry', [
      _NotifItem(
        'prayer',
        'Prayer Requests',
        'New requests and status changes',
      ),
      _NotifItem('survey', 'Surveys', 'Survey assignments'),
    ]),
    _NotifTypeInfo('Deliveries', [
      _NotifItem('delivery', 'Deliveries', 'Assignment and status updates'),
    ]),
    _NotifTypeInfo('Team', [
      _NotifItem('team', 'Team Updates', 'Join requests and approvals'),
    ]),
    _NotifTypeInfo('Messaging', [
      _NotifItem('walkie', 'Walkie Talkie', 'Voice message notifications'),
      _NotifItem('chat', 'Chat', 'New chat messages'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _bloc = NotificationBloc()..add(const NotificationLoadPreferences());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.leading(context),
          title: const Text('Notification Settings'),
        ),
        body: BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) {
            return ListView(
              children: [
                for (final group in _notificationTypes) ...[
                  _buildGroupHeader(context, group.title),
                  for (final item in group.items)
                    _buildPreferenceRow(context, state, item),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPreferenceRow(
    BuildContext context,
    NotificationState state,
    _NotifItem item,
  ) {
    final pref = state.preferences.firstWhere(
      (p) => p.notificationType == item.type,
      orElse: () => NotificationPreference(
        notificationType: item.type,
        inAppEnabled: true,
        pushEnabled: true,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: Theme.of(context).textTheme.bodyLarge),
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, size: 16),
                        const SizedBox(width: 4),
                        const Text('In-app'),
                        const Spacer(),
                        Switch(
                          value: pref.inAppEnabled,
                          onChanged: (value) {
                            _bloc.add(
                              NotificationUpdatePreference(
                                notificationType: item.type,
                                inAppEnabled: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, size: 16),
                        const SizedBox(width: 4),
                        const Text('Push'),
                        const Spacer(),
                        Switch(
                          value: pref.pushEnabled,
                          onChanged: (value) {
                            _bloc.add(
                              NotificationUpdatePreference(
                                notificationType: item.type,
                                pushEnabled: value,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifTypeInfo {
  final String title;
  final List<_NotifItem> items;
  const _NotifTypeInfo(this.title, this.items);
}

class _NotifItem {
  final String type;
  final String label;
  final String description;
  const _NotifItem(this.type, this.label, this.description);
}
