import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/worker_tracking/worker_tracking_bloc.dart';

class WorkerTrackingScreen extends StatefulWidget {
  const WorkerTrackingScreen({super.key});

  @override
  State<WorkerTrackingScreen> createState() => _WorkerTrackingScreenState();
}

class _WorkerTrackingScreenState extends State<WorkerTrackingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String _searchQuery = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      context.read<WorkerTrackingBloc>().add(const WorkerTrackingRefreshWorkers());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWorkers();
    });
  }

  Future<void> _loadWorkers() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      String? teamId = authState.user.teamId;

      if (teamId == null && authState.user.isTeamLeader) {
        teamId = await _fetchLedTeamId(authState.user.id);
      }

      if (teamId != null && mounted) {
        context.read<WorkerTrackingBloc>().add(
          WorkerTrackingLoadWorkers(teamId: teamId),
        );
      }
    }
  }

  Future<String?> _fetchLedTeamId(String leaderId) async {
    try {
      final apiClient = await ApiClient.getInstance();
      final response = await apiClient.get('/api/teams?leader_id=$leaderId');
      if (response.statusCode == 200) {
        final data = response.data;
        final teams = data is List ? data : data['teams'] ?? [];
        if (teams.isNotEmpty) {
          return teams[0]['id']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search workers...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Track Workers'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: BlocBuilder<WorkerTrackingBloc, WorkerTrackingState>(
        builder: (context, state) {
          if (state is WorkerTrackingLoading) {
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
                    onPressed: _loadWorkers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is WorkerTrackingWorkersLoaded) {
            final workers = _searchQuery.isEmpty
                ? state.workers
                : state.workers
                    .where((w) => w.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();

            if (workers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No workers matching "$_searchQuery"'
                          : 'No active workers',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<WorkerTrackingBloc>().add(
                  WorkerTrackingLoadWorkers(teamId: state.teamId),
                );
                // Wait for state change
                await context.read<WorkerTrackingBloc>().stream.firstWhere(
                  (s) => s is WorkerTrackingWorkersLoaded || s is WorkerTrackingError,
                );
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return _WorkerCard(
                    worker: worker,
                    isDark: isDark,
                    pulseController: _pulseController,
                    onTap: () {
                      context.push(
                        '/leader/worker-trail/${worker.id}?name=${Uri.encodeComponent(worker.name)}',
                      );
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final TrackedWorker worker;
  final bool isDark;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _WorkerCard({
    required this.worker,
    required this.isDark,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = worker.status == 'working' || worker.status == 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  radius: 24,
                  child: Text(
                    worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        worker.territoryName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isActive)
                            AnimatedBuilder(
                              animation: pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(
                                      (150 + 105 * pulseController.value).toInt(),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              },
                            )
                          else
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.textSecondaryLight,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive ? AppColors.success : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (worker.todayDistanceKm != null) ...[
                            _dot(isDark),
                            Text(
                              '${worker.todayDistanceKm!.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                          if (worker.todayHours != null) ...[
                            _dot(isDark),
                            Text(
                              '${worker.todayHours!.toStringAsFixed(1)}h',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '\u2022',
        style: TextStyle(
          fontSize: 10,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
