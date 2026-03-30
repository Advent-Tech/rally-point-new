import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/target_models.dart';
import '../../../data/repositories/targets_repository.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/navigation/app_back_button.dart';

class LeaderTargetsScreen extends StatefulWidget {
  const LeaderTargetsScreen({super.key});

  @override
  State<LeaderTargetsScreen> createState() => _LeaderTargetsScreenState();
}

class _LeaderTargetsScreenState extends State<LeaderTargetsScreen>
    with SingleTickerProviderStateMixin {
  final TargetsRepository _targetsRepository = TargetsRepository();

  List<AssignedTargetWithProgress> _assignedTargets = [];
  List<TargetDefinition> _templates = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  String? _resolvedTeamId;

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
      final teamId = await _ensureTeamId();
      final assignedRes = await _targetsRepository.getLeaderAssignedTargets(
        teamId: teamId,
      );
      final templatesRes = await _targetsRepository.getLeaderTargetTemplates();

      if (!mounted) return;

      setState(() {
        final errors = <String>[];
        if (assignedRes.isSuccess) {
          _assignedTargets = assignedRes.data ?? [];
        } else {
          errors.add(assignedRes.errorMessage ?? 'Failed to load assigned');
        }

        if (templatesRes.isSuccess) {
          _templates = templatesRes.data ?? [];
        } else {
          errors.add(templatesRes.errorMessage ?? 'Failed to load templates');
        }

        _error = errors.isEmpty ? null : errors.join('\n');
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading leader targets: $e');
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
        leading: AppBackButton.leading(
          context,
          fallbackRoute: '/leader/dashboard',
        ),
        title: const Text('Targets'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Assigned'),
            Tab(text: 'Templates'),
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
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _showCreateTargetDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : TabBarView(
              controller: _tabController,
              children: [_buildAssignedTab(isDark), _buildTemplatesTab(isDark)],
            ),
    );
  }

  Widget _buildAssignedTab(bool isDark) {
    if (_assignedTargets.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.analytics_outlined,
        title: 'No Assigned Targets',
        subtitle: 'Assign targets to a team or worker',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assignedTargets.length,
        itemBuilder: (context, index) {
          final item = _assignedTargets[index];
          return _AssignedTargetCard(
            item: item,
            isDark: isDark,
            onRemove: () => _confirmRemoveAssignment(item.assignment.id),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesTab(bool isDark) {
    if (_templates.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.flag_outlined,
        title: 'No Templates',
        subtitle: 'Create a target template, then assign it',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final target = _templates[index];
          return _TemplateTargetCard(
            target: target,
            isDark: isDark,
            onEdit: () => _showEditTargetDialog(target),
            onDelete: () => _confirmDeleteTemplate(target.id),
            onAssign: () => _showAssignDialog(target),
          );
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

  String? _currentTeamId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final teamId = authState.user.teamId;
      if (teamId != null && teamId.isNotEmpty) return teamId;
    }
    return _resolvedTeamId;
  }

  Future<String?> _ensureTeamId() async {
    final current = _currentTeamId();
    if (current != null && current.isNotEmpty) return current;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return null;

    if (!authState.user.isTeamLeader) return null;

    final res = await _targetsRepository.getLeaderTeamId(authState.user.id);
    if (!mounted) return null;

    if (res.isSuccess) {
      final teamId = res.data;
      if (teamId != null && teamId.isNotEmpty) {
        setState(() {
          _resolvedTeamId = teamId;
        });
      }
      return teamId;
    }

    _showSnack(res.errorMessage ?? 'Failed to resolve team id');
    return null;
  }

  Future<void> _showCreateTargetDialog() async {
    await _showCreateEditDialog();
  }

  Future<void> _showEditTargetDialog(TargetDefinition target) async {
    await _showCreateEditDialog(existing: target);
  }

  Future<void> _showCreateEditDialog({TargetDefinition? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valueCtrl = TextEditingController(
      text: existing == null ? '' : existing.targetValue.toStringAsFixed(0),
    );

    String targetType = existing?.targetType.isNotEmpty == true
        ? existing!.targetType
        : 'territory';
    String targetUnit = existing?.targetUnit.isNotEmpty == true
        ? existing!.targetUnit
        : 'count';
    String periodType = existing?.periodType.isNotEmpty == true
        ? existing!.periodType
        : 'weekly';

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> onSave() async {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                isSaving = true;
                error = null;
              });

              final value = double.tryParse(valueCtrl.text.trim()) ?? 0;
              final description = descCtrl.text.trim();

              final res = existing == null
                  ? await _targetsRepository.createTargetTemplate(
                      name: nameCtrl.text.trim(),
                      description: description,
                      targetType: targetType,
                      targetUnit: targetUnit,
                      targetValue: value,
                      periodType: periodType,
                    )
                  : await _targetsRepository.updateTargetTemplate(
                      targetId: existing.id,
                      name: nameCtrl.text.trim(),
                      description: description,
                      targetType: targetType,
                      targetUnit: targetUnit,
                      targetValue: value,
                      periodType: periodType,
                    );

              if (!mounted) return;

              if (res.isSuccess) {
                Navigator.of(context).pop();
                setState(() {
                  isSaving = false;
                });
                await _reloadAfterMutation();
              } else {
                setState(() {
                  isSaving = false;
                  error = res.errorMessage ?? 'Failed to save target';
                });
              }
            }

            return AlertDialog(
              title: Text(existing == null ? 'Create Target' : 'Edit Target'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: targetType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'territory',
                            child: Text('Territory'),
                          ),
                          DropdownMenuItem(
                            value: 'donation',
                            child: Text('Donation'),
                          ),
                          DropdownMenuItem(
                            value: 'prayer',
                            child: Text('Prayer'),
                          ),
                          DropdownMenuItem(
                            value: 'visit',
                            child: Text('Visit'),
                          ),
                          DropdownMenuItem(
                            value: 'session',
                            child: Text('Session'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (v) =>
                                  setState(() => targetType = v ?? targetType),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: targetUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: const [
                          DropdownMenuItem(
                            value: 'count',
                            child: Text('Count'),
                          ),
                          DropdownMenuItem(
                            value: 'amount',
                            child: Text('Amount'),
                          ),
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage'),
                          ),
                          DropdownMenuItem(
                            value: 'hours',
                            child: Text('Hours'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (v) =>
                                  setState(() => targetUnit = v ?? targetUnit),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: valueCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Target value',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null) return 'Invalid number';
                          if (parsed <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: periodType,
                        decoration: const InputDecoration(labelText: 'Period'),
                        items: const [
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Daily'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Weekly'),
                          ),
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Text('Monthly'),
                          ),
                          DropdownMenuItem(
                            value: 'cumulative',
                            child: Text('Cumulative'),
                          ),
                        ],
                        onChanged: isSaving
                            ? null
                            : (v) =>
                                  setState(() => periodType = v ?? periodType),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignDialog(TargetDefinition target) async {
    final teamId = await _ensureTeamId();
    final workersRes = await _targetsRepository.getAssignableWorkers(
      teamId: teamId,
    );
    final workers = workersRes.data ?? [];

    if (!mounted) return;

    String mode = 'team';
    TeamMemberLite? selectedWorker;
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> onAssign() async {
              setState(() {
                isSaving = true;
                error = null;
              });

              final resolvedTeamId = await _ensureTeamId();

              final res = mode == 'team'
                  ? (resolvedTeamId == null || resolvedTeamId.isEmpty)
                        ? const ApiResult<void>.failure(
                            'Unable to resolve team id',
                          )
                        : await _targetsRepository.assignTargetToTeam(
                            targetId: target.id,
                            teamId: resolvedTeamId,
                          )
                  : (selectedWorker == null)
                  ? const ApiResult<void>.failure('Select a worker')
                  : await _targetsRepository.assignTargetToWorker(
                      targetId: target.id,
                      workerId: selectedWorker!.id,
                    );

              if (!mounted) return;

              if (res.isSuccess) {
                Navigator.of(context).pop();
                await _reloadAfterMutation();
              } else {
                setState(() {
                  isSaving = false;
                  error = res.errorMessage ?? 'Failed to assign';
                });
              }
            }

            return AlertDialog(
              title: const Text('Assign Target'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'team', label: Text('Team')),
                      ButtonSegment(value: 'worker', label: Text('Worker')),
                    ],
                    selected: {mode},
                    onSelectionChanged: isSaving
                        ? null
                        : (s) => setState(() => mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'team')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        (teamId == null || teamId.isEmpty)
                            ? 'Resolving team…'
                            : 'Assign to your team',
                      ),
                    )
                  else
                    DropdownButtonFormField<TeamMemberLite>(
                      value: selectedWorker,
                      decoration: const InputDecoration(
                        labelText: 'Select worker',
                      ),
                      items: workers
                          .map(
                            (w) =>
                                DropdownMenuItem(value: w, child: Text(w.name)),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (v) => setState(() => selectedWorker = v),
                    ),
                  if (workersRes.isFailure) ...[
                    const SizedBox(height: 8),
                    Text(
                      workersRes.errorMessage ?? 'Failed to load workers',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : onAssign,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteTemplate(String targetId) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete target?'),
              content: const Text('This will delete the target template.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;
    final res = await _targetsRepository.deleteTargetTemplate(targetId);
    if (!mounted) return;
    if (res.isSuccess) {
      await _reloadAfterMutation();
    } else {
      _showSnack(res.errorMessage ?? 'Failed to delete target');
    }
  }

  Future<void> _confirmRemoveAssignment(String assignmentId) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Remove assignment?'),
              content: const Text('This will unassign the target.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;
    final res = await _targetsRepository.deleteAssignment(assignmentId);
    if (!mounted) return;
    if (res.isSuccess) {
      await _reloadAfterMutation();
    } else {
      _showSnack(res.errorMessage ?? 'Failed to remove assignment');
    }
  }

  Future<void> _reloadAfterMutation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    await _loadData();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AssignedTargetCard extends StatelessWidget {
  final AssignedTargetWithProgress item;
  final bool isDark;
  final VoidCallback onRemove;

  const _AssignedTargetCard({
    required this.item,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final target = item.assignment.target;
    final name = target?.name.isNotEmpty == true ? target!.name : 'Target';
    final type = target?.targetType.isNotEmpty == true
        ? target!.targetType
        : 'other';
    final targetValue = target?.targetValue ?? 0;
    final currentValue = item.progress.currentValue;
    final progress = targetValue > 0 ? currentValue / targetValue : 0.0;
    final assignedTo = item.assignment.assignedToType.toUpperCase();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentValue.toStringAsFixed(0)} / ${targetValue.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      assignedTo,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.link_off),
                    tooltip: 'Remove assignment',
                  ),
                ],
              ),
            ],
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

class _TemplateTargetCard extends StatelessWidget {
  final TargetDefinition target;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAssign;

  const _TemplateTargetCard({
    required this.target,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final type = target.targetType;
    final unit = target.targetUnit;
    final value = target.targetValue;
    final period = target.periodType;
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
          child: const Icon(Icons.flag_outlined, color: AppColors.primary),
        ),
        title: Text(
          target.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.navyBlue,
          ),
        ),
        subtitle: Text(
          '${type.toUpperCase()} • ${value.toStringAsFixed(0)} ${unit.toUpperCase()} • ${period.toUpperCase()}',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'assign':
                onAssign();
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'assign', child: Text('Assign')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
