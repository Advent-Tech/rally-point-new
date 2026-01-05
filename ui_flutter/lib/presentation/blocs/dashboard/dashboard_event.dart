part of 'dashboard_bloc.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Load all dashboard stats for a team
class DashboardLoadStats extends DashboardEvent {
  final String teamId;

  const DashboardLoadStats({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}

/// Refresh dashboard data
class DashboardRefresh extends DashboardEvent {
  const DashboardRefresh();
}

/// Load team activity feed
class DashboardLoadActivity extends DashboardEvent {
  final String teamId;
  final int limit;
  final int offset;

  const DashboardLoadActivity({
    required this.teamId,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  List<Object?> get props => [teamId, limit, offset];
}
