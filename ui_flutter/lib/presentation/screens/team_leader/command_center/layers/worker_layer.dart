import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/team_model.dart';
import '../command_center_state.dart' as cc;
import '../services/annotation_registry.dart';

class WorkerLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<cc.Position>();

  CircleAnnotationManager? _circleManager;

  WorkerLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
    } catch (e) {
      debugPrint('Error initializing worker layer: $e');
    }
  }

  Future<void> updateWorkers(
    List<TeamMember> workers,
    Map<String, cc.Position> liveLocations,
  ) async {
    if (_circleManager == null) return;

    final entities = Map<String, cc.Position>.from(liveLocations);
    final currentIds = entities.keys.toSet();
    final diff = _registry.diff(currentIds, entities);

    final added = (diff['added'] as List? ?? []).cast<String>();
    final updated = (diff['updated'] as List? ?? []).cast<String>();

    final removedMapRaw = diff['removed'] as Map? ?? {};
    final removed = removedMapRaw.map(
      (k, v) => MapEntry(k as String, List<dynamic>.from(v as Iterable)),
    );

    if (removed.isNotEmpty) {
      final toRemove = removed.values.expand((r) => r).toList();
      for (final annotation in toRemove) {
        if (annotation is CircleAnnotation) {
          await _circleManager?.delete(annotation);
        }
      }
    }

    final circlesToAdd = <CircleAnnotationOptions>[];
    final idsToAdd = <String>[];

    for (final workerId in [...added, ...updated]) {
      final position = entities[workerId];
      if (position == null) continue;
      circlesToAdd.add(
        CircleAnnotationOptions(
          geometry: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          circleColor: const Color(0xCC22C55E).toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      idsToAdd.add(workerId);
    }

    if (circlesToAdd.isNotEmpty) {
      final created = await _circleManager?.createMulti(circlesToAdd);
      if (created != null) {
        for (var i = 0; i < idsToAdd.length; i++) {
          final workerId = idsToAdd[i];
          final pos = entities[workerId]!;
          final circle = created[i];
          if (circle != null) {
            _registry.register(workerId, pos, [circle.id], [circle]);
          }
        }
      }
    }
  }

  Future<void> clear() async {
    if (_circleManager == null) return;
    await _circleManager!.deleteAll();
    _registry.clear();
  }

  void dispose() {
    _circleManager = null;
  }
}

