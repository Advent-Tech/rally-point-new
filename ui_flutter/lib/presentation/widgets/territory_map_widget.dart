import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../data/models/territory_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/map_constants.dart';

/// Model for visit markers on the map
class VisitMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String? address;
  final String outcome;
  final String? notes;
  final DateTime timestamp;

  const VisitMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.outcome,
    this.notes,
    required this.timestamp,
  });
}

class TerritoryMapWidget extends StatefulWidget {
  final List<GeoTerritory> territories;
  final GeoTerritory? selectedTerritory;
  final Function(GeoTerritory)? onTerritoryTap;
  final bool showLabels;
  final bool showZoomControls;
  final List<VisitMarker> visitMarkers;
  final bool allowAddVisit;
  final Function(double latitude, double longitude)? onAddVisit;
  final bool fitToTerritories;
  final double? userLatitude;
  final double? userLongitude;

  const TerritoryMapWidget({
    super.key,
    required this.territories,
    this.selectedTerritory,
    this.onTerritoryTap,
    this.showLabels = true,
    this.showZoomControls = true,
    this.visitMarkers = const [],
    this.allowAddVisit = false,
    this.onAddVisit,
    this.fitToTerritories = false,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<TerritoryMapWidget> createState() => _TerritoryMapWidgetState();
}

class _TerritoryMapWidgetState extends State<TerritoryMapWidget> {
  MapboxMap? _mapboxMap;
  PolygonAnnotationManager? _polygonManager;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleManager;
  bool _isMapReady = false;
  bool _hasInitiallyFitTerritories = false;

  static const List<Color> _territoryColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFFCDDC39),
  ];

  final Map<String, List<Position>> _geometryCache = {};

  @override
  void didUpdateWidget(TerritoryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_territoriesChanged(oldWidget.territories, widget.territories)) {
      _geometryCache.clear();
    }

    final wasEmpty = oldWidget.territories.isEmpty;
    final nowHasData = widget.territories.isNotEmpty;
    final fitRequested = widget.fitToTerritories && !oldWidget.fitToTerritories;

    if (_isMapReady) {
      _updateAnnotations();
      if (fitRequested ||
          (wasEmpty && nowHasData) ||
          (!_hasInitiallyFitTerritories && nowHasData) ||
          (widget.fitToTerritories &&
              _territoriesChanged(oldWidget.territories, widget.territories))) {
        _fitToAllTerritories();
        _hasInitiallyFitTerritories = true;
      }
    }
  }

  bool _territoriesChanged(
      List<GeoTerritory> oldList, List<GeoTerritory> newList) {
    if (oldList.isEmpty && newList.isEmpty) return false;
    if (oldList.length != newList.length) return true;
    final oldIds = oldList.map((t) => t.id).toSet();
    final newIds = newList.map((t) => t.id).toSet();
    return !oldIds.containsAll(newIds) || !newIds.containsAll(oldIds);
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Create annotation managers
    _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();

    setState(() => _isMapReady = true);

    // Add annotations and fit to bounds
    await _updateAnnotations();
    await Future.delayed(const Duration(milliseconds: 200));
    _fitToAllTerritories();
  }

  Future<void> _updateAnnotations() async {
    if (_polygonManager == null || _polylineManager == null || _circleManager == null) return;

    // Clear ALL existing annotations at once
    await _polygonManager!.deleteAll();
    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();

    debugPrint('TerritoryMapWidget: Updating ${widget.territories.length} territories');

    // Add territory polygons and boundary lines
    for (int i = 0; i < widget.territories.length; i++) {
      final territory = widget.territories[i];
      final coords = _parseGeometryForTerritory(territory);

      debugPrint('TerritoryMapWidget: Territory ${territory.entityName} - coords: ${coords.length}, geometry: ${territory.geometry?.keys}');

      if (coords.isEmpty) {
        debugPrint('TerritoryMapWidget: Skipping territory ${territory.entityName} - no coordinates');
        continue;
      }

      final isSelected = widget.selectedTerritory?.id == territory.id;
      final colorIndex = i % _territoryColors.length;
      final baseColor =
          isSelected ? AppColors.primary : _territoryColors[colorIndex];

      try {
        // Add filled polygon with high visibility
        final polygonOptions = PolygonAnnotationOptions(
          geometry: Polygon(coordinates: [coords]),
          fillColor: baseColor.toARGB32(),
          fillOpacity: isSelected ? 0.5 : 0.4,
        );
        await _polygonManager!.create(polygonOptions);

        debugPrint('TerritoryMapWidget: Created polygon for ${territory.entityName} with ${coords.length} coords');

        // Add boundary line (polyline) for visibility - thicker line
        final lineCoords = List<Position>.from(coords);
        // Close the polygon line if not already closed
        if (lineCoords.isNotEmpty && lineCoords.first != lineCoords.last) {
          lineCoords.add(lineCoords.first);
        }

        // Use a darker border color for better contrast
        final borderColor = Color.fromARGB(255,
          (baseColor.r * 0.7).toInt(),
          (baseColor.g * 0.7).toInt(),
          (baseColor.b * 0.7).toInt()
        );

        final lineOptions = PolylineAnnotationOptions(
          geometry: LineString(coordinates: lineCoords),
          lineColor: borderColor.toARGB32(),
          lineWidth: isSelected ? 6.0 : 4.0,
          lineOpacity: 1.0,
        );
        await _polylineManager!.create(lineOptions);

        debugPrint('TerritoryMapWidget: Created polyline for ${territory.entityName}');

        // Also add a centroid marker for visibility at zoomed-out levels
        if (coords.length > 2) {
          final centroid = _calculateCentroid(coords);
          await _circleManager?.create(CircleAnnotationOptions(
            geometry: Point(coordinates: centroid),
            circleColor: baseColor.toARGB32(),
            circleRadius: isSelected ? 12.0 : 8.0,
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
            circleOpacity: 0.9,
          ));
        }
      } catch (e) {
        debugPrint('TerritoryMapWidget: Error creating annotations for ${territory.entityName}: $e');
      }
    }

    // Update visit markers
    await _updateVisitMarkers();
  }

  Future<void> _updateVisitMarkers() async {
    if (_circleManager == null) return;

    // NOTE: Don't delete circles here - they're deleted in _updateAnnotations()
    // This preserves territory centroid markers

    for (final visit in widget.visitMarkers) {
      Color markerColor;
      switch (visit.outcome.toLowerCase()) {
        case 'interested':
        case 'positive':
          markerColor = AppColors.success;
          break;
        case 'not_home':
        case 'not home':
          markerColor = AppColors.warning;
          break;
        case 'not_interested':
        case 'not interested':
          markerColor = AppColors.error;
          break;
        case 'callback':
        case 'follow_up':
          markerColor = AppColors.info;
          break;
        default:
          markerColor = AppColors.secondary;
      }

      // Use circle markers for visit markers (more visible than point annotations)
      final options = CircleAnnotationOptions(
        geometry: Point(coordinates: Position(visit.longitude, visit.latitude)),
        circleColor: markerColor.toARGB32(),
        circleRadius: 10,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
      );

      await _circleManager!.create(options);
    }
  }

  void _fitToAllTerritories() {
    if (_mapboxMap == null) return;

    if (widget.territories.isEmpty) {
      // Use user location if available, otherwise default to US center
      final lat = widget.userLatitude ?? MapConstants.defaultLatitude;
      final lng = widget.userLongitude ?? MapConstants.defaultLongitude;
      final zoom = widget.userLatitude != null ? 12.0 : MapConstants.defaultZoom;

      _mapboxMap?.setCamera(CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ));
      return;
    }

    final bounds = _calculateBounds();
    if (bounds != null) {
      debugPrint('TerritoryMapWidget: Fitting to bounds - SW: ${bounds.southwest.coordinates}, NE: ${bounds.northeast.coordinates}');

      _mapboxMap?.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 60, left: 60, bottom: 60, right: 60),
        null, // bearing
        null, // pitch
        18.0, // maxZoom - limit how far it zooms in for small territories
        null, // offset
      ).then((cameraOptions) {
        debugPrint('TerritoryMapWidget: Camera zoom: ${cameraOptions.zoom}');
        _mapboxMap?.setCamera(cameraOptions);
      });
      _hasInitiallyFitTerritories = true;
    }
  }

  CoordinateBounds? _calculateBounds() {
    if (widget.territories.isEmpty) return null;

    double? minLat, maxLat, minLng, maxLng;

    for (final territory in widget.territories) {
      final coords = _parseGeometryForTerritory(territory);

      for (final coord in coords) {
        if (coord.lat.abs() < 0.1 && coord.lng.abs() < 0.1) continue;

        if (minLat == null || coord.lat < minLat) minLat = coord.lat.toDouble();
        if (maxLat == null || coord.lat > maxLat) maxLat = coord.lat.toDouble();
        if (minLng == null || coord.lng < minLng) minLng = coord.lng.toDouble();
        if (maxLng == null || coord.lng > maxLng) maxLng = coord.lng.toDouble();
      }
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }

    return CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
  }

  void _zoomIn() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: (currentCamera.zoom) + 1,
      ));
    }
  }

  void _zoomOut() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: math.max(1, (currentCamera.zoom) - 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('mapWidget'),
          styleUri: MapConstants.getThemedStyleUri(isDark),
          cameraOptions: CameraOptions(
            center: Point(
                coordinates: Position(MapConstants.defaultLongitude,
                    MapConstants.defaultLatitude)),
            zoom: MapConstants.defaultZoom,
          ),
          onMapCreated: (mapboxMap) async {
            // Enable all gestures
            await mapboxMap.gestures.updateSettings(GesturesSettings(
              scrollEnabled: true,
              rotateEnabled: true,
              pinchToZoomEnabled: true,
              doubleTapToZoomInEnabled: true,
              doubleTouchToZoomOutEnabled: true,
              quickZoomEnabled: true,
              pitchEnabled: true,
              simultaneousRotateAndPinchToZoomEnabled: true,
            ));
            _onMapCreated(mapboxMap);
          },
          onTapListener: (context) async {
            // Handle tap on territories
            final point = context.point;

            // First, check if tap is near any centroid marker (for zoomed-out views)
            GeoTerritory? tappedTerritory = _findTerritoryNearPoint(point);

            // If not near centroid, check if inside polygon boundary
            if (tappedTerritory == null) {
              for (final territory in widget.territories) {
                if (_isPointInTerritory(point, territory)) {
                  tappedTerritory = territory;
                  break;
                }
              }
            }

            if (tappedTerritory != null) {
              widget.onTerritoryTap?.call(tappedTerritory);
            }
          },
          onLongTapListener: widget.allowAddVisit
              ? (context) {
                  final point = context.point;
                  widget.onAddVisit
                      ?.call(point.coordinates.lat.toDouble(), point.coordinates.lng.toDouble());
                }
              : null,
        ),

        // Zoom Controls
        if (widget.showZoomControls)
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _ZoomButton(icon: Icons.add, onPressed: _zoomIn),
                const SizedBox(height: 8),
                _ZoomButton(icon: Icons.remove, onPressed: _zoomOut),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.fit_screen,
                  onPressed: _fitToAllTerritories,
                  tooltip: 'Fit all territories',
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Position> _parseGeometryForTerritory(GeoTerritory territory) {
    if (_geometryCache.containsKey(territory.id)) {
      return _geometryCache[territory.id]!;
    }

    final coords = _parseGeometryRaw(territory.geometry);
    _geometryCache[territory.id] = coords;
    return coords;
  }

  Position _calculateCentroid(List<Position> coords) {
    if (coords.isEmpty) {
      return Position(MapConstants.defaultLongitude, MapConstants.defaultLatitude);
    }

    double sumLat = 0, sumLng = 0;
    for (final coord in coords) {
      sumLat += coord.lat.toDouble();
      sumLng += coord.lng.toDouble();
    }
    return Position(sumLng / coords.length, sumLat / coords.length);
  }

  /// Find territory whose centroid is near the tapped point
  /// Uses a threshold that scales with zoom level
  GeoTerritory? _findTerritoryNearPoint(Point point) {
    const double thresholdDegrees = 2.0; // ~200km at equator, good for zoomed-out view

    double closestDistance = double.infinity;
    GeoTerritory? closestTerritory;

    for (final territory in widget.territories) {
      final coords = _parseGeometryForTerritory(territory);
      if (coords.isEmpty) continue;

      final centroid = _calculateCentroid(coords);
      final distance = _calculateDistance(
        point.coordinates.lat.toDouble(),
        point.coordinates.lng.toDouble(),
        centroid.lat.toDouble(),
        centroid.lng.toDouble(),
      );

      if (distance < thresholdDegrees && distance < closestDistance) {
        closestDistance = distance;
        closestTerritory = territory;
      }
    }

    return closestTerritory;
  }

  /// Calculate simple Euclidean distance in degrees (good enough for proximity check)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat2 - lat1;
    final dLng = lng2 - lng1;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  List<Position> _parseGeometryRaw(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map<Position>((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map<Position>((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('TerritoryMapWidget: Error parsing geometry: $e');
    }

    return [];
  }

  bool _isPointInTerritory(Point point, GeoTerritory territory) {
    final coords = _parseGeometryForTerritory(territory);
    if (coords.isEmpty) return false;

    bool inside = false;
    int j = coords.length - 1;

    for (int i = 0; i < coords.length; j = i++) {
      final xi = coords[i].lng;
      final yi = coords[i].lat;
      final xj = coords[j].lng;
      final yj = coords[j].lat;

      if (((yi > point.coordinates.lat) != (yj > point.coordinates.lat)) &&
          (point.coordinates.lng <
              (xj - xi) * (point.coordinates.lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }

    return inside;
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, size: 22, color: AppColors.textPrimaryLight),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// A detailed map view for a single territory
class TerritoryDetailMapWidget extends StatefulWidget {
  final GeoTerritory territory;
  final double height;

  const TerritoryDetailMapWidget({
    super.key,
    required this.territory,
    this.height = 300,
  });

  @override
  State<TerritoryDetailMapWidget> createState() =>
      _TerritoryDetailMapWidgetState();
}

class _TerritoryDetailMapWidgetState extends State<TerritoryDetailMapWidget> {
  MapboxMap? _mapboxMap;
  PolygonAnnotationManager? _polygonManager;
  PolylineAnnotationManager? _polylineManager;

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();

    await _addTerritoryPolygon();
    await Future.delayed(const Duration(milliseconds: 200));
    _fitToTerritory();
  }

  Future<void> _addTerritoryPolygon() async {
    if (_polygonManager == null || _polylineManager == null) return;

    final coords = _parseGeometry(widget.territory.geometry);
    if (coords.isEmpty) return;

    // Add filled polygon
    final polygonOptions = PolygonAnnotationOptions(
      geometry: Polygon(coordinates: [coords]),
      fillColor: AppColors.primary.toARGB32(),
      fillOpacity: 0.25,
    );
    await _polygonManager!.create(polygonOptions);

    // Add boundary line for visibility
    final lineCoords = List<Position>.from(coords);
    if (lineCoords.isNotEmpty && lineCoords.first != lineCoords.last) {
      lineCoords.add(lineCoords.first);
    }

    final lineOptions = PolylineAnnotationOptions(
      geometry: LineString(coordinates: lineCoords),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 3.0,
      lineOpacity: 0.9,
    );
    await _polylineManager!.create(lineOptions);
  }

  void _fitToTerritory() {
    final coords = _parseGeometry(widget.territory.geometry);
    if (coords.isEmpty || _mapboxMap == null) return;

    final bounds = _calculateBoundsFromCoords(coords);
    if (bounds != null) {
      _mapboxMap!
          .cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
        null, // bearing
        null, // pitch
        null, // maxZoom
        null, // offset
      )
          .then((cameraOptions) {
        _mapboxMap!.setCamera(cameraOptions);
      });
    }
  }

  CoordinateBounds? _calculateBoundsFromCoords(List<Position> coords) {
    if (coords.isEmpty) return null;

    double minLat = coords[0].lat.toDouble();
    double maxLat = coords[0].lat.toDouble();
    double minLng = coords[0].lng.toDouble();
    double maxLng = coords[0].lng.toDouble();

    for (final coord in coords) {
      if (coord.lat < minLat) minLat = coord.lat.toDouble();
      if (coord.lat > maxLat) maxLat = coord.lat.toDouble();
      if (coord.lng < minLng) minLng = coord.lng.toDouble();
      if (coord.lng > maxLng) maxLng = coord.lng.toDouble();
    }

    return CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
  }

  void _zoomIn() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: (currentCamera.zoom) + 1,
      ));
    }
  }

  void _zoomOut() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: math.max(1, (currentCamera.zoom) - 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final center = _getTerritoryCenter(_parseGeometry(widget.territory.geometry));

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            MapWidget(
              key: ValueKey('detailMap_${widget.territory.id}'),
              styleUri: MapConstants.getThemedStyleUri(isDark),
              cameraOptions: CameraOptions(
                center: center,
                zoom: 12,
              ),
              onMapCreated: (mapboxMap) async {
                // Enable all gestures
                await mapboxMap.gestures.updateSettings(GesturesSettings(
                  scrollEnabled: true,
                  rotateEnabled: true,
                  pinchToZoomEnabled: true,
                  doubleTapToZoomInEnabled: true,
                  doubleTouchToZoomOutEnabled: true,
                  quickZoomEnabled: true,
                  pitchEnabled: true,
                  simultaneousRotateAndPinchToZoomEnabled: true,
                ));
                _onMapCreated(mapboxMap);
              },
            ),
            // Zoom controls
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _SmallZoomButton(icon: Icons.remove, onPressed: _zoomOut),
                  const SizedBox(width: 4),
                  _SmallZoomButton(icon: Icons.add, onPressed: _zoomIn),
                  const SizedBox(width: 4),
                  _SmallZoomButton(
                    icon: Icons.center_focus_strong,
                    onPressed: _fitToTerritory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Position> _parseGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map<Position>((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map<Position>((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('Error parsing geometry: $e');
    }

    return [];
  }

  Point _getTerritoryCenter(List<Position> coords) {
    if (coords.isEmpty) {
      return Point(
          coordinates: Position(
              MapConstants.defaultLongitude, MapConstants.defaultLatitude));
    }

    double sumLat = 0, sumLng = 0;
    for (final coord in coords) {
      sumLat += coord.lat;
      sumLng += coord.lng;
    }

    return Point(
        coordinates: Position(sumLng / coords.length, sumLat / coords.length));
  }
}

class _SmallZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallZoomButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Icon(icon, size: 18, color: AppColors.textPrimaryLight),
        ),
      ),
    );
  }
}
