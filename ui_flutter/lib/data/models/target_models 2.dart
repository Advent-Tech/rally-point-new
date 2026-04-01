class TargetDefinition {
  final String id;
  final String name;
  final String? description;
  final String targetType;
  final String targetUnit;
  final double targetValue;
  final String periodType;
  final bool? isActive;

  const TargetDefinition({
    required this.id,
    required this.name,
    this.description,
    required this.targetType,
    required this.targetUnit,
    required this.targetValue,
    required this.periodType,
    this.isActive,
  });

  factory TargetDefinition.fromJson(Map<String, dynamic> json) {
    return TargetDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      targetType: json['target_type']?.toString() ?? '',
      targetUnit: json['target_unit']?.toString() ?? '',
      targetValue: (json['target_value'] ?? 0).toDouble(),
      periodType: json['period_type']?.toString() ?? '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : null,
    );
  }

  Map<String, dynamic> toCreateUpdateJson() {
    return {
      'name': name,
      'description': description ?? '',
      'target_type': targetType,
      'target_unit': targetUnit,
      'target_value': targetValue,
      'period_type': periodType,
    };
  }
}

class TargetAssignment {
  final String id;
  final String assignedToType;
  final String assignedToId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? status;
  final TargetDefinition? target;

  const TargetAssignment({
    required this.id,
    required this.assignedToType,
    required this.assignedToId,
    this.periodStart,
    this.periodEnd,
    this.status,
    this.target,
  });

  factory TargetAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return TargetAssignment(
      id: json['id']?.toString() ?? '',
      assignedToType: json['assigned_to_type']?.toString() ?? '',
      assignedToId: json['assigned_to_id']?.toString() ?? '',
      periodStart: parseDate(json['period_start']),
      periodEnd: parseDate(json['period_end']),
      status: json['status']?.toString(),
      target: json['target'] is Map<String, dynamic>
          ? TargetDefinition.fromJson(json['target'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TargetProgress {
  final double currentValue;
  final DateTime? lastUpdated;

  const TargetProgress({
    required this.currentValue,
    this.lastUpdated,
  });

  factory TargetProgress.fromJson(Map<String, dynamic> json) {
    final lastUpdatedRaw = json['last_updated'];
    DateTime? lastUpdated;
    if (lastUpdatedRaw is String && lastUpdatedRaw.isNotEmpty) {
      lastUpdated = DateTime.tryParse(lastUpdatedRaw);
    }

    return TargetProgress(
      currentValue: (json['current_value'] ?? 0).toDouble(),
      lastUpdated: lastUpdated,
    );
  }
}

class AssignedTargetWithProgress {
  final TargetAssignment assignment;
  final TargetProgress progress;
  final double? percentage;
  final bool? isCompleted;

  const AssignedTargetWithProgress({
    required this.assignment,
    required this.progress,
    this.percentage,
    this.isCompleted,
  });

  factory AssignedTargetWithProgress.fromJson(Map<String, dynamic> json) {
    return AssignedTargetWithProgress(
      assignment: TargetAssignment.fromJson(
        (json['assignment'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      progress: TargetProgress.fromJson(
        (json['progress'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      percentage: json['percentage'] == null
          ? null
          : (json['percentage'] ?? 0).toDouble(),
      isCompleted: json['is_completed'] is bool
          ? json['is_completed'] as bool
          : null,
    );
  }
}

class TeamMemberLite {
  final String id;
  final String name;
  final String? email;

  const TeamMemberLite({
    required this.id,
    required this.name,
    this.email,
  });

  factory TeamMemberLite.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name']?.toString();
    final name = (displayName?.isNotEmpty == true)
        ? displayName!
        : (json['name']?.toString() ?? json['email']?.toString() ?? 'Worker');

    return TeamMemberLite(
      id: json['id']?.toString() ?? '',
      name: name,
      email: json['email']?.toString(),
    );
  }
}
