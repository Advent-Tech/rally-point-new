import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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
  MapboxMap? _mapboxMap;
  PolygonAnnotationManager? _polygonManager;
  CircleAnnotationManager? _circleManager;
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

  PolylineAnnotationManager? _polylineManager;

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polygonManager = await mapboxMap.annotations.createPolygonAnnotationManager();
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();

    setState(() => _isMapReady = true);

    // Update annotations when map is ready
    final state = context.read<TeamMapBloc>().state;
    if (state is TeamMapLoaded) {
      await _updateAnnotations(state);
      _fitToAllMarkers(state);
    }
  }

  Future<void> _updateAnnotations(TeamMapLoaded state) async {
    if (_polygonManager == null || _circleManager == null || _polylineManager == null) return;

    // Clear existing annotations
    await _polygonManager!.deleteAll();
    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();

    // Add territory polygons and boundary lines
    if (state.showTerritories) {
      final activeTerritoriesNames = state.activeWorkers.map((w) => w.territoryName).toSet();
      for (final territory in state.territoryBoundaries) {
        final coords = _parseCoordinates(territory.coordinates);
        if (coords.isEmpty) continue;

        final territoryColor = _getWorkerColor(territory.name);
        final isActive = activeTerritoriesNames.contains(territory.name);

        // Add filled polygon
        await _polygonManager!.create(PolygonAnnotationOptions(
          geometry: Polygon(coordinates: [coords]),
          fillColor: territoryColor.toARGB32(),
          fillOpacity: isActive ? 0.35 : 0.2,
        ));

        // Add boundary line for visibility
        final lineCoords = List<Position>.from(coords);
        if (lineCoords.isNotEmpty && lineCoords.first != lineCoords.last) {
          lineCoords.add(lineCoords.first);
        }

        await _polylineManager!.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: lineCoords),
          lineColor: territoryColor.toARGB32(),
          lineWidth: isActive ? 3.5 : 2.5,
          lineOpacity: isActive ? 1.0 : 0.8,
        ));
      }
    }

    // Add worker markers
    if (state.showWorkers) {
      for (final worker in state.activeWorkers) {
        if (worker.latitude.abs() < 0.1 && worker.longitude.abs() < 0.1) continue;

        final statusColor = worker.status == 'working' ? AppColors.success : AppColors.warning;
        await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(worker.longitude, worker.latitude)),
          circleColor: statusColor.toARGB32(),
          circleRadius: 12,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
        ));
      }
    }

    // Add delivery markers
    if (state.showDeliveries) {
      for (final delivery in state.deliveries) {
        if (delivery.latitude.abs() < 0.1 && delivery.longitude.abs() < 0.1) continue;

        Color color;
        switch (delivery.status) {
          case 'pending':
            color = AppColors.warning;
          case 'in_transit':
            color = AppColors.primary;
          case 'delivered':
            color = AppColors.success;
          default:
            color = AppColors.error;
        }

        await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(delivery.longitude, delivery.latitude)),
          circleColor: color.toARGB32(),
          circleRadius: 10,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ));
      }
    }

    // Add receipt markers
    if (state.showReceipts) {
      for (final receipt in state.receipts) {
        if (receipt.latitude.abs() < 0.1 && receipt.longitude.abs() < 0.1) continue;

        await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(receipt.longitude, receipt.latitude)),
          circleColor: AppColors.accent.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ));
      }
    }

    // Add donation markers
    if (state.showDonations) {
      for (final donation in state.donations) {
        if (donation.latitude.abs() < 0.1 && donation.longitude.abs() < 0.1) continue;

        await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(donation.longitude, donation.latitude)),
          circleColor: AppColors.secondary.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ));
      }
    }
  }

  List<Position> _parseCoordinates(List<List<double>> coordinates) {
    return coordinates
        .where((coord) => coord.length >= 2)
        .map((coord) => Position(coord[0], coord[1])) // [lng, lat]
        .toList();
  }

  void _fitToAllMarkers(TeamMapLoaded state) {
    if (!_isMapReady || _mapboxMap == null) return;

    final allPoints = <Position>[];

    // Collect territory boundary points first
    if (state.showTerritories) {
      for (final territory in state.territoryBoundaries) {
        for (final coord in territory.coordinates) {
          if (coord.length >= 2) {
            allPoints.add(Position(coord[0], coord[1]));
          }
        }
      }
    }

    // If we have territory boundaries, fit to territories
    if (allPoints.isNotEmpty) {
      _fitToBounds(allPoints);
      return;
    }

    // No territories - fall back to fitting all markers
    bool isValidCoord(double lat, double lng) => lat.abs() > 0.1 || lng.abs() > 0.1;

    if (state.showWorkers) {
      allPoints.addAll(state.activeWorkers
          .where((w) => isValidCoord(w.latitude, w.longitude))
          .map((w) => Position(w.longitude, w.latitude)));
    }
    if (state.showDeliveries) {
      allPoints.addAll(state.deliveries
          .where((d) => isValidCoord(d.latitude, d.longitude))
          .map((d) => Position(d.longitude, d.latitude)));
    }
    if (state.showReceipts) {
      allPoints.addAll(state.receipts
          .where((r) => isValidCoord(r.latitude, r.longitude))
          .map((r) => Position(r.longitude, r.latitude)));
    }
    if (state.showDonations) {
      allPoints.addAll(state.donations
          .where((d) => isValidCoord(d.latitude, d.longitude))
          .map((d) => Position(d.longitude, d.latitude)));
    }

    if (allPoints.isEmpty) return;

    _fitToBounds(allPoints);
  }

  void _fitToBounds(List<Position> points) {
    if (points.isEmpty || _mapboxMap == null) return;

    double minLat = points[0].lat.toDouble();
    double maxLat = points[0].lat.toDouble();
    double minLng = points[0].lng.toDouble();
    double maxLng = points[0].lng.toDouble();

    for (final point in points) {
      if (point.lat < minLat) minLat = point.lat.toDouble();
      if (point.lat > maxLat) maxLat = point.lat.toDouble();
      if (point.lng < minLng) minLng = point.lng.toDouble();
      if (point.lng > maxLng) maxLng = point.lng.toDouble();
    }

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
    final hash = territoryName.hashCode.abs();
    return _territoryColors[hash % _territoryColors.length];
  }

  void _zoomIn() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: currentCamera.zoom + 1,
      ));
    }
  }

  void _zoomOut() async {
    final currentCamera = await _mapboxMap?.getCameraState();
    if (currentCamera != null) {
      _mapboxMap?.setCamera(CameraOptions(
        center: currentCamera.center,
        zoom: math.max(1, currentCamera.zoom - 1),
      ));
    }
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
      body: BlocConsumer<TeamMapBloc, TeamMapState>(
        listener: (context, state) {
          if (state is TeamMapLoaded && _isMapReady) {
            _updateAnnotations(state);
          }
        },
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
            final hasData = state.territoryBoundaries.isNotEmpty ||
                state.activeWorkers.isNotEmpty ||
                state.deliveries.isNotEmpty ||
                state.receipts.isNotEmpty ||
                state.donations.isNotEmpty;

            return Stack(
              children: [
                MapWidget(
                  key: const ValueKey('teamMapWidget'),
                  styleUri: MapConstants.getThemedStyleUri(isDark),
                  cameraOptions: CameraOptions(
                    center: Point(coordinates: Position(
                      MapConstants.defaultLongitude,
                      MapConstants.defaultLatitude,
                    )),
                    zoom: 4,
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
                        onPressed: _zoomIn,
                      ),
                      const SizedBox(height: 8),
                      _MapControlButton(
                        icon: Icons.remove,
                        onPressed: _zoomOut,
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
