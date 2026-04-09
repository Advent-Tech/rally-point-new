import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../command_center_state.dart' as cc;
import '../services/annotation_registry.dart';

class TrailLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<List<cc.Position>>();

  PolylineAnnotationManager? _polylineManager;

  TrailLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _polylineManager = await mapController.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('Error initializing trail layer: $e');
    }
  }

  Future<void> updateTrails(Map<String, List<cc.Position>> workerPaths) async {
    if (_polylineManager == null) return;

    final Set<String> currentIds = workerPaths.keys.toSet();
    final Map<String, List<cc.Position>> entities =
        Map<String, List<cc.Position>>.from(workerPaths);
    final Map<String, dynamic> diff = _registry.diff(currentIds, entities);

    final List<String> added = (diff['added'] as List? ?? [])
        .map((e) => e as String)
        .toList();

    final List<String> updated = (diff['updated'] as List? ?? [])
        .map((e) => e as String)
        .toList();

    final Map<dynamic, dynamic> removedMapRaw = diff['removed'] as Map? ?? {};
    final Map<String, List<dynamic>> removed = removedMapRaw.map(
      (k, v) => MapEntry(k as String, List<dynamic>.from(v as Iterable)),
    );

    // Remove old trails
    if (removed.isNotEmpty) {
      final toRemove = removed.values.expand((r) => r).toList();
      for (final annotation in toRemove) {
        if (annotation is PolylineAnnotation) {
          await _polylineManager?.delete(annotation);
        }
      }
    }

    // Updated paths must replace prior polyline annotations; otherwise trails
    // pile up on each websocket tick and can eventually freeze the map UI.
    if (updated.isNotEmpty) {
      for (final workerId in updated) {
        final existing = _registry.getAnnotations(workerId);
        for (final annotation in existing) {
          if (annotation is PolylineAnnotation) {
            await _polylineManager?.delete(annotation);
          }
        }
      }
    }

    // Add/update trails
    final List<PolylineAnnotationOptions> polylinesToAdd = [];
    final List<String> idsToAdd = [];

    for (final String workerId in [...added, ...updated]) {
      final List<cc.Position>? path = workerPaths[workerId];
      if (path != null && path.length >= 2) {
        final List<Position> coordinates = path
            .map((p) => Position(p.longitude, p.latitude))
            .toList();
        polylinesToAdd.add(
          PolylineAnnotationOptions(
            geometry: LineString(coordinates: coordinates),
            lineColor: const Color(
              0x8022C55E,
            ).toARGB32(), // rgba(34, 197, 94, 0.5)
            lineWidth: 3.0,
          ),
        );
        idsToAdd.add(workerId);
      }
    }

    if (polylinesToAdd.isNotEmpty) {
      final List<PolylineAnnotation?>? createdPolylines = await _polylineManager
          ?.createMulti(polylinesToAdd);

      if (createdPolylines != null) {
        // Update registry
        for (var i = 0; i < idsToAdd.length; i++) {
          final String workerId = idsToAdd[i];
          final List<cc.Position> path = workerPaths[workerId]!;
          final polyline = createdPolylines[i];
          if (polyline != null) {
            _registry.register(workerId, path, [polyline.id], [polyline]);
          }
        }
      }
    }
  }

  Future<void> clear() async {
    await _polylineManager?.deleteAll();
    _registry.clear();
  }

  void dispose() {
    _polylineManager = null;
  }
}
