import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/user_model.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _pendingLeaders = [];
  List<UserModel> _pendingWorkers = [];
  List<UserModel> _allUsers = [];
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Load pending team leaders
      final leadersResponse = await api.get(ApiConstants.adminTeamLeaders);
      debugPrint(
          'Leaders response: ${leadersResponse.statusCode} - ${leadersResponse.data}');
      if (leadersResponse.statusCode == 200) {
        final data = leadersResponse.data is List
            ? leadersResponse.data
            : leadersResponse.data['leaders'] ?? [];
        _pendingLeaders = (data as List)
            .map((json) => UserModel.fromJson(json))
            .where((u) => u.isPending)
            .toList();
        debugPrint('Parsed ${_pendingLeaders.length} pending leaders');
      }

      // Load pending workers
      final workersResponse = await api.get(ApiConstants.adminWorkersPending);
      if (workersResponse.statusCode == 200) {
        final data = workersResponse.data is List
            ? workersResponse.data
            : workersResponse.data['workers'] ?? [];
        _pendingWorkers =
            (data as List).map((json) => UserModel.fromJson(json)).toList();
      }

      // Load all users (leaders + verified workers)
      _allUsers = [];
      try {
        // Get all leaders (any status)
        final allLeadersResponse = await api.get(ApiConstants.adminTeamLeaders);
        if (allLeadersResponse.statusCode == 200) {
          final data = allLeadersResponse.data is List
              ? allLeadersResponse.data
              : allLeadersResponse.data['leaders'] ?? [];
          _allUsers.addAll(
              (data as List).map((json) => UserModel.fromJson(json)));
        }
        // Get verified workers
        final verifiedWorkersResponse =
            await api.get(ApiConstants.adminWorkersVerified);
        if (verifiedWorkersResponse.statusCode == 200) {
          final data = verifiedWorkersResponse.data is List
              ? verifiedWorkersResponse.data
              : verifiedWorkersResponse.data['workers'] ?? [];
          _allUsers.addAll(
              (data as List).map((json) => UserModel.fromJson(json)));
        }
        // Add pending workers too
        _allUsers.addAll(_pendingWorkers);
        // Remove duplicates by ID
        final seen = <String>{};
        _allUsers = _allUsers.where((u) => seen.add(u.id)).toList();
      } catch (e) {
        debugPrint('Failed to load all users: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  Future<void> _verifyUser(UserModel user) async {
    try {
      final api = await ApiClient.getInstance();
      final endpoint = user.isTeamLeader
          ? '${ApiConstants.adminTeamLeaders}/${user.id}/verify'
          : '${ApiConstants.adminWorkers}/${user.id}/verify';

      await api.put(endpoint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been verified'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify user: $e')),
        );
      }
    }
  }

  Future<void> _rejectUser(UserModel user, String reason) async {
    try {
      final api = await ApiClient.getInstance();
      final endpoint = user.isTeamLeader
          ? '${ApiConstants.adminTeamLeaders}/${user.id}/reject'
          : '${ApiConstants.adminWorkers}/${user.id}/reject';

      await api.put(endpoint, data: {'reason': reason});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} has been rejected'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject user: $e')),
        );
      }
    }
  }

  void _showRejectDialog(UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting: ${user.fullName}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(context);
              _rejectUser(user, controller.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isMobile ? 'Leaders' : 'Pending Leaders'),
                  if (_pendingLeaders.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingLeaders.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isMobile ? 'Workers' : 'Pending Workers'),
                  if (_pendingWorkers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingWorkers.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: isMobile ? 'All' : 'All Users'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingList(_pendingLeaders, 'team leaders'),
                _buildPendingList(_pendingWorkers, 'workers'),
                _buildAllUsers(),
              ],
            ),
    );
  }

  Widget _buildPendingList(List<UserModel> users, String type) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              'No pending $type',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'All $type have been reviewed',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return Card(
            margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: isMobile
                  ? _buildMobileUserCard(user)
                  : _buildDesktopUserCard(user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopUserCard(UserModel user) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(30),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (user.teamName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Team: ${user.teamName}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.warning.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Pending',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () => _showRejectDialog(user),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
          child: const Text('Reject'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => _verifyUser(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
          ),
          child: const Text('Verify'),
        ),
      ],
    );
  }

  Widget _buildMobileUserCard(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        if (user.teamName != null) ...[
          const SizedBox(height: 8),
          Text(
            'Team: ${user.teamName}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _showRejectDialog(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _verifyUser(user),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Verify'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllUsers() {
    if (_allUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No Users Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: _allUsers.length,
        itemBuilder: (context, index) {
          final user = _allUsers[index];
          return Card(
            margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRoleColor(user).withAlpha(30),
                child: Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: _getRoleColor(user),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.email,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (user.teamName != null)
                    Text(
                      'Team: ${user.teamName}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRoleColor(user).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getRoleLabel(user),
                      style: TextStyle(
                        color: _getRoleColor(user),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(user).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.verificationStatus?.toUpperCase() ?? 'N/A',
                      style: TextStyle(
                        color: _getStatusColor(user),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(UserModel user) {
    if (user.isAdmin || user.isSuperAdmin) return AppColors.error;
    if (user.isTeamLeader) return AppColors.primary;
    return AppColors.info;
  }

  String _getRoleLabel(UserModel user) {
    if (user.isSuperAdmin) return 'SUPERADMIN';
    if (user.isAdmin) return 'ADMIN';
    if (user.isTeamLeader) return 'LEADER';
    return 'WORKER';
  }

  Color _getStatusColor(UserModel user) {
    if (user.isVerified) return AppColors.success;
    if (user.isPending) return AppColors.warning;
    if (user.isRejected) return AppColors.error;
    return AppColors.textSecondary;
  }
}
