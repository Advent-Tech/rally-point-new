import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/map_constants.dart';
import '../../../data/models/territory_model.dart';

class CreateTerritoryScreen extends StatefulWidget {
  final GeoTerritory? existingTerritory;

  const CreateTerritoryScreen({super.key, this.existingTerritory});

  @override
  State<CreateTerritoryScreen> createState() => _CreateTerritoryScreenState();
}

class _CreateTerritoryScreenState extends State<CreateTerritoryScreen> {
  final MapController _mapController = MapController();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _entityNameController = TextEditingController();
  final _entityIdController = TextEditingController();
  final _unionNameController = TextEditingController();
  final _conferenceController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipcodeController = TextEditingController();
  final _populationController = TextEditingController();
  final _housingUnitsController = TextEditingController();

  // Search
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  // Polygon drawing
  List<LatLng> _polygonPoints = [];
  bool _isPolygonClosed = false;
  bool _isDrawingMode = true;
  String? _selfIntersectionError;

  // Validation
  bool _isValidating = false;
  bool? _isGeometryValid;
  String? _validationReason;
  List<String> _overlappingIds = [];

  // Existing territories for background display
  final Map<String, GeoTerritory> _existingTerritories = {};
  final Set<String> _loadedGridCells = {};
  static const double _gridCellSize = 0.15;
  Timer? _loadDebounceTimer;
  bool _isMapReady = false;

  // Save state
  bool _isSaving = false;

  bool get _isEditMode => widget.existingTerritory != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _prefillForm();
    }
  }

  @override
  void dispose() {
    _entityNameController.dispose();
    _entityIdController.dispose();
    _unionNameController.dispose();
    _conferenceController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipcodeController.dispose();
    _populationController.dispose();
    _housingUnitsController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  void _prefillForm() {
    final t = widget.existingTerritory!;
    _entityNameController.text = t.entityName;
    _entityIdController.text = t.solid; // entityId maps to solid in GeoTerritory
    _unionNameController.text = t.unionName ?? '';
    _conferenceController.text = t.conferenceName ?? '';

    // Parse existing geometry into polygon points
    if (t.geometry != null) {
      final coords = _parseGeometry(t.geometry!);
      if (coords.isNotEmpty) {
        _polygonPoints = coords;
        _isPolygonClosed = true;
        _isDrawingMode = false;
      }
    }
  }

  List<LatLng> _parseGeometry(Map<String, dynamic> geometry) {
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

  // --- Geocoding Search ---

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _performGeocode(query);
    });
  }

  Future<void> _performGeocode(String query) async {
    try {
      final url = MapConstants.getGeocodingUrl(query);
      final response = await Dio().get(url);
      if (response.statusCode == 200 && mounted) {
        final features = response.data['features'] as List? ?? [];
        setState(() {
          _searchResults = features.map<Map<String, dynamic>>((f) {
            final center = f['center'] as List;
            return {
              'name': f['place_name'] as String? ?? '',
              'lat': (center[1] as num).toDouble(),
              'lng': (center[0] as num).toDouble(),
            };
          }).toList();
          _showSearchResults = _searchResults.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  void _onSearchResultTap(Map<String, dynamic> result) {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    _mapController.move(LatLng(lat, lng), 14);
    setState(() {
      _showSearchResults = false;
      _searchController.clear();
    });
  }

  // --- Polygon Drawing ---

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!_isDrawingMode || _isPolygonClosed) return;

    setState(() {
      _polygonPoints.add(point);
      _selfIntersectionError = null;
    });

    // Check for self-intersection with 4+ points
    if (_polygonPoints.length >= 4) {
      if (_checkSelfIntersection(_polygonPoints)) {
        setState(() {
          _selfIntersectionError = 'Edges cross — undo last point';
        });
      }
    }
  }

  void _undoLastPoint() {
    if (_polygonPoints.isEmpty || _isPolygonClosed) return;
    setState(() {
      _polygonPoints.removeLast();
      _selfIntersectionError = null;
      _isGeometryValid = null;
      _validationReason = null;
      _overlappingIds = [];
    });
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _isPolygonClosed = false;
      _isDrawingMode = true;
      _selfIntersectionError = null;
      _isGeometryValid = null;
      _validationReason = null;
      _overlappingIds = [];
    });
  }

  void _closePolygon() {
    if (_polygonPoints.length < 3) return;

    // Check self-intersection before closing
    final testPoints = [..._polygonPoints, _polygonPoints.first];
    if (_checkSelfIntersection(testPoints)) {
      setState(() {
        _selfIntersectionError = 'Cannot close — polygon would self-intersect';
      });
      return;
    }

    setState(() {
      _isPolygonClosed = true;
      _isDrawingMode = false;
      _selfIntersectionError = null;
    });

    _validateGeometryOnServer();
  }

  // --- Self-Intersection Check (Cross-product algorithm) ---

  bool _checkSelfIntersection(List<LatLng> points) {
    final n = points.length;
    if (n < 4) return false;

    for (int i = 0; i < n - 1; i++) {
      for (int j = i + 2; j < n - 1; j++) {
        // Skip adjacent segments
        if (i == 0 && j == n - 2) continue;
        if (_segmentsIntersect(
          points[i], points[i + 1],
          points[j], points[j + 1],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  bool _segmentsIntersect(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
    final d1 = _cross(b1, b2, a1);
    final d2 = _cross(b1, b2, a2);
    final d3 = _cross(a1, a2, b1);
    final d4 = _cross(a1, a2, b2);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  double _cross(LatLng o, LatLng a, LatLng b) {
    return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
  }

  // --- Server Validation ---

  Future<void> _validateGeometryOnServer() async {
    if (_polygonPoints.length < 3 || !_isPolygonClosed) return;

    setState(() => _isValidating = true);

    try {
      final geojson = _buildGeoJSON();
      final api = await ApiClient.getInstance();
      final response = await api.post(
        ApiConstants.validateGeometry,
        data: {'geometry': geojson},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _isGeometryValid = response.data['is_valid'] as bool? ?? false;
          _validationReason = response.data['reason'] as String?;
          final overlaps = response.data['overlapping_ids'] as List?;
          _overlappingIds = overlaps?.map((e) => e.toString()).toList() ?? [];
        });
      }
    } catch (e) {
      debugPrint('Validation error: $e');
      if (mounted) {
        setState(() {
          _isGeometryValid = null;
          _validationReason = 'Validation failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Map<String, dynamic> _buildGeoJSON() {
    final coords = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
    // Close the ring
    if (coords.isNotEmpty && (coords.first[0] != coords.last[0] || coords.first[1] != coords.last[1])) {
      coords.add([coords.first[0], coords.first[1]]);
    }
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  // --- Load Existing Territories ---

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadExistingTerritories();
    });
  }

  Future<void> _loadExistingTerritories() async {
    if (!_isMapReady) return;

    final bounds = _mapController.camera.visibleBounds;
    final cells = _getGridCellsForBounds(bounds);
    final newCells = cells.where((c) => !_loadedGridCells.contains(c)).toList();
    if (newCells.isEmpty) return;

    try {
      final api = await ApiClient.getInstance();
      final boundsStr =
          '${bounds.west.toStringAsFixed(4)},${bounds.south.toStringAsFixed(4)},${bounds.east.toStringAsFixed(4)},${bounds.north.toStringAsFixed(4)}';
      final url =
          '${ApiConstants.territories}?bounds=$boundsStr&limit=100&zoom=${_mapController.camera.zoom.round()}';
      final response = await api.get(url);

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        List<GeoTerritory> territories = [];

        if (data is Map && data['features'] != null) {
          final features = data['features'] as List;
          territories = features.map((feature) {
            final props = Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
            props['id'] = feature['id'];
            props['geometry'] = feature['geometry'];
            return GeoTerritory.fromJson(props);
          }).toList();
        }

        for (final t in territories) {
          if (t.id.isNotEmpty) {
            _existingTerritories[t.id] = t;
          }
        }
        _loadedGridCells.addAll(newCells);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load existing territories: $e');
    }
  }

  List<String> _getGridCellsForBounds(LatLngBounds bounds) {
    final cells = <String>[];
    final minLat = (bounds.south / _gridCellSize).floor();
    final maxLat = (bounds.north / _gridCellSize).floor();
    final minLng = (bounds.west / _gridCellSize).floor();
    final maxLng = (bounds.east / _gridCellSize).floor();
    for (int lat = minLat; lat <= maxLat; lat++) {
      for (int lng = minLng; lng <= maxLng; lng++) {
        cells.add('$lat,$lng');
      }
    }
    return cells;
  }

  // --- Save ---

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPolygonClosed || _polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw and close a polygon first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final api = await ApiClient.getInstance();
      final geojson = _buildGeoJSON();

      final body = <String, dynamic>{
        'entity_name': _entityNameController.text.trim(),
        'entity_id': _entityIdController.text.trim(),
        'geometry': geojson,
      };

      if (_unionNameController.text.trim().isNotEmpty) {
        body['union_name'] = _unionNameController.text.trim();
      }
      if (_conferenceController.text.trim().isNotEmpty) {
        body['conference'] = _conferenceController.text.trim();
      }
      if (_cityController.text.trim().isNotEmpty) {
        body['city'] = _cityController.text.trim();
      }
      if (_stateController.text.trim().isNotEmpty) {
        body['state'] = _stateController.text.trim();
      }
      if (_zipcodeController.text.trim().isNotEmpty) {
        body['zipcode'] = _zipcodeController.text.trim();
      }
      if (_populationController.text.trim().isNotEmpty) {
        body['population'] = int.tryParse(_populationController.text.trim());
      }
      if (_housingUnitsController.text.trim().isNotEmpty) {
        body['housing_units'] = int.tryParse(_housingUnitsController.text.trim());
      }

      Response response;
      if (_isEditMode) {
        response = await api.put(
          '${ApiConstants.territories}/${widget.existingTerritory!.id}',
          data: body,
        );
      } else {
        response = await api.post(ApiConstants.territories, data: body);
      }

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? 'Territory updated' : 'Territory created'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${response.data}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Build UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Territory' : 'Create Territory'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar
            _buildSearchBar(),
            const SizedBox(height: 12),

            // Map
            _buildMap(),
            const SizedBox(height: 8),

            // Drawing toolbar
            _buildToolbar(),
            const SizedBox(height: 8),

            // Validation status
            _buildValidationStatus(),
            const SizedBox(height: 16),

            // Metadata form
            _buildMetadataForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search location...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _showSearchResults = false;
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: _onSearchChanged,
        ),
        if (_showSearchResults)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 18),
                  title: Text(
                    result['name'] as String,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _onSearchResultTap(result),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMap() {
    final initialCenter = _isEditMode && _polygonPoints.isNotEmpty
        ? _getPolygonCenter(_polygonPoints)
        : const LatLng(39.8283, -98.5795);
    final initialZoom = _isEditMode && _polygonPoints.isNotEmpty ? 14.0 : 4.0;

    return Container(
      height: 450,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: initialZoom,
          minZoom: 3,
          maxZoom: 18,
          onTap: _onMapTap,
          onMapReady: () {
            setState(() => _isMapReady = true);
            Future.delayed(const Duration(milliseconds: 300), _loadExistingTerritories);
          },
          onPositionChanged: _onMapPositionChanged,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConstants.getTileUrl(),
            userAgentPackageName: 'com.rallypoint.admin',
            tileSize: 512,
            zoomOffset: -1,
          ),
          // Existing territories (gray background)
          PolygonLayer(polygons: _buildExistingPolygons()),
          // Drawing polygon
          if (_polygonPoints.length >= 2)
            PolygonLayer(polygons: [_buildDrawingPolygon()]),
          // Vertex markers
          MarkerLayer(markers: _buildVertexMarkers()),
        ],
      ),
    );
  }

  List<Polygon> _buildExistingPolygons() {
    final polygons = <Polygon>[];
    for (final territory in _existingTerritories.values) {
      if (territory.geometry == null) continue;
      // Skip the territory being edited
      if (_isEditMode && territory.id == widget.existingTerritory!.id) continue;

      final coords = _parseGeometry(territory.geometry!);
      if (coords.isEmpty) continue;

      polygons.add(Polygon(
        points: coords,
        color: Colors.grey.withAlpha(60),
        borderColor: Colors.grey.withAlpha(150),
        borderStrokeWidth: 1.0,
      ));
    }
    return polygons;
  }

  Polygon _buildDrawingPolygon() {
    final hasError = _selfIntersectionError != null;
    return Polygon(
      points: _polygonPoints,
      color: hasError
          ? Colors.red.withAlpha(50)
          : AppColors.primary.withAlpha(70),
      borderColor: hasError ? Colors.red : AppColors.primary,
      borderStrokeWidth: 2.5,
    );
  }

  List<Marker> _buildVertexMarkers() {
    final markers = <Marker>[];
    for (int i = 0; i < _polygonPoints.length; i++) {
      final point = _polygonPoints[i];
      markers.add(Marker(
        point: point,
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${i + 1}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ));
    }
    return markers;
  }

  LatLng _getPolygonCenter(List<LatLng> points) {
    double sumLat = 0, sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _polygonPoints.isNotEmpty && !_isPolygonClosed ? _undoLastPoint : null,
          icon: const Icon(Icons.undo, size: 18),
          label: const Text('Undo'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _polygonPoints.isNotEmpty ? _clearPolygon : null,
          icon: const Icon(Icons.clear, size: 18),
          label: const Text('Clear'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _polygonPoints.length >= 3 && !_isPolygonClosed ? _closePolygon : null,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Close Polygon'),
        ),
        const Spacer(),
        Text(
          '${_polygonPoints.length} points',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (_isDrawingMode && !_isPolygonClosed)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Tap map to draw',
                style: TextStyle(fontSize: 12, color: AppColors.info),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildValidationStatus() {
    if (_selfIntersectionError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(_selfIntersectionError!, style: const TextStyle(color: AppColors.error)),
          ],
        ),
      );
    }

    if (_isValidating) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.info.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Validating geometry...'),
          ],
        ),
      );
    }

    if (_isGeometryValid == true && _overlappingIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withAlpha(80)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('Valid geometry', style: TextStyle(color: AppColors.success)),
          ],
        ),
      );
    }

    if (_isGeometryValid == true && _overlappingIds.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withAlpha(100)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
            const SizedBox(width: 8),
            Text(
              'Valid geometry, but overlaps ${_overlappingIds.length} existing territory(ies)',
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
        ),
      );
    }

    if (_isGeometryValid == false) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Invalid geometry: ${_validationReason ?? "unknown reason"}',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }

    if (!_isPolygonClosed && _polygonPoints.length < 3) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text('Draw at least 3 points, then close the polygon to validate'),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMetadataForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Territory Metadata',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _entityNameController,
                  decoration: const InputDecoration(
                    labelText: 'Entity Name *',
                    hintText: 'e.g., Community Church',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _entityIdController,
                  decoration: const InputDecoration(
                    labelText: 'Entity ID *',
                    hintText: 'e.g., CHURCH-001',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Union Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _conferenceController,
                  decoration: const InputDecoration(
                    labelText: 'Conference',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _zipcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Zipcode',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _populationController,
                  decoration: const InputDecoration(
                    labelText: 'Population',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _housingUnitsController,
                  decoration: const InputDecoration(
                    labelText: 'Housing Units',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
