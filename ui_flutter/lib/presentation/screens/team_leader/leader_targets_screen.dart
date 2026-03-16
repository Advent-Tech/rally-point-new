import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class LeaderTargetsScreen extends StatefulWidget {
  const LeaderTargetsScreen({super.key});

  @override
  State<LeaderTargetsScreen> createState() => _LeaderTargetsScreenState();
}

class _LeaderTargetsScreenState extends State<LeaderTargetsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _teamTargets = [];
  List<dynamic> _workers = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final apiClient = await ApiClient.getInstance();

      final teamResponse = await apiClient.get('/api/teams/my/targets');
      debugPrint('Team targets API: ${teamResponse.statusCode}');

      final workersResponse = await apiClient.get('/api/teams/my/workers');
      debugPrint('Workers API: ${workersResponse.statusCode}');

      if (mounted) {
        setState(() {
          if (teamResponse.statusCode == 200 && teamResponse.data != null) {
            if (teamResponse.data is List) {
              _teamTargets = teamResponse.data as List;
            } else if (teamResponse.data is Map) {
              final mapData = teamResponse.data as Map;
              if (mapData['data'] is List) {
                _teamTargets = mapData['data'] as List;
              }
            }
          }

          if (workersResponse.statusCode == 200 &&
              workersResponse.data != null) {
            if (workersResponse.data is List) {
              _workers = workersResponse.data as List;
            } else if (workersResponse.data is Map) {
              final mapData = workersResponse.data as Map;
              if (mapData['data'] is List) {
                _workers = mapData['data'] as List;
              }
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team targets: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Targets'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Team Targets'),
            Tab(text: 'Worker Targets'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTeamTargetsTab(isDark),
                _buildWorkerTargetsTab(isDark),
              ],
            ),
    );
  }

  Widget _buildTeamTargetsTab(bool isDark) {
    if (_teamTargets.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.analytics_outlined,
        title: 'No Team Targets',
        subtitle: 'Set team targets to track progress',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _teamTargets.length,
        itemBuilder: (context, index) {
          final target = _teamTargets[index];
          return _TeamTargetCard(target: target, isDark: isDark);
        },
      ),
    );
  }

  Widget _buildWorkerTargetsTab(bool isDark) {
    if (_workers.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.people_outline,
        title: 'No Workers',
        subtitle: 'Add workers to track their targets',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workers.length,
        itemBuilder: (context, index) {
          final worker = _workers[index];
          return _WorkerTargetCard(worker: worker, isDark: isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.navyBlue.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.navyBlue.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _TeamTargetCard extends StatelessWidget {
  final Map<String, dynamic> target;
  final bool isDark;

  const _TeamTargetCard({required this.target, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final targetInfo = target['target'] as Map<String, dynamic>? ?? {};
    final progressData = target['progress'] as Map<String, dynamic>? ?? {};

    final name = targetInfo['name']?.toString() ?? 'Target';
    final type = targetInfo['target_type']?.toString() ?? 'other';
    final targetValue = (targetInfo['target_value'] ?? 0).toDouble();
    final currentValue = (progressData['current_value'] ?? 0).toDouble();
    final progress = targetValue > 0 ? currentValue / targetValue : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: _getTypeColor(type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    Text(
                      _getTypeLabel(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getTypeColor(type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: _getTypeColor(type).withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(_getTypeColor(type)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${currentValue.toStringAsFixed(0)} / ${targetValue.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return Icons.map_outlined;
      case 'donation':
        return Icons.volunteer_activism_outlined;
      case 'prayer':
        return Icons.church;
      case 'visit':
        return Icons.directions_walk_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return AppColors.secondary;
      case 'donation':
        return AppColors.accent;
      case 'prayer':
        return AppColors.warning;
      case 'visit':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return 'Territories';
      case 'donation':
        return 'Donations';
      case 'prayer':
        return 'Prayer Requests';
      case 'visit':
        return 'Visits';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }
}

class _WorkerTargetCard extends StatelessWidget {
  final Map<String, dynamic> worker;
  final bool isDark;

  const _WorkerTargetCard({required this.worker, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = worker['name']?.toString() ?? 'Worker';
    final email = worker['email']?.toString() ?? '';
    final targets = worker['targets'] as List? ?? [];

    int completedTargets = 0;
    for (final t in targets) {
      final progressData = t['progress'] as Map<String, dynamic>? ?? {};
      final targetInfo = t['target'] as Map<String, dynamic>? ?? {};
      final targetValue = (targetInfo['target_value'] ?? 0).toDouble();
      final currentValue = (progressData['current_value'] ?? 0).toDouble();
      if (targetValue > 0 && currentValue >= targetValue) {
        completedTargets++;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        subtitle: email.isNotEmpty
            ? Text(
                email,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: completedTargets > 0
                ? AppColors.success.withOpacity(0.1)
                : AppColors.textSecondaryLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$completedTargets/${targets.length}',
            style: TextStyle(
              color: completedTargets > 0
                  ? AppColors.success
                  : AppColors.textSecondaryLight,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
