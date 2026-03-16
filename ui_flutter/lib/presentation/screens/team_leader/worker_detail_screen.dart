import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  Map<String, dynamic>? _worker;
  List<dynamic> _targets = [];
  List<dynamic> _activity = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

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
    try {
      final apiClient = await ApiClient.getInstance();

      final workerResponse = await apiClient.get(
        '/api/workers/${widget.workerId}',
      );
      debugPrint('Worker detail API: ${workerResponse.statusCode}');

      final targetsResponse = await apiClient.get(
        '/api/workers/${widget.workerId}/targets',
      );
      debugPrint('Worker targets API: ${targetsResponse.statusCode}');

      final activityResponse = await apiClient.get(
        '/api/workers/${widget.workerId}/activity',
      );
      debugPrint('Worker activity API: ${activityResponse.statusCode}');

      if (mounted) {
        setState(() {
          if (workerResponse.statusCode == 200 && workerResponse.data != null) {
            _worker = workerResponse.data as Map<String, dynamic>;
          }

          if (targetsResponse.statusCode == 200 &&
              targetsResponse.data != null) {
            if (targetsResponse.data is List) {
              _targets = targetsResponse.data as List;
            } else if (targetsResponse.data is Map) {
              final mapData = targetsResponse.data as Map;
              if (mapData['data'] is List) {
                _targets = mapData['data'] as List;
              }
            }
          }

          if (activityResponse.statusCode == 200 &&
              activityResponse.data != null) {
            if (activityResponse.data is List) {
              _activity = activityResponse.data as List;
            } else if (activityResponse.data is Map) {
              final mapData = activityResponse.data as Map;
              if (mapData['data'] is List) {
                _activity = mapData['data'] as List;
              }
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worker detail: $e');
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
    final name = widget.workerName ?? _worker?['name']?.toString() ?? 'Worker';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Targets'),
            Tab(text: 'Activity'),
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
                _buildOverviewTab(isDark),
                _buildTargetsTab(isDark),
                _buildActivityTab(isDark),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final worker = _worker;
    if (worker == null) {
      return _buildEmptyState(isDark, 'No worker data');
    }

    final name = worker['name']?.toString() ?? 'Unknown';
    final email = worker['email']?.toString() ?? '';
    final phone = worker['phone']?.toString() ?? '';
    final status = worker['status']?.toString() ?? 'active';
    final role = worker['role']?.toString() ?? 'worker';

    int completedTargets = 0;
    for (final t in _targets) {
      final progressData = t['progress'] as Map<String, dynamic>? ?? {};
      final targetInfo = t['target'] as Map<String, dynamic>? ?? {};
      final targetValue = (targetInfo['target_value'] ?? 0).toDouble();
      final currentValue = (progressData['current_value'] ?? 0).toDouble();
      if (targetValue > 0 && currentValue >= targetValue) {
        completedTargets++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        AppColors.buttonPrimaryDark,
                        AppColors.buttonPrimaryDarkEnd,
                      ]
                    : [
                        AppColors.buttonPrimaryLight,
                        AppColors.buttonPrimaryLightEnd,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoCard(
            isDark: isDark,
            children: [
              if (email.isNotEmpty)
                _InfoRow(icon: Icons.email, label: 'Email', value: email),
              if (phone.isNotEmpty)
                _InfoRow(icon: Icons.phone, label: 'Phone', value: phone),
              _InfoRow(
                icon: Icons.check_circle,
                label: 'Status',
                value: status,
                valueColor: status == 'active'
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.flag,
                  label: 'Targets',
                  value: '${completedTargets}/${_targets.length}',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                _StatItem(
                  icon: Icons.history,
                  label: 'Activities',
                  value: '${_activity.length}',
                  color: AppColors.secondary,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetsTab(bool isDark) {
    if (_targets.isEmpty) {
      return _buildEmptyState(isDark, 'No targets assigned');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _targets.length,
      itemBuilder: (context, index) {
        final target = _targets[index];
        return _TargetCard(target: target, isDark: isDark);
      },
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_activity.isEmpty) {
      return _buildEmptyState(isDark, 'No recent activity');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activity.length,
      itemBuilder: (context, index) {
        final item = _activity[index];
        return _ActivityCard(activity: item, isDark: isDark);
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppColors.navyBlue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.navyBlue.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _InfoCard({required this.isDark, required this.children});

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
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  final Map<String, dynamic> target;
  final bool isDark;

  const _TargetCard({required this.target, required this.isDark});

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
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getTypeColor(type),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isDark;

  const _ActivityCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final type = activity['type']?.toString() ?? 'activity';
    final description =
        activity['description']?.toString() ?? 'Activity recorded';
    final timestamp = activity['created_at']?.toString() ?? '';

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getTypeColor(type).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(type),
              color: _getTypeColor(type),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(timestamp),
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
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'visit':
        return Icons.directions_walk;
      case 'delivery':
        return Icons.local_shipping;
      case 'prayer':
        return Icons.church;
      case 'territory':
        return Icons.map;
      default:
        return Icons.history;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'visit':
        return AppColors.success;
      case 'delivery':
        return AppColors.primary;
      case 'prayer':
        return AppColors.warning;
      case 'territory':
        return AppColors.secondary;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }
}
