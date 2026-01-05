part of 'territory_bloc.dart';

abstract class TerritoryState extends Equatable {
  const TerritoryState();

  @override
  List<Object?> get props => [];
}

class TerritoryInitial extends TerritoryState {}

class TerritoryLoading extends TerritoryState {}

class TerritorySearching extends TerritoryState {}

class TerritoryRequesting extends TerritoryState {}

class TerritoryAssignmentsLoaded extends TerritoryState {
  final List<TerritoryAssignment> assignments;
  final int activeCount;
  final int completedCount;
  final bool isOffline;

  const TerritoryAssignmentsLoaded({
    required this.assignments,
    this.activeCount = 0,
    this.completedCount = 0,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [assignments, activeCount, completedCount, isOffline];
}

class TerritoryAvailableLoaded extends TerritoryState {
  final List<GeoTerritory> territories;
  final bool hasMore;
  final int total;
  final int currentOffset;

  const TerritoryAvailableLoaded({
    required this.territories,
    this.hasMore = false,
    this.total = 0,
    this.currentOffset = 0,
  });

  @override
  List<Object?> get props => [territories, hasMore, total, currentOffset];
}

class TerritorySearchResults extends TerritoryState {
  final List<GeoTerritory> territories;
  final String query;
  final bool hasMore;
  final int total;

  const TerritorySearchResults({
    required this.territories,
    required this.query,
    this.hasMore = false,
    this.total = 0,
  });

  @override
  List<Object?> get props => [territories, query, hasMore, total];
}

class TerritoryNearbyLoaded extends TerritoryState {
  final List<GeoTerritory> territories;
  final double latitude;
  final double longitude;

  const TerritoryNearbyLoaded({
    required this.territories,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [territories, latitude, longitude];
}

class TerritoryUnionStatsLoaded extends TerritoryState {
  final List<UnionStats> stats;

  const TerritoryUnionStatsLoaded({required this.stats});

  @override
  List<Object?> get props => [stats];
}

class TerritoryChurchesLoaded extends TerritoryState {
  final List<ChurchLocation> churches;

  const TerritoryChurchesLoaded({required this.churches});

  @override
  List<Object?> get props => [churches];
}

class TerritoryRequestSuccess extends TerritoryState {
  final String message;

  const TerritoryRequestSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class TerritoryError extends TerritoryState {
  final String message;

  const TerritoryError({required this.message});

  @override
  List<Object?> get props => [message];
}

class TerritoryAssignSuccess extends TerritoryState {
  final String message;

  const TerritoryAssignSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
