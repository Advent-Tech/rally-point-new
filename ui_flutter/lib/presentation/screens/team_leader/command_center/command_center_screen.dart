import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:showcaseview/showcaseview.dart';
import 'command_center_bloc.dart';
import 'command_center_event.dart';
import 'command_center_state.dart' as cc;
import 'command_center_controller.dart';
import 'services/realtime_bridge.dart';
import 'widgets/mode_selector.dart';
import 'widgets/map_controls.dart';
import 'widgets/empty_state_overlay.dart';
import 'widgets/follow_mode_banner.dart';
import 'widgets/breach_alert_banner.dart';
import 'widgets/worker_bottom_sheet.dart';
import 'widgets/territory_bottom_sheet.dart';
import 'widgets/overview_stats_bar.dart';
import 'widgets/map_popup_overlay.dart';
import '../../../../core/constants/map_constants.dart';
import '../../../../services/coach_marks_service.dart';
import '../../../../services/websocket_service.dart';

class CommandCenterScreen extends StatefulWidget {
  final cc.MapMode? initialMode;

  const CommandCenterScreen({super.key, this.initialMode});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  mapbox.MapboxMap? _mapController;
  CommandCenterController? _commandController;
  late RealtimeBridge _realtimeBridge;
  final _showcaseModeTabs = GlobalKey();
  final _showcaseMapControls = GlobalKey();
  final _showcaseOverviewStats = GlobalKey();
  final _showcaseWorkerSheet = GlobalKey();
  final _showcaseTerritorySheet = GlobalKey();
  bool _coachMarksBusy = false;
  final Set<cc.MapMode> _coachMarksCompletedModes = <cc.MapMode>{};

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CommandCenterBloc>();
    bloc.add(
      InitializeEvent(initialMode: widget.initialMode ?? cc.MapMode.overview),
    );

    // Initialize realtime bridge
    _realtimeBridge = RealtimeBridge(bloc: bloc);
    context.read<WebSocketService>().connect();
  }

  @override
  void dispose() {
    _commandController?.dispose();
    _realtimeBridge.dispose();
    super.dispose();
  }

  void _onMapCreated(mapbox.MapboxMap controller) {
    _mapController = controller;
    _commandController = CommandCenterController(
      mapController: controller,
      bloc: context.read<CommandCenterBloc>(),
    );
  }

  void _maybeShowModeCoachMarks(cc.MapMode mode) {
    if (_coachMarksBusy || _coachMarksCompletedModes.contains(mode)) return;
    final stepId = switch (mode) {
      cc.MapMode.overview => 'command_center_overview',
      cc.MapMode.workers => 'command_center_workers',
      cc.MapMode.territories => 'command_center_territories',
    };
    _coachMarksBusy = true;
    CoachMarksService().hasBeenShown(stepId).then((shown) {
      if (!mounted) {
        _coachMarksBusy = false;
        return;
      }
      if (shown) {
        _coachMarksCompletedModes.add(mode);
        _coachMarksBusy = false;
        return;
      }
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) {
          _coachMarksBusy = false;
          return;
        }
        final keys = <GlobalKey>[
          _showcaseModeTabs,
          _showcaseMapControls,
          if (mode == cc.MapMode.overview) _showcaseOverviewStats,
          if (mode == cc.MapMode.workers) _showcaseWorkerSheet,
          if (mode == cc.MapMode.territories) _showcaseTerritorySheet,
        ];
        ShowcaseView.get().startShowCase(keys);
        CoachMarksService().markAsShown(stepId);
        _coachMarksCompletedModes.add(mode);
        _coachMarksBusy = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final backButtonTop = topInset + 8;
    final modeTabsTop = topInset + 52;
    final followBannerTop = topInset + 150;
    return ShowCaseWidget(
      enableAutoScroll: true,
      builder: (_) => Scaffold(
        body: BlocConsumer<CommandCenterBloc, cc.CommandCenterState>(
          listenWhen: (previous, current) =>
              previous.mapMode != current.mapMode && !current.isLoading,
          listener: (context, state) {
            _maybeShowModeCoachMarks(state.mapMode);
          },
          builder: (context, state) {
            return Stack(
              children: [
                // Map Layer
                mapbox.MapWidget(
                  key: const ValueKey('command-center-map'),
                  onMapCreated: _onMapCreated,
                  onTapListener: (context) =>
                      _commandController?.handleMapTap(context),
                  cameraOptions: mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(-98.5795, 39.8283),
                    ),
                    zoom: 4.0,
                  ),
                  styleUri: MapConstants.getThemedStyleUri(isDark),
                ),

                MapPopupOverlay(mapController: _mapController),

                // Mode Selector (top)
                Positioned(
                  top: modeTabsTop,
                  left: 0,
                  right: 0,
                  child: Showcase(
                    key: _showcaseModeTabs,
                    title: 'Map Tabs',
                    description:
                        'Switch between Overview, Workers and Territories to manage operations.',
                    child: const ModeSelector(),
                  ),
                ),

                Positioned(
                  top: backButtonTop,
                  left: 10,
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.92),
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/leader/dashboard');
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back, size: 22),
                      ),
                    ),
                  ),
                ),

                // Map Controls (right side)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Showcase(
                    key: _showcaseMapControls,
                    title: 'Map Controls',
                    description:
                        'Use zoom, layer and style controls to inspect field activity clearly.',
                    child: MapControls(mapController: _mapController),
                  ),
                ),

                // Context-aware overlays and sheets
                Stack(
                  children: [
                    // Overview stats bar
                    if (state.mapMode == cc.MapMode.overview)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Showcase(
                          key: _showcaseOverviewStats,
                          title: 'Overview Summary',
                          description:
                              'This bar summarizes active workers, donations and prayer records.',
                          child: const OverviewStatsBar(),
                        ),
                      ),

                    // Follow mode banner
                    if (state.followTarget != null)
                      Positioned(
                        top: followBannerTop,
                        left: 0,
                        right: 0,
                        child: const FollowModeBanner(),
                      ),

                    if (state.breachedWorkerIds.isNotEmpty)
                      Positioned(
                        top: state.followTarget != null
                            ? followBannerTop + 50
                            : followBannerTop,
                        left: 0,
                        right: 0,
                        child: const BreachAlertBanner(),
                      ),

                    // Worker bottom sheet
                    if (state.mapMode == cc.MapMode.workers)
                      Showcase(
                        key: _showcaseWorkerSheet,
                        title: 'Workers Panel',
                        description:
                            'Tap a worker to view details, and follow to track live movement.',
                        child: const WorkerBottomSheet(),
                      ),

                    // Territory bottom sheet
                    if (state.mapMode == cc.MapMode.territories)
                      Showcase(
                        key: _showcaseTerritorySheet,
                        title: 'Territories Panel',
                        description:
                            'Review assigned territories and progress. If empty, ask admin to assign.',
                        child: const TerritoryBottomSheet(),
                      ),

                    // Empty state overlay
                    if (_shouldShowEmptyState(state))
                      EmptyStateOverlay(
                        mode: state.mapMode,
                        onAction: () => _handleEmptyStateAction(state),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _shouldShowEmptyState(cc.CommandCenterState state) {
    if (state.isLoading) return false;

    switch (state.mapMode) {
      case cc.MapMode.overview:
        return state.territories.isEmpty;
      case cc.MapMode.workers:
        return state.workers.isEmpty;
      case cc.MapMode.territories:
        return state.territories.isEmpty;
    }
  }

  void _handleEmptyStateAction(cc.CommandCenterState state) {
    // Handle empty state CTA actions
    switch (state.mapMode) {
      case cc.MapMode.overview:
      case cc.MapMode.territories:
        context.read<CommandCenterBloc>().add(RefreshDataEvent());
        break;
      case cc.MapMode.workers:
        context.read<CommandCenterBloc>().add(RefreshDataEvent());
        break;
    }
  }
}
