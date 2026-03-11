// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationTrack _$LocationTrackFromJson(Map<String, dynamic> json) =>
    LocationTrack(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      sessionId: json['session_id'] as String?,
      trackedAt: DateTime.parse(json['tracked_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$LocationTrackToJson(LocationTrack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'accuracy': instance.accuracy,
      'altitude': instance.altitude,
      'speed': instance.speed,
      'heading': instance.heading,
      'session_id': instance.sessionId,
      'tracked_at': instance.trackedAt.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };

LocationSession _$LocationSessionFromJson(Map<String, dynamic> json) =>
    LocationSession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      teamId: json['team_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      endLat: (json['end_lat'] as num?)?.toDouble(),
      endLng: (json['end_lng'] as num?)?.toDouble(),
      totalDistanceMeters:
          (json['total_distance_meters'] as num?)?.toDouble() ?? 0,
      trackPointsCount: (json['track_points_count'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$LocationSessionToJson(LocationSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'team_id': instance.teamId,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'start_lat': instance.startLat,
      'start_lng': instance.startLng,
      'end_lat': instance.endLat,
      'end_lng': instance.endLng,
      'total_distance_meters': instance.totalDistanceMeters,
      'track_points_count': instance.trackPointsCount,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
    };

LocationUpdate _$LocationUpdateFromJson(Map<String, dynamic> json) =>
    LocationUpdate(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      sessionId: json['session_id'] as String?,
      teamId: json['team_id'] as String?,
    );

Map<String, dynamic> _$LocationUpdateToJson(LocationUpdate instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'accuracy': instance.accuracy,
      'altitude': instance.altitude,
      'speed': instance.speed,
      'heading': instance.heading,
      'session_id': instance.sessionId,
      'team_id': instance.teamId,
    };

WorkerLocation _$WorkerLocationFromJson(Map<String, dynamic> json) =>
    WorkerLocation(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
      isActive: json['is_active'] as bool? ?? true,
      sessionId: json['session_id'] as String?,
    );

Map<String, dynamic> _$WorkerLocationToJson(WorkerLocation instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'display_name': instance.displayName,
      'avatar_url': instance.avatarUrl,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'last_updated': instance.lastUpdated.toIso8601String(),
      'is_active': instance.isActive,
      'session_id': instance.sessionId,
    };

LocationStats _$LocationStatsFromJson(Map<String, dynamic> json) =>
    LocationStats(
      totalSessions: (json['session_count'] as num?)?.toInt() ?? 0,
      totalDistanceKm: (json['total_distance'] as num?)?.toDouble() ?? 0.0,
      totalDurationSeconds: (json['total_time_seconds'] as num?)?.toInt() ?? 0,
      averageSpeed: (json['average_speed'] as num?)?.toDouble() ?? 0.0,
      maxSpeed: (json['max_speed'] as num?)?.toDouble() ?? 0.0,
      locationCount: (json['location_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$LocationStatsToJson(LocationStats instance) =>
    <String, dynamic>{
      'session_count': instance.totalSessions,
      'total_distance': instance.totalDistanceKm,
      'total_time_seconds': instance.totalDurationSeconds,
      'average_speed': instance.averageSpeed,
      'max_speed': instance.maxSpeed,
      'location_count': instance.locationCount,
    };
