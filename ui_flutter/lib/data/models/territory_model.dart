import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'territory_model.g.dart';

/// Custom converter to handle geometry that may come as a JSON string or Map
Map<String, dynamic>? _geometryFromJson(dynamic json) {
  if (json == null) return null;
  if (json is Map<String, dynamic>) return json;
  if (json is String) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  return null;
}

String? _geometryToJson(Map<String, dynamic>? geometry) {
  if (geometry == null) return null;
  return jsonEncode(geometry);
}

@JsonSerializable()
class GeoTerritory {
  final String id;
  final int? fid;
  final String solid;
  @JsonKey(name: 'entity_name')
  final String entityName;
  @JsonKey(name: 'entity_id')
  final String entityId;
  @JsonKey(name: 'group_id')
  final String? groupId;
  final String? address;
  @JsonKey(name: 'street_address')
  final String? streetAddress;
  final String? city;
  final String? county;
  final String? state;
  final String? zipcode;
  final int? population;
  @JsonKey(name: 'housing_units')
  final int? housingUnits;
  @JsonKey(name: 'union_name')
  final String? unionName;
  final String? conference;
  final String? geoid;
  @JsonKey(fromJson: _geometryFromJson, toJson: _geometryToJson)
  final Map<String, dynamic>? geometry;

  const GeoTerritory({
    required this.id,
    this.fid,
    required this.solid,
    required this.entityName,
    required this.entityId,
    this.groupId,
    this.address,
    this.streetAddress,
    this.city,
    this.county,
    this.state,
    this.zipcode,
    this.population,
    this.housingUnits,
    this.unionName,
    this.conference,
    this.geoid,
    this.geometry,
  });

  factory GeoTerritory.fromJson(Map<String, dynamic> json) => _$GeoTerritoryFromJson(json);
  Map<String, dynamic> toJson() => _$GeoTerritoryToJson(this);

  String get displayLocation {
    final parts = <String>[];
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }
}

@JsonSerializable()
class TerritoryAssignment {
  final String id;
  @JsonKey(name: 'territory_id')
  final String territoryId;
  @JsonKey(name: 'territory_solid')
  final String territorySolid;
  @JsonKey(name: 'team_id')
  final String teamId;
  @JsonKey(name: 'assigned_worker_id')
  final String? assignedWorkerId;
  @JsonKey(name: 'assigned_by')
  final String assignedBy;
  @JsonKey(name: 'assigned_at')
  final DateTime assignedAt;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  final String status;
  final String priority;
  final String? notes;
  @JsonKey(name: 'last_worked_at')
  final DateTime? lastWorkedAt;
  @JsonKey(name: 'visits_count')
  final int visitsCount;
  @JsonKey(name: 'completeness_percentage')
  final double completenessPercentage;

  // Territory details (when joined)
  @JsonKey(name: 'entity_name')
  final String? entityName;
  @JsonKey(name: 'entity_id')
  final String? entityId;
  final String? city;
  final String? state;
  @JsonKey(name: 'union_name')
  final String? unionName;
  final String? conference;
  final int? population;
  @JsonKey(name: 'housing_units')
  final int? housingUnits;
  @JsonKey(fromJson: _geometryFromJson, toJson: _geometryToJson)
  final Map<String, dynamic>? geometry;

  const TerritoryAssignment({
    required this.id,
    required this.territoryId,
    required this.territorySolid,
    required this.teamId,
    this.assignedWorkerId,
    required this.assignedBy,
    required this.assignedAt,
    this.expiresAt,
    required this.status,
    required this.priority,
    this.notes,
    this.lastWorkedAt,
    this.visitsCount = 0,
    this.completenessPercentage = 0.0,
    this.entityName,
    this.entityId,
    this.city,
    this.state,
    this.unionName,
    this.conference,
    this.population,
    this.housingUnits,
    this.geometry,
  });

  factory TerritoryAssignment.fromJson(Map<String, dynamic> json) => _$TerritoryAssignmentFromJson(json);
  Map<String, dynamic> toJson() => _$TerritoryAssignmentToJson(this);

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isPaused => status == 'paused';
}

@JsonSerializable()
class UnionStats {
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

  const UnionStats({
    required this.unionName,
    required this.territoryCount,
    required this.churchCount,
    required this.conferenceCount,
    required this.totalPopulation,
    required this.totalHousing,
  });

  factory UnionStats.fromJson(Map<String, dynamic> json) => _$UnionStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UnionStatsToJson(this);
}

@JsonSerializable()
class ChurchLocation {
  @JsonKey(name: 'entity_id')
  final String entityId;
  @JsonKey(name: 'entity_name')
  final String entityName;
  @JsonKey(name: 'union_name')
  final String? unionName;
  final String? conference;
  final String? address;
  final String? city;
  final String? state;
  final double latitude;
  final double longitude;
  @JsonKey(name: 'territory_count')
  final int territoryCount;
  @JsonKey(name: 'total_population')
  final int totalPopulation;
  @JsonKey(name: 'total_housing')
  final int totalHousing;

  const ChurchLocation({
    required this.entityId,
    required this.entityName,
    this.unionName,
    this.conference,
    this.address,
    this.city,
    this.state,
    required this.latitude,
    required this.longitude,
    required this.territoryCount,
    required this.totalPopulation,
    required this.totalHousing,
  });

  factory ChurchLocation.fromJson(Map<String, dynamic> json) => _$ChurchLocationFromJson(json);
  Map<String, dynamic> toJson() => _$ChurchLocationToJson(this);
}
