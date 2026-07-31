import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/prayer_request_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/territory_model.dart';
import 'command_center_event.dart';
import 'command_center_state.dart';
import 'services/road_snap_service.dart';

class CommandCenterBloc extends Bloc<CommandCenterEvent, CommandCenterState> {
  final ApiClient _apiClient;
  final SecureStorage _storage;
  final RoadSnapService _roadSnapService;

  // Client-side EMA smoothing for live worker dots (alpha=0.3: responsive but smooth)
  final Map<String, Position> _emaPositions = {};
  static const double _emaAlpha = 0.3;

  // Road snapping state per worker
  final Map<String, List<Position>> _positionRingBuffers = {};
  final Map<String, DateTime> _lastSnapTimes = {};
  final Map<String, Position> _snappedPositions = {};
  static const int _ringBufferSize = 5;
  static const Duration _snapRateLimit = Duration(seconds: 3);

  CommandCenterBloc({
    required ApiClient apiClient,
    required SecureStorage storage,
    RoadSnapService? roadSnapService,
  }) : _apiClient = apiClient,
       _storage = storage,
       _roadSnapService = roadSnapService ?? RoadSnapService(),
       super(const CommandCenterState()) {
    on<InitializeEvent>(_onInitialize);
    on<ChangeMapModeEvent>(_onChangeMapMode);
    on<RefreshDataEvent>(_onRefreshData);
    on<UpdateLiveLocationEvent>(_onUpdateLiveLocation);
    on<AddDonationEvent>(_onAddDonation);
    on<AddPrayerRequestEvent>(_onAddPrayerRequest);
    on<SelectTerritoryEvent>(_onSelectTerritory);
    on<FollowWorkerEvent>(_onFollowWorker);
    on<RecenterFollowEvent>(_onRecenterFollow);
    on<SeedFollowPathEvent>(_onSeedFollowPath);
    on<ToggleLayerEvent>(_onToggleLayer);
    on<UpdateWorkerPathEvent>(_onUpdateWorkerPath);
    on<ShowMapPopupEvent>(_onShowMapPopup);
    on<HideMapPopupEvent>(_onHideMapPopup);
    on<ToggleMapPopupExpandedEvent>(_onToggleMapPopupExpanded);
  }

  Future<void> _onInitialize(
    InitializeEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    emit(state.copyWith(mapMode: event.initialMode, isLoading: true));
    await _loadAllData(emit);
  }

  Future<void> _onChangeMapMode(
    ChangeMapModeEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    switch (event.mode) {
      case MapMode.overview:
        emit(
          state.copyWith(
            mapMode: event.mode,
            showTerritories: true,
            showWorkers: true,
            showActivities: true,
            showTrails: false,
            followTarget: '',
            activePopup: null,
          ),
        );
        break;
      case MapMode.workers:
        emit(
          state.copyWith(
            mapMode: event.mode,
            showTerritories: true,
            showWorkers: true,
            showActivities: false,
            showTrails: false,
            activePopup: null,
          ),
        );
        break;
      case MapMode.territories:
        emit(
          state.copyWith(
            mapMode: event.mode,
            showTerritories: true,
            showWorkers: false,
            showActivities: false,
            showTrails: false,
            followTarget: '',
            activePopup: null,
          ),
        );
        break;
    }
  }

  Future<void> _onRefreshData(
    RefreshDataEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    await _loadAllData(emit);
  }

  Future<void> _loadAllData(Emitter<CommandCenterState> emit) async {
    try {
      final teamId = await _storage.read('team_id');
      if (teamId == null) {
        emit(state.copyWith(isLoading: false, error: 'No team ID found'));
        return;
      }

      final results = await Future.wait([
        _loadTerritories(),
        _loadDonations(teamId),
        _loadPrayerRequests(teamId),
        _loadWorkers(teamId),
        _loadLiveWorkerLocations(teamId),
      ], eagerError: false);

      final territories = results[0] as List<GeoTerritory>? ?? [];
      final donations = results[1] as List<DonationModel>? ?? [];
      final prayerRequests = results[2] as List<PrayerRequestModel>? ?? [];
      final workers = results[3] as List<TeamMember>? ?? [];
      final fetchedLiveLocations = results[4] as Map<String, Position>? ?? {};

      final mergedLiveLocations = Map<String, Position>.from(
        state.liveLocations,
      )..addAll(fetchedLiveLocations);

      final mergedLiveUpdatedAt = Map<String, DateTime>.from(
        state.liveLocationUpdatedAt,
      );
      final fetchTime = DateTime.now().toUtc();
      for (final workerId in fetchedLiveLocations.keys) {
        mergedLiveUpdatedAt.putIfAbsent(workerId, () => fetchTime);
      }

      emit(
        state.copyWith(
          territories: territories,
          donations: donations,
          prayerRequests: prayerRequests,
          workers: workers,
          liveLocations: mergedLiveLocations,
          liveLocationUpdatedAt: mergedLiveUpdatedAt,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<Map<String, Position>?> _loadLiveWorkerLocations(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.workSessions}/teams/$teamId/workers/active',
      );
      if (response.statusCode != 200) return null;

      final data = response.data;
      if (kDebugMode) {
        debugPrint(
          'LiveLocations: /workers/active response type=${data.runtimeType}',
        );
      }

      List<dynamic> workers;
      if (data is List) {
        workers = data;
      } else if (data is Map) {
        final activeSessions =
            data['active_sessions'] ?? data['activeSessions'];
        final topWorkers = data['workers'] ?? data['members'];
        final nestedData = data['data'];

        if (activeSessions is List) {
          workers = activeSessions;
        } else if (topWorkers is List) {
          workers = topWorkers;
        } else if (nestedData is List) {
          workers = nestedData;
        } else if (nestedData is Map) {
          final nestedWorkers =
              nestedData['workers'] ?? nestedData['active_sessions'];
          workers = nestedWorkers is List ? nestedWorkers : const [];
        } else {
          workers = const [];
        }
      } else {
        workers = const [];
      }

      final locations = <String, Position>{};
      for (final item in workers) {
        if (item is! Map) continue;

        final workerId =
            item['worker_id']?.toString() ??
            item['workerId']?.toString() ??
            item['user_id']?.toString() ??
            item['userId']?.toString() ??
            item['id']?.toString();

        final latRaw =
            item['entry_lat'] ??
            item['entryLat'] ??
            item['latitude'] ??
            item['lat'] ??
            (item['location'] is Map
                ? (item['location']['latitude'] ?? item['location']['lat'])
                : null);

        final lngRaw =
            item['entry_lng'] ??
            item['entryLng'] ??
            item['longitude'] ??
            item['lng'] ??
            item['lon'] ??
            (item['location'] is Map
                ? (item['location']['longitude'] ??
                      item['location']['lng'] ??
                      item['location']['lon'])
                : null);

        if (workerId == null || workerId.isEmpty) continue;
        if (latRaw is! num || lngRaw is! num) continue;
        final lat = latRaw.toDouble();
        final lng = lngRaw.toDouble();
        if (!_isValidLocation(lat, lng)) continue;

        locations[workerId] = Position(
          latitude: lat,
          longitude: lng,
        );
      }

      if (kDebugMode) {
        debugPrint('LiveLocations: parsed locations=${locations.length}');
      }
      return locations;
    } catch (e) {
      debugPrint('Error loading live worker locations: $e');
      return null;
    }
  }

  Future<List<GeoTerritory>?> _loadTerritories() async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.territories}/my-allocations',
      );

      if (response.statusCode == 200) {
        final results = _extractList(
          response.data,
          keys: const [
            'results',
            'data',
            'allocations',
            'assignments',
            'territories',
          ],
        );

        return results.whereType<Map<String, dynamic>>().map((item) {
          final territory = item['territory'];
          if (territory is Map<String, dynamic>) {
            return GeoTerritory.fromJson(_sanitizeGeoTerritoryJson(territory));
          }
          return GeoTerritory.fromJson(_sanitizeGeoTerritoryJson(item));
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading territories: $e');
      return null;
    }
  }

  Future<List<DonationModel>?> _loadDonations(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.donations}/team/$teamId',
      );
      final bookSalesResponse = await _apiClient.get(
        '${ApiConstants.bookSales}/team/$teamId',
      );

      if (response.statusCode == 200 || bookSalesResponse.statusCode == 200) {
        final donationItems =
            _extractList(
                  response.data,
                  keys: const ['results', 'data', 'donations'],
                )
                .whereType<Map<String, dynamic>>()
                .map(DonationModel.fromJson)
                .toList();

        final bookAsDonations =
            _extractList(
                  bookSalesResponse.data,
                  keys: const ['results', 'data', 'book_sales'],
                )
                .whereType<Map<String, dynamic>>()
                .map(_bookSaleToDonationModel)
                .toList();

        return [...donationItems, ...bookAsDonations];
      }
      return null;
    } catch (e) {
      debugPrint('Error loading donations: $e');
      return null;
    }
  }

  Future<List<PrayerRequestModel>?> _loadPrayerRequests(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.prayerRequests}/team/$teamId',
      );

      if (response.statusCode == 200) {
        return _extractList(
              response.data,
              keys: const ['results', 'data', 'prayer_requests', 'prayers'],
            )
            .whereType<Map<String, dynamic>>()
            .map(PrayerRequestModel.fromJson)
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading prayer requests: $e');
      return null;
    }
  }

  Future<List<TeamMember>?> _loadWorkers(String teamId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConstants.teams}/$teamId/workers',
      );

      if (response.statusCode == 200) {
        return _extractList(
              response.data,
              keys: const ['results', 'data', 'workers', 'members', 'users'],
            )
            .whereType<Map<String, dynamic>>()
            .map(TeamMember.fromUserJson)
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error loading workers: $e');
      return null;
    }
  }

  Future<void> _onUpdateLiveLocation(
    UpdateLiveLocationEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    if (!_isValidLocation(event.latitude, event.longitude)) return;
    final existingTs = state.liveLocationUpdatedAt[event.workerId];
    if (existingTs != null && event.occurredAt.isBefore(existingTs)) {
      return;
    }

    final updatedLocations = Map<String, Position>.from(state.liveLocations);
    final previous = updatedLocations[event.workerId];

    // Apply client-side EMA smoothing to reduce jitter
    final rawPos = Position(
      latitude: event.latitude,
      longitude: event.longitude,
    );
    final smoothedPos = _smoothPosition(event.workerId, rawPos);

    // Update ring buffer with raw position (for road snap context)
    _updateRingBuffer(event.workerId, rawPos);

    // Try road snapping (rate-limited)
    final snappedPos = await _tryRoadSnap(event.workerId, smoothedPos);

    // Use snapped if available, else EMA-smoothed
    final displayPos = snappedPos ?? smoothedPos;

    if (previous != null) {
      final movementMeters = _haversineMeters(
        previous.latitude,
        previous.longitude,
        displayPos.latitude,
        displayPos.longitude,
      );
      if (movementMeters < 1.5) {
        return;
      }
    }

    updatedLocations[event.workerId] = displayPos;

    final updatedTimestamps = Map<String, DateTime>.from(
      state.liveLocationUpdatedAt,
    );
    updatedTimestamps[event.workerId] = event.occurredAt;

    final updatedGpsLive = Set<String>.from(state.gpsLiveWorkerIds)
      ..add(event.workerId);

    final updatedAccuracy = Map<String, double>.from(
      state.liveLocationAccuracy,
    );
    if (event.accuracy != null && event.accuracy! >= 0) {
      updatedAccuracy[event.workerId] = event.accuracy!;
    }

    final updatedSpeed = Map<String, double>.from(state.liveLocationSpeedMps);
    if (event.speedMps != null && event.speedMps! >= 0) {
      updatedSpeed[event.workerId] = event.speedMps!;
    }

    final breachedWorkerIds = _computeBreachedWorkers(
      updatedLocations,
      state.territories,
    );

    final shouldExtendPath =
        state.followTarget == event.workerId ||
        (state.workerPaths[event.workerId]?.isNotEmpty ?? false);
    final updatedPaths = Map<String, List<Position>>.from(state.workerPaths);
    if (shouldExtendPath) {
      final currentPath = List<Position>.from(
        updatedPaths[event.workerId] ?? const [],
      );
      final bool shouldAppendPoint =
          currentPath.isEmpty ||
          _haversineMeters(
                currentPath.last.latitude,
                currentPath.last.longitude,
                displayPos.latitude,
                displayPos.longitude,
              ) >=
              1.5;
      if (shouldAppendPoint) {
        currentPath.add(displayPos);
      }
      updatedPaths[event.workerId] = currentPath.length > 2400
          ? currentPath.sublist(currentPath.length - 2400)
          : currentPath;
    }

    emit(
      state.copyWith(
        liveLocations: updatedLocations,
        liveLocationUpdatedAt: updatedTimestamps,
        liveLocationAccuracy: updatedAccuracy,
        liveLocationSpeedMps: updatedSpeed,
        gpsLiveWorkerIds: updatedGpsLive,
        workerPaths: updatedPaths,
        breachedWorkerIds: breachedWorkerIds,
      ),
    );
  }

  Set<String> _computeBreachedWorkers(
    Map<String, Position> locations,
    List<GeoTerritory> territories,
  ) {
    final breached = <String>{};
    for (final entry in locations.entries) {
      final workerId = entry.key;
      final pos = entry.value;
      bool insideAny = false;
      for (final territory in territories) {
        final geom = territory.geometry;
        if (geom == null) continue;
        if (_isPointInGeometry(pos, geom)) {
          insideAny = true;
          break;
        }
      }
      if (!insideAny) {
        breached.add(workerId);
      }
    }
    return breached;
  }

  bool _isPointInGeometry(Position point, Map<String, dynamic> geometry) {
    final type = geometry['type'] as String?;
    if (type == 'Polygon') {
      return _isPointInPolygon(point, geometry['coordinates']);
    } else if (type == 'MultiPolygon') {
      final polygons = geometry['coordinates'] as List?;
      if (polygons == null) return false;
      for (final polygon in polygons) {
        if (_isPointInPolygon(point, polygon)) return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(Position point, dynamic coordinates) {
    if (coordinates is! List || coordinates.isEmpty) return false;
    final ring = coordinates[0] as List?;
    if (ring == null || ring.length < 3) return false;

    bool inside = false;
    final n = ring.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = (ring[i] as List)[0] as num;
      final yi = (ring[i] as List)[1] as num;
      final xj = (ring[j] as List)[0] as num;
      final yj = (ring[j] as List)[1] as num;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _onAddDonation(
    AddDonationEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(donations: [...state.donations, event.donation]));
  }

  void _onAddPrayerRequest(
    AddPrayerRequestEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(
      state.copyWith(
        prayerRequests: [...state.prayerRequests, event.prayerRequest],
      ),
    );
  }

  void _onSelectTerritory(
    SelectTerritoryEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(
      state.copyWith(selectedTerritoryId: event.territoryId, activePopup: null),
    );
  }

  Future<void> _onFollowWorker(
    FollowWorkerEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    if (event.workerId == null || event.workerId!.isEmpty) {
      emit(state.copyWith(followTarget: '', activePopup: null));
      return;
    }

    final workerId = event.workerId!;
    final pos = state.liveLocations[workerId];
    if (pos == null || !_isValidLocation(pos.latitude, pos.longitude)) return;
    final updatedPaths = <String, List<Position>>{};
    final existingPathForTarget = state.workerPaths[workerId];
    if (existingPathForTarget != null && existingPathForTarget.isNotEmpty) {
      updatedPaths[workerId] = List<Position>.from(existingPathForTarget);
    }
    emit(
      state.copyWith(
        followTarget: workerId,
        showTrails: true,
        workerPaths: updatedPaths,
        activePopup: null,
      ),
    );

    unawaited(_loadFollowPathInBackground(workerId));
  }

  Future<void> _onRecenterFollow(
    RecenterFollowEvent event,
    Emitter<CommandCenterState> emit,
  ) async {
    final workerId = state.followTarget;
    if (workerId == null || workerId.isEmpty) return;
    final pos = state.liveLocations[workerId];
    if (pos == null || !_isValidLocation(pos.latitude, pos.longitude)) return;

    // Force camera-follow re-initialization even when no fresh GPS packet arrives.
    final updatedPaths = <String, List<Position>>{};
    final existingPathForTarget = state.workerPaths[workerId];
    if (existingPathForTarget != null && existingPathForTarget.isNotEmpty) {
      updatedPaths[workerId] = List<Position>.from(existingPathForTarget);
    }

    emit(
      state.copyWith(
        followTarget: '',
        activePopup: null,
      ),
    );

    emit(
      state.copyWith(
        followTarget: workerId,
        showTrails: true,
        workerPaths: updatedPaths,
        activePopup: null,
      ),
    );
  }

  void _onSeedFollowPath(
    SeedFollowPathEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    if (state.followTarget != event.workerId) return;
    final updatedPaths = Map<String, List<Position>>.from(state.workerPaths)
      ..[event.workerId] = event.path;

    final livePoint = state.liveLocations[event.workerId];
    if (livePoint != null) {
      final current = List<Position>.from(
        updatedPaths[event.workerId] ?? const [],
      );
      if (current.isEmpty ||
          _haversineMeters(
                current.last.latitude,
                current.last.longitude,
                livePoint.latitude,
                livePoint.longitude,
              ) >=
              1.5) {
        current.add(livePoint);
      }
      updatedPaths[event.workerId] = current.length > 2400
          ? current.sublist(current.length - 2400)
          : current;
    }

    emit(state.copyWith(workerPaths: updatedPaths));
  }

  Future<void> _loadFollowPathInBackground(String workerId) async {
    final historyPath = await _fetchWorkerPathHistory(workerId);
    if (historyPath == null || historyPath.isEmpty) return;

    final snappedPath = await _roadSnapService.snapPath(historyPath);
    final path = (snappedPath != null && snappedPath.isNotEmpty)
        ? snappedPath
        : historyPath;

    if (!isClosed) {
      add(SeedFollowPathEvent(workerId: workerId, path: path));
    }
  }

  void _onShowMapPopup(
    ShowMapPopupEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(activePopup: event.popup));
  }

  void _onHideMapPopup(
    HideMapPopupEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    emit(state.copyWith(activePopup: null));
  }

  void _onToggleMapPopupExpanded(
    ToggleMapPopupExpandedEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    final current = state.activePopup;
    if (current == null) return;
    emit(
      state.copyWith(
        activePopup: current.copyWith(expanded: !current.expanded),
      ),
    );
  }

  void _onToggleLayer(
    ToggleLayerEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    switch (event.layer) {
      case 'territories':
        emit(state.copyWith(showTerritories: !state.showTerritories));
        break;
      case 'workers':
        emit(state.copyWith(showWorkers: !state.showWorkers));
        break;
      case 'activities':
        emit(state.copyWith(showActivities: !state.showActivities));
        break;
      case 'trails':
        emit(state.copyWith(showTrails: !state.showTrails));
        break;
    }
  }

  void _onUpdateWorkerPath(
    UpdateWorkerPathEvent event,
    Emitter<CommandCenterState> emit,
  ) {
    final updatedPaths = Map<String, List<Position>>.from(state.workerPaths)
      ..[event.workerId] = event.path;
    emit(state.copyWith(workerPaths: updatedPaths));
  }

  Future<List<Position>?> _fetchWorkerPathHistory(String workerId) async {
    try {
      final end = DateTime.now().toUtc();
      final start = end.subtract(const Duration(minutes: 45));
      final response = await _apiClient.get(
        '/api/workers/$workerId/path-history',
        queryParameters: <String, dynamic>{
          'start_time': start.toIso8601String(),
          'end_time': end.toIso8601String(),
          'limit': 600,
          'sample_meters': 5,
        },
      );
      if (response.statusCode != 200) return null;

      final payload = response.data;
      final pointsRaw = payload is Map ? payload['path_points'] : null;
      if (pointsRaw is! List) return null;

      final pointsWithTs = <({Position p, DateTime ts})>[];
      for (final item in pointsRaw) {
        if (item is! Map) continue;
        final lat = item['latitude'];
        final lng = item['longitude'];
        if (lat is! num || lng is! num) continue;
        final trackedAt = item['tracked_at'];
        final timestamp = trackedAt is String
            ? DateTime.tryParse(trackedAt)?.toUtc()
            : null;
        pointsWithTs.add((
          p: Position(latitude: lat.toDouble(), longitude: lng.toDouble()),
          ts: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ));
      }

      if (pointsWithTs.isEmpty) return null;
      pointsWithTs.sort((a, b) => a.ts.compareTo(b.ts));

      final deduped = <Position>[];
      for (final entry in pointsWithTs) {
        if (deduped.isEmpty) {
          deduped.add(entry.p);
          continue;
        }
        final last = deduped.last;
        final distance = _haversineMeters(
          last.latitude,
          last.longitude,
          entry.p.latitude,
          entry.p.longitude,
        );
        if (distance >= 1.5) deduped.add(entry.p);
      }

      return deduped;
    } catch (e) {
      debugPrint('Error loading worker path history for $workerId: $e');
      return null;
    }
  }

  List<dynamic> _extractList(dynamic data, {required List<String> keys}) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in keys) {
        final v = data[key];
        if (v is List) return v;
      }
    }
    return const [];
  }

  Map<String, dynamic> _sanitizeGeoTerritoryJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final solid = json['solid']?.toString() ?? 'false';
    final entityName =
        json['entity_name']?.toString() ?? json['entityName']?.toString() ?? '';
    final entityId =
        json['entity_id']?.toString() ?? json['entityId']?.toString() ?? '';

    return <String, dynamic>{
      ...json,
      'id': id,
      'solid': solid,
      'entity_name': entityName,
      'entity_id': entityId,
    };
  }

  DonationModel _bookSaleToDonationModel(Map<String, dynamic> json) {
    final receipt = (json['receipt_number'] as String?) ?? '';
    final totalAmount = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final lat =
        (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble() ??
        (json['location_lat'] as num?)?.toDouble() ??
        (json['buyer_latitude'] as num?)?.toDouble();
    final lng =
        (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble() ??
        (json['location_lng'] as num?)?.toDouble() ??
        (json['buyer_longitude'] as num?)?.toDouble();
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final unitPrice = (json['price_per_unit'] as num?)?.toDouble();

    return DonationModel.fromJson({
      'id': json['id'],
      'session_id': null,
      'worker_id': json['worker_id'],
      'worker_name': json['worker_name'] ?? 'Light Squad',
      'team_id': json['team_id'],
      'donor_name': json['buyer_name'] ?? 'Buyer',
      'donor_phone': json['buyer_phone'],
      'donor_email': json['buyer_email'],
      'donor_address': json['buyer_address'] ?? '',
      'latitude': lat,
      'longitude': lng,
      'amount': totalAmount > 0
          ? totalAmount
          : (unitPrice != null ? unitPrice * quantity : 0.0),
      'currency': json['currency'] ?? 'USD',
      'donation_type': 'book_sale',
      'purpose': json['book_title'],
      'payment_method': json['payment_method'] ?? 'cash',
      'payment_ref': null,
      'receipt_number': receipt.isEmpty ? 'BOOK-SALE' : receipt,
      'is_anonymous': false,
      'notes': json['notes'],
      'status': (json['status'] == 'completed')
          ? 'received'
          : (json['status'] ?? 'received'),
      'collected_at': json['sold_at'] ?? json['created_at'],
      'deposited_at': null,
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
    });
  }

  Position _smoothPosition(String workerId, Position raw) {
    final prev = _emaPositions[workerId];
    if (prev == null) {
      _emaPositions[workerId] = raw;
      return raw;
    }
    final smoothed = Position(
      latitude: _emaAlpha * raw.latitude + (1 - _emaAlpha) * prev.latitude,
      longitude: _emaAlpha * raw.longitude + (1 - _emaAlpha) * prev.longitude,
    );
    _emaPositions[workerId] = smoothed;
    return smoothed;
  }

  void _updateRingBuffer(String workerId, Position raw) {
    final buffer = _positionRingBuffers.putIfAbsent(workerId, () => []);
    buffer.add(raw);
    if (buffer.length > _ringBufferSize) {
      buffer.removeAt(0);
    }
  }

  Future<Position?> _tryRoadSnap(String workerId, Position smoothed) async {
    final now = DateTime.now();
    final lastSnap = _lastSnapTimes[workerId];
    if (lastSnap != null && now.difference(lastSnap) < _snapRateLimit) {
      // Rate limited — return last snapped position if available
      return _snappedPositions[workerId];
    }

    _lastSnapTimes[workerId] = now;

    try {
      final buffer = _positionRingBuffers[workerId];
      final context = buffer != null && buffer.length >= 2 ? buffer : null;

      final result = await _roadSnapService.snapPoint(
        smoothed,
        context: context,
      );

      if (result != null) {
        _snappedPositions[workerId] = result;
        return result;
      }
    } catch (_) {
      // Road snap failed silently — fall back to EMA
    }

    // Fallback: return last snapped or null (EMA will be used)
    return _snappedPositions[workerId];
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  bool _isValidLocation(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }
}
