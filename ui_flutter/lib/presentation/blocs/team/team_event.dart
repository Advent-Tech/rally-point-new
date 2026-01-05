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
