import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/activity_stats_model.dart';
import '../../../data/models/donation_model.dart';
import '../../../data/models/prayer_request_model.dart';
import '../../../data/models/user_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  bool _isLoading = true;

  // Overview stats
  int _totalWorkers = 0;
  int _activeWorkers = 0;
  int _totalTeams = 0;
  int _totalTerritories = 0;

  // Donation stats
  DonationStats? _donationStats;
  List<DonationModel> _recentDonations = [];

  // Prayer request stats
  PrayerRequestStats? _prayerStats;

  // Worker stats
  List<WorkerPerformanceStats> _workerStats = [];

  final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTeams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _totalTeams = _teams.length;
          _selectedTeamId = 'all';
        });
        _loadAllData();
      }
    } catch (e) {
      debugPrint('Failed to load teams: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadOverviewStats(),
      _loadDonationStats(),
      _loadPrayerStats(),
      _loadWorkerStats(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadOverviewStats() async {
    try {
      final api = await ApiClient.getInstance();

      // Load active workers count
      try {
        final workersResponse = await api.get(ApiConstants.activeWorkers);
        if (workersResponse.statusCode == 200) {
          final data = workersResponse.data is List
              ? workersResponse.data
              : workersResponse.data['workers'] ?? [];
          _activeWorkers = (data as List).length;
        }
      } catch (e) {
        debugPrint('Failed to load active workers: $e');
      }

      // Load total workers from admin
      try {
        final allWorkersResponse = await api.get(ApiConstants.adminWorkers);
        if (allWorkersResponse.statusCode == 200) {
          final data = allWorkersResponse.data is List
              ? allWorkersResponse.data
              : allWorkersResponse.data['workers'] ?? [];
          _totalWorkers = (data as List).length;
        }
      } catch (e) {
        debugPrint('Failed to load total workers: $e');
      }

      // Load territory allocations
      try {
        final allocResponse = await api.get(ApiConstants.adminTerritoryAllocations);
        if (allocResponse.statusCode == 200) {
          final data = allocResponse.data is List
              ? allocResponse.data
              : allocResponse.data['allocations'] ?? [];
          _totalTerritories = (data as List).length;
        }
      } catch (e) {
        debugPrint('Failed to load allocations: $e');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load overview stats: $e');
    }
  }

  Future<void> _loadDonationStats() async {
    try {
      final api = await ApiClient.getInstance();

      final isAll = _selectedTeamId == null || _selectedTeamId == 'all';
      final statsPath = isAll
          ? ApiConstants.donationStats
          : '${ApiConstants.donationStats}/team/$_selectedTeamId';
      final donationsPath = isAll
          ? ApiConstants.donationsAll
          : '${ApiConstants.donations}/team/$_selectedTeamId';

      // Load donation stats
      final statsResponse = await api.get(statsPath);
      if (statsResponse.statusCode == 200) {
        _donationStats = DonationStats.fromJson(statsResponse.data);
      }

      // Load recent donations
      final donationsResponse = await api.get(donationsPath);
      if (donationsResponse.statusCode == 200) {
        final data = donationsResponse.data is List
            ? donationsResponse.data
            : donationsResponse.data['donations'] ?? [];
        _recentDonations = (data as List)
            .map((json) => DonationModel.fromJson(json))
            .take(10)
            .toList();
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load donation stats: $e');
    }
  }

  Future<void> _loadPrayerStats() async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(ApiConstants.prayerRequestStats);
      if (response.statusCode == 200) {
        _prayerStats = PrayerRequestStats.fromJson(response.data);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load prayer stats: $e');
    }
  }

  Future<void> _loadWorkerStats() async {
    if (_selectedTeamId == null || _selectedTeamId == 'all') {
      _workerStats = [];
      return;
    }

    try {
      final api = await ApiClient.getInstance();
      final response = await api.get(
        '${ApiConstants.teamWorkerStats}/$_selectedTeamId/worker-stats',
      );
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['workers'] ?? [];
        _workerStats = (data as List)
            .map((json) => WorkerPerformanceStats.fromJson(json))
            .toList();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to load worker stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          if (_teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String>(
                value: _selectedTeamId,
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Teams'),
                  ),
                  ..._teams.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedTeamId = value);
                  _loadAllData();
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Donations'),
            Tab(text: 'Prayer Requests'),
            Tab(text: 'Workers'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildDonationsTab(),
                _buildPrayerRequestsTab(),
                _buildWorkersTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Stats Grid
                Text(
                  'Summary Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: isMobile ? 2 : (isTablet ? 3 : 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isMobile ? 1.1 : 1.5,
                  children: [
                    _SummaryCard(
                      title: 'Total Workers',
                      value: _totalWorkers.toString(),
                      subtitle: '$_activeWorkers active now',
                      icon: Icons.people,
                      color: AppColors.primary,
                      compact: isMobile,
                    ),
                    _SummaryCard(
                      title: 'Teams',
                      value: _totalTeams.toString(),
                      icon: Icons.groups,
                      color: AppColors.secondary,
                      compact: isMobile,
                    ),
                    _SummaryCard(
                      title: 'Territories',
                      value: _totalTerritories.toString(),
                      subtitle: 'allocated',
                      icon: Icons.map,
                      color: AppColors.info,
                      compact: isMobile,
                    ),
                    _SummaryCard(
                      title: 'Total Donations',
                      value: _currencyFormat.format(_donationStats?.totalAmount ?? 0),
                      subtitle: '${_donationStats?.totalDonations ?? 0} donations',
                      icon: Icons.volunteer_activism,
                      color: AppColors.success,
                      compact: isMobile,
                    ),
                    _SummaryCard(
                      title: 'Prayer Requests',
                      value: (_prayerStats?.totalRequests ?? 0).toString(),
                      subtitle: '${_prayerStats?.pendingRequests ?? 0} pending',
                      icon: Icons.favorite,
                      color: AppColors.warning,
                      compact: isMobile,
                    ),
                    _SummaryCard(
                      title: 'Avg Donation',
                      value: _currencyFormat.format(_donationStats?.averageDonation ?? 0),
                      subtitle: 'per donation',
                      icon: Icons.analytics,
                      color: AppColors.info,
                      compact: isMobile,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Charts - Stack vertically on mobile
                if (isMobile) ...[
                  _buildChartCard('Donation Breakdown', _buildDonationBreakdownChart()),
                  const SizedBox(height: 16),
                  _buildChartCard('Prayer Request Status', _buildPrayerPieChart()),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildChartCard('Donation Breakdown', _buildDonationBreakdownChart())),
                      const SizedBox(width: 16),
                      Expanded(child: _buildChartCard('Prayer Request Status', _buildPrayerPieChart())),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationBreakdownChart() {
    if (_recentDonations.isEmpty) {
      return const Center(child: Text('No donation data available'));
    }

    // Group donations by type
    final Map<String, double> byType = {};
    for (final d in _recentDonations) {
      final type = d.donationType.isNotEmpty ? d.donationType : 'other';
      byType[type] = (byType[type] ?? 0) + d.amount;
    }

    if (byType.isEmpty) {
      return const Center(child: Text('No donation data available'));
    }

    final typeColors = {
      'one_time': AppColors.success,
      'recurring': AppColors.primary,
      'pledge': AppColors.info,
      'book_distribution': AppColors.warning,
      'other': AppColors.secondary,
    };

    final entries = byType.entries.toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: entries.map((entry) {
                return PieChartSectionData(
                  color: typeColors[entry.key.toLowerCase()] ?? AppColors.primary,
                  value: entry.value,
                  title: _currencyFormat.format(entry.value),
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  radius: 50,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((entry) {
              final color = typeColors[entry.key.toLowerCase()] ?? AppColors.primary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key[0].toUpperCase() + entry.key.substring(1),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerPieChart() {
    if (_prayerStats == null) {
      return const Center(child: Text('No prayer data available'));
    }

    final total = _prayerStats!.totalRequests;
    if (total == 0) {
      return const Center(child: Text('No prayer requests recorded'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: AppColors.success,
            value: _prayerStats!.completedRequests.toDouble(),
            title: '${_prayerStats!.completedRequests}',
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            radius: 50,
          ),
          PieChartSectionData(
            color: AppColors.warning,
            value: _prayerStats!.pendingRequests.toDouble(),
            title: '${_prayerStats!.pendingRequests}',
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            radius: 50,
          ),
          PieChartSectionData(
            color: AppColors.primary,
            value: _prayerStats!.homeVisitRequests.toDouble(),
            title: '${_prayerStats!.homeVisitRequests}',
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            radius: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationsTab() {
    return RefreshIndicator(
      onRefresh: _loadDonationStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Donation Summary Cards - Responsive Grid
                GridView.count(
                  crossAxisCount: isMobile ? 2 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isMobile ? 1.2 : 1.8,
                  children: [
                    _CompactStatCard(
                      title: 'Total Donations',
                      value: _currencyFormat.format(_donationStats?.totalAmount ?? 0),
                      subtitle: '${_donationStats?.totalDonations ?? 0} donations',
                      icon: Icons.volunteer_activism,
                      color: AppColors.success,
                    ),
                    _CompactStatCard(
                      title: 'Average Donation',
                      value: _currencyFormat.format(_donationStats?.averageDonation ?? 0),
                      subtitle: 'per donation',
                      icon: Icons.analytics,
                      color: AppColors.primary,
                    ),
                    _CompactStatCard(
                      title: 'Online Pending',
                      value: _currencyFormat.format(_donationStats?.pendingDeposit ?? 0),
                      subtitle: 'unverified online',
                      icon: Icons.pending_actions,
                      color: AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Donation by Type Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donations by Type',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: isMobile ? 200 : 250,
                          child: _buildDonationTypeChart(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Recent Donations List
                Text(
                  'Recent Donations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (_recentDonations.isEmpty)
                  const Center(child: Text('No donations recorded'))
                else
                  ...(_recentDonations.map((donation) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.success.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.volunteer_activism, color: AppColors.success),
                          ),
                          title: Text(
                            donation.isAnonymous ? 'Anonymous' : donation.donorName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${donation.donationType}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _currencyFormat.format(donation.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ))),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDonationTypeChart() {
    if (_donationStats == null) {
      return const Center(child: Text('No donation data available'));
    }

    final oneTime = _donationStats!.oneTimeAmount;
    final recurring = _donationStats!.recurringAmount;

    if (oneTime == 0 && recurring == 0) {
      return const Center(child: Text('No donation data available'));
    }

    final data = [
      {'label': 'One-Time', 'amount': oneTime, 'count': _donationStats!.oneTimeDonations},
      {'label': 'Recurring', 'amount': recurring, 'count': _donationStats!.recurringDonations},
    ];

    return Row(
      children: [
        // Pie chart
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  color: AppColors.primary,
                  value: oneTime,
                  title: _currencyFormat.format(oneTime),
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  radius: 50,
                ),
                PieChartSectionData(
                  color: AppColors.success,
                  value: recurring,
                  title: _currencyFormat.format(recurring),
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  radius: 50,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((item) {
              final color = item['label'] == 'One-Time' ? AppColors.primary : AppColors.success;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${item['count']} donations',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerRequestsTab() {
    return RefreshIndicator(
      onRefresh: _loadPrayerStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prayer Request Summary Cards - Responsive Grid
                GridView.count(
                  crossAxisCount: isMobile ? 2 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isMobile ? 1.2 : 1.6,
                  children: [
                    _CompactStatCard(
                      title: 'Total Requests',
                      value: (_prayerStats?.totalRequests ?? 0).toString(),
                      icon: Icons.favorite,
                      color: AppColors.primary,
                    ),
                    _CompactStatCard(
                      title: 'Pending',
                      value: (_prayerStats?.pendingRequests ?? 0).toString(),
                      subtitle: 'awaiting action',
                      icon: Icons.pending,
                      color: AppColors.warning,
                    ),
                    _CompactStatCard(
                      title: 'Completed',
                      value: (_prayerStats?.completedRequests ?? 0).toString(),
                      subtitle: 'fulfilled',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    ),
                    _CompactStatCard(
                      title: 'Home Visits',
                      value: (_prayerStats?.homeVisitRequests ?? 0).toString(),
                      subtitle: 'requested',
                      icon: Icons.home,
                      color: AppColors.info,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Charts - Stack vertically on mobile
                if (isMobile) ...[
                  _buildChartCard('By Category', _buildCategoryChart()),
                  const SizedBox(height: 16),
                  _buildChartCard('By Urgency', _buildUrgencyChart()),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'By Category',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: _buildCategoryChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'By Urgency',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: _buildUrgencyChart(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final categories = _prayerStats?.byCategory ?? {};
    if (categories.isEmpty) {
      return const Center(child: Text('No category data available'));
    }

    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      AppColors.secondary,
      AppColors.error,
    ];

    final entries = categories.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: entries.asMap().entries.map((entry) {
                final percentage = (entry.value.value / total * 100).toStringAsFixed(0);
                return PieChartSectionData(
                  color: colors[entry.key % colors.length],
                  value: entry.value.value.toDouble(),
                  title: '$percentage%',
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  radius: 45,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors[entry.key % colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value.key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value.value}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencyChart() {
    final urgencies = _prayerStats?.byUrgency ?? {};
    if (urgencies.isEmpty) {
      return const Center(child: Text('No urgency data available'));
    }

    final urgencyColors = {
      'low': AppColors.success,
      'normal': AppColors.info,
      'medium': AppColors.warning,
      'high': AppColors.error,
      'urgent': const Color(0xFF880000),
    };

    final entries = urgencies.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[index].key.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: urgencyColors[entry.value.key.toLowerCase()] ?? AppColors.primary,
                width: 40,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWorkersTab() {
    return RefreshIndicator(
      onRefresh: _loadWorkerStats,
      child: _workerStats.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No worker performance data available'),
                  SizedBox(height: 8),
                  Text(
                    'Select a team to see worker statistics',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Worker Performance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Worker')),
                          DataColumn(label: Text('Deliveries'), numeric: true),
                          DataColumn(label: Text('Completed'), numeric: true),
                          DataColumn(label: Text('Failed'), numeric: true),
                          DataColumn(label: Text('Rate'), numeric: true),
                          DataColumn(label: Text('Avg Time'), numeric: true),
                          DataColumn(label: Text('Distance'), numeric: true),
                        ],
                        rows: _workerStats.map((worker) {
                          return DataRow(cells: [
                            DataCell(Text(worker.workerName ?? 'Unknown')),
                            DataCell(Text(worker.totalDeliveries.toString())),
                            DataCell(Text(worker.completedDeliveries.toString())),
                            DataCell(Text(worker.failedDeliveries.toString())),
                            DataCell(Text('${worker.completionRate.toStringAsFixed(0)}%')),
                            DataCell(Text('${worker.averageDeliveryTime.toStringAsFixed(0)} min')),
                            DataCell(Text('${worker.totalDistance.toStringAsFixed(1)} km')),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Performance Chart
                  Text(
                    'Completion Rate by Worker',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        height: 300,
                        child: _buildWorkerPerformanceChart(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkerPerformanceChart() {
    if (_workerStats.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final sortedWorkers = List<WorkerPerformanceStats>.from(_workerStats)
      ..sort((a, b) => b.completionRate.compareTo(a.completionRate));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${sortedWorkers[group.x].workerName}\n${rod.toY.toStringAsFixed(0)}%',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedWorkers.length) {
                  final name = sortedWorkers[index].workerName ?? 'Unknown';
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 60,
                      child: Text(
                        name.length > 8 ? '${name.substring(0, 8)}...' : name,
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: sortedWorkers.asMap().entries.map((entry) {
          final rate = entry.value.completionRate;
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: rate,
                color: rate >= 80
                    ? AppColors.success
                    : rate >= 60
                        ? AppColors.warning
                        : AppColors.error,
                width: 25,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool compact;

  const _SummaryCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: compact ? 16 : 20),
                ),
                Icon(Icons.trending_up, color: AppColors.success, size: compact ? 12 : 16),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 18 : 22,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: compact ? 10 : 12,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: compact ? 9 : 11,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _CompactStatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
