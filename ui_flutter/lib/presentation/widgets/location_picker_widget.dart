import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/map_constants.dart';

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
  /// Initial latitude (defaults to current location or US center if null)
  final double? initialLatitude;

  /// Initial longitude (defaults to current location or US center if null)
  final double? initialLongitude;

  /// Initial zoom level
  final double initialZoom;

  /// Height of the map widget
  final double height;

  /// Callback when location is selected
  final Function(double latitude, double longitude)? onLocationSelected;

  /// Whether the picker is in compact mode (smaller size)
  final bool compact;

  /// Show a confirmation button
  final bool showConfirmButton;

  /// Label for the confirm button
  final String confirmButtonLabel;

  /// Territory boundaries to display on the map
  final List<TerritoryBoundary> territories;

  /// Whether to show a warning when selecting outside territory
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
  late MapController _mapController;
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isExpanded = false;
  bool _isLoadingLocation = true;
  String? _locationError;
  bool _isOutsideTerritory = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
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
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move map to current location
      if (_mapController.camera.center.latitude != 0) {
        _mapController.move(_currentLocation!, widget.initialZoom);
      }
    } catch (e) {
      setState(() {
        _locationError = 'Could not get location';
        _isLoadingLocation = false;
      });
    }
  }

  LatLng get _center {
    if (_selectedLocation != null) {
      return _selectedLocation!;
    }
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      return LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    // Prioritize territory center over current location so map shows territories
    final territoryCenter = _getTerritoryCenter();
    if (territoryCenter != null) {
      return territoryCenter;
    }
    if (_currentLocation != null) {
      return _currentLocation!;
    }
    // Default to US center if no location available
    return const LatLng(39.8283, -98.5795);
  }

  double get _initialZoom {
    // If we have territories, use zoom that fits them
    if (widget.territories.isNotEmpty) {
      return 13.0;
    }
    if (_selectedLocation != null || _currentLocation != null) {
      return widget.initialZoom;
    }
    return 4.0; // Zoomed out if no location
  }

  /// Parse geometry from GeoJSON format to list of LatLng points
  List<LatLng> _parseGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return [];

    try {
      final type = geometry['type'] as String?;
      final coordinates = geometry['coordinates'];

      if (coordinates == null) return [];

      if (type == 'Polygon') {
        final ring = coordinates[0] as List;
        return ring.map((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      } else if (type == 'MultiPolygon') {
        // For MultiPolygon, just use the first polygon
        final firstPolygon = coordinates[0] as List;
        final ring = firstPolygon[0] as List;
        return ring.map((coord) {
          final c = coord as List;
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();
      }
    } catch (e) {
      debugPrint('Error parsing geometry: $e');
    }

    return [];
  }

  /// Build polygon layers for territories
  List<Polygon> _buildTerritoryPolygons() {
    final polygons = <Polygon>[];

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      if (points.isEmpty) continue;

      final color = territory.color ?? AppColors.primary;
      polygons.add(Polygon(
        points: points,
        color: color.withAlpha(40),
        borderColor: color,
        borderStrokeWidth: 2.0,
        isFilled: true,
      ));
    }

    return polygons;
  }

  /// Check if a point is inside any of the territories using ray casting algorithm
  bool _isPointInTerritories(LatLng point) {
    if (widget.territories.isEmpty) return true; // No territories = always valid

    for (final territory in widget.territories) {
      final polygon = _parseGeometry(territory.geometry);
      if (polygon.isEmpty) continue;

      if (_isPointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }

  /// Ray casting algorithm to check if point is inside polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      if (((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Get center of all territories for initial map position
  LatLng? _getTerritoryCenter() {
    if (widget.territories.isEmpty) return null;

    double sumLat = 0;
    double sumLng = 0;
    int count = 0;

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      for (final point in points) {
        sumLat += point.latitude;
        sumLng += point.longitude;
        count++;
      }
    }

    if (count == 0) return null;
    return LatLng(sumLat / count, sumLng / count);
  }

  /// Zoom to fit all territories in view
  void _zoomToFitTerritories() {
    if (widget.territories.isEmpty) return;

    double minLat = 90, maxLat = -90;
    double minLng = 180, maxLng = -180;

    for (final territory in widget.territories) {
      final points = _parseGeometry(territory.geometry);
      for (final point in points) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
    }

    if (minLat == 90) return; // No valid points found

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Calculate zoom level to fit bounds (approximate)
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 14.0;
    if (maxDiff > 0.5) zoom = 10.0;
    else if (maxDiff > 0.2) zoom = 11.0;
    else if (maxDiff > 0.1) zoom = 12.0;
    else if (maxDiff > 0.05) zoom = 13.0;
    else if (maxDiff > 0.02) zoom = 14.0;
    else zoom = 15.0;

    _mapController.move(center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final mapHeight = _isExpanded ? 350.0 : widget.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand toggle
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
                          ? 'Location: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}'
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

        // Map
        if (!widget.compact || _isExpanded)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: mapHeight,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _initialZoom,
                        onMapReady: () {
                          // Move to current location when map is ready
                          if (_currentLocation != null) {
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) {
                                _mapController.move(_currentLocation!, _initialZoom);
                              }
                            });
                          }
                        },
                        onTap: (tapPosition, point) {
                          final isInside = _isPointInTerritories(point);
                          setState(() {
                            _selectedLocation = point;
                            _isOutsideTerritory = !isInside;
                          });
                          widget.onLocationSelected?.call(point.latitude, point.longitude);
                        },
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
                        // Territory polygon layer
                        if (widget.territories.isNotEmpty)
                          PolygonLayer(polygons: _buildTerritoryPolygons()),
                        MarkerLayer(
                          markers: [
                            // Current location marker (blue)
                            if (_currentLocation != null && _selectedLocation == null)
                              Marker(
                                point: _currentLocation!,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withAlpha(100),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Selected location marker (red pin)
                            if (_selectedLocation != null)
                              Marker(
                                point: _selectedLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: AppColors.error,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Loading overlay
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

                    // Hint overlay
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

                    // Selected location info
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
                                '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Zoom controls and My Location button
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Column(
                        children: [
                          _ZoomButton(
                            icon: Icons.add,
                            onPressed: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(_mapController.camera.center, currentZoom + 1);
                            },
                          ),
                          const SizedBox(height: 4),
                          _ZoomButton(
                            icon: Icons.remove,
                            onPressed: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(_mapController.camera.center, currentZoom - 1);
                            },
                          ),
                          const SizedBox(height: 8),
                          // My Location button
                          _ZoomButton(
                            icon: Icons.my_location,
                            onPressed: () {
                              if (_currentLocation != null) {
                                _mapController.move(_currentLocation!, widget.initialZoom);
                              } else {
                                _getCurrentLocation();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // Clear button
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

                    // Location error message
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

                    // Outside territory warning
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

                    // Territory info badge - clickable to zoom to fit all territories
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

        // Confirm button
        if (widget.showConfirmButton && _selectedLocation != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onLocationSelected?.call(
                    _selectedLocation!.latitude,
                    _selectedLocation!.longitude,
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
