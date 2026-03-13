import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/theme/theme.dart';
import '../../../data/models/territory_model.dart';
import '../../../services/coach_marks_service.dart';
import '../../blocs/territory/territory_bloc.dart';
import '../../blocs/work_session/work_session_bloc.dart';
import '../../widgets/widgets.dart';

class TerritoryScreen extends StatefulWidget {
  const TerritoryScreen({super.key});

  @override
  State<TerritoryScreen> createState() => _TerritoryScreenState();
}

class _TerritoryScreenState extends State<TerritoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isFabExpanded = false;
  Timer? _searchDebounce;

  // Coach mark keys
  final _showcaseSearch = GlobalKey();
  final _showcaseFab = GlobalKey();
  bool _coachMarksChecked = false;

  static const _tooltipTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF1E293B),
    letterSpacing: -0.2,
  );
  static const _tooltipDescStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFF64748B),
    height: 1.4,
  );
  static final _tooltipRadius = BorderRadius.circular(14);
  static const _tooltipPadding = EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 16,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
    });
  }

  void _maybeShowCoachMarks() {
    if (_coachMarksChecked) return;
    _coachMarksChecked = true;
    CoachMarksService().hasBeenShown('territory').then((shown) {
      if (!shown && mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            ShowcaseView.get().startShowCase([_showcaseSearch, _showcaseFab]);
            CoachMarksService().markAsShown('territory');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ignore: deprecated_member_use
    return ShowCaseWidget(
      onFinish: () {},
      enableAutoScroll: true,
      builder: (_) {
        _maybeShowCoachMarks();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Territory'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Areas'),
                Tab(text: 'Map'),
              ],
            ),
            actions: const [RoleBadge()],
          ),
          body: Column(
            children: [
              // Search Bar
              Showcase(
                key: _showcaseSearch,
                title: 'Search Territories',
                description:
                    'Find territories by name or location. Results will appear on the map.',
                titleTextStyle: _tooltipTitleStyle,
                descTextStyle: _tooltipDescStyle,
                tooltipBorderRadius: _tooltipRadius,
                tooltipPadding: _tooltipPadding,
                targetBorderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomSearchField(
                    controller: _searchController,
                    hint: 'Search territories...',
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
              // Tab Content - disable swipe to allow map panning
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MyAreasTab(isDark: isDark, tabController: _tabController),
                    _MapTab(isDark: isDark, tabController: _tabController),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _buildCommunicationFab(context, isDark),
        );
      },
    );
  }

  Widget _buildCommunicationFab(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
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
          Showcase(
            key: _showcaseFab,
            title: 'Team Communication',
            description:
                'Tap to access Chat or Walkie-Talkie to communicate with your team in the field.',
            titleTextStyle: _tooltipTitleStyle,
            descTextStyle: _tooltipDescStyle,
            tooltipBorderRadius: _tooltipRadius,
            tooltipPadding: _tooltipPadding,
            targetBorderRadius: BorderRadius.circular(28),
            child: FloatingActionButton(
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
          ),
        ],
      ),
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
      if (currentState is! TerritoryAssignmentsLoaded &&
          currentState is! TerritoryLoading) {
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
              description:
                  'You don\'t have any territories assigned yet.\nBrowse available territories to request one.',
              actionLabel: 'Browse Available',
              onAction: () {},
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TerritoryBloc>().add(
                const TerritoryLoadAssignments(),
              );
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: state.assignments.length,
              itemBuilder: (context, index) {
                final assignment = state.assignments[index];
                return StaggeredFadeIn(
                  index: index,
                  child: _AssignmentCard(
                    name: assignment.entityName ?? 'Territory ${index + 1}',
                    location:
                        '${assignment.city ?? ''}, ${assignment.state ?? ''}'
                            .trim(),
                    households: assignment.housingUnits ?? 0,
                    status: assignment.status,
                    progress: assignment.completenessPercentage,
                    isDark: widget.isDark,
                    onTap: () {
                      final geoTerritory = GeoTerritory(
                        id: assignment.territoryId,
                        solid: assignment.territorySolid,
                        entityName:
                            assignment.entityName ?? 'Territory ${index + 1}',
                        entityId: assignment.entityId ?? '',
                        city: assignment.city,
                        state: assignment.state,
                        unionName: assignment.unionName,
                        conference: assignment.conference,
                        population: assignment.population,
                        housingUnits: assignment.housingUnits,
                        geometry: assignment.geometry,
                      );
                      _showTerritoryDetailSheet(context, geoTerritory);
                    },
                  ),
                );
              },
            ),
          );
        }

        if (state is TerritoryError) {
          return ErrorState(
            message: state.message,
            onRetry: () {
              context.read<TerritoryBloc>().add(
                const TerritoryLoadAssignments(),
              );
            },
          );
        }

        return EmptyState(
          icon: Icons.map_outlined,
          title: 'No Assigned Territories',
          description:
              'You don\'t have any territories assigned yet.\nBrowse available territories to request one.',
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
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
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
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

class _MapTab extends StatefulWidget {
  final bool isDark;
  final TabController tabController;

  const _MapTab({required this.isDark, required this.tabController});

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  GeoTerritory? _selectedTerritory;
  // final List<VisitMarker> _visitMarkers = [];
  double? _userLatitude;
  double? _userLongitude;
  bool _showTapHint = false;

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
    _getUserLocation();
    _checkTapHint();
    // Load data immediately on init to prevent blank map on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMapData();
      }
    });
  }

  void _checkTapHint() {
    CoachMarksService().hasBeenShown('territory_map_hint').then((shown) {
      if (!shown && mounted) {
        setState(() => _showTapHint = true);
        CoachMarksService().markAsShown('territory_map_hint');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showTapHint = false);
        });
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

  void _loadMapData() {
    final state = context.read<TerritoryBloc>().state;
    // Only load worker's assigned territories
    if (state is! TerritoryAssignmentsLoaded && state is! TerritoryLoading) {
      context.read<TerritoryBloc>().add(const TerritoryLoadAssignments());
    }
  }

  void _onTabChange() {
    if (!mounted) return; // Prevent using context after dispose
    // Load territories when Map tab is selected
    if (widget.tabController.index == 1) {
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
            return _buildMapView(
              territoriesWithGeometry,
              isSearchResult: true,
              searchQuery: state.query,
            );
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
        if (state is TerritoryAssignmentsLoaded &&
            state.assignments.isNotEmpty) {
          // Convert assignments to GeoTerritory for the map
          final territories = state.assignments
              .where((a) => a.geometry != null)
              .map(
                (a) => GeoTerritory(
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
                ),
              )
              .toList();

          if (territories.isNotEmpty) {
            return _buildMapView(territories);
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

  Widget _buildMapView(
    List<GeoTerritory> territories, {
    bool isSearchResult = false,
    String? searchQuery,
  }) {
    return Stack(
      children: [
        // Map widget removed - use Command Center instead
        Container(
          color: Colors.grey[100],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Map view has moved to Command Center',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        // Territory count badge
        Positioned(
          left: AppSpacing.md,
          top: AppSpacing.md,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.sm,
            ),
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
                      : '${territories.length} assigned territories',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSearchResult
                        ? Colors.white
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (isSearchResult) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      context.read<TerritoryBloc>().add(
                        const TerritoryLoadAssignments(),
                      );
                    },
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Visit outcome legend (always visible)
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendDot(AppColors.warning, 'Not Home'),
                const SizedBox(width: 10),
                _legendDot(AppColors.success, 'Interested'),
                const SizedBox(width: 10),
                _legendDot(AppColors.error, 'Declined'),
                const SizedBox(width: 10),
                _legendDot(AppColors.info, 'Callback'),
              ],
            ),
          ),
        ),
        // My Location button
        if (_userLatitude != null && _userLongitude != null)
          Positioned(
            right: 16,
            bottom: 56,
            child: GestureDetector(
              onTap: () {
                // The map widget handles centering via userLatitude/userLongitude
                // Force a rebuild to recenter
                setState(() {});
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
        // Auto-dismiss tap hint (first visit only)
        if (_showTapHint)
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showTapHint ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Tap a territory to see details',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showAddVisitDialog(
    BuildContext context,
    double latitude,
    double longitude,
  ) {
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
            bottom: MediaQuery.of(context).viewInsets.bottom + 80,
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
                    child: const Icon(
                      Icons.add_location_alt,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.smd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Visit',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondaryLight),
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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
                    onSelected: () =>
                        setSheetState(() => selectedOutcome = 'not_home'),
                  ),
                  _OutcomeChip(
                    label: 'Interested',
                    value: 'interested',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    selected: selectedOutcome == 'interested',
                    onSelected: () =>
                        setSheetState(() => selectedOutcome = 'interested'),
                  ),
                  _OutcomeChip(
                    label: 'Not Interested',
                    value: 'not_interested',
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                    selected: selectedOutcome == 'not_interested',
                    onSelected: () =>
                        setSheetState(() => selectedOutcome = 'not_interested'),
                  ),
                  _OutcomeChip(
                    label: 'Callback',
                    value: 'callback',
                    icon: Icons.schedule,
                    color: AppColors.info,
                    selected: selectedOutcome == 'callback',
                    onSelected: () =>
                        setSheetState(() => selectedOutcome = 'callback'),
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
                      // Visit markers functionality removed with map widget
                    });
                    Navigator.pop(context);
                    AppSnackbar.success(
                      context,
                      message: 'Visit logged successfully',
                    );
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
      description:
          'No territories assigned to you yet.\nCheck the My Areas tab for details.',
      iconColor: AppColors.secondary,
      actionLabel: 'Load Territories',
      onAction: _loadMapData,
    );
  }

  /// Opens a bottom sheet showing territory details; main map handles the polygon
  void _showTerritoryDetailMap(BuildContext context, GeoTerritory territory) {
    _showTerritoryDetailSheet(
      context,
      territory,
      onDismiss: () {
        setState(() => _selectedTerritory = null);
      },
    );
  }
}

/// Shared bottom sheet for territory detail - used by both list and map tabs
void _showTerritoryDetailSheet(
  BuildContext context,
  GeoTerritory territory, {
  VoidCallback? onDismiss,
}) {
  final workSessionBloc = WorkSessionBloc();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => BlocProvider.value(
      value: workSessionBloc,
      child: DraggableScrollableSheet(
        initialChildSize: 0.32,
        minChildSize: 0.2,
        maxChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.backgroundDark.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 10,
                bottom: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Header row with name, ID, and close button
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              territory.entityName,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ID: ${territory.solid}',
                              style: Theme.of(sheetContext).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Compact detail chips
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (territory.displayLocation.isNotEmpty)
                        _InfoChip(
                          icon: Icons.location_city,
                          text: territory.displayLocation,
                        ),
                      if (territory.unionName != null)
                        _InfoChip(
                          icon: Icons.account_balance,
                          text: territory.unionName!,
                        ),
                      if (territory.housingUnits != null)
                        _InfoChip(
                          icon: Icons.home,
                          text: '${territory.housingUnits} units',
                        ),
                      if (territory.population != null)
                        _InfoChip(
                          icon: Icons.people,
                          text: '${territory.population} pop',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Assigned badge + Start Working button in a row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Assigned',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BlocConsumer<WorkSessionBloc, WorkSessionState>(
                          listener: (context, state) {
                            if (state is WorkSessionActive) {
                              Navigator.pop(sheetContext);
                              AppSnackbar.success(
                                context,
                                message:
                                    'Started working in ${territory.entityName}',
                              );
                            } else if (state is WorkSessionError) {
                              AppSnackbar.error(
                                context,
                                message: state.message,
                              );
                            }
                          },
                          builder: (context, state) {
                            final isLoading = state is WorkSessionLoading;
                            return CustomButton(
                              text: isLoading ? 'Starting...' : 'Start Working',
                              icon: Icons.play_arrow,
                              isLoading: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      context.read<WorkSessionBloc>().add(
                                        WorkSessionCheckIn(
                                          territoryId: territory.id,
                                          territoryName: territory.entityName,
                                        ),
                                      );
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    workSessionBloc.close();
    onDismiss?.call();
  });
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondaryLight),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.08),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: 6,
          ),
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
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
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
