import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';
import '../schedule/schedule_bloc.dart';

part 'worker_schedule_event.dart';
part 'worker_schedule_state.dart';

class WorkerScheduleBloc extends Bloc<WorkerScheduleEvent, WorkerScheduleState> {
  ApiClient? _apiClient;
  bool _isInitialized = false;
  Timer? _scheduleCheckTimer;

  WorkerScheduleBloc() : super(WorkerScheduleInitial()) {
    on<WorkerScheduleLoad>(_onLoad);
    on<WorkerScheduleLoadRange>(_onLoadRange);
    on<WorkerScheduleRefresh>(_onRefresh);
    on<WorkerScheduleStartSession>(_onStartSession);
    on<WorkerScheduleCompleteSession>(_onCompleteSession);
    on<WorkerScheduleCheckTime>(_onCheckTime);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _onLoad(WorkerScheduleLoad event, Emitter<WorkerScheduleState> emit) async {
    emit(WorkerScheduleLoading());

    try {
      await _initialize();

      final dateStr = _formatDate(event.date);
      final response = await _apiClient!.get(
        '/api/schedules/worker/me',
        queryParameters: {'date': dateStr},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['schedules'] ?? [];
        final schedules = data.map((json) => ScheduleEntry.fromJson(json)).toList();

        // Sort by start time
        schedules.sort((a, b) => a.startTime.compareTo(b.startTime));

        emit(WorkerScheduleLoaded(
          schedules: schedules,
          selectedDate: event.date,
        ));

        // Start timer to check for schedule time
        _startScheduleCheckTimer();
      } else {
        emit(WorkerScheduleLoaded(
          schedules: [],
          selectedDate: event.date,
        ));
      }
    } catch (e) {
      emit(WorkerScheduleError(message: e.toString()));
    }
  }

  Future<void> _onLoadRange(WorkerScheduleLoadRange event, Emitter<WorkerScheduleState> emit) async {
    emit(WorkerScheduleLoading());

    try {
      await _initialize();

      final response = await _apiClient!.get(
        '/api/schedules/worker/me',
        queryParameters: {
          'start_date': _formatDate(event.startDate),
          'end_date': _formatDate(event.endDate),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['schedules'] ?? [];
        final schedules = data.map((json) => ScheduleEntry.fromJson(json)).toList();

        // Sort by date and start time
        schedules.sort((a, b) {
          final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
          if (dateCompare != 0) return dateCompare;
          return a.startTime.compareTo(b.startTime);
        });

        emit(WorkerScheduleRangeLoaded(
          schedules: schedules,
          startDate: event.startDate,
          endDate: event.endDate,
        ));
      } else {
        emit(WorkerScheduleRangeLoaded(
          schedules: [],
          startDate: event.startDate,
          endDate: event.endDate,
        ));
      }
    } catch (e) {
      emit(WorkerScheduleError(message: e.toString()));
    }
  }

  Future<void> _onRefresh(WorkerScheduleRefresh event, Emitter<WorkerScheduleState> emit) async {
    final currentState = state;
    if (currentState is WorkerScheduleLoaded) {
      add(WorkerScheduleLoad(date: currentState.selectedDate));
    } else if (currentState is WorkerScheduleRangeLoaded) {
      add(WorkerScheduleLoadRange(
        startDate: currentState.startDate,
        endDate: currentState.endDate,
      ));
    } else {
      add(WorkerScheduleLoad(date: DateTime.now()));
    }
  }

  Future<void> _onStartSession(WorkerScheduleStartSession event, Emitter<WorkerScheduleState> emit) async {
    try {
      await _initialize();

      final response = await _apiClient!.post(
        '/api/schedules/${event.scheduleId}/start',
      );

      if (response.statusCode == 200) {
        // Refresh to get updated status
        add(const WorkerScheduleRefresh());
        emit(WorkerScheduleSessionStarted(scheduleId: event.scheduleId));
      }
    } catch (e) {
      emit(WorkerScheduleError(message: 'Failed to start session: ${e.toString()}'));
    }
  }

  Future<void> _onCompleteSession(WorkerScheduleCompleteSession event, Emitter<WorkerScheduleState> emit) async {
    try {
      await _initialize();

      final response = await _apiClient!.post(
        '/api/schedules/${event.scheduleId}/complete',
      );

      if (response.statusCode == 200) {
        // Refresh to get updated status
        add(const WorkerScheduleRefresh());
        emit(WorkerScheduleSessionCompleted(scheduleId: event.scheduleId));
      }
    } catch (e) {
      emit(WorkerScheduleError(message: 'Failed to complete session: ${e.toString()}'));
    }
  }

  void _startScheduleCheckTimer() {
    _scheduleCheckTimer?.cancel();
    _scheduleCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        // Check if bloc is still open before adding event
        if (!isClosed) {
          add(const WorkerScheduleCheckTime());
        }
      },
    );
  }

  Future<void> _onCheckTime(WorkerScheduleCheckTime event, Emitter<WorkerScheduleState> emit) async {
    final currentState = state;
    if (currentState is WorkerScheduleLoaded) {
      // Check if any schedule is about to start (within 5 minutes)
      final now = DateTime.now();
      for (final schedule in currentState.schedules) {
        if (schedule.status == 'scheduled') {
          final startTime = schedule.startDateTime;
          final diff = startTime.difference(now).inMinutes;
          if (diff >= 0 && diff <= 5) {
            emit(WorkerScheduleTimeToStart(schedule: schedule));
            return;
          }
        }
      }
    }
  }

  @override
  Future<void> close() {
    _scheduleCheckTimer?.cancel();
    return super.close();
  }
}
