import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'command_center_bloc.dart';
import 'command_center_state.dart';
import 'layers/territory_layer.dart';
import 'layers/worker_layer.dart';
import 'layers/activity_layer.dart';
import 'layers/trail_layer.dart';
import 'layers/breach_layer.dart';
import 'services/camera_controller.dart';
import 'services/bounds_calculator.dart';

class CommandCenterController {
  final MapboxMap mapController;
  final CommandCenterBloc bloc;

  late TerritoryLayer _territoryLayer;
  late WorkerLayer _workerLayer;
  late ActivityLayer _activityLayer;
  late TrailLayer _trailLayer;
  late BreachLayer _breachLayer;
  late CommandCenterCameraController _cameraController;

  StreamSubscription? _stateSubscription;
  CommandCenterState? _previousState;

  CommandCenterController({required this.mapController, required this.bloc}) {
    _initialize();
  }

  void _initialize() async {
    // Initialize layers
    _territoryLayer = TerritoryLayer(mapController: mapController);
    _workerLayer = WorkerLayer(mapController: mapController);
    _activityLayer = ActivityLayer(mapController: mapController);
    _trailLayer = TrailLayer(mapController: mapController);
    _breachLayer = BreachLayer(mapController: mapController);
    _cameraController = CommandCenterCameraController(
      mapController: mapController,
    );

    await _territoryLayer.initialize();
    await _workerLayer.initialize();
    await _activityLayer.initialize();
    await _trailLayer.initialize();
    await _breachLayer.initialize();

    // Listen to state changes
    _stateSubscription = bloc.stream.listen(_handleStateChange);
  }

  void _handleStateChange(CommandCenterState state) {
    final previous = _previousState;

    // Update territories if changed
    if (state.territories != previous?.territories && state.showTerritories) {
      _territoryLayer.updateTerritories(state.territories);
    }

    // Update workers if changed or visibility toggled
    if ((state.liveLocations != previous?.liveLocations ||
            state.showWorkers != previous?.showWorkers) &&
        state.showWorkers) {
      _workerLayer.updateWorkers(state.workers, state.liveLocations);
    }

    // Update activities if changed
    if ((state.donations != previous?.donations ||
            state.prayerRequests != previous?.prayerRequests ||
            state.showActivities != previous?.showActivities) &&
        state.showActivities) {
      _activityLayer.updateActivities(state.donations, state.prayerRequests);
    }

    // Update trails if changed
    if ((state.workerPaths != previous?.workerPaths ||
            state.showTrails != previous?.showTrails) &&
        state.showTrails) {
      _trailLayer.updateTrails(state.workerPaths);
    }

    // Update breaches
    if (state.breachedWorkerIds != previous?.breachedWorkerIds) {
      _breachLayer.updateBreaches(state.breachedWorkerIds, state.liveLocations);
    }

    // Handle camera changes
    _handleCameraChanges(state, previous);

    // Auto-fit if data just loaded for the first time
    if (state.mapMode == MapMode.overview &&
        previous != null &&
        previous.isLoading &&
        !state.isLoading &&
        (state.territories.isNotEmpty ||
            state.donations.isNotEmpty ||
            state.prayerRequests.isNotEmpty)) {
      final bounds = BoundsCalculator.calculateOverviewBounds(state);
      _cameraController.fitToBounds(bounds, priority: CameraPriority.autoFit);
    }

    _previousState = state;
  }

  void _handleCameraChanges(
    CommandCenterState state,
    CommandCenterState? previous,
  ) {
    // Follow mode
    if (state.followTarget != previous?.followTarget) {
      if (state.followTarget != null &&
          state.liveLocations.containsKey(state.followTarget)) {
        final position = state.liveLocations[state.followTarget]!;
        _cameraController.follow(position.latitude, position.longitude);
      } else {
        _cameraController.stopFollow();
      }
    }

    // Territory selection
    if (state.selectedTerritoryId != previous?.selectedTerritoryId &&
        state.selectedTerritoryId != null) {
      final territory = state.territories.firstWhere(
        (t) => t.id == state.selectedTerritoryId,
        orElse: () => state.territories.first,
      );
      final bounds = BoundsCalculator.fromTerritories([territory]);
      _cameraController.fitToBounds(bounds);
    }

    // Auto-fit on mode change
    if (state.mapMode != previous?.mapMode) {
      switch (state.mapMode) {
        case MapMode.overview:
          final bounds = BoundsCalculator.calculateOverviewBounds(state);
          _cameraController.fitToBounds(
            bounds,
            priority: CameraPriority.autoFit,
          );
          break;
        case MapMode.workers:
        case MapMode.territories:
          // Keep current view
          break;
      }
    }
  }

  void dispose() {
    _stateSubscription?.cancel();
    _territoryLayer.dispose();
    _workerLayer.dispose();
    _activityLayer.dispose();
    _trailLayer.dispose();
    _breachLayer.dispose();
  }
}
