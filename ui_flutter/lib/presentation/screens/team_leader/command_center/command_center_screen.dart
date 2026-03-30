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
  final _showcaseMode = GlobalKey();
  final _showcaseControls = GlobalKey();
  bool _coachMarksChecked = false;

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

  void _maybeShowCoachMarks() {
    if (_coachMarksChecked) return;
    _coachMarksChecked = true;
    CoachMarksService().hasBeenShown('leader_command_center').then((shown) {
      if (!shown && mounted) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          ShowcaseView.get().startShowCase([_showcaseMode, _showcaseControls]);
          CoachMarksService().markAsShown('leader_command_center');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShowCaseWidget(
      builder: (_) {
        _maybeShowCoachMarks();
        return Scaffold(
          body: Stack(
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

              // Context-aware overlays and sheets
              BlocBuilder<CommandCenterBloc, cc.CommandCenterState>(
                builder: (context, state) {
                  final safeTop = MediaQuery.of(context).padding.top;
                  final followTop = safeTop + 64;
                  final breachTop = followTop + 52;
                  return Stack(
                    children: [
                      // Overview stats bar
                      if (state.mapMode == cc.MapMode.overview)
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: OverviewStatsBar(),
                        ),

                      // Follow mode banner
                      if (state.followTarget != null)
                        Positioned(
                          top: followTop,
                          left: 0,
                          right: 0,
                          child: const FollowModeBanner(),
                        ),

                      if (state.breachedWorkerIds.isNotEmpty)
                        Positioned(
                          top: state.followTarget != null
                              ? breachTop
                              : followTop,
                          left: 0,
                          right: 0,
                          child: const BreachAlertBanner(),
                        ),

                      // Worker bottom sheet
                      if (state.mapMode == cc.MapMode.workers)
                        const WorkerBottomSheet(),

                      // Territory bottom sheet
                      if (state.mapMode == cc.MapMode.territories)
                        const TerritoryBottomSheet(),

                      // Empty state overlay
                      if (_shouldShowEmptyState(state))
                        EmptyStateOverlay(
                          mode: state.mapMode,
                          onAction: () => _handleEmptyStateAction(state),
                        ),
                    ],
                  );
                },
              ),

              // Keep top controls as the highest z-order so sheets/overlays can't block them.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Showcase(
                    key: _showcaseMode,
                    title: 'Command Views',
                    description:
                        'Switch between overview, workers, and territories based on what you want to monitor.',
                    child: const ModeSelector(),
                  ),
                ),
              ),

              // Keep map controls above bottom sheets.
              BlocBuilder<CommandCenterBloc, cc.CommandCenterState>(
                builder: (context, state) {
                  final bottomOffset = switch (state.mapMode) {
                    cc.MapMode.overview => 104.0,
                    cc.MapMode.workers => 250.0,
                    cc.MapMode.territories => 250.0,
                  };
                  return Positioned(
                    right: 16,
                    bottom: bottomOffset,
                    child: Showcase(
                      key: _showcaseControls,
                      title: 'Map Controls',
                      description:
                          'Zoom and switch map style to inspect worker and territory details clearly.',
                      child: MapControls(mapController: _mapController),
                    ),
                  );
                },
              ),
              Positioned(
                left: 12,
                top: MediaQuery.of(context).padding.top + 6,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/leader/dashboard');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.black87,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
