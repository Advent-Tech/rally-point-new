part of 'team_map_bloc.dart';

abstract class TeamMapEvent extends Equatable {
  const TeamMapEvent();

  @override
  List<Object?> get props => [];
}

class TeamMapLoad extends TeamMapEvent {
  final String teamId;

  const TeamMapLoad({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}

class TeamMapRefresh extends TeamMapEvent {
  const TeamMapRefresh();
}

/// Lightweight refresh that only updates dynamic data (workers, deliveries, receipts, donations)
/// without reloading static data (territory boundaries)
class TeamMapRefreshMarkers extends TeamMapEvent {
  const TeamMapRefreshMarkers();
}

class TeamMapUpdateFilters extends TeamMapEvent {
  final bool? showWorkers;
  final bool? showDeliveries;
  final bool? showReceipts;
  final bool? showDonations;
  final bool? showTerritories;

  const TeamMapUpdateFilters({
    this.showWorkers,
    this.showDeliveries,
    this.showReceipts,
    this.showDonations,
    this.showTerritories,
  });

  @override
  List<Object?> get props => [showWorkers, showDeliveries, showReceipts, showDonations, showTerritories];
}
