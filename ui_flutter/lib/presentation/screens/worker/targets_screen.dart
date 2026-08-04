import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class TargetsScreen extends StatefulWidget {
  const TargetsScreen({super.key});

  @override
  State<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends State<TargetsScreen> {
  List<dynamic> _targets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.get('/api/targets/me');
      debugPrint(
        'Targets API response: ${response.statusCode} - ${response.data}',
      );

      if (mounted) {
        setState(() {
          if (response.statusCode == 200 && response.data != null) {
            if (response.data is List) {
              _targets = response.data as List;
            } else if (response.data is Map) {
              final mapData = response.data as Map;
              if (mapData['data'] is List) {
                _targets = mapData['data'] as List;
              } else {
                _targets = [];
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading targets: $e');
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
        title: const Text('My Targets'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadTargets();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _targets.isEmpty
          ? _buildEmptyState(isDark)
          : _buildTargetsList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppColors.navyBlue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Targets Set',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your leader to set targets for you',
            style: TextStyle(color: AppColors.navyBlue.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetsList(bool isDark) {
    final groupedTargets = <String, List<dynamic>>{};
    for (final target in _targets) {
      final assignment = target['assignment'] as Map<String, dynamic>? ?? {};
      final targetInfo = assignment['target'] as Map<String, dynamic>? ?? {};
      final targetType = _normalizeTargetType(
        targetInfo['target_type']?.toString(),
      );

      groupedTargets.putIfAbsent(targetType, () => []).add(target);
    }

    double overallProgress = 0;
    int completedCount = 0;
    int totalCount = _targets.length;

    for (final target in _targets) {
      final assignment = target['assignment'] as Map<String, dynamic>? ?? {};
      final targetInfo = assignment['target'] as Map<String, dynamic>? ?? {};
      final progressData = target['progress'] as Map<String, dynamic>? ?? {};

      final targetValue = (targetInfo['target_value'] ?? 0).toDouble();
      final currentValue = (progressData['current_value'] ?? 0).toDouble();

      if (targetValue > 0) {
        overallProgress += currentValue / targetValue;
        if (currentValue >= targetValue) completedCount++;
      }
    }

    final avgProgress = totalCount > 0 ? overallProgress / totalCount : 0.0;

    return RefreshIndicator(
      onRefresh: _loadTargets,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Overall Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(avgProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: avgProgress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.success,
                      ),
                      minHeight: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$completedCount of $totalCount targets completed',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'By Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (groupedTargets.isEmpty)
              _buildEmptyState(isDark)
            else
              ...groupedTargets.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TargetCategoryCard(
                    title: _getCategoryTitle(entry.key),
                    icon: _getCategoryIcon(entry.key),
                    color: _getCategoryColor(entry.key),
                    targets: entry.value,
                    isDark: isDark,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _getCategoryTitle(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return 'Territories';
      case 'donation':
        return 'Donations';
      case 'book_sale':
      case 'book':
        return 'Books Distributed';
      case 'prayer':
        return 'Prayer Requests';
      case 'visit':
        return 'Visits';
      case 'session':
        return 'Sessions';
      default:
        return _toTitle(type);
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return Icons.map_outlined;
      case 'donation':
        return Icons.volunteer_activism_outlined;
      case 'book_sale':
      case 'book':
        return Icons.menu_book_rounded;
      case 'prayer':
        return Icons.church;
      case 'visit':
        return Icons.directions_walk_outlined;
      case 'session':
        return Icons.schedule_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'territory':
        return AppColors.secondary;
      case 'donation':
        return AppColors.accent;
      case 'book_sale':
      case 'book':
        return AppColors.warning;
      case 'prayer':
        return AppColors.warning;
      case 'visit':
        return AppColors.success;
      case 'session':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  String _normalizeTargetType(String? rawType) {
    final normalized = (rawType ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'other';
    if (normalized == 'book' || normalized == 'booksale') return 'book_sale';
    return normalized;
  }

  String _toTitle(String value) {
    if (value.isEmpty) return 'Other';
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _TargetCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<dynamic> targets;
  final bool isDark;

  const _TargetCategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.targets,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${targets.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...targets.map((target) {
            final assignment =
                target['assignment'] as Map<String, dynamic>? ?? {};
            final targetInfo =
                assignment['target'] as Map<String, dynamic>? ?? {};
            final progressData =
                target['progress'] as Map<String, dynamic>? ?? {};

            final name =
                targetInfo['name']?.toString() ??
                targetInfo['target_type']?.toString() ??
                'Target';
            final targetValue = (targetInfo['target_value'] ?? 0).toDouble();
            final currentValue = (progressData['current_value'] ?? 0)
                .toDouble();
            final unit = targetInfo['target_unit']?.toString() ?? 'count';
            final isTeamTarget = assignment['assigned_to_type'] == 'team';

            final progress = targetValue > 0 ? currentValue / targetValue : 0.0;

            String currentStr;
            String targetStr;
            if (unit == 'amount') {
              currentStr = '\$${currentValue.toStringAsFixed(0)}';
              targetStr = '\$${targetValue.toStringAsFixed(0)}';
            } else if (unit == 'percentage') {
              currentStr = '${currentValue.toStringAsFixed(0)}%';
              targetStr = '${targetValue.toStringAsFixed(0)}%';
            } else {
              currentStr = currentValue.toStringAsFixed(0);
              targetStr = targetValue.toStringAsFixed(0);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isTeamTarget) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'TEAM',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '$currentStr / $targetStr',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
