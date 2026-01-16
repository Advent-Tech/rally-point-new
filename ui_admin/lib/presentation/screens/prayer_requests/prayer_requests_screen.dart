import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/prayer_request_model.dart';
import '../../../data/models/user_model.dart';

class PrayerRequestsScreen extends StatefulWidget {
  const PrayerRequestsScreen({super.key});

  @override
  State<PrayerRequestsScreen> createState() => _PrayerRequestsScreenState();
}

class _PrayerRequestsScreenState extends State<PrayerRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PrayerRequestModel> _prayerRequests = [];
  PrayerRequestStats? _stats;
  List<TeamModel> _teams = [];
  String? _selectedTeamId;
  String? _selectedStatus;
  bool _isLoading = true;

  final _statusOptions = [
    'all',
    'pending',
    'scheduled',
    'in_progress',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          _loadData();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Build query params
      String url = ApiConstants.prayerRequests;
      final params = <String>[];
      if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
        url = '/api/prayer-requests/team/$_selectedTeamId';
      }
      if (_selectedStatus != null && _selectedStatus != 'all') {
        params.add('status=$_selectedStatus');
      }
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      // Load prayer requests
      final response = await api.get(url);
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['prayer_requests'] ?? [];
        _prayerRequests = (data as List)
            .map((json) => PrayerRequestModel.fromJson(json))
            .toList();
      }

      // Load stats
      String statsUrl = ApiConstants.prayerRequestStats;
      if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
        statsUrl += '?team_id=$_selectedTeamId';
      }
      final statsResponse = await api.get(statsUrl);
      if (statsResponse.statusCode == 200) {
        _stats = PrayerRequestStats.fromJson(statsResponse.data);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Requests'),
        actions: [
          // Team filter
          if (_teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                value: _selectedTeamId,
                hint: const Text('All Teams'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All Teams'),
                  ),
                  ..._teams.map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedTeamId = value);
                  _loadData();
                },
              ),
            ),
          // Status filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedStatus ?? 'all',
              underline: const SizedBox(),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s == 'all' ? 'All Status' : _formatStatus(s)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                _loadData();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'All Requests'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverview(),
                _buildRequestsList(),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _loadData,
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
                // Stats cards
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isMobile ? 1.1 : 1.4,
                  children: [
                    _ResponsiveStatCard(
                      title: 'Total Requests',
                      value: '${_stats?.totalRequests ?? 0}',
                      subtitle: 'prayer requests',
                      icon: Icons.volunteer_activism,
                      color: AppColors.primary,
                      compact: isMobile,
                    ),
                    _ResponsiveStatCard(
                      title: 'Pending',
                      value: '${_stats?.pendingRequests ?? 0}',
                      subtitle: 'awaiting action',
                      icon: Icons.pending_actions,
                      color: AppColors.warning,
                      compact: isMobile,
                    ),
                    _ResponsiveStatCard(
                      title: 'Completed',
                      value: '${_stats?.completedRequests ?? 0}',
                      subtitle: 'fulfilled',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                      compact: isMobile,
                    ),
                    _ResponsiveStatCard(
                      title: 'Home Visits',
                      value: '${_stats?.homeVisitRequests ?? 0}',
                      subtitle: 'requested',
                      icon: Icons.home,
                      color: AppColors.info,
                      compact: isMobile,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

            // By Category
            if (_stats?.byCategory != null && _stats!.byCategory!.isNotEmpty) ...[
              Text(
                'By Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _stats!.byCategory!.entries.map((e) {
                  return _CategoryChip(
                    category: e.key,
                    count: e.value,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],

            // By Urgency
            if (_stats?.byUrgency != null && _stats!.byUrgency!.isNotEmpty) ...[
              Text(
                'By Urgency',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _stats!.byUrgency!.entries.map((e) {
                  return _UrgencyChip(
                    urgency: e.key,
                    count: e.value,
                  );
                }).toList(),
              ),
            ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_prayerRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism_outlined,
                size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Prayer Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'No prayer requests found',
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
        itemCount: _prayerRequests.length,
        itemBuilder: (context, index) {
          final request = _prayerRequests[index];
          return _PrayerRequestCard(
            request: request,
            onTap: () => _showRequestDetails(request),
            onStatusChange: (status) => _updateStatus(request.id, status),
          );
        },
      ),
    );
  }

  void _showRequestDetails(PrayerRequestModel request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              request.requestType == 'home_visit' ? Icons.home : Icons.church,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(request.prayerSubject)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(
                label: 'Requester',
                value: request.requesterName,
              ),
              if (request.requesterPhone != null)
                _DetailRow(
                  label: 'Phone',
                  value: request.requesterPhone!,
                ),
              if (request.requesterEmail != null)
                _DetailRow(
                  label: 'Email',
                  value: request.requesterEmail!,
                ),
              if (request.requesterAddress != null)
                _DetailRow(
                  label: 'Address',
                  value: request.requesterAddress!,
                ),
              const Divider(),
              _DetailRow(
                label: 'Category',
                value: _formatCategory(request.prayerCategory),
              ),
              _DetailRow(
                label: 'Urgency',
                value: _formatUrgency(request.urgency),
              ),
              _DetailRow(
                label: 'Type',
                value: request.requestType == 'home_visit'
                    ? 'Home Visit Requested'
                    : 'Church Prayer',
              ),
              _DetailRow(
                label: 'Status',
                value: _formatStatus(request.status),
              ),
              const Divider(),
              const Text(
                'Prayer Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(request.prayerDetails),
              if (request.preferredVisitDate != null ||
                  request.preferredVisitTime != null) ...[
                const Divider(),
                if (request.preferredVisitDate != null)
                  _DetailRow(
                    label: 'Preferred Date',
                    value: request.preferredVisitDate!,
                  ),
                if (request.preferredVisitTime != null)
                  _DetailRow(
                    label: 'Preferred Time',
                    value: request.preferredVisitTime!,
                  ),
              ],
              if (request.workerName != null) ...[
                const Divider(),
                _DetailRow(
                  label: 'Collected By',
                  value: request.workerName!,
                ),
              ],
              if (request.createdAt != null)
                _DetailRow(
                  label: 'Created',
                  value: DateFormat('MMM d, yyyy h:mm a').format(request.createdAt!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (request.status == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(request.id, 'completed');
              },
              child: const Text('Mark Completed'),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      final api = await ApiClient.getInstance();
      await api.put(
        '/api/prayer-requests/$id/status',
        data: {'status': status},
      );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${_formatStatus(status)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatUrgency(String urgency) {
    return urgency[0].toUpperCase() + urgency.substring(1);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool compact;

  const _ResponsiveStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(compact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: compact ? 16 : 20),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: compact ? 8 : 16),
            if (compact)
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (compact) const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 20 : null,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: compact ? 10 : 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final int count;

  const _CategoryChip({
    required this.category,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
      label: Text(_formatCategory(category)),
      backgroundColor: AppColors.primary.withAlpha(20),
    );
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

class _UrgencyChip extends StatelessWidget {
  final String urgency;
  final int count;

  const _UrgencyChip({
    required this.urgency,
    required this.count,
  });

  Color get _color {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'normal':
        return AppColors.info;
      case 'low':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: _color,
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
      label: Text(urgency[0].toUpperCase() + urgency.substring(1)),
      backgroundColor: _color.withAlpha(20),
    );
  }
}

class _PrayerRequestCard extends StatelessWidget {
  final PrayerRequestModel request;
  final VoidCallback onTap;
  final Function(String) onStatusChange;

  const _PrayerRequestCard({
    required this.request,
    required this.onTap,
    required this.onStatusChange,
  });

  Color get _statusColor {
    switch (request.status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'scheduled':
        return AppColors.info;
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _urgencyColor {
    switch (request.urgency.toLowerCase()) {
      case 'urgent':
        return AppColors.error;
      case 'high':
        return AppColors.warning;
      case 'normal':
        return AppColors.info;
      case 'low':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      request.requestType == 'home_visit'
                          ? Icons.home
                          : Icons.volunteer_activism,
                      color: _statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.prayerSubject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.requesterName,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.status.toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _urgencyColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.urgency.toUpperCase(),
                          style: TextStyle(
                            color: _urgencyColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.prayerDetails,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatCategory(request.prayerCategory),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (request.createdAt != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(request.createdAt!),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
