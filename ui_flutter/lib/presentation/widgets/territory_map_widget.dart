import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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

  /// List of visit markers to display on the map
  final List<VisitMarker> visitMarkers;

  /// Whether to allow adding new visit markers via long-press
  final bool allowAddVisit;

  /// Callback when user long-presses to add a visit location
  final Function(double latitude, double longitude)? onAddVisit;

  /// Force fit camera to territories bounds (e.g., after search)
  final bool fitToTerritories;

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
  });

  @override
  State<TerritoryMapWidget> createState() => _TerritoryMapWidgetState();
}

class _TerritoryMapWidgetState extends State<TerritoryMapWidget> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  // Color palette for different territories to make boundaries distinguishable
  static const List<Color> _territoryColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
    Color(0xFFCDDC39), // Lime
  ];

  bool _hasInitiallyFitTerritories = false;

  // Cache parsed geometries to avoid repeated parsing
  final Map<String, List<LatLng>> _geometryCache = {};

  @override
  void initState() {
    super.initState();
    // Fit to bounds after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToAllTerritories();
    });
  }

  @override
  void didUpdateWidget(TerritoryMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear geometry cache if territories changed
    if (_territoriesChanged(oldWidget.territories, widget.territories)) {
      _geometryCache.clear();
    }

    // Fit to territories when:
    // 1. Territories were empty and now have data (initial load)
    // 2. Territory IDs actually changed
    // 3. fitToTerritories flag changed from false to true (search results)
    final wasEmpty = oldWidget.territories.isEmpty;
    final nowHasData = widget.territories.isNotEmpty;
    final fitRequested = widget.fitToTerritories && !oldWidget.fitToTerritories;

    if (_isMapReady) {
      if (fitRequested ||
          (wasEmpty && nowHasData) ||
          (!_hasInitiallyFitTerritories && nowHasData) ||
          (widget.fitToTerritories && _territoriesChanged(oldWidget.territories, widget.territories))) {
        _fitToAllTerritories();
        _hasInitiallyFitTerritories = true;
      }
    }
  }

  bool _territoriesChanged(List<GeoTerritory> oldList, List<GeoTerritory> newList) {
    if (oldList.isEmpty && newList.isEmpty) return false;
    if (oldList.length != newList.length) return true;
    final oldIds = oldList.map((t) => t.id).toSet();
    final newIds = newList.map((t) => t.id).toSet();
    return !oldIds.containsAll(newIds) || !newIds.containsAll(oldIds);
  }

  void _fitToAllTerritories() {
    final bounds = _calculateBounds();
    if (bounds != null && _isMapReady) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
      _hasInitiallyFitTerritories = true;
    } else if (_isMapReady && !_hasInitiallyFitTerritories) {
      // No valid bounds, ensure we show US center
      _mapController.move(const LatLng(39.8283, -98.5795), 4);
      _hasInitiallyFitTerritories = true;
    }
  }

  void _focusOnTerritory(GeoTerritory territory) {
    final coords = _parseGeometryForTerritory(territory);
    if (coords.isEmpty) return;

    final bounds = _calculateBoundsFromCoords(coords);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(30),
        ),
      );
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  LatLngBounds? _calculateBounds() {
    if (widget.territories.isEmpty) return null;

    double? minLat, maxLat, minLng, maxLng;

    for (final territory in widget.territories) {
      final coords = _parseGeometryForTerritory(territory);

      for (final coord in coords) {
        // Skip invalid coordinates (0, 0 or very close)
        if (coord.latitude.abs() < 0.1 && coord.longitude.abs() < 0.1) continue;

        if (minLat == null || coord.latitude < minLat) minLat = coord.latitude;
        if (maxLat == null || coord.latitude > maxLat) maxLat = coord.latitude;
        if (minLng == null || coord.longitude < minLng) minLng = coord.longitude;
        if (maxLng == null || coord.longitude > maxLng) maxLng = coord.longitude;
      }
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
      return null;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  LatLngBounds? _calculateBoundsFromCoords(List<LatLng> coords) {
    if (coords.isEmpty) return null;

    double minLat = coords[0].latitude;
    double maxLat = coords[0].latitude;
    double minLng = coords[0].longitude;
    double maxLng = coords[0].longitude;

    for (final coord in coords) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polygons = _buildPolygons();
    final markers = widget.showLabels ? _buildMarkers() : <Marker>[];

    // Default center (US center) - will be overridden by fitBounds
    const defaultCenter = LatLng(39.8283, -98.5795);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: defaultCenter,
            initialZoom: 4,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: () {
              setState(() => _isMapReady = true);
              // Fit to territories after a short delay to ensure tiles are loaded
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _fitToAllTerritories();
                }
              });
            },
            onTap: (tapPosition, point) {
              // Check if tapped on any territory
              for (final territory in widget.territories) {
                if (_isPointInTerritory(point, territory)) {
                  widget.onTerritoryTap?.call(territory);
                  break;
                }
              }
            },
            onLongPress: widget.allowAddVisit
                ? (tapPosition, point) {
                    widget.onAddVisit?.call(point.latitude, point.longitude);
                  }
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: MapConstants.getThemedTileUrl(
                Theme.of(context).brightness == Brightness.dark,
              ),
              userAgentPackageName: 'com.rallypoint.app',
              keepBuffer: 5,
              panBuffer: 1,
            ),
            PolygonLayer(polygons: polygons),
            MarkerLayer(markers: [...markers, ..._buildVisitMarkers()]),
          ],
        ),

        // Zoom Controls
        if (widget.showZoomControls)
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                ),
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

  List<Polygon> _buildPolygons() {
    final polygons = <Polygon>[];

    for (int i = 0; i < widget.territories.length; i++) {
      final territory = widget.territories[i];
      final coords = _parseGeometryForTerritory(territory);
      if (coords.isEmpty) continue;

      final isSelected = widget.selectedTerritory?.id == territory.id;
      final colorIndex = i % _territoryColors.length;
      final baseColor = isSelected ? AppColors.primary : _territoryColors[colorIndex];

      polygons.add(Polygon(
        points: coords,
        color: baseColor.withAlpha(isSelected ? 100 : 50),
        borderColor: baseColor,
        borderStrokeWidth: isSelected ? 4.0 : 2.5,
        isFilled: true,
      ));
    }

    return polygons;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final territory in widget.territories) {
      final center = _getTerritoryCenter(territory);
      if (center == null) continue;

      final isSelected = widget.selectedTerritory?.id == territory.id;

      markers.add(Marker(
        point: center,
        width: 120,
        height: 32,
        child: GestureDetector(
          onTap: () {
            widget.onTerritoryTap?.call(territory);
            _focusOnTerritory(territory);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.secondary,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              territory.solid,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  List<Marker> _buildVisitMarkers() {
    final markers = <Marker>[];

    for (final visit in widget.visitMarkers) {
      Color markerColor;
      IconData markerIcon;

      // Color code by outcome
      switch (visit.outcome.toLowerCase()) {
        case 'interested':
        case 'positive':
          markerColor = AppColors.success;
          markerIcon = Icons.check_circle;
          break;
        case 'not_home':
        case 'not home':
          markerColor = AppColors.warning;
          markerIcon = Icons.home_outlined;
          break;
        case 'not_interested':
        case 'not interested':
          markerColor = AppColors.error;
          markerIcon = Icons.cancel;
          break;
        case 'callback':
        case 'follow_up':
          markerColor = AppColors.info;
          markerIcon = Icons.schedule;
          break;
        default:
          markerColor = AppColors.secondary;
          markerIcon = Icons.location_on;
      }

      markers.add(Marker(
        point: LatLng(visit.latitude, visit.longitude),
        width: 36,
        height: 36,
        child: Tooltip(
          message: '${visit.address ?? "Visit"}\n${visit.outcome}',
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              markerIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  /// Parse geometry with caching to avoid repeated parsing
  List<LatLng> _parseGeometryForTerritory(GeoTerritory territory) {
    // Check cache first
    if (_geometryCache.containsKey(territory.id)) {
      return _geometryCache[territory.id]!;
    }

    final coords = _parseGeometryRaw(territory.geometry);
    _geometryCache[territory.id] = coords;
    return coords;
  }

  List<LatLng> _parseGeometryRaw(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map<LatLng>((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map<LatLng>((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('TerritoryMapWidget: Error parsing geometry: $e');
    }

    return [];
  }

  LatLng? _getTerritoryCenter(GeoTerritory territory) {
    final coords = _parseGeometryForTerritory(territory);
    if (coords.isEmpty) return null;

    double sumLat = 0, sumLng = 0;
    for (final coord in coords) {
      sumLat += coord.latitude;
      sumLng += coord.longitude;
    }

    return LatLng(sumLat / coords.length, sumLng / coords.length);
  }

  bool _isPointInTerritory(LatLng point, GeoTerritory territory) {
    final coords = _parseGeometryForTerritory(territory);
    if (coords.isEmpty) return false;

    bool inside = false;
    int j = coords.length - 1;

    for (int i = 0; i < coords.length; j = i++) {
      final xi = coords[i].longitude;
      final yi = coords[i].latitude;
      final xj = coords[j].longitude;
      final yj = coords[j].latitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
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
  State<TerritoryDetailMapWidget> createState() => _TerritoryDetailMapWidgetState();
}

class _TerritoryDetailMapWidgetState extends State<TerritoryDetailMapWidget> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToTerritory();
    });
  }

  void _fitToTerritory() {
    final coords = _parseGeometry(widget.territory.geometry);
    if (coords.isEmpty || !_isMapReady) return;

    final bounds = _calculateBoundsFromCoords(coords);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    }
  }

  LatLngBounds? _calculateBoundsFromCoords(List<LatLng> coords) {
    if (coords.isEmpty) return null;

    double minLat = coords[0].latitude;
    double maxLat = coords[0].latitude;
    double minLng = coords[0].longitude;
    double maxLng = coords[0].longitude;

    for (final coord in coords) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    // Add some padding to the bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coords = _parseGeometry(widget.territory.geometry);
    final center = _getTerritoryCenter(coords);

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                minZoom: 5,
                maxZoom: 18,
                onMapReady: () {
                  setState(() => _isMapReady = true);
                  _fitToTerritory();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.getThemedTileUrl(
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                  userAgentPackageName: 'com.rallypoint.app',
                ),
                if (coords.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: coords,
                        color: AppColors.primary.withAlpha(80),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 3.0,
                        isFilled: true,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 180,
                      height: 45,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(50),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.territory.entityName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'ID: ${widget.territory.solid}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Zoom controls for detail view
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  _SmallZoomButton(
                    icon: Icons.remove,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                  ),
                  const SizedBox(width: 4),
                  _SmallZoomButton(
                    icon: Icons.add,
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                  ),
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

  List<LatLng> _parseGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map<LatLng>((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map<LatLng>((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('Error parsing geometry: $e');
    }

    return [];
  }

  LatLng _getTerritoryCenter(List<LatLng> coords) {
    if (coords.isEmpty) {
      return const LatLng(39.8283, -98.5795);
    }

    double sumLat = 0, sumLng = 0;
    for (final coord in coords) {
      sumLat += coord.latitude;
      sumLng += coord.longitude;
    }

    return LatLng(sumLat / coords.length, sumLng / coords.length);
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
