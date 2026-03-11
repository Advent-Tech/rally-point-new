part of 'team_map_bloc.dart';

abstract class TeamMapState extends Equatable {
  const TeamMapState();

  @override
  List<Object?> get props => [];
}

class TeamMapInitial extends TeamMapState {}

class TeamMapLoading extends TeamMapState {}

class TeamMapLoaded extends TeamMapState {
  final List<ActiveWorkerLocation> activeWorkers;
  final List<MapPrayerMarker> prayerRequests;
  final List<MapDonationMarker> donations;
  final List<TerritoryBoundary> territoryBoundaries;
  final bool showWorkers;
  final bool showPrayers;
  final bool showDonations;
  final bool showTerritories;
  final String teamId;

  const TeamMapLoaded({
    required this.activeWorkers,
    required this.prayerRequests,
    required this.donations,
    this.territoryBoundaries = const [],
    this.showWorkers = true,
    this.showPrayers = true,
    this.showDonations = true,
    this.showTerritories = true,
    required this.teamId,
  });

  TeamMapLoaded copyWith({
    List<ActiveWorkerLocation>? activeWorkers,
    List<MapPrayerMarker>? prayerRequests,
    List<MapDonationMarker>? donations,
    List<TerritoryBoundary>? territoryBoundaries,
    bool? showWorkers,
    bool? showPrayers,
    bool? showDonations,
    bool? showTerritories,
    String? teamId,
  }) {
    return TeamMapLoaded(
      activeWorkers: activeWorkers ?? this.activeWorkers,
      prayerRequests: prayerRequests ?? this.prayerRequests,
      donations: donations ?? this.donations,
      territoryBoundaries: territoryBoundaries ?? this.territoryBoundaries,
      showWorkers: showWorkers ?? this.showWorkers,
      showPrayers: showPrayers ?? this.showPrayers,
      showDonations: showDonations ?? this.showDonations,
      showTerritories: showTerritories ?? this.showTerritories,
      teamId: teamId ?? this.teamId,
    );
  }

  @override
  List<Object?> get props => [
    activeWorkers,
    prayerRequests,
    donations,
    territoryBoundaries,
    showWorkers,
    showPrayers,
    showDonations,
    showTerritories,
    teamId,
  ];
}

class TeamMapError extends TeamMapState {
  final String message;

  const TeamMapError({required this.message});

  @override
  List<Object?> get props => [message];
}

// Data models for map markers
class ActiveWorkerLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String status;
  final String territoryName;
  final DateTime lastUpdate;

  const ActiveWorkerLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.territoryName,
    required this.lastUpdate,
  });

  factory ActiveWorkerLocation.fromJson(Map<String, dynamic> json) {
    return ActiveWorkerLocation(
      id: json['worker_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['worker_name'] ?? json['name'] ?? 'Unknown',
      latitude: (json['latitude'] ?? json['entry_lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['entry_lng'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'working',
      territoryName: json['territory_name'] ?? 'Unknown Territory',
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class MapDonationMarker {
  final String id;
  final double latitude;
  final double longitude;
  final double amount;
  final String donorName;
  final String workerName;
  final String workerId;

  const MapDonationMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.amount,
    required this.donorName,
    required this.workerName,
    required this.workerId,
  });

  factory MapDonationMarker.fromJson(Map<String, dynamic> json) {
    return MapDonationMarker(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      amount: (json['amount'] ?? 0.0).toDouble(),
      donorName: json['donor_name'] ?? 'Anonymous',
      workerName: json['worker_name'] ?? json['collector_name'] ?? 'Unknown',
      workerId:
          json['worker_id']?.toString() ??
          json['collected_by_id']?.toString() ??
          '',
    );
  }
}

class MapPrayerMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? description;
  final String workerName;
  final String workerId;
  final String status;
  final DateTime createdAt;

  const MapPrayerMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.description,
    required this.workerName,
    required this.workerId,
    required this.status,
    required this.createdAt,
  });

  factory MapPrayerMarker.fromJson(Map<String, dynamic> json) {
    return MapPrayerMarker(
      id: json['id']?.toString() ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      title: json['title'] ?? 'Prayer Request',
      description: json['description'],
      workerName: json['worker_name'] ?? json['submitted_by_name'] ?? 'Unknown',
      workerId:
          json['worker_id']?.toString() ??
          json['submitted_by']?.toString() ??
          '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a territory boundary polygon for map display
class TerritoryBoundary {
  final String id;
  final String name;
  final String? solid;
  final List<List<double>> coordinates; // List of [lng, lat] pairs

  const TerritoryBoundary({
    required this.id,
    required this.name,
    this.solid,
    required this.coordinates,
  });

  /// Parse from GeoJSON feature
  factory TerritoryBoundary.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'];

    // Handle case where geometry might be a string (JSON not auto-parsed)
    Map<String, dynamic> geometryMap;
    if (geometry is Map<String, dynamic>) {
      geometryMap = geometry;
    } else if (geometry is String) {
      // Try to parse if it's a JSON string
      try {
        geometryMap = Map<String, dynamic>.from(jsonDecode(geometry));
      } catch (_) {
        geometryMap = <String, dynamic>{};
      }
    } else {
      geometryMap = <String, dynamic>{};
    }

    // Extract coordinates based on geometry type
    List<List<double>> coords = [];
    final geometryType = geometryMap['type'] as String?;
    final rawCoordinates = geometryMap['coordinates'];

    if (rawCoordinates != null) {
      if (geometryType == 'Polygon') {
        // Polygon: [[[lng, lat], [lng, lat], ...]]
        final outer = rawCoordinates[0] as List;
        coords = outer.map<List<double>>((point) {
          final p = point as List;
          return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
        }).toList();
      } else if (geometryType == 'MultiPolygon') {
        // MultiPolygon: [[[[lng, lat], ...]], [[[lng, lat], ...]]]
        // Take only the first polygon for simplicity
        if ((rawCoordinates as List).isNotEmpty) {
          final firstPolygon = rawCoordinates[0] as List;
          if (firstPolygon.isNotEmpty) {
            final outer = firstPolygon[0] as List;
            coords = outer.map<List<double>>((point) {
              final p = point as List;
              return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
            }).toList();
          }
        }
      }
    }

    return TerritoryBoundary(
      id: feature['id']?.toString() ?? properties['id']?.toString() ?? '',
      name:
          properties['entity_name']?.toString() ??
          properties['name']?.toString() ??
          'Territory',
      solid: properties['solid']?.toString(),
      coordinates: coords,
    );
  }

  /// Parse from assignment response (same format as delivery screen uses)
  factory TerritoryBoundary.fromAssignment(Map<String, dynamic> json) {
    List<List<double>> coords = [];

    // The geometry field contains the GeoJSON geometry
    final geometry = json['geometry'] as Map<String, dynamic>?;
    if (geometry != null) {
      final geometryType = geometry['type'] as String?;
      final rawCoordinates = geometry['coordinates'];

      if (rawCoordinates != null) {
        if (geometryType == 'Polygon') {
          // Polygon: [[[lng, lat], [lng, lat], ...]]
          final outer = rawCoordinates[0] as List;
          coords = outer.map<List<double>>((point) {
            final p = point as List;
            return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
          }).toList();
        } else if (geometryType == 'MultiPolygon') {
          // MultiPolygon: [[[[lng, lat], ...]], [[[lng, lat], ...]]]
          if ((rawCoordinates as List).isNotEmpty) {
            final firstPolygon = rawCoordinates[0] as List;
            if (firstPolygon.isNotEmpty) {
              final outer = firstPolygon[0] as List;
              coords = outer.map<List<double>>((point) {
                final p = point as List;
                return [(p[0] as num).toDouble(), (p[1] as num).toDouble()];
              }).toList();
            }
          }
        }
      }
    }

    return TerritoryBoundary(
      id: json['id']?.toString() ?? json['territory_id']?.toString() ?? '',
      name:
          json['territory_name']?.toString() ??
          json['entity_name']?.toString() ??
          'Territory',
      solid: json['solid']?.toString(),
      coordinates: coords,
    );
  }
}
