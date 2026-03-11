part of 'work_session_bloc.dart';

abstract class WorkSessionState extends Equatable {
  const WorkSessionState();

  @override
  List<Object?> get props => [];
}

class WorkSessionInitial extends WorkSessionState {}

class WorkSessionLoading extends WorkSessionState {}

/// Currently checked in and working
class WorkSessionActive extends WorkSessionState {
  final WorkSession session;
  final List<VisitRecord> todayVisits;
  final bool autoTrackingEnabled;
  final double? currentLatitude;
  final double? currentLongitude;

  const WorkSessionActive({
    required this.session,
    this.todayVisits = const [],
    this.autoTrackingEnabled = false,
    this.currentLatitude,
    this.currentLongitude,
  });

  WorkSessionActive copyWith({
    WorkSession? session,
    List<VisitRecord>? todayVisits,
    bool? autoTrackingEnabled,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return WorkSessionActive(
      session: session ?? this.session,
      todayVisits: todayVisits ?? this.todayVisits,
      autoTrackingEnabled: autoTrackingEnabled ?? this.autoTrackingEnabled,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }

  @override
  List<Object?> get props => [session, todayVisits, autoTrackingEnabled, currentLatitude, currentLongitude];
}

/// Not currently checked in
class WorkSessionInactive extends WorkSessionState {
  final WorkSession? lastSession;
  final bool autoTrackingEnabled;

  const WorkSessionInactive({this.lastSession, this.autoTrackingEnabled = false});

  WorkSessionInactive copyWith({
    WorkSession? lastSession,
    bool? autoTrackingEnabled,
  }) {
    return WorkSessionInactive(
      lastSession: lastSession ?? this.lastSession,
      autoTrackingEnabled: autoTrackingEnabled ?? this.autoTrackingEnabled,
    );
  }

  @override
  List<Object?> get props => [lastSession, autoTrackingEnabled];
}

class WorkSessionError extends WorkSessionState {
  final String message;

  const WorkSessionError({required this.message});

  @override
  List<Object?> get props => [message];
}

class WorkSessionVisitLogged extends WorkSessionState {
  final String message;

  const WorkSessionVisitLogged({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Work session model
class WorkSession extends Equatable {
  final String id;
  final String workerId;
  final String territoryId;
  final String territoryName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final int visitsCount;
  final String? notes;

  const WorkSession({
    required this.id,
    required this.workerId,
    required this.territoryId,
    required this.territoryName,
    required this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.visitsCount = 0,
    this.notes,
  });

  bool get isActive => checkOutTime == null;

  Duration get duration {
    final endTime = checkOutTime ?? DateTime.now();
    return endTime.difference(checkInTime);
  }

  String get formattedDuration {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  factory WorkSession.fromJson(Map<String, dynamic> json) {
    return WorkSession(
      id: json['id']?.toString() ?? '',
      workerId: json['worker_id']?.toString() ?? json['workerId']?.toString() ?? '',
      territoryId: json['territory_id']?.toString() ?? json['territoryId']?.toString() ?? '',
      territoryName: json['territory_name']?.toString() ?? json['territoryName']?.toString() ?? 'Unknown Territory',
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'].toString()) ?? DateTime.now()
          : (json['checkInTime'] != null
              ? DateTime.tryParse(json['checkInTime'].toString()) ?? DateTime.now()
              : DateTime.now()),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.tryParse(json['check_out_time'].toString())
          : (json['checkOutTime'] != null
              ? DateTime.tryParse(json['checkOutTime'].toString())
              : null),
      checkInLatitude: (json['check_in_latitude'] ?? json['checkInLatitude'])?.toDouble(),
      checkInLongitude: (json['check_in_longitude'] ?? json['checkInLongitude'])?.toDouble(),
      visitsCount: json['visits_count'] ?? json['visitsCount'] ?? 0,
      notes: json['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, workerId, territoryId, checkInTime, checkOutTime];
}

/// Visit record model
class VisitRecord extends Equatable {
  final String id;
  final String sessionId;
  final String address;
  final String outcome;
  final DateTime timestamp;
  final String? notes;
  final double? latitude;
  final double? longitude;

  const VisitRecord({
    required this.id,
    required this.sessionId,
    required this.address,
    required this.outcome,
    required this.timestamp,
    this.notes,
    this.latitude,
    this.longitude,
  });

  String get outcomeIcon {
    switch (outcome) {
      case 'contacted':
        return '✅';
      case 'not_home':
        return '🚪';
      case 'interested':
        return '⭐';
      case 'do_not_call':
        return '🚫';
      case 'completed':
        return '✓';
      default:
        return '📍';
    }
  }

  String get outcomeLabel {
    switch (outcome) {
      case 'contacted':
        return 'Contacted';
      case 'not_home':
        return 'Not Home';
      case 'interested':
        return 'Interested';
      case 'do_not_call':
        return 'Do Not Call';
      case 'completed':
        return 'Completed';
      default:
        return outcome;
    }
  }

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    return VisitRecord(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? json['sessionId']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      outcome: json['outcome']?.toString() ?? 'visited',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
              : DateTime.now()),
      notes: json['notes']?.toString(),
      latitude: (json['latitude'] ?? json['lat'])?.toDouble(),
      longitude: (json['longitude'] ?? json['lng'])?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [id, sessionId, address, outcome, timestamp];
}
