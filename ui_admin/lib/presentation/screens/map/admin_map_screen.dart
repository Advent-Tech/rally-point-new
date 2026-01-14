import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/map_constants.dart';
import '../../../data/models/activity_stats_model.dart';
import '../../../data/models/territory_model.dart';
import '../../../data/models/user_model.dart';

// For web geolocation
import 'dart:html' as html;

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _isLoading = false;
  double _currentZoom = 5.0;

  // Initial center - US overview
  LatLng _initialCenter = const LatLng(39.8283, -98.5795);

  // Data
  List<GeoTerritory> _territories = [];
  List<ActiveWorkerLocation> _activeWorkers = [];
  List<ChurchLocation> _churches = [];
  List<PrayerMapMarker> _prayerMarkers = [];
  List<TeamModel> _teams = [];
  String? _selectedTeamId;

  // Layer visibility toggles
  bool _showTerritories = true;
  bool _showWorkers = true;
  bool _showChurches = true;
  bool _showPrayers = true;

  // Caching
  final Map<String, GeoTerritory> _territoriesCache = {};
  final Set<String> _loadedGridCells = {};
  static const double _gridCellSize = 0.15;
  static const double _polygonZoomThreshold = 10.0;
  static const int _maxPointsPerPolygon = 30;

  // Debounce timer
  Timer? _loadDebounceTimer;

  // Colors for unions
  static const List<Color> _unionColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadTeams();
    _loadInitialData();
  }

  @override
  void dispose() {
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      final geolocation = html.window.navigator.geolocation;
      final position = await geolocation.getCurrentPosition(
        enableHighAccuracy: false,
        timeout: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _initialCenter = LatLng(
            position.coords!.latitude!.toDouble(),
            position.coords!.longitude!.toDouble(),
          );
        });

        if (_isMapReady) {
          _mapController.move(_initialCenter, 10);
        }
      }
    } catch (e) {
      debugPrint('Could not get user location: $e');
    }
  }

  Future<void> _loadTeams() async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(ApiConstants.teams);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['teams'] ?? [];
        setState(() {
          _teams = (data as List).map((json) => TeamModel.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load teams: $e');
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadChurches(),
      _loadActiveWorkers(),
      _loadPrayerMarkers(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadChurches() async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(ApiConstants.churches);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['churches'] ?? [];
        setState(() {
          _churches = (data as List)
              .map((json) => ChurchLocation.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load churches: $e');
    }
  }

  Future<void> _loadActiveWorkers() async {
    try {
      final api = await ApiClient.getInstance();
      String url = ApiConstants.activeWorkers;
      if (_selectedTeamId != null) {
        url = '${ApiConstants.teamActiveWorkers}/$_selectedTeamId/workers/active';
      }
      final response = await api.get(url);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['workers'] ?? [];
        setState(() {
          _activeWorkers = (data as List)
              .map((json) => ActiveWorkerLocation.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load active workers: $e');
    }
  }

  Future<void> _loadPrayerMarkers() async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(ApiConstants.prayerRequestMap);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['markers'] ?? [];
        setState(() {
          _prayerMarkers = (data as List)
              .map((json) => PrayerMapMarker.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load prayer markers: $e');
    }
  }

  Future<void> _loadTerritoriesInBounds() async {
    if (!_isMapReady || _currentZoom < 8) return;

    final bounds = _mapController.camera.visibleBounds;
    final viewportCells = _getGridCellsForBounds(bounds);
    final newCells = viewportCells.where((cell) => !_loadedGridCells.contains(cell)).toList();

    _updateVisibleTerritories();

    if (newCells.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final api = await ApiClient.getInstance();
      final boundsStr = '${bounds.west.toStringAsFixed(4)},${bounds.south.toStringAsFixed(4)},${bounds.east.toStringAsFixed(4)},${bounds.north.toStringAsFixed(4)}';
      final url = '${ApiConstants.territoriesInBounds}?bounds=$boundsStr&limit=30&zoom=${_currentZoom.round()}';

      final response = await api.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        List<GeoTerritory> newTerritories = [];

        if (data is Map && data['features'] != null) {
          final features = data['features'] as List;
          newTerritories = features.map((feature) {
            final props = Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
            props['id'] = feature['id'];
            props['geometry'] = feature['geometry'];
            return GeoTerritory.fromJson(props);
          }).toList();
        } else if (data is Map && data['territories'] != null) {
          final features = data['territories'] as List;
          newTerritories = features.map((json) => GeoTerritory.fromJson(json)).toList();
        } else if (data is List) {
          newTerritories = (data).map((json) => GeoTerritory.fromJson(json)).toList();
        }

        for (final territory in newTerritories) {
          if (territory.id.isNotEmpty) {
            _territoriesCache[territory.id] = territory;
          }
        }

        _loadedGridCells.addAll(newCells);
        _updateVisibleTerritories();
      }
    } catch (e) {
      debugPrint('Failed to load territories: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  void _updateVisibleTerritories() {
    _territories = _territoriesCache.values.toList();
    if (mounted) setState(() {});
  }

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    final newZoom = position.zoom;

    if (newZoom != _currentZoom) {
      setState(() => _currentZoom = newZoom);
    }

    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      _loadTerritoriesInBounds();
    });
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

  List<LatLng> _simplifyPolygon(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final simplified = <LatLng>[];
    for (int i = 0; i < points.length; i += step) {
      simplified.add(points[i]);
    }
    if (simplified.last != points.last) {
      simplified.add(points.last);
    }
    return simplified;
  }

  Color _getUnionColor(String? unionName) {
    if (unionName == null) return _unionColors[0];
    final hash = unionName.hashCode;
    return _unionColors[hash.abs() % _unionColors.length];
  }

  LatLng? _getPolygonCentroid(Map<String, dynamic>? geometry) {
    if (geometry == null) return null;

    try {
      final coords = _parseGeometry(geometry);
      if (coords.isEmpty) return null;

      double sumLat = 0, sumLng = 0;
      for (final coord in coords) {
        sumLat += coord.latitude;
        sumLng += coord.longitude;
      }
      return LatLng(sumLat / coords.length, sumLng / coords.length);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Map'),
        actions: [
          // Team filter
          if (_teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _selectedTeamId,
                underline: const SizedBox(),
                hint: const Text('All Teams'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Teams'),
                  ),
                  ..._teams.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedTeamId = value);
                  _loadActiveWorkers();
                },
              ),
            ),
          // Layer toggles
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers),
            tooltip: 'Toggle Layers',
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'territories':
                    _showTerritories = !_showTerritories;
                    break;
                  case 'workers':
                    _showWorkers = !_showWorkers;
                    break;
                  case 'churches':
                    _showChurches = !_showChurches;
                    break;
                  case 'prayers':
                    _showPrayers = !_showPrayers;
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: 'territories',
                checked: _showTerritories,
                child: const Text('Territories'),
              ),
              CheckedPopupMenuItem(
                value: 'workers',
                checked: _showWorkers,
                child: const Text('Active Workers'),
              ),
              CheckedPopupMenuItem(
                value: 'churches',
                checked: _showChurches,
                child: const Text('Churches'),
              ),
              CheckedPopupMenuItem(
                value: 'prayers',
                checked: _showPrayers,
                child: const Text('Prayer Requests'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 5,
              minZoom: 3,
              maxZoom: 18,
              onMapReady: () {
                setState(() => _isMapReady = true);
                Future.delayed(const Duration(milliseconds: 300), _loadTerritoriesInBounds);
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
              // Territory polygons
              if (_showTerritories && _currentZoom >= _polygonZoomThreshold)
                PolygonLayer(polygons: _buildTerritoryPolygons()),
              // Territory markers (when zoomed out)
              if (_showTerritories && _currentZoom < _polygonZoomThreshold)
                MarkerLayer(markers: _buildTerritoryMarkers()),
              // Church markers
              if (_showChurches)
                MarkerLayer(markers: _buildChurchMarkers()),
              // Active worker markers
              if (_showWorkers)
                MarkerLayer(markers: _buildWorkerMarkers()),
              // Prayer request markers
              if (_showPrayers)
                MarkerLayer(markers: _buildPrayerMarkers()),
            ],
          ),
          // Loading indicator
          if (_isLoading)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          // Zoom controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.my_location,
                  onPressed: () {
                    _mapController.move(_initialCenter, 12);
                  },
                  tooltip: 'My Location',
                ),
              ],
            ),
          ),
          // Legend
          Positioned(
            left: 16,
            bottom: 16,
            child: _buildLegend(),
          ),
          // Stats card
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildStatsCard(),
          ),
        ],
      ),
    );
  }

  List<Polygon> _buildTerritoryPolygons() {
    final polygons = <Polygon>[];

    for (final territory in _territories) {
      var coords = _parseGeometry(territory.geometry);
      if (coords.isEmpty) continue;

      if (coords.length > _maxPointsPerPolygon) {
        coords = _simplifyPolygon(coords, _maxPointsPerPolygon);
      }

      final color = _getUnionColor(territory.unionName);

      polygons.add(Polygon(
        points: coords,
        color: color.withAlpha(80),
        borderColor: color,
        borderStrokeWidth: 2.0,
      ));
    }

    return polygons;
  }

  List<Marker> _buildTerritoryMarkers() {
    final markers = <Marker>[];

    for (final territory in _territories) {
      final centroid = _getPolygonCentroid(territory.geometry);
      if (centroid == null) continue;

      final color = _getUnionColor(territory.unionName);

      markers.add(Marker(
        point: centroid,
        width: 16,
        height: 16,
        child: GestureDetector(
          onTap: () => _showTerritoryDetails(territory),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  List<Marker> _buildChurchMarkers() {
    return _churches.map((church) {
      return Marker(
        point: LatLng(church.latitude, church.longitude),
        width: 30,
        height: 30,
        child: GestureDetector(
          onTap: () => _showChurchDetails(church),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.church,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildWorkerMarkers() {
    return _activeWorkers.where((w) => w.latitude != null && w.longitude != null).map((worker) {
      return Marker(
        point: LatLng(worker.latitude!, worker.longitude!),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showWorkerDetails(worker),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildPrayerMarkers() {
    return _prayerMarkers.map((prayer) {
      final color = _getPrayerUrgencyColor(prayer.urgency);
      return Marker(
        point: LatLng(prayer.latitude, prayer.longitude),
        width: 28,
        height: 28,
        child: GestureDetector(
          onTap: () => _showPrayerDetails(prayer),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getPrayerUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return const Color(0xFF880000);
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Legend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _LegendItem(
              icon: Icons.circle,
              color: AppColors.primary,
              label: 'Territory',
            ),
            _LegendItem(
              icon: Icons.church,
              color: AppColors.primary,
              label: 'Church',
            ),
            _LegendItem(
              icon: Icons.person,
              color: AppColors.success,
              label: 'Active Worker',
            ),
            _LegendItem(
              icon: Icons.favorite,
              color: AppColors.error,
              label: 'Prayer Request',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Map Stats',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text('${_territoriesCache.length} territories', style: const TextStyle(fontSize: 11)),
            Text('${_activeWorkers.length} active workers', style: const TextStyle(fontSize: 11)),
            Text('${_churches.length} churches', style: const TextStyle(fontSize: 11)),
            Text('${_prayerMarkers.length} prayer requests', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              'Zoom: ${_currentZoom.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            if (_currentZoom < _polygonZoomThreshold)
              Text(
                'Zoom in to see boundaries',
                style: TextStyle(fontSize: 10, color: AppColors.info),
              ),
          ],
        ),
      ),
    );
  }

  void _showTerritoryDetails(GeoTerritory territory) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _TerritoryDetailsSheet(territory: territory),
    );
  }

  void _showChurchDetails(ChurchLocation church) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ChurchDetailsSheet(church: church),
    );
  }

  void _showWorkerDetails(ActiveWorkerLocation worker) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _WorkerDetailsSheet(worker: worker),
    );
  }

  void _showPrayerDetails(PrayerMapMarker prayer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _PrayerDetailsSheet(prayer: prayer),
    );
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
          child: Icon(icon, size: 22, color: Colors.grey[800]),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

// Bottom sheet widgets
class _TerritoryDetailsSheet extends StatelessWidget {
  final GeoTerritory territory;

  const _TerritoryDetailsSheet({required this.territory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      territory.entityName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (territory.unionName != null)
                      Text(
                        territory.unionName!,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _DetailRow(label: 'SOLID', value: territory.solid),
          if (territory.conferenceName != null)
            _DetailRow(label: 'Conference', value: territory.conferenceName!),
          if (territory.housingUnits != null)
            _DetailRow(label: 'Housing Units', value: territory.housingUnits.toString()),
        ],
      ),
    );
  }
}

class _ChurchDetailsSheet extends StatelessWidget {
  final ChurchLocation church;

  const _ChurchDetailsSheet({required this.church});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.church, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      church.entityName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (church.city != null || church.state != null)
                      Text(
                        '${church.city ?? ''}, ${church.state ?? ''}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (church.unionName != null)
            _DetailRow(label: 'Union', value: church.unionName!),
          if (church.conference != null)
            _DetailRow(label: 'Conference', value: church.conference!),
          if (church.territoryCount != null)
            _DetailRow(label: 'Territories', value: church.territoryCount.toString()),
          if (church.totalHousing != null)
            _DetailRow(label: 'Total Housing', value: church.totalHousing.toString()),
        ],
      ),
    );
  }
}

class _WorkerDetailsSheet extends StatelessWidget {
  final ActiveWorkerLocation worker;

  const _WorkerDetailsSheet({required this.worker});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: AppColors.success),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.workerName ?? 'Unknown Worker',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Active Now',
                          style: TextStyle(color: AppColors.success, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (worker.teamName != null)
            _DetailRow(label: 'Team', value: worker.teamName!),
          if (worker.territoryName != null)
            _DetailRow(label: 'Territory', value: worker.territoryName!),
          if (worker.sessionStart != null)
            _DetailRow(
              label: 'Session Started',
              value: _formatDateTime(worker.sessionStart!),
            ),
          if (worker.lastUpdate != null)
            _DetailRow(
              label: 'Last Update',
              value: _formatDateTime(worker.lastUpdate!),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PrayerDetailsSheet extends StatelessWidget {
  final PrayerMapMarker prayer;

  const _PrayerDetailsSheet({required this.prayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite, color: AppColors.error),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.prayerSubject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      prayer.requesterName,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _DetailRow(label: 'Category', value: prayer.prayerCategory),
          _DetailRow(label: 'Request Type', value: prayer.requestType),
          _DetailRow(label: 'Status', value: prayer.status),
          _DetailRow(label: 'Urgency', value: prayer.urgency.toUpperCase()),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
