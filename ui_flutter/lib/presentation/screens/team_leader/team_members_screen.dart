import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/team_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/team/team_bloc.dart';
import '../../widgets/custom_button.dart';

class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});

  @override
  State<TeamMembersScreen> createState() => _TeamMembersScreenState();
}

class _TeamMembersScreenState extends State<TeamMembersScreen> {
  late TeamBloc _teamBloc;

  @override
  void initState() {
    super.initState();
    _teamBloc = TeamBloc();

    // Load team members if user has a team
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.teamId != null) {
      _teamBloc.add(TeamLoadMembers(teamId: authState.user.teamId!));
    }
  }

  @override
  void dispose() {
    _teamBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _teamBloc,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Team Members'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite Member',
              onPressed: () => _showInviteDialog(context),
            ),
          ],
        ),
        body: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            if (state is TeamLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is TeamError) {
              return _buildErrorView(context, state.message, isDark);
            }

            if (state is TeamMembersLoaded) {
              final members = state.members;

              if (members.isEmpty) {
                return _buildEmptyState(context, isDark);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<TeamBloc>().add(const TeamRefresh());
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _TeamMemberCard(
                      member: member,
                      isDark: isDark,
                      onTap: () => _showMemberDetails(context, member),
                    );
                  },
                ),
              );
            }

            // Initial state - check if user has a team
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated && authState.user.teamId == null) {
              return _buildNoTeamView(context, isDark);
            }

            return _buildEmptyState(context, isDark);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showInviteDialog(context),
          backgroundColor: AppColors.secondary,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text(
            'Invite Member',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Retry',
              onPressed: () {
                context.read<TeamBloc>().add(const TeamRefresh());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTeamView(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 80,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 24),
            Text(
              'No Team Found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a team first to manage team members.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withAlpha(40),
                    AppColors.primary.withAlpha(40),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 48,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Team Members Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite workers to join your team so you can assign territories to them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Invite Team Member',
              icon: Icons.person_add,
              onPressed: () => _showInviteDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Team Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the email address of the person you want to invite to your team.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'example@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement invite functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite functionality coming soon'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  void _showMemberDetails(BuildContext context, TeamMember member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withAlpha(30),
              backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
              child: member.avatarUrl == null
                  ? Text(
                      (member.displayName ?? member.email ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              member.displayName ?? member.email ?? 'Unknown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (member.email != null) ...[
              const SizedBox(height: 4),
              Text(
                member.email!,
                style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(member.role).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatRole(member.role),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(member.role),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (member.isOnline ? Colors.green : Colors.grey).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: member.isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: member.isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (member.role == 'worker') ...[
              // Use Column to avoid overflow
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'View Assignments',
                      icon: Icons.map_outlined,
                      type: ButtonType.outline,
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to worker's territory assignments
                        context.push('/leader/worker-assignments/${member.userId}?name=${Uri.encodeComponent(member.displayName ?? member.email ?? 'Worker')}');
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Assign Territory',
                      icon: Icons.add_location,
                      onPressed: () {
                        Navigator.pop(context);
                        // Pass worker ID so territory assignment can pre-select this worker
                        context.push('/leader/territory-assignment?workerId=${member.userId}&workerName=${Uri.encodeComponent(member.displayName ?? member.email ?? 'Worker')}');
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'team_leader':
        return AppColors.secondary;
      case 'worker':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'team_leader':
        return 'Team Leader';
      case 'worker':
        return 'Worker';
      default:
        return role;
    }
  }
}

class _TeamMemberCard extends StatelessWidget {
  final TeamMember member;
  final bool isDark;
  final VoidCallback? onTap;

  const _TeamMemberCard({
    required this.member,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withAlpha(30),
                backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                child: member.avatarUrl == null
                    ? Text(
                        (member.displayName ?? member.email ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName ?? member.email ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (member.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.email!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getRoleColor(member.role).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatRole(member.role),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(member.role),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: member.isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          member.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
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
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'team_leader':
        return AppColors.secondary;
      case 'worker':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'team_leader':
        return 'Team Leader';
      case 'worker':
        return 'Worker';
      default:
        return role;
    }
  }
}
