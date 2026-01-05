// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'territory_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeoTerritory _$GeoTerritoryFromJson(Map<String, dynamic> json) => GeoTerritory(
      id: json['id'] as String,
      fid: (json['fid'] as num?)?.toInt(),
      solid: json['solid'] as String,
      entityName: json['entity_name'] as String,
      entityId: json['entity_id'] as String,
      groupId: json['group_id'] as String?,
      address: json['address'] as String?,
      streetAddress: json['street_address'] as String?,
      city: json['city'] as String?,
      county: json['county'] as String?,
      state: json['state'] as String?,
      zipcode: json['zipcode'] as String?,
      population: (json['population'] as num?)?.toInt(),
      housingUnits: (json['housing_units'] as num?)?.toInt(),
      unionName: json['union_name'] as String?,
      conference: json['conference'] as String?,
      geoid: json['geoid'] as String?,
      geometry: _geometryFromJson(json['geometry']),
    );

Map<String, dynamic> _$GeoTerritoryToJson(GeoTerritory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fid': instance.fid,
      'solid': instance.solid,
      'entity_name': instance.entityName,
      'entity_id': instance.entityId,
      'group_id': instance.groupId,
      'address': instance.address,
      'street_address': instance.streetAddress,
      'city': instance.city,
      'county': instance.county,
      'state': instance.state,
      'zipcode': instance.zipcode,
      'population': instance.population,
      'housing_units': instance.housingUnits,
      'union_name': instance.unionName,
      'conference': instance.conference,
      'geoid': instance.geoid,
      'geometry': _geometryToJson(instance.geometry),
    };

TerritoryAssignment _$TerritoryAssignmentFromJson(Map<String, dynamic> json) =>
    TerritoryAssignment(
      id: json['id'] as String,
      territoryId: json['territory_id'] as String,
      territorySolid: json['territory_solid'] as String,
      teamId: json['team_id'] as String,
      assignedWorkerId: json['assigned_worker_id'] as String?,
      assignedBy: json['assigned_by'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      status: json['status'] as String,
      priority: json['priority'] as String,
      notes: json['notes'] as String?,
      lastWorkedAt: json['last_worked_at'] == null
          ? null
          : DateTime.parse(json['last_worked_at'] as String),
      visitsCount: (json['visits_count'] as num?)?.toInt() ?? 0,
      completenessPercentage:
          (json['completeness_percentage'] as num?)?.toDouble() ?? 0.0,
      entityName: json['entity_name'] as String?,
      entityId: json['entity_id'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      unionName: json['union_name'] as String?,
      conference: json['conference'] as String?,
      population: (json['population'] as num?)?.toInt(),
      housingUnits: (json['housing_units'] as num?)?.toInt(),
      geometry: _geometryFromJson(json['geometry']),
    );

Map<String, dynamic> _$TerritoryAssignmentToJson(
        TerritoryAssignment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'territory_id': instance.territoryId,
      'territory_solid': instance.territorySolid,
      'team_id': instance.teamId,
      'assigned_worker_id': instance.assignedWorkerId,
      'assigned_by': instance.assignedBy,
      'assigned_at': instance.assignedAt.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
      'status': instance.status,
      'priority': instance.priority,
      'notes': instance.notes,
      'last_worked_at': instance.lastWorkedAt?.toIso8601String(),
      'visits_count': instance.visitsCount,
      'completeness_percentage': instance.completenessPercentage,
      'entity_name': instance.entityName,
      'entity_id': instance.entityId,
      'city': instance.city,
      'state': instance.state,
      'union_name': instance.unionName,
      'conference': instance.conference,
      'population': instance.population,
      'housing_units': instance.housingUnits,
      'geometry': _geometryToJson(instance.geometry),
    };

UnionStats _$UnionStatsFromJson(Map<String, dynamic> json) => UnionStats(
      unionName: json['union_name'] as String,
      territoryCount: (json['territory_count'] as num).toInt(),
      churchCount: (json['church_count'] as num).toInt(),
      conferenceCount: (json['conference_count'] as num).toInt(),
      totalPopulation: (json['total_population'] as num).toInt(),
      totalHousing: (json['total_housing'] as num).toInt(),
    );

Map<String, dynamic> _$UnionStatsToJson(UnionStats instance) =>
    <String, dynamic>{
      'union_name': instance.unionName,
      'territory_count': instance.territoryCount,
      'church_count': instance.churchCount,
      'conference_count': instance.conferenceCount,
      'total_population': instance.totalPopulation,
      'total_housing': instance.totalHousing,
    };

ChurchLocation _$ChurchLocationFromJson(Map<String, dynamic> json) =>
    ChurchLocation(
      entityId: json['entity_id'] as String,
      entityName: json['entity_name'] as String,
      unionName: json['union_name'] as String?,
      conference: json['conference'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      territoryCount: (json['territory_count'] as num).toInt(),
      totalPopulation: (json['total_population'] as num).toInt(),
      totalHousing: (json['total_housing'] as num).toInt(),
    );

Map<String, dynamic> _$ChurchLocationToJson(ChurchLocation instance) =>
    <String, dynamic>{
      'entity_id': instance.entityId,
      'entity_name': instance.entityName,
      'union_name': instance.unionName,
      'conference': instance.conference,
      'address': instance.address,
      'city': instance.city,
      'state': instance.state,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'territory_count': instance.territoryCount,
      'total_population': instance.totalPopulation,
      'total_housing': instance.totalHousing,
    };
