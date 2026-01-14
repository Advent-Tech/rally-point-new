// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'territory_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TerritoryModel _$TerritoryModelFromJson(Map<String, dynamic> json) =>
    TerritoryModel(
      id: json['id'] as String,
      solid: json['solid'] as String?,
      entityName: json['entity_name'] as String,
      entityId: json['entity_id'] as String?,
      unionName: json['union_name'] as String?,
      conferenceName: json['conference_name'] as String?,
      housingUnits: (json['housing_units'] as num?)?.toInt(),
      population: (json['population'] as num?)?.toInt(),
      areaSqKm: (json['area_sqkm'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TerritoryModelToJson(TerritoryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'solid': instance.solid,
      'entity_name': instance.entityName,
      'entity_id': instance.entityId,
      'union_name': instance.unionName,
      'conference_name': instance.conferenceName,
      'housing_units': instance.housingUnits,
      'population': instance.population,
      'area_sqkm': instance.areaSqKm,
    };

TerritoryAllocation _$TerritoryAllocationFromJson(Map<String, dynamic> json) =>
    TerritoryAllocation(
      id: json['id'] as String,
      leaderId: json['leader_id'] as String,
      leaderName: json['leader_name'] as String?,
      territoryId: json['territory_id'] as String,
      territorySolid: json['territory_solid'] as String?,
      territoryName: json['territory_name'] as String?,
      allocatedBy: json['allocated_by'] as String,
      allocatedAt: json['allocated_at'] == null
          ? null
          : DateTime.parse(json['allocated_at'] as String),
      notes: json['notes'] as String?,
      territory: json['territory'] == null
          ? null
          : TerritoryModel.fromJson(json['territory'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TerritoryAllocationToJson(
  TerritoryAllocation instance,
) => <String, dynamic>{
  'id': instance.id,
  'leader_id': instance.leaderId,
  'leader_name': instance.leaderName,
  'territory_id': instance.territoryId,
  'territory_solid': instance.territorySolid,
  'territory_name': instance.territoryName,
  'allocated_by': instance.allocatedBy,
  'allocated_at': instance.allocatedAt?.toIso8601String(),
  'notes': instance.notes,
  'territory': instance.territory,
};

UnionStats _$UnionStatsFromJson(Map<String, dynamic> json) => UnionStats(
  unionName: json['union_name'] as String,
  territoryCount: (json['territory_count'] as num).toInt(),
  totalHousingUnits: (json['total_housing'] as num?)?.toInt() ?? 0,
  totalPopulation: (json['total_population'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$UnionStatsToJson(UnionStats instance) =>
    <String, dynamic>{
      'union_name': instance.unionName,
      'territory_count': instance.territoryCount,
      'total_housing': instance.totalHousingUnits,
      'total_population': instance.totalPopulation,
    };
