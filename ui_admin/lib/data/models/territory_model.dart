import 'package:json_annotation/json_annotation.dart';

part 'territory_model.g.dart';

@JsonSerializable()
class TerritoryModel {
  final String id;
  final String? solid;
  @JsonKey(name: 'entity_name')
  final String entityName;
  @JsonKey(name: 'entity_id')
  final String? entityId;
  @JsonKey(name: 'union_name')
  final String? unionName;
  @JsonKey(name: 'conference_name')
  final String? conferenceName;
  @JsonKey(name: 'housing_units')
  final int? housingUnits;
  final int? population;
  @JsonKey(name: 'area_sqkm')
  final double? areaSqKm;

  const TerritoryModel({
    required this.id,
    this.solid,
    required this.entityName,
    this.entityId,
    this.unionName,
    this.conferenceName,
    this.housingUnits,
    this.population,
    this.areaSqKm,
  });

  factory TerritoryModel.fromJson(Map<String, dynamic> json) => _$TerritoryModelFromJson(json);
  Map<String, dynamic> toJson() => _$TerritoryModelToJson(this);
}

@JsonSerializable()
class TerritoryAllocation {
  final String id;
  @JsonKey(name: 'leader_id')
  final String leaderId;
  @JsonKey(name: 'leader_name')
  final String? leaderName;
  @JsonKey(name: 'territory_id')
  final String territoryId;
  @JsonKey(name: 'territory_solid')
  final String? territorySolid;
  @JsonKey(name: 'territory_name')
  final String? territoryName;
  @JsonKey(name: 'allocated_by')
  final String allocatedBy;
  @JsonKey(name: 'allocated_at')
  final DateTime? allocatedAt;
  final String? notes;
  final TerritoryModel? territory;

  const TerritoryAllocation({
    required this.id,
    required this.leaderId,
    this.leaderName,
    required this.territoryId,
    this.territorySolid,
    this.territoryName,
    required this.allocatedBy,
    this.allocatedAt,
    this.notes,
    this.territory,
  });

  factory TerritoryAllocation.fromJson(Map<String, dynamic> json) {
    final base = _$TerritoryAllocationFromJson(json);
    // API returns entity_name, not territory_name
    if (base.territoryName == null && json['entity_name'] != null) {
      return TerritoryAllocation(
        id: base.id,
        leaderId: base.leaderId,
        leaderName: base.leaderName,
        territoryId: base.territoryId,
        territorySolid: base.territorySolid,
        territoryName: json['entity_name'] as String?,
        allocatedBy: base.allocatedBy,
        allocatedAt: base.allocatedAt,
        notes: base.notes,
        territory: base.territory,
      );
    }
    return base;
  }
  Map<String, dynamic> toJson() => _$TerritoryAllocationToJson(this);
}

@JsonSerializable()
class UnionStats {
  @JsonKey(name: 'union_name')
  final String unionName;
  @JsonKey(name: 'territory_count')
  final int territoryCount;
  @JsonKey(name: 'total_housing', defaultValue: 0)
  final int totalHousingUnits;
  @JsonKey(name: 'total_population', defaultValue: 0)
  final int totalPopulation;

  const UnionStats({
    required this.unionName,
    required this.territoryCount,
    this.totalHousingUnits = 0,
    this.totalPopulation = 0,
  });

  factory UnionStats.fromJson(Map<String, dynamic> json) => _$UnionStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UnionStatsToJson(this);
}

/// Territory with geometry data for map display
class GeoTerritory {
  final String id;
  final String solid;
  final String entityName;
  final String? unionName;
  final String? conferenceName;
  final int? housingUnits;
  final Map<String, dynamic>? geometry;

  const GeoTerritory({
    required this.id,
    required this.solid,
    required this.entityName,
    this.unionName,
    this.conferenceName,
    this.housingUnits,
    this.geometry,
  });

  factory GeoTerritory.fromJson(Map<String, dynamic> json) {
    return GeoTerritory(
      id: json['id']?.toString() ?? '',
      solid: json['solid']?.toString() ?? json['territory_solid']?.toString() ?? '',
      entityName: json['entity_name']?.toString() ?? json['name']?.toString() ?? '',
      unionName: json['union_name']?.toString(),
      conferenceName: json['conference']?.toString() ?? json['conference_name']?.toString(),
      housingUnits: json['housing_units'] as int?,
      geometry: json['geometry'] as Map<String, dynamic>?,
    );
  }
}
