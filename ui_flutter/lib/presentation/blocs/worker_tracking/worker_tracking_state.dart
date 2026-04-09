part of 'worker_tracking_bloc.dart';

abstract class WorkerTrackingState extends Equatable {
  const WorkerTrackingState();

  @override
  List<Object?> get props => [];
}

class WorkerTrackingInitial extends WorkerTrackingState {}

class WorkerTrackingLoading extends WorkerTrackingState {}

class WorkerTrackingWorkersLoaded extends WorkerTrackingState {
  final List<TrackedWorker> workers;
  final String teamId;

  const WorkerTrackingWorkersLoaded({
    required this.workers,
    required this.teamId,
  });

  @override
  List<Object?> get props => [workers, teamId];
}

class WorkerTrackingTrailLoading extends WorkerTrackingState {}

class WorkerTrackingTrailLoaded extends WorkerTrackingState {
  final List<TrailPoint> trailPoints;
  final WorkerTrailStats stats;
  final String workerId;
  final String workerName;
  final DateTime selectedDate;

  const WorkerTrackingTrailLoaded({
    required this.trailPoints,
    required this.stats,
    required this.workerId,
    required this.workerName,
    required this.selectedDate,
  });

  @override
  List<Object?> get props => [
    trailPoints,
    stats,
    workerId,
    workerName,
    selectedDate,
  ];
}

class WorkerTrackingError extends WorkerTrackingState {
  final String message;

  const WorkerTrackingError({required this.message});

  @override
  List<Object?> get props => [message];
}

// --- Data Models ---

class TrackedWorker {
  final String id;
  final String name;
  final String status;
  final String territoryName;
  final double latitude;
  final double longitude;
  final DateTime lastUpdate;
  final double? todayDistanceKm;
  final double? todayHours;

  const TrackedWorker({
    required this.id,
    required this.name,
    required this.status,
    required this.territoryName,
    required this.latitude,
    required this.longitude,
    required this.lastUpdate,
    this.todayDistanceKm,
    this.todayHours,
  });

  factory TrackedWorker.fromJson(
    Map<String, dynamic> json, {
    double? distanceKm,
    double? hours,
  }) {
    return TrackedWorker(
      id: json['worker_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['worker_name'] ?? json['name'] ?? 'Unknown',
      status: json['status'] ?? 'working',
      // API returns entity_name, also try city + state for full territory info
      territoryName:
          json['entity_name'] ??
          (json['city'] != null && json['state'] != null
              ? '${json['city']}, ${json['state']}'
              : json['territory_name'] ?? 'Unknown Territory'),
      latitude: (json['latitude'] ?? json['entry_lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['entry_lng'] ?? 0.0).toDouble(),
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'].toString()) ?? DateTime.now()
          : DateTime.now(),
      todayDistanceKm: distanceKm,
      todayHours: hours,
    );
  }
}

class TrailPoint {
  final double latitude;
  final double longitude;
  final DateTime trackedAt;
  final double? speed;
  final double? accuracy;
  final String? sessionId;

  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.trackedAt,
    this.speed,
    this.accuracy,
    this.sessionId,
  });

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      trackedAt: json['tracked_at'] != null
          ? DateTime.tryParse(json['tracked_at'].toString()) ?? DateTime.now()
          : json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['timestamp'] is int
                      ? json['timestamp']
                      : (json['timestamp'] as num).toInt()) *
                  1000,
            )
          : DateTime.now(),
      speed: (json['speed'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      sessionId: json['session_id']?.toString(),
    );
  }
}

class WorkerTrailStats {
  final double totalDistanceKm;
  final double totalHours;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final int locationCount;
  final int sessionCount;

  const WorkerTrailStats({
    this.totalDistanceKm = 0,
    this.totalHours = 0,
    this.averageSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.locationCount = 0,
    this.sessionCount = 0,
  });

  factory WorkerTrailStats.fromJson(Map<String, dynamic> json) {
    return WorkerTrailStats(
      totalDistanceKm: (json['total_distance_km'] ?? 0).toDouble(),
      totalHours: (json['total_hours'] ?? 0).toDouble(),
      averageSpeedKmh: (json['average_speed_kmh'] ?? 0).toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] ?? 0).toDouble(),
      locationCount: (json['location_count'] ?? 0).toInt(),
      sessionCount: (json['session_count'] ?? 0).toInt(),
    );
  }
}
