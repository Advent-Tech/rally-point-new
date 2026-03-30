import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/prayer_request_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/prayer_request/prayer_request_bloc.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/navigation/app_back_button.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/states/empty_state.dart';

class PrayerRequestScreen extends StatefulWidget {
  const PrayerRequestScreen({super.key});

  @override
  State<PrayerRequestScreen> createState() => _PrayerRequestScreenState();
}

class _PrayerRequestScreenState extends State<PrayerRequestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedStatus;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrayerRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadPrayerRequests() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final isLeader =
          authState.user.role == 'team_leader' ||
          authState.user.role == 'admin';
      context.read<PrayerRequestBloc>().add(
        PrayerRequestRefresh(isLeader: isLeader, teamId: authState.user.teamId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.leading(context),
        title: const Text('Prayer Requests'),
        actions: [
          const RoleBadge(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrayerRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'List'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
          ],
        ),
      ),
      body: BlocBuilder<PrayerRequestBloc, PrayerRequestState>(
        builder: (context, state) {
          if (state is PrayerRequestLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PrayerRequestError) {
            return _buildErrorState(state.message);
          }

          if (state is PrayerRequestLoaded) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildListView(state, isDark),
                _buildStatsView(state, isDark),
              ],
            );
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/prayer-requests/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
        ),
      ),
    );
  }

  Widget _buildListView(PrayerRequestLoaded state, bool isDark) {
    final filteredRequests = _filterRequests(state.prayerRequests);

    if (filteredRequests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => _loadPrayerRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredRequests.length,
        itemBuilder: (context, index) {
          final request = filteredRequests[index];
          return _buildPrayerRequestCard(request, isDark);
        },
      ),
    );
  }

  List<PrayerRequestModel> _filterRequests(List<PrayerRequestModel> requests) {
    return requests.where((r) {
      if (_selectedStatus != null && r.status != _selectedStatus) return false;
      if (_selectedCategory != null && r.prayerCategory != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildPrayerRequestCard(PrayerRequestModel request, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getUrgencyColor(request.urgency).withAlpha(100),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildTypeChip(request.requestType),
                  const SizedBox(width: 8),
                  _buildStatusChip(request.status),
                  const Spacer(),
                  _buildUrgencyIndicator(request.urgency),
                ],
              ),
              const SizedBox(height: 12),

              // Requester name
              Text(
                request.requesterName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),

              // Prayer subject
              Text(
                request.prayerSubject,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Category and date
              Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    request.categoryDisplay,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const Spacer(),
                  if (request.createdAt != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(request.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
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

  Widget _buildTypeChip(String type) {
    final isHomeVisit = type == PrayerRequestType.homeVisit;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHomeVisit
            ? AppColors.warning.withAlpha(30)
            : AppColors.info.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHomeVisit ? Icons.home_outlined : Icons.church_outlined,
            size: 14,
            color: isHomeVisit ? AppColors.warning : AppColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            PrayerRequestType.getDisplayName(type),
            style: TextStyle(
              color: isHomeVisit ? AppColors.warning : AppColors.info,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        PrayerRequestStatus.getDisplayName(status),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildUrgencyIndicator(String urgency) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _getUrgencyColor(urgency).withAlpha(30),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getUrgencyIcon(urgency),
        size: 16,
        color: _getUrgencyColor(urgency),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case PrayerRequestStatus.pending:
        return AppColors.warning;
      case PrayerRequestStatus.scheduled:
        return AppColors.info;
      case PrayerRequestStatus.inProgress:
        return AppColors.primary;
      case PrayerRequestStatus.completed:
        return AppColors.success;
      case PrayerRequestStatus.cancelled:
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case PrayerUrgency.urgent:
        return AppColors.error;
      case PrayerUrgency.high:
        return AppColors.warning;
      case PrayerUrgency.normal:
        return AppColors.info;
      case PrayerUrgency.low:
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  IconData _getUrgencyIcon(String urgency) {
    switch (urgency) {
      case PrayerUrgency.urgent:
        return Icons.priority_high;
      case PrayerUrgency.high:
        return Icons.arrow_upward;
      case PrayerUrgency.normal:
        return Icons.remove;
      case PrayerUrgency.low:
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }

  Widget _buildStatsView(PrayerRequestLoaded state, bool isDark) {
    final stats = state.stats;
    if (stats == null) {
      return const Center(child: Text('No statistics available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  stats.totalRequests.toString(),
                  Icons.volunteer_activism,
                  AppColors.primary,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  stats.pendingRequests.toString(),
                  Icons.pending_actions,
                  AppColors.warning,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  stats.completedRequests.toString(),
                  Icons.check_circle_outline,
                  AppColors.success,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Home Visits',
                  stats.homeVisitRequests.toString(),
                  Icons.home_outlined,
                  AppColors.info,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // By Category
          if (stats.byCategory != null && stats.byCategory!.isNotEmpty) ...[
            Text(
              'By Category',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...stats.byCategory!.entries.map(
              (entry) => _buildProgressItem(
                PrayerCategory.getDisplayName(entry.key),
                entry.value,
                stats.totalRequests,
                isDark,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // By Urgency
          if (stats.byUrgency != null && stats.byUrgency!.isNotEmpty) ...[
            Text(
              'By Urgency',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...stats.byUrgency!.entries.map(
              (entry) => _buildProgressItem(
                PrayerUrgency.getDisplayName(entry.key),
                entry.value,
                stats.totalRequests,
                isDark,
                color: _getUrgencyColor(entry.key),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String label,
    int value,
    int total,
    bool isDark, {
    Color? color,
  }) {
    final progress = total > 0 ? value / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark
                ? AppColors.borderDark
                : AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.volunteer_activism_outlined,
      title: 'No Prayer Requests',
      description: 'Share a prayer request with your team.',
      actionLabel: 'New Prayer Request',
      onAction: () => context.push('/prayer-requests/new'),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Error', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CustomButton(text: 'Retry', onPressed: _loadPrayerRequests),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Prayer Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...PrayerRequestStatus.all.map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(PrayerRequestStatus.getDisplayName(s)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...PrayerCategory.all.map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(PrayerCategory.getDisplayName(c)),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _selectedCategory = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Clear Filters'),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _showRequestDetails(PrayerRequestModel request) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTypeChip(request.requestType),
                  const SizedBox(width: 8),
                  _buildStatusChip(request.status),
                  const Spacer(),
                  _buildUrgencyIndicator(request.urgency),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                request.requesterName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (request.requesterPhone != null)
                _buildDetailRow(Icons.phone_outlined, request.requesterPhone!),
              if (request.requesterEmail != null)
                _buildDetailRow(Icons.email_outlined, request.requesterEmail!),
              if (request.requesterAddress != null)
                _buildDetailRow(
                  Icons.location_on_outlined,
                  request.requesterAddress!,
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Prayer Subject',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(request.prayerSubject),
              const SizedBox(height: 16),
              Text(
                'Prayer Details',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(request.prayerDetails),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.category_outlined,
                    request.categoryDisplay,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.flag_outlined, request.urgencyDisplay),
                ],
              ),
              if (request.notes != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(request.notes!),
              ],
              const SizedBox(height: 24),
              if (request.status != PrayerRequestStatus.completed &&
                  request.status != PrayerRequestStatus.cancelled)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _markAsCompleted(request);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  void _markAsCompleted(PrayerRequestModel request) {
    context.read<PrayerRequestBloc>().add(
      PrayerRequestComplete(id: request.id),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
