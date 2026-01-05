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
