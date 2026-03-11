import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/api_client.dart';

part 'worker_tracking_event.dart';
part 'worker_tracking_state.dart';

class WorkerTrackingBloc
    extends Bloc<WorkerTrackingEvent, WorkerTrackingState> {
  ApiClient? _apiClient;
  bool _isInitialized = false;
  String? _currentTeamId;
  String? _currentWorkerId;
  String? _currentWorkerName;

  WorkerTrackingBloc() : super(WorkerTrackingInitial()) {
    on<WorkerTrackingLoadWorkers>(_onLoadWorkers);
    on<WorkerTrackingLoadTrail>(_onLoadTrail);
    on<WorkerTrackingChangeDate>(_onChangeDate);
    on<WorkerTrackingRefreshWorkers>(_onRefreshWorkers);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _isInitialized = true;
  }

  Future<void> _onLoadWorkers(
    WorkerTrackingLoadWorkers event,
    Emitter<WorkerTrackingState> emit,
  ) async {
    debugPrint('WorkerTrackingBloc: Loading workers for team ${event.teamId}');
    emit(WorkerTrackingLoading());
    _currentTeamId = event.teamId;

    try {
      await _initialize();

      // First, try to get live worker locations from Redis cache (immediate)
      // This returns real-time positions of active workers
      List<Map<String, dynamic>> liveWorkerData = [];
      try {
        final liveResponse = await _apiClient!.get(
          '/api/locations/workers/team?team_id=${event.teamId}',
        );
        if (liveResponse.statusCode == 200 &&
            liveResponse.data['workers'] != null) {
          liveWorkerData = List<Map<String, dynamic>>.from(
            liveResponse.data['workers'] ?? [],
          );
          debugPrint(
            'WorkerTrackingBloc: Loaded ${liveWorkerData.length} live worker locations',
          );
        }
      } catch (e) {
        debugPrint('WorkerTrackingBloc: Live locations fetch failed: $e');
      }

      // Fetch active workers from geofence (work sessions with territory info)
      final response = await _apiClient!.get(
        '/api/geofence/teams/${event.teamId}/workers/active',
      );

      if (response.statusCode != 200) {
        emit(const WorkerTrackingError(message: 'Failed to load workers'));
        return;
      }

      final List<dynamic> data = response.data is List
          ? response.data
          : response.data['active_sessions'] ?? response.data['workers'] ?? [];

      // Parse workers first, then fetch stats in parallel
      final workerJsonList = data.cast<Map<String, dynamic>>();

      // Fetch today's stats for each worker in parallel
      final statsFutures = workerJsonList.map((json) {
        final workerId =
            json['worker_id']?.toString() ?? json['id']?.toString() ?? '';
        return _fetchWorkerStats(workerId, days: 1);
      }).toList();

      final statsResults = await Future.wait(statsFutures);

      final workers = <TrackedWorker>[];
      for (int i = 0; i < workerJsonList.length; i++) {
        final stats = statsResults[i];
        final json = workerJsonList[i];

        // Try to get live location from Redis data
        final workerId =
            json['worker_id']?.toString() ?? json['id']?.toString() ?? '';
        final liveData = liveWorkerData.firstWhere(
          (w) => w['user_id']?.toString() == workerId,
          orElse: () => <String, dynamic>{},
        );

        // Merge live location into worker data if available
        if (liveData.isNotEmpty &&
            liveData['latitude'] != null &&
            liveData['longitude'] != null) {
          json['latitude'] = liveData['latitude'];
          json['longitude'] = liveData['longitude'];
        }

        workers.add(
          TrackedWorker.fromJson(
            json,
            distanceKm: stats?['total_distance_km']?.toDouble(),
            hours: stats?['total_hours']?.toDouble(),
          ),
        );
      }

      debugPrint(
        'WorkerTrackingBloc: Loaded ${workers.length} workers with stats',
      );

      emit(WorkerTrackingWorkersLoaded(workers: workers, teamId: event.teamId));
    } catch (e) {
      debugPrint('WorkerTrackingBloc: Error loading workers: $e');
      emit(WorkerTrackingError(message: e.toString()));
    }
  }

  Future<void> _onLoadTrail(
    WorkerTrackingLoadTrail event,
    Emitter<WorkerTrackingState> emit,
  ) async {
    debugPrint(
      'WorkerTrackingBloc: Loading trail for worker ${event.workerId}',
    );
    emit(WorkerTrackingTrailLoading());
    _currentWorkerId = event.workerId;
    _currentWorkerName = event.workerName;

    try {
      await _initialize();

      final now = DateTime.now();
      final startTime =
          event.startTime ?? DateTime(now.year, now.month, now.day);
      final endTime =
          event.endTime ?? DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Fetch trail and stats in parallel
      final results = await Future.wait([
        _fetchPathHistory(event.workerId, startTime, endTime),
        _fetchWorkerStats(event.workerId, days: 1),
      ]);

      final trailPoints = results[0] as List<TrailPoint>;
      final statsJson = results[1] as Map<String, dynamic>?;
      final stats = statsJson != null
          ? WorkerTrailStats.fromJson(statsJson)
          : const WorkerTrailStats();

      debugPrint(
        'WorkerTrackingBloc: Loaded ${trailPoints.length} trail points',
      );

      emit(
        WorkerTrackingTrailLoaded(
          trailPoints: trailPoints,
          stats: stats,
          workerId: event.workerId,
          workerName: event.workerName,
          selectedDate: startTime,
        ),
      );
    } catch (e) {
      debugPrint('WorkerTrackingBloc: Error loading trail: $e');
      emit(WorkerTrackingError(message: e.toString()));
    }
  }

  Future<void> _onChangeDate(
    WorkerTrackingChangeDate event,
    Emitter<WorkerTrackingState> emit,
  ) async {
    if (_currentWorkerId == null || _currentWorkerName == null) return;

    final startTime = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final endTime = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      23,
      59,
      59,
    );

    add(
      WorkerTrackingLoadTrail(
        workerId: _currentWorkerId!,
        workerName: _currentWorkerName!,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  Future<void> _onRefreshWorkers(
    WorkerTrackingRefreshWorkers event,
    Emitter<WorkerTrackingState> emit,
  ) async {
    if (_currentTeamId == null) return;
    final currentState = state;
    if (currentState is! WorkerTrackingWorkersLoaded) return;

    try {
      await _initialize();

      final response = await _apiClient!.get(
        '/api/geofence/teams/$_currentTeamId/workers/active',
      );

      if (response.statusCode != 200) return;

      final List<dynamic> data = response.data is List
          ? response.data
          : response.data['active_sessions'] ?? response.data['workers'] ?? [];

      final workerJsonList = data.cast<Map<String, dynamic>>();

      final statsFutures = workerJsonList.map((json) {
        final workerId =
            json['worker_id']?.toString() ?? json['id']?.toString() ?? '';
        return _fetchWorkerStats(workerId, days: 1);
      }).toList();

      final statsResults = await Future.wait(statsFutures);

      final workers = <TrackedWorker>[];
      for (int i = 0; i < workerJsonList.length; i++) {
        final json = workerJsonList[i];
        final stats = statsResults[i];
        final worker = TrackedWorker.fromJson(
          json,
          distanceKm: stats?['total_distance_km']?.toDouble(),
          hours: stats?['total_hours']?.toDouble(),
        );
        debugPrint(
          '[WorkerTrackingBloc] Worker: ${worker.name}, lat=${worker.latitude}, lng=${worker.longitude}',
        );
        workers.add(worker);
      }

      emit(
        WorkerTrackingWorkersLoaded(workers: workers, teamId: _currentTeamId!),
      );
    } catch (e) {
      // On error, keep existing state
      debugPrint('WorkerTrackingBloc: Refresh error: $e');
    }
  }

  Future<List<TrailPoint>> _fetchPathHistory(
    String workerId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final response = await _apiClient!.get(
        '/api/workers/$workerId/path-history',
        queryParameters: {
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> points = response.data['path_points'] ?? [];
        return points
            .map((json) => TrailPoint.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('WorkerTrackingBloc: Error fetching path history: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> _fetchWorkerStats(
    String workerId, {
    int days = 1,
  }) async {
    try {
      final response = await _apiClient!.get(
        '/api/workers/$workerId/location-stats',
        queryParameters: {'days': days},
      );

      if (response.statusCode == 200) {
        return response.data is Map<String, dynamic> ? response.data : null;
      }
    } catch (e) {
      debugPrint('WorkerTrackingBloc: Error fetching stats for $workerId: $e');
    }
    return null;
  }
}
