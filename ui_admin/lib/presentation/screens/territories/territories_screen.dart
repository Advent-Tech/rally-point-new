import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/map_constants.dart';
import '../../../data/models/territory_model.dart';
import '../../../data/models/user_model.dart';

// For web geolocation
import 'dart:html' as html;

class TerritoriesScreen extends StatefulWidget {
  const TerritoriesScreen({super.key});

  @override
  State<TerritoriesScreen> createState() => _TerritoriesScreenState();
}

class _TerritoriesScreenState extends State<TerritoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<GeoTerritory> _geoTerritories = [];
  List<TerritoryModel> _territories = [];
  List<TerritoryAllocation> _allocations = [];
  List<UserModel> _teamLeaders = [];
  List<UnionStats> _unionStats = [];
  bool _isLoading = true;
  bool _isLoadingMap = false;
  bool _isLoadingStats = true;
  String? _statsError;
  String _searchQuery = '';
  String? _selectedUnion;
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  double _currentZoom = 10.0;

  // Initial center - will be updated with user location
  LatLng _initialCenter = const LatLng(40.7128, -74.0060); // New York default

  // Debounce timer for viewport loading
  Timer? _loadDebounceTimer;

  // SMART CACHING: Keep all loaded territories, keyed by their ID
  final Map<String, GeoTerritory> _territoriesCache = {};

  // Track which grid cells have been loaded to avoid reloading
  final Set<String> _loadedGridCells = {};

  // Grid cell size in degrees (roughly 10-15 km per cell)
  static const double _gridCellSize = 0.15;

  // Zoom threshold for showing polygons vs markers
  static const double _polygonZoomThreshold = 10.0;
  // Max territories to load per request
  static const int _maxTerritoriesPerLoad = 30;
  // Max points per polygon for performance
  static const int _maxPointsPerPolygon = 30;

  // Color palette for different unions
  static const List<Color> _unionColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF3F51B5), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getUserLocation();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  // Get user's location for initial map center
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

        // Move map to user location if map is ready
        if (_isMapReady) {
          _mapController.move(_initialCenter, 10);
        }
      }
    } catch (e) {
      debugPrint('Could not get user location: $e');
      // Keep default location (New York)
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Load allocations (fast)
      try {
        final allocResponse = await api.get(ApiConstants.adminTerritoryAllocations);
        if (allocResponse.statusCode == 200) {
          final data = allocResponse.data is List
              ? allocResponse.data
              : allocResponse.data['allocations'] ?? [];
          _allocations = (data as List).map((json) => TerritoryAllocation.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Failed to load allocations: $e');
      }

      // Load verified team leaders (fast)
      try {
        final leadersResponse = await api.get(ApiConstants.adminTeamLeaders);
        debugPrint('Team leaders response: ${leadersResponse.statusCode}');
        if (leadersResponse.statusCode == 200) {
          // Backend returns { leaders: [...], total, pending, verified, rejected }
          final data = leadersResponse.data is List
              ? leadersResponse.data
              : leadersResponse.data['leaders'] ?? [];
          _teamLeaders = (data as List)
              .map((json) => UserModel.fromJson(json))
              .where((u) => u.isVerified)
              .toList();
          debugPrint('Loaded ${_teamLeaders.length} verified team leaders');
        }
      } catch (e) {
        debugPrint('Failed to load team leaders: $e');
      }

      setState(() => _isLoading = false);

      // Load union stats in background
      debugPrint('About to call _loadUnionStats()');
      _loadUnionStats();
      debugPrint('Called _loadUnionStats()');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  Future<void> _loadUnionStats() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      final api = await ApiClient.getInstance();
      debugPrint('Loading union stats from: ${ApiConstants.unionStats}');
      final statsResponse = await api.get(ApiConstants.unionStats);
      debugPrint('Union stats response: ${statsResponse.statusCode}');
      debugPrint('Union stats data: ${statsResponse.data}');

      if (!mounted) return;

      if (statsResponse.statusCode == 200) {
        final data = statsResponse.data is List
            ? statsResponse.data
            : statsResponse.data['unions'] ?? [];
        debugPrint('Parsed ${(data as List).length} unions');
        setState(() {
          _unionStats = data.map<UnionStats>((json) => UnionStats.fromJson(json)).toList();
          _isLoadingStats = false;
        });
      } else {
        final errorMsg = 'Failed to load: ${statsResponse.statusCode}';
        debugPrint('Stats error: $errorMsg');
        setState(() {
          _statsError = errorMsg;
          _isLoadingStats = false;
        });
        // Show snackbar for visibility
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stats: $errorMsg'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Failed to load union stats: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      final errorMsg = e.toString();
      setState(() {
        _statsError = errorMsg;
        _isLoadingStats = false;
      });
      // Show snackbar for visibility
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stats error: $errorMsg'), backgroundColor: AppColors.error),
      );
    }
  }

  // Get grid cell key for a coordinate
  String _getGridCellKey(double lat, double lng) {
    final cellLat = (lat / _gridCellSize).floor();
    final cellLng = (lng / _gridCellSize).floor();
    return '$cellLat,$cellLng';
  }

  // Get all grid cells that cover the visible bounds
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

  // Load territories - SMART CACHING: only loads new grid cells, keeps existing data
  Future<void> _loadTerritoriesInBounds() async {
    if (!_isMapReady) return;

    final bounds = _mapController.camera.visibleBounds;

    // Get all grid cells in viewport
    final viewportCells = _getGridCellsForBounds(bounds);

    // Find cells that haven't been loaded yet
    final newCells = viewportCells.where((cell) => !_loadedGridCells.contains(cell)).toList();

    // Update visible territories from cache (even before loading new ones)
    _updateVisibleTerritories();

    // If all cells are already loaded, no need to fetch more
    if (newCells.isEmpty) {
      debugPrint('All ${viewportCells.length} grid cells already cached. Total cached: ${_territoriesCache.length}');
      return;
    }

    setState(() => _isLoadingMap = true);

    try {
      final api = await ApiClient.getInstance();

      // Calculate bounds for only the new cells (expand slightly for overlap)
      final boundsStr = '${bounds.west.toStringAsFixed(4)},${bounds.south.toStringAsFixed(4)},${bounds.east.toStringAsFixed(4)},${bounds.north.toStringAsFixed(4)}';

      final url = '${ApiConstants.territoriesInBounds}?bounds=$boundsStr&limit=$_maxTerritoriesPerLoad&zoom=${_currentZoom.round()}';

      debugPrint('Loading ${newCells.length} new grid cells. Already cached: ${_loadedGridCells.length} cells, ${_territoriesCache.length} territories');

      final response = await api.get(url);

      if (response.statusCode == 200) {
        final data = response.data;
        List<GeoTerritory> newTerritories = [];

        if (data is Map && data['features'] != null) {
          // GeoJSON FeatureCollection format
          // - feature['id'] contains the territory ID
          // - feature['properties'] contains all other fields
          // - feature['geometry'] contains the geometry
          final features = data['features'] as List;
          newTerritories = features.map((feature) {
            final props = Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
            // Important: Copy ID from feature level (not in properties)
            props['id'] = feature['id'];
            props['geometry'] = feature['geometry'];
            return GeoTerritory.fromJson(props);
          }).toList();
          debugPrint('Parsed ${newTerritories.length} territories from GeoJSON FeatureCollection');
        } else if (data is Map && data['territories'] != null) {
          final features = data['territories'] as List;
          newTerritories = features.map((json) => GeoTerritory.fromJson(json)).toList();
        } else if (data is List) {
          newTerritories = (data).map((json) => GeoTerritory.fromJson(json)).toList();
        }

        // Add to cache (using ID as key to avoid duplicates)
        int addedCount = 0;
        for (final territory in newTerritories) {
          // Skip territories with empty IDs (parsing failure)
          if (territory.id.isEmpty) {
            debugPrint('Skipping territory with empty ID: ${territory.entityName}');
            continue;
          }
          _territoriesCache[territory.id] = territory;
          addedCount++;
        }

        // Mark these cells as loaded
        _loadedGridCells.addAll(newCells);

        // Update visible list from cache
        _updateVisibleTerritories();

        debugPrint('Added $addedCount territories (${newTerritories.length} received). Total cached: ${_territoriesCache.length}');
      }
    } catch (e) {
      debugPrint('Failed to load territories: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  // Update the visible territories list from cache
  void _updateVisibleTerritories() {
    // Show ALL cached territories - they persist as user pans around
    _geoTerritories = _territoriesCache.values.toList();
    if (mounted) setState(() {});
  }

  // Debounced loading - called on map movement
  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    final newZoom = position.zoom;

    // Update zoom level
    if (newZoom != _currentZoom) {
      setState(() => _currentZoom = newZoom);
    }

    // Debounce the API call - shorter delay since we cache
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

  Color _getUnionColor(String? unionName) {
    if (unionName == null) return _unionColors[0];
    final index = _unionStats.indexWhere((u) => u.unionName == unionName);
    return _unionColors[index >= 0 ? index % _unionColors.length : 0];
  }

  Future<void> _searchTerritories(String query) async {
    if (query.isEmpty) {
      setState(() => _territories = []);
      return;
    }

    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(
        ApiConstants.territoriesSearch,
        queryParameters: {'q': query, 'limit': 50},
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['territories'] ?? [];
        setState(() {
          _territories = (data as List).map((json) => TerritoryModel.fromJson(json)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _allocateTerritory(TerritoryModel territory, UserModel leader) async {
    try {
      final api = await ApiClient.getInstance();
      await api.post(
        ApiConstants.adminTerritoryAllocate,
        data: {
          'leader_id': leader.id,
          'territory_id': territory.id,
          'territory_solid': territory.solid,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Territory allocated to ${leader.fullName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to allocate territory: $e')),
        );
      }
    }
  }

  void _showAllocateDialog(TerritoryModel territory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate Territory'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Territory: ${territory.entityName}'),
              if (territory.unionName != null)
                Text('Union: ${territory.unionName}'),
              const SizedBox(height: 16),
              const Text('Select Team Leader:'),
              const SizedBox(height: 8),
              if (_teamLeaders.isEmpty)
                const Text('No verified team leaders available')
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _teamLeaders.length,
                    itemBuilder: (context, index) {
                      final leader = _teamLeaders[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(leader.fullName.isNotEmpty
                              ? leader.fullName[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(leader.fullName),
                        subtitle: Text(leader.email),
                        onTap: () {
                          Navigator.pop(context);
                          _allocateTerritory(territory, leader);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Territory Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Allocations'),
            Tab(text: 'Search & Allocate'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildAllocations(),
                _buildSearch(),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (isMobile) {
      return _buildMobileOverview();
    }

    return Row(
      children: [
        // Map view (takes most of the space)
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 10,
                  minZoom: 4,
                  maxZoom: 18,
                  onMapReady: () {
                    setState(() => _isMapReady = true);
                    // Load initial territories for the viewport
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
                  // Show polygons when zoomed in enough
                  if (_currentZoom >= _polygonZoomThreshold)
                    PolygonLayer(polygons: _buildPolygons()),
                  // Always show markers for territory locations
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
              // Loading indicator (non-blocking)
              if (_isLoadingMap)
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
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, zoom + 1);
                      },
                    ),
                    const SizedBox(height: 8),
                    _ZoomButton(
                      icon: Icons.remove,
                      onPressed: () {
                        final zoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, zoom - 1);
                      },
                    ),
                    const SizedBox(height: 8),
                    _ZoomButton(
                      icon: Icons.my_location,
                      onPressed: () {
                        _mapController.move(_initialCenter, 12);
                      },
                      tooltip: 'Go to my location',
                    ),
                  ],
                ),
              ),
              // Territory count and zoom info
              Positioned(
                left: 16,
                bottom: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_territoriesCache.length} territories loaded',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_loadedGridCells.length} areas cached • Zoom ${_currentZoom.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        if (_currentZoom < _polygonZoomThreshold)
                          Text(
                            'Zoom in to see boundaries',
                            style: TextStyle(fontSize: 11, color: AppColors.info),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Stats sidebar
        SizedBox(
          width: 320,
          child: Card(
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stats header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withAlpha(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Territory Statistics',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MiniStatBox(
                            label: 'Unions',
                            value: '${_unionStats.length}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          _MiniStatBox(
                            label: 'Territories',
                            value: _formatNumber(_unionStats.fold(0, (sum, u) => sum + u.territoryCount)),
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          _MiniStatBox(
                            label: 'Allocated',
                            value: '${_allocations.length}',
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick navigation to union
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Jump to Union',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedUnion,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Select Union...')),
                      ..._unionStats.map((u) => DropdownMenuItem(
                            value: u.unionName,
                            child: Text(u.unionName),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedUnion = value);
                      if (value != null) {
                        // Load territories for this union and zoom to them
                        _loadUnionTerritories(value);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                // Union list
                Expanded(
                  child: _isLoadingStats
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Loading statistics...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _statsError != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Failed to load statistics',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _loadUnionStats,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _unionStats.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No union statistics available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _unionStats.length,
                          itemBuilder: (context, index) {
                            final stats = _unionStats[index];
                            final color = _unionColors[index % _unionColors.length];
                            return ListTile(
                              dense: true,
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              title: Text(
                                stats.unionName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('${_formatNumber(stats.territoryCount)} territories'),
                              trailing: Text(
                                '${_formatNumber(stats.totalHousingUnits)} homes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onTap: () => _loadUnionTerritories(stats.unionName),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Mobile-optimized overview with map and expandable bottom sheet for stats
  Widget _buildMobileOverview() {
    return Stack(
      children: [
        // Full-screen map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 10,
            minZoom: 4,
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
            if (_currentZoom >= _polygonZoomThreshold)
              PolygonLayer(polygons: _buildPolygons()),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        // Loading indicator
        if (_isLoadingMap)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        // Zoom controls (smaller on mobile)
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _ZoomButton(icon: Icons.add, onPressed: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, zoom + 1);
              }),
              const SizedBox(height: 6),
              _ZoomButton(icon: Icons.remove, onPressed: () {
                final zoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, zoom - 1);
              }),
              const SizedBox(height: 6),
              _ZoomButton(icon: Icons.my_location, onPressed: () {
                _mapController.move(_initialCenter, 12);
              }),
            ],
          ),
        ),
        // Stats button (opens bottom sheet)
        Positioned(
          left: 12,
          bottom: 12,
          child: GestureDetector(
            onTap: _showMobileStatsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_unionStats.length} Unions',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${_territoriesCache.length} territories loaded',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.expand_less, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Mobile stats bottom sheet
  void _showMobileStatsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Territory Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Mini stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _MiniStatBox(
                      label: 'Unions',
                      value: '${_unionStats.length}',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatBox(
                      label: 'Territories',
                      value: _formatNumber(_unionStats.fold(0, (sum, u) => sum + u.territoryCount)),
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _MiniStatBox(
                      label: 'Allocated',
                      value: '${_allocations.length}',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              // Union list
              Expanded(
                child: _isLoadingStats
                    ? const Center(child: CircularProgressIndicator())
                    : _statsError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, color: AppColors.error, size: 40),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _loadUnionStats();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _unionStats.length,
                            itemBuilder: (context, index) {
                              final stats = _unionStats[index];
                              final color = _unionColors[index % _unionColors.length];
                              return ListTile(
                                dense: true,
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                title: Text(stats.unionName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('${_formatNumber(stats.territoryCount)} territories'),
                                trailing: Text(
                                  '${_formatNumber(stats.totalHousingUnits)} homes',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _loadUnionTerritories(stats.unionName);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Load and zoom to a specific union's territories
  Future<void> _loadUnionTerritories(String unionName) async {
    setState(() => _isLoadingMap = true);

    try {
      final api = await ApiClient.getInstance();
      final url = '${ApiConstants.territoriesList}?union=${Uri.encodeComponent(unionName)}&limit=50&include_geometry=true';

      final response = await api.get(url);

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['territories'] ?? [];
        final newTerritories = (data as List).map((json) => GeoTerritory.fromJson(json)).toList();

        // Add to cache (smart caching - keeps existing data)
        for (final territory in newTerritories) {
          _territoriesCache[territory.id] = territory;
        }

        // Update visible list from cache
        _updateVisibleTerritories();

        // Calculate bounds and zoom to them
        if (newTerritories.isNotEmpty) {
          // Temporarily set _geoTerritories to union territories for fit calculation
          final tempList = _geoTerritories;
          _geoTerritories = newTerritories;
          _fitMapToTerritories();
          _geoTerritories = tempList;
        }

        debugPrint('Loaded ${newTerritories.length} territories for $unionName. Total cached: ${_territoriesCache.length}');
      }
    } catch (e) {
      debugPrint('Failed to load union territories: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }
  }

  void _fitMapToTerritories() {
    if (_geoTerritories.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;

    for (final territory in _geoTerritories) {
      final coords = _parseGeometry(territory.geometry);
      for (final coord in coords) {
        if (coord.latitude.abs() < 0.1 && coord.longitude.abs() < 0.1) continue;
        if (minLat == null || coord.latitude < minLat) minLat = coord.latitude;
        if (maxLat == null || coord.latitude > maxLat) maxLat = coord.latitude;
        if (minLng == null || coord.longitude < minLng) minLng = coord.longitude;
        if (maxLng == null || coord.longitude > maxLng) maxLng = coord.longitude;
      }
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  List<Polygon> _buildPolygons() {
    final polygons = <Polygon>[];

    for (final territory in _geoTerritories) {
      var coords = _parseGeometry(territory.geometry);
      if (coords.isEmpty) continue;

      // Simplify polygon if too many points for performance
      if (coords.length > _maxPointsPerPolygon) {
        coords = _simplifyPolygon(coords, _maxPointsPerPolygon);
      }

      final color = _getUnionColor(territory.unionName);

      polygons.add(Polygon(
        points: coords,
        color: color.withAlpha(100),
        borderColor: color,
        borderStrokeWidth: 2.0,
      ));
    }

    return polygons;
  }

  // Simplify polygon by keeping every Nth point
  List<LatLng> _simplifyPolygon(List<LatLng> points, int maxPoints) {
    if (points.length <= maxPoints) return points;
    final step = (points.length / maxPoints).ceil();
    final simplified = <LatLng>[];
    for (int i = 0; i < points.length; i += step) {
      simplified.add(points[i]);
    }
    // Always include the last point to close the polygon
    if (simplified.last != points.last) {
      simplified.add(points.last);
    }
    return simplified;
  }

  // Build markers for territories
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final territory in _geoTerritories) {
      final centroid = _getPolygonCentroid(territory.geometry);
      if (centroid == null) continue;

      final color = _getUnionColor(territory.unionName);

      // Larger markers when zoomed out, smaller when zoomed in (polygons are visible)
      final markerSize = _currentZoom < _polygonZoomThreshold ? 20.0 : 8.0;

      markers.add(Marker(
        point: centroid,
        width: markerSize,
        height: markerSize,
        child: GestureDetector(
          onTap: () => _onTerritoryMarkerTap(territory, centroid),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: _currentZoom < _polygonZoomThreshold ? 2 : 1),
              boxShadow: _currentZoom < _polygonZoomThreshold ? [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
          ),
        ),
      ));
    }

    return markers;
  }

  // Handle territory marker tap - zoom in and show details
  void _onTerritoryMarkerTap(GeoTerritory territory, LatLng centroid) {
    // If zoomed out, zoom in to show the boundary
    if (_currentZoom < _polygonZoomThreshold) {
      _mapController.move(centroid, _polygonZoomThreshold + 2);
      // Show details after a short delay to let the map animate
      Future.delayed(const Duration(milliseconds: 300), () {
        _showTerritoryDetailsSheet(territory);
      });
    } else {
      // Already zoomed in, show details directly
      _showTerritoryDetailsSheet(territory);
    }
  }

  // Show territory details bottom sheet with assignment option
  void _showTerritoryDetailsSheet(GeoTerritory territory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TerritoryDetailsSheet(
        territory: territory,
        teamLeaders: _teamLeaders,
        unionColor: _getUnionColor(territory.unionName),
        onAssign: (leader) {
          Navigator.pop(context);
          _allocateTerritoryFromMap(territory, leader);
        },
      ),
    );
  }

  // Allocate territory from map view
  Future<void> _allocateTerritoryFromMap(GeoTerritory territory, UserModel leader) async {
    try {
      final api = await ApiClient.getInstance();
      await api.post(
        ApiConstants.adminTerritoryAllocate,
        data: {
          'leader_id': leader.id,
          'territory_id': territory.id,
          'territory_solid': territory.solid,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Territory "${territory.entityName}" assigned to ${leader.fullName}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData(); // Refresh allocations
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign territory: $e')),
        );
      }
    }
  }

  // Calculate centroid of a polygon for marker placement
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildAllocations() {
    if (_allocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Allocations Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Search for territories and allocate them to team leaders',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allocations.length,
        itemBuilder: (context, index) {
          final allocation = _allocations[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle, color: AppColors.success),
              ),
              title: Text(allocation.territoryName ?? allocation.territoryId),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Leader: ${allocation.leaderName ?? allocation.leaderId}'),
                  if (allocation.allocatedAt != null)
                    Text(
                      'Allocated: ${allocation.allocatedAt!.toLocal().toString().split('.')[0]}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _confirmRevokeAllocation(allocation),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmRevokeAllocation(TerritoryAllocation allocation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Allocation'),
        content: Text(
          'Are you sure you want to revoke this territory allocation from ${allocation.leaderName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _revokeAllocation(allocation);
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeAllocation(TerritoryAllocation allocation) async {
    try {
      final api = await ApiClient.getInstance();
      await api.delete('${ApiConstants.adminTerritoryAllocations}/${allocation.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allocation revoked'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke allocation: $e')),
        );
      }
    }
  }

  Widget _buildSearch() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search territories by name...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _searchTerritories(value);
            },
          ),
        ),
        Expanded(
          child: _territories.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'Enter a search term to find territories'
                        : 'No territories found',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _territories.length,
                  itemBuilder: (context, index) {
                    final territory = _territories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primary),
                        ),
                        title: Text(territory.entityName),
                        subtitle: Text(
                          '${territory.unionName ?? ''} • ${territory.housingUnits ?? 0} homes',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showAllocateDialog(territory),
                          child: const Text('Allocate'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Territory details bottom sheet with assignment functionality
class _TerritoryDetailsSheet extends StatelessWidget {
  final GeoTerritory territory;
  final List<UserModel> teamLeaders;
  final Color unionColor;
  final Function(UserModel) onAssign;

  const _TerritoryDetailsSheet({
    required this.territory,
    required this.teamLeaders,
    required this.unionColor,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with territory info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unionColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: unionColor, width: 2),
                  ),
                  child: Icon(Icons.location_on, color: unionColor, size: 28),
                ),
                const SizedBox(width: 16),
                // Territory details
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        territory.unionName ?? 'Unknown Union',
                        style: TextStyle(
                          fontSize: 14,
                          color: unionColor,
                          fontWeight: FontWeight.w500,
                        ),
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
          ),
          // Territory stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.home,
                  label: 'Housing',
                  value: territory.housingUnits?.toString() ?? 'N/A',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.tag,
                  label: 'SOLID',
                  value: territory.solid,
                  color: AppColors.info,
                ),
                if (territory.conferenceName != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.business,
                      label: 'Conference',
                      value: territory.conferenceName!,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Team leader selection
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assign to Team Leader',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (teamLeaders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No verified team leaders available.\nPlease verify team leaders first.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...teamLeaders.take(5).map((leader) => _LeaderTile(
                        leader: leader,
                        onTap: () => onAssign(leader),
                      )),
                if (teamLeaders.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+ ${teamLeaders.length - 5} more team leaders',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  final UserModel leader;
  final VoidCallback onTap;

  const _LeaderTile({
    required this.leader,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(30),
          child: Text(
            leader.fullName.isNotEmpty ? leader.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(
          leader.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          leader.email,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Assign'),
        ),
      ),
    );
  }
}
