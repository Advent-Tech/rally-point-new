part of 'territory_bloc.dart';

abstract class TerritoryEvent extends Equatable {
  const TerritoryEvent();

  @override
  List<Object?> get props => [];
}

class TerritoryLoadAssignments extends TerritoryEvent {
  const TerritoryLoadAssignments();
}

class TerritoryLoadAvailable extends TerritoryEvent {
  final int limit;
  final int offset;
  final String? unionName;
  final String? conference;
  final String? searchQuery;

  const TerritoryLoadAvailable({
    this.limit = 20,
    this.offset = 0,
    this.unionName,
    this.conference,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [limit, offset, unionName, conference, searchQuery];
}

class TerritorySearch extends TerritoryEvent {
  final String query;
  final int limit;
  final int offset;

  const TerritorySearch({
    required this.query,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [query, limit, offset];
}

class TerritoryRequestAssignment extends TerritoryEvent {
  final String territoryId;
  final String? notes;

  const TerritoryRequestAssignment({
    required this.territoryId,
    this.notes,
  });

  @override
  List<Object?> get props => [territoryId, notes];
}

class TerritoryLoadNearby extends TerritoryEvent {
  final double latitude;
  final double longitude;
  final double radiusKm;

  const TerritoryLoadNearby({
    required this.latitude,
    required this.longitude,
    this.radiusKm = 10,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusKm];
}

class TerritoryLoadUnionStats extends TerritoryEvent {
  const TerritoryLoadUnionStats();
}

class TerritoryLoadChurches extends TerritoryEvent {
  final String? unionName;

  const TerritoryLoadChurches({this.unionName});

  @override
  List<Object?> get props => [unionName];
}

class TerritoryRefresh extends TerritoryEvent {
  const TerritoryRefresh();
}

class TerritoryAssignToWorker extends TerritoryEvent {
  final String territoryId;
  final String territorySolid;
  final String workerId;
  final String teamId;
  final String assignedBy;
  final String priority;
  final String? notes;

  const TerritoryAssignToWorker({
    required this.territoryId,
    required this.territorySolid,
    required this.workerId,
    required this.teamId,
    required this.assignedBy,
    this.priority = 'medium',
    this.notes,
  });

  @override
  List<Object?> get props => [territoryId, territorySolid, workerId, teamId, assignedBy, priority, notes];
}
