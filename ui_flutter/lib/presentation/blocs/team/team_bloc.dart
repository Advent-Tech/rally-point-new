import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../core/network/api_result.dart';

part 'team_event.dart';
part 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  final TeamRepository _teamRepository;
  String? _currentTeamId;

  TeamBloc({TeamRepository? teamRepository})
      : _teamRepository = teamRepository ?? TeamRepository(),
        super(TeamInitial()) {
    on<TeamLoadMembers>(_onLoadMembers);
    on<TeamRefresh>(_onRefresh);
  }

  Future<void> _onLoadMembers(TeamLoadMembers event, Emitter<TeamState> emit) async {
    emit(TeamLoading());
    _currentTeamId = event.teamId;

    final result = await _teamRepository.getTeamMembers(event.teamId);

    result.when(
      success: (members) {
        emit(TeamMembersLoaded(
          members: members,
          teamId: event.teamId,
        ));
      },
      failure: (message, statusCode) {
        emit(TeamError(message: message));
      },
    );
  }

  Future<void> _onRefresh(TeamRefresh event, Emitter<TeamState> emit) async {
    if (_currentTeamId != null) {
      add(TeamLoadMembers(teamId: _currentTeamId!));
    }
  }
}
