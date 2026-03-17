import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/team_model.dart';
import '../command_center_state.dart' as cc;
import '../services/annotation_registry.dart';

class WorkerLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<cc.Position>();

  CircleAnnotationManager? _circleManager;
  Timer? _pulseTimer;
  double _pulseRadius = 1.0;
  bool _pulsing = false;

  WorkerLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
      _startPulseAnimation();
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

  Future<void> updateWorkers(
    List<TeamMember> workers,
    Map<String, cc.Position> liveLocations,
  ) async {
    if (_circleManager == null) return;

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
    final Map<String, List<String>> removed = removedMap.map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    );

    // Remove old annotations
    if (removed.isNotEmpty) {
      final toRemove = removed.values
          .expand((r) => r as Iterable<dynamic>)
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
  }

  Future<void> clear() async {
    if (_circleManager == null) return;
    await _circleManager!.deleteAll();
    _registry.clear();
  }

  void dispose() {
    _pulseTimer?.cancel();
    _circleManager = null;
  }
}
