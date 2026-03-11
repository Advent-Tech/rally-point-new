part of 'team_bloc.dart';

abstract class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

class TeamLoadMembers extends TeamEvent {
  final String teamId;

  const TeamLoadMembers({required this.teamId});

  @override
  List<Object?> get props => [teamId];
}

class TeamRefresh extends TeamEvent {
  const TeamRefresh();
}

/// Load join requests for a team (team leader only)
class TeamLoadJoinRequests extends TeamEvent {
  final String teamId;
  final String? status;

  const TeamLoadJoinRequests({required this.teamId, this.status = 'pending'});

  @override
  List<Object?> get props => [teamId, status];
}

/// Approve a worker's join request
class TeamApproveJoinRequest extends TeamEvent {
  final String requestId;
  final String teamId;

  const TeamApproveJoinRequest({required this.requestId, required this.teamId});

  @override
  List<Object?> get props => [requestId, teamId];
}

/// Reject a worker's join request
class TeamRejectJoinRequest extends TeamEvent {
  final String requestId;
  final String teamId;
  final String? reason;

  const TeamRejectJoinRequest({
    required this.requestId,
    required this.teamId,
    this.reason,
  });

  @override
  List<Object?> get props => [requestId, teamId, reason];
}

/// Send an invitation to join a team
class TeamSendInvitation extends TeamEvent {
  final String teamId;
  final String email;

  const TeamSendInvitation({required this.teamId, required this.email});

  @override
  List<Object?> get props => [teamId, email];
}
