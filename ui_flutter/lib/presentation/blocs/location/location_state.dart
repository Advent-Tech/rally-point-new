part of 'location_bloc.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationPermissionGranted extends LocationState {}

class LocationPermissionDenied extends LocationState {
  final String message;
  final bool canRequestAgain;

  const LocationPermissionDenied({
    required this.message,
    this.canRequestAgain = true,
  });

  @override
  List<Object?> get props => [message, canRequestAgain];
}

class LocationTracking extends LocationState {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final String? sessionId;
  final DateTime startTime;
  final double distance;
  final Duration duration;

  const LocationTracking({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.sessionId,
    required this.startTime,
    required this.distance,
    required this.duration,
  });

  String get formattedDistance {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String get formattedSpeed {
    if (speed == null) return '0 km/h';
    final kmh = speed! * 3.6; // Convert m/s to km/h
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  @override
  List<Object?> get props => [
    latitude, longitude, accuracy, speed, heading, altitude,
    sessionId, startTime, distance, duration,
  ];
}

class LocationStopped extends LocationState {}

class LocationSessionsLoaded extends LocationState {
  final List<LocationSession> sessions;
  final bool hasMore;
  final bool isOffline;

  const LocationSessionsLoaded({
    required this.sessions,
    this.hasMore = false,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [sessions, hasMore, isOffline];
}

class LocationStatsLoaded extends LocationState {
  final LocationStats stats;

  const LocationStatsLoaded({required this.stats});

  @override
  List<Object?> get props => [stats];
}

class LocationNearbyWorkersLoaded extends LocationState {
  final List<WorkerLocation> workers;

  const LocationNearbyWorkersLoaded({required this.workers});

  @override
  List<Object?> get props => [workers];
}

class LocationError extends LocationState {
  final String message;

  const LocationError({required this.message});

  @override
  List<Object?> get props => [message];
}
