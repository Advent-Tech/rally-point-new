import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../../data/models/territory_model.dart';
import '../services/annotation_registry.dart';

class TerritoryLayer {
  final MapboxMap mapController;
  final _registry = AnnotationRegistry<GeoTerritory>();
  final Map<String, List<List<Position>>> _geometryCache = {};

  PolygonAnnotationManager? _polygonManager;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleManager;

  TerritoryLayer({required this.mapController});

  List<dynamic> getRegisteredAnnotations(String domainId) {
    return _registry.getAnnotations(domainId);
  }

  Future<void> initialize() async {
    try {
      _polygonManager = await mapController.annotations
          .createPolygonAnnotationManager();
      _polylineManager = await mapController.annotations
          .createPolylineAnnotationManager();
      _circleManager = await mapController.annotations
          .createCircleAnnotationManager();
    } catch (e) {
      debugPrint('Error initializing territory layer: $e');
    }
  }

  void updateTerritories(
    List<GeoTerritory> territories, {
    String? selectedId,
  }) async {
    if (_polygonManager == null ||
        _polylineManager == null ||
        _circleManager == null) {
      return;
    }

    // Clear and batch update for performance
    await _polygonManager!.deleteAll();
    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();
    _registry.clear();

    final List<PolygonAnnotationOptions> polygonsToAdd = [];
    final List<PolylineAnnotationOptions> polylinesToAdd = [];
    final List<CircleAnnotationOptions> circlesToAdd = [];
    final List<String> idsToAdd = [];

    for (final territory in territories) {
      final id = territory.id;
      final isSelected = id == selectedId;

      List<List<Position>> polygonCoords = _geometryCache[id] ?? [];

      if (polygonCoords.isEmpty) {
        final geometry = territory.geometry;
        if (geometry != null) {
          final type = geometry['type'] as String?;
          final coordinates = geometry['coordinates'];

          if (coordinates is List) {
            if (type == 'Polygon') {
              for (final ring in coordinates) {
                if (ring is List) {
                  final List<Position> points = ring.map((coord) {
                    final c = coord as List;
                    return Position(
                      (c[0] as num).toDouble(),
                      (c[1] as num).toDouble(),
                    );
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
                      return Position(
                        (c[0] as num).toDouble(),
                        (c[1] as num).toDouble(),
                      );
                    }).toList();
                    polygonCoords.add(points);
                  }
                }
              }
            }
            if (polygonCoords.isNotEmpty) {
              _geometryCache[id] = polygonCoords;
            }
          }
        }
      }

      if (polygonCoords.isNotEmpty) {
        final isSolid = territory.solid.toLowerCase() == 'true';

        polygonsToAdd.add(
          PolygonAnnotationOptions(
            geometry: Polygon(coordinates: polygonCoords),
            fillColor: isSelected
                ? const Color(0x993B82F6)
                      .toARGB32() // Higher opacity for selected
                : (isSolid
                      ? const Color(0x803B82F6).toARGB32()
                      : const Color(0x4D3B82F6).toARGB32()),
            fillOutlineColor: const Color(0xFF3B82F6).toARGB32(),
          ),
        );

        for (final points in polygonCoords) {
          polylinesToAdd.add(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: points),
              lineColor: const Color(0xFF3B82F6).toARGB32(),
              lineWidth: isSelected ? 5.0 : 3.5,
            ),
          );
        }

        // Add centroid marker for better visibility at zoomed-out levels
        final centroid = _calculateCentroid(polygonCoords.first);
        circlesToAdd.add(
          CircleAnnotationOptions(
            geometry: Point(coordinates: centroid),
            circleColor: const Color(0xFF3B82F6).toARGB32(),
            circleRadius: isSelected ? 12.0 : 8.0,
            circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
            circleStrokeWidth: 2.0,
          ),
        );

        idsToAdd.add(id);
      }
    }

    if (polygonsToAdd.isNotEmpty) {
      final createdPolygons = await _polygonManager!.createMulti(polygonsToAdd);
      final createdPolylines = await _polylineManager!.createMulti(
        polylinesToAdd,
      );
      final createdCircles = await _circleManager!.createMulti(circlesToAdd);

      for (var i = 0; i < idsToAdd.length; i++) {
        final id = idsToAdd[i];
        final territory = territories.firstWhere((t) => t.id == id);
        _registry.register(
          id,
          territory,
          [
            createdPolygons[i]!.id,
            createdPolylines[i]!.id,
            createdCircles[i]!.id,
          ],
          [createdPolygons[i], createdPolylines[i], createdCircles[i]],
        );
      }
    }
  }

  Position _calculateCentroid(List<Position> coords) {
    if (coords.isEmpty) return Position(0, 0);
    double sumLat = 0, sumLng = 0;
    for (final coord in coords) {
      sumLat += coord.lat;
      sumLng += coord.lng;
    }
    return Position(sumLng / coords.length, sumLat / coords.length);
  }

  Future<void> clear() async {
    await _polygonManager?.deleteAll();
    await _polylineManager?.deleteAll();
    await _circleManager?.deleteAll();
    _registry.clear();
  }

  void dispose() {
    _polygonManager = null;
    _polylineManager = null;
    _circleManager = null;
    _geometryCache.clear();
  }
}
