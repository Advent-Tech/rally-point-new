/// Persistent notification model (from backend)
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String priority;
  final bool isRead;
  final DateTime? readAt;
  final String? groupKey;
  final String? actorId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.priority = 'normal',
    this.isRead = false,
    this.readAt,
    this.groupKey,
    this.actorId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] : {},
      priority: json['priority']?.toString() ?? 'normal',
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      groupKey: json['group_key']?.toString(),
      actorId: json['actor_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead, DateTime? readAt}) {
    return NotificationModel(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: data,
      priority: priority,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      groupKey: groupKey,
      actorId: actorId,
      createdAt: createdAt,
    );
  }
}

/// Notification preference model
class NotificationPreference {
  final String notificationType;
  final bool inAppEnabled;
  final bool pushEnabled;

  NotificationPreference({
    required this.notificationType,
    this.inAppEnabled = true,
    this.pushEnabled = true,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      notificationType: json['notification_type']?.toString() ?? '',
      inAppEnabled: json['in_app_enabled'] ?? true,
      pushEnabled: json['push_enabled'] ?? true,
    );
  }

  NotificationPreference copyWith({bool? inAppEnabled, bool? pushEnabled}) {
    return NotificationPreference(
      notificationType: notificationType,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
