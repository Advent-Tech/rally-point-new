import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/local_storage.dart';
import '../data/models/territory_model.dart';

/// Callback types for session tracking events
typedef OnTerritoryEntered =
    void Function(TerritoryAssignment territory, Position position);
typedef OnTerritoryExited =
    void Function(TerritoryAssignment territory, Position position);
typedef OnLocationUpdated = void Function(Position position);
typedef OnAutoSessionStarted =
    void Function(String sessionId, TerritoryAssignment territory);
typedef OnAutoSessionEnded = void Function(String sessionId);
typedef OnTrackingError = void Function(String error);

/// Service for automatic session tracking based on geofence entry/exit
class SessionTrackingService {
  static SessionTrackingService? _instance;

  ApiClient? _apiClient;
  LocalStorage? _localStorage;
  bool _isInitialized = false;
  bool _isTracking = false;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _geofenceCheckTimer;
  Timer? _positionWatchdogTimer;

  // Current state
  String? _userId;
  String? _teamId;
  TerritoryAssignment? _currentTerritory;
  String? _currentSessionId;
  Position? _lastPosition;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  DateTime? _lastPositionAt;
  List<TerritoryAssignment> _assignedTerritories = [];

  // Settings
  Duration _geofenceCheckInterval = const Duration(seconds: 60);
  bool _autoCheckIn = true;
  bool _autoCheckOut = true;
  Duration _minSendInterval = const Duration(seconds: 3);
  double _minSendDistanceMeters = 8;
  Duration _watchdogInterval = const Duration(seconds: 20);
  Duration _maxPositionSilence = const Duration(seconds: 75);

  // Callbacks
  OnTerritoryEntered? onTerritoryEntered;
  OnTerritoryExited? onTerritoryExited;
  OnLocationUpdated? onLocationUpdated;
  OnAutoSessionStarted? onAutoSessionStarted;
  OnAutoSessionEnded? onAutoSessionEnded;
  OnTrackingError? onTrackingError;

  SessionTrackingService._();

  factory SessionTrackingService() {
    _instance ??= SessionTrackingService._();
    return _instance!;
  }

  static Future<SessionTrackingService> getInstance() async {
    _instance ??= SessionTrackingService._();
    if (!_instance!._isInitialized) {
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _localStorage = await LocalStorage.getInstance();

    // Load user data
    final userData = _localStorage?.getUserData();
    debugPrint('[SessionTracking] User data loaded: $userData');
    if (userData != null) {
      _userId = userData['id']?.toString() ?? userData['user_id']?.toString();
      _teamId = userData['team_id']?.toString();
      debugPrint('[SessionTracking] Set userId=$_userId, teamId=$_teamId');
    }

    _isInitialized = true;

    // Load assigned territories
    await _loadAssignedTerritories();
  }

  /// Load territories assigned to the current user
  Future<void> _loadAssignedTerritories() async {
    try {
      final response = await _apiClient!.get(ApiConstants.myAssignments);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : (response.data['assignments'] ?? []);
        _assignedTerritories = data
            .map<TerritoryAssignment>(
              (json) => TerritoryAssignment.fromJson(json),
            )
            .where((a) => a.isActive)
            .toList();
        debugPrint(
          'SessionTracking: Loaded ${_assignedTerritories.length} active assignments',
        );
      }
    } catch (e) {
      debugPrint('SessionTracking: Error loading assignments: $e');
    }
  }

  /// Refresh assigned territories
  Future<void> refreshTerritories() async {
    await _loadAssignedTerritories();
  }

  /// Current tracking state
  bool get isTracking => _isTracking;
  TerritoryAssignment? get currentTerritory => _currentTerritory;
  String? get currentSessionId => _currentSessionId;
  Position? get lastPosition => _lastPosition;
  List<TerritoryAssignment> get assignedTerritories => _assignedTerritories;

  /// Configure tracking settings
  void configure({
    Duration? geofenceCheckInterval,
    bool? autoCheckIn,
    bool? autoCheckOut,
    Duration? minSendInterval,
    double? minSendDistanceMeters,
  }) {
    if (geofenceCheckInterval != null) {
      _geofenceCheckInterval = geofenceCheckInterval;
    }
    if (autoCheckIn != null) {
      _autoCheckIn = autoCheckIn;
    }
    if (autoCheckOut != null) {
      _autoCheckOut = autoCheckOut;
    }
    if (minSendInterval != null) {
      _minSendInterval = minSendInterval;
    }
    if (minSendDistanceMeters != null && minSendDistanceMeters >= 0) {
      _minSendDistanceMeters = minSendDistanceMeters;
    }
  }

  /// Start automatic tracking
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    try {
      debugPrint(
        '[SessionTracking] Starting tracking... userId=$_userId, teamId=$_teamId',
      );
      await _initialize();

      // Check location permissions
      final permission = await _checkLocationPermission();
      debugPrint('[SessionTracking] Location permission: $permission');
      if (!permission) {
        onTrackingError?.call('Location permission denied');
        return false;
      }

      // Start location updates
      await _startLocationUpdates();
      debugPrint('[SessionTracking] Location updates started');
      _lastPositionAt = DateTime.now().toUtc();
      _lastSentAt = null;
      _lastSentPosition = null;

      // Start geofence check timer
      _geofenceCheckTimer = Timer.periodic(_geofenceCheckInterval, (_) {
        _checkGeofence();
      });
      _positionWatchdogTimer = Timer.periodic(_watchdogInterval, (_) {
        _ensurePositionStreamHealthy();
      });

      _isTracking = true;
      debugPrint('[SessionTracking] Started tracking successfully');
      return true;
    } catch (e) {
      debugPrint('[SessionTracking] Error starting tracking: $e');
      onTrackingError?.call(e.toString());
      return false;
    }
  }

  /// Stop automatic tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    _geofenceCheckTimer?.cancel();
    _geofenceCheckTimer = null;
    _positionWatchdogTimer?.cancel();
    _positionWatchdogTimer = null;

    _isTracking = false;
    debugPrint('SessionTracking: Stopped tracking');
  }

  /// Check location permission
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Start location updates
  Future<void> _startLocationUpdates() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Minimum distance in meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _lastPosition = position;
            _lastPositionAt = DateTime.now().toUtc();
            onLocationUpdated?.call(position);
            _sendLocationUpdate(position);
          },
          onError: (error) {
            debugPrint('SessionTracking: Location error: $error');
            onTrackingError?.call(error.toString());
            unawaited(_restartLocationStream());
          },
          onDone: () {
            debugPrint('SessionTracking: Position stream closed; restarting');
            unawaited(_restartLocationStream());
          },
        );
  }

  Future<void> _restartLocationStream() async {
    if (!_isTracking) return;
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await _startLocationUpdates();
    } catch (e) {
      debugPrint('SessionTracking: Failed restarting stream: $e');
    }
  }

  Future<void> _ensurePositionStreamHealthy() async {
    if (!_isTracking) return;
    final now = DateTime.now().toUtc();
    final lastTick = _lastPositionAt;
    if (lastTick != null && now.difference(lastTick) <= _maxPositionSilence) {
      return;
    }

    debugPrint(
      'SessionTracking: No GPS updates for ${lastTick == null ? 'unknown' : now.difference(lastTick).inSeconds}s; repairing stream',
    );
    await _restartLocationStream();

    // Kick one immediate fix if stream is quiet due to platform throttling.
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _lastPosition = pos;
      _lastPositionAt = DateTime.now().toUtc();
      onLocationUpdated?.call(pos);
      await _sendLocationUpdate(pos);
    } catch (e) {
      debugPrint('SessionTracking: Watchdog currentPosition failed: $e');
    }
  }

  /// Send location update to server
  Future<void> _sendLocationUpdate(Position position) async {
    final now = DateTime.now().toUtc();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < _minSendInterval &&
        _lastSentPosition != null) {
      final moved = _distanceMeters(
        _lastSentPosition!.latitude,
        _lastSentPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved < _minSendDistanceMeters) {
        return;
      }
    }

    try {
      debugPrint(
        '[SessionTracking] Sending location: lat=${position.latitude}, lng=${position.longitude}, teamId=$_teamId, userId=$_userId',
      );

      // 1. Send to location service (stores in location_tracks table)
      final locationResponse = await _apiClient!.post(
        ApiConstants.locationUpdate,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'altitude': position.altitude,
          'speed': position.speed,
          'heading': position.heading,
          if (_currentSessionId != null) 'session_id': _currentSessionId,
          if (_teamId != null) 'team_id': _teamId,
        },
      );
      debugPrint(
        '[SessionTracking] Location update response: ${locationResponse.statusCode}',
      );

      // 2. Send to geofence service (triggers territory entry/exit detection)
      if (_userId != null) {
        final geofenceResponse = await _apiClient!.post(
          ApiConstants.geofenceLocationUpdate,
          data: {
            'worker_id': _userId,
            if (_teamId != null) 'team_id': _teamId,
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
        debugPrint(
          '[SessionTracking] Geofence update response: ${geofenceResponse.statusCode}',
        );
      }
      _lastSentAt = now;
      _lastSentPosition = position;
    } catch (e) {
      debugPrint('[SessionTracking] Error sending location: $e');
    }
  }

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Check geofence for territory entry/exit
  Future<void> _checkGeofence() async {
    if (_lastPosition == null) return;

    try {
      // Call server to check which territory the user is in
      final response = await _apiClient!.get(
        ApiConstants.geoTerritoriesAt,
        queryParameters: {
          'lat': _lastPosition!.latitude,
          'lng': _lastPosition!.longitude,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final territoryId = data['territory_id']?.toString();
        final territorySolid = data['solid']?.toString();

        if (territoryId != null && territorySolid != null) {
          // User is inside a territory
          await _handleInsideTerritory(territoryId, territorySolid);
        } else {
          // User is outside all territories
          await _handleOutsideTerritory();
        }
      }
    } catch (e) {
      debugPrint('SessionTracking: Geofence check error: $e');
    }
  }

  /// Handle when user is inside a territory
  Future<void> _handleInsideTerritory(
    String territoryId,
    String territorySolid,
  ) async {
    // Find if this is an assigned territory
    final assignment = _assignedTerritories.firstWhere(
      (a) => a.territoryId == territoryId || a.territorySolid == territorySolid,
      orElse: () => TerritoryAssignment(
        id: '',
        territoryId: territoryId,
        territorySolid: territorySolid,
        teamId: '',
        assignedBy: '',
        assignedAt: DateTime.now(),
        status: 'unknown',
        priority: 'normal',
      ),
    );

    if (assignment.id.isEmpty) {
      // Not an assigned territory, ignore
      return;
    }

    // Check if we already have a session for this territory
    if (_currentTerritory?.territoryId == territoryId) {
      return; // Already tracking this territory
    }

    // If we're in a different territory, handle exit first
    if (_currentTerritory != null &&
        _currentTerritory!.territoryId != territoryId) {
      await _handleTerritoryExit();
    }

    // Handle entry into new territory
    _currentTerritory = assignment;
    onTerritoryEntered?.call(assignment, _lastPosition!);

    if (_autoCheckIn) {
      await _autoCheckInToTerritory(assignment);
    }
  }

  /// Handle when user exits all territories
  Future<void> _handleOutsideTerritory() async {
    if (_currentTerritory == null) return;

    await _handleTerritoryExit();
  }

  /// Handle territory exit
  Future<void> _handleTerritoryExit() async {
    if (_currentTerritory == null) return;

    final exitedTerritory = _currentTerritory!;
    onTerritoryExited?.call(exitedTerritory, _lastPosition!);

    if (_autoCheckOut && _currentSessionId != null) {
      await _autoCheckOutFromTerritory();
    }

    _currentTerritory = null;
  }

  /// Auto check-in to a territory
  Future<void> _autoCheckInToTerritory(TerritoryAssignment territory) async {
    try {
      // Get fresh position if not available
      Position? position = _lastPosition;
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          _lastPosition = position;
        } catch (e) {
          debugPrint('SessionTracking: Could not get position for checkin: $e');
        }
      }

      final response = await _apiClient!.post(
        '${ApiConstants.workSessions}/checkin',
        data: {
          'worker_id': _userId,
          'territory_id': territory.territoryId,
          'territory_name':
              territory.entityName ?? 'Territory ${territory.territorySolid}',
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          'auto_checkin': true,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentSessionId =
            response.data['id']?.toString() ??
            response.data['session']?['id']?.toString();
        await _localStorage?.saveCurrentWorkSession(response.data);
        onAutoSessionStarted?.call(_currentSessionId!, territory);
        debugPrint(
          'SessionTracking: Auto check-in successful, session: $_currentSessionId',
        );
      }
    } catch (e) {
      debugPrint('SessionTracking: Auto check-in error: $e');
      onTrackingError?.call('Auto check-in failed: $e');
    }
  }

  /// Auto check-out from current territory
  Future<void> _autoCheckOutFromTerritory() async {
    if (_currentSessionId == null) return;

    try {
      // Get fresh position for checkout
      Position? position = _lastPosition;
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          debugPrint(
            'SessionTracking: Could not get position for checkout: $e',
          );
        }
      }

      final response = await _apiClient!.post(
        '${ApiConstants.workSessions}/checkout',
        data: {
          'worker_id': _userId,
          'session_id': _currentSessionId,
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          'auto_checkout': true,
        },
      );

      if (response.statusCode == 200) {
        final sessionId = _currentSessionId!;
        _currentSessionId = null;
        await _localStorage?.clearCurrentWorkSession();
        onAutoSessionEnded?.call(sessionId);
        debugPrint('SessionTracking: Auto check-out successful');
      }
    } catch (e) {
      debugPrint('SessionTracking: Auto check-out error: $e');
      onTrackingError?.call('Auto check-out failed: $e');
    }
  }

  /// Manually start a session (bypass auto-tracking)
  Future<String?> manualCheckIn(TerritoryAssignment territory) async {
    await _initialize();

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _lastPosition = position;
      } catch (e) {
        debugPrint('SessionTracking: Could not get position: $e');
      }

      final response = await _apiClient!.post(
        '${ApiConstants.workSessions}/checkin',
        data: {
          'worker_id': _userId,
          'territory_id': territory.territoryId,
          'territory_name':
              territory.entityName ?? 'Territory ${territory.territorySolid}',
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          'auto_checkin': false,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentSessionId =
            response.data['id']?.toString() ??
            response.data['session']?['id']?.toString();
        _currentTerritory = territory;
        await _localStorage?.saveCurrentWorkSession(response.data);
        return _currentSessionId;
      }
    } catch (e) {
      debugPrint('SessionTracking: Manual check-in error: $e');
    }
    return null;
  }

  /// Manually end current session
  Future<bool> manualCheckOut({String? notes}) async {
    if (_currentSessionId == null) return false;

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        _lastPosition = position;
      } catch (e) {
        debugPrint('SessionTracking: Could not get position: $e');
      }

      final response = await _apiClient!.post(
        '${ApiConstants.workSessions}/checkout',
        data: {
          'worker_id': _userId,
          'session_id': _currentSessionId,
          if (position != null) 'latitude': position.latitude,
          if (position != null) 'longitude': position.longitude,
          if (notes != null) 'notes': notes,
          'auto_checkout': false,
        },
      );

      if (response.statusCode == 200) {
        _currentSessionId = null;
        _currentTerritory = null;
        await _localStorage?.clearCurrentWorkSession();
        return true;
      }
    } catch (e) {
      debugPrint('SessionTracking: Manual check-out error: $e');
    }
    return false;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('SessionTracking: Error getting position: $e');
      return null;
    }
  }

  /// Dispose service
  void dispose() {
    stopTracking();
    _instance = null;
  }
}
