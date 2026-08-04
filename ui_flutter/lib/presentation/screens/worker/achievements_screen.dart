import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _achievements = [];
  Map<String, dynamic>? _workerLevel;
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

      final achievementsResponse = await apiClient.get('/api/achievements/me');
      debugPrint('Achievements API: ${achievementsResponse.statusCode}');

      final levelResponse = await apiClient.get('/api/achievements/me/level');
      debugPrint('Level API: ${levelResponse.statusCode}');

      if (mounted) {
        setState(() {
          if (achievementsResponse.statusCode == 200 &&
              achievementsResponse.data != null) {
            _achievements = _normalizeAchievementsResponse(
              achievementsResponse.data,
            );
          }

          if (levelResponse.statusCode == 200 && levelResponse.data != null) {
            _workerLevel = _normalizeLevelResponse(levelResponse.data);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading achievements: $e');
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
        title: const Text('Achievements'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Badges'),
            Tab(text: 'My Level'),
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
              children: [_buildBadgesTab(isDark), _buildLevelTab(isDark)],
            ),
    );
  }

  Widget _buildBadgesTab(bool isDark) {
    if (_achievements.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.emoji_events_outlined,
        title: 'No Achievements Yet',
        subtitle: 'Complete tasks to earn badges',
      );
    }

    final grouped = <String, List<dynamic>>{};
    for (final ach in _achievements) {
      final category = _normalizeCategory(ach['category']?.toString());
      grouped.putIfAbsent(category, () => []).add(ach);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBadgesSummary(isDark),
          const SizedBox(height: 24),
          ...grouped.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _AchievementCategoryCard(
                category: entry.key,
                achievements: entry.value,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSummary(bool isDark) {
    final total = _achievements.length;
    int territory = 0,
        donation = 0,
        bookSales = 0,
        prayer = 0,
        visit = 0,
        streak = 0;

    for (final ach in _achievements) {
      final cat = _normalizeCategory(ach['category']?.toString());
      switch (cat) {
        case 'territory':
          territory++;
          break;
        case 'donation':
          donation++;
          break;
        case 'book_sale':
          bookSales++;
          break;
        case 'prayer':
          prayer++;
          break;
        case 'visit':
          visit++;
          break;
        case 'streak':
          streak++;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A237E), const Color(0xFFFF6F00)]
              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
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
                'Total Badges',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _BadgeCount(
                icon: Icons.map,
                count: territory,
                label: 'Territory',
              ),
              _BadgeCount(
                icon: Icons.volunteer_activism,
                count: donation,
                label: 'Donation',
              ),
              _BadgeCount(
                icon: Icons.menu_book_rounded,
                count: bookSales,
                label: 'Books',
              ),
              _BadgeCount(icon: Icons.church, count: prayer, label: 'Prayer'),
              _BadgeCount(
                icon: Icons.directions_walk,
                count: visit,
                label: 'Visit',
              ),
              _BadgeCount(
                icon: Icons.local_fire_department,
                count: streak,
                label: 'Streak',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTab(bool isDark) {
    if (_workerLevel == null) {
      return _buildEmptyState(
        isDark,
        icon: Icons.military_tech_outlined,
        title: 'No Level Data',
        subtitle: 'Complete achievements to level up',
      );
    }

    final level = _workerLevel!;
    final currentLevel = level['current_level']?.toString() ?? 'Bronze';
    final totalPoints = level['total_points'] ?? 0;
    final progress = (level['level_progress'] ?? 0.0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getLevelColors(currentLevel),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getLevelColors(currentLevel)[0].withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _getLevelIcon(currentLevel),
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  currentLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '$totalPoints Points',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: _getLevelColors(
                      currentLevel,
                    )[0].withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(
                      _getLevelColors(currentLevel)[0],
                    ),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% to next level',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Badges by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 16),
          _LevelStatRow(
            icon: Icons.map,
            label: 'Territory Badges',
            value: level['territory_badges'] ?? 0,
            color: AppColors.secondary,
            isDark: isDark,
          ),
          _LevelStatRow(
            icon: Icons.volunteer_activism,
            label: 'Donation Badges',
            value: level['donation_badges'] ?? 0,
            color: AppColors.accent,
            isDark: isDark,
          ),
          _LevelStatRow(
            icon: Icons.menu_book_rounded,
            label: 'Book Distribution Badges',
            value: level['book_sale_badges'] ?? level['book_badges'] ?? 0,
            color: AppColors.warning,
            isDark: isDark,
          ),
          _LevelStatRow(
            icon: Icons.church,
            label: 'Prayer Badges',
            value: level['prayer_badges'] ?? 0,
            color: AppColors.warning,
            isDark: isDark,
          ),
          _LevelStatRow(
            icon: Icons.directions_walk,
            label: 'Visit Badges',
            value: level['visit_badges'] ?? 0,
            color: AppColors.success,
            isDark: isDark,
          ),
          _LevelStatRow(
            icon: Icons.local_fire_department,
            label: 'Streak Badges',
            value: level['streak_badges'] ?? 0,
            color: Colors.orange,
            isDark: isDark,
          ),
        ],
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

  List<Color> _getLevelColors(String level) {
    switch (level.toLowerCase()) {
      case 'platinum':
        return [Colors.purple.shade700, Colors.purple.shade400];
      case 'gold':
        return [Colors.amber.shade700, Colors.amber.shade500];
      case 'silver':
        return [Colors.grey.shade600, Colors.grey.shade400];
      default:
        return [Colors.orange.shade700, Colors.orange.shade500];
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'platinum':
        return Icons.diamond;
      case 'gold':
        return Icons.emoji_events;
      case 'silver':
        return Icons.workspace_premium;
      default:
        return Icons.military_tech;
    }
  }

  String _normalizeCategory(String? rawCategory) {
    final normalized = (rawCategory ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return 'other';
    if (normalized == 'book' || normalized == 'booksale') return 'book_sale';
    return normalized;
  }

  List<dynamic> _normalizeAchievementsResponse(dynamic raw) {
    final List<dynamic> rows;
    if (raw is List) {
      rows = raw;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final listCandidate =
          map['data'] ?? map['achievements'] ?? map['items'] ?? [];
      if (listCandidate is List) {
        rows = listCandidate;
      } else {
        rows = const [];
      }
    } else {
      rows = const [];
    }

    return rows.whereType<Map>().map<Map<String, dynamic>>((entryRaw) {
      final entry = Map<String, dynamic>.from(entryRaw);
      final nestedRaw = entry['achievement'];
      final nested = nestedRaw is Map<String, dynamic>
          ? nestedRaw
          : (nestedRaw is Map ? Map<String, dynamic>.from(nestedRaw) : null);
      if (nested == null) return entry;

      // Flatten nested achievement payload so existing UI fields work.
      return {
        ...nested,
        ...entry,
        'category': entry['category'] ?? nested['category'],
        'name': entry['name'] ?? nested['name'],
        'description': entry['description'] ?? nested['description'],
        'icon': entry['icon'] ?? nested['icon'],
        'level': entry['level'] ?? nested['level'],
        'points': entry['points'] ?? nested['points'],
      };
    }).toList();
  }

  Map<String, dynamic>? _normalizeLevelResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final nested = raw['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return raw;
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }
}

class _BadgeCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _BadgeCount({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

class _AchievementCategoryCard extends StatelessWidget {
  final String category;
  final List<dynamic> achievements;
  final bool isDark;

  const _AchievementCategoryCard({
    required this.category,
    required this.achievements,
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
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _getCategoryTitle(category),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${achievements.length}',
                  style: TextStyle(
                    color: _getCategoryColor(category),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: achievements
                .map(
                  (ach) => _AchievementBadge(achievement: ach, isDark: isDark),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _getCategoryTitle(String cat) {
    switch (cat) {
      case 'territory':
        return 'Territories';
      case 'donation':
        return 'Donations';
      case 'book_sale':
        return 'Books Distributed';
      case 'prayer':
        return 'Prayer';
      case 'visit':
        return 'Visits';
      case 'streak':
        return 'Streaks';
      case 'session':
        return 'Sessions';
      case 'team':
        return 'Team';
      default:
        return _toTitle(cat);
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'territory':
        return Icons.map_outlined;
      case 'donation':
        return Icons.volunteer_activism_outlined;
      case 'book_sale':
        return Icons.menu_book_rounded;
      case 'prayer':
        return Icons.church;
      case 'visit':
        return Icons.directions_walk_outlined;
      case 'streak':
        return Icons.local_fire_department;
      case 'session':
        return Icons.schedule_outlined;
      case 'team':
        return Icons.group;
      default:
        return Icons.emoji_events;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'territory':
        return AppColors.secondary;
      case 'donation':
        return AppColors.accent;
      case 'book_sale':
        return AppColors.warning;
      case 'prayer':
        return AppColors.warning;
      case 'visit':
        return AppColors.success;
      case 'streak':
        return Colors.orange;
      case 'session':
        return AppColors.primary;
      case 'team':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  String _toTitle(String value) {
    if (value.isEmpty) return 'Other';
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _AchievementBadge extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final bool isDark;

  const _AchievementBadge({required this.achievement, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = achievement['name']?.toString() ?? 'Achievement';
    final level = achievement['level']?.toString() ?? 'bronze';
    final points = achievement['points'] ?? 0;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getLevelColor(level).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getLevelColor(level).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(_getLevelIcon(level), color: _getLevelColor(level), size: 32),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$points pts',
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'platinum':
        return Colors.purple;
      case 'gold':
        return Colors.amber.shade700;
      case 'silver':
        return Colors.grey.shade600;
      default:
        return Colors.orange.shade700;
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'platinum':
        return Icons.diamond;
      case 'gold':
        return Icons.emoji_events;
      case 'silver':
        return Icons.workspace_premium;
      default:
        return Icons.military_tech;
    }
  }
}

class _LevelStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const _LevelStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
