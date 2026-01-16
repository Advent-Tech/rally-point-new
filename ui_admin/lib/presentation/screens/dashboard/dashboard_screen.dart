import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../blocs/auth/auth_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalUsers = 0;
  int _pendingLeaders = 0;
  int _activeTeams = 0;
  int _totalTerritories = 0;
  int _allocatedTerritories = 0;
  int _totalSurveys = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = await ApiClient.getInstance();

      // Fetch team leaders stats
      try {
        final leadersResponse = await apiClient.get(
          ApiConstants.adminTeamLeaders,
        );
        if (leadersResponse.data != null) {
          _totalUsers = leadersResponse.data['total'] ?? 0;
          _pendingLeaders = leadersResponse.data['pending'] ?? 0;
        }
      } catch (e) {
        debugPrint('Failed to load team leaders: $e');
      }

      // Fetch teams count
      try {
        final teamsResponse = await apiClient.get('${ApiConstants.teams}/');
        if (teamsResponse.data != null) {
          _activeTeams = teamsResponse.data['count'] ?? 0;
        }
      } catch (e) {
        debugPrint('Failed to load teams: $e');
      }

      // Fetch territory allocations
      try {
        final allocationsResponse = await apiClient.get(
          ApiConstants.adminTerritoryAllocations,
        );
        if (allocationsResponse.data != null) {
          _allocatedTerritories = allocationsResponse.data['total'] ?? 0;
        }
      } catch (e) {
        debugPrint('Failed to load allocations: $e');
      }

      // Fetch territory stats (union stats)
      try {
        final territoryResponse = await apiClient.get(ApiConstants.unionStats);
        if (territoryResponse.data != null &&
            territoryResponse.data['unions'] != null) {
          final unions = territoryResponse.data['unions'] as List;
          _totalTerritories = unions.fold<int>(
            0,
            (sum, u) => sum + ((u['territory_count'] ?? 0) as int),
          );
        }
      } catch (e) {
        debugPrint('Failed to load territory stats: $e');
      }

      // Fetch surveys count
      try {
        final surveysResponse = await apiClient.get(ApiConstants.surveys);
        if (surveysResponse.data != null) {
          if (surveysResponse.data is List) {
            _totalSurveys = (surveysResponse.data as List).length;
          } else if (surveysResponse.data['surveys'] != null) {
            _totalSurveys = (surveysResponse.data['surveys'] as List).length;
          } else if (surveysResponse.data['count'] != null) {
            _totalSurveys = surveysResponse.data['count'];
          }
        }
      } catch (e) {
        debugPrint('Failed to load surveys: $e');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh',
          ),
          if (user != null && !isMobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  user.email,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Message
                    Text(
                      'Welcome back${user != null ? '!' : ', Admin!'}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 20 : null,
                          ),
                    ),
                    if (isMobile && user != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Here\'s an overview of your Rally Point system.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: isMobile ? 14 : null,
                      ),
                    ),
                    SizedBox(height: isMobile ? 20 : 32),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Some data failed to load. Pull to refresh.',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Stats Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount;
                        double childAspectRatio;

                        if (constraints.maxWidth > 1200) {
                          crossAxisCount = 4;
                          childAspectRatio = 1.8;
                        } else if (constraints.maxWidth > 800) {
                          crossAxisCount = 3;
                          childAspectRatio = 1.6;
                        } else if (constraints.maxWidth > 500) {
                          crossAxisCount = 2;
                          childAspectRatio = 1.5;
                        } else {
                          crossAxisCount = 2;
                          childAspectRatio = 1.3;
                        }

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: isMobile ? 12 : 16,
                          crossAxisSpacing: isMobile ? 12 : 16,
                          childAspectRatio: childAspectRatio,
                          children: [
                            _StatCard(
                              title: 'Team Leaders',
                              value: _totalUsers.toString(),
                              subtitle: '$_pendingLeaders pending',
                              icon: Icons.people,
                              color: AppColors.primary,
                              isMobile: isMobile,
                            ),
                            _StatCard(
                              title: 'Active Teams',
                              value: _activeTeams.toString(),
                              icon: Icons.groups,
                              color: AppColors.secondary,
                              isMobile: isMobile,
                            ),
                            _StatCard(
                              title: 'Territories',
                              value: _totalTerritories.toString(),
                              subtitle: '$_allocatedTerritories allocated',
                              icon: Icons.map,
                              color: AppColors.info,
                              isMobile: isMobile,
                            ),
                            _StatCard(
                              title: 'Surveys',
                              value: _totalSurveys.toString(),
                              icon: Icons.assignment,
                              color: AppColors.warning,
                              isMobile: isMobile,
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: isMobile ? 24 : 32),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 18 : null,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),

                    // Responsive Quick Actions
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = isMobile
                            ? constraints.maxWidth
                            : (isTablet
                                  ? (constraints.maxWidth - 16) / 2
                                  : 280.0);

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickActionCard(
                              title: 'Verify Team Leaders',
                              description:
                                  'Review pending team leader accounts',
                              icon: Icons.verified_user,
                              color: AppColors.success,
                              badge: _pendingLeaders > 0
                                  ? _pendingLeaders.toString()
                                  : null,
                              width: cardWidth,
                              isMobile: isMobile,
                              onTap: () => context.go('/users'),
                            ),
                            _QuickActionCard(
                              title: 'Allocate Territories',
                              description: 'Assign territories to team leaders',
                              icon: Icons.add_location,
                              color: AppColors.primary,
                              width: cardWidth,
                              isMobile: isMobile,
                              onTap: () => context.go('/territories'),
                            ),
                            _QuickActionCard(
                              title: 'Create Survey',
                              description: 'Design a new survey for teams',
                              icon: Icons.add_chart,
                              color: AppColors.info,
                              width: cardWidth,
                              isMobile: isMobile,
                              onTap: () => context.go('/surveys'),
                            ),
                            _QuickActionCard(
                              title: 'View Donations',
                              description: 'Check donation reports',
                              icon: Icons.volunteer_activism,
                              color: AppColors.warning,
                              width: cardWidth,
                              isMobile: isMobile,
                              onTap: () => context.go('/donations'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
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
  final bool isMobile;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: isMobile ? 16 : 20),
                ),
                Icon(
                  Icons.trending_up,
                  color: AppColors.success,
                  size: isMobile ? 14 : 16,
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 20 : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: isMobile ? 11 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: isMobile ? 10 : 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  final double width;
  final bool isMobile;

  const _QuickActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
    required this.width,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: isMobile ? 20 : 24),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 14 : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: isMobile ? 12 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: isMobile ? 14 : 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
