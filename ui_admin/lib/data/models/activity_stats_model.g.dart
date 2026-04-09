// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_stats_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryStats _$DeliveryStatsFromJson(Map<String, dynamic> json) =>
    DeliveryStats(
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      pendingDeliveries: (json['pending_deliveries'] as num?)?.toInt() ?? 0,
      inProgressDeliveries: (json['in_progress_deliveries'] as num?)?.toInt() ?? 0,
      completedDeliveries: (json['completed_deliveries'] as num?)?.toInt() ?? 0,
      failedDeliveries: (json['failed_deliveries'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
      averageDeliveryTime: (json['average_delivery_time'] as num?)?.toDouble() ?? 0,
      totalRoutes: (json['total_routes'] as num?)?.toInt() ?? 0,
      activeRoutes: (json['active_routes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$DeliveryStatsToJson(DeliveryStats instance) =>
    <String, dynamic>{
      'total_deliveries': instance.totalDeliveries,
      'pending_deliveries': instance.pendingDeliveries,
      'in_progress_deliveries': instance.inProgressDeliveries,
      'completed_deliveries': instance.completedDeliveries,
      'failed_deliveries': instance.failedDeliveries,
      'completion_rate': instance.completionRate,
      'average_delivery_time': instance.averageDeliveryTime,
      'total_routes': instance.totalRoutes,
      'active_routes': instance.activeRoutes,
    };

WorkerPerformanceStats _$WorkerPerformanceStatsFromJson(Map<String, dynamic> json) =>
    WorkerPerformanceStats(
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String?,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 0,
      completedDeliveries: (json['completed_deliveries'] as num?)?.toInt() ?? 0,
      failedDeliveries: (json['failed_deliveries'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
      averageDeliveryTime: (json['average_delivery_time'] as num?)?.toDouble() ?? 0,
      totalDistance: (json['total_distance'] as num?)?.toDouble() ?? 0,
      totalRoutes: (json['total_routes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WorkerPerformanceStatsToJson(WorkerPerformanceStats instance) =>
    <String, dynamic>{
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'total_deliveries': instance.totalDeliveries,
      'completed_deliveries': instance.completedDeliveries,
      'failed_deliveries': instance.failedDeliveries,
      'completion_rate': instance.completionRate,
      'average_delivery_time': instance.averageDeliveryTime,
      'total_distance': instance.totalDistance,
      'total_routes': instance.totalRoutes,
    };

ActiveWorkerLocation _$ActiveWorkerLocationFromJson(Map<String, dynamic> json) =>
    ActiveWorkerLocation(
      workerId: json['worker_id'] as String,
      workerName: json['worker_name'] as String?,
      teamId: json['team_id'] as String?,
      teamName: json['team_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      territoryId: json['territory_id'] as String?,
      territoryName: json['territory_name'] as String?,
      sessionStart: json['session_start'] == null
          ? null
          : DateTime.parse(json['session_start'] as String),
      lastUpdate: json['last_update'] == null
          ? null
          : DateTime.parse(json['last_update'] as String),
    );

Map<String, dynamic> _$ActiveWorkerLocationToJson(ActiveWorkerLocation instance) =>
    <String, dynamic>{
      'worker_id': instance.workerId,
      'worker_name': instance.workerName,
      'team_id': instance.teamId,
      'team_name': instance.teamName,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'territory_id': instance.territoryId,
      'territory_name': instance.territoryName,
      'session_start': instance.sessionStart?.toIso8601String(),
      'last_update': instance.lastUpdate?.toIso8601String(),
    };

ChurchLocation _$ChurchLocationFromJson(Map<String, dynamic> json) =>
    ChurchLocation(
      entityId: json['entity_id'] as String,
      entityName: json['entity_name'] as String,
      unionName: json['union_name'] as String?,
      conference: json['conference'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      territoryCount: (json['territory_count'] as num?)?.toInt(),
      totalPopulation: (json['total_population'] as num?)?.toInt(),
      totalHousing: (json['total_housing'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ChurchLocationToJson(ChurchLocation instance) =>
    <String, dynamic>{
      'entity_id': instance.entityId,
      'entity_name': instance.entityName,
      'union_name': instance.unionName,
      'conference': instance.conference,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'city': instance.city,
      'state': instance.state,
      'territory_count': instance.territoryCount,
      'total_population': instance.totalPopulation,
      'total_housing': instance.totalHousing,
    };

PrayerMapMarker _$PrayerMapMarkerFromJson(Map<String, dynamic> json) =>
    PrayerMapMarker(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      requesterName: json['requester_name'] as String,
      prayerSubject: json['prayer_subject'] as String,
      prayerCategory: json['prayer_category'] as String,
      requestType: json['request_type'] as String,
      status: json['status'] as String,
      urgency: json['urgency'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PrayerMapMarkerToJson(PrayerMapMarker instance) =>
    <String, dynamic>{
      'id': instance.id,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'requester_name': instance.requesterName,
      'prayer_subject': instance.prayerSubject,
      'prayer_category': instance.prayerCategory,
      'request_type': instance.requestType,
      'status': instance.status,
      'urgency': instance.urgency,
      'created_at': instance.createdAt?.toIso8601String(),
    };

UnionStatsModel _$UnionStatsModelFromJson(Map<String, dynamic> json) =>
    UnionStatsModel(
      unionName: json['union_name'] as String,
      territoryCount: (json['territory_count'] as num?)?.toInt() ?? 0,
      churchCount: (json['church_count'] as num?)?.toInt() ?? 0,
      conferenceCount: (json['conference_count'] as num?)?.toInt() ?? 0,
      totalPopulation: (json['total_population'] as num?)?.toInt() ?? 0,
      totalHousing: (json['total_housing'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UnionStatsModelToJson(UnionStatsModel instance) =>
    <String, dynamic>{
      'union_name': instance.unionName,
      'territory_count': instance.territoryCount,
      'church_count': instance.churchCount,
      'conference_count': instance.conferenceCount,
      'total_population': instance.totalPopulation,
      'total_housing': instance.totalHousing,
    };
