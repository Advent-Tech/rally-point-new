part of 'notification_bloc.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationLoadList extends NotificationEvent {
  const NotificationLoadList();
}

class NotificationLoadMore extends NotificationEvent {
  const NotificationLoadMore();
}

class NotificationMarkRead extends NotificationEvent {
  final String notificationId;
  const NotificationMarkRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class NotificationMarkAllRead extends NotificationEvent {
  const NotificationMarkAllRead();
}

class NotificationDelete extends NotificationEvent {
  final String notificationId;
  const NotificationDelete(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class NotificationReceived extends NotificationEvent {
  final Map<String, dynamic> data;
  const NotificationReceived(this.data);

  @override
  List<Object?> get props => [data];
}

class NotificationLoadPreferences extends NotificationEvent {
  const NotificationLoadPreferences();
}

class NotificationUpdatePreference extends NotificationEvent {
  final String notificationType;
  final bool? inAppEnabled;
  final bool? pushEnabled;

  const NotificationUpdatePreference({
    required this.notificationType,
    this.inAppEnabled,
    this.pushEnabled,
  });

  @override
  List<Object?> get props => [notificationType, inAppEnabled, pushEnabled];
}
