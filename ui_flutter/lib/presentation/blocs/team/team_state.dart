part of 'team_bloc.dart';

abstract class TeamState extends Equatable {
  const TeamState();

  @override
  List<Object?> get props => [];
}

class TeamInitial extends TeamState {}

class TeamLoading extends TeamState {}

class TeamMembersLoaded extends TeamState {
  final List<TeamMember> members;
  final String teamId;

  const TeamMembersLoaded({
    required this.members,
    required this.teamId,
  });

  @override
  List<Object?> get props => [members, teamId];

  /// Get only worker members (excludes team leaders and admins for assignment)
  List<TeamMember> get workers => members.where((m) => m.role == 'worker').toList();
}

class TeamError extends TeamState {
  final String message;

  const TeamError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State when join requests are loaded
class TeamJoinRequestsLoaded extends TeamState {
  final List<TeamJoinRequest> requests;
  final String teamId;

  const TeamJoinRequestsLoaded({
    required this.requests,
    required this.teamId,
  });

  @override
  List<Object?> get props => [requests, teamId];

  int get pendingCount => requests.where((r) => r.isPending).length;
}

/// State when a join request action (approve/reject) succeeds
class TeamJoinRequestActionSuccess extends TeamState {
  final String message;
  final String teamId;

  const TeamJoinRequestActionSuccess({
    required this.message,
    required this.teamId,
  });

  @override
  List<Object?> get props => [message, teamId];
}

/// State when an invitation is sent successfully
class TeamInvitationSent extends TeamState {
  final String message;
  final String email;
  final String teamId;

  const TeamInvitationSent({
    required this.message,
    required this.email,
    required this.teamId,
  });

  @override
  List<Object?> get props => [message, email, teamId];
}
