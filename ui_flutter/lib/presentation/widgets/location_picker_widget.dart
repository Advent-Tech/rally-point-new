import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/map_constants.dart';

// Type alias for clarity
typedef MapPosition = Position;

/// Territory boundary data for displaying on the map
class TerritoryBoundary {
  final String? name;
  final Map<String, dynamic>? geometry;
  final Color? color;

  const TerritoryBoundary({
    this.name,
    this.geometry,
    this.color,
  });
}

/// A widget that allows users to pick a location on a map
class LocationPickerWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final double initialZoom;
  final double height;
  final Function(double latitude, double longitude)? onLocationSelected;
  final bool compact;
  final bool showConfirmButton;
  final String confirmButtonLabel;
  final List<TerritoryBoundary> territories;
  final bool warnOutsideTerritory;

  const LocationPickerWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialZoom = 16.0,
    this.height = 200,
    this.onLocationSelected,
    this.compact = false,
    this.showConfirmButton = false,
    this.confirmButtonLabel = 'Confirm Location',
    this.territories = const [],
    this.warnOutsideTerritory = true,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  MapboxMap? _mapboxMap;
  PolygonAnnotationManager? _polygonManager;
  CircleAnnotationManager? _circleManager;
  Position? _selectedLocation;
  Position? _currentLocation;
  bool _isExpanded = false;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _isOutsideTerritory = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = Position(widget.initialLongitude!, widget.initialLatitude!);
      _currentLocation = _selectedLocation;
      _isLoadingLocation = false;
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentLocation = Position(position.longitude, position.latitude);
        _isLoadingLocation = false;
      });

      if (_mapboxMap != null && _isMapReady) {
        _mapboxMap!.setCamera(CameraOptions(
          center: Point(coordinates: _currentLocation!),
          zoom: widget.initialZoom,
        ));
      }
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location';
        _isLoadingLocation = false;
      });
    }
  }

  Point get _center {
    if (_selectedLocation != null) {
      return Point(coordinates: _selectedLocation!);
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return Point(coordinates: Position(widget.initialLongitude!, widget.initialLatitude!));
    }
    final territoryCenter = _getTerritoryCenter();
    if (territoryCenter != null) {
      return territoryCenter;
    }
    if (_currentLocation != null) {
      return Point(coordinates: _currentLocation!);
    }
    return Point(coordinates: Position(MapConstants.defaultLongitude, MapConstants.defaultLatitude));
  }

  double get _initialZoom {
    if (widget.territories.isNotEmpty) return 13.0;
    if (_selectedLocation != null || _currentLocation != null) return widget.initialZoom;
    return 4.0;
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();
    _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();

    setState(() => _isMapReady = true);

    await _updateTerritoryPolygons();
    await _updateLocationMarkers();
  }

  Future<void> _updateTerritoryPolygons() async {
    if (_polygonManager == null) return;

    await _polygonManager!.deleteAll();

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      if (points.isEmpty) continue;

      final color = territory.color ?? AppColors.primary;
      final options = PolygonAnnotationOptions(
        geometry: Polygon(coordinates: [points]),
        fillColor: color.toARGB32(),
        fillOpacity: 0.15,
        fillOutlineColor: color.toARGB32(),
      );

      await _polygonManager!.create(options);
    }
  }

  Future<void> _updateLocationMarkers() async {
    if (_circleManager == null) return;

    await _circleManager!.deleteAll();

    // Current location marker (blue)
    if (_currentLocation != null && _selectedLocation == null) {
      await _circleManager!.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _currentLocation!),
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 10,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ));
    }

    // Selected location marker (red)
    if (_selectedLocation != null) {
      await _circleManager!.create(CircleAnnotationOptions(
        geometry: Point(coordinates: _selectedLocation!),
        circleColor: AppColors.error.toARGB32(),
        circleRadius: 12,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ));
    }
  }

  List<Position> _parseGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map((coord) {
          final c = coord as List;
          return Position(c[0].toDouble(), c[1].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('Error parsing geometry: $e');
    }

    return [];
  }

  bool _isPointInTerritories(Position point) {
    if (widget.territories.isEmpty) return true;

    for (final territory in widget.territories) {
      final polygon = _parseGeometry(territory.geometry);
      if (polygon.isEmpty) continue;

      if (_isPointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(Position point, List<Position> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].lng;
      final yi = polygon[i].lat;
      final xj = polygon[j].lng;
      final yj = polygon[j].lat;

      if (((yi > point.lat) != (yj > point.lat)) &&
          (point.lng < (xj - xi) * (point.lat - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  Point? _getTerritoryCenter() {
    if (widget.territories.isEmpty) return null;

    double sumLat = 0;
    double sumLng = 0;
    int count = 0;

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      for (final point in points) {
        sumLat += point.lat;
        sumLng += point.lng;
        count++;
      }
    }

    if (count == 0) return null;
    return Point(coordinates: Position(sumLng / count, sumLat / count));
  }

  void _zoomToFitTerritories() {
    if (widget.territories.isEmpty || _mapboxMap == null) return;

    double minLat = 90, maxLat = -90;
    double minLng = 180, maxLng = -180;

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      for (final point in points) {
        if (point.lat.toDouble() < minLat) minLat = point.lat.toDouble();
        if (point.lat.toDouble() > maxLat) maxLat = point.lat.toDouble();
        if (point.lng.toDouble() < minLng) minLng = point.lng.toDouble();
        if (point.lng.toDouble() > maxLng) maxLng = point.lng.toDouble();
      }
    }

    if (minLat == 90) return;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    _mapboxMap!.cameraForCoordinateBounds(
      bounds,
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      null, // bearing
      null, // pitch
      null, // maxZoom
      null, // offset
    ).then((cameraOptions) {
      _mapboxMap!.setCamera(cameraOptions);
    });
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
    final mapHeight = _isExpanded ? 350.0 : widget.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.compact)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedLocation != null
                          ? 'Location: ${_selectedLocation!.lat.toStringAsFixed(5)}, ${_selectedLocation!.lng.toStringAsFixed(5)}'
                          : 'Tap to select location on map',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

        if (!widget.compact || _isExpanded)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: mapHeight,
                child: Stack(
                  children: [
                    MapWidget(
                      key: const ValueKey('locationPickerMap'),
                      styleUri: MapConstants.getThemedStyleUri(isDark),
                      cameraOptions: CameraOptions(
                        center: _center,
                        zoom: _initialZoom,
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
                      onTapListener: (context) {
                        final point = context.point;
                        final position = point.coordinates;
                        final isInside = _isPointInTerritories(position);
                        setState(() {
                          _selectedLocation = position;
                          _isOutsideTerritory = !isInside;
                        });
                        _updateLocationMarkers();
                        widget.onLocationSelected?.call(position.lat.toDouble(), position.lng.toDouble());
                      },
                    ),

                    if (_isLoadingLocation)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withAlpha(200),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Getting your location...',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_selectedLocation == null && !_isLoadingLocation)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(180),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app, size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Tap to select delivery location',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_selectedLocation != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(30),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text(
                                '${_selectedLocation!.lat.toStringAsFixed(5)}, ${_selectedLocation!.lng.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          _ZoomButton(icon: Icons.add, onPressed: _zoomIn),
                          const SizedBox(height: 4),
                          _ZoomButton(icon: Icons.remove, onPressed: _zoomOut),
                          const SizedBox(height: 8),
                          _ZoomButton(
                            icon: Icons.my_location,
                            onPressed: () {
                              if (_currentLocation != null) {
                                _mapboxMap?.setCamera(CameraOptions(
                                  center: Point(coordinates: _currentLocation!),
                                  zoom: widget.initialZoom,
                                ));
                              } else {
                                _getCurrentLocation();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    if (_selectedLocation != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedLocation = null);
                              _updateLocationMarkers();
                              widget.onLocationSelected?.call(0, 0);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.clear, size: 16, color: AppColors.error),
                                  SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(color: AppColors.error, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_locationError != null && !_isLoadingLocation)
                      Positioned(
                        left: 8,
                        bottom: 50,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(230),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                _locationError!,
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isOutsideTerritory && widget.warnOutsideTerritory && _selectedLocation != null)
                      Positioned(
                        left: 8,
                        bottom: 50,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(230),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber, size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Location is outside your assigned territory',
                                style: TextStyle(fontSize: 11, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.territories.isNotEmpty)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: _zoomToFitTerritories,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(200),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.map_outlined, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.territories.length} territory${widget.territories.length > 1 ? 'ies' : ''}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.zoom_out_map, size: 12, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        if (widget.showConfirmButton && _selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onLocationSelected?.call(
                    _selectedLocation!.lat.toDouble(),
                    _selectedLocation!.lng.toDouble(),
                  );
                },
                icon: const Icon(Icons.check),
                label: Text(widget.confirmButtonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ZoomButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.textPrimaryLight),
        ),
      ),
    );
  }
}
