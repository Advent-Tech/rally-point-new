import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/map_constants.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/team_map/team_map_bloc.dart';

/// Team Map Screen for team leaders to visualize workers, deliveries, and activities
class TeamMapScreen extends StatefulWidget {
  final String? teamId;

  const TeamMapScreen({super.key, this.teamId});

  @override
  State<TeamMapScreen> createState() => _TeamMapScreenState();
}

class _TeamMapScreenState extends State<TeamMapScreen> {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh markers every 30 seconds (lightweight - doesn't reload territories)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      context.read<TeamMapBloc>().add(const TeamMapRefreshMarkers());
    });

    // Load data - get team ID from auth state or widget parameter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTeamMap();
    });
  }

  Future<void> _initializeTeamMap() async {
    final authState = context.read<AuthBloc>().state;
    String? teamId = widget.teamId;

    if (teamId == null && authState is AuthAuthenticated) {
      teamId = authState.user.teamId;

      // If user is a team leader but has no teamId, try to fetch their led team
      if (teamId == null && authState.user.isTeamLeader) {
        teamId = await _fetchLedTeamId(authState.user.id);
      }
    }

    if (teamId != null && mounted) {
      context.read<TeamMapBloc>().add(TeamMapLoad(teamId: teamId));
    }
  }

  Future<String?> _fetchLedTeamId(String leaderId) async {
    try {
      final apiClient = await ApiClient.getInstance();
      // Fetch teams where the user is the leader
      // The teams table has leader_id, so we need an endpoint for this
      // For now, try the teams endpoint with the user ID as a query parameter
      final response = await apiClient.get('/api/teams?leader_id=$leaderId');

      if (response.statusCode == 200) {
        final data = response.data;
        final teams = data is List ? data : data['teams'] ?? [];
        if (teams.isNotEmpty) {
          return teams[0]['id']?.toString();
        }
      }
    } catch (_) {
      // Silent fail - team fetch is optional
    }
    return null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _fitToAllMarkers(TeamMapLoaded state) {
    if (!_isMapReady) return;

    final territoryPoints = <LatLng>[];

    // Collect territory boundary points first - these are the primary view for team leaders
    if (state.showTerritories) {
      for (final territory in state.territoryBoundaries) {
        for (final coord in territory.coordinates) {
          if (coord.length >= 2) {
            territoryPoints.add(LatLng(coord[1], coord[0])); // [lng, lat] -> LatLng(lat, lng)
          }
        }
      }
    }

    // If we have territory boundaries, fit ONLY to territories
    // This prevents distant markers (e.g., test data in different countries) from zooming out too far
    if (territoryPoints.isNotEmpty) {
      final bounds = _calculateBounds(territoryPoints);
      if (bounds != null) {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }
      return;
    }

    // No territories - fall back to fitting all markers
    final allPoints = <LatLng>[];

    // Filter out invalid coordinates (0,0 or near it - indicates unset GPS)
    bool isValidCoord(double lat, double lng) => lat.abs() > 0.1 || lng.abs() > 0.1;

    if (state.showWorkers) {
      allPoints.addAll(state.activeWorkers
          .where((w) => isValidCoord(w.latitude, w.longitude))
          .map((w) => LatLng(w.latitude, w.longitude)));
    }
    if (state.showDeliveries) {
      allPoints.addAll(state.deliveries
          .where((d) => isValidCoord(d.latitude, d.longitude))
          .map((d) => LatLng(d.latitude, d.longitude)));
    }
    if (state.showReceipts) {
      allPoints.addAll(state.receipts
          .where((r) => isValidCoord(r.latitude, r.longitude))
          .map((r) => LatLng(r.latitude, r.longitude)));
    }
    if (state.showDonations) {
      allPoints.addAll(state.donations
          .where((d) => isValidCoord(d.latitude, d.longitude))
          .map((d) => LatLng(d.latitude, d.longitude)));
    }

    if (allPoints.isEmpty) return;

    final bounds = _calculateBounds(allPoints);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  LatLngBounds? _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return null;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TeamMapBloc>().add(const TeamMapRefresh()),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: BlocBuilder<TeamMapBloc, TeamMapState>(
        builder: (context, state) {
          if (state is TeamMapLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TeamMapError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      String? teamId = widget.teamId;
                      if (teamId == null && authState is AuthAuthenticated) {
                        teamId = authState.user.teamId;
                      }
                      if (teamId != null) {
                        context.read<TeamMapBloc>().add(TeamMapLoad(teamId: teamId));
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is TeamMapLoaded) {
            // Include territories in hasData check - territories are the primary view for team leaders
            final hasData = state.territoryBoundaries.isNotEmpty ||
                state.activeWorkers.isNotEmpty ||
                state.deliveries.isNotEmpty ||
                state.receipts.isNotEmpty ||
                state.donations.isNotEmpty;

            // Default center (US center) - always start here
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
                      // Fit to data if available after a short delay
                      if (hasData) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            _fitToAllMarkers(state);
                          }
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConstants.getThemedTileUrl(isDark),
                      userAgentPackageName: 'com.rallypoint.app',
                      keepBuffer: 5,
                      panBuffer: 1,
                    ),
                    // Territory boundaries layer (render first so it's below markers)
                    // Always render PolygonLayer (even if empty) to maintain consistent layer order
                    PolygonLayer(
                      polygons: state.showTerritories
                          ? _buildTerritoryPolygons(
                              state.territoryBoundaries,
                              state.activeWorkers.map((w) => w.territoryName).toSet(),
                            )
                          : <Polygon>[],
                    ),
                    // Territory center markers - tap to zoom to territory
                    if (state.showTerritories && state.territoryBoundaries.isNotEmpty)
                      MarkerLayer(markers: _buildTerritoryCenterMarkers(state.territoryBoundaries)),
                    if (state.showWorkers)
                      MarkerLayer(markers: _buildWorkerMarkers(state.activeWorkers)),
                    if (state.showDeliveries)
                      MarkerLayer(markers: _buildDeliveryMarkers(state.deliveries)),
                    if (state.showReceipts)
                      MarkerLayer(markers: _buildReceiptMarkers(state.receipts)),
                    if (state.showDonations)
                      MarkerLayer(markers: _buildDonationMarkers(state.donations)),
                  ],
                ),

                // Empty state overlay
                if (!hasData)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, size: 64, color: AppColors.textSecondaryLight),
                          SizedBox(height: 16),
                          Text('No Activity Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text(
                            'Active workers, deliveries, and transactions\nwill appear here on the map.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Map controls
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.add,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom + 1);
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.remove,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, currentZoom - 1);
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.fit_screen,
                        onPressed: () => _fitToAllMarkers(state),
                      ),
                    ],
                  ),
                ),

                // Stats overlay
                if (hasData)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _StatsOverlay(
                      totalTerritories: state.territoryBoundaries.length,
                      activeWorkers: state.activeWorkers.length,
                      pendingDeliveries: state.deliveries.where((d) => d.status == 'pending').length,
                      inTransitDeliveries: state.deliveries.where((d) => d.status == 'in_transit').length,
                      completedDeliveries: state.deliveries.where((d) => d.status == 'delivered').length,
                      // Count unique territories with active workers
                      activeTerritoriesCount: state.activeWorkers.map((w) => w.territoryName).toSet().length,
                      isDark: isDark,
                    ),
                  ),

                // Legend
                if (hasData)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _MapLegend(isDark: isDark),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // Color palette for different territories
  static const List<Color> _territoryColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
  ];

  Color _getWorkerColor(String territoryName) {
    // Generate consistent color based on territory name hash
    final hash = territoryName.hashCode.abs();
    return _territoryColors[hash % _territoryColors.length];
  }

  List<Marker> _buildWorkerMarkers(List<ActiveWorkerLocation> workers) {
    return workers.map((worker) {
      final territoryColor = _getWorkerColor(worker.territoryName);
      final statusColor = worker.status == 'working' ? AppColors.success : AppColors.warning;

      return Marker(
        point: LatLng(worker.latitude, worker.longitude),
        width: 120,
        height: 70,
        child: GestureDetector(
          onTap: () => _showWorkerDetails(worker),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Worker name badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: territoryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status indicator dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      worker.name.split(' ').first,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Pin icon with territory color
              Icon(Icons.person_pin_circle, color: territoryColor, size: 32),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildDeliveryMarkers(List<MapDeliveryMarker> deliveries) {
    return deliveries.map((delivery) {
      Color color;
      IconData icon;
      switch (delivery.status) {
        case 'pending':
          color = AppColors.warning;
          icon = Icons.pending_actions;
        case 'in_transit':
          color = AppColors.primary;
          icon = Icons.local_shipping;
        case 'delivered':
          color = AppColors.success;
          icon = Icons.check_circle;
        default:
          color = AppColors.error;
          icon = Icons.error;
      }

      return Marker(
        point: LatLng(delivery.latitude, delivery.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDeliveryDetails(delivery),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildReceiptMarkers(List<MapReceiptMarker> receipts) {
    return receipts.map((receipt) {
      return Marker(
        point: LatLng(receipt.latitude, receipt.longitude),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showReceiptDetails(receipt),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildDonationMarkers(List<MapDonationMarker> donations) {
    return donations.map((donation) {
      return Marker(
        point: LatLng(donation.latitude, donation.longitude),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showDonationDetails(donation),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();
  }

  List<Polygon> _buildTerritoryPolygons(List<TerritoryBoundary> territories, Set<String> activeTerritoriesNames) {
    final polygons = <Polygon>[];

    for (final territory in territories) {
      // Convert coordinates [lng, lat] to LatLng
      final points = territory.coordinates
          .map((coord) => LatLng(coord[1], coord[0])) // coord is [lng, lat]
          .toList();

      if (points.length < 3) continue;

      // Use consistent color based on territory name (matches worker colors)
      final territoryColor = _getWorkerColor(territory.name);
      final isActive = activeTerritoriesNames.contains(territory.name);

      polygons.add(Polygon(
        points: points,
        // Higher opacity for visibility - active territories more prominent
        color: isActive
            ? territoryColor.withAlpha(150)  // ~60% opacity for active
            : territoryColor.withAlpha(100),   // ~40% opacity for inactive
        borderColor: isActive ? territoryColor : territoryColor.withAlpha(220),
        borderStrokeWidth: isActive ? 4.0 : 3.0,
        isFilled: true,
        label: '${territory.name}${isActive ? ' (Active)' : ''}',
        labelStyle: TextStyle(
          color: territoryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        labelPlacement: PolygonLabelPlacement.centroid,
      ));
    }

    return polygons;
  }

  /// Build markers at the center of each territory for easy identification and tap-to-zoom
  List<Marker> _buildTerritoryCenterMarkers(List<TerritoryBoundary> territories) {
    final markers = <Marker>[];

    for (final territory in territories) {
      if (territory.coordinates.isEmpty) continue;

      // Calculate centroid of the territory
      double sumLat = 0, sumLng = 0;
      for (final coord in territory.coordinates) {
        if (coord.length >= 2) {
          sumLat += coord[1]; // lat
          sumLng += coord[0]; // lng
        }
      }
      final centroid = LatLng(
        sumLat / territory.coordinates.length,
        sumLng / territory.coordinates.length,
      );

      // Get territory color (matching polygon color)
      final territoryColor = _getWorkerColor(territory.name);

      markers.add(Marker(
        point: centroid,
        width: 100,
        height: 50,
        child: GestureDetector(
          onTap: () => _zoomToTerritory(territory),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Territory name badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: territoryColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(60),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        territory.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Tap indicator icon
              Icon(
                Icons.touch_app,
                color: territoryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ));
    }

    return markers;
  }

  /// Zoom the map to fit a specific territory
  void _zoomToTerritory(TerritoryBoundary territory) {
    if (territory.coordinates.isEmpty) return;

    // Convert coordinates to LatLng points
    final points = territory.coordinates
        .where((coord) => coord.length >= 2)
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();

    if (points.isEmpty) return;

    // Calculate bounds
    final bounds = _calculateBounds(points);
    if (bounds != null) {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );

      // Show territory info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viewing: ${territory.name}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showFilterSheet(BuildContext context) {
    final bloc = context.read<TeamMapBloc>();
    final state = bloc.state;
    if (state is! TeamMapLoaded) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => BlocBuilder<TeamMapBloc, TeamMapState>(
        bloc: bloc,
        builder: (context, currentState) {
          if (currentState is! TeamMapLoaded) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                const Text('Map Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active Workers'),
                  secondary: const Icon(Icons.person_pin_circle, color: AppColors.primary),
                  value: currentState.showWorkers,
                  onChanged: (value) => bloc.add(TeamMapUpdateFilters(showWorkers: value)),
                ),
                SwitchListTile(
                  title: const Text('Deliveries'),
                  secondary: const Icon(Icons.local_shipping, color: AppColors.warning),
                  value: currentState.showDeliveries,
                  onChanged: (value) => bloc.add(TeamMapUpdateFilters(showDeliveries: value)),
                ),
                SwitchListTile(
                  title: const Text('Receipts'),
                  secondary: const Icon(Icons.receipt_long, color: AppColors.accent),
                  value: currentState.showReceipts,
                  onChanged: (value) => bloc.add(TeamMapUpdateFilters(showReceipts: value)),
                ),
                SwitchListTile(
                  title: const Text('Donations'),
                  secondary: const Icon(Icons.volunteer_activism, color: AppColors.secondary),
                  value: currentState.showDonations,
                  onChanged: (value) => bloc.add(TeamMapUpdateFilters(showDonations: value)),
                ),
                SwitchListTile(
                  title: const Text('Territory Boundaries'),
                  secondary: const Icon(Icons.layers_outlined, color: AppColors.primary),
                  value: currentState.showTerritories,
                  onChanged: (value) => bloc.add(TeamMapUpdateFilters(showTerritories: value)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showWorkerDetails(ActiveWorkerLocation worker) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: worker.status == 'working' ? AppColors.success : AppColors.warning,
                  radius: 24,
                  child: Text(worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: worker.status == 'working' ? AppColors.success : AppColors.warning, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(worker.status == 'working' ? 'Currently Working' : 'Idle', style: TextStyle(color: worker.status == 'working' ? AppColors.success : AppColors.warning)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.location_on, label: 'Territory', value: worker.territoryName),
            _DetailRow(icon: Icons.access_time, label: 'Last Update', value: _formatTimeAgo(worker.lastUpdate)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _mapController.move(LatLng(worker.latitude, worker.longitude), 15);
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Focus'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/leader/worker-activity/${worker.id}?name=${Uri.encodeComponent(worker.name)}');
                    },
                    icon: const Icon(Icons.analytics),
                    label: const Text('Activity'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryDetails(MapDeliveryMarker delivery) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _getDeliveryColor(delivery.status).withAlpha(30), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.local_shipping, color: _getDeliveryColor(delivery.status)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(delivery.recipientName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: _getDeliveryColor(delivery.status).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                        child: Text(delivery.status.toUpperCase().replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getDeliveryColor(delivery.status))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (delivery.workerName != null) _DetailRow(icon: Icons.person, label: 'Assigned To', value: delivery.workerName!),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReceiptDetails(MapReceiptMarker receipt) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.accent.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: AppColors.accent)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$${receipt.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Donation', style: const TextStyle(color: AppColors.accent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.person, label: 'Collected By', value: receipt.workerName),
          ],
        ),
      ),
    );
  }

  void _showDonationDetails(MapDonationMarker donation) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.secondary.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.volunteer_activism, color: AppColors.secondary)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$${donation.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Donation', style: TextStyle(color: AppColors.secondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.person, label: 'Donor', value: donation.donorName),
            _DetailRow(icon: Icons.person_outline, label: 'Collected By', value: donation.workerName),
          ],
        ),
      ),
    );
  }

  Color _getDeliveryColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'in_transit':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      default:
        return AppColors.error;
    }
  }

  String _formatTimeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(8), child: Icon(icon, size: 22, color: AppColors.textPrimaryLight))),
    );
  }
}

class _StatsOverlay extends StatelessWidget {
  final int totalTerritories;
  final int activeTerritoriesCount;
  final int activeWorkers;
  final int pendingDeliveries;
  final int inTransitDeliveries;
  final int completedDeliveries;
  final bool isDark;

  const _StatsOverlay({
    required this.totalTerritories,
    required this.activeTerritoriesCount,
    required this.activeWorkers,
    required this.pendingDeliveries,
    required this.inTransitDeliveries,
    required this.completedDeliveries,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Territory overview
          _StatRow(icon: Icons.map, color: AppColors.primary, label: 'Territories', value: '$activeTerritoriesCount/$totalTerritories active'),
          const SizedBox(height: 8),
          _StatRow(icon: Icons.person, color: AppColors.success, label: 'Workers', value: '$activeWorkers'),
          const SizedBox(height: 8),
          _StatRow(icon: Icons.pending, color: AppColors.warning, label: 'Pending', value: '$pendingDeliveries'),
          const SizedBox(height: 8),
          _StatRow(icon: Icons.local_shipping, color: AppColors.primary, label: 'In Transit', value: '$inTransitDeliveries'),
          const SizedBox(height: 8),
          _StatRow(icon: Icons.check_circle, color: AppColors.success, label: 'Delivered', value: '$completedDeliveries'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12)), const SizedBox(width: 8), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]);
  }
}

class _MapLegend extends StatelessWidget {
  final bool isDark;

  const _MapLegend({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4, offset: const Offset(0, 2))]),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_LegendItem(color: AppColors.primary, label: 'Worker'), SizedBox(height: 4), _LegendItem(color: AppColors.warning, label: 'Pending'), SizedBox(height: 4), _LegendItem(color: AppColors.success, label: 'Delivered'), SizedBox(height: 4), _LegendItem(color: AppColors.accent, label: 'Receipt'), SizedBox(height: 4), _LegendItem(color: AppColors.secondary, label: 'Donation')],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 10))]);
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(icon, size: 18, color: AppColors.textSecondaryLight), const SizedBox(width: 8), Text('$label: ', style: const TextStyle(color: AppColors.textSecondaryLight)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)))]));
  }
}
