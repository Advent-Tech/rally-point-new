import 'package:equatable/equatable.dart';
import '../../../../data/models/territory_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/prayer_request_model.dart';

enum MapMode { overview, workers, territories }

enum MapPopupKind {
  activityDonation,
  activityBookSale,
  activityPrayer,
  territory,
  worker,
}

class MapPopup extends Equatable {
  final MapPopupKind kind;
  final String id;
  final double? latitude;
  final double? longitude;
  final bool expanded;

  const MapPopup({
    required this.kind,
    required this.id,
    this.latitude,
    this.longitude,
    this.expanded = false,
  });

  MapPopup copyWith({bool? expanded}) {
    return MapPopup(
      kind: kind,
      id: id,
      latitude: latitude,
      longitude: longitude,
      expanded: expanded ?? this.expanded,
    );
  }

  @override
  List<Object?> get props => [kind, id, latitude, longitude, expanded];
}

class CommandCenterState extends Equatable {
  // Map mode and UI state
  final MapMode mapMode;
  final bool isLoading;
  final String? error;

  // Layer visibility
  final bool showTerritories;
  final bool showWorkers;
  final bool showActivities;
  final bool showTrails;

  // Cached data
  final List<GeoTerritory> territories;
  final List<TeamMember> workers;
  final List<DonationModel> donations;
  final List<PrayerRequestModel> prayerRequests;

  // Real-time data
  final Map<String, Position> liveLocations; // workerId -> Position
  final Map<String, DateTime> liveLocationUpdatedAt; // workerId -> last event ts
  final Set<String> gpsLiveWorkerIds; // workerIds with websocket GPS updates
  final Set<String> breachedWorkerIds;

  // Interaction state
  final String? followTarget; // workerId being followed
  final String? selectedTerritoryId;
  final Map<String, List<Position>> workerPaths; // workerId -> trail

  final MapPopup? activePopup;

  const CommandCenterState({
    this.mapMode = MapMode.overview,
    this.isLoading = true,
    this.error,
    this.showTerritories = true,
    this.showWorkers = true,
    this.showActivities = true,
    this.showTrails = false,
    this.territories = const [],
    this.workers = const [],
    this.donations = const [],
    this.prayerRequests = const [],
    this.liveLocations = const {},
    this.liveLocationUpdatedAt = const {},
    this.gpsLiveWorkerIds = const {},
    this.breachedWorkerIds = const {},
    this.followTarget,
    this.selectedTerritoryId,
    this.workerPaths = const {},
    this.activePopup,
  });

  @override
  List<Object?> get props => [
    mapMode,
    isLoading,
    error,
    showTerritories,
    showWorkers,
    showActivities,
    showTrails,
    territories,
    workers,
    donations,
    prayerRequests,
    liveLocations,
    liveLocationUpdatedAt,
    gpsLiveWorkerIds,
    breachedWorkerIds,
    followTarget,
    selectedTerritoryId,
    workerPaths,
    activePopup,
  ];

  CommandCenterState copyWith({
    MapMode? mapMode,
    bool? isLoading,
    String? error,
    bool? showTerritories,
    bool? showWorkers,
    bool? showActivities,
    bool? showTrails,
    List<GeoTerritory>? territories,
    List<TeamMember>? workers,
    List<DonationModel>? donations,
    List<PrayerRequestModel>? prayerRequests,
    Map<String, Position>? liveLocations,
    Map<String, DateTime>? liveLocationUpdatedAt,
    Set<String>? gpsLiveWorkerIds,
    Set<String>? breachedWorkerIds,
    String? followTarget,
    String? selectedTerritoryId,
    Map<String, List<Position>>? workerPaths,
    MapPopup? activePopup,
  }) {
    return CommandCenterState(
      mapMode: mapMode ?? this.mapMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showTerritories: showTerritories ?? this.showTerritories,
      showWorkers: showWorkers ?? this.showWorkers,
      showActivities: showActivities ?? this.showActivities,
      showTrails: showTrails ?? this.showTrails,
      territories: territories ?? this.territories,
      workers: workers ?? this.workers,
      donations: donations ?? this.donations,
      prayerRequests: prayerRequests ?? this.prayerRequests,
      liveLocations: liveLocations ?? this.liveLocations,
      liveLocationUpdatedAt:
          liveLocationUpdatedAt ?? this.liveLocationUpdatedAt,
      gpsLiveWorkerIds: gpsLiveWorkerIds ?? this.gpsLiveWorkerIds,
      breachedWorkerIds: breachedWorkerIds ?? this.breachedWorkerIds,
      followTarget: followTarget == ''
          ? null
          : (followTarget ?? this.followTarget),
      selectedTerritoryId: selectedTerritoryId == ''
          ? null
          : (selectedTerritoryId ?? this.selectedTerritoryId),
      workerPaths: workerPaths ?? this.workerPaths,
      activePopup: activePopup,
    );
  }
}

// Simple position class for real-time locations
class Position {
  final double latitude;
  final double longitude;

  const Position({required this.latitude, required this.longitude});
}
