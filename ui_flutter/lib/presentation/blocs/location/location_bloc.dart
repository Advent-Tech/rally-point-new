import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/models/location_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  late final ApiClient _apiClient;
  late final LocalStorage _localStorage;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _uploadTimer;
  List<LocationUpdate> _pendingUpdates = [];
  String? _currentSessionId;
  String? _teamId;

  LocationBloc() : super(LocationInitial()) {
    on<LocationCheckPermission>(_onCheckPermission);
    on<LocationRequestPermission>(_onRequestPermission);
    on<LocationStartTracking>(_onStartTracking);
    on<LocationStopTracking>(_onStopTracking);
    on<LocationUpdatePosition>(_onUpdatePosition);
    on<LocationLoadSessions>(_onLoadSessions);
    on<LocationLoadStats>(_onLoadStats);
    on<LocationLoadNearbyWorkers>(_onLoadNearbyWorkers);
    on<LocationSyncPending>(_onSyncPending);
  }

  Future<void> _initialize() async {
    _apiClient = await ApiClient.getInstance();
    _localStorage = await LocalStorage.getInstance();

    // Load team_id from user data
    final userData = _localStorage.getUserData();
    if (userData != null) {
      _teamId = userData['team_id']?.toString();
      debugPrint('[LocationBloc] Loaded team_id: $_teamId');
    }
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    _uploadTimer?.cancel();
    return super.close();
  }

  Future<void> _onCheckPermission(
    LocationCheckPermission event,
    Emitter<LocationState> emit,
  ) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      emit(
        LocationPermissionDenied(
          message: 'Location services are disabled',
          canRequestAgain: false,
        ),
      );
      return;
    }

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        emit(
          LocationPermissionDenied(
            message: 'Location permission is required for tracking',
            canRequestAgain: true,
          ),
        );
        break;
      case LocationPermission.deniedForever:
        emit(
          LocationPermissionDenied(
            message:
                'Location permission is permanently denied. Please enable it in settings.',
            canRequestAgain: false,
          ),
        );
        break;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        emit(LocationPermissionGranted());
        break;
      case LocationPermission.unableToDetermine:
        emit(
          LocationPermissionDenied(
            message: 'Unable to determine location permission status',
            canRequestAgain: true,
          ),
        );
        break;
    }
  }

  Future<void> _onRequestPermission(
    LocationRequestPermission event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      emit(
        LocationPermissionDenied(
          message: 'Please enable location services',
          canRequestAgain: false,
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      emit(
        LocationPermissionDenied(
          message: 'Location permission denied',
          canRequestAgain: true,
        ),
      );
    } else if (permission == LocationPermission.deniedForever) {
      emit(
        LocationPermissionDenied(
          message:
              'Location permission permanently denied. Please enable in settings.',
          canRequestAgain: false,
        ),
      );
    } else {
      emit(LocationPermissionGranted());
    }
  }

  Future<void> _onStartTracking(
    LocationStartTracking event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    try {
      await _initialize();

      // Get current position first
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Start session on server
      final response = await _apiClient.post(
        ApiConstants.sessionsStart,
        data: {'start_lat': position.latitude, 'start_lng': position.longitude},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentSessionId = response.data['id'] ?? response.data['session_id'];

        emit(
          LocationTracking(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            speed: position.speed,
            heading: position.heading,
            altitude: position.altitude,
            sessionId: _currentSessionId,
            startTime: DateTime.now(),
            distance: 0,
            duration: Duration.zero,
          ),
        );

        // Start listening to position updates
        _positionSubscription =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 10,
              ),
            ).listen((position) {
              add(
                LocationUpdatePosition(
                  latitude: position.latitude,
                  longitude: position.longitude,
                  accuracy: position.accuracy,
                  speed: position.speed,
                  heading: position.heading,
                  altitude: position.altitude,
                ),
              );
            });

        // Start upload timer with jitter to prevent thundering herd
        _startJitteredUploadTimer();
      } else {
        emit(LocationError(message: 'Failed to start tracking session'));
      }
    } catch (e) {
      emit(LocationError(message: e.toString()));
    }
  }

  Future<void> _onStopTracking(
    LocationStopTracking event,
    Emitter<LocationState> emit,
  ) async {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;

    try {
      await _initialize();

      // Sync any pending updates
      if (_pendingUpdates.isNotEmpty) {
        await _uploadPendingUpdates();
      }

      // End session on server
      if (_currentSessionId != null) {
        final position = await Geolocator.getCurrentPosition();

        await _apiClient.put(
          '${ApiConstants.locationSessions}/$_currentSessionId/end',
          data: {'end_lat': position.latitude, 'end_lng': position.longitude},
        );
      }

      _currentSessionId = null;
      emit(LocationStopped());
    } catch (e) {
      // Still stop tracking locally even if server fails
      _currentSessionId = null;
      emit(LocationStopped());
    }
  }

  void _startJitteredUploadTimer() {
    // Random interval between 25-35 seconds to spread load across users
    final jitter = 25 + Random().nextInt(11);
    _uploadTimer = Timer(Duration(seconds: jitter), () {
      add(const LocationSyncPending());
      _startJitteredUploadTimer();
    });
  }

  Future<void> _onUpdatePosition(
    LocationUpdatePosition event,
    Emitter<LocationState> emit,
  ) async {
    final currentState = state;
    if (currentState is LocationTracking) {
      // Calculate distance
      final newDistance = Geolocator.distanceBetween(
        currentState.latitude,
        currentState.longitude,
        event.latitude,
        event.longitude,
      );

      final totalDistance = currentState.distance + newDistance;
      final duration = DateTime.now().difference(currentState.startTime);

      // Add to pending updates
      _pendingUpdates.add(
        LocationUpdate(
          latitude: event.latitude,
          longitude: event.longitude,
          accuracy: event.accuracy,
          speed: event.speed,
          heading: event.heading,
          altitude: event.altitude,
          sessionId: _currentSessionId,
          teamId: _teamId,
        ),
      );

      emit(
        LocationTracking(
          latitude: event.latitude,
          longitude: event.longitude,
          accuracy: event.accuracy,
          speed: event.speed,
          heading: event.heading,
          altitude: event.altitude,
          sessionId: _currentSessionId,
          startTime: currentState.startTime,
          distance: totalDistance,
          duration: duration,
        ),
      );
    }
  }

  Future<void> _onLoadSessions(
    LocationLoadSessions event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());

    try {
      await _initialize();

      final response = await _apiClient.get(
        ApiConstants.locationSessions,
        queryParameters: {'limit': event.limit, 'offset': event.offset},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['sessions'] ?? [];
        final sessions = data
            .map((json) => LocationSession.fromJson(json))
            .toList();

        // Cache for offline
        await _localStorage.saveLocationSessions(data);

        emit(
          LocationSessionsLoaded(
            sessions: sessions,
            hasMore: sessions.length == event.limit,
          ),
        );
      } else {
        emit(LocationError(message: 'Failed to load sessions'));
      }
    } catch (e) {
      // Try loading from cache
      final cached = _localStorage.getLocationSessions();
      if (cached != null && cached.isNotEmpty) {
        final sessions = cached
            .map((json) => LocationSession.fromJson(json))
            .toList();
        emit(
          LocationSessionsLoaded(
            sessions: sessions,
            hasMore: false,
            isOffline: true,
          ),
        );
      } else {
        emit(LocationError(message: e.toString()));
      }
    }
  }

  Future<void> _onLoadStats(
    LocationLoadStats event,
    Emitter<LocationState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _apiClient.get(ApiConstants.locationStats);

      if (response.statusCode == 200) {
        final stats = LocationStats.fromJson(response.data);
        emit(LocationStatsLoaded(stats: stats));
      }
    } catch (e) {
      // Silent fail - stats are not critical
    }
  }

  Future<void> _onLoadNearbyWorkers(
    LocationLoadNearbyWorkers event,
    Emitter<LocationState> emit,
  ) async {
    try {
      await _initialize();

      final response = await _apiClient.get(
        ApiConstants.workersNearby,
        queryParameters: {
          'lat': event.latitude,
          'lng': event.longitude,
          'radius': event.radiusKm,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['workers'] ?? [];
        final workers = data
            .map((json) => WorkerLocation.fromJson(json))
            .toList();

        emit(LocationNearbyWorkersLoaded(workers: workers));
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _onSyncPending(
    LocationSyncPending event,
    Emitter<LocationState> emit,
  ) async {
    if (_pendingUpdates.isEmpty) return;

    try {
      await _uploadPendingUpdates();
    } catch (e) {
      // Save to local storage for later sync
      final pendingJson = _pendingUpdates.map((u) => u.toJson()).toList();
      await _localStorage.savePendingLocationUpdates(pendingJson);
    }
  }

  Future<void> _uploadPendingUpdates() async {
    if (_pendingUpdates.isEmpty) return;

    final updates = List<LocationUpdate>.from(_pendingUpdates);
    _pendingUpdates.clear();

    debugPrint('[LocationBloc] Uploading ${updates.length} location updates');

    // Send each update individually since /api/location/batch doesn't exist
    for (final update in updates) {
      try {
        debugPrint(
          '[LocationBloc] Sending location: lat=${update.latitude}, lng=${update.longitude}',
        );
        await _apiClient.post(
          ApiConstants.locationUpdate,
          data: update.toJson(),
        );
        debugPrint('[LocationBloc] Location sent successfully');
      } catch (e) {
        debugPrint('[LocationBloc] Error sending location: $e');
        // If one fails, continue with the rest
      }
    }
  }
}
