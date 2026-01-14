import 'package:json_annotation/json_annotation.dart';

part 'activity_stats_model.g.dart';

/// Combined delivery statistics for a team
@JsonSerializable()
class DeliveryStats {
  @JsonKey(name: 'total_deliveries')
  final int totalDeliveries;
  @JsonKey(name: 'pending_deliveries')
  final int pendingDeliveries;
  @JsonKey(name: 'in_progress_deliveries')
  final int inProgressDeliveries;
  @JsonKey(name: 'completed_deliveries')
  final int completedDeliveries;
  @JsonKey(name: 'failed_deliveries')
  final int failedDeliveries;
  @JsonKey(name: 'completion_rate')
  final double completionRate;
  @JsonKey(name: 'average_delivery_time')
  final double averageDeliveryTime;
  @JsonKey(name: 'total_routes')
  final int totalRoutes;
  @JsonKey(name: 'active_routes')
  final int activeRoutes;

  const DeliveryStats({
    this.totalDeliveries = 0,
    this.pendingDeliveries = 0,
    this.inProgressDeliveries = 0,
    this.completedDeliveries = 0,
    this.failedDeliveries = 0,
    this.completionRate = 0,
    this.averageDeliveryTime = 0,
    this.totalRoutes = 0,
    this.activeRoutes = 0,
  });

  factory DeliveryStats.fromJson(Map<String, dynamic> json) =>
      _$DeliveryStatsFromJson(json);
  Map<String, dynamic> toJson() => _$DeliveryStatsToJson(this);
}

/// Worker performance statistics
@JsonSerializable()
class WorkerPerformanceStats {
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'total_deliveries')
  final int totalDeliveries;
  @JsonKey(name: 'completed_deliveries')
  final int completedDeliveries;
  @JsonKey(name: 'failed_deliveries')
  final int failedDeliveries;
  @JsonKey(name: 'completion_rate')
  final double completionRate;
  @JsonKey(name: 'average_delivery_time')
  final double averageDeliveryTime;
  @JsonKey(name: 'total_distance')
  final double totalDistance;
  @JsonKey(name: 'total_routes')
  final int totalRoutes;

  const WorkerPerformanceStats({
    required this.workerId,
    this.workerName,
    this.totalDeliveries = 0,
    this.completedDeliveries = 0,
    this.failedDeliveries = 0,
    this.completionRate = 0,
    this.averageDeliveryTime = 0,
    this.totalDistance = 0,
    this.totalRoutes = 0,
  });

  factory WorkerPerformanceStats.fromJson(Map<String, dynamic> json) =>
      _$WorkerPerformanceStatsFromJson(json);
  Map<String, dynamic> toJson() => _$WorkerPerformanceStatsToJson(this);
}

/// Active worker location for map
@JsonSerializable()
class ActiveWorkerLocation {
  @JsonKey(name: 'worker_id')
  final String workerId;
  @JsonKey(name: 'worker_name')
  final String? workerName;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'team_name')
  final String? teamName;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'territory_id')
  final String? territoryId;
  @JsonKey(name: 'territory_name')
  final String? territoryName;
  @JsonKey(name: 'session_start')
  final DateTime? sessionStart;
  @JsonKey(name: 'last_update')
  final DateTime? lastUpdate;

  const ActiveWorkerLocation({
    required this.workerId,
    this.workerName,
    this.teamId,
    this.teamName,
    this.latitude,
    this.longitude,
    this.territoryId,
    this.territoryName,
    this.sessionStart,
    this.lastUpdate,
  });

  factory ActiveWorkerLocation.fromJson(Map<String, dynamic> json) =>
      _$ActiveWorkerLocationFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveWorkerLocationToJson(this);
}

/// Church location for map markers
@JsonSerializable()
class ChurchLocation {
  @JsonKey(name: 'entity_id')
  final String entityId;
  @JsonKey(name: 'entity_name')
  final String entityName;
  @JsonKey(name: 'union_name')
  final String? unionName;
  final String? conference;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? state;
  @JsonKey(name: 'territory_count')
  final int? territoryCount;
  @JsonKey(name: 'total_population')
  final int? totalPopulation;
  @JsonKey(name: 'total_housing')
  final int? totalHousing;

  const ChurchLocation({
    required this.entityId,
    required this.entityName,
    this.unionName,
    this.conference,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    this.territoryCount,
    this.totalPopulation,
    this.totalHousing,
  });

  factory ChurchLocation.fromJson(Map<String, dynamic> json) =>
      _$ChurchLocationFromJson(json);
  Map<String, dynamic> toJson() => _$ChurchLocationToJson(this);
}

/// Prayer request map marker
@JsonSerializable()
class PrayerMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'requester_name')
  final String requesterName;
  @JsonKey(name: 'prayer_subject')
  final String prayerSubject;
  @JsonKey(name: 'prayer_category')
  final String prayerCategory;
  @JsonKey(name: 'request_type')
  final String requestType;
  final String status;
  final String urgency;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const PrayerMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.requesterName,
    required this.prayerSubject,
    required this.prayerCategory,
    required this.requestType,
    required this.status,
    required this.urgency,
    this.createdAt,
  });

  factory PrayerMapMarker.fromJson(Map<String, dynamic> json) =>
      _$PrayerMapMarkerFromJson(json);
  Map<String, dynamic> toJson() => _$PrayerMapMarkerToJson(this);
}

/// Union statistics for overview
@JsonSerializable()
class UnionStatsModel {
  @JsonKey(name: 'union_name')
  final String unionName;
  @JsonKey(name: 'territory_count')
  final int territoryCount;
  @JsonKey(name: 'church_count')
  final int churchCount;
  @JsonKey(name: 'conference_count')
  final int conferenceCount;
  @JsonKey(name: 'total_population')
  final int totalPopulation;
  @JsonKey(name: 'total_housing')
  final int totalHousing;

  const UnionStatsModel({
    required this.unionName,
    this.territoryCount = 0,
    this.churchCount = 0,
    this.conferenceCount = 0,
    this.totalPopulation = 0,
    this.totalHousing = 0,
  });

  factory UnionStatsModel.fromJson(Map<String, dynamic> json) =>
      _$UnionStatsModelFromJson(json);
  Map<String, dynamic> toJson() => _$UnionStatsModelToJson(this);
}
