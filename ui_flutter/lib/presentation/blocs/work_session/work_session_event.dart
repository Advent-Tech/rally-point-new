part of 'work_session_bloc.dart';

abstract class WorkSessionEvent extends Equatable {
  const WorkSessionEvent();

  @override
  List<Object?> get props => [];
}

/// Check in to start working on a territory
class WorkSessionCheckIn extends WorkSessionEvent {
  final String territoryId;
  final String territoryName;
  final double? latitude;
  final double? longitude;

  const WorkSessionCheckIn({
    required this.territoryId,
    required this.territoryName,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [territoryId, territoryName, latitude, longitude];
}

/// Check out to end working on current territory
class WorkSessionCheckOut extends WorkSessionEvent {
  final String? notes;

  const WorkSessionCheckOut({this.notes});

  @override
  List<Object?> get props => [notes];
}

/// Load current active session if any
class WorkSessionLoadCurrent extends WorkSessionEvent {
  const WorkSessionLoadCurrent();
}

/// Log a visit to an address
class WorkSessionLogVisit extends WorkSessionEvent {
  final String address;
  final String outcome; // 'contacted', 'not_home', 'interested', 'do_not_call', 'completed'
  final String? notes;
  final double? latitude;
  final double? longitude;

  const WorkSessionLogVisit({
    required this.address,
    required this.outcome,
    this.notes,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [address, outcome, notes, latitude, longitude];
}

/// Load session history
class WorkSessionLoadHistory extends WorkSessionEvent {
  final int limit;
  final int offset;

  const WorkSessionLoadHistory({
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Enable/disable auto-tracking
class WorkSessionToggleAutoTracking extends WorkSessionEvent {
  final bool enabled;

  const WorkSessionToggleAutoTracking({required this.enabled});

  @override
  List<Object?> get props => [enabled];
}

/// Auto check-in triggered by geofence
class WorkSessionAutoCheckIn extends WorkSessionEvent {
  final String territoryId;
  final String territoryName;
  final double latitude;
  final double longitude;

  const WorkSessionAutoCheckIn({
    required this.territoryId,
    required this.territoryName,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [territoryId, territoryName, latitude, longitude];
}

/// Auto check-out triggered by geofence
class WorkSessionAutoCheckOut extends WorkSessionEvent {
  final double? latitude;
  final double? longitude;

  const WorkSessionAutoCheckOut({
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}

/// Location updated during session
class WorkSessionLocationUpdated extends WorkSessionEvent {
  final double latitude;
  final double longitude;
  final double? accuracy;

  const WorkSessionLocationUpdated({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracy];
}
