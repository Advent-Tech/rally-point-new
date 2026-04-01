import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String workerId;
  final String? workerName;
  final String? teamId;

  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    this.workerName,
    this.teamId,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  List<DonationItem> _donations = [];
  List<PrayerItem> _prayers = [];
  int _territoriesAssigned = 0;
  double _coveragePercent = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final errors = <String>[];

    try {
      final apiClient = await ApiClient.getInstance();

      // Donations
      try {
        final response = await apiClient.get(
          '/api/donations/worker/${widget.workerId}',
          queryParameters: {'limit': 100, 'offset': 0},
        );
        if (response.statusCode == 200) {
          final body = response.data;
          final List<dynamic> rows = body is Map
              ? (body['donations'] as List? ?? const [])
              : (body is List ? body : const []);
          _donations = rows
              .whereType<Map>()
              .map((e) => DonationItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (e) {
        errors.add('donations');
        debugPrint('WorkerDetail donations error: $e');
      }

      // Prayers
      try {
        final response = await apiClient.get(
          '/api/prayer-requests/worker/${widget.workerId}',
          queryParameters: {'page': 1, 'page_size': 100},
        );
        if (response.statusCode == 200) {
          final body = response.data;
          final List<dynamic> rows = body is Map
              ? (body['prayer_requests'] as List? ?? const [])
              : (body is List ? body : const []);
          _prayers = rows
              .whereType<Map>()
              .map((e) => PrayerItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (e) {
        errors.add('prayers');
        debugPrint('WorkerDetail prayers error: $e');
      }

      // Territories assigned
      try {
        final response = await apiClient.get(
          '/api/territories/worker/${widget.workerId}',
        );
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map;
          _territoriesAssigned =
              (data['count'] as num?)?.toInt() ??
              ((data['territories'] as List?)?.length ?? 0);
        }
      } catch (e) {
        errors.add('territories');
        debugPrint('WorkerDetail territories error: $e');
      }

      // Worker completion percentage (used as coverage in this screen)
      try {
        final response = await apiClient.get(
          '/api/workers/${widget.workerId}/stats',
          queryParameters: {'days': 30},
        );
        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map;
          _coveragePercent = (data['completion_rate'] as num?)?.toDouble() ?? 0;
        }
      } catch (e) {
        debugPrint('WorkerDetail coverage stats error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (_donations.isEmpty && _prayers.isEmpty && errors.isNotEmpty) {
          _error = 'Unable to load worker analytics (${errors.join(', ')})';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerName = widget.workerName ?? 'worker';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(workerName),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Donations'),
            Tab(text: 'Prayers'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(context),
                _buildDonationsTab(context),
                _buildPrayersTab(context),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final totalDonation = _donations.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final byDay = _weeklyActivityCounts();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.volunteer_activism,
                  value: '\$${totalDonation.toStringAsFixed(0)}',
                  label: 'Donations',
                  subLabel: '${_donations.length} collected',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite,
                  value: '${_prayers.length}',
                  label: 'Prayers',
                  subLabel: 'Recorded',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.map_outlined,
                  value: '$_territoriesAssigned',
                  label: 'Territories',
                  subLabel: 'Assigned',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.bar_chart,
                  value: '${_coveragePercent.toStringAsFixed(0)}%',
                  label: 'Coverage',
                  subLabel: 'Avg completion',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/leader/command-center?mode=territories&preSelectedWorkerId=${widget.workerId}&preSelectedWorkerName=${Uri.encodeComponent(widget.workerName ?? 'Worker')}',
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('View Territories on Map'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Activity This Week',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: _WeeklyChart(byDay: byDay),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsTab(BuildContext context) {
    final totalDonation = _donations.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F5EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Total: \$${totalDonation.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 34 > 24 ? 24 : 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF11A67B),
                  ),
                ),
                Text('${_donations.length} donations'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _donations.isEmpty
              ? const Center(child: Text('No donations found'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _donations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = _donations[index];
                    return _DonationTile(donation: d);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPrayersTab(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '${_prayers.length}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF18A3C5),
                  ),
                ),
                const Text('prayer requests'),
              ],
            ),
          ),
        ),
        Expanded(
          child: _prayers.isEmpty
              ? const Center(child: Text('No prayer requests found'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _prayers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = _prayers[index];
                    return _PrayerTile(prayer: p);
                  },
                ),
        ),
      ],
    );
  }

  Map<String, int> _weeklyActivityCounts() {
    final counts = <String, int>{
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    void add(DateTime dt) {
      final day = DateTime(dt.year, dt.month, dt.day);
      if (day.isBefore(start) ||
          day.isAfter(start.add(const Duration(days: 6)))) {
        return;
      }
      const keys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final key = keys[dt.weekday - 1];
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final d in _donations) {
      add(d.timestamp);
    }
    for (final p in _prayers) {
      add(p.createdAt);
    }

    return counts;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String subLabel;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 30 > 26 ? 26 : 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 20 > 14 ? 14 : 14)),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final Map<String, int> byDay;

  const _WeeklyChart({required this.byDay});

  @override
  Widget build(BuildContext context) {
    final maxCount = byDay.values.fold<int>(0, (m, e) => e > m ? e : m);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((day) {
        final count = byDay[day] ?? 0;
        final factor = maxCount == 0 ? 0.0 : (count / maxCount);
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 14,
                    height: 84 * factor,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DonationTile extends StatelessWidget {
  final DonationItem donation;

  const _DonationTile({required this.donation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F6ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.volunteer_activism,
              color: Color(0xFF28B978),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${donation.amount.toStringAsFixed(2)} • ${donation.paymentMethod}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20 > 22 ? 22 : 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  donation.donorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (donation.donorAddress.isNotEmpty)
                  Text(
                    donation.donorAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(donation.timestamp),
            style: const TextStyle(color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatelessWidget {
  final PrayerItem prayer;

  const _PrayerTile({required this.prayer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.favorite,
              color: Color(0xFF16ABC7),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        prayer.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _PrayerStatusChip(status: prayer.status),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM dd').format(prayer.createdAt),
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  prayer.requesterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (prayer.details.isNotEmpty)
                  Text(
                    prayer.details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
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

class _PrayerStatusChip extends StatelessWidget {
  final String status;

  const _PrayerStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    Color fg;
    Color bg;

    switch (normalized) {
      case 'completed':
        fg = const Color(0xFF2BAA7C);
        bg = const Color(0xFFDFF3EA);
        break;
      case 'scheduled':
        fg = const Color(0xFF6F86D6);
        bg = const Color(0xFFE6EBFF);
        break;
      case 'in_progress':
        fg = const Color(0xFF2A8FD8);
        bg = const Color(0xFFE2F1FF);
        break;
      default:
        fg = const Color(0xFF6C83C8);
        bg = const Color(0xFFE9EEFF);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        normalized.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class DonationItem {
  final String id;
  final double amount;
  final String donorName;
  final String donorAddress;
  final String paymentMethod;
  final DateTime timestamp;

  const DonationItem({
    required this.id,
    required this.amount,
    required this.donorName,
    required this.donorAddress,
    required this.paymentMethod,
    required this.timestamp,
  });

  factory DonationItem.fromJson(Map<String, dynamic> json) {
    final donorName = (json['donor_name'] ?? '').toString().trim();
    final address = (json['donor_address'] ?? '').toString().trim();

    return DonationItem(
      id: (json['id'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      donorName: donorName.isEmpty ? 'Unknown donor' : donorName,
      donorAddress: address,
      paymentMethod: (json['payment_method'] ?? 'cash').toString(),
      timestamp:
          DateTime.tryParse(
            (json['collected_at'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}

class PrayerItem {
  final String id;
  final String subject;
  final String details;
  final String requesterName;
  final String status;
  final DateTime createdAt;

  const PrayerItem({
    required this.id,
    required this.subject,
    required this.details,
    required this.requesterName,
    required this.status,
    required this.createdAt,
  });

  factory PrayerItem.fromJson(Map<String, dynamic> json) {
    return PrayerItem(
      id: (json['id'] ?? '').toString(),
      subject: (json['prayer_subject'] ?? 'Prayer request').toString(),
      details: (json['prayer_details'] ?? '').toString(),
      requesterName: (json['requester_name'] ?? 'Unknown').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
