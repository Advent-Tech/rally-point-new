import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/team_model.dart';
import '../command_center_state.dart' as cc;
import '../services/annotation_registry.dart';

class WorkerLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<cc.Position>();

  CircleAnnotationManager? _circleManager;
  PolylineAnnotationManager? _headingManager;
  Timer? _pulseTimer;
  Timer? _animationTimer;
  double _pulseRadius = 1.0;
  bool _pulsing = false;
  bool _isAnimating = false;
  Map<String, cc.Position> _targetPositions = const {};

  WorkerLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
      _headingManager = await mapController.annotations
          .createPolylineAnnotationManager();
      _startPulseAnimation();
      _startPositionAnimation();
    } catch (e) {
      debugPrint('Error initializing worker layer: $e');
    }
  }

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _pulseRadius = _pulsing ? _pulseRadius + 0.1 : 1.0;
      if (_pulseRadius > 1.5) {
        _pulsing = false;
        _pulseRadius = 1.0;
      }
    });
  }

  void _startPositionAnimation() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_targetPositions.isEmpty || _circleManager == null) return;
      _isAnimating = true;
      _animateTowardsTargets();
      _isAnimating = false;
    });
  }

  Future<void> updateWorkers(
    List<TeamMember> workers,
    Map<String, cc.Position> liveLocations,
  ) async {
    if (_circleManager == null) return;
    _targetPositions = Map<String, cc.Position>.from(liveLocations);

    final Map<String, cc.Position> entities = Map<String, cc.Position>.from(
      liveLocations,
    );
    final Set<String> currentIds = entities.keys.toSet();
    final Map<String, dynamic> diff = _registry.diff(currentIds, entities);

    final List<String> added = (diff['added'] as List? ?? [])
        .map((e) => e as String)
        .toList();

    final List<String> updated = (diff['updated'] as List? ?? [])
        .map((e) => e as String)
        .toList();

    final Map<dynamic, dynamic> removedMap = diff['removed'] as Map;
    final Map<String, List<dynamic>> removed = removedMap.map(
      (k, v) => MapEntry(k as String, List<dynamic>.from(v as Iterable)),
    );

    // Remove old annotations
    if (removed.isNotEmpty) {
      final toRemove = removed.values
          .expand((r) => r)
          .toList();
      for (final annotation in toRemove) {
        if (annotation is CircleAnnotation) {
          await _circleManager?.delete(annotation);
        }
      }
    }

    // Add/update workers
    final List<CircleAnnotationOptions> circlesToAdd = [];
    final List<String> idsToAdd = [];

    for (final String workerId in [...added, ...updated]) {
      final cc.Position? position = entities[workerId];
      if (position != null) {
        circlesToAdd.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            circleColor: const Color(
              0xCC22C55E,
            ).toARGB32(), // rgba(34, 197, 94, 0.8)
            circleRadius: (8.0 * _pulseRadius).toDouble(),
            circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );
        idsToAdd.add(workerId);
      }
    }

    if (circlesToAdd.isNotEmpty) {
      final List<CircleAnnotation?>? createdCircles = await _circleManager
          ?.createMulti(circlesToAdd);

      if (createdCircles != null) {
        // Update registry
        for (var i = 0; i < idsToAdd.length; i++) {
          final String workerId = idsToAdd[i];
          final cc.Position pos = entities[workerId]!;
          final circle = createdCircles[i];
          if (circle != null) {
            _registry.register(workerId, pos, [circle.id], [circle]);
          }
        }
      }

      _pulsing = true;
    }

    if (!_isAnimating) {
      await _updateHeadingIndicators();
    }
  }

  Future<void> clear() async {
    if (_circleManager == null) return;
    await _circleManager!.deleteAll();
    await _headingManager?.deleteAll();
    _registry.clear();
    _targetPositions = const {};
  }

  void dispose() {
    _pulseTimer?.cancel();
    _animationTimer?.cancel();
    _circleManager = null;
    _headingManager = null;
  }

  void _animateTowardsTargets() {
    final ids = _registry.domainIds.toList();
    for (final workerId in ids) {
      final target = _targetPositions[workerId];
      final current = _registry.getEntity(workerId);
      if (target == null || current == null) continue;

      final distance = _haversineMeters(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );
      if (distance < 0.8) continue;

      final eased = _lerpPosition(current, target, 0.28);
      final annotations = _registry.getAnnotations(workerId);
      if (annotations.isEmpty) continue;
      final ann = annotations.first;
      if (ann is! CircleAnnotation) continue;
      ann.geometry = Point(
        coordinates: Position(eased.longitude, eased.latitude),
      );
      ann.circleRadius = (8.0 * _pulseRadius).toDouble();
      _circleManager?.update(ann);
      _registry.register(workerId, eased, [ann.id], [ann]);
    }
    _updateHeadingIndicators();
  }

  Future<void> _updateHeadingIndicators() async {
    if (_headingManager == null) return;
    await _headingManager!.deleteAll();
    final toCreate = <PolylineAnnotationOptions>[];
    for (final workerId in _registry.domainIds) {
      final current = _registry.getEntity(workerId);
      final target = _targetPositions[workerId];
      if (current == null || target == null) continue;
      final distance = _haversineMeters(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );
      if (distance < 4) continue;

      final heading = _bearingRadians(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );
      final arrowTip = _projectMeters(current, heading, 18);
      toCreate.add(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              Position(current.longitude, current.latitude),
              Position(arrowTip.longitude, arrowTip.latitude),
            ],
          ),
          lineColor: const Color(0xCC22C55E).toARGB32(),
          lineWidth: 2.5,
        ),
      );
    }
    if (toCreate.isNotEmpty) {
      await _headingManager!.createMulti(toCreate);
    }
  }

  cc.Position _lerpPosition(cc.Position a, cc.Position b, double t) {
    return cc.Position(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: a.longitude + (b.longitude - a.longitude) * t,
    );
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

  double _bearingRadians(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    return math.atan2(y, x);
  }

  cc.Position _projectMeters(cc.Position from, double bearingRad, double meters) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = from.latitude * math.pi / 180.0;
    final lon1 = from.longitude * math.pi / 180.0;
    final angDist = meters / earthRadiusMeters;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angDist) +
          math.cos(lat1) * math.sin(angDist) * math.cos(bearingRad),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearingRad) * math.sin(angDist) * math.cos(lat1),
          math.cos(angDist) - math.sin(lat1) * math.sin(lat2),
        );
    return cc.Position(
      latitude: lat2 * 180.0 / math.pi,
      longitude: lon2 * 180.0 / math.pi,
    );
  }
}
