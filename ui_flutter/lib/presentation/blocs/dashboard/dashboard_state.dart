part of 'dashboard_bloc.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final TeamDashboardStats stats;
  final List<TeamActivity> recentActivity;
  final List<WorkerPerformance> workerPerformance;
  final List<TerritoryStats> territoryStats;

  const DashboardLoaded({
    required this.stats,
    this.recentActivity = const [],
    this.workerPerformance = const [],
    this.territoryStats = const [],
  });

  @override
  List<Object?> get props => [
    stats,
    recentActivity,
    workerPerformance,
    territoryStats,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Team dashboard statistics model
class TeamDashboardStats extends Equatable {
  final int totalMembers;
  final int activeWorkers;
  final int totalTerritories;
  final double completionPercentage;
  final int visitsToday;
  final int visitsThisWeek;
  final int totalDeliveries;
  final int totalDonations;

  const TeamDashboardStats({
    this.totalMembers = 0,
    this.activeWorkers = 0,
    this.totalTerritories = 0,
    this.completionPercentage = 0.0,
    this.visitsToday = 0,
    this.visitsThisWeek = 0,
    this.totalDeliveries = 0,
    this.totalDonations = 0,
  });

  factory TeamDashboardStats.fromJson(Map<String, dynamic> json) {
    return TeamDashboardStats(
      totalMembers: json['total_members'] ?? json['totalMembers'] ?? 0,
      activeWorkers: json['active_workers'] ?? json['activeWorkers'] ?? 0,
      totalTerritories:
          json['total_territories'] ?? json['totalTerritories'] ?? 0,
      completionPercentage:
          (json['completion_percentage'] ?? json['completionPercentage'] ?? 0.0)
              .toDouble(),
      visitsToday: json['visits_today'] ?? json['visitsToday'] ?? 0,
      visitsThisWeek: json['visits_this_week'] ?? json['visitsThisWeek'] ?? 0,
      totalDeliveries: json['total_deliveries'] ?? json['totalDeliveries'] ?? 0,
      totalDonations: json['total_donations'] ?? json['totalDonations'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    totalMembers,
    activeWorkers,
    totalTerritories,
    completionPercentage,
    visitsToday,
    visitsThisWeek,
    totalDeliveries,
    totalDonations,
  ];
}

/// Team activity item model
class TeamActivity extends Equatable {
  final String id;
  final String type; // 'check_in', 'check_out', 'visit', 'assignment'
  final String workerId;
  final String workerName;
  final String? workerAvatar;
  final String description;
  final String? territoryName;
  final String? address;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const TeamActivity({
    required this.id,
    required this.type,
    required this.workerId,
    required this.workerName,
    this.workerAvatar,
    required this.description,
    this.territoryName,
    this.address,
    required this.timestamp,
    this.metadata,
  });

  factory TeamActivity.fromJson(Map<String, dynamic> json) {
    return TeamActivity(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'activity',
      workerId:
          json['worker_id']?.toString() ?? json['workerId']?.toString() ?? '',
      workerName:
          json['worker_name']?.toString() ??
          json['workerName']?.toString() ??
          'Unknown',
      workerAvatar:
          json['worker_avatar']?.toString() ?? json['workerAvatar']?.toString(),
      description: json['description']?.toString() ?? '',
      territoryName:
          json['territory_name']?.toString() ??
          json['territoryName']?.toString(),
      address: json['address']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  String get activityIcon {
    switch (type) {
      case 'check_in':
        return '📍';
      case 'check_out':
        return '🏁';
      case 'visit':
        return '🏠';
      case 'assignment':
        return '📋';
      case 'delivery':
        return '📦';
      case 'donation':
        return '💚';
      case 'book_sale':
        return '📚';
      default:
        return '📌';
    }
  }

  @override
  List<Object?> get props => [
    id,
    type,
    workerId,
    workerName,
    description,
    timestamp,
  ];
}

/// Worker performance statistics
class WorkerPerformance extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final int donationsCount;
  final double donationsTotal;
  final int prayersCount;
  final int territoriesAssigned;
  final double territoryCoverage;
  final bool isActive;
  final DateTime? lastActive;

  const WorkerPerformance({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.donationsCount = 0,
    this.donationsTotal = 0.0,
    this.prayersCount = 0,
    this.territoriesAssigned = 0,
    this.territoryCoverage = 0.0,
    this.isActive = false,
    this.lastActive,
  });

  factory WorkerPerformance.fromJson(Map<String, dynamic> json) {
    return WorkerPerformance(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['full_name']?.toString() ??
          '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      avatarUrl:
          json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
      donationsCount: json['donations_count'] ?? json['donationsCount'] ?? 0,
      donationsTotal: (json['donations_total'] ?? json['donationsTotal'] ?? 0.0)
          .toDouble(),
      prayersCount: json['prayers_count'] ?? json['prayersCount'] ?? 0,
      territoriesAssigned:
          json['territories_assigned'] ?? json['territoriesAssigned'] ?? 0,
      territoryCoverage:
          (json['territory_coverage'] ?? json['territoryCoverage'] ?? 0.0)
              .toDouble(),
      isActive: json['is_active'] ?? json['isActive'] ?? false,
      lastActive: json['last_active'] != null
          ? DateTime.tryParse(json['last_active'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    donationsCount,
    donationsTotal,
    prayersCount,
    territoryCoverage,
    isActive,
  ];
}

/// Territory statistics with coverage info
class TerritoryStats extends Equatable {
  final String id;
  final String name;
  final String? assigneeName;
  final String? assigneeId;
  final int housingUnits;
  final int visitedCount;
  final int pendingCount;
  final double completionRate;
  final DateTime? lastVisited;
  final String? status;

  const TerritoryStats({
    required this.id,
    required this.name,
    this.assigneeName,
    this.assigneeId,
    this.housingUnits = 0,
    this.visitedCount = 0,
    this.pendingCount = 0,
    this.completionRate = 0.0,
    this.lastVisited,
    this.status,
  });

  factory TerritoryStats.fromJson(Map<String, dynamic> json) {
    final housingUnits = json['housing_units'] ?? json['housingUnits'] ?? 0;
    final visitedCount =
        json['visited_count'] ??
        json['visitedCount'] ??
        json['visits_count'] ??
        0;
    final completionFromApi =
        json['completeness_percentage'] ??
        json['completion_rate'] ??
        json['completionRate'];

    // Calculate completion rate: visited / housing_units or use API value
    double completionRate;
    if (completionFromApi != null) {
      completionRate = (completionFromApi as num).toDouble();
    } else if (housingUnits > 0) {
      completionRate = (visitedCount / housingUnits) * 100;
    } else {
      completionRate = 0.0;
    }

    return TerritoryStats(
      id:
          json['id']?.toString() ??
          json['territory_id']?.toString() ??
          json['entity_id']?.toString() ??
          '',
      name:
          json['name']?.toString() ??
          json['entity_name']?.toString() ??
          json['territory_name']?.toString() ??
          'Unknown',
      assigneeName:
          json['assignee_name']?.toString() ?? json['worker_name']?.toString(),
      assigneeId:
          json['assignee_id']?.toString() ?? json['worker_id']?.toString(),
      housingUnits: housingUnits,
      visitedCount: visitedCount,
      pendingCount: housingUnits > visitedCount
          ? housingUnits - visitedCount
          : 0,
      completionRate: completionRate,
      lastVisited: json['last_visited'] != null
          ? DateTime.tryParse(json['last_visited'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }

  /// Coverage percentage (0-100)
  double get coveragePercentage => completionRate.clamp(0, 100);

  /// Remaining households to visit
  int get remaining => pendingCount;

  @override
  List<Object?> get props => [
    id,
    name,
    housingUnits,
    visitedCount,
    completionRate,
  ];
}
