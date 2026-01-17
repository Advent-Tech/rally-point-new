import 'package:json_annotation/json_annotation.dart';

part 'location_model.g.dart';

@JsonSerializable()
class LocationTrack {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  @JsonKey(name: 'session_id')
  final String? sessionId;
  @JsonKey(name: 'tracked_at')
  final DateTime trackedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const LocationTrack({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.sessionId,
    required this.trackedAt,
    this.createdAt,
  });

  factory LocationTrack.fromJson(Map<String, dynamic> json) => _$LocationTrackFromJson(json);
  Map<String, dynamic> toJson() => _$LocationTrackToJson(this);
}

@JsonSerializable()
class LocationSession {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'team_id')
  final String? teamId;
  @JsonKey(name: 'start_time')
  final DateTime startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  @JsonKey(name: 'start_lat')
  final double? startLat;
  @JsonKey(name: 'start_lng')
  final double? startLng;
  @JsonKey(name: 'end_lat')
  final double? endLat;
  @JsonKey(name: 'end_lng')
  final double? endLng;
  @JsonKey(name: 'total_distance_meters')
  final double totalDistanceMeters;
  @JsonKey(name: 'track_points_count')
  final int trackPointsCount;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const LocationSession({
    required this.id,
    required this.userId,
    this.teamId,
    required this.startTime,
    this.endTime,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.totalDistanceMeters = 0,
    this.trackPointsCount = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory LocationSession.fromJson(Map<String, dynamic> json) => _$LocationSessionFromJson(json);
  Map<String, dynamic> toJson() => _$LocationSessionToJson(this);

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get formattedDuration {
    final dur = duration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedDistance {
    if (totalDistanceMeters >= 1000) {
      return '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${totalDistanceMeters.toStringAsFixed(0)} m';
  }
}

@JsonSerializable()
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  @JsonKey(name: 'session_id')
  final String? sessionId;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.sessionId,
  });

  factory LocationUpdate.fromJson(Map<String, dynamic> json) => _$LocationUpdateFromJson(json);
  Map<String, dynamic> toJson() => _$LocationUpdateToJson(this);
}

@JsonSerializable()
class WorkerLocation {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'last_updated')
  final DateTime lastUpdated;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'session_id')
  final String? sessionId;

  const WorkerLocation({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.isActive = true,
    this.sessionId,
  });

  factory WorkerLocation.fromJson(Map<String, dynamic> json) => _$WorkerLocationFromJson(json);
  Map<String, dynamic> toJson() => _$WorkerLocationToJson(this);
}

@JsonSerializable()
class LocationStats {
  @JsonKey(name: 'session_count', defaultValue: 0)
  final int totalSessions;
  @JsonKey(name: 'total_distance', defaultValue: 0.0)
  final double totalDistanceKm;
  @JsonKey(name: 'total_time_seconds', defaultValue: 0)
  final int totalDurationSeconds;
  @JsonKey(name: 'average_speed', defaultValue: 0.0)
  final double averageSpeed;
  @JsonKey(name: 'max_speed', defaultValue: 0.0)
  final double maxSpeed;
  @JsonKey(name: 'location_count', defaultValue: 0)
  final int locationCount;

  const LocationStats({
    required this.totalSessions,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.locationCount,
  });

  factory LocationStats.fromJson(Map<String, dynamic> json) => _$LocationStatsFromJson(json);
  Map<String, dynamic> toJson() => _$LocationStatsToJson(this);

  // Convert km to meters for backwards compatibility
  double get totalDistanceMeters => totalDistanceKm * 1000;

  String get formattedTotalDistance {
    if (totalDistanceKm >= 1) {
      return '${totalDistanceKm.toStringAsFixed(2)} km';
    }
    return '${(totalDistanceKm * 1000).toStringAsFixed(0)} m';
  }

  String get formattedTotalDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
