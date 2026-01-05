import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/territory_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../../data/repositories/territory_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final TeamRepository _teamRepository;
  final TerritoryRepository _territoryRepository;
  ApiClient? _apiClient;
  String? _currentTeamId;
  bool _isInitialized = false;

  ScheduleBloc({
    TeamRepository? teamRepository,
    TerritoryRepository? territoryRepository,
  })  : _teamRepository = teamRepository ?? TeamRepository(),
        _territoryRepository = territoryRepository ?? TerritoryRepository(),
        super(ScheduleInitial()) {
    on<ScheduleLoadData>(_onLoadData);
    on<ScheduleRefresh>(_onRefresh);
    on<ScheduleSelectDate>(_onSelectDate);
    on<ScheduleCreate>(_onCreate);
    on<ScheduleUpdate>(_onUpdate);
    on<ScheduleDelete>(_onDelete);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  Future<void> _onLoadData(ScheduleLoadData event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    _currentTeamId = event.teamId;

    try {
      await _initialize();

      // Fetch workers and territories in parallel
      final results = await Future.wait([
        _teamRepository.getTeamMembers(event.teamId),
        _territoryRepository.getMyAssignments(teamId: event.teamId),
        _fetchSchedules(event.teamId, DateTime.now()),
      ]);

      final workersResult = results[0];
      final territoriesResult = results[1];
      final schedules = results[2] as List<ScheduleEntry>;

      List<TeamMember> workers = [];
      List<TerritoryAssignment> territories = [];

      // Handle workers result using pattern matching
      if (workersResult is ApiResult<List<TeamMember>>) {
        if (workersResult.isSuccess) {
          workers = workersResult.data ?? [];
        }
      }

      // Handle territories result using pattern matching
      if (territoriesResult is ApiResult<List<TerritoryAssignment>>) {
        if (territoriesResult.isSuccess) {
          territories = territoriesResult.data ?? [];
        }
      }

      emit(ScheduleLoaded(
        workers: workers,
        territories: territories,
        schedules: schedules,
        selectedDate: DateTime.now(),
        teamId: event.teamId,
      ));
    } catch (e) {
      emit(ScheduleError(message: e.toString()));
    }
  }

  Future<List<ScheduleEntry>> _fetchSchedules(String teamId, DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _apiClient!.get(
        '/api/schedules/team/$teamId',
        queryParameters: {'date': dateStr},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['schedules'] ?? [];
        return data.map((json) => ScheduleEntry.fromJson(json)).toList();
      }
    } catch (e) {
      // Return empty list on error - schedules table may not exist yet
    }
    return [];
  }

  Future<void> _onRefresh(ScheduleRefresh event, Emitter<ScheduleState> emit) async {
    if (_currentTeamId != null) {
      add(ScheduleLoadData(teamId: _currentTeamId!));
    }
  }

  Future<void> _onSelectDate(ScheduleSelectDate event, Emitter<ScheduleState> emit) async {
    final currentState = state;
    if (currentState is ScheduleLoaded) {
      emit(currentState.copyWith(selectedDate: event.date));

      // Fetch schedules for the new date
      try {
        final schedules = await _fetchSchedules(currentState.teamId, event.date);
        emit(currentState.copyWith(
          selectedDate: event.date,
          schedules: schedules,
        ));
      } catch (e) {
        // Keep current schedules on error
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onCreate(ScheduleCreate event, Emitter<ScheduleState> emit) async {
    final currentState = state;
    if (currentState is ScheduleLoaded) {
      try {
        await _initialize();

        debugPrint('ScheduleBloc: Creating schedule for worker ${event.workerId} on ${_formatDate(event.date)}');

        final response = await _apiClient!.post(
          '/api/schedules/',
          data: {
            'team_id': currentState.teamId,
            'worker_id': event.workerId,
            'worker_name': event.workerName,
            if (event.territoryId != null) 'territory_id': event.territoryId,
            if (event.territoryName != null) 'territory_name': event.territoryName,
            'date': _formatDate(event.date),
            'start_time': event.startTime,
            'end_time': event.endTime,
            if (event.notes != null) 'notes': event.notes,
          },
        );

        debugPrint('ScheduleBloc: Create response status: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final newSchedule = ScheduleEntry.fromJson(response.data);
          final updatedSchedules = [...currentState.schedules, newSchedule];
          emit(currentState.copyWith(schedules: updatedSchedules));
          debugPrint('ScheduleBloc: Schedule created successfully with ID: ${newSchedule.id}');
        } else {
          // API returned non-success status
          final errorMsg = response.data is Map ? response.data['error']?.toString() : 'Unknown error';
          debugPrint('ScheduleBloc: Failed to create schedule: $errorMsg');
          emit(ScheduleError(message: 'Failed to create schedule: $errorMsg'));
          // Restore previous state after showing error
          emit(currentState);
        }
      } catch (e) {
        // Log the actual error instead of silently creating local schedule
        debugPrint('ScheduleBloc: Error creating schedule: $e');
        emit(ScheduleError(message: 'Failed to create schedule: ${e.toString()}'));
        // Restore previous state after showing error
        emit(currentState);
      }
    }
  }

  Future<void> _onUpdate(ScheduleUpdate event, Emitter<ScheduleState> emit) async {
    final currentState = state;
    if (currentState is ScheduleLoaded) {
      try {
        await _initialize();

        await _apiClient!.put(
          '/api/schedules/${event.scheduleId}',
          data: {
            if (event.workerId != null) 'worker_id': event.workerId,
            if (event.workerName != null) 'worker_name': event.workerName,
            if (event.territoryId != null) 'territory_id': event.territoryId,
            if (event.territoryName != null) 'territory_name': event.territoryName,
            if (event.date != null) 'date': _formatDate(event.date!),
            if (event.startTime != null) 'start_time': event.startTime,
            if (event.endTime != null) 'end_time': event.endTime,
            if (event.status != null) 'status': event.status,
            if (event.notes != null) 'notes': event.notes,
          },
        );
      } catch (e) {
        // Continue with local update if API fails
      }

      // Update locally
      final updatedSchedules = currentState.schedules.map((schedule) {
        if (schedule.id == event.scheduleId) {
          return schedule.copyWith(
            workerId: event.workerId,
            workerName: event.workerName,
            territoryId: event.territoryId,
            territoryName: event.territoryName,
            scheduledDate: event.date,
            startTime: event.startTime,
            endTime: event.endTime,
            status: event.status,
            notes: event.notes,
          );
        }
        return schedule;
      }).toList();

      emit(currentState.copyWith(schedules: updatedSchedules));
    }
  }

  Future<void> _onDelete(ScheduleDelete event, Emitter<ScheduleState> emit) async {
    final currentState = state;
    if (currentState is ScheduleLoaded) {
      try {
        await _initialize();
        await _apiClient!.delete('/api/schedules/${event.scheduleId}');
      } catch (e) {
        // Continue with local delete if API fails
      }

      final updatedSchedules = currentState.schedules
          .where((schedule) => schedule.id != event.scheduleId)
          .toList();

      emit(currentState.copyWith(schedules: updatedSchedules));
    }
  }
}
