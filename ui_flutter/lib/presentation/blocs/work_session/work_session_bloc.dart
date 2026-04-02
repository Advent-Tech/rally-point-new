import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../services/session_tracking_service.dart';

part 'work_session_event.dart';
part 'work_session_state.dart';

class WorkSessionBloc extends Bloc<WorkSessionEvent, WorkSessionState> {
  ApiClient? _apiClient;
  LocalStorage? _localStorage;
  SessionTrackingService? _trackingService;
  bool _isInitialized = false;
  bool _autoTrackingEnabled = false;
  WorkSession? _currentSession;

  WorkSessionBloc() : super(WorkSessionInitial()) {
    on<WorkSessionLoadCurrent>(_onLoadCurrent);
    on<WorkSessionCheckIn>(_onCheckIn);
    on<WorkSessionCheckOut>(_onCheckOut);
    on<WorkSessionLogVisit>(_onLogVisit);
    on<WorkSessionLoadHistory>(_onLoadHistory);
    on<WorkSessionToggleAutoTracking>(_onToggleAutoTracking);
    on<WorkSessionAutoCheckIn>(_onAutoCheckIn);
    on<WorkSessionAutoCheckOut>(_onAutoCheckOut);
    on<WorkSessionLocationUpdated>(_onLocationUpdated);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _localStorage = await LocalStorage.getInstance();
    _isInitialized = true;
  }

  ApiClient get _api => _apiClient!;

  /// Check if there's a current active session
  Future<void> _onLoadCurrent(
    WorkSessionLoadCurrent event,
    Emitter<WorkSessionState> emit,
  ) async {
    emit(WorkSessionLoading());

    try {
      await _initialize();

      // Get worker ID
      final userData = _localStorage?.getUserData();
      final workerId =
          userData?['id']?.toString() ?? userData?['user_id']?.toString();

      // Try to get current session from server first (source of truth)
      try {
        final response = await _api.get(
          '${ApiConstants.workerCurrentSession}/$workerId/session',
        );

        if (response.statusCode == 200 && response.data != null) {
          // Backend wraps session in {"session": {...}, "has_active": true}
          final sessionData = response.data['session'];
          if (sessionData == null) {
            // No active session
            await _localStorage?.clearCurrentWorkSession();
            emit(const WorkSessionInactive());
            return;
          }
          _currentSession = WorkSession.fromJson(sessionData);
          await _localStorage?.saveCurrentWorkSession(sessionData);

          if (_currentSession!.isActive) {
            _autoTrackingEnabled = true;
            _trackingService ??= await SessionTrackingService.getInstance();
            await _startTrackingService();
            final visits = await _fetchTodayVisits();
            emit(
              WorkSessionActive(session: _currentSession!, todayVisits: visits),
            );
            return;
          } else {
            // Session exists but not active - clear and show inactive
            await _localStorage?.clearCurrentWorkSession();
            emit(WorkSessionInactive(lastSession: _currentSession));
            return;
          }
        }
      } catch (serverError) {
        // Server request failed - will fall back to local storage below
      }

      // Fallback: Try local storage if server request failed
      final cachedSession = _localStorage?.getCurrentWorkSession();
      if (cachedSession != null) {
        _currentSession = WorkSession.fromJson(cachedSession);
        if (_currentSession!.isActive) {
          _autoTrackingEnabled = true;
          _trackingService ??= await SessionTrackingService.getInstance();
          await _startTrackingService();
          final visits = await _fetchTodayVisits();
          emit(
            WorkSessionActive(session: _currentSession!, todayVisits: visits),
          );
          return;
        }
      }

      // No active session found
      await _localStorage?.clearCurrentWorkSession();
      _currentSession = null;
      emit(const WorkSessionInactive());
    } catch (e) {
      // Clear any stale data and show inactive
      await _localStorage?.clearCurrentWorkSession();
      _currentSession = null;
      emit(const WorkSessionInactive());
    }
  }

  Future<void> _onCheckIn(
    WorkSessionCheckIn event,
    Emitter<WorkSessionState> emit,
  ) async {
    emit(WorkSessionLoading());

    try {
      await _initialize();

      // Get worker ID from local storage
      final userData = _localStorage?.getUserData();
      final workerId =
          userData?['id']?.toString() ?? userData?['user_id']?.toString();

      if (workerId == null || workerId.isEmpty) {
        emit(const WorkSessionError(message: 'User not authenticated'));
        return;
      }

      final response = await _api.post(
        '${ApiConstants.workSessions}/checkin',
        data: {
          'worker_id': workerId,
          'territory_id': event.territoryId,
          'territory_name': event.territoryName,
          if (event.latitude != null) 'latitude': event.latitude,
          if (event.longitude != null) 'longitude': event.longitude,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend wraps session in {"session": {...}, "message": "..."}
        final sessionData = response.data['session'] ?? response.data;
        _currentSession = WorkSession.fromJson(sessionData);
        await _localStorage?.saveCurrentWorkSession(sessionData);

        // Auto-start GPS tracking after check-in
        _autoTrackingEnabled = true;
        _trackingService ??= await SessionTrackingService.getInstance();
        await _startTrackingService();

        emit(WorkSessionActive(session: _currentSession!, todayVisits: []));
      } else {
        emit(WorkSessionError(message: 'Failed to check in'));
      }
    } catch (e) {
      emit(WorkSessionError(message: e.toString()));
    }
  }

  Future<void> _onCheckOut(
    WorkSessionCheckOut event,
    Emitter<WorkSessionState> emit,
  ) async {
    emit(WorkSessionLoading());

    try {
      await _initialize();

      // Get worker ID from local storage
      final userData = _localStorage?.getUserData();
      final workerId =
          userData?['id']?.toString() ?? userData?['user_id']?.toString();

      if (workerId == null || workerId.isEmpty) {
        emit(const WorkSessionError(message: 'User not authenticated'));
        return;
      }

      // Get session ID - try current session first, then local storage
      String? sessionId = _currentSession?.id;
      if (sessionId == null || sessionId.isEmpty) {
        final cachedSession = _localStorage?.getCurrentWorkSession();
        sessionId =
            cachedSession?['id']?.toString() ??
            cachedSession?['session_id']?.toString();
      }

      if (sessionId == null || sessionId.isEmpty) {
        // No session to end - just clear and go inactive
        await _localStorage?.clearCurrentWorkSession();
        _currentSession = null;
        emit(const WorkSessionInactive());
        return;
      }

      final response = await _api.post(
        '${ApiConstants.workSessions}/checkout',
        data: {
          'worker_id': workerId,
          'session_id': sessionId,
          if (event.notes != null) 'notes': event.notes,
        },
      );

      if (response.statusCode == 200) {
        // Backend wraps session in {"session": {...}, "message": "..."}
        final sessionData = response.data['session'] ?? response.data;
        final lastSession = WorkSession.fromJson(sessionData);
        await _trackingService?.stopTracking();
        _autoTrackingEnabled = false;
        _currentSession = null;
        await _localStorage?.clearCurrentWorkSession();

        emit(WorkSessionInactive(lastSession: lastSession));
      } else {
        emit(WorkSessionError(message: 'Failed to check out'));
      }
    } catch (e) {
      // If checkout fails, still clear local state
      _currentSession = null;
      await _localStorage?.clearCurrentWorkSession();
      emit(WorkSessionError(message: e.toString()));
    }
  }

  Future<void> _onLogVisit(
    WorkSessionLogVisit event,
    Emitter<WorkSessionState> emit,
  ) async {
    if (_currentSession == null) {
      emit(const WorkSessionError(message: 'Not checked in to any territory'));
      return;
    }

    try {
      await _initialize();

      final response = await _api.post(
        '${ApiConstants.assignmentVisit}/${_currentSession!.territoryId}/visit',
        data: {
          'session_id': _currentSession!.id,
          'address': event.address,
          'outcome': event.outcome,
          if (event.notes != null) 'notes': event.notes,
          if (event.latitude != null) 'latitude': event.latitude,
          if (event.longitude != null) 'longitude': event.longitude,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh today's visits
        final visits = await _fetchTodayVisits();
        emit(WorkSessionActive(session: _currentSession!, todayVisits: visits));
      } else {
        emit(const WorkSessionError(message: 'Failed to log visit'));
      }
    } catch (e) {
      emit(WorkSessionError(message: e.toString()));
    }
  }

  Future<List<VisitRecord>> _fetchTodayVisits() async {
    // Ensure we have a valid session with an ID
    if (_currentSession == null) return [];

    final sessionId = _currentSession!.id;
    if (sessionId.isEmpty) return [];

    try {
      // Correct endpoint: /api/geofence/sessions/{sessionId}/visits
      final response = await _api.get(
        '${ApiConstants.workSessions}/sessions/$sessionId/visits',
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['visits'] ?? []);
        return data
            .map<VisitRecord>((json) => VisitRecord.fromJson(json))
            .toList();
      }
    } catch (_) {
      // Silently handle errors - visits are not critical for session display
    }

    return [];
  }

  Future<void> _onLoadHistory(
    WorkSessionLoadHistory event,
    Emitter<WorkSessionState> emit,
  ) async {
    // For loading session history - can be expanded later
  }

  /// Toggle auto-tracking on/off
  Future<void> _onToggleAutoTracking(
    WorkSessionToggleAutoTracking event,
    Emitter<WorkSessionState> emit,
  ) async {
    debugPrint('[WorkSessionBloc] Toggle auto-tracking: ${event.enabled}');
    await _initialize();
    _trackingService ??= await SessionTrackingService.getInstance();
    debugPrint(
      '[WorkSessionBloc] Tracking service initialized: $_trackingService',
    );

    _autoTrackingEnabled = event.enabled;

    if (event.enabled) {
      await _startTrackingService();
    } else {
      await _trackingService!.stopTracking();
    }

    // Update current state with auto-tracking status
    final currentState = state;
    if (currentState is WorkSessionActive) {
      emit(currentState.copyWith(autoTrackingEnabled: event.enabled));
    } else if (currentState is WorkSessionInactive) {
      emit(currentState.copyWith(autoTrackingEnabled: event.enabled));
    }
  }

  /// Start the tracking service with all callbacks
  Future<void> _startTrackingService() async {
    if (_trackingService == null) return;
    if (_trackingService!.isTracking) return;

    debugPrint('[WorkSessionBloc] Starting tracking...');
    // Set up callbacks
    _trackingService!.onAutoSessionStarted = (sessionId, territory) {
      add(
        WorkSessionAutoCheckIn(
          territoryId: territory.territoryId,
          territoryName:
              territory.entityName ?? 'Territory ${territory.territorySolid}',
          latitude: _trackingService!.lastPosition?.latitude ?? 0,
          longitude: _trackingService!.lastPosition?.longitude ?? 0,
        ),
      );
    };

    _trackingService!.onAutoSessionEnded = (sessionId) {
      add(
        WorkSessionAutoCheckOut(
          latitude: _trackingService!.lastPosition?.latitude,
          longitude: _trackingService!.lastPosition?.longitude,
        ),
      );
    };

    _trackingService!.onLocationUpdated = (position) {
      add(
        WorkSessionLocationUpdated(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    };

    await _trackingService!.startTracking();
    debugPrint('[WorkSessionBloc] Tracking started');
  }

  /// Handle auto check-in from geofence
  Future<void> _onAutoCheckIn(
    WorkSessionAutoCheckIn event,
    Emitter<WorkSessionState> emit,
  ) async {
    // Don't show loading for auto check-in
    try {
      await _initialize();

      // Get worker ID from local storage
      final userData = _localStorage?.getUserData();
      final workerId =
          userData?['id']?.toString() ?? userData?['user_id']?.toString();

      if (workerId == null || workerId.isEmpty) {
        return; // Can't auto check-in without worker ID
      }

      final response = await _api.post(
        '${ApiConstants.workSessions}/checkin',
        data: {
          'worker_id': workerId,
          'territory_id': event.territoryId,
          'territory_name': event.territoryName,
          'latitude': event.latitude,
          'longitude': event.longitude,
          'auto_checkin': true,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend wraps session in {"session": {...}, "message": "..."}
        final sessionData = response.data['session'] ?? response.data;
        _currentSession = WorkSession.fromJson(sessionData);
        await _localStorage?.saveCurrentWorkSession(sessionData);

        emit(
          WorkSessionActive(
            session: _currentSession!,
            todayVisits: [],
            autoTrackingEnabled: _autoTrackingEnabled,
            currentLatitude: event.latitude,
            currentLongitude: event.longitude,
          ),
        );
      }
    } catch (e) {
      // Silent failure for auto check-in
    }
  }

  /// Handle auto check-out from geofence
  Future<void> _onAutoCheckOut(
    WorkSessionAutoCheckOut event,
    Emitter<WorkSessionState> emit,
  ) async {
    if (_currentSession == null) return;

    try {
      await _initialize();

      // Get worker ID from local storage
      final userData = _localStorage?.getUserData();
      final workerId =
          userData?['id']?.toString() ?? userData?['user_id']?.toString();

      if (workerId == null || workerId.isEmpty) {
        return; // Can't auto check-out without worker ID
      }

      final response = await _api.post(
        '${ApiConstants.workSessions}/checkout',
        data: {
          'worker_id': workerId,
          'session_id': _currentSession!.id,
          if (event.latitude != null) 'latitude': event.latitude,
          if (event.longitude != null) 'longitude': event.longitude,
          'auto_checkout': true,
        },
      );

      if (response.statusCode == 200) {
        // Backend wraps session in {"session": {...}, "message": "..."}
        final sessionData = response.data['session'] ?? response.data;
        final lastSession = WorkSession.fromJson(sessionData);
        _currentSession = null;
        await _localStorage?.clearCurrentWorkSession();

        emit(
          WorkSessionInactive(
            lastSession: lastSession,
            autoTrackingEnabled: _autoTrackingEnabled,
          ),
        );
      }
    } catch (e) {
      // Silent failure for auto check-out
    }
  }

  /// Handle location updates during session
  Future<void> _onLocationUpdated(
    WorkSessionLocationUpdated event,
    Emitter<WorkSessionState> emit,
  ) async {
    final currentState = state;
    if (currentState is WorkSessionActive) {
      emit(
        currentState.copyWith(
          currentLatitude: event.latitude,
          currentLongitude: event.longitude,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _trackingService?.stopTracking();
    return super.close();
  }
}
