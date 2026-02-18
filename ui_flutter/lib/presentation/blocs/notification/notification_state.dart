part of 'notification_bloc.dart';

class NotificationState extends Equatable {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final List<NotificationPreference> preferences;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.preferences = const [],
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    bool? hasMore,
    String? error,
    List<NotificationPreference>? preferences,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  List<Object?> get props => [notifications, unreadCount, isLoading, hasMore, error, preferences];
}
