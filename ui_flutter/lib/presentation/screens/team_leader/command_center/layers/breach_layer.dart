import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../command_center_state.dart' as cc;
import '../services/annotation_registry.dart';

class BreachLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<String>();

  CircleAnnotationManager? _circleManager;
  Timer? _pulseTimer;
  double _pulseRadius = 1.0;

  BreachLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
      _startPulseAnimation();
    } catch (e) {
      debugPrint('Error initializing breach layer: $e');
    }
  }

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _pulseRadius = (_pulseRadius > 2.0) ? 1.0 : _pulseRadius + 0.1;
    });
  }

  Future<void> updateBreaches(
    Set<String> breachedWorkerIds,
    Map<String, cc.Position> liveLocations,
  ) async {
    if (_circleManager == null) return;

    final Map<String, dynamic> diff = _registry.diff(
      breachedWorkerIds,
      Map.fromEntries(breachedWorkerIds.map((id) => MapEntry(id, id))),
    );

    final List<String> added = List<String>.from(
      diff['added'] as Iterable? ?? [],
    );
    final List<String> updated = List<String>.from(
      diff['updated'] as Iterable? ?? [],
    );
    final Map<String, List<String>> removed = Map<String, List<String>>.from(
      diff['removed'] as Map? ?? {},
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

    final circlesToAdd = <CircleAnnotationOptions>[];
    final idsToAdd = <String>[];

    // Use original diff to get IDs
    final addedIds = <String>[];
    for (final String workerId in breachedWorkerIds) {
      final position = liveLocations[workerId];
      if (position != null &&
          (added.contains(workerId) || updated.contains(workerId))) {
        addedIds.add(workerId);
      }
    }

    for (final workerId in addedIds) {
      final position = liveLocations[workerId];
      if (position != null) {
        circlesToAdd.add(
          CircleAnnotationOptions(
            geometry: Point(
              coordinates: Position(position.longitude, position.latitude),
            ),
            circleColor: const Color(
              0x1AEF4444,
            ).toARGB32(), // rgba(239, 68, 68, 0.1)
            circleRadius: (20.0 * _pulseRadius).toDouble(),
            circleStrokeColor: const Color(
              0xCCEF4444,
            ).toARGB32(), // rgba(239, 68, 68, 0.8)
            circleStrokeWidth: 3.0,
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
          final workerId = idsToAdd[i];
          final circle = createdCircles[i];
          if (circle != null) {
            _registry.register(workerId, workerId, [circle.id], [circle]);
          }
        }
      }
    }
  }

  void dispose() {
    _pulseTimer?.cancel();
    _circleManager = null;
  }
}
