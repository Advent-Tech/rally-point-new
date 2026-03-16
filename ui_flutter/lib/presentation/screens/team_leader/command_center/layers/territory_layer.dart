import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/territory_model.dart';
import '../services/annotation_registry.dart';

class TerritoryLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<GeoTerritory>();

  PolygonAnnotationManager? _polygonManager;
  PolylineAnnotationManager? _polylineManager;

  TerritoryLayer({required this.mapController});

  Future<void> initialize() async {
    try {
      _polygonManager = await mapController.annotations
          .createPolygonAnnotationManager();
      _polylineManager = await mapController.annotations
          .createPolylineAnnotationManager();
    } catch (e) {
      debugPrint('Error initializing territory layer: $e');
    }
  }

  void updateTerritories(List<GeoTerritory> territories) async {
    if (_polygonManager == null || _polylineManager == null) return;

    final currentIds = territories.map((t) => t.id).toSet();
    final Map<String, GeoTerritory> entities = Map.fromEntries(
      territories.map((t) => MapEntry(t.id, t)),
    );
    final Map<String, dynamic> diff = _registry.diff(currentIds, entities);

    final List<String> added = List<String>.from(diff['added'] as Iterable);
    final List<String> updated = List<String>.from(diff['updated'] as Iterable);
    final Map<String, List<String>> removed = Map<String, List<String>>.from(
      diff['removed'] as Map,
    );

    // Remove old annotations
    if (removed.isNotEmpty) {
      final toRemove = removed.values
          .expand((r) => r as Iterable<dynamic>)
          .toList();
      for (final annotation in toRemove) {
        if (annotation is PolygonAnnotation) {
          await _polygonManager?.delete(annotation);
        } else if (annotation is PolylineAnnotation) {
          await _polylineManager?.delete(annotation);
        }
      }
    }

    // Add/update territories
    final List<PolygonAnnotationOptions> polygonsToAdd = [];
    final List<PolylineAnnotationOptions> polylinesToAdd = [];
    final List<String> idsToAdd = [];

    for (final id in [...added, ...updated]) {
      final territory = entities[id];
      if (territory == null) continue;
      final geometry = territory.geometry;
      if (geometry != null) {
        final type = geometry['type'] as String?;
        final coordinates = geometry['coordinates'];

        if (coordinates is List) {
          final List<List<Position>> polygonCoords = [];

          if (type == 'Polygon') {
            for (final ring in coordinates) {
              if (ring is List) {
                final List<Position> points = ring.map((coord) {
                  final c = coord as List;
                  final lng = (c[0] as num).toDouble();
                  final lat = (c[1] as num).toDouble();

                  // // Debug logging for the first point of each ring
                  // if (polygonCoords.isEmpty && points.isEmpty) {
                  //   debugPrint('Territory $id First Point: Lng=$lng, Lat=$lat');
                  // }

                  return Position(lng, lat);
                }).toList();
                polygonCoords.add(points);
              }
            }
          } else if (type == 'MultiPolygon') {
            for (final polygon in coordinates) {
              if (polygon is List && polygon.isNotEmpty) {
                final ring = polygon.first;
                if (ring is List) {
                  final List<Position> points = ring.map((coord) {
                    final c = coord as List;
                    final lng = (c[0] as num).toDouble();
                    final lat = (c[1] as num).toDouble();

                    // Debug logging for the first point of each polygon
                    // if (polygonCoords.isEmpty && points.isEmpty) {
                    //   debugPrint(
                    //     'MultiTerritory $id First Point: Lng=$lng, Lat=$lat',
                    //   );
                    // }

                    return Position(lng, lat);
                  }).toList();
                  polygonCoords.add(points);
                }
              }
            }
          }

          if (polygonCoords.isNotEmpty) {
            final isSolid = territory.solid.toLowerCase() == 'true';

            polygonsToAdd.add(
              PolygonAnnotationOptions(
                geometry: Polygon(coordinates: polygonCoords),
                fillColor: isSolid
                    ? const Color(0x803B82F6)
                          .toARGB32() // 0.5 opacity (increased)
                    : const Color(
                        0x4D3B82F6,
                      ).toARGB32(), // 0.3 opacity (increased)
                fillOutlineColor: const Color(0xFF3B82F6).toARGB32(),
              ),
            );

            // Add outlines for each ring
            for (final points in polygonCoords) {
              polylinesToAdd.add(
                PolylineAnnotationOptions(
                  geometry: LineString(coordinates: points),
                  lineColor: const Color(0xFF3B82F6).toARGB32(),
                  lineWidth: 3.5, // Increased width
                ),
              );
            }
            idsToAdd.add(territory.id);
          }
        }
      }
    }

    if (polygonsToAdd.isNotEmpty) {
      final List<PolygonAnnotation?>? createdPolygons = await _polygonManager
          ?.createMulti(polygonsToAdd);
      final List<PolylineAnnotation?>? createdPolylines = await _polylineManager
          ?.createMulti(polylinesToAdd);

      if (createdPolygons != null && createdPolylines != null) {
        // Update registry
        for (var i = 0; i < idsToAdd.length; i++) {
          final id = idsToAdd[i];
          final territory = entities[id]!;
          final polygon = createdPolygons[i];
          final polyline = createdPolylines[i];
          if (polygon != null && polyline != null) {
            _registry.register(
              id,
              territory,
              [polygon.id, polyline.id],
              [polygon, polyline],
            );
          }
        }
      }
    }
  }

  void dispose() {
    _polygonManager = null;
    _polylineManager = null;
  }
}
