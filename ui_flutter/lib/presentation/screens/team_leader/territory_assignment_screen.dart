import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/territory_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/team/team_bloc.dart';
import '../../blocs/territory/territory_bloc.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/territory_map_widget.dart';
import '../../widgets/feedback/app_snackbar.dart';

class TerritoryAssignmentScreen extends StatefulWidget {
  final String? preSelectedWorkerId;
  final String? preSelectedWorkerName;

  const TerritoryAssignmentScreen({
    super.key,
    this.preSelectedWorkerId,
    this.preSelectedWorkerName,
  });

  @override
  State<TerritoryAssignmentScreen> createState() => _TerritoryAssignmentScreenState();
}

class _TerritoryAssignmentScreenState extends State<TerritoryAssignmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TeamBloc _teamBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _teamBloc = TeamBloc();

    // Team leaders should only see territories allocated to them by admin
    // Use TerritoryLoadMyAllocations instead of TerritoryLoadAvailable
    context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());

    // Load team members if user has a team
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.teamId != null) {
      _teamBloc.add(TeamLoadMembers(teamId: authState.user.teamId!));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          title: const Text('Territory Assignment'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Territories'),
              Tab(text: 'Team Members'),
            ],
            indicatorColor: AppColors.secondary,
            labelColor: AppColors.secondary,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(), // Disable swipe to allow map panning
          children: [
            _TerritoriesTab(
              isDark: isDark,
              preSelectedWorkerId: widget.preSelectedWorkerId,
              preSelectedWorkerName: widget.preSelectedWorkerName,
            ),
            _TeamMembersTab(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _TerritoriesTab extends StatefulWidget {
  final bool isDark;
  final String? preSelectedWorkerId;
  final String? preSelectedWorkerName;

  const _TerritoriesTab({
    required this.isDark,
    this.preSelectedWorkerId,
    this.preSelectedWorkerName,
  });

  @override
  State<_TerritoriesTab> createState() => _TerritoriesTabState();
}

class _TerritoriesTabState extends State<_TerritoriesTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  String _currentSearchQuery = '';
  bool _isLoadingMore = false;
  bool _isMapView = true; // Default to map view to show territory boundaries
  GeoTerritory? _selectedTerritory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<TerritoryBloc>().state;

      // Handle pagination for search results
      if (state is TerritorySearchResults && state.hasMore) {
        setState(() => _isLoadingMore = true);
        context.read<TerritoryBloc>().add(TerritorySearch(
          query: _currentSearchQuery,
          offset: state.territories.length,
        ));
      }
      // Handle pagination for regular list
      else if (state is TerritoryAvailableLoaded && state.hasMore) {
        setState(() => _isLoadingMore = true);
        context.read<TerritoryBloc>().add(TerritoryLoadAvailable(
          offset: state.currentOffset,
        ));
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentSearchQuery = query;
        _isLoadingMore = false;
      });
      if (query.isNotEmpty) {
        // Use dedicated search endpoint for actual search
        context.read<TerritoryBloc>().add(TerritorySearch(
          query: query,
          offset: 0,
        ));
      } else {
        // Load allocated territories when search is cleared
        context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearchQuery = '';
      _isLoadingMore = false;
    });
    context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar and View Toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search territories...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: widget.isDark ? AppColors.backgroundDark : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // View Toggle Button
                  Container(
                    decoration: BoxDecoration(
                      color: widget.isDark ? AppColors.backgroundDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ViewToggleButton(
                          icon: Icons.list,
                          isSelected: !_isMapView,
                          onTap: () => setState(() => _isMapView = false),
                          isLeft: true,
                        ),
                        _ViewToggleButton(
                          icon: Icons.map,
                          isSelected: _isMapView,
                          onTap: () => setState(() => _isMapView = true),
                          isLeft: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Results (List or Map view)
        Expanded(
          child: BlocConsumer<TerritoryBloc, TerritoryState>(
            listener: (context, state) {
              if (state is TerritoryAvailableLoaded ||
                  state is TerritorySearchResults ||
                  state is TerritoryAllocationsLoaded) {
                setState(() => _isLoadingMore = false);
              }
            },
            builder: (context, state) {
              if (state is TerritoryLoading || state is TerritorySearching) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is TerritoryError) {
                return _buildErrorView(state.message);
              }

              // Get territories from either state
              // TerritoryAllocationsLoaded = territories allocated to leader by admin
              // TerritoryAvailableLoaded = all territories (fallback)
              // TerritorySearchResults = search results
              List<GeoTerritory> territories = [];
              bool hasMore = false;

              if (state is TerritoryAllocationsLoaded) {
                territories = state.territories;
                hasMore = false; // Allocations are not paginated
              } else if (state is TerritorySearchResults) {
                territories = state.territories;
                hasMore = state.hasMore;
              } else if (state is TerritoryAvailableLoaded) {
                territories = state.territories;
                hasMore = state.hasMore;
              }

              if (territories.isEmpty) {
                return _buildEmptyView();
              }

              // Show Map or List based on toggle
              if (_isMapView) {
                return _buildMapView(territories);
              }

              if (state is TerritorySearchResults) {
                return _buildSearchResultsList(state);
              }

              // Handle both allocation and available loaded states
              if (state is TerritoryAllocationsLoaded || state is TerritoryAvailableLoaded) {
                return _buildAllocatedTerritoryList(territories, hasMore);
              }

              return _buildEmptyView();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Retry',
              onPressed: () {
                if (_currentSearchQuery.isNotEmpty) {
                  context.read<TerritoryBloc>().add(TerritorySearch(
                    query: _currentSearchQuery,
                  ));
                } else {
                  context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final isSearching = _currentSearchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.map_outlined,
              size: 80,
              color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'No Results Found' : 'No Territories Allocated',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term or clear the search.'
                  : 'No territories have been allocated to you by admin yet.\nContact your administrator to get territories assigned.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: 'Clear Search',
                onPressed: _clearSearch,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllocatedTerritoryList(List<GeoTerritory> territories, bool hasMore) {
    return RefreshIndicator(
      onRefresh: () async {
        // Reload allocated territories for the team leader
        context.read<TerritoryBloc>().add(const TerritoryLoadMyAllocations());
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: territories.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at the bottom
          if (index == territories.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final territory = territories[index];
          return _TerritoryCard(
            territory: territory,
            isDark: widget.isDark,
            index: index + 1,
            onAssign: () => _showAssignmentSheet(context, territory, preSelectedWorkerId: widget.preSelectedWorkerId, preSelectedWorkerName: widget.preSelectedWorkerName),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsList(TerritorySearchResults state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<TerritoryBloc>().add(TerritorySearch(
          query: _currentSearchQuery,
          offset: 0,
        ));
      },
      child: Column(
        children: [
          // Search results header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  '${state.total} results for "${state.query}"',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.territories.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading indicator at the bottom
                if (index == state.territories.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final territory = state.territories[index];
                return _TerritoryCard(
                  territory: territory,
                  isDark: widget.isDark,
                  index: index + 1,
                  onAssign: () => _showAssignmentSheet(context, territory, preSelectedWorkerId: widget.preSelectedWorkerId, preSelectedWorkerName: widget.preSelectedWorkerName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(List<GeoTerritory> territories) {
    return Stack(
      children: [
        TerritoryMapWidget(
          territories: territories,
          selectedTerritory: _selectedTerritory,
          onTerritoryTap: (territory) {
            setState(() => _selectedTerritory = territory);
            _showTerritoryDetailSheet(context, territory);
          },
          showLabels: true,
        ),
        // Floating territory count badge
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${territories.length} territories',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Selected territory card
        if (_selectedTerritory != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildSelectedTerritoryCard(_selectedTerritory!),
          ),
      ],
    );
  }

  Widget _buildSelectedTerritoryCard(GeoTerritory territory) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        territory.entityName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ID: ${territory.solid}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (territory.displayLocation.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                territory.displayLocation,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedTerritory = null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'View Details',
                    type: ButtonType.outline,
                    onPressed: () => _showTerritoryDetailSheet(context, territory),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Assign',
                    onPressed: () => _showAssignmentSheet(context, territory, preSelectedWorkerId: widget.preSelectedWorkerId, preSelectedWorkerName: widget.preSelectedWorkerName),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTerritoryDetailSheet(BuildContext context, GeoTerritory territory) {
    // Capture parent context before modal - modal context won't have access to BLoCs
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _TerritoryDetailSheet(
          territory: territory,
          scrollController: scrollController,
          onAssign: () {
            Navigator.pop(modalContext);
            // Use parentContext which has access to TeamBloc
            _showAssignmentSheet(parentContext, territory, preSelectedWorkerId: widget.preSelectedWorkerId, preSelectedWorkerName: widget.preSelectedWorkerName);
          },
        ),
      ),
    );
  }

  void _showAssignmentSheet(BuildContext context, GeoTerritory territory, {String? preSelectedWorkerId, String? preSelectedWorkerName}) {
    // Capture blocs from parent context before creating modal
    final teamBloc = context.read<TeamBloc>();
    final territoryBloc = context.read<TerritoryBloc>();
    final authBloc = context.read<AuthBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: teamBloc),
          BlocProvider.value(value: territoryBloc),
          BlocProvider.value(value: authBloc),
        ],
        child: _AssignmentBottomSheet(
          territory: territory,
          preSelectedWorkerId: preSelectedWorkerId,
          preSelectedWorkerName: preSelectedWorkerName,
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isLeft;

  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(10) : Radius.zero,
            right: !isLeft ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _TerritoryDetailSheet extends StatelessWidget {
  final GeoTerritory territory;
  final ScrollController scrollController;
  final VoidCallback onAssign;

  const _TerritoryDetailSheet({
    required this.territory,
    required this.scrollController,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            territory.entityName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: ${territory.solid}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (territory.conference != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    territory.conference!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Map with boundary
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 250,
                    child: TerritoryDetailMapWidget(
                      territory: territory,
                      height: 250,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Location info
                _DetailSection(
                  title: 'Location',
                  icon: Icons.location_on_outlined,
                  isDark: isDark,
                  children: [
                    if (territory.address != null)
                      _DetailRow(label: 'Address', value: territory.address!, isDark: isDark),
                    if (territory.city != null)
                      _DetailRow(label: 'City', value: territory.city!, isDark: isDark),
                    if (territory.county != null)
                      _DetailRow(label: 'County', value: territory.county!, isDark: isDark),
                    if (territory.state != null)
                      _DetailRow(label: 'State', value: territory.state!, isDark: isDark),
                    if (territory.zipcode != null)
                      _DetailRow(label: 'ZIP Code', value: territory.zipcode!, isDark: isDark),
                  ],
                ),

                const SizedBox(height: 16),

                // Statistics
                _DetailSection(
                  title: 'Statistics',
                  icon: Icons.bar_chart,
                  isDark: isDark,
                  children: [
                    _DetailRow(
                      label: 'Population',
                      value: _formatNumber(territory.population ?? 0),
                      isDark: isDark,
                    ),
                    _DetailRow(
                      label: 'Housing Units',
                      value: _formatNumber(territory.housingUnits ?? 0),
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Organization info
                _DetailSection(
                  title: 'Organization',
                  icon: Icons.church_outlined,
                  isDark: isDark,
                  children: [
                    if (territory.unionName != null)
                      _DetailRow(label: 'Union', value: territory.unionName!, isDark: isDark),
                    if (territory.conference != null)
                      _DetailRow(label: 'Conference', value: territory.conference!, isDark: isDark),
                    _DetailRow(label: 'Entity ID', value: territory.entityId, isDark: isDark),
                    if (territory.geoid != null)
                      _DetailRow(label: 'GEO ID', value: territory.geoid!, isDark: isDark),
                  ],
                ),

                const SizedBox(height: 24),

                // Assign button
                CustomButton(
                  text: 'Assign This Territory',
                  icon: Icons.assignment_add,
                  onPressed: onAssign,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)},${(number % 1000).toString().padLeft(3, '0')}';
    }
    return number.toString();
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerritoryCard extends StatelessWidget {
  final GeoTerritory territory;
  final bool isDark;
  final int index;
  final VoidCallback onAssign;

  const _TerritoryCard({
    required this.territory,
    required this.isDark,
    required this.index,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onAssign,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Index Number Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Entity Name (Church Name)
                        Text(
                          territory.entityName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // SOLID (Unique ID)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ID: ${territory.solid}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (territory.conference != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    territory.conference!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.assignment_add, color: AppColors.primary),
                    onPressed: onAssign,
                    tooltip: 'Assign Territory',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Location Row
              if (territory.displayLocation.isNotEmpty || territory.address != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          territory.address ?? territory.displayLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Stats Row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.home_work_outlined,
                    value: '${territory.housingUnits ?? 0}',
                    label: 'Housing',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.people_outline,
                    value: _formatNumber(territory.population ?? 0),
                    label: 'Population',
                    isDark: isDark,
                  ),
                  if (territory.unionName != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.church_outlined,
                        value: territory.unionName!,
                        label: 'Union',
                        isDark: isDark,
                        expanded: true,
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;
  final bool expanded;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        expanded
            ? Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
      ],
    );
  }
}

class _TeamMembersTab extends StatelessWidget {
  final bool isDark;

  const _TeamMembersTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        if (state is TeamLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is TeamError) {
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
                    state.message,
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

        if (state is TeamMembersLoaded) {
          final members = state.members;

          if (members.isEmpty) {
            return _buildEmptyState(context);
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
                return _TeamMemberCard(member: member, isDark: isDark);
              },
            ),
          );
        }

        // Initial state - check if user has a team
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated && authState.user.teamId == null) {
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

        return _buildEmptyState(context);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
              onPressed: () {
                // TODO: Invite member
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final TeamMember member;
  final bool isDark;

  const _TeamMemberCard({
    required this.member,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withAlpha(30),
          backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
          child: member.avatarUrl == null
              ? Text(
                  (member.displayName ?? member.email ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Text(
          member.displayName ?? member.email ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null)
              Text(
                member.email!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        trailing: member.role == 'worker'
            ? IconButton(
                icon: const Icon(Icons.assignment, color: AppColors.primary),
                tooltip: 'View Assignments',
                onPressed: () {
                  // TODO: View member's territory assignments
                },
              )
            : null,
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

class _AssignmentBottomSheet extends StatefulWidget {
  final GeoTerritory territory;
  final String? preSelectedWorkerId;
  final String? preSelectedWorkerName;

  const _AssignmentBottomSheet({
    required this.territory,
    this.preSelectedWorkerId,
    this.preSelectedWorkerName,
  });

  @override
  State<_AssignmentBottomSheet> createState() => _AssignmentBottomSheetState();
}

class _AssignmentBottomSheetState extends State<_AssignmentBottomSheet> {
  TeamMember? _selectedWorker;
  String _priority = 'medium';
  bool _isAssigning = false;
  bool _hasAutoSelectedWorker = false;

  void _autoSelectWorkerIfNeeded(List<TeamMember> workers) {
    if (_hasAutoSelectedWorker || widget.preSelectedWorkerId == null) return;

    // Find the pre-selected worker in the list
    final preSelectedWorker = workers.where(
      (w) => w.userId == widget.preSelectedWorkerId
    ).firstOrNull;

    if (preSelectedWorker != null) {
      setState(() {
        _selectedWorker = preSelectedWorker;
        _hasAutoSelectedWorker = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<TerritoryBloc, TerritoryState>(
      listener: (context, state) {
        if (state is TerritoryAssignSuccess) {
          Navigator.pop(context);
          AppSnackbar.success(context, message: state.message);
        } else if (state is TerritoryError && _isAssigning) {
          setState(() => _isAssigning = false);
          AppSnackbar.error(context, message: state.message);
        }
      },
      builder: (context, territoryState) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              Text(
                'Assign Territory',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Territory Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.territory.entityName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${widget.territory.solid}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (widget.territory.displayLocation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.territory.displayLocation,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Text(
                'Select Worker',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Worker Selection using TeamBloc
              BlocBuilder<TeamBloc, TeamState>(
                builder: (context, teamState) {
                  if (teamState is TeamLoading) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (teamState is TeamMembersLoaded) {
                    final workers = teamState.workers;

                    // Auto-select worker if pre-selected from Team Members screen
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _autoSelectWorkerIfNeeded(workers);
                    });

                    if (workers.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No workers available in your team',
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Column(
                        children: workers.map((worker) {
                          final isSelected = _selectedWorker?.userId == worker.userId;
                          return InkWell(
                            onTap: () => setState(() => _selectedWorker = worker),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withAlpha(20) : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withAlpha(30),
                                    backgroundImage: worker.avatarUrl != null
                                        ? NetworkImage(worker.avatarUrl!)
                                        : null,
                                    child: worker.avatarUrl == null
                                        ? Text(
                                            (worker.displayName ?? worker.email ?? 'U')[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          worker.displayName ?? worker.email ?? 'Unknown',
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                        if (worker.email != null)
                                          Text(
                                            worker.email!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  // Initial or error state
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Unable to load team members',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              Text(
                'Priority Level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ('low', 'Low'),
                  ('medium', 'Medium'),
                  ('high', 'High'),
                ].asMap().entries.map((entry) {
                  final index = entry.key;
                  final (value, label) = entry.value;
                  final isSelected = _priority == value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = value),
                      child: Container(
                        margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary
                              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.secondary
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Cancel',
                      type: ButtonType.outline,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: _isAssigning ? 'Assigning...' : 'Assign',
                      onPressed: _selectedWorker != null && !_isAssigning
                          ? () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState is! AuthAuthenticated) {
                                AppSnackbar.error(context, message: 'Not authenticated');
                                return;
                              }
                              final user = authState.user;
                              if (user.teamId == null) {
                                AppSnackbar.error(context, message: 'No team assigned');
                                return;
                              }

                              setState(() => _isAssigning = true);
                              context.read<TerritoryBloc>().add(
                                TerritoryAssignToWorker(
                                  territoryId: widget.territory.id,
                                  territorySolid: widget.territory.solid,
                                  workerId: _selectedWorker!.userId,
                                  teamId: user.teamId!,
                                  assignedBy: user.id,
                                  priority: _priority,
                                ),
                              );
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
      },
    );
  }
}
