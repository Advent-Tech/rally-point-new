import 'package:flutter/foundation.dart';
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
    on<TeamLoadJoinRequests>(_onLoadJoinRequests);
    on<TeamApproveJoinRequest>(_onApproveJoinRequest);
    on<TeamRejectJoinRequest>(_onRejectJoinRequest);
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

  /// Load join requests for a team (team leader only)
  Future<void> _onLoadJoinRequests(TeamLoadJoinRequests event, Emitter<TeamState> emit) async {
    emit(TeamLoading());
    _currentTeamId = event.teamId;

    final result = await _teamRepository.getJoinRequests(event.teamId, status: event.status);

    result.when(
      success: (requests) {
        debugPrint('TeamBloc: Loaded ${requests.length} join requests');
        emit(TeamJoinRequestsLoaded(
          requests: requests,
          teamId: event.teamId,
        ));
      },
      failure: (message, statusCode) {
        emit(TeamError(message: message));
      },
    );
  }

  /// Approve a join request
  Future<void> _onApproveJoinRequest(TeamApproveJoinRequest event, Emitter<TeamState> emit) async {
    emit(TeamLoading());

    final result = await _teamRepository.approveJoinRequest(event.requestId);

    result.when(
      success: (_) {
        debugPrint('TeamBloc: Successfully approved join request ${event.requestId}');
        emit(TeamJoinRequestActionSuccess(
          message: 'Worker approved successfully',
          teamId: event.teamId,
        ));
        // Reload join requests to refresh the list
        add(TeamLoadJoinRequests(teamId: event.teamId));
      },
      failure: (message, statusCode) {
        emit(TeamError(message: message));
      },
    );
  }

  /// Reject a join request
  Future<void> _onRejectJoinRequest(TeamRejectJoinRequest event, Emitter<TeamState> emit) async {
    emit(TeamLoading());

    final result = await _teamRepository.rejectJoinRequest(event.requestId, reason: event.reason);

    result.when(
      success: (_) {
        debugPrint('TeamBloc: Successfully rejected join request ${event.requestId}');
        emit(TeamJoinRequestActionSuccess(
          message: 'Join request rejected',
          teamId: event.teamId,
        ));
        // Reload join requests to refresh the list
        add(TeamLoadJoinRequests(teamId: event.teamId));
      },
      failure: (message, statusCode) {
        emit(TeamError(message: message));
      },
    );
  }
}
