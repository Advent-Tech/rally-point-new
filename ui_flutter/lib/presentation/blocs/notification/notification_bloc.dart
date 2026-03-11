import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/notification_model.dart';
import '../../../services/notification_api_service.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationApiService? _apiService;
  static const _pageSize = 20;

  NotificationBloc() : super(const NotificationState()) {
    on<NotificationLoadList>(_onLoadList);
    on<NotificationLoadMore>(_onLoadMore);
    on<NotificationMarkRead>(_onMarkRead);
    on<NotificationMarkAllRead>(_onMarkAllRead);
    on<NotificationDelete>(_onDelete);
    on<NotificationReceived>(_onReceived);
    on<NotificationLoadPreferences>(_onLoadPreferences);
    on<NotificationUpdatePreference>(_onUpdatePreference);
  }

  Future<void> _ensureService() async {
    _apiService ??= await NotificationApiService.getInstance();
  }

  Future<void> _onLoadList(NotificationLoadList event, Emitter<NotificationState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _ensureService();
      final response = await _apiService!.getNotifications(limit: _pageSize, offset: 0);
      final list = (response['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n))
          .toList();
      final unread = await _apiService!.getUnreadCount();

      emit(state.copyWith(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
        hasMore: list.length >= _pageSize,
      ));
    } catch (e) {
      debugPrint('NotificationBloc: load error: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to load notifications'));
    }
  }

  Future<void> _onLoadMore(NotificationLoadMore event, Emitter<NotificationState> emit) async {
    if (state.isLoading || !state.hasMore) return;
    emit(state.copyWith(isLoading: true));
    try {
      await _ensureService();
      final response = await _apiService!.getNotifications(
        limit: _pageSize,
        offset: state.notifications.length,
      );
      final list = (response['notifications'] as List)
          .map((n) => NotificationModel.fromJson(n))
          .toList();

      emit(state.copyWith(
        notifications: [...state.notifications, ...list],
        isLoading: false,
        hasMore: list.length >= _pageSize,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onMarkRead(NotificationMarkRead event, Emitter<NotificationState> emit) async {
    try {
      await _ensureService();
      await _apiService!.markAsRead(event.notificationId);
      final updated = state.notifications.map((n) {
        if (n.id == event.notificationId) return n.copyWith(isRead: true, readAt: DateTime.now());
        return n;
      }).toList();

      emit(state.copyWith(
        notifications: updated,
        unreadCount: (state.unreadCount - 1).clamp(0, 999999),
      ));
    } catch (e) {
      debugPrint('NotificationBloc: mark read error: $e');
    }
  }

  Future<void> _onMarkAllRead(NotificationMarkAllRead event, Emitter<NotificationState> emit) async {
    try {
      await _ensureService();
      await _apiService!.markAllAsRead();
      final updated = state.notifications
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList();

      emit(state.copyWith(notifications: updated, unreadCount: 0));
    } catch (e) {
      debugPrint('NotificationBloc: mark all read error: $e');
    }
  }

  Future<void> _onDelete(NotificationDelete event, Emitter<NotificationState> emit) async {
    try {
      await _ensureService();
      await _apiService!.deleteNotification(event.notificationId);
      final updated = state.notifications.where((n) => n.id != event.notificationId).toList();
      final wasUnread = state.notifications.any((n) => n.id == event.notificationId && !n.isRead);

      emit(state.copyWith(
        notifications: updated,
        unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 999999) : state.unreadCount,
      ));
    } catch (e) {
      debugPrint('NotificationBloc: delete error: $e');
    }
  }

  void _onReceived(NotificationReceived event, Emitter<NotificationState> emit) {
    final n = NotificationModel.fromJson(event.data);
    emit(state.copyWith(
      notifications: [n, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    ));
  }

  Future<void> _onLoadPreferences(NotificationLoadPreferences event, Emitter<NotificationState> emit) async {
    try {
      await _ensureService();
      final prefsJson = await _apiService!.getPreferences();
      final prefs = prefsJson
          .map((p) => NotificationPreference.fromJson(p as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(preferences: prefs));
    } catch (e) {
      debugPrint('NotificationBloc: load preferences error: $e');
    }
  }

  Future<void> _onUpdatePreference(NotificationUpdatePreference event, Emitter<NotificationState> emit) async {
    try {
      await _ensureService();
      await _apiService!.updatePreferences(
        notificationType: event.notificationType,
        inAppEnabled: event.inAppEnabled,
        pushEnabled: event.pushEnabled,
      );
      // Reload preferences
      add(const NotificationLoadPreferences());
    } catch (e) {
      debugPrint('NotificationBloc: update preference error: $e');
    }
  }
}
