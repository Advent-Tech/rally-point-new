import 'dart:async';
import 'dart:math' as math;

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
  bool _coachMarksActive = false;
  bool _showRecenterButton = false;
  Timer? _followMonitorTimer;
  final Set<String> _coachMarksShownThisSession = <String>{};

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
    _startFollowMonitor();
  }

  @override
  void dispose() {
    _followMonitorTimer?.cancel();
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

  void _startFollowMonitor() {
    _followMonitorTimer?.cancel();
    _followMonitorTimer = Timer.periodic(const Duration(milliseconds: 1200), (
      _,
    ) async {
      if (!mounted || _mapController == null) return;
      final state = context.read<CommandCenterBloc>().state;
      final followId = state.followTarget;
      if (followId == null || followId.isEmpty) {
        if (_showRecenterButton) {
          setState(() => _showRecenterButton = false);
        }
        return;
      }
      final pos = state.liveLocations[followId];
      if (pos == null) {
        if (_showRecenterButton) {
          setState(() => _showRecenterButton = false);
        }
        return;
      }
      try {
        final camera = await _mapController!.getCameraState();
        final center = camera.center.coordinates;
        final distanceMeters = _distanceMeters(
          center.lat.toDouble(),
          center.lng.toDouble(),
          pos.latitude,
          pos.longitude,
        );
        final shouldShow = distanceMeters > 120;
        if (shouldShow != _showRecenterButton && mounted) {
          setState(() => _showRecenterButton = shouldShow);
        }
      } catch (_) {}
    });
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius * c;
  }

  void _maybeShowModeCoachMarks(cc.MapMode mode) {
    if (_coachMarksBusy) return;
    final modeStepId = switch (mode) {
      cc.MapMode.overview => 'command_center_overview',
      cc.MapMode.workers => 'command_center_workers',
      cc.MapMode.territories => 'command_center_territories',
    };
    final commonStepId = 'command_center_common';
    if (_coachMarksShownThisSession.contains(modeStepId) &&
        _coachMarksShownThisSession.contains(commonStepId)) {
      return;
    }
    _coachMarksBusy = true;
    Future.wait<bool>([
      CoachMarksService().hasBeenShown(commonStepId),
      CoachMarksService().hasBeenShown(modeStepId),
    ]).then((shownFlags) {
      if (!mounted) {
        _coachMarksBusy = false;
        return;
      }
      final commonShown = shownFlags[0];
      final modeShown = shownFlags[1];
      if (commonShown && modeShown) {
        _coachMarksShownThisSession.add(commonStepId);
        _coachMarksShownThisSession.add(modeStepId);
        _coachMarksBusy = false;
        return;
      }
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) {
          _coachMarksBusy = false;
          return;
        }
        final keys = <GlobalKey>[];
        // Common command center guidance should only be shown once globally.
        if (!commonShown) {
          keys.addAll([_showcaseModeTabs, _showcaseMapControls]);
        }
        // Per-tab guidance is distinct and should only show once per tab.
        if (!modeShown) {
          if (mode == cc.MapMode.overview) keys.add(_showcaseOverviewStats);
          if (mode == cc.MapMode.workers) keys.add(_showcaseWorkerSheet);
          if (mode == cc.MapMode.territories) keys.add(_showcaseTerritorySheet);
        }
        if (keys.isEmpty) {
          _coachMarksBusy = false;
          return;
        }
        _coachMarksActive = true;
        ShowcaseView.get().startShowCase(keys);
        // Safety fallback: never allow coach marks to block interaction forever.
        Future.delayed(const Duration(seconds: 8), () {
          if (!mounted) return;
          if (_coachMarksActive) {
            ShowcaseView.get().dismiss();
            _coachMarksActive = false;
            _coachMarksBusy = false;
          }
        });
        Future.wait<void>([
          if (!commonShown) CoachMarksService().markAsShown(commonStepId),
          if (!modeShown) CoachMarksService().markAsShown(modeStepId),
        ]).whenComplete(() {
          _coachMarksActive = false;
          _coachMarksShownThisSession.add(commonStepId);
          _coachMarksShownThisSession.add(modeStepId);
          _coachMarksBusy = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tooltipBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final tooltipTitleStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF111827),
      fontWeight: FontWeight.w700,
      fontSize: 15,
    );
    final tooltipDescStyle = TextStyle(
      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
      fontSize: 13,
      height: 1.3,
    );
    final topInset = MediaQuery.of(context).padding.top;
    final backButtonTop = topInset + 8;
    final modeTabsTop = topInset + 52;
    final followBannerTop = topInset + 128;
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
                        'Switch between Overview, Light Squads and Territories to manage operations.',
                    tooltipBackgroundColor: tooltipBg,
                    titleTextStyle: tooltipTitleStyle,
                    descTextStyle: tooltipDescStyle,
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
                    tooltipBackgroundColor: tooltipBg,
                    titleTextStyle: tooltipTitleStyle,
                    descTextStyle: tooltipDescStyle,
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
                              'This bar summarizes active light squads, donations and prayer records.',
                          tooltipBackgroundColor: tooltipBg,
                          titleTextStyle: tooltipTitleStyle,
                          descTextStyle: tooltipDescStyle,
                          child: const OverviewStatsBar(),
                        ),
                      ),

                    // Follow mode banner
                    if (state.followTarget != null)
                      Positioned(
                        top: followBannerTop,
                        left: 16,
                        right: 16,
                        child: const Align(
                          alignment: Alignment.topCenter,
                          child: FollowModeBanner(),
                        ),
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

                    if (state.followTarget != null && _showRecenterButton)
                      Positioned(
                        right: 16,
                        bottom: 248,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter_follow',
                          onPressed: () {
                            context.read<CommandCenterBloc>().add(
                              const RecenterFollowEvent(),
                            );
                            setState(() => _showRecenterButton = false);
                          },
                          child: const Icon(Icons.my_location),
                        ),
                      ),

                    // Worker bottom sheet
                    if (state.mapMode == cc.MapMode.workers)
                      Showcase(
                        key: _showcaseWorkerSheet,
                        title: 'Light Squads Panel',
                        description:
                            'Tap a light squad to view details, and follow to track live movement.',
                        tooltipBackgroundColor: tooltipBg,
                        titleTextStyle: tooltipTitleStyle,
                        descTextStyle: tooltipDescStyle,
                        child: const WorkerBottomSheet(),
                      ),

                    // Territory bottom sheet
                    if (state.mapMode == cc.MapMode.territories)
                      Showcase(
                        key: _showcaseTerritorySheet,
                        title: 'Territories Panel',
                        description:
                            'Review assigned territories and progress. If empty, ask admin to assign.',
                        tooltipBackgroundColor: tooltipBg,
                        titleTextStyle: tooltipTitleStyle,
                        descTextStyle: tooltipDescStyle,
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
