import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/territory_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/territory/territory_bloc.dart';
import '../../widgets/widgets.dart';

class TerritoryScreen extends StatefulWidget {
  const TerritoryScreen({super.key});

  @override
  State<TerritoryScreen> createState() => _TerritoryScreenState();
}

class _TerritoryScreenState extends State<TerritoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isFabExpanded = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load data on init
    context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounce?.cancel();

    if (value.length < 2) return;

    // Debounce: wait 500ms after user stops typing before searching
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      context.read<TerritoryBloc>().add(TerritorySearch(query: value));
      // Switch to Map tab to show results on map
      if (_tabController.index != 2) {
        _tabController.animateTo(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Territory'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Areas'),
            Tab(text: 'Available'),
            Tab(text: 'Map'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchField(
              controller: _searchController,
              hint: 'Search territories...',
              onChanged: _onSearchChanged,
            ),
          ),
          // Tab Content - disable swipe to allow map panning
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MyAreasTab(isDark: isDark, tabController: _tabController),
                _AvailableTab(isDark: isDark, tabController: _tabController),
                _MapTab(isDark: isDark, tabController: _tabController),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCommunicationFab(context, isDark),
    );
  }

  Widget _buildCommunicationFab(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mini FABs (shown when expanded)
          if (_isFabExpanded) ...[
            // Chat button
            _MiniActionButton(
              icon: Icons.chat_bubble,
              label: 'Chat',
              color: AppColors.secondary,
              onTap: () {
                setState(() => _isFabExpanded = false);
                context.push('/chat');
              },
            ),
            const SizedBox(height: 12),
            // Walkie-talkie button
            _MiniActionButton(
              icon: Icons.speaker_phone,
              label: 'Walkie',
              color: AppColors.primary,
              onTap: () {
                setState(() => _isFabExpanded = false);
                showWalkieBottomSheet(context);
              },
            ),
            const SizedBox(height: 12),
          ],
          // Main FAB
          FloatingActionButton(
            heroTag: 'territory_fab',
            onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
            backgroundColor: _isFabExpanded ? Colors.grey : AppColors.primary,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _isFabExpanded ? 0.125 : 0,
              child: Icon(
                _isFabExpanded ? Icons.close : Icons.forum,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Territories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _FilterChip(label: 'All', selected: true),
                _FilterChip(label: 'Available', selected: false),
                _FilterChip(label: 'Assigned', selected: false),
                _FilterChip(label: 'Completed', selected: false),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Apply Filters',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {},
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }
}

class _MyAreasTab extends StatefulWidget {
  final bool isDark;
  final TabController tabController;

  const _MyAreasTab({required this.isDark, required this.tabController});

  @override
  State<_MyAreasTab> createState() => _MyAreasTabState();
}

class _MyAreasTabState extends State<_MyAreasTab> {
  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted) return; // Prevent using context after dispose
    // Reload assignments when switching back to this tab (index 0)
    if (widget.tabController.index == 0) {
      final currentState = context.read<TerritoryBloc>().state;
      // Only reload if not already showing assignments
      if (currentState is! TerritoryAssignmentsLoaded && currentState is! TerritoryLoading) {
        context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TerritoryBloc, TerritoryState>(
      builder: (context, state) {
        if (state is TerritoryLoading) {
          return const SkeletonList(
            itemCount: 5,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          );
        }

        if (state is TerritoryAssignmentsLoaded) {
          if (state.assignments.isEmpty) {
            return EmptyState(
              icon: Icons.map_outlined,
              title: 'No Assigned Territories',
              description: 'You don\'t have any territories assigned yet.\nBrowse available territories to request one.',
              actionLabel: 'Browse Available',
              onAction: () {},
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: state.assignments.length,
              itemBuilder: (context, index) {
                final assignment = state.assignments[index];
                return _AssignmentCard(
                  name: assignment.entityName ?? 'Territory ${index + 1}',
                  location: '${assignment.city ?? ''}, ${assignment.state ?? ''}'.trim(),
                  households: assignment.housingUnits ?? 0,
                  status: assignment.status,
                  progress: assignment.completenessPercentage,
                  isDark: widget.isDark,
                  onTap: () {},
                );
              },
            ),
          );
        }

        if (state is TerritoryError) {
          return ErrorState(
            message: state.message,
            onRetry: () {
              context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
            },
          );
        }

        return EmptyState(
          icon: Icons.map_outlined,
          title: 'No Assigned Territories',
          description: 'You don\'t have any territories assigned yet.\nBrowse available territories to request one.',
          actionLabel: 'Browse Available',
          onAction: () {},
        );
      },
    );
  }
}


class _AssignmentCard extends StatelessWidget {
  final String name;
  final String location;
  final int households;
  final String status;
  final double progress;
  final bool isDark;
  final VoidCallback? onTap;

  const _AssignmentCard({
    required this.name,
    required this.location,
    required this.households,
    required this.status,
    required this.progress,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'paused':
        statusColor = AppColors.warning;
        break;
      case 'completed':
        statusColor = AppColors.primary;
        break;
      default:
        statusColor = AppColors.secondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSpacing.avatarLg,
                    height: AppSpacing.avatarLg,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: Icon(Icons.location_on, color: statusColor),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$households households',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        '${progress.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableTab extends StatefulWidget {
  final bool isDark;
  final TabController tabController;

  const _AvailableTab({required this.isDark, required this.tabController});

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends State<_AvailableTab> {
  bool _isTeamLeader = false;

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
    _checkUserRole();
  }

  void _checkUserRole() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() {
        _isTeamLeader = authState.user.isTeamLeader;
      });
    }
  }

  void _onTabChange() {
    if (!mounted) return;
    if (widget.tabController.index == 1) {
      _loadTerritories();
    }
  }

  void _loadTerritories() {
    // Team leaders see only their allocated territories from admin
    if (_isTeamLeader) {
      context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
    } else {
      context.read<TerritoryBloc>().add(const TerritoryLoadAvailable());
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _showAssignToWorkerDialog(BuildContext context, GeoTerritory territory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignToWorkerSheet(
        territory: territory,
        isDark: widget.isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TerritoryBloc, TerritoryState>(
      builder: (context, state) {
        if (state is TerritoryLoading) {
          return const SkeletonList(
            itemCount: 5,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          );
        }

        // Handle team leader's allocated territories
        if (state is TerritoryAllocationsLoaded) {
          if (state.territories.isEmpty) {
            return EmptyState(
              icon: Icons.map_outlined,
              title: 'No Allocated Territories',
              description: 'You don\'t have any territories allocated yet.\nAn admin will allocate territories to you.',
              iconColor: AppColors.info,
              secondaryColor: AppColors.primary,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: state.territories.length,
              itemBuilder: (context, index) {
                final territory = state.territories[index];
                return _TerritoryCard(
                  name: territory.entityName,
                  union: territory.unionName ?? '',
                  households: territory.housingUnits ?? 0,
                  status: 'allocated',
                  isDark: widget.isDark,
                  isLeaderView: true,
                  onAssign: () => _showAssignToWorkerDialog(context, territory),
                );
              },
            ),
          );
        }

        // Handle regular available territories for workers
        if (state is TerritoryAvailableLoaded) {
          return RefreshIndicator(
            onRefresh: () async {
              context.read<TerritoryBloc>().add(const TerritoryLoadAvailable());
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: state.territories.length,
              itemBuilder: (context, index) {
                final territory = state.territories[index];
                return _TerritoryCard(
                  name: territory.entityName,
                  union: territory.unionName ?? '',
                  households: territory.housingUnits ?? 0,
                  status: 'available',
                  isDark: widget.isDark,
                  onRequest: () {
                    context.read<TerritoryBloc>().add(
                      TerritoryRequestAssignment(territoryId: territory.id),
                    );
                  },
                );
              },
            ),
          );
        }

        // Empty state - trigger load if not already loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state is! TerritoryLoading) {
            _loadTerritories();
          }
        });
        return const SkeletonList(
          itemCount: 5,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        );
      },
    );
  }
}

class _TerritoryCard extends StatelessWidget {
  final String name;
  final String union;
  final int households;
  final String status;
  final bool isDark;
  final VoidCallback? onRequest;
  final VoidCallback? onAssign;
  final bool isLeaderView;

  const _TerritoryCard({
    required this.name,
    required this.union,
    required this.households,
    required this.status,
    required this.isDark,
    this.onRequest,
    this.onAssign,
    this.isLeaderView = false,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Pending';
        break;
      case 'assigned':
        statusColor = AppColors.success;
        statusText = 'Assigned';
        break;
      case 'allocated':
        statusColor = AppColors.info;
        statusText = 'Allocated';
        break;
      default:
        statusColor = AppColors.primary;
        statusText = 'Available';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.smd),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppSpacing.avatarLg,
                  height: AppSpacing.avatarLg,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        union,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusFull,
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.home_outlined, size: AppSpacing.iconSm, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$households households',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            if (status == 'available' && onRequest != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Request Territory',
                  type: ButtonType.outline,
                  size: ButtonSize.small,
                  onPressed: onRequest!,
                ),
              ),
            ],
            if (isLeaderView && status == 'allocated' && onAssign != null) ...[
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Assign to Worker',
                  icon: Icons.person_add,
                  type: ButtonType.primary,
                  size: ButtonSize.small,
                  onPressed: onAssign!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapTab extends StatefulWidget {
  final bool isDark;
  final TabController tabController;

  const _MapTab({required this.isDark, required this.tabController});

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  GeoTerritory? _selectedTerritory;
  final List<VisitMarker> _visitMarkers = [];
  bool _isTeamLeader = false;
  bool _showOnlyMyTerritories = true; // Default to showing assigned territories
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
    _checkUserRole();
    _getUserLocation();
    // Load data immediately on init to prevent blank map on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMapData();
      }
    });
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() {
          _userLatitude = position.latitude;
          _userLongitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  void _checkUserRole() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() {
        _isTeamLeader = authState.user.isTeamLeader;
      });
    }
  }

  void _loadMapData() {
    final state = context.read<TerritoryBloc>().state;
    // Team leaders see only their allocated territories from admin
    if (_isTeamLeader) {
      if (state is! TerritoryAllocationsLoaded && state is! TerritoryLoading) {
        context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
      }
    } else {
      // Workers: load assigned territories first (default), or all available if toggled
      if (_showOnlyMyTerritories) {
        if (state is! TerritoryAssignmentsLoaded && state is! TerritoryLoading) {
          context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
        }
      } else {
        if (state is! TerritoryAvailableLoaded && state is! TerritoryLoading) {
          context.read<TerritoryBloc>().add(const TerritoryLoadAvailable(limit: 50));
        }
      }
    }
  }

  void _toggleTerritoryView() {
    setState(() {
      _showOnlyMyTerritories = !_showOnlyMyTerritories;
    });
    // Force reload based on new toggle state
    if (_showOnlyMyTerritories) {
      context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
    } else {
      context.read<TerritoryBloc>().add(const TerritoryLoadAvailable(limit: 50));
    }
  }

  void _onTabChange() {
    if (!mounted) return; // Prevent using context after dispose
    // Load territories when Map tab is selected
    if (widget.tabController.index == 2) {
      _loadMapData();
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TerritoryBloc, TerritoryState>(
      builder: (context, state) {
        // Handle search results - prioritize showing search results
        if (state is TerritorySearchResults && state.territories.isNotEmpty) {
          final territoriesWithGeometry = state.territories
              .where((t) => t.geometry != null)
              .toList();

          if (territoriesWithGeometry.isNotEmpty) {
            return _buildMapView(territoriesWithGeometry, isSearchResult: true, searchQuery: state.query);
          }
        }

        // Handle searching state
        if (state is TerritorySearching) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Searching territories...'),
              ],
            ),
          );
        }

        // Check if we have territories from assignments
        if (state is TerritoryAssignmentsLoaded && state.assignments.isNotEmpty) {
          // Convert assignments to GeoTerritory for the map
          final territories = state.assignments
              .where((a) => a.geometry != null)
              .map((a) => GeoTerritory(
                    id: a.territoryId,
                    solid: a.territorySolid,
                    entityName: a.entityName ?? 'Territory ${a.territorySolid}',
                    entityId: a.entityId ?? '',
                    city: a.city,
                    state: a.state,
                    unionName: a.unionName,
                    conference: a.conference,
                    population: a.population,
                    housingUnits: a.housingUnits,
                    geometry: a.geometry,
                  ))
              .toList();

          if (territories.isNotEmpty) {
            return _buildMapView(territories);
          }
        }

        // Handle team leader's allocated territories
        if (state is TerritoryAllocationsLoaded) {
          if (state.territories.isEmpty) {
            return _buildEmptyAllocationsState(context);
          }
          final territoriesWithGeometry = state.territories
              .where((t) => t.geometry != null)
              .toList();

          if (territoriesWithGeometry.isNotEmpty) {
            return _buildMapView(territoriesWithGeometry, isLeaderView: true);
          }
          return _buildEmptyAllocationsState(context);
        }

        // Check if we have available territories (for workers)
        if (state is TerritoryAvailableLoaded && state.territories.isNotEmpty) {
          final territoriesWithGeometry = state.territories
              .where((t) => t.geometry != null)
              .toList();

          if (territoriesWithGeometry.isNotEmpty) {
            return _buildMapView(territoriesWithGeometry);
          }
        }

        // Loading state
        if (state is TerritoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Empty or no geometry - trigger load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state is! TerritoryLoading) {
            _loadMapData();
          }
        });

        return _buildEmptyState(context);
      },
    );
  }

  Widget _buildMapView(List<GeoTerritory> territories, {bool isSearchResult = false, String? searchQuery, bool isLeaderView = false}) {
    return Stack(
      children: [
        TerritoryMapWidget(
          territories: territories,
          selectedTerritory: _selectedTerritory,
          onTerritoryTap: (territory) {
            setState(() => _selectedTerritory = territory);
            _showTerritoryDetails(context, territory);
          },
          showLabels: true,
          showZoomControls: true,
          visitMarkers: _visitMarkers,
          allowAddVisit: true,
          onAddVisit: (lat, lng) => _showAddVisitDialog(context, lat, lng),
          fitToTerritories: true, // Always fit to territories
          userLatitude: _userLatitude,
          userLongitude: _userLongitude,
        ),
        // Territory count badge with search indicator
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSearchResult ? AppColors.primary : Colors.white,
                  borderRadius: AppSpacing.borderRadiusFull,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSearchResult ? Icons.search : Icons.map_outlined,
                      size: 16,
                      color: isSearchResult ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSearchResult
                          ? '${territories.length} results for "$searchQuery"'
                          : '${territories.length} ${_showOnlyMyTerritories ? 'assigned' : 'available'} territories',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSearchResult ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (isSearchResult) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          // Clear search and reload based on toggle
                          if (_showOnlyMyTerritories) {
                            context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
                          } else {
                            context.read<TerritoryBloc>().add(const TerritoryLoadAvailable(limit: 50));
                          }
                        },
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
              // Toggle switch for workers (not team leaders)
              if (!_isTeamLeader && !isSearchResult) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _toggleTerritoryView,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppSpacing.borderRadiusFull,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOnlyMyTerritories ? Icons.person : Icons.public,
                          size: 16,
                          color: _showOnlyMyTerritories ? AppColors.success : AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showOnlyMyTerritories ? 'My Territories' : 'All Available',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _showOnlyMyTerritories ? AppColors.success : AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Long press hint
        Positioned(
          left: AppSpacing.md,
          bottom: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: AppSpacing.borderRadiusFull,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Long-press to mark visit',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddVisitDialog(BuildContext context, double latitude, double longitude) {
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    String selectedOutcome = 'not_home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: AppSpacing.avatarLg,
                    height: AppSpacing.avatarLg,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    child: const Icon(Icons.add_location_alt, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Visit',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Enter address or description',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Visit Outcome',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OutcomeChip(
                    label: 'Not Home',
                    value: 'not_home',
                    icon: Icons.home_outlined,
                    color: AppColors.warning,
                    selected: selectedOutcome == 'not_home',
                    onSelected: () => setSheetState(() => selectedOutcome = 'not_home'),
                  ),
                  _OutcomeChip(
                    label: 'Interested',
                    value: 'interested',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    selected: selectedOutcome == 'interested',
                    onSelected: () => setSheetState(() => selectedOutcome = 'interested'),
                  ),
                  _OutcomeChip(
                    label: 'Not Interested',
                    value: 'not_interested',
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                    selected: selectedOutcome == 'not_interested',
                    onSelected: () => setSheetState(() => selectedOutcome = 'not_interested'),
                  ),
                  _OutcomeChip(
                    label: 'Callback',
                    value: 'callback',
                    icon: Icons.schedule,
                    color: AppColors.info,
                    selected: selectedOutcome == 'callback',
                    onSelected: () => setSheetState(() => selectedOutcome = 'callback'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes about this visit',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Save Visit',
                  icon: Icons.save,
                  onPressed: () {
                    // Add the visit marker
                    setState(() {
                      _visitMarkers.add(VisitMarker(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        latitude: latitude,
                        longitude: longitude,
                        address: addressController.text.isNotEmpty ? addressController.text : null,
                        outcome: selectedOutcome,
                        notes: notesController.text.isNotEmpty ? notesController.text : null,
                        timestamp: DateTime.now(),
                      ));
                    });
                    Navigator.pop(context);
                    AppSnackbar.success(context, message: 'Visit logged successfully');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.map,
      title: 'No Territories to Display',
      description: 'No territories with map data available.\nTry loading available territories.',
      iconColor: AppColors.secondary,
      actionLabel: 'Load Territories',
      onAction: _loadMapData,
    );
  }

  Widget _buildEmptyAllocationsState(BuildContext context) {
    return EmptyState(
      icon: Icons.map_outlined,
      title: 'No Allocated Territories',
      description: 'You don\'t have any territories allocated yet.\nAn admin will allocate territories to you\nthat you can then assign to your team workers.',
      iconColor: AppColors.info,
      secondaryColor: AppColors.primary,
      actionLabel: 'Refresh',
      onAction: () {
        context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
      },
    );
  }

  void _showTerritoryDetails(BuildContext context, GeoTerritory territory) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: AppSpacing.avatarLg,
                  height: AppSpacing.avatarLg,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        territory.entityName,
                        style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${territory.solid}',
                        style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.mlg),
            _DetailRow(
              icon: Icons.location_city,
              label: 'Location',
              value: territory.displayLocation.isNotEmpty
                  ? territory.displayLocation
                  : 'Not specified',
            ),
            if (territory.unionName != null)
              _DetailRow(
                icon: Icons.account_balance,
                label: 'Union',
                value: territory.unionName!,
              ),
            if (territory.housingUnits != null)
              _DetailRow(
                icon: Icons.home,
                label: 'Housing Units',
                value: '${territory.housingUnits}',
              ),
            if (territory.population != null)
              _DetailRow(
                icon: Icons.people,
                label: 'Population',
                value: '${territory.population}',
              ),
            const SizedBox(height: 20),
            // Show different button based on role and view mode
            if (_isTeamLeader)
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Assign to Worker',
                  icon: Icons.person_add,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showAssignToWorkerDialog(context, territory);
                  },
                ),
              )
            else if (_showOnlyMyTerritories)
              // Viewing assigned territories - show status and work button
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.smd),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusMd,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned to you',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Start Working',
                      icon: Icons.play_arrow,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        // Navigate to territory detail or start work flow
                        AppSnackbar.info(context, message: 'Starting work in ${territory.entityName}');
                      },
                    ),
                  ),
                ],
              )
            else
              // Viewing available territories - show request button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Request Territory',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.read<TerritoryBloc>().add(
                      TerritoryRequestAssignment(territoryId: territory.id),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAssignToWorkerDialog(BuildContext context, GeoTerritory territory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AssignToWorkerSheet(
        territory: territory,
        isDark: widget.isDark,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondaryLight),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  const _OutcomeChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: AppSpacing.borderRadiusFull,
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.24),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSpacing.iconSm,
              color: selected ? color : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini action button for the expandable FAB
class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppSpacing.borderRadiusSm,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Mini FAB
        FloatingActionButton.small(
          heroTag: 'fab_$label',
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

/// Bottom sheet for team leaders to assign a territory to a worker
class _AssignToWorkerSheet extends StatefulWidget {
  final GeoTerritory territory;
  final bool isDark;

  const _AssignToWorkerSheet({
    required this.territory,
    required this.isDark,
  });

  @override
  State<_AssignToWorkerSheet> createState() => _AssignToWorkerSheetState();
}

class _AssignToWorkerSheetState extends State<_AssignToWorkerSheet> {
  List<dynamic> _workers = [];
  bool _isLoading = true;
  String? _selectedWorkerId;
  String? _teamId;
  String? _leaderId;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeamWorkers();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamWorkers() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        setState(() => _isLoading = false);
        return;
      }

      _leaderId = authState.user.id;
      _teamId = authState.user.teamId;

      if (_teamId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final api = await ApiClient.getInstance();
      final response = await api.get(
        '${ApiConstants.teams}/$_teamId/workers',
      );

      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['workers'] ?? response.data['members'] ?? [];
        setState(() {
          _workers = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading team workers: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _assignTerritory() async {
    if (_selectedWorkerId == null || _teamId == null || _leaderId == null) {
      AppSnackbar.warning(context, message: 'Please select a worker');
      return;
    }

    context.read<TerritoryBloc>().add(
      TerritoryAssignToWorker(
        territoryId: widget.territory.id,
        territorySolid: widget.territory.solid,
        workerId: _selectedWorkerId!,
        teamId: _teamId!,
        assignedBy: _leaderId!,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      ),
    );

    Navigator.pop(context);

    AppSnackbar.success(context, message: 'Territory assignment submitted');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: AppSpacing.avatarLg,
                height: AppSpacing.avatarLg,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: const Icon(Icons.person_add, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Territory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.territory.entityName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Territory info
          Container(
            padding: const EdgeInsets.all(AppSpacing.smd),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.territory.entityName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (widget.territory.displayLocation.isNotEmpty)
                        Text(
                          widget.territory.displayLocation,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.territory.housingUnits != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Text(
                      '${widget.territory.housingUnits} units',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Select worker
          Text(
            'Select Worker',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_workers.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No workers in your team yet.\nWorkers need to join and be approved first.',
                      style: TextStyle(
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _workers.length,
                itemBuilder: (context, index) {
                  final worker = _workers[index];
                  final workerId = worker['id']?.toString() ?? '';
                  final workerName = worker['display_name'] ?? worker['name'] ?? 'Worker';
                  final workerEmail = worker['email'] ?? '';
                  final isSelected = _selectedWorkerId == workerId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        workerName.isNotEmpty ? workerName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      workerName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      workerEmail,
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                    onTap: () {
                      setState(() => _selectedWorkerId = workerId);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusMd,
                    ),
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withValues(alpha: 0.04),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Add any notes for the worker',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Assign button
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Assign Territory',
              icon: Icons.check,
              onPressed: _workers.isNotEmpty ? _assignTerritory : null,
            ),
          ),
        ],
      ),
    );
  }
}
