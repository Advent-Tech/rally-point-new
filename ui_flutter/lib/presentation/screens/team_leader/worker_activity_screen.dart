import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/network/api_client.dart';

/// Worker Activity Screen - Shows all activity for a specific worker
/// Used by team leaders to view detailed worker performance and activity history
class WorkerActivityScreen extends StatefulWidget {
  final String workerId;
  final String workerName;

  const WorkerActivityScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkerActivityScreen> createState() => _WorkerActivityScreenState();
}

class _WorkerActivityScreenState extends State<WorkerActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  // Activity data
  List<WorkerSession> _sessions = [];
  List<WorkerVisit> _visits = [];
  List<WorkerDelivery> _deliveries = [];
  List<WorkerDonation> _donations = [];

  // Filter
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadWorkerActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerActivity() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = await ApiClient.getInstance();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Load sessions
      try {
        final sessionsResponse = await apiClient.get(
          '/api/work-sessions/worker/${widget.workerId}',
          queryParameters: {'date': dateStr},
        );
        if (sessionsResponse.statusCode == 200) {
          final List<dynamic> data = sessionsResponse.data is List
              ? sessionsResponse.data
              : sessionsResponse.data['sessions'] ?? [];
          _sessions = data.map((json) => WorkerSession.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Failed to load sessions: $e');
      }

      // Load visits
      try {
        final visitsResponse = await apiClient.get(
          '/api/visits/worker/${widget.workerId}',
          queryParameters: {'date': dateStr},
        );
        if (visitsResponse.statusCode == 200) {
          final List<dynamic> data = visitsResponse.data is List
              ? visitsResponse.data
              : visitsResponse.data['visits'] ?? [];
          _visits = data.map((json) => WorkerVisit.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Failed to load visits: $e');
      }

      // Load deliveries - use correct endpoint /api/workers/:workerId/deliveries
      try {
        final deliveriesResponse = await apiClient.get(
          '/api/workers/${widget.workerId}/deliveries',
          queryParameters: {
            'date': dateStr,
          },
        );
        if (deliveriesResponse.statusCode == 200) {
          final List<dynamic> data = deliveriesResponse.data is List
              ? deliveriesResponse.data
              : deliveriesResponse.data['deliveries'] ?? [];
          _deliveries = data.map((json) => WorkerDelivery.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Failed to load deliveries: $e');
      }

      // Load donations
      try {
        final donationsResponse = await apiClient.get(
          '/api/donations/worker/${widget.workerId}',
          queryParameters: {
            'date': dateStr,
          },
        );
        if (donationsResponse.statusCode == 200) {
          final List<dynamic> data = donationsResponse.data is List
              ? donationsResponse.data
              : donationsResponse.data['donations'] ?? [];
          _donations = data.map((json) => WorkerDonation.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Failed to load donations: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadWorkerActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.workerName),
            Text(
              'Activity Details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _selectDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(DateFormat('MMM d').format(_selectedDate)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWorkerActivity,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Map'),
            Tab(text: 'Timeline'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWorkerActivity,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      sessions: _sessions,
                      visits: _visits,
                      deliveries: _deliveries,
                      donations: _donations,
                      isDark: isDark,
                    ),
                    _MapTab(
                      visits: _visits,
                      deliveries: _deliveries,
                      isDark: isDark,
                    ),
                    _TimelineTab(
                      sessions: _sessions,
                      visits: _visits,
                      deliveries: _deliveries,
                      donations: _donations,
                      isDark: isDark,
                    ),
                    _StatsTab(
                      sessions: _sessions,
                      visits: _visits,
                      deliveries: _deliveries,
                      donations: _donations,
                      isDark: isDark,
                    ),
                  ],
                ),
    );
  }
}

// Overview Tab
class _OverviewTab extends StatelessWidget {
  final List<WorkerSession> sessions;
  final List<WorkerVisit> visits;
  final List<WorkerDelivery> deliveries;
  final List<WorkerDonation> donations;
  final bool isDark;

  const _OverviewTab({
    required this.sessions,
    required this.visits,
    required this.deliveries,
    required this.donations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty && visits.isEmpty && deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No activity recorded for this day',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.timer,
                  label: 'Work Time',
                  value: _calculateTotalTime(),
                  color: AppColors.primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.home_work,
                  label: 'Visits',
                  value: visits.length.toString(),
                  color: AppColors.accent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.local_shipping,
                  label: 'Deliveries',
                  value: deliveries.length.toString(),
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.volunteer_activism,
                  label: 'Donations',
                  value: '\$${_calculateTotalDonations()}',
                  color: AppColors.warning,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Sessions
          if (sessions.isNotEmpty) ...[
            Text(
              'Sessions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...sessions.map((session) => _SessionCard(session: session, isDark: isDark)),
          ],

          // Recent Visits
          if (visits.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent Visits',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...visits.take(5).map((visit) => _VisitCard(visit: visit, isDark: isDark)),
          ],

          // Recent Deliveries
          if (deliveries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Deliveries',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...deliveries.take(5).map((delivery) => _DeliveryCard(delivery: delivery, isDark: isDark)),
          ],
        ],
      ),
    );
  }

  String _calculateTotalTime() {
    int totalMinutes = 0;
    for (final session in sessions) {
      if (session.endTime != null) {
        totalMinutes += session.endTime!.difference(session.startTime).inMinutes;
      } else {
        totalMinutes += DateTime.now().difference(session.startTime).inMinutes;
      }
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String _calculateTotalDonations() {
    double total = 0;
    for (final donation in donations) {
      total += donation.amount;
    }
    return total.toStringAsFixed(0);
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkerSession session;
  final bool isDark;

  const _SessionCard({required this.session, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isActive = session.endTime == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success.withAlpha(20) : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.success : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.play_circle_filled : Icons.check_circle,
            color: isActive ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.territoryName ?? 'Unknown Territory',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${DateFormat('HH:mm').format(session.startTime)} - ${session.endTime != null ? DateFormat('HH:mm').format(session.endTime!) : 'Active'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success.withAlpha(30) : AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isActive ? 'ACTIVE' : 'COMPLETED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final WorkerVisit visit;
  final bool isDark;

  const _VisitCard({required this.visit, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.home, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.address ?? 'Visit at ${DateFormat('HH:mm').format(visit.timestamp)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (visit.notes != null)
                  Text(
                    visit.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(visit.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final WorkerDelivery delivery;
  final bool isDark;

  const _DeliveryCard({required this.delivery, required this.isDark});

  Color _getStatusColor() {
    switch (delivery.status) {
      case 'delivered':
        return AppColors.success;
      case 'in_transit':
        return AppColors.primary;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  delivery.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              delivery.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Map Tab
class _MapTab extends StatelessWidget {
  final List<WorkerVisit> visits;
  final List<WorkerDelivery> deliveries;
  final bool isDark;

  const _MapTab({
    required this.visits,
    required this.deliveries,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    double avgLat = 0, avgLng = 0;
    int count = 0;

    // Add visit markers
    for (final visit in visits) {
      if (visit.latitude != null && visit.longitude != null) {
        avgLat += visit.latitude!;
        avgLng += visit.longitude!;
        count++;
        markers.add(Marker(
          point: LatLng(visit.latitude!, visit.longitude!),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.home, color: Colors.white, size: 16),
          ),
        ));
      }
    }

    // Add delivery markers
    for (final delivery in deliveries) {
      if (delivery.latitude != null && delivery.longitude != null) {
        avgLat += delivery.latitude!;
        avgLng += delivery.longitude!;
        count++;
        markers.add(Marker(
          point: LatLng(delivery.latitude!, delivery.longitude!),
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: delivery.status == 'delivered' ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
          ),
        ));
      }
    }

    if (markers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 64,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No location data available',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    avgLat /= count;
    avgLng /= count;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(avgLat, avgLng),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: MapConstants.getThemedTileUrl(isDark),
              userAgentPackageName: 'com.rallypoint.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapLegendItem(color: AppColors.accent, label: '${visits.length} Visits'),
                const SizedBox(height: 4),
                _MapLegendItem(color: AppColors.success, label: '${deliveries.length} Deliveries'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _MapLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Timeline Tab
class _TimelineTab extends StatelessWidget {
  final List<WorkerSession> sessions;
  final List<WorkerVisit> visits;
  final List<WorkerDelivery> deliveries;
  final List<WorkerDonation> donations;
  final bool isDark;

  const _TimelineTab({
    required this.sessions,
    required this.visits,
    required this.deliveries,
    required this.donations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Combine all activities into timeline
    final activities = <_TimelineItem>[];

    for (final session in sessions) {
      activities.add(_TimelineItem(
        time: session.startTime,
        type: 'session_start',
        title: 'Session Started',
        subtitle: session.territoryName ?? 'Unknown Territory',
        icon: Icons.play_arrow,
        color: AppColors.success,
      ));
      if (session.endTime != null) {
        activities.add(_TimelineItem(
          time: session.endTime!,
          type: 'session_end',
          title: 'Session Ended',
          subtitle: session.territoryName ?? 'Unknown Territory',
          icon: Icons.stop,
          color: AppColors.primary,
        ));
      }
    }

    for (final visit in visits) {
      activities.add(_TimelineItem(
        time: visit.timestamp,
        type: 'visit',
        title: 'Visit Logged',
        subtitle: visit.address ?? 'Location recorded',
        icon: Icons.home,
        color: AppColors.accent,
      ));
    }

    for (final delivery in deliveries) {
      if (delivery.completedAt != null) {
        activities.add(_TimelineItem(
          time: delivery.completedAt!,
          type: 'delivery',
          title: 'Delivery ${delivery.status == 'delivered' ? 'Completed' : 'Failed'}',
          subtitle: delivery.recipientName,
          icon: Icons.local_shipping,
          color: delivery.status == 'delivered' ? AppColors.success : AppColors.error,
        ));
      }
    }

    for (final donation in donations) {
      activities.add(_TimelineItem(
        time: donation.timestamp,
        type: 'donation',
        title: 'Donation Collected',
        subtitle: '\$${donation.amount.toStringAsFixed(2)}',
        icon: Icons.volunteer_activism,
        color: AppColors.warning,
      ));
    }

    // Sort by time descending (most recent first)
    activities.sort((a, b) => b.time.compareTo(a.time));

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline,
              size: 64,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No activity timeline available',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final item = activities[index];
        final isLast = index == activities.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          DateFormat('HH:mm').format(item.time),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineItem {
  final DateTime time;
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _TimelineItem({
    required this.time,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// Stats Tab
class _StatsTab extends StatelessWidget {
  final List<WorkerSession> sessions;
  final List<WorkerVisit> visits;
  final List<WorkerDelivery> deliveries;
  final List<WorkerDonation> donations;
  final bool isDark;

  const _StatsTab({
    required this.sessions,
    required this.visits,
    required this.deliveries,
    required this.donations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    int totalMinutes = 0;
    for (final session in sessions) {
      if (session.endTime != null) {
        totalMinutes += session.endTime!.difference(session.startTime).inMinutes;
      } else {
        totalMinutes += DateTime.now().difference(session.startTime).inMinutes;
      }
    }

    final completedDeliveries = deliveries.where((d) => d.status == 'delivered').length;
    final failedDeliveries = deliveries.where((d) => d.status == 'failed').length;

    double totalDonations = 0;
    for (final d in donations) {
      totalDonations += d.amount;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Total Work Time', value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m', isDark: isDark),
          _StatRow(label: 'Sessions', value: sessions.length.toString(), isDark: isDark),
          _StatRow(label: 'Visits Logged', value: visits.length.toString(), isDark: isDark),
          const Divider(height: 32),
          Text(
            'Deliveries',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Total Deliveries', value: deliveries.length.toString(), isDark: isDark),
          _StatRow(label: 'Completed', value: completedDeliveries.toString(), valueColor: AppColors.success, isDark: isDark),
          _StatRow(label: 'Failed', value: failedDeliveries.toString(), valueColor: AppColors.error, isDark: isDark),
          if (deliveries.isNotEmpty)
            _StatRow(
              label: 'Success Rate',
              value: '${(completedDeliveries / deliveries.length * 100).toStringAsFixed(0)}%',
              isDark: isDark,
            ),
          const Divider(height: 32),
          Text(
            'Donations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _StatRow(label: 'Total Collected', value: '\$${totalDonations.toStringAsFixed(2)}', isDark: isDark),
          _StatRow(label: 'Number of Donations', value: donations.length.toString(), isDark: isDark),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isDark;

  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Data models
class WorkerSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String? territoryId;
  final String? territoryName;

  WorkerSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.territoryId,
    this.territoryName,
  });

  factory WorkerSession.fromJson(Map<String, dynamic> json) {
    return WorkerSession(
      id: json['id']?.toString() ?? '',
      // Backend returns entry_time/exit_time not check_in_time/check_out_time
      startTime: json['entry_time'] != null
          ? DateTime.parse(json['entry_time'].toString())
          : (json['check_in_time'] != null
              ? DateTime.parse(json['check_in_time'].toString())
              : DateTime.now()),
      endTime: json['exit_time'] != null
          ? DateTime.tryParse(json['exit_time'].toString())
          : (json['check_out_time'] != null
              ? DateTime.tryParse(json['check_out_time'].toString())
              : null),
      territoryId: json['territory_id']?.toString(),
      // Territory name can be in entity_name or territory_name
      territoryName: json['entity_name']?.toString() ?? json['territory_name']?.toString(),
    );
  }
}

class WorkerVisit {
  final String id;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? notes;

  WorkerVisit({
    required this.id,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.address,
    this.notes,
  });

  factory WorkerVisit.fromJson(Map<String, dynamic> json) {
    return WorkerVisit(
      id: json['id']?.toString() ?? '',
      timestamp: json['visited_at'] != null
          ? DateTime.parse(json['visited_at'].toString())
          : DateTime.now(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      address: json['address']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class WorkerDelivery {
  final String id;
  final String recipientName;
  final String address;
  final String status;
  final double? latitude;
  final double? longitude;
  final DateTime? completedAt;

  WorkerDelivery({
    required this.id,
    required this.recipientName,
    required this.address,
    required this.status,
    this.latitude,
    this.longitude,
    this.completedAt,
  });

  factory WorkerDelivery.fromJson(Map<String, dynamic> json) {
    // Handle both wrapped (DeliveryWithItems) and unwrapped delivery formats
    final delivery = json['delivery'] as Map<String, dynamic>? ?? json;
    return WorkerDelivery(
      id: delivery['id']?.toString() ?? '',
      recipientName: delivery['recipient_name']?.toString() ?? 'Unknown',
      address: delivery['address']?.toString() ?? '',
      status: delivery['status']?.toString() ?? 'pending',
      latitude: delivery['latitude'] != null ? double.tryParse(delivery['latitude'].toString()) : null,
      longitude: delivery['longitude'] != null ? double.tryParse(delivery['longitude'].toString()) : null,
      // Backend uses completed_at not delivered_at
      completedAt: delivery['completed_at'] != null
          ? DateTime.tryParse(delivery['completed_at'].toString())
          : (delivery['delivered_at'] != null
              ? DateTime.tryParse(delivery['delivered_at'].toString())
              : null),
    );
  }
}

class WorkerDonation {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String? donorName;

  WorkerDonation({
    required this.id,
    required this.amount,
    required this.timestamp,
    this.donorName,
  });

  factory WorkerDonation.fromJson(Map<String, dynamic> json) {
    return WorkerDonation(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      donorName: json['donor_name']?.toString(),
    );
  }
}
