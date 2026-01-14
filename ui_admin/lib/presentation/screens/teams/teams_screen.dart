import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/user_model.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<TeamModel> _teams = [];
  List<UserModel> _availableLeaders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Load teams
      final teamsResponse = await api.get(ApiConstants.teams);
      if (teamsResponse.statusCode == 200) {
        final data = teamsResponse.data is List
            ? teamsResponse.data
            : teamsResponse.data['teams'] ?? [];
        _teams = (data as List).map((json) => TeamModel.fromJson(json)).toList();
      }

      // Load verified team leaders without team
      final leadersResponse = await api.get(ApiConstants.adminTeamLeaders);
      if (leadersResponse.statusCode == 200) {
        // Backend returns { leaders: [...], total, pending, verified, rejected }
        final data = leadersResponse.data is List
            ? leadersResponse.data
            : leadersResponse.data['leaders'] ?? [];
        _availableLeaders = (data as List)
            .map((json) => UserModel.fromJson(json))
            .where((u) => u.isVerified && u.teamId == null)
            .toList();
        debugPrint('Loaded ${_availableLeaders.length} verified leaders without team');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load teams: $e')),
        );
      }
    }
  }

  void _showCreateTeamDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    UserModel? selectedLeader;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Team'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Team Name *',
                    hintText: 'Enter team name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownSearch<UserModel>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search leaders by name or email...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    itemBuilder: (context, item, isSelected) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withAlpha(30),
                        child: Text(
                          item.fullName.isNotEmpty ? item.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(item.fullName),
                      subtitle: Text(item.email, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                    ),
                  ),
                  items: _availableLeaders,
                  itemAsString: (item) => '${item.fullName} (${item.email})',
                  filterFn: (item, filter) {
                    final query = filter.toLowerCase();
                    return item.fullName.toLowerCase().contains(query) ||
                        item.email.toLowerCase().contains(query);
                  },
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      labelText: 'Assign Leader (Optional)',
                      hintText: 'Select a team leader',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  selectedItem: selectedLeader,
                  onChanged: (value) {
                    setDialogState(() => selectedLeader = value);
                  },
                  clearButtonProps: const ClearButtonProps(isVisible: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter team name')),
                  );
                  return;
                }
                Navigator.pop(context);
                _createTeam(
                  name: nameController.text,
                  description: descController.text,
                  leaderId: selectedLeader?.id,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTeam({
    required String name,
    String? description,
    String? leaderId,
  }) async {
    try {
      final api = await ApiClient.getInstance();
      await api.post(
        ApiConstants.adminTeams,
        data: {
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (leaderId != null) 'leader_id': leaderId,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create team: $e')),
        );
      }
    }
  }

  void _showAssignLeaderDialog(TeamModel team) {
    UserModel? selectedLeader;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Leader'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Team: ${team.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (_availableLeaders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No available team leaders'),
                  )
                else
                  DropdownSearch<UserModel>(
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search leaders by name or email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      itemBuilder: (context, item, isSelected) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withAlpha(30),
                          child: Text(
                            item.fullName.isNotEmpty ? item.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(item.fullName),
                        subtitle: Text(item.email, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                      ),
                    ),
                    items: _availableLeaders,
                    itemAsString: (item) => '${item.fullName} (${item.email})',
                    filterFn: (item, filter) {
                      final query = filter.toLowerCase();
                      return item.fullName.toLowerCase().contains(query) ||
                          item.email.toLowerCase().contains(query);
                    },
                    dropdownDecoratorProps: const DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Select Leader',
                        hintText: 'Search and select a leader',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    selectedItem: selectedLeader,
                    onChanged: (value) {
                      setDialogState(() => selectedLeader = value);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedLeader == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      _assignLeader(team, selectedLeader!);
                    },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignLeader(TeamModel team, UserModel leader) async {
    try {
      final api = await ApiClient.getInstance();
      await api.put(
        '${ApiConstants.adminTeams}/${team.id}/assign-leader',
        data: {'leader_id': leader.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${leader.fullName} assigned as leader of ${team.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign leader: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teams.isEmpty
              ? _buildEmptyState()
              : _buildTeamList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 80, color: AppColors.textSecondary),
          const SizedBox(height: 24),
          Text(
            'No Teams Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first team to get started',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateTeamDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Team'),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _teams.length,
        itemBuilder: (context, index) {
          final team = _teams[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              team.leaderName ?? 'No leader assigned',
                              style: TextStyle(
                                color: team.leaderName != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${team.memberCount} members',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: team.isActive
                          ? AppColors.success.withAlpha(30)
                          : AppColors.textSecondary.withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      team.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: team.isActive ? AppColors.success : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (team.leaderId == null)
                    OutlinedButton(
                      onPressed: () => _showAssignLeaderDialog(team),
                      child: const Text('Assign Leader'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
