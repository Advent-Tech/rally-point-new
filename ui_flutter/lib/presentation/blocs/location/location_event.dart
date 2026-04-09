part of 'location_bloc.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class LocationCheckPermission extends LocationEvent {
  const LocationCheckPermission();
}

class LocationRequestPermission extends LocationEvent {
  const LocationRequestPermission();
}

class LocationStartTracking extends LocationEvent {
  const LocationStartTracking();
}

class LocationStopTracking extends LocationEvent {
  const LocationStopTracking();
}

class LocationUpdatePosition extends LocationEvent {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  const LocationUpdatePosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracy, speed, heading, altitude];
}

class LocationLoadSessions extends LocationEvent {
  final int limit;
  final int offset;

  const LocationLoadSessions({
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [limit, offset];
}

class LocationLoadStats extends LocationEvent {
  const LocationLoadStats();
}

class LocationLoadNearbyWorkers extends LocationEvent {
  final double latitude;
  final double longitude;
  final double radiusKm;

  const LocationLoadNearbyWorkers({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 5,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusKm];
}

class LocationSyncPending extends LocationEvent {
  const LocationSyncPending();
}
