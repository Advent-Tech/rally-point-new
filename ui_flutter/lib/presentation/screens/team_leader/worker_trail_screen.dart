import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/map_constants.dart';
import '../../blocs/worker_tracking/worker_tracking_bloc.dart';

class WorkerTrailScreen extends StatefulWidget {
  final String workerId;
  final String workerName;

  const WorkerTrailScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkerTrailScreen> createState() => _WorkerTrailScreenState();
}

class _WorkerTrailScreenState extends State<WorkerTrailScreen> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotationManager? _circleManager;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkerTrackingBloc>().add(
        WorkerTrackingLoadTrail(
          workerId: widget.workerId,
          workerName: widget.workerName,
        ),
      );
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();

    setState(() => _isMapReady = true);

    final state = context.read<WorkerTrackingBloc>().state;
    if (state is WorkerTrackingTrailLoaded) {
      await _drawTrail(state);
    }
  }

  Future<void> _drawTrail(WorkerTrackingTrailLoaded state) async {
    if (_polylineManager == null || _circleManager == null) return;

    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();

    if (state.trailPoints.isEmpty) return;

    // Build polyline coordinates
    final coords = state.trailPoints
        .map((p) => Position(p.longitude, p.latitude))
        .toList();

    // Draw the trail polyline
    await _polylineManager!.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: coords),
      lineColor: AppColors.primary.toARGB32(),
      lineWidth: 4.0,
    ));

    // Start marker (green)
    final first = state.trailPoints.first;
    await _circleManager!.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(first.longitude, first.latitude)),
      circleColor: AppColors.success.toARGB32(),
      circleRadius: 10,
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 3,
    ));

    // End marker (red)
    final last = state.trailPoints.last;
    await _circleManager!.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(last.longitude, last.latitude)),
      circleColor: AppColors.error.toARGB32(),
      circleRadius: 10,
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 3,
    ));

    // Direction indicator dots every ~20 points
    for (int i = 20; i < state.trailPoints.length - 1; i += 20) {
      final p = state.trailPoints[i];
      await _circleManager!.create(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(p.longitude, p.latitude)),
        circleColor: AppColors.primaryDark.toARGB32(),
        circleRadius: 4,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 1.5,
      ));
    }

    // Fit camera to trail bounds
    _fitToBounds(coords);
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
      MbxEdgeInsets(top: 100, left: 50, bottom: 250, right: 50),
      null,
      null,
      null,
      null,
    ).then((cameraOptions) {
      _mapboxMap!.setCamera(cameraOptions);
    });
  }

  void _recenterMap() {
    final state = context.read<WorkerTrackingBloc>().state;
    if (state is WorkerTrackingTrailLoaded && state.trailPoints.isNotEmpty) {
      final coords = state.trailPoints
          .map((p) => Position(p.longitude, p.latitude))
          .toList();
      _fitToBounds(coords);
    }
  }

  Future<void> _pickDate() async {
    final state = context.read<WorkerTrackingBloc>().state;
    DateTime initialDate = DateTime.now();
    if (state is WorkerTrackingTrailLoaded) {
      initialDate = state.selectedDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      context.read<WorkerTrackingBloc>().add(
        WorkerTrackingChangeDate(date: picked),
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<WorkerTrackingBloc, WorkerTrackingState>(
          builder: (context, state) {
            final dateStr = state is WorkerTrackingTrailLoaded
                ? _formatDate(state.selectedDate)
                : _formatDate(DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.workerName,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _pickDate,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.my_location, size: 20),
            onPressed: _recenterMap,
            tooltip: 'Recenter',
          ),
        ],
      ),
      body: BlocConsumer<WorkerTrackingBloc, WorkerTrackingState>(
        listener: (context, state) {
          if (state is WorkerTrackingTrailLoaded && _isMapReady) {
            _drawTrail(state);
          }
        },
        builder: (context, state) {
          if (state is WorkerTrackingTrailLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is WorkerTrackingError) {
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
                      context.read<WorkerTrackingBloc>().add(
                        WorkerTrackingLoadTrail(
                          workerId: widget.workerId,
                          workerName: widget.workerName,
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final isTrailLoaded = state is WorkerTrackingTrailLoaded;
          final hasPoints = isTrailLoaded && state.trailPoints.isNotEmpty;

          return Stack(
            children: [
              // Map
              MapWidget(
                key: const ValueKey('workerTrailMapWidget'),
                styleUri: MapConstants.getThemedStyleUri(isDark),
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(
                    MapConstants.defaultLongitude,
                    MapConstants.defaultLatitude,
                  )),
                  zoom: 4,
                ),
                onMapCreated: (mapboxMap) async {
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
              if (isTrailLoaded && !hasPoints)
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.route,
                          size: 64,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Tracking Data',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No GPS data for ${_formatDate(state.selectedDate)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Stats panel — use Positioned to avoid blocking map gestures
              if (isTrailLoaded)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _StatsPanel(
                    stats: state.stats,
                    workerName: state.workerName,
                    selectedDate: state.selectedDate,
                    isDark: isDark,
                    onDateTap: _pickDate,
                    formatDate: _formatDate,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final WorkerTrailStats stats;
  final String workerName;
  final DateTime selectedDate;
  final bool isDark;
  final VoidCallback onDateTap;
  final String Function(DateTime) formatDate;

  const _StatsPanel({
    required this.stats,
    required this.workerName,
    required this.selectedDate,
    required this.isDark,
    required this.onDateTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  workerName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(selectedDate),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                  label: 'Distance',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: '${stats.totalHours.toStringAsFixed(1)} hr',
                  label: 'Time',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: '${stats.averageSpeedKmh.toStringAsFixed(1)} kph',
                  label: 'Speed',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Additional info
          Text(
            'Sessions: ${stats.sessionCount}  \u2022  Points: ${stats.locationCount}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;

  const _StatTile({
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
